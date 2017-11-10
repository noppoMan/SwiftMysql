# SwiftMysql

[![Build Status](https://travis-ci.org/noppoMan/SwiftMysql.svg?branch=master)](https://travis-ci.org/noppoMan/SwiftMysql)

A pure Swift Client implementing the MySQL protocol. this is not depend on libmysql.

## Features

* [x] Thread safe
* [x] Pooling connections
* [x] Prepared statements
* [x] Transactions
* [x] JSON Data Type in MySQL 5.7
* [x] Streaming query rows
* [x] Non-Blocking Querying

## Instllation

```swift
let package = Package(
    name: "MyApp",
    dependencies: [
        .package(url: "https://github.com/noppoMan/SwiftMysql.git", .upToNextMajor(from: "0.1.0"))
    ],
)
```

## Basic querying

```swift
let url = URL(string: "mysql://localhost:3306")
let con = try Connection(url: url!, user: "root", password: "password", database: "swift_mysql")

let result = try con.query("selct * from users")
if let rows = result.asRows() {
    for row in rows {
      print(row) // ["id": 1, "name": "Luke", "email": "test@example.com"]
    }
}
```

## Prepared statements

You can easy to use prepared statement as following.

```swift
let url = URL(string: "mysql://localhost:3306")
let con = try Connection(url: url!, user: "root", password: "password", database: "swift_mysql")

let result = try con.query("selct * from books where published_at > ? and category_id = ?", [2017, 3])
if let rows = result.asRows() {
    for row in rs {
      print(row)
    }
}
```


## Pooling connections

Rather than creating and managing connections one-by-one, this module also provides built-in connection pooling using `ConnectionPool(url:user:database:minPoolSize:maxPoolSize)`

```swift
let pool = try ConnectionPool(
    url: URL(string: "mysql://localhost:3306")!,
    user: "root",
    database: "swift_mysql",
    minPoolSize: 3,
    maxPoolSize: 10
)

try pool.query("select * from users") // the connection is released after finishing query.
```

### failedToGetConnectionFromPool Error

`failedToGetConnectionFromPool` will be thrown when the number of connections that are used in internally reaches `maxPoolSize`, and then `query` is called. But It's recoverable, all developers can retry to perform `query` as like following.

```swift
do {
    try pool.query("select * from users")
} catch ConnectionPoolError.failedToGetConnectionFromPool {
    // may need to wait a moment...

    // try again.
    try pool.query("select * from users")
}
```

## Transactions

Simple transaction support is available at the connection level

### Commit

If the program that in transaction block is finished without throwing error, transaction should be committed automatically.

```swift
try con.transaction {
    $0.query("insert into users (name, email), value (\"Foo\", \"foo@example.com\")")
}
```

### Rollback

if the error is thrown in transaction block, `rollback` should be performed.

```swift
try con.transaction {
    throw FooError
}
```

## Streaming query rows

Sometimes you may want to select large quantities of rows and process each of them as they are received. This can be done like this

```swift
let result = try con.query("selct * from large_tables")
if let resultFetcher = result.asResultSet() {
    print(resultFetcher.columns) // [String]

    // resultFetcher.rows is a infinity Sequence
    // you can loop it until the Mysql sends EOF packet.
    for row in resultFetcher.rows {
        print(row)
    }
}
```

## Terminating connections

once call `close` method, the Mysql connection is terminated safely.

```swift
try con.close()
```

# Non-Blocking Querying

SwiftMysql supports Non-Blocking querying with `AsyncConnection`. Non-Blocking means event-driven non-blocking I/O using OS native asynchronous system calls (epoll/kqueue). It doesn't concurrent execution by worker threads.

Currently all of non-blocking features are **not thread safe**. So you should use them on the single thread.

## Non-Blocking Querying with AsyncConnection

You can asynchronously connect to the mysql with `AsyncConnection(url:user:password:database:queue)`,

Once call initializer of `AsyncConnection`, connection is automatically opened on a specified thread(queue). Then, all of your operations(query) are queued and processed in order.
The thread will create event loop on the own thread to observe the file descriptor of the connection.

```swift
import Foundation
import SwiftMysql

let url = URL(string: "mysql://localhost:3306")!
let con = try SwiftMysql.AsyncConnection(
    url: url,
    user: "root",
    password: nil,
    database: "swift_mysql"
)

con.onConnect {
    print("connected to \(url)")
}

con.onError { error in
    print("Error: \(error)")
}

con.query("select * from users where id = 1") { result in
    if let error = result.asError() {
        print(error)
        return
    }

    result.asRows {
        print($0) // [["id": 1, "name": "Jack....]]
    }
}

con.query("select * from users where id = 2") { result in
    if let error = result.asError() {
        print(error)
        return
    }

    result.asRows {
        print($0) // [["id": 2, "name": "Tonny....]]
    }
}

RunLoop.main.run()
```

### Event Loop Thread

If you didn't care the thread for running event loop, it's automatically determined by `DispatchQueue(attributes: .serial)` internally.

Or you can provide it by `queue` label of initializer like following.

```swift
let url = URL(string: "mysql://localhost:3306")!
let con = try SwiftMysql.AsyncConnection(
    url: url,
    user: "root",
    password: nil,
    database: "swift_mysql",
    queue: DispatchQueue.main
)

con.connect {
    print(Thread.current == Thread.main) // true
}

con.query("...") { _ in
    print(Thread.current == Thread.main) // true
}
```

### Event Driven Query rows and fields

You can improve memory efficiency for fetching records to use `ResultSetEvent`.

`ResultSetEvent` provides two methods to fetch fields and rows streamly.

* `onFields`: onFields is called when the all fields packets are received.
* `onRow`: onRow is called when the per row packets are received.

```swift
con.query("select * from users limit ?", bindParams: [100]) { result in
    let rs = result.asResultSet() // get ResultSetEvent

    rs.onFields { fields in
        print(fields) // ["id", "name", "age"...]
    }

    event.onRow { row in
        print(row) // [[1, "Jack", 35...]]
    }
}
```


## Pooling connections
Also you can use pooling connections for non-blocking querying with `AsyncConnectionPool`. The usage is roughly same as sync version. The number of connections using at the same time are reached `maxPoolSize`, the next query queue should wait for a connection is available.

```swift
let pool = try AsyncConnectionPool(
    url: url,
    user: "root",
    database: "swift_mysql",
    minPoolSize: 2,
    maxPoolSize: 10
)

pool.onReady {
    print("The initial connections are ready")
}

pool.onNewConnectionIsReady {
    print("new Connection is ready")
}

// Uses a existing connection
pool.query("select * from users where id = ?", bindParams: [1]) { result in
    result.asRows()
    // connection will be released automatically,
    // when the all of packets of this query are received.
}

// Uses a existing connection
pool.query("select * from users where id = ?", bindParams: [2]) { result in
    result.asRows()
}

// May create a new connection asynchronously.
// Depends on the timing of first query finished.
pool.query("select * from users where id = ?", bindParams: [3]) { result in
    result.asRows()
}
```

## Transactions

```swift
pool.transaction { error, con in
    con?.query("insert into ....") { result in
        if let error = result.asError() {
            con?.rollback { _ in
                done(error)
            }
            return
        }

        con?.query("update users set name = ....") { result in
          if let error = result.asError() {
              con?.rollback { _ in
                  done(error)
              }
              return
          }

          con?.commit { _ in
              done(nil)
          }
        }
    }
}
```


## License
SwiftMysql is released under the MIT license. See LICENSE for details.
