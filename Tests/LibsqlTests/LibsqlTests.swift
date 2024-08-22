import XCTest

@testable import Libsql

final class LibsqlTests: XCTestCase {
    func testOpenDb() throws {
        _ = try Database(":memory:")
    }

    func testExecute() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        try conn.execute("create table test (data integer)")
    }

    func testQuery() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        print(try conn.query("select 1").next()!.getInt(0))
    }

    func testExecuteParams() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        try conn.execute("create table test (data integer)")
        try conn.execute("insert into test values (?)", 1)
        try conn.execute("insert into test values (?)", 2)
        try conn.execute("insert into test values (?)", 3)
    }
}
