import XCTest
@testable import SwiftMysqlTests

XCTMain([
    testCase(ConnectionTests.allTests),
    testCase(TransactionTests.allTests),
    testCase(ConnectionPoolTests.allTests),
    testCase(SelectTests.allTests),
    testCase(PreparedStatementTests.allTests),
    testCase(AsyncConnectionPoolTests.allTests),
    testCase(AsyncConnectionTests.allTests),
    testCase(AsyncSelectTests.allTests),
    testCase(AsyncTransactionTests.allTests),
    testCase(AsyncWriteTests.allTests)
])
