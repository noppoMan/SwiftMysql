//
//  Error.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/06.
//

import Foundation

func mysqlError(fromPacket bytes :[UInt8]) -> MysqlError? {
    if bytes.count == 0 || bytes[0] != 0xff {
        return nil
    }
    
    let errno = bytes[1...3].uInt16()
    var pos = 3
    
    if bytes[3] == 0x23 {
        pos = 9
    }
    var d1 = Array(bytes[pos..<bytes.count])
    d1.append(0)
    let errStr = d1.string()
    
    if errno > 2000 {
        return MysqlClientError.error(code: Int16(errno), message: errStr ?? "Unknown")
    }
    
    return MysqlServerError.error(code: Int16(errno), message: errStr ?? "Unknown")
}

public protocol MysqlError: Error {
    var code: Int16 { get }
    var message: String { get }
}

public enum MysqlClientError: MysqlError {
    case commandsOutOfSync
    case error(code: Int16, message: String)
}

extension MysqlClientError {
    public var code: Int16 {
        switch self {
        case .commandsOutOfSync:
            return 2014
        case .error(let code, _):
            return code
        }
    }
    
    public var message: String {
        switch self {
        case .commandsOutOfSync:
            return "Commands out of sync; you can't run this command now"
        case .error(_, let mes):
            return mes
        }
    }
}

extension MysqlClientError: CustomStringConvertible {
    public var description: String {
        return "MYSQL CLIENT ERROR \(code): \(message)"
    }
}

public enum MysqlServerError: MysqlError {
    case eofEncountered
    case error(code: Int16, message: String)
}

extension MysqlServerError {
    public var code: Int16 {
        switch self {
        case .eofEncountered:
            return -1
        case .error(let code, _):
            return code
        }
    }
    
    public var message: String {
        switch self {
        case .eofEncountered:
            return "EOF encountered"
        case .error(_, let mes):
            return mes
        }
    }
}

extension MysqlServerError: CustomStringConvertible {
    public var description: String {
        return "MYSQL SERVER ERROR \(code): \(message)"
    }
}
