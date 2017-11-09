//
//  AsyncTransaction.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/09.
//

import Foundation

extension AsyncConnection {
    public func transaction(completion: @escaping (Error?, AsyncConnection?) -> Void) {
        query("START TRANSACTION;") { [weak self] result in
            if let error = result.asError() {
                return completion(error, nil)
            }
            guard let strongSelf = self else { return }
            strongSelf.isTransacting = true
            _ = result.asQueryStatus()
            completion(nil, strongSelf)
        }
    }
    
    public func commit(completion: @escaping (AsyncQueryResult) -> Void) {
        query("COMMIT;") { [weak self] in
            self?.isTransacting = false
            self?.release()
            completion($0)
        }
    }
    
    public func rollback(completion: @escaping (AsyncQueryResult) -> Void) {
        query("ROLLBACK;") { [weak self] in
            self?.isTransacting = false
            self?.release()
            completion($0)
        }
    }
}

extension AsyncConnectionPool {
    public func transaction(completion: @escaping (Error?, AsyncConnection?) -> Void) {
        getConnection { error, con in
            if let error = error {
                return completion(error, nil)
            }
            
            con?.transaction(completion: completion)
        }
    }
    
    public func commit(completion: @escaping (AsyncQueryResult) -> Void) {
        getConnection { error, con in
            if let error = error {
                return completion(.error(error))
            }
            
            con?.commit(completion: completion)
        }
    }
    
    public func rollback(completion: @escaping (AsyncQueryResult) -> Void) {
        getConnection { error, con in
            if let error = error {
                return completion(.error(error))
            }
            
            con?.rollback(completion: completion)
        }
    }
}
