import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

public final class AsyncConnectionPool: AsyncConnectionProtocol, ConnectionPoolProvidable {
    
    public var url: URL
    
    public var user: String
    
    public var password: String?
    
    public var database: String?
    
    public private(set) var isClosed = false
    
    public private(set) var isReady = false
    
    public var minPoolSize: UInt
    
    public var maxPoolSize: UInt
    
    public var pooledConnectionCount: Int {
        return connections.count
    }
    
    public var activeConnectionCount: Int {
        return connections.filter({ $0.isConnected }).count
    }
    
    public var availableConnectionCount: Int {
        return connections.filter({ !$0.isUsed }).count
    }
    
    var connections: [AsyncConnection] = []
    
    let queue: DispatchQueue
    
    private var _onReady: (() -> Void)?
    private var _onNewConnectionIsReady: (() -> Void)?
    
    private var getConnectionQueue: [(Error?, AsyncConnection?) -> Void] = []
    
    public init(url: URL, user: String, password: String? = nil, database: String? = nil, minPoolSize: UInt = 1, maxPoolSize: UInt = 5, queue: DispatchQueue? = nil) throws {
        self.url = url
        self.user = user
        self.password = password
        self.database = database
        self.minPoolSize = minPoolSize
        self.maxPoolSize = maxPoolSize
        self.queue = queue ?? DispatchQueue(label: "com.github.noppoMan.SwiftMysql-PoolingWokerThreadQueue")
        
        for _ in (0..<minPoolSize) {
            let con = try AsyncConnection(url: url, user: user, password: password, database: database, queue: self.queue)
            connections.append(con)
            con.connectEventEmitter.once { [weak self] _ in
                self?._onNewConnectionIsReady?()
                if let strongSelf = self, strongSelf.activeConnectionCount >= strongSelf.minPoolSize {
                    if strongSelf._onReady == nil {
                        strongSelf.onReady { }
                    }
                    strongSelf._onReady?()
                }
            }
            
            con.connectionFreedEventEmitter.on { [weak self] con in
                self?.processNextQueue(withConnection: con)
            }
        }
    }
    
    /// An event handler that is called when the minimum connections are connected with the Mysql Server
    public func onReady(completion: @escaping () -> Void) {
        _onReady = { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.isReady = true
            strongSelf.processQueueIfConnectionIsAvailable()
            
            let numOfConnectionsDiffFromMax = strongSelf.connections.count - Int(strongSelf.maxPoolSize)
            if numOfConnectionsDiffFromMax < 0 {
                var remainig = abs(numOfConnectionsDiffFromMax)
                if strongSelf.getConnectionQueue.count > 0 {
                    while remainig > 0 {
                        remainig-=1
                        strongSelf.addNewConnection()
                    }
                }
            }
            
            completion()
        }
    }
    
    /// An event handler that is called when a connection is connected with the Mysql Server
    public func onNewConnectionIsReady(completion: @escaping () -> Void) {
        _onNewConnectionIsReady = completion
    }
    
    public func query(_ query: String, completion: @escaping (AsyncQueryResult) -> Void) {
        getConnection { error, con in
            if let error = error {
                return completion(.error(error))
            }
            
            con?.query(query, completion: completion)
        }
    }
    
    public func query(_ query: String, bindParams params: [Any], completion: @escaping (AsyncQueryResult) -> Void) {
        getConnection { error, con in
            if let error = error {
                return completion(.error(error))
            }
            
            con?.query(query, bindParams: params, completion: completion)
        }
    }
    
    public func close() {
        for con in connections {
            // may need to socket.setBlocking(true)
            con.close()
        }
        isClosed = true
        connections.removeAll()
    }
    
    /// get a connection from pool
    /// TODO timeout is not implemented yet
    func getConnection(timeoutMilliseconds timeout: Int = 100000 /* 10 sec */, completion: @escaping (Error?, AsyncConnection?) -> Void) {
        
        getConnectionQueue.insert(completion, at: 0)
        
        if connections.isEmpty { // before ready
            return
        }
        
        if isReady, getConnectionQueue.count > activeConnectionCount {
            if connections.count < maxPoolSize {
                addNewConnection()
            }
        }
        
        processQueueIfConnectionIsAvailable()

// TODO implement timeout
//        let timer = DispatchSource.makeTimerSource()
//
//        timer.schedule(
//            deadline: DispatchTime(uptimeNanoseconds: 1),
//            repeating: DispatchTimeInterval.microseconds(100)
//        )
//
//
//        timer.setEventHandler {
//            print("fooooooooo")
//        }
//
//        timer.resume()
    }
    
    private func addNewConnection() {
        do {
            let con = try AsyncConnection(url: url, user: user, password: password, database: database, queue: queue)
            connections.append(con)
            
            con.connectEventEmitter.once { [weak self, unowned con] _ in
                self?.processNextQueue(withConnection: con)
                self?._onNewConnectionIsReady?()
            }
            
            con.connectionFreedEventEmitter.on { [weak self] con in
                self?.processNextQueue(withConnection: con)
            }
            
        } catch {
            print("[SwiftMysql] Error: Could not create new connection")
        }
    }
    
    private func processNextQueue(withConnection con: AsyncConnection) {
        if let queue = getConnectionQueue.last {
            con.reserve()
            _ = getConnectionQueue.removeLast()
            queue(nil, con)
        }
    }
    
    private func processQueueIfConnectionIsAvailable() {
        for con in self.connections {
            if !con.isConnected {
                continue
            }
            
            if con.isUsed {
                continue
            }
            
            processNextQueue(withConnection: con)
        }
    }
}
