import Foundation

extension Connection {
    
    private func sqlLog(_ query: String, bindParams: [Any]){
        if isShowSQLLog {
            print("sql: \(query) bindParams: \(bindParams)")
        }
    }
    
    public func query(_ query: String, bindParams params: [Any]) throws -> QueryResult {
        if self.isClosed {
            throw StreamError.alreadyClosed
        }
        
        sqlLog(query, bindParams: params)
        
        let stmt = try prepare(query)
        
        let packet = try stmt.executePacket(params: params)
        
        try stream.writePacket(packet, packnr: -1)
        
        return try readResults(RowDataParser: BinaryRowDataPacket.self)
    }
    
    private func prepare(_ query: String) throws -> Statement {
        if self.isClosed {
            throw StreamError.alreadyClosed
        }
        
        try stream.write(.stmtPrepare, query: query)
        let (bytes, _) = try stream.readPacket()
        
        if bytes[0] != 0x00 {
            switch bytes[0] {
            case 0x03:
                throw MysqlClientError.commandsOutOfSync
            default:
                throw createErrorFrom(errorPacket: bytes)
            }
        }
        
        guard let prepareResult = try PrepareResultPacket(bytes: bytes) else {
            throw PrepareResultPacketError.failedToParsePrepareResultPacket
        }
        
        if prepareResult.paramCount > 0 {
            try stream.readUntilEOF()
        }
        
        if prepareResult.columnCount > 0 {
            try stream.readUntilEOF()
        }
    
        return Statement(prepareResult: prepareResult)
    }
    
    public func query(_ query: String) throws -> QueryResult {
        if self.isClosed {
            throw StreamError.alreadyClosed
        }
        
        sqlLog(query, bindParams: [])
        
        try stream.write(.query, query: query)
        
        return try readResults(RowDataParser: RowDataPacket.self)
    }
    
    private func readResults(RowDataParser: RowDataParsable.Type) throws -> QueryResult {
        var len: Int, _okPacket: OKPacket?
        (len, _okPacket) = try stream.readHeaderPacket()
        
        if let okPacket = _okPacket {
            let qs = QueryStatus(
                affectedRows: okPacket.affectedRows ?? 0,
                insertId: okPacket.insertId
            )
            return .queryStatus(qs)
        }
        
        if len == 0 {
            throw MysqlClientError.commandsOutOfSync
        }
        
        let fetcher = ResultFetcher(
            stream: stream,
            columnLength: len,
            RowDataParser: RowDataParser
        )
        return .resultSet(fetcher)
    }
    
    public func use(database: String) throws {
        try stream.write(.initDB, query: database)
        let (len, _) = try stream.readHeaderPacket()
        
        if len > 0 {
            try stream.readUntilEOF()
            try stream.readUntilEOF()
        }
    }
}
