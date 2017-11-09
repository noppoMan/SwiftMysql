import XCTest
@testable import SwiftMysql
import Foundation

class AsyncSelectTests: XCTestCase {
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testSelect() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        series(tasks: [
            // select all
            { next in
                con.query("select * from users") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows.count, 200)
                        next()
                    }
                }
            },
            
            { next in
                con.query("select * from users where id = 1") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows.first?["id"] as? Int, 1)
                        next()
                    }
                }
            },
            
            { next in
                con.query("select * from users limit 10, 5") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows.count, 5)
                        XCTAssertEqual(rows.first?["id"] as? Int, 11)
                        XCTAssertEqual(rows.last?["id"] as? Int, 15)
                        next()
                    }
                }
            },
            
            { next in
                con.query("select * from users where id in (1, 100, 150)") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows.count, 3)
                        XCTAssertEqual(rows[0]["id"] as? Int, 1)
                        XCTAssertEqual(rows[1]["id"] as? Int, 100)
                        XCTAssertEqual(rows[2]["id"] as? Int, 150)
                        next()
                    }
                }
            },
            
            { next in
                con.query("select * from users where id = 10000") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows.count, 0)
                        next()
                    }
                }
            },
        ]) {
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testFunction() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        series(tasks: [
            { next in
                con.query("select count(*) as cnt from users") { result in
                    result.asRows { rows in
                        XCTAssertEqual(rows[0]["cnt"] as? Int64, 200)
                        next()
                    }
                }
            }
        ]) {
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testJoin() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        con.query("""
            select t1.*, t2.token from \(userTableName) as t1 join \(accessTokenTableName) as t2
            on t1.id = t2.user_id
            where t1.id in(1, 2, 3)
            """)
        {
            $0.asRows { rows in
                for (i, row) in rows.enumerated() {
                    XCTAssertEqual(row["token"] as? String, "accesstoken\(i+1)")
                }
            }
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testError() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        series(tasks: [
            { next in
                con.query("select * fro users") {
                    switch $0 {
                    case .error(let error):
                        switch error {
                        case MysqlServerError.error(let code, let message):
                            // syntax error
                            XCTAssertEqual(code, 1064, message)
                            next()
                        default:
                            XCTFail("Here is never called")
                        }
                        
                    default:
                        XCTFail("Here is never called")
                    }
                }
            },
            { next in
                con.query("select * from fooooooooooooooo") {
                    switch $0 {
                    case .error(let error):
                        switch error {
                        case MysqlServerError.error(let code, let message):
                            // table doesn't exist
                            XCTAssertEqual(code, 1146, message)
                            next()
                        default:
                            XCTFail("Here is never called")
                        }
                        
                    default:
                        XCTFail("Here is never called")
                    }
                }
            }
        ]) {
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testResultSetEvent() throws {
        let exp = expectation(description: #function)
        let con = try newAsyncConnection()
        
        con.query("select * from users") {
            let rs = $0.asResultSet()
            
            rs?.onFields { fields in
                XCTAssertEqual(fields, ["id", "name", "email"])
            }
            
            var rowCount = 0
            
            rs?.onRow { _ in
                rowCount+=1
            }
            
            rs?.onEnd {
                XCTAssertEqual(rowCount, 200)
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests : [(String, (AsyncSelectTests) -> () throws -> Void)] {
        return [
            ("testSelect", testSelect),
            ("testFunction", testFunction),
            ("testJoin", testJoin),
            ("testError", testError),
            ("testResultSetEvent", testResultSetEvent)
        ]
    }
}
