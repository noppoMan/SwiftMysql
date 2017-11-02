import XCTest
@testable import SwiftMysql
import Foundation

class PreparedStatementTests: XCTestCase {
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testSelect() {
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            
            do {
                let result = try con.query("select * from users where id = ? OR id = ?", bindParams: [102, 200])
                let rows = result.asRows()!
                XCTAssertEqual(rows.first?["id"] as? Int, 102)
                XCTAssertEqual(rows.last?["id"] as? Int, 200)
            }
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testError() {
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            _ = try con.query("select * from users where id = ?", bindParams: [1])
            _ = try con.query("select * from users where id = ?", bindParams: [2])
        } catch MysqlClientError.commandsOutOfSync {
            XCTAssertTrue(true, "Error shoule be a MysqlClientError.commandsOutOfSync")
        } catch {
            XCTFail("\(error)")
        }
        
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            _ = try con.query("select * from users where id = ? OR id = ?", bindParams: [1])
        } catch StatementError.argsCountMismatch {
            XCTAssertTrue(true, "Error shoule be a StatementError.argsCountMismatch")
        } catch {
            XCTFail("\(error)")
        }
    }
    
    static var allTests : [(String, (PreparedStatementTests) -> () throws -> Void)] {
        return [
            ("testSelect", testSelect),
            ("testError", testError)
        ]
    }
}
