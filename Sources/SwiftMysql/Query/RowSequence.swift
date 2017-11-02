//
//  RowSequence.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/03.
//

import Foundation

public struct RowSequence: Sequence, IteratorProtocol {
    
    private let stream: PacketStream
    
    private let parser: RowDataParsable
    
    public typealias Element = [Any?]
    
    init(stream: PacketStream, fields: [Field], RowDataParser: RowDataParsable.Type) {
        self.stream = stream
        self.parser = RowDataParser.init(columns: fields)
    }
    
    public mutating func next() -> [Any?]? {
        do {
            return try attemptToRead(rowsWithParser: parser)
        } catch {
            print("\(error)")
            return nil
        }
    }
    
    private func attemptToRead(rowsWithParser parser: RowDataParsable) throws -> [Any?]? {
        while true {
            let (bytes, _) = try stream.readPacket()
            if let rows = try parser.parse(bytes: bytes) {
                return rows
            } else {
                if parser.hasMoreResults {
                    continue
                }
            }
            break
        }
        
        return nil
    }
}

