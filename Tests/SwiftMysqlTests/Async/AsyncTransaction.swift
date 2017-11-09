import XCTest
@testable import SwiftMysql
import Foundation

class AsyncTransactionTests: XCTestCase {
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testTransaction() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        series(tasks: [
            { next in
                con.transaction { _, _ in
                    con.query("insert into users (name, email) values (\"Jack\", \"jack@example.com\")") { _ in
                        con.commit { _ in
                            con.query("select count(*) as cnt from users") {
                                $0.asRows {
                                    XCTAssertEqual($0.first?["cnt"] as? Int64, 201)
                                    next()
                                }
                            }
                        }
                    }
                }
            },
            { next in
                con.transaction { _, _ in
                    con.query("insert into users (name, email) values (\"Jack\", \"jack@example.com\")") { _ in
                        con.rollback { _ in
                            con.query("select count(*) as cnt from users") {
                                $0.asRows {
                                    XCTAssertEqual($0.first?["cnt"] as? Int64, 201)
                                    next()
                                }
                            }
                        }
                    }
                }
            }
        ]) {
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests : [(String, (AsyncTransactionTests) -> () throws -> Void)] {
        return [
            ("testTransaction", testTransaction)
        ]
    }
}

