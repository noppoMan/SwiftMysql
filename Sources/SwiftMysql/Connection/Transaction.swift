extension Connection {
    public func transaction(_ callback: (Connection) throws -> Void) throws {
        defer {
            isTransacting = false
            release()
        }
        isUsed = true
        _ = try query("START TRANSACTION;")
        isTransacting = true
        
        do {
            try callback(self)
            _ = try query("COMMIT;")
        } catch {
            do {
                _ = try query("ROLLBACK;")
            } catch {
                throw error
            }
            throw error
        }
    }
}

extension ConnectionPool {
    public func transaction(_ callback: (Connection) throws -> Void) throws {
        let con = try getConnection()
        try con.transaction(callback)
    }
    
}
