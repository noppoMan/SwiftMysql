import XCTest
@testable import SwiftMysql
import Foundation

class TransactionTests: XCTestCase {
    static var allTests : [(String, (TransactionTests) -> () throws -> Void)] {
        return [
            ("testTransactionCommit", testTransactionCommit),
            ("testTransactionRollback", testTransactionRollback)
        ]
    }
    
    override func setUp() {
        signal(EINTR) { _ in }
        try! prepareTestDataSeed()
    }
    
    override func tearDown() {
        cleanTestTables()
    }
    
    func testTransactionCommit(){
        do {
            let con = try newConnection(withDatabase: testDatabaseName)
            defer {
                try? con.close()
            }
            _ = try con.transaction { con in
                let res = try con.query("""
                    INSERT INTO \(userTableName)(name, email)
                        VALUES
                        ("Jack", "jack@example.com");
                    """)
                XCTAssertEqual(res.asQueryStatus()?.insertId, 201)
            }
            
            let result = try con.query("select * from \(userTableName)")
            XCTAssertEqual(result.asRows()?.count, 201)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testTransactionRollback() {
        let con = try? newConnection(withDatabase: testDatabaseName)
        
        do {
            _ = try con?.transaction { con in
                try _ = con.query("""
                    INSERT INTO \(userTableName)(name, email)
                    VALUES
                    ("Test User", "test@example.com");
                    """)
                
                try _ = con.query("""
                    INSERT INTO \(userTableName)(id, name, email)
                    VALUES
                    (201, "Test User", "test@example.com");
                    """)
            }
            
        } catch MysqlServerError.error(let code, _){
            defer {
                try? con?.close()
            }
            XCTAssertEqual(code, 1062) // duplicate entry
            let result = try? con?.query("select * from \(userTableName)")
            
            // check rollback is worked
            XCTAssertEqual(result??.asRows()?.count, 200)
        } catch {
            XCTFail("\(error)")
        }
    }
}
