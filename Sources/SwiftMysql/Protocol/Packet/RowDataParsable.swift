protocol RowDataParsable {
    var hasMoreResults: Bool { get set }
    var columns: [Field] { get }
    func parse(bytes: [UInt8]) throws -> [Any?]?
    init(columns: [Field])
}
