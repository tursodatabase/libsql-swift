import CLibsql
import Foundation

enum Value {
    case integer(Int64)
    case text(String)
    case blob(Data)
    case real(Double)
}

protocol ValueRepresentable {
    func toValue() -> Value
}

extension Int: ValueRepresentable {
    func toValue() -> Value { .integer(Int64(self)) }
}

extension Int64: ValueRepresentable {
    func toValue() -> Value { .integer(self) }
}

extension String: ValueRepresentable {
    func toValue() -> Value { .text(self) }
}

extension Data: ValueRepresentable {
    func toValue() -> Value { .blob(self) }
}

extension Double: ValueRepresentable {
    func toValue() -> Value { .real(self) }
}

enum LibsqlError: Error {
    case runtimeError(String)
    case unexpectedType
}

class Row {
    var inner: libsql_row_t

    fileprivate init?(fromPtr inner: libsql_row_t?) {
        guard let inner = inner else {
            return nil
        }

        self.inner = inner
    }

    func getData(_ index: Int32) throws -> Data {
        var slice: blob = blob()

        var err: UnsafePointer<CChar>?
        if libsql_get_blob(self.inner, index, &slice, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return Data(bytes: slice.ptr, count: Int(slice.len))
    }

    func getDouble(_ index: Int32) throws -> Double {
        var double: Double = 0

        var err: UnsafePointer<CChar>?
        if libsql_get_float(self.inner, index, &double, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return double
    }

    func getString(_ index: Int32) throws -> String {
        var string: UnsafePointer<CChar>? = nil

        var err: UnsafePointer<CChar>?
        if libsql_get_string(self.inner, index, &string, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return String(cString: string!)
    }

    func getInt(_ index: Int32) throws -> Int {
        var integer: Int64 = 0

        var err: UnsafePointer<CChar>?
        if libsql_get_int(self.inner, index, &integer, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }
        return Int(integer)
    }
}

class Rows {
    var inner: libsql_rows_t

    fileprivate init(fromPtr inner: libsql_rows_t) {
        self.inner = inner
    }

    deinit {
        libsql_free_rows(self.inner)
    }

    func next() throws -> Row? {
        var row: libsql_row_t?

        var err: UnsafePointer<CChar>?
        if libsql_next_row(self.inner, &row, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return Row(fromPtr: row)

    }
}

class Connection {
    var inner: libsql_connection_t

    deinit {
        libsql_disconnect(self.inner)
    }

    fileprivate init(fromPtr inner: libsql_connection_t) {
        self.inner = inner
    }

    func query(_ sql: String) throws -> Rows {
        var rows: libsql_rows_t? = nil
        try sql.withCString { sql in
            var err: UnsafePointer<CChar>? = nil
            if libsql_query(self.inner, sql, &rows, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }

        return Rows(fromPtr: rows!)
    }

    func execute(_ sql: String) throws {
        try sql.withCString { sql in
            var err: UnsafePointer<CChar>? = nil
            if libsql_execute(self.inner, sql, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }
    }

    func execute(_ sql: String, _ params: ValueRepresentable...) throws {
        var stmt: libsql_stmt_t? = nil

        try sql.withCString { sql in
            var err: UnsafePointer<CChar>? = nil
            if libsql_prepare(self.inner, sql, &stmt, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }

        for (i, v) in params.enumerated() {
            let i = Int32(i + 1)

            switch v.toValue() {
            case .integer(let integer):
                var err: UnsafePointer<CChar>? = nil
                if libsql_bind_int(stmt, i, integer, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            case .text(let text):
                try text.withCString { text in
                    var err: UnsafePointer<CChar>? = nil
                    if libsql_bind_string(stmt, i, text, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                }
            case .blob(let blob):
                try blob.withUnsafeBytes { blob in
                    let blob = blob.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    var err: UnsafePointer<CChar>? = nil
                    if libsql_bind_string(stmt, i, blob, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                }
            case .real(let real):
                var err: UnsafePointer<CChar>? = nil
                if libsql_bind_float(stmt, i, real, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            }
        }

    }
}

class Database {
    var inner: libsql_database_t

    deinit {
        libsql_close(self.inner)
    }

    func connect() throws -> Connection {
        var conn: libsql_connection_t? = nil
        var err: UnsafePointer<CChar>? = nil

        if libsql_connect(self.inner, &conn, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return Connection(fromPtr: conn!)
    }

    init(_ path: String) throws {
        var db: libsql_database_t? = nil
        var err: UnsafePointer<CChar>? = nil

        try path.withCString { path in
            if libsql_open_ext(path, &db, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }

        self.inner = db!
    }

    init(url: String, authToken: String) throws {
        var db: libsql_database_t? = nil
        var err: UnsafePointer<CChar>? = nil

        try url.withCString { url in
            try authToken.withCString { authToken in
                if libsql_open_remote(url, authToken, &db, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            }
        }

        self.inner = db!
    }
}
