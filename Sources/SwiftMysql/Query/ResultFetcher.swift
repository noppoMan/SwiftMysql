//
//  ResultFetcher.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/03.
//

import Foundation

public final class ResultFetcher {
    
    private let stream: PacketStream
    
    private let columnLength: Int
    
    private let RowDataParser: RowDataParsable.Type
    
    private let onReceiveEOF: (() -> Void)?
    
    public var columns: [String] {
        return fields?.map({ $0.name }) ?? []
    }
    
    private lazy var fields: [Field]? = {
        do {
            return try readColumns(count: columnLength)
        } catch {
            print("\(error)")
            return nil
        }
    }()
    
    public lazy var rows: RowSequence = {
        return RowSequence(
            stream: stream,
            fields: fields ?? [],
            RowDataParser: RowDataParser,
            onReceiveEOF: onReceiveEOF
        )
    }()
    
    init(stream: PacketStream, columnLength: Int, RowDataParser: RowDataParsable.Type, onReceiveEOF: (() -> Void)? = nil) {
        self.stream = stream
        self.columnLength = columnLength
        self.RowDataParser = RowDataParser
        self.onReceiveEOF = onReceiveEOF
    }
    
    private func readColumns(count: Int) throws -> [Field] {
        if stream.isClosed {
            throw StreamError.alreadyClosed
        }
        
        if count == 0 {
            return []
        }
        
        let parser = FieldParser(count: count)
        while true {
            let (bytes, _) = try stream.readPacket()
            guard let fields = try parser.parse(bytes: bytes) else {
                continue
            }
            
            return fields
        }
    }
}
