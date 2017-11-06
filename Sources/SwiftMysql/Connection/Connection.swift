//
//  Connection.swift
//  SwiftKnex
//
//  Created by Yuki Takei on 2017/01/09.
//
//

import Foundation

public enum ConnectionError: Error {
    case failedToParseHandshakeOf(String)
    case wrongHandshake
}

// syncronous connection
public final class Connection: ConnectionProtocol {
    public let url: URL
    public let user: String
    public let password: String?
    public let database: String?
    
    private var _isClosed = true
    
    public var isClosed: Bool {
        return _isClosed
    }
    
    var isUsed = false
    
    var isTransacting = false
    
    public var isShowSQLLog = false
    
    let stream: PacketStream
    
    let cond = Cond()
    
    public init(url: URL, user: String, password: String? = nil, database: String? = nil) throws {
        self.url = url
        self.user = user
        self.password = password
        self.database = database
        let tcp = try TCPStream(host: url.host ?? "localhost", port: UInt(url.port ?? 3306))
        self.stream = PacketStream(stream: tcp)
        try self.open()
    }
    
    private func open() throws {
        try stream.open()
        let (handshakeBytes, packnr) = try self.stream.readPacket()
        let hp = try HandshakePacket(bytes: handshakeBytes)
        
        let authPacket = hp.buildAuthPacket(
            user: user,
            password: password,
            database: database
        )
        
        try stream.writePacket(authPacket, packnr: packnr)
        let (bytes, _) = try stream.readPacket()
        
        guard let _ = try OKPacket(bytes: bytes) else {
            fatalError("OK Packet should not be nil")
        }
        
        _isClosed = false
    }
    
    func reserve(){
        cond.mutex.lock()
        isUsed = true
        cond.mutex.unlock()
    }
    
    func release(){
        cond.mutex.lock()
        isUsed = false
        cond.mutex.unlock()
    }
    
    public func close() throws {
        try stream.write(.quit)
        stream.close()
        _isClosed = true
        release()
    }
}
