//
//  AsyncQueryResult.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/08.
//

public enum AsyncQueryResult {
    public final class ResultSetEvent {
        var _onFilds: (([String]) -> Void)?
        var _onRow: (([Any?]) -> Void)?
        var _onEnd: (() -> Void)?
        
        public func onFields(completion: @escaping ([String]) -> Void) {
            self._onFilds = completion
        }
        
        public func onRow(completion: @escaping ([Any?]) -> Void) {
            self._onRow = completion
        }
        
        public func onEnd(completion: @escaping () -> Void) {
            self._onEnd = completion
        }
    }
    
    case error(Error)
    case resultSet(ResultSetEvent)
    case queryStatus(QueryStatus)
}

extension AsyncQueryResult {
    public func asError() -> Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
    
    public func asQueryStatus() -> QueryStatus? {
        if case .queryStatus(let qs) = self {
            return qs
        }
        return nil
    }
    
    public func asResultSet() -> ResultSetEvent? {
        if case .resultSet(let event) = self {
            return event
        }
        return nil
    }
    
    public func asRows(completion: @escaping (Rows) -> Void) {
        if case .resultSet(let event) = self {
            var fields = [String]()
            var rows = [[Any?]]()
            
            event.onFields {
                fields = $0
            }
            
            event.onRow {
                rows.append($0)
            }
            
            event.onEnd {
                completion(QueryResult.merge(columns: fields, andRows: rows))
            }
        }
    }
}
