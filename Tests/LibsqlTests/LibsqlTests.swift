import XCTest

@testable import Libsql

final class LibsqlTests: XCTestCase {
  func testOpenDb() throws {
    let db = try Database(path: ":memory:")
    print("test")
  }
  
  func testOpenDbFail() throws {
    let db = try Database(path: ":memory")
    assert(db == nil)
    print(db?.inner)
    print("test")
  }
}
