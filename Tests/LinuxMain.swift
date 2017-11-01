import XCTest
@testable import SwiftMysqlTests

XCTMain([
    testCase(ConnectionTests.allTests),
    testCase(TransactionTests.allTests),
    testCase(ConnectionPoolTests.allTests)
])
