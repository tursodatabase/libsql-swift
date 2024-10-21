import Libsql
import Foundation

let db = try Database(
    path: "./local.db",
    url: ProcessInfo.processInfo.environment["TURSO_DATABASE_URL"] ?? "",
    authToken: ProcessInfo.processInfo.environment["TURSO_AUTH_TOKEN"] ?? "",
    syncInterval: 1000

)
let conn = try db.connect()

_ = try conn.executeBatch("""
  DROP TABLE IF EXISTS users;
  CREATE TABLE users (id INTEGER PRIMARY KEY, email TEXT);
  INSERT INTO users VALUES (1, 'first@example.com');
  INSERT INTO users VALUES (2, 'second@example.com');
  INSERT INTO users VALUES (3, 'third@example.com');

""")

for row in try conn.query("select * from users", [1]) {
    print(try row.getInt(0), try row.getString(1))
}
