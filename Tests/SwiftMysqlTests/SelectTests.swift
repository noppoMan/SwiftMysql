import XCTest
@testable import SwiftMysql
import Foundation

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

class SelectTests: XCTestCase {
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testSelect() throws {
        let con = try newConnection(withDatabase: testDatabaseName)
        defer {
            try? con.close()
        }
        
        // fields
        do {
            let result = try con.query("select id from users where id = 1").asResultSet()!
            XCTAssertEqual(result.columns, ["id"])
            let rows = result.rows.map({ $0 })
            XCTAssertEqual(rows.count, 1)
        }
        
        // where
        do {
            let result = try con.query("select * from users where id = 1")
            let rows = result.asRows()
            XCTAssertEqual(rows?.first?["id"] as? Int, 1)
            XCTAssertEqual(rows?.first?["name"] as? String, "Test User1")
            XCTAssertEqual(rows?.first?["email"] as? String, "test1@example.com")
        }
        
        // where in
        do {
            let result = try con.query("select * from users where id in(1, 2, 3)")
            let rows = result.asRows()
            XCTAssertEqual(rows?[0]["id"] as? Int, 1)
            XCTAssertEqual(rows?[1]["id"] as? Int, 2)
            XCTAssertEqual(rows?[2]["id"] as? Int, 3)
        }
        
        // where between
        do {
            let result = try con.query("select * from users where id between 10 and 37")
            let rows = result.asRows()
            XCTAssertEqual(rows?.first?["id"] as? Int, 10)
            XCTAssertEqual(rows?.last?["id"] as? Int, 37)
        }
        
        // where + limit
        do {
            let result = try con.query("select * from users where id > 10 limit 20")
            let rows = result.asRows()
            XCTAssertEqual(rows?.first?["id"] as? Int, 11)
            XCTAssertEqual(rows?.count, 20)
        }
        
        // where + limit, offset
        do {
            let result = try con.query("select * from users where id > 20 limit 5, 10")
            let rows = result.asRows()
            XCTAssertEqual(rows?.first?["id"] as? Int, 26)
            XCTAssertEqual(rows?.count, 10)
        }
        
        // No records
        do {
            let result = try con.query("select * from users where id = 10000")
            XCTAssertEqual(result.asRows()?.count, 0)
        }
    }
    
    func testFunction() throws {
        let con = try newConnection(withDatabase: testDatabaseName)
        defer {
            try? con.close()
        }
        
        // count
        do {
            let rows = try con.query("select count(id) as x from users").asRows()!
            XCTAssertEqual(rows.first?["x"] as? Int64, 200)
        }
        
        // abs
        do {
            let rows = try con.query("select abs(-100) as x").asRows()!
            XCTAssertEqual(rows.first?["x"] as? Int64, 100)
        }
        
        // exp
        do {
            let rows = try con.query("select exp(2) as x").asRows()!
            let y = 7.3890560989307 // exepected
            if let x = rows.first?["x"] as? Double {
                // nearly equal
                XCTAssertEqual(Double.minimumMagnitude(x, y), 7.38905609893065)
            } else {
                XCTFail("x type should be a Double")
            }
        }
    }
    
    func testJoin() throws {
        let con = try newConnection(withDatabase: testDatabaseName)
        defer {
            try? con.close()
        }
        
        let result = try con.query("""
            select t1.*, t2.token from \(userTableName) as t1 join \(accessTokenTableName) as t2
            on t1.id = t2.user_id
            where t1.id in(1, 2, 3)
            """)
        
        let rows = result.asRows()!
        for (i, row) in rows.enumerated() {
            XCTAssertEqual(row["token"] as? String, "accesstoken\(i+1)")
        }
    }
    
    func testError() {
        // commandsOutOfSync
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            _ = try con.query("select * from users where id = 1")
            _ = try con.query("select * from users where id = 2")
        } catch MysqlClientError.commandsOutOfSync {
            XCTAssertTrue(true, "Error should be a MysqlClientError.commandsOutOfSync")
        } catch {
            XCTFail("\(error)")
        }
        
        // syntax error
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            _ = try con.query("select * from users id = 1")
        } catch {
            if let e = error as? MysqlServerError {
                XCTAssertEqual(e.code, 1064)
            } else {
                XCTFail("Error should be a SyntaxError")
            }
        }
    }

    func testResultFetcherInfinitSequence() throws {
        let con = try newConnection(withDatabase: testDatabaseName)
        defer {
            try? con.close()
        }
        
        let result = try con.query("select * from users")
        guard let resultSet = result.asResultSet() else {
            fatalError("Here is never called")
        }
        
        XCTAssertEqual(resultSet.columns[0], "id")
        XCTAssertEqual(resultSet.columns[1], "name")
        XCTAssertEqual(resultSet.columns[2], "email")
        
        for (i, row) in resultSet.rows.enumerated() {
            XCTAssertEqual(row[0] as? Int, i+1)
            XCTAssertEqual(row[1] as? String, "Test User\(i+1)")
            XCTAssertEqual(row[2] as? String, "test\(i+1)@example.com")
        }
    }
    
// TODO not implemented yet
//    func testMultipleQueries() {
//        let url = URL(string: "mysql://localhost:3306")
//        let con = try! Connection(url: url!, user: "root", password: nil)
//
//        let result = try! con.query("select 1 + 1 as sum; select 2 + 1 as sum2")
//        print(result.asResultSet())
//    }
    
    static var allTests : [(String, (SelectTests) -> () throws -> Void)] {
        return [
            ("testSelect", testSelect),
            ("testFunction", testFunction),
            ("testJoin", testJoin),
            ("testError", testError),
            ("testResultFetcherInfinitSequence", testResultFetcherInfinitSequence)
        ]
    }
}
