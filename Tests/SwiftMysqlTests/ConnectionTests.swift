import XCTest
@testable import SwiftMysql
import Foundation

class ConnectionTests: XCTestCase {
    
    func testConnection() {
        let con = try! Connection(url: mysqlURL, user: "root", password: nil)
        XCTAssertFalse(con.isClosed)
        try! con.close()
        XCTAssertTrue(con.isClosed)
    }
    
    static var allTests : [(String, (ConnectionTests) -> () throws -> Void)] {
        return [
            ("testConnection", testConnection),
        ]
    }
}
