import XCTest
@testable import SwiftMysql
import Foundation

class AsyncConnectionTests: XCTestCase {
    func testConnection() {
        let exp = expectation(description: "testConnection")
        
        let con = try! AsyncConnection(url: mysqlURL, user: "root")
        con.onConnect {
            XCTAssertTrue(con.isConnected)
            XCTAssertFalse(con.isClosed)
            con.close() // close connection
            XCTAssertTrue(con.isClosed)
            XCTAssertFalse(con.isConnected)
            exp.fulfill()
        }
        
        con.onError { error in
            XCTFail("\(error)")
        }
        
        waitForExpectations(timeout: 2, handler: nil)
    }
    
    static var allTests : [(String, (AsyncConnectionTests) -> () throws -> Void)] {
        return [
            ("testConnection", testConnection)
        ]
    }
}
