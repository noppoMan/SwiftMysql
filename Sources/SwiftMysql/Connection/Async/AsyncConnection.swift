//
//  AsyncMysqlConnection.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/08.
//

import Foundation

public struct Nothing {}
public struct RowEndPacket {}

public protocol AsyncConnectionProtocol {
    var url: URL { get }
    var user: String { get }
    var password: String? { get }
    var database: String? { get }
    var isClosed: Bool { get }
    
    func query(_ query: String, completion: @escaping (AsyncQueryResult) -> Void)
    func query(_ query: String, bindParams params: [Any], completion: @escaping (AsyncQueryResult) -> Void)
    func close ()
}

public final class AsyncConnection: AsyncConnectionProtocol {
    class QueryQueueItem {
        let sql: String
        let params: [Any]?
        let RowDataParser: RowDataParsable.Type
        
        let fieldsEventEmitter: ThreadUnsafeEventEmitter<[String]>
        let rowEventEmitter: ThreadUnsafeEventEmitter<[Any?]>
        let errorEventEmitter: ThreadUnsafeEventEmitter<Error>
        let queryStatusSetEventEmitter: ThreadUnsafeEventEmitter<QueryStatus>
        
        init(sql: String, params: [Any]? = nil, RowDataParser: RowDataParsable.Type) {
            self.sql = sql
            self.params = params
            self.RowDataParser = RowDataParser
            
            self.fieldsEventEmitter = ThreadUnsafeEventEmitter<[String]>()
            self.rowEventEmitter = ThreadUnsafeEventEmitter<[Any?]>()
            self.errorEventEmitter = ThreadUnsafeEventEmitter<Error>()
            self.queryStatusSetEventEmitter = ThreadUnsafeEventEmitter<QueryStatus>()
        }
    }
    
    public let url: URL
    
    public let user: String
    
    public let password: String?
    
    public let database: String?
    
    public var isClosed: Bool {
        return stream.isClosed
    }
    
    public private(set) var isConnected = false
    
    public var isShowSQLLog = false
    
    var isTransacting = false
    
    var isUsed = false
    
    private let stream: AsyncTCPConnection
    
    private var unmanagedSelf: Unmanaged<AsyncConnection>?
    
    let connectEventEmitter: ThreadUnsafeEventEmitter<Nothing>
    let errorEventEmitter: ThreadUnsafeEventEmitter<Error>
    let connectionFreedEventEmitter: ThreadUnsafeEventEmitter<AsyncConnection>
    
    let packetWriter: MysqlPacketWriter
    
    private var queryQueue: [QueryQueueItem] = []
    
    private var _onConnet: (() -> Void)?
    private var _onError: ((Error) -> Void)?
    
    private var state: State = .beforeAuthenticate
    
    public init(url: URL, user: String, password: String? = nil, database: String? = nil, queue: DispatchQueue? = nil) throws {
        self.url = url
        self.user = user
        self.password = password
        self.database = database
        self.stream = try AsyncTCPConnection.create(host: url.host!, port: UInt(url.port!), queue: queue)
        self.connectEventEmitter = ThreadUnsafeEventEmitter<Nothing>()
        self.errorEventEmitter = ThreadUnsafeEventEmitter<Error>()
        self.connectionFreedEventEmitter = ThreadUnsafeEventEmitter<AsyncConnection>()
        
        self.packetWriter = MysqlPacketWriter(stream: stream)
        
        self.open()
        self.unmanagedSelf = Unmanaged.passRetained(self)
        
        setupEventEmitter()
    }
    
    private func setupEventEmitter() {
        connectEventEmitter.on { [weak self] _ in
            self?.processNextQueue()
            self?._onConnet?()
        }
        
        errorEventEmitter.on { [weak self] error in
            self?._onError?(error)
        }
    }
    
    public func onConnect(completion: @escaping () -> Void) {
        _onConnet = completion
    }
    
    public func onError(completion: @escaping (Error) -> Void) {
        _onError = completion
    }
    
    func reserve() {
        isUsed = true
    }
    
    func release() {
        isUsed = false
        connectionFreedEventEmitter.emit(with: self)
    }
    
