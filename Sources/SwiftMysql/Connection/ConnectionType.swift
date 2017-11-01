//
//  Connection+parser.swift
//  SwiftKnex
//
//  Created by Yuki Takei on 2017/01/10.
//
//

import Foundation

public protocol ConnectionProtocol {
    var url: URL { get }
    var user: String { get }
    var password: String? { get }
    var database: String? { get }
    var isClosed: Bool { get }
    
    func query(_ sql: String) throws -> QueryResult
    func query(_ sql: String, bindParams params: [Any]) throws -> QueryResult
    func close () throws
}
