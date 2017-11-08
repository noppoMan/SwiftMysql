import Foundation

class RowDataPacket: RowDataParsable {
    
    let columns: [Field]
    
    var hasMoreResults = false
    
    required init(columns: [Field]) {
        self.columns = columns
    }
    
    func parse(bytes: [UInt8]) throws -> [Any?]? {
        if columns.isEmpty {
            return nil
        }
        
        if bytes[0] == 0xfe && bytes.count == 5 {
            let flags = Array(bytes[3..<5]).uInt16()
            self.hasMoreResults = flags & serverMoreResultsExists == serverMoreResultsExists
            return nil
        }
        
        if let error = mysqlError(fromPacket: bytes) {
            throw error
        }
        
        var rows = [Any?]()
        var pos = 0
        
        for index in 0...columns.count-1 {
            let (name, n) = lenEncStr(Array(bytes[pos..<bytes.count]))
            pos += n
            
            let column = columns[index]
            
            if let value = name {
                let row: Any?
                switch column.fieldType {
                case .varString:
                    row = value
                    
                case .longlong:
                    row = column.flags.isUnsigned() ? UInt64(value) : Int64(value)
                    
                case .int24, .long:
                    row = column.flags.isUnsigned() ? UInt(value) : Int(value)
                    
                case .short:
                    row = column.flags.isUnsigned() ? UInt16(value) : Int16(value)
                    
                case .tiny:
                    row = column.flags.isUnsigned() ? UInt8(value) : Int8(value)
                    
                case .double:
                    row = Double(value)
                    
                case .float:
                    row = Float(value)
                    
                case .date:
                    row = Date(dateString: String(value))
                    
                case .time:
                    row = Date(timeString: String(value))
                    
                case .datetime:
                    row = Date(dateTimeString: String(value))
                    
                case .timestamp:
                    row = Date(dateTimeString: String(value))
                    
                case .null:
                    row = nil
                    
                default:
                    row = nil
                }
                rows.append(row)
            } else {
                rows.append(nil)
            }
        }
        
        return rows
    }
}