    private func open() {
        stream.open { [weak self] error, con in
            guard let strongSelf = self else { return }
            if let error = error {
                return strongSelf.errorEventEmitter.emit(with: error)
            }
            
            strongSelf.isConnected = true
            strongSelf.connectEventEmitter.emit(with: Nothing())
            strongSelf.parseIncomingMysqlPacket()
        }
    }
    
    public func close() {
        packetWriter.write(.quit)
        stream.close()
        isConnected = false
        unmanagedSelf?.release()
    }
    
    private func sqlLog(_ query: String, bindParams: [Any]){
        if isShowSQLLog {
            print("sql: \(query) bindParams: \(bindParams)")
        }
    }
}


extension AsyncConnection {
    public func query(_ query: String, completion: @escaping (AsyncQueryResult) -> Void) {
        execute(query: query, bindParams: nil, RowDataParser: RowDataPacket.self, completion: completion)
    }
    
    public func query(_ query: String, bindParams params: [Any], completion: @escaping (AsyncQueryResult) -> Void) {
        execute(query: query, bindParams: params, RowDataParser: BinaryRowDataPacket.self, completion: completion)
    }
    
    private func execute(query: String, bindParams params: [Any]?, RowDataParser: RowDataParsable.Type, completion: @escaping (AsyncQueryResult) -> Void) {
        if self.isClosed {
            return completion(.error(StreamError.alreadyClosed))
        }
        
        var resultSetEvent: AsyncQueryResult.ResultSetEvent?
        
        let item = QueryQueueItem(sql: query, params: params, RowDataParser: RowDataParser.self)
        
        item.fieldsEventEmitter.on { fields in
            if resultSetEvent == nil {
                resultSetEvent = AsyncQueryResult.ResultSetEvent()
                completion(.resultSet(resultSetEvent!))
            }
            
            resultSetEvent!._onFilds?(fields)
        }
        
        item.rowEventEmitter.on { row in
            if resultSetEvent == nil {
                resultSetEvent = AsyncQueryResult.ResultSetEvent()
                completion(.resultSet(resultSetEvent!))
            }
            
            if row.count == 0 {
                resultSetEvent!._onRow?(row)
                return
            }
            
            if let _ = row[0] as? RowEndPacket {
                resultSetEvent!._onEnd?()
            } else {
                resultSetEvent!._onRow?(row)
            }
        }
        
        item.errorEventEmitter.on {
            completion(.error($0))
        }
        
        item.queryStatusSetEventEmitter.on {
            completion(.queryStatus($0))
        }
        
        queryQueue.push(item)
        
        processNextQueue()
    }
}

/// internal state management and packet parsing
private extension AsyncConnection {
    enum State {
        case beforeAuthenticate
        case authenticating
        case authenticated
        case endWithQueryStatus
        
        case startQuerying
        case startStmt // parepared statement
        case parsingColumns
        case parsingResultSet
        case endWithResultSet
        case endWithError
        
        var canWriteQuery: Bool {
            switch self {
            case .authenticated, .endWithQueryStatus, .endWithResultSet, .endWithError:
                return true
            default:
                return false
            }
        }
    }
    
