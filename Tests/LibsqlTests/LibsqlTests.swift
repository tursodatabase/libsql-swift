import Foundation
import XCTest

@testable import Libsql

final class LibsqlTests: XCTestCase {
    func testOpenDbMemory() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
    }
    
    func testOpenDbFile() throws {
        let db = try Database("test.db")
        let conn = try db.connect()
    }

    func testExecute() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        try conn.execute("create table test (i integer, s text)")
        try conn.execute("insert into test values (?, ?)", 1, "lorem ipsum")
    }

    func testQuerySimple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        XCTAssertEqual(try conn.query("select 1").next()!.getInt(0), 1)
        XCTAssertEqual(try conn.query("select ?", 1).next()!.getInt(0), 1)
    }

    func testStatement() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        let stmt = try conn.prepare("select ?")
        try stmt.bind(1)
        XCTAssertEqual(try stmt.query().next()!.getInt(0), 1)
    }

    func testQueryMultiple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        try conn.execute("create table test (i integer, t text, r real, b blob)")

        let range = 0...255

        for i in range {
            try conn.execute(
                "insert into test values (?, ?, ?, ?)", i, "\(i)", exp(Double(i)), Data([UInt8(i)]))
        }

        for (i, row) in zip(range, try conn.query("select * from test")) {
            XCTAssertEqual(try row.getInt(0), i)
            XCTAssertEqual(try row.getString(1), "\(i)")
            XCTAssertEqual(try row.getDouble(2), exp(Double(i)))
            XCTAssertEqual(try row.getData(3), Data([UInt8(i)]))
        }
    }
}
