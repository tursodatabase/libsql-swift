
import Foundation
import Libsql

let db = try Database(":memory:")
let conn = try db.connect()

_ = try conn.executeBatch("""
    create table users(id integer primary key autoincrement, name text);
    insert into users (name) values ('Iku Turso');
""")

let forenames = ["John", "Mary", "Alice", "Mark"]
let surnames = ["Doe", "Smith", "Jones", "Taylor"]

for forename in forenames {
    for surname in surnames {
        _ = try conn.execute(
            "insert into users (name) values (?)",
            ["\(forename) \(surname)"]
        );
    }
}

for row in try conn.query("select * from users", [1]) {
    print(try row.getInt(0), try row.getString(1))
}

