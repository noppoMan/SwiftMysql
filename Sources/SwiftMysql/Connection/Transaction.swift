extension Connection {
    
    private func startTransaction() {
        cond.mutex.lock()
        isTransacting = true
        cond.mutex.unlock()
    }
    
    private func endTransaction() {
        cond.mutex.lock()
        isTransacting = false
        cond.mutex.unlock()
    }
    
    public func transaction(_ callback: (Connection) throws -> Void) throws {
        func _release() {
            endTransaction()
            release()
        }
        
        reserve()
        startTransaction()
        
        do {
            _ = try query("START TRANSACTION;")
        } catch {
            endTransaction()
            throw error
        }
        
        do {
            try callback(self)
            _ = try query("COMMIT;")
            _release()
        } catch {
            do {
                _ = try query("ROLLBACK;")
            } catch {
                _release()
                throw error
            }
            
            _release()
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
