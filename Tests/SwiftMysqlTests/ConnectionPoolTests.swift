import XCTest
@testable import SwiftMysql
import Foundation

class ConnectionPoolTests: XCTestCase {
    
    func newPoolingConnection() throws -> ConnectionPool {
        return try ConnectionPool(
            url: URL(string: "mysql://localhost:3306")!,
            user: "root",
            database: "swift_mysql_test",
            minPoolSize: 2,
            maxPoolSize: 5
        )
    }
    
    func testMinPool() {
        do {
            let pool = try newPoolingConnection()
            defer {
                try? pool.close()
            }
            XCTAssertEqual(pool.availableConnectionCount, 2)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testMaxPool() {
        var pool: ConnectionPool?
        do {
            pool = try newPoolingConnection()
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
            try? pool?.close()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testConnectionCount() {
        do {
            let pool = try newPoolingConnection()
            defer {
                try? pool.close()
            }

            XCTAssertEqual(pool.availableConnectionCount, 2)
            let result = try pool.query("show tables like 'user'")
            XCTAssertEqual(pool.availableConnectionCount, 1)
            _ = result.asRows()
            XCTAssertEqual(pool.availableConnectionCount, 2)
        } catch {
            print("hello")
            print(error)
            XCTFail("\(error)")
        }
    }
    
    func testTransactingConnectionShouldNotBeRelease() {
        do {
            let pool = try newPoolingConnection()
            defer {
                try? pool.close()
            }
            
            XCTAssertEqual(pool.availableConnectionCount, 2)
            
            try pool.transaction { con in
                let result = try con.query("show tables like 'user'")
                _ = result.asRows()
                XCTAssertEqual(con.isTransacting, true)
                XCTAssertEqual(pool.availableConnectionCount, 1)
            }
            
            XCTAssertEqual(pool.availableConnectionCount, 2)
            
        } catch {
            XCTFail("\(error)")
        }
    }
    
    static var allTests : [(String, (ConnectionPoolTests) -> () throws -> Void)] {
        return [
            ("testMinPool", testMinPool),
            ("testMaxPool", testMaxPool),
            ("testConnectionCount", testConnectionCount),
            ("testTransactingConnectionShouldNotBeRelease", testTransactingConnectionShouldNotBeRelease),
        ]
    }
}
