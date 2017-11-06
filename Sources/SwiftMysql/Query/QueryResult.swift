public enum QueryResult {
    case resultSet(ResultFetcher)
    case queryStatus(QueryStatus)
}

extension QueryResult {
    public func asResultSet() -> ResultFetcher? {
        switch self {
        case .resultSet(let fetcher):
            return fetcher
        default:
            return nil
        }
    }
    
    public func asQueryStatus() -> QueryStatus? {
        switch self {
        case .queryStatus(let status):
            return status
        default:
            return nil
        }
    }
    
    public func asRows() -> Rows? {
        switch self {
        case .resultSet(let resultSet):
            let collection: [[String:Any?]] = resultSet.rows
                .map { zip(resultSet.columns, $0) }
                .map { row in
                    var dictionary = [String:Any?]()
                    for (title, value) in row {
                        if dictionary[title] == nil {
                            dictionary[title] = value
                        } else {
                            var i = 1
                            while (dictionary[title + ".\(i)"] != nil) {
                                i = i + 1
                            }
                            dictionary[title + ".\(i)"] = value
                        }
                    }
                    return dictionary
                }
                return collection
        default:
            return nil
        }
    }
}