    func parseIncomingMysqlPacket() {
        var buffer = [Byte]()
        var currentColumnLength = 0
        var fieldParser: FieldParser?
        var rowParser: RowDataParsable?
        var fields: [Field]?
        var prepareResult: PrepareResultPacket?
        
        stream.read { [weak self] error, _currentReceivedBytes in
            do {
                if let error = error {
                    throw error
                }
                
                guard let strongSelf = self, let currentReceivedBytes = _currentReceivedBytes else {
                    fatalError("Impossible to reach")
                }
                
                switch strongSelf.state {
                case .beforeAuthenticate:
                    let (_, seqId, body) = try strongSelf.parseHeaderPacket(bytes: currentReceivedBytes)
                    buffer.append(contentsOf: body)
                    
                    let hp = try HandshakePacket(bytes: buffer)
                    let authPacket = hp.buildAuthPacket(
                        user: strongSelf.user,
                        password: strongSelf.password,
                        database: strongSelf.database
                    )
                    
                    strongSelf.packetWriter.writePacket(authPacket, packnr: seqId)
                    strongSelf.changeState(to: .authenticating)
                    buffer.removeAll()
                    
                case .authenticating:
                    let (_, _, body) = try strongSelf.parseHeaderPacket(bytes: currentReceivedBytes)
                    buffer.append(contentsOf: body)
                    
                    guard let _ = try OKPacket(bytes: buffer) else {
                        fatalError("OK Packet should not be nil")
                    }
                    
                    strongSelf.changeState(to: .authenticated)
                    strongSelf.connectEventEmitter.emit(with: Nothing())
                    strongSelf.processNextQueue()
                    buffer.removeAll()
                    
                case .authenticated, .endWithError, .endWithResultSet, .endWithQueryStatus:
                    print("[SwiftMysql] Warning: unhandled packets are received.")
                    break
                    
                case .startStmt:
                    if buffer.isEmpty {
                        let (_, _, body) = try strongSelf.parseHeaderPacket(bytes: currentReceivedBytes)
                        
                        if !body[0].isStmtPacket {
                            switch body[0] {
                            case 0x03:
                                throw MysqlClientError.commandsOutOfSync
                            default:
                                throw mysqlError(fromPacket: body) ?? MysqlServerError.eofEncountered
                            }
                        }
                        
                        let preparePacket = Array(body[..<9])
                        if let _prepareResult = try PrepareResultPacket(bytes: preparePacket) {
                            prepareResult = _prepareResult
                            buffer = Array(body[preparePacket.count...])
                        }
                    } else {
                        buffer.append(contentsOf: currentReceivedBytes)
                    }
                    
                    let eofPacketIndex = buffer.count-5
                    if let prepareResult = prepareResult, buffer[eofPacketIndex].isEOFPacket {
                        let stmt = Statement(prepareResult: prepareResult)
                        let packet = try stmt.executePacket(params: strongSelf.queryQueue.head!.params!)
                        strongSelf.packetWriter.writePacket(packet, packnr: -1)
                        strongSelf.changeState(to: .startQuerying)
                        buffer.removeAll()
                    }
                    
                case .startQuerying:
                    let (length, _, body) = try strongSelf.parseHeaderPacket(bytes: currentReceivedBytes)

                    let bodyBytes = Array(body[..<length])
                    if let error = mysqlError(fromPacket: bodyBytes) {
                        throw error
                    }
                    
                    let (columnLength, _okPacket) = try okPacketOrFieldLength(for: bodyBytes)
                    
                    if let okPacket = _okPacket {
                        let qs = QueryStatus(
                            affectedRows: okPacket.affectedRows ?? 0,
                            insertId: okPacket.insertId
                        )
                        buffer.removeAll()
                        strongSelf.queryQueue.head?.queryStatusSetEventEmitter.emit(with: qs)
                        strongSelf.changeState(to: .endWithQueryStatus)
                        if !strongSelf.isTransacting {
                            strongSelf.release()
                        }
                        _ = strongSelf.queryQueue.popOrDie()
                        strongSelf.processNextQueue()
                        break
                    }
                    
                    currentColumnLength = columnLength
                    
                    buffer.append(contentsOf: Array(body[length...]))
                    strongSelf.changeState(to: .parsingColumns)
                    fallthrough
                    
                case .parsingColumns:
                    if fieldParser == nil {
                        fieldParser = FieldParser(count: currentColumnLength)
                    }
                    
                    if fieldParser?.columns.count ?? 0 > 0 {
                        buffer.append(contentsOf: currentReceivedBytes)
                    }
                    
                    while true {
                        do {
                            let (_bytes, nextBuffer) = try strongSelf.fieledBytes(bytes: buffer)
                            
                            buffer = nextBuffer
                            
                            if let bytes = _bytes {
                                if let _fields = try fieldParser?.parse(bytes: bytes) {
                                    strongSelf.queryQueue.head?.fieldsEventEmitter.emit(with: _fields.map({ $0.name }))
                                    strongSelf.changeState(to: .parsingResultSet)
                                    fields = _fields
                                    fallthrough
                                }
                                continue
                            }
                        } catch PacketParsingError.headerPacketIsTooShort {
                            // skip
                        } catch {
                            throw error
                        }
                        break
                    }
                    
                case .parsingResultSet:
                    guard let fields = fields, let query = strongSelf.queryQueue.head else {
                        fatalError("Impossible to reach")
                    }
                    
                    if rowParser == nil {
                        rowParser = query.RowDataParser.init(columns: fields)
                    } else {
                        buffer.append(contentsOf: currentReceivedBytes)
                    }
                    
                    while true {
                        do {
                            let (length, _, body) = try strongSelf.parseHeaderPacket(bytes: buffer)
                            if body.count < length {
                                break
                            }
                            
                            let rowBytes = Array(body[..<length])
                            
                            if let row = try rowParser?.parse(bytes: rowBytes) {
                                buffer = Array(body[length...])
                                query.rowEventEmitter.emit(with: row)
                                continue
                            }
                            
                            if body[0].isEOFPacket {
                                buffer.removeAll()
                                fieldParser = nil
                                rowParser = nil
                                strongSelf.changeState(to: .endWithResultSet)
                                let query = strongSelf.queryQueue.popOrDie()
                                query.rowEventEmitter.emit(with: [RowEndPacket()]) // emit row end event
                                if !strongSelf.isTransacting {
                                    strongSelf.release()
                                }
                                strongSelf.processNextQueue()
                            }
                            
                        } catch PacketParsingError.headerPacketIsTooShort {
                            // skip
                        } catch {
                            throw error
                        }
                        break
                    }
                }
            } catch  {
                switch error {
                case let error as MysqlClientError:
                    let queue = self?.queryQueue.popOrDie()
                    queue!.errorEventEmitter.emit(with: error)
                    
                case let error as MysqlServerError:
                    let queue = self?.queryQueue.popOrDie()
                    queue!.errorEventEmitter.emit(with: error)
                    
                case PacketParsingError.headerPacketIsTooShort:
                    fatalError("Unhandled error")
                    
                default:
                    self?.errorEventEmitter.emit(with: error)
                }
                
                self?.changeState(to: .endWithError)
                self?.processNextQueue()
                self?.release()
            }
        }
    }
    
