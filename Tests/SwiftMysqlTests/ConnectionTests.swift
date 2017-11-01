import XCTest
@testable import SwiftMysql
import Foundation

class ConnectionTests: XCTestCase {
    
    func testConnection() {
        let url = URL(string: "mysql://localhost:3306")
        let con = try! Connection(url: url!, user: "root", password: nil)
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
