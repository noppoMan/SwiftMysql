import XCTest
@testable import SwiftMysql
import Foundation

class ConnectionPoolTests: XCTestCase {
    
    func testMinPool() {
        do {
            let pool = try ConnectionPool(
                url: URL(string: "mysql://localhost:3306")!,
                user: "root",
                database: "swift_mysql_test",
                minPoolSize: 2,
                maxPoolSize: 5
            )
            
            XCTAssertEqual(pool.availableConnectionCount, 2)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testMaxPool() {
        let pool = try? ConnectionPool(
            url: URL(string: "mysql://localhost:3306")!,
            user: "root",
            database: "swift_mysql_test",
            minPoolSize: 2,
            maxPoolSize: 5
        )
        
        do {
            _ = try pool?.getConnection()
            _ = try pool?.getConnection()
            _ = try pool?.getConnection()
            _ = try pool?.getConnection()
            _ = try pool?.getConnection()
            
            // can not get this
            _ = try pool?.getConnection()
            
        } catch ConnectionPoolError.failedToGetConnectionFromPool {
            pool?.connections.first?.release()
            XCTAssertEqual(pool?.availableConnectionCount, 1)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testTransactingConnectionShouldNotBeRelease() {
        let pool = try? ConnectionPool(
            url: URL(string: "mysql://localhost:3306")!,
            user: "root",
            database: "swift_mysql_test",
            minPoolSize: 1,
            maxPoolSize: 2
        )
        
        try? pool?.transaction { con in
            _ = try con.query("show tables like 'user'")
            XCTAssertEqual(con.isTransacting, true)
            XCTAssertEqual(pool?.availableConnectionCount, 0)
        }
    }
    
    static var allTests : [(String, (ConnectionPoolTests) -> () throws -> Void)] {
        return [
            ("testMinPool", testMinPool),
            ("testMaxPool", testMaxPool),
            ("testTransactingConnectionShouldNotBeRelease", testTransactingConnectionShouldNotBeRelease),
        ]
    }
}
