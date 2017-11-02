//
//  Support.swift
//  SwiftMysqlPackageDescription
//
//  Created by Yuki Takei on 2017/11/06.
//

import Foundation
@testable import SwiftMysql

let testDatabaseName = "swift_mysql_test"
let userTableName = "`\(testDatabaseName)`.`users`"
let accessTokenTableName = "`\(testDatabaseName)`.`acces_tokens`"
let mysqlURL = URL(string: "mysql://localhost:3306")!

func cleanTestTables() {
    let con = try? Connection(url: mysqlURL, user: "root")
    _ = try? con?.query("DROP TABLE \(userTableName)")
    try? con?.close()
}

func createUserTable() throws {
    let con = try Connection(url: mysqlURL, user: "root")
    _ = try? con.query("DROP TABLE \(userTableName)")
    _ = try con.query("""
        CREATE TABLE \(userTableName) (
            `id` int not null auto_increment,
            `name` varchar(255) not null,
            `email` varchar(255) not null,
            PRIMARY KEY(`id`)
        )  ENGINE=InnoDB DEFAULT CHARSET=utf8
        """)
    try con.close()
}

func createAccessTokenTable() throws {
    let con = try Connection(url: mysqlURL, user: "root")
    _ = try? con.query("DROP TABLE \(accessTokenTableName);")
    _ = try con.query("""
        CREATE TABLE \(accessTokenTableName) (
        `id` int not null auto_increment,
        `user_id` int not null,
        `token` varchar(255) not null,
        PRIMARY KEY(`id`)
        )  ENGINE=InnoDB DEFAULT CHARSET=utf8;
        """)
    _ = try con.query("ALTER TABLE \(accessTokenTableName) ADD UNIQUE INDEX (token), ADD UNIQUE INDEX (user_id);")
    try con.close()
}


func newConnection(withDatabase db: String? = nil) throws -> Connection {
    return try Connection(
        url: mysqlURL,
        user: "root",
        password: nil,
        database: db
    )
}

func prepareTestDataSeed() throws {
    try createUserTable()
    try createAccessTokenTable()
    
    var userValues: [String] = []
    
    let numOfRecords = 200
    
    for i in 0..<numOfRecords {
        let value = """
        ("Test User\(i+1)", "test\(i+1)@example.com")
        """
        userValues.append(value)
    }
    
    var tokenValues: [String] = []
    
    for i in 0..<numOfRecords {
        let value = """
        (\(i+1), "accesstoken\(i+1)")
        """
        tokenValues.append(value)
    }
    
    let con = try Connection(url: mysqlURL, user: "root", password: nil)
    try con.transaction { con in
        let result = try con.query("""
            INSERT INTO \(userTableName)(name, email)
            VALUES
            \(userValues.joined(separator: ","));
            """)
        assert(result.asQueryStatus()?.affectedRows == UInt64(numOfRecords))
        
        let result2 = try con.query("""
            INSERT INTO \(accessTokenTableName)(user_id, token)
            VALUES
            \(tokenValues.joined(separator: ","));
            """)
        assert(result2.asQueryStatus()?.affectedRows == UInt64(numOfRecords))
    }
}

