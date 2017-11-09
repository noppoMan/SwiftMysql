import Foundation
import Dispatch
import ProrsumNet

// TODO Should divide Readable and Writable
public protocol AsyncDuplexStream {
    func read(upTo: Int, completion: @escaping (Error?, Bytes?) -> Void)
    func write(_ bytes: Bytes, completion: (() -> Void)?)
    func close()
    func suspend()
    func resume()
    func open(completion: ((Error?, AsyncTCPConnection?) -> Void)?)
    var isClosed: Bool { get }
}

extension AsyncDuplexStream {
    public func read(upTo numOfBytes: Int = 1024, completion: @escaping (Error?, Bytes?) -> Void) {
        self.read(upTo: numOfBytes, completion: completion)
    }
}

public class AsyncTCPConnection: AsyncDuplexStream {
    let socket: TCPSocket
    
    public let host: String
    
    public let port: UInt
    
    private var readSource: DispatchSourceRead?
    
    private var connectSource: DispatchSourceRead?
    
    private var _onRead: ((Error?, Bytes?) -> Void)?
    private var _writeQueue: [() -> Void] = []
    
    private var numOfBytesToRead: Int = 1024
    
    let queue: DispatchQueue
    
    var readSourceIsSuspending = true
    
    var _onConnect: ((Error?, AsyncTCPConnection?) -> Void)?
    
    public var isClosed: Bool {
        return socket.isClosed
    }
    
    init(socket: TCPSocket, host: String, port: UInt, queue: DispatchQueue? = nil) {
        self.socket = socket
        self.host = host
        self.port = port
        self.queue = queue ?? DispatchQueue(label: "com.github.noppoMan.SwiftMysql-WokerThreadQueue")
        createConnectSource()
    }
    
    /// Connect to the remote host
    /// Currently DNS resolver is blocking operation
    public func open(completion: ((Error?, AsyncTCPConnection?) -> Void)?) {
        _onConnect = completion
        
        DispatchQueue.global().async { [weak self] in
            guard let strongSelf = self else { return }
            
            do {
                // resolve dns on the another worker thread
                let address = Address(host: strongSelf.host, port: strongSelf.port, addressFamily: .inet)
                let resolvedAddress = try address.resolve(sockType: .stream, protocolType: .tcp)
                
                // back to our worker thread
                strongSelf.queue.async { [weak self] in
                    do {
                        try self?.socket.connect(withResolvedAddress: resolvedAddress)
                    } catch SystemError.operationNowInProgress {
                        // connect returns EINPROGRESS, When the socket is non-blocking.
                        // It doesn't need to report
                        
                        // EINPROGRESS
                        //
                        // The socket is nonblocking and the connection cannot be completed
                        // immediately.  It is possible to select(2) or poll(2) for completion by
                        // selecting the socket for writing.  After select(2) indicates
                        // writability, use getsockopt(2) to read the SO_ERROR option at level
                        // SOL_SOCKET to determine whether connect() completed successfully
                        // (SO_ERROR is zero) or unsuccessfully (SO_ERROR is one of the usual
                        // error codes listed here, explaining the reason for the failure).
                    } catch {
                        self?._onConnect?(error, nil)
                    }
                }
            } catch {
                strongSelf._onConnect?(error, nil)
            }
        }
    }

    private func createConnectSource() {
        self.connectSource = DispatchSource.makeReadSource(fileDescriptor: socket.fd, queue: queue)
        
        connectSource!.setEventHandler { [weak self, weak connectSource] in
            connectSource?.cancel()
            guard let strongSelf = self else { return }
            strongSelf._onConnect?(nil, strongSelf)
            
            // move to read source
            strongSelf.createReadSource()
        }
        connectSource?.resume()
    }
    
    private func createReadSource() {
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: socket.fd, queue: queue)
        
        readSource!.setEventHandler { [weak self] in
            guard let strongSelf = self else { return }
            do {
                let bytes = try strongSelf.socket.recv(upTo: strongSelf.numOfBytesToRead, deadline: 0)
                strongSelf._onRead?(nil, bytes)
            } catch ProrsumNet.SocketError.alreadyClosed {
                self?.close()
            } catch {
                strongSelf._onRead?(error, nil)
            }
        }
        resume()
    }
    
    public func close() {
        socket.close()
        readSource?.cancel()
    }
    
    public func read(upTo numOfBytes: Int, completion: @escaping (Error?, Bytes?) -> Void) {
        //snumOfBytesToRead = numOfBytes
        _onRead = nil
        _onRead = completion
    }
    
    public func write(_ bytes: Bytes, completion: (() -> Void)? = nil) {
        do {
            try self.socket.send(bytes)
            completion?()
        } catch {
            completion?()
            // TODO should pass the error to the user
            print("Error occured on writing packet: \(error)")
        }
    }
    
    public func resume() {
        if readSourceIsSuspending {
            readSource?.resume()
            readSourceIsSuspending = false
        }
    }
    
    public func suspend() {
        if !readSourceIsSuspending {
            readSource?.suspend()
            readSourceIsSuspending = true
        }
    }
    
    /// builder method
    public static func create(host: String, port: UInt, queue: DispatchQueue? = nil) throws -> AsyncTCPConnection {
        let socket = try TCPSocket(addressFamily: .inet)
        try socket.setBlocking(shouldBlock: false) // enable non-blocking modes
        return AsyncTCPConnection(socket: socket, host: host, port: port, queue: queue)
    }
}
