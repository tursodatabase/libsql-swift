
import Foundation
import Libsql

let db = try Libsql.Database(":memory:")
let conn = try db.connect()

_ = try conn.execute("create table users(id integer primary key autoincrement, name text)")

let forenames = ["John", "Mary", "Alice", "Mark"]
let surnames = ["Doe", "Smith", "Jones", "Taylor"]

for forename in forenames {
    for surname in surnames {
        _ = try conn.execute(
            "insert into users (name) values (?)",
            ["\(forename) \(surname)"
        ]);
    }
}

for row in try conn.query("select * from users", [1]) {
    print(try row.getInt(0), try row.getString(1))
}

