import Foundation
import XCTest

@testable import Libsql

final class LibsqlTests: XCTestCase {
    func testOpenDbMemory() throws {
        let db = try Database(":memory:")
        let _ = try db.connect()
    }
    
    func testOpenDbFile() throws {
        let db = try Database("test.db")
        let _ = try db.connect()
    }

    func testExecute() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        _ = try conn.execute("create table test (i integer, s text)")
        _ = try conn.execute("insert into test values (?, ?)", [1, "lorem ipsum"])
        let row = try conn.query("select * from test").next()!;

        XCTAssertEqual(try row.getInt(0), 1)
        XCTAssertEqual(try row.getString(1), "lorem ipsum")
    }

    func testExecuteBatch() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        _ = try conn.executeBatch("""
            create table test (i integer, s text);
            insert into test values (1, \"lorem ipsum\");
        """)
        let row = try conn.query("select * from test").next()!;

        XCTAssertEqual(try row.getInt(0), 1)
        XCTAssertEqual(try row.getString(1), "lorem ipsum")
    }

    func testQuerySimple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        XCTAssertEqual(try conn.query("select 1").next()!.getInt(0), 1)
        XCTAssertEqual(try conn.query("select :named", [":named": 1]).next()!.getInt(0), 1)
        XCTAssertEqual(try conn.query("select ?", [1]).next()!.getInt(0), 1)
    }

    func testStatement() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        let stmt = try conn.prepare("select ?").bind([1])
        XCTAssertEqual(try stmt.query().next()!.getInt(0), 1)
    }
    
    func testTransaction() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        
        do {
            let tx = try conn.transaction()
            defer { tx.commit() }
            
            _ = try tx.execute("create table test (i integer)")
            _ = try tx.execute("insert into test values (:v)", [ ":v": 1 ])
        }
        
        XCTAssertEqual(try conn.query("select * from test").next()!.getInt(0), 1)
    }
    
    func testTransactionRollback() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()
        
        _ = try conn.execute("create table test (i integer)")
        
        do {
            let tx = try conn.transaction()
            defer { tx.rollback() }
            
            _ = try tx.execute("insert into test values (:v)", [ ":v": 1 ])
        }
        
        XCTAssert(try conn.query("select * from test").next() == nil)
    }

    func testQueryMultiple() throws {
        let db = try Database(":memory:")
        let conn = try db.connect()

        _ = try conn.execute("create table test (i integer, t text, r real, b blob)")

        let range = 0...255

        for i in range {
            _ = try conn.execute(
                "insert into test values (?, ?, ?, ?)",
                [ i, "\(i)", exp(Double(i)), Data([UInt8(i)]) ]
            )
        }

        for (i, row) in zip(range, try conn.query("select * from test")) {
            XCTAssertEqual(try row.getInt(0), i)
            XCTAssertEqual(try row.getString(1), "\(i)")
            XCTAssertEqual(try row.getDouble(2), exp(Double(i)))
            XCTAssertEqual(try row.getData(3), Data([UInt8(i)]))
        }
    }
}
