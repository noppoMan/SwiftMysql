import XCTest
@testable import SwiftMysql
import Foundation

class AsyncWriteTests: XCTestCase {
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testInsert() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        series(tasks: [
            { next in
                con.query("insert into users (name, email) values (\"Jack\", \"jack@example.com\")") {
                    XCTAssertEqual($0.asQueryStatus()?.affectedRows, 1)
                    XCTAssertEqual($0.asQueryStatus()?.insertId, 201)
                    next()
                }
            },
            { next in
                con.query("""
                    insert into users (name, email) values
                        ("Tonny", "tonny@example.com"),
                        ("Chloe", "chloe@example.com");
                """) {
                    XCTAssertEqual($0.asQueryStatus()?.affectedRows, 2)
                    XCTAssertEqual($0.asQueryStatus()?.insertId, 202)
                    next()
                }
            }
        ]) {
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests : [(String, (AsyncWriteTests) -> () throws -> Void)] {
        return [
            ("testInsert", testInsert)
        ]
    }
}
