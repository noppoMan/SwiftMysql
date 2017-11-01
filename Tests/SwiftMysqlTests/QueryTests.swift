import XCTest
@testable import SwiftMysql
import Foundation

class QueryTests: XCTestCase {
    func testSum() {
        let url = URL(string: "mysql://localhost:3306")
        let con = try! Connection(url: url!, user: "root", password: nil)
        
        let result = try! con.query("select 1 + 1 as sum")
        XCTAssertEqual(result.asResultSet()?.first?["sum"] as? Int64, 2)
    }
    
    func testQuery() {
        let url = URL(string: "mysql://localhost:3306")
        let con = try! Connection(url: url!, user: "root", password: nil, database: "mysql")
        let result = try! con.query("show tables like 'user'")
        XCTAssertEqual(result.asResultSet()!.count, 1)
        try! con.close()
    }
    
    func testNoRecord() {
        let url = URL(string: "mysql://localhost:3306")
        let con = try! Connection(url: url!, user: "root", password: nil, database: "mysql")
        let result = try! con.query("show tables like 'foobar'")
        XCTAssertTrue(result.isNoRecord)
        try! con.close()
    }
    
    func testPreparedStatement() {
        let url = URL(string: "mysql://localhost:3306")
        let con = try! Connection(url: url!, user: "root", password: nil, database: "mysql")
        con.isShowSQLLog = true
        let result = try! con.query("select * from user where User = ?", bindParams: ["root"])
        XCTAssertNotEqual(result.asResultSet()!.count, 0)
        try! con.close()
    }
    
// TODO not implemented yet
//    func testMultipleQueries() {
//        let url = URL(string: "mysql://localhost:3306")
//        let con = try! Connection(url: url!, user: "root", password: nil)
//
//        let result = try! con.query("select 1 + 1 as sum; select 2 + 1 as sum2")
//        print(result.asResultSet())
//    }
    
    static var allTests : [(String, (QueryTests) -> () throws -> Void)] {
        return [
            ("testSum", testSum),
            ("testQuery", testQuery),
            ("testNoRecord", testNoRecord),
            ("testPreparedStatement", testPreparedStatement)
        ]
    }
}
