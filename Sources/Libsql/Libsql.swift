import CLibsql
import Foundation

enum Value {
    case integer(Int64)
    case text(String)
    case blob(Data)
    case real(Double)
    case null
}

protocol ValueRepresentable {
    func toValue() -> Value
}

extension Value: ValueRepresentable {
    func toValue() -> Value { self }
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

extension String? {
    func withCString<Result>(_ body: (UnsafePointer<Int8>?) throws -> Result) rethrows -> Result {
        if self == nil {
            return try body(nil)
        } else {
            return try self!.withCString(body)
        }
    }
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

        defer { libsql_free_blob(slice) }

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

        defer { libsql_free_string(string) }

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

class Rows: Sequence, IteratorProtocol {
    var inner: libsql_rows_t

    fileprivate init(fromPtr inner: libsql_rows_t) {
        self.inner = inner
    }

    deinit {
        libsql_free_rows(self.inner)
    }

    func next() -> Row? {
        var row: libsql_row_t?

        var err: UnsafePointer<CChar>?
        guard libsql_next_row(self.inner, &row, &err) == 0 else {
            defer { libsql_free_string(err) }
            fatalError(String(cString: err!))
        }

        return Row(fromPtr: row)
    }
}

class Statement {
    var inner: libsql_stmt_t

    deinit {
        libsql_free_stmt(self.inner)
    }

    fileprivate init(fromPtr inner: libsql_stmt_t) {
        self.inner = inner
    }

    func execute() throws {
        var err: UnsafePointer<CChar>? = nil
        if libsql_execute_stmt(self.inner, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }
    }

    func execute(_ params: [ValueRepresentable]) throws {
        try self.bind(params)
        return try self.execute()
    }

    func execute(_ params: ValueRepresentable...) throws {
        try self.bind(params)
        return try self.execute()
    }

    func query() throws -> Rows {
        var rows: libsql_rows_t? = nil

        var err: UnsafePointer<CChar>? = nil
        if libsql_query_stmt(self.inner, &rows, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }

        return Rows(fromPtr: rows!)
    }

    func query(_ params: [ValueRepresentable]) throws -> Rows {
        try self.bind(params)
        return try self.query()
    }

    func query(_ params: ValueRepresentable...) throws -> Rows {
        try self.bind(params)
        return try self.query()
    }

    func bind(_ params: ValueRepresentable...) throws {
        return try self.bind(params)
    }

    func bind(_ params: [ValueRepresentable]) throws {
        for (i, v) in params.enumerated() {
            let i = Int32(i + 1)

            switch v.toValue() {
            case .integer(let integer):
                var err: UnsafePointer<CChar>? = nil
                if libsql_bind_int(self.inner, i, integer, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            case .text(let text):
                try text.withCString { text in
                    var err: UnsafePointer<CChar>? = nil
                    if libsql_bind_string(self.inner, i, text, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                }
            case .blob(let slice):
                try slice.withUnsafeBytes { slice in
                    let base = slice.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    let len = Int32(slice.count)

                    var err: UnsafePointer<CChar>? = nil
                    if libsql_bind_blob(self.inner, i, base, len, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                }
            case .real(let real):
                var err: UnsafePointer<CChar>? = nil
                if libsql_bind_float(self.inner, i, real, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            case .null:
                var err: UnsafePointer<CChar>? = nil
                if libsql_bind_null(self.inner, i, &err) != 0 {
                    defer { libsql_free_string(err) }
                    throw LibsqlError.runtimeError(String(cString: err!))
                }
            }
        }
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

    func query(_ sql: String, _ params: [ValueRepresentable]) throws -> Rows {
        let stmt = try self.prepare(sql)
        return try stmt.query(params)
    }

    func query(_ sql: String, _ params: ValueRepresentable...) throws -> Rows {
        return try self.query(sql, params as [ValueRepresentable])
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

    func execute(_ sql: String, _ params: [ValueRepresentable]) throws {
        let stmt = try self.prepare(sql)
        return try stmt.execute(params)
    }

    func execute(_ sql: String, _ params: ValueRepresentable...) throws {
        return try self.execute(sql, params as [ValueRepresentable])
    }

    func prepare(_ sql: String) throws -> Statement {
        var stmt: libsql_stmt_t? = nil

        try sql.withCString { sql in
            var err: UnsafePointer<CChar>? = nil
            if libsql_prepare(self.inner, sql, &stmt, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }

        return Statement(fromPtr: stmt!)
    }
}

class Database {
    var inner: libsql_database_t

    deinit {
        libsql_close(self.inner)
    }

    func sync() throws {
        var err: UnsafePointer<CChar>? = nil
        if libsql_sync(self.inner, &err) != 0 {
            defer { libsql_free_string(err) }
            throw LibsqlError.runtimeError(String(cString: err!))
        }
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

        try path.withCString { path in
            var err: UnsafePointer<CChar>? = nil
            if libsql_open_ext(path, &db, &err) != 0 {
                defer { libsql_free_string(err) }
                throw LibsqlError.runtimeError(String(cString: err!))
            }
        }

        self.inner = db!
    }

    init(url: String, authToken: String, withWebpki: Bool = false) throws {
        var db: libsql_database_t? = nil

        try url.withCString { url in
            try authToken.withCString { authToken in
                if withWebpki {
                    var err: UnsafePointer<CChar>? = nil
                    if libsql_open_remote(url, authToken, &db, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                } else {
                    var err: UnsafePointer<CChar>? = nil
                    if libsql_open_remote_with_webpki(url, authToken, &db, &err) != 0 {
                        defer { libsql_free_string(err) }
                        throw LibsqlError.runtimeError(String(cString: err!))
                    }
                }
            }
        }

        self.inner = db!
    }

    init(
        path: String,
        url: String,
        authToken: String,
        readYourWrites: Bool = false,
        encryptionKey: String? = nil,
        syncInterval: Int = 0,
        withWebpki: Bool = false
    ) throws {
        var db: libsql_database_t? = nil

        try path.withCString { path in
            try url.withCString { url in
                try authToken.withCString { authToken in
                    try encryptionKey.withCString { encryptionKey in
                        var err: UnsafePointer<CChar>? = nil
                        if libsql_open_sync_with_config(
                            libsql_config(
                                db_path: path,
                                primary_url: url,
                                auth_token: authToken,
                                read_your_writes: Int8(readYourWrites ? 1 : 0 as Int),
                                encryption_key: encryptionKey,
                                sync_interval: Int32(syncInterval),
                                with_webpki: Int8(readYourWrites ? 1 : 0 as Int)
                            ),
                            &db,
                            &err
                        ) != 0 {
                            defer { libsql_free_string(err) }
                            throw LibsqlError.runtimeError(String(cString: err!))
                        }
                    }
                }
            }
        }

        self.inner = db!
    }
}