    private func processNextQueue() {
        if state.canWriteQuery, let query = queryQueue.head {
            if let _ = query.params {
                // parepated statement
                packetWriter.write(.stmtPrepare, query: query.sql)
                changeState(to: .startStmt)
            } else {
                // normal query
                packetWriter.write(.query, query: query.sql)
                changeState(to: .startQuerying)
            }
        }
    }
    
    enum PacketParsingError: Error {
        case headerPacketIsTooShort
    }
    
    private func fieledBytes(bytes: Bytes) throws -> (Bytes?, Bytes) {
        let (length, _, body) = try parseHeaderPacket(bytes: bytes)
        
        if bytes.count >= length {
            return (Array(body[..<length]), Array(body[length...]))
        }
        
        return (nil, bytes)
    }
    
    private func parseHeaderPacket(bytes: Bytes) throws -> (Int, Int, Bytes) {
        if bytes.count < 5 {
            throw PacketParsingError.headerPacketIsTooShort
        }
        
        let len = Int(Array(bytes[..<3]).uInt24())
        let sequenceId = Int(bytes[3])
        let body = Array(bytes[4...])
        return (len, sequenceId, body)
    }
    
    private func changeState(to state: State) {
        self.state = state
    }
}

extension Array where Element == AsyncConnection.QueryQueueItem {
    mutating func push(_ item: Element) {
        insert(item, at: 0)
    }
    
    var tail: Element? {
        return first
    }
    
    var head: Element? {
        return last
    }
    
    mutating func popOrNil() -> Element? {
        if count == 0 {
            return nil
        }
        
        return removeLast()
    }
    
    @discardableResult
    mutating func popOrDie() -> Element {
        if let item = popOrNil() {
            return item
        }
        fatalError("QueryQueueItem should not be an empty")
    }
}
