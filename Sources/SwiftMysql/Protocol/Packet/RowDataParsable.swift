protocol RowDataParsable {
    var hasMoreResults: Bool { get set }
    var columns: [Field] { get }
    func parse(bytes: [UInt8]) throws -> Row?
    init(columns: [Field])
}
