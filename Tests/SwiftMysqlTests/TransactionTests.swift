import XCTest
@testable import SwiftMysql
import Foundation

class TransactionTests: XCTestCase {
    
    var tableName = "`swift_mysql_test`.`users`"
    
    static var allTests : [(String, (TransactionTests) -> () throws -> Void)] {
        return [
            ("testTransactionCommit", testTransactionCommit),
            ("testTransactionRollback", testTransactionRollback)
        ]
    }
    
    override func setUp() {
        signal(EINTR) { _ in }
        do {
            let con = try Connection(url: URL(string: "mysql://localhost:3306")!, user: "root")
            _ = try? con.query("DROP TABLE \(tableName)")
            _ = try con.query("""
            CREATE TABLE \(tableName) (
                `id` int not null auto_increment,
                `name` varchar(255) not null,
                `email` varchar(255) not null,
                PRIMARY KEY(`id`)
            )  ENGINE=InnoDB DEFAULT CHARSET=utf8
            """)
            try con.close()
        } catch {
            XCTFail("\(error)")
        }
    }
    
    override func tearDown() {
        let con = try? Connection(url: URL(string: "mysql://localhost:3306")!, user: "root")
        _ = try? con?.query("DROP TABLE \(tableName)")
        try? con?.close()
    }
    
    func testTransactionCommit(){
        do {
            let con = try Connection(url: URL(string: "mysql://localhost:3306")!, user: "root")
            defer {
                try? con.close()
            }
            _ = try con.transaction { con in
                try _ = con.query("""
                    INSERT INTO \(tableName)(name, email)
                        VALUES
                        ("Test User", "test@example.com");
                    """)
            }
            
            let result = try con.query("select * from \(tableName)")
            XCTAssertEqual(result.asResultSet()?.count, 1)
        } catch {
            XCTFail("\(error)")
        }
    }
    
    func testTransactionRollback() {
        let con = try? Connection(url: URL(string: "mysql://localhost:3306")!, user: "root")
        
        do {
            defer {
                try? con?.close()
            }
            _ = try con?.transaction { con in
                try _ = con.query("""
                    INSERT INTO \(tableName)(name, email)
                    VALUES
                    ("Test User", "test@example.com");
                    """)
                
                try _ = con.query("""
                    INSERT INTO \(tableName)(id, name, email)
                    VALUES
                    (1, "Test User", "test@example.com");
                    """)
            }
            
        } catch MySQLError.rawError(let code, _){
            XCTAssertEqual(code, 1062) // duplicate entry
            let result = try? con?.query("select * from \(tableName)")
            XCTAssertEqual(result??.asResultSet()?.count, nil)
        } catch {
            XCTFail("\(error)")
        }
    }
}
