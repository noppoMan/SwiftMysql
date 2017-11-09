import XCTest
@testable import SwiftMysql
import Foundation
import Dispatch

class AsyncConnectionPoolTests: XCTestCase {

    func testMinPool() throws {
        let exp = expectation(description: #function)
        
        let pool = try newAsyncPoolingConnection()
        pool.onReady {
            XCTAssertFalse(pool.isClosed)
            XCTAssertEqual(pool.availableConnectionCount, 2)
            XCTAssertEqual(pool.activeConnectionCount, 2)
            pool.close()
            XCTAssertEqual(pool.availableConnectionCount, 0)
            XCTAssertEqual(pool.activeConnectionCount, 0)
            XCTAssertTrue(pool.isClosed)
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    func testMaxPool() throws {
        let exp = expectation(description: #function)
        
        let pool = try newAsyncPoolingConnection()
        
        var connectionCount = 0
        
        
        func checkConnectionCountEqualsMaxPoolSize(_ connectionCount: Int) {
            DispatchQueue.global().async {
                sleep(1)
                XCTAssertEqual(pool.activeConnectionCount, 5)
                XCTAssertEqual(pool.availableConnectionCount, 0)
                pool.close()
                exp.fulfill()
            }
        }
        
        pool.onNewConnectionIsReady {
            connectionCount+=1
            if connectionCount > pool.maxPoolSize {
                XCTFail("Number of Pooling connections exceeds the maxPoolSize")
            }
            if connectionCount == pool.maxPoolSize {
                checkConnectionCountEqualsMaxPoolSize(connectionCount)
            }
        }
        
        var i = 0
        for _ in 0..<10 {
            pool.getConnection { error, _ in
                defer {
                    i+=1
                }
                XCTAssertLessThan(i, Int(pool.maxPoolSize))
                if let error = error {
                    XCTFail("\(error)")
                }
            }
        }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testConnectionCounts() throws {
        let exp = expectation(description: #function)

        let pool = try newAsyncPoolingConnection()

        pool.query("show tables like 'user'") { res in
            XCTAssertEqual(pool.availableConnectionCount, 1, "Now using a connection")
            DispatchQueue.global().async {
                sleep(1)
                XCTAssertEqual(pool.availableConnectionCount, 2, "The connection is released")
                exp.fulfill()
            }
        }

        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testTransactingConnectionShouldNotBeRelease() throws {
        let exp = expectation(description: #function)
        
        let pool = try newAsyncPoolingConnection()
        
        XCTAssertEqual(pool.availableConnectionCount, 2)
        
        pool.transaction { error, con in
            XCTAssertNil(error)
            XCTAssertNotNil(con)
            XCTAssertEqual(pool.availableConnectionCount, 1)
            XCTAssertTrue(con!.isTransacting)
            
            con?.query("select 1 + 1") { _ in
                XCTAssertTrue(con!.isUsed)
                XCTAssertTrue(con!.isTransacting)
                XCTAssertEqual(pool.availableConnectionCount, 1)
                
                con?.query("select 1 + 2") { _ in
                    XCTAssertTrue(con!.isUsed)
                    XCTAssertTrue(con!.isTransacting)
                    XCTAssertEqual(pool.availableConnectionCount, 1)
                    
                    con?.query("select 1 + 3") { _ in
                        XCTAssertTrue(con!.isUsed)
                        XCTAssertTrue(con!.isTransacting)
                        XCTAssertEqual(pool.availableConnectionCount, 1)
                        
                        con!.commit { _ in
                            XCTAssertFalse(con!.isTransacting)
                            XCTAssertFalse(con!.isUsed)
                            XCTAssertEqual(pool.availableConnectionCount, 2)
                            
                            exp.fulfill()
                        }
                    }
                }
            }
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests : [(String, (AsyncConnectionPoolTests) -> () throws -> Void)] {
        return [
            ("testMinPool", testMinPool),
            ("testMaxPool", testMaxPool),
            ("testConnectionCounts", testConnectionCounts),
            ("testTransactingConnectionShouldNotBeRelease", testTransactingConnectionShouldNotBeRelease)
        ]
    }
}

