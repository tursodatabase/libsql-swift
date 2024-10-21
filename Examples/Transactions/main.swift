import Foundation
import Libsql

let db = try Database(":memory:")
let conn = try db.connect()

_ = try conn.executeBatch("""
    create table users(id integer primary key autoincrement, name text);
    insert into users (name) values ('First Iku Turso');
""")

let tx = try conn.transaction();

let fullNames = ["John Doe", "Mary Smith", "Alice Jones", "Mark Taylor"]

for fullName in fullNames {
    _ = try tx.execute(
        "insert into users (name) values (?)",
        [fullName]
    );
}

tx.rollback() // Discards all inserts

_ = try conn.execute("insert into users (name) values (?)", ["Second Iku Turso"])

// Only returns "1 Iku turso", since the transaction was rollbacked.
for row in try conn.query("select * from users", [1]) {
    print(try row.getInt(0), try row.getString(1))
}
