# SwiftMysql

A pure Swift Client implementing the MySql protocol. this is not depend on libmysql.

## Features

* [x] Thread safe
* [x] Pooling connections
* [x] Prepared statements
* [x] Transactions
* [x] JSON Data Type in Mysql 5.7
* [x] Streaming query rows
* [ ] NonBlocking I/O

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

## License
SwiftMysql is released under the MIT license. See LICENSE for details.
