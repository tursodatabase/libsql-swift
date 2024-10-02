import CLibsql
import Foundation

public enum Value {
    case integer(Int64)
    case text(String)
    case blob(Data)
    case real(Double)
    case null
}

public protocol ValueRepresentable {
    func toValue() -> Value
}

extension Value: ValueRepresentable {
    public func toValue() -> Value { self }
}

extension Int: ValueRepresentable {
    public func toValue() -> Value { .integer(Int64(self)) }
}

extension Int64: ValueRepresentable {
    public func toValue() -> Value { .integer(self) }
}

extension String: ValueRepresentable {
    public func toValue() -> Value { .text(self) }
}

extension Data: ValueRepresentable {
    public func toValue() -> Value { .blob(self) }
}

extension Double: ValueRepresentable {
    public func toValue() -> Value { .real(self) }
}

public protocol Prepareable {
    func prepare(_ sql: String) throws -> Statement
}

public extension Prepareable {
    func execute(_ sql: String) throws -> Int {
        return try self.prepare(sql).execute()
    }
    
    func execute(_ sql: String, _ params: [String: ValueRepresentable]) throws -> Int {
        return try self.prepare(sql).bind(params).execute()
    }
    
    func execute(_ sql: String, _ params: [ValueRepresentable]) throws -> Int {
        return try self.prepare(sql).bind(params).execute()
    }
    
    func query(_ sql: String) throws -> Rows {
        return try self.prepare(sql).query()
    }
    
    func query(_ sql: String, _ params: [String: ValueRepresentable]) throws -> Rows {
        return try self.prepare(sql).bind(params).query()
    }
    
    func query(_ sql: String, _ params: [ValueRepresentable]) throws -> Rows {
        return try self.prepare(sql).bind(params).query()
    }
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

func errIf(_ err: OpaquePointer!) throws {
    if (err != nil) {
        defer { libsql_error_deinit(err) }
        throw LibsqlError.runtimeError(String(cString: libsql_error_message(err)!))
    }
}

enum LibsqlError: Error {
    case runtimeError(String)
    case typeMismatch
}

public class Row {
    var inner: libsql_row_t

    fileprivate init?(from inner: libsql_row_t?) {
        guard let inner = inner else {
            return nil
        }

        self.inner = inner
    }
    
    public func get(_ index: Int32) throws -> Value {
        let result = libsql_row_value(self.inner, index)
        try errIf(result.err)
       
        switch result.ok.type {
        case LIBSQL_TYPE_BLOB:
            let slice = result.ok.value.blob
            defer { libsql_slice_deinit(slice) }
            return .blob(Data(bytes: slice.ptr, count: Int(slice.len)))
        case LIBSQL_TYPE_TEXT:
            let slice = result.ok.value.text
            defer { libsql_slice_deinit(slice) }
            return .text(String(cString: slice.ptr.assumingMemoryBound(to: UInt8.self)))
        case LIBSQL_TYPE_INTEGER:
            return .integer(result.ok.value.integer)
        case LIBSQL_TYPE_REAL:
            return .real(result.ok.value.real)
        case LIBSQL_TYPE_NULL:
            return .null
        default:
            preconditionFailure()
        }
    }

    public func getData(_ index: Int32) throws -> Data {
        guard case let .blob(data) = try self.get(index) else {
            throw LibsqlError.typeMismatch
        }
        return data
    }

    public func getDouble(_ index: Int32) throws -> Double {
        guard case let .real(double) = try self.get(index) else {
            throw LibsqlError.typeMismatch
        }
        return double
    }

    public func getString(_ index: Int32) throws -> String {
        guard case let .text(string) = try self.get(index) else {
            throw LibsqlError.typeMismatch
        }
        return string
    }

    public func getInt(_ index: Int32) throws -> Int {
        guard case let .integer(int) = try self.get(index) else {
            throw LibsqlError.typeMismatch
        }
        return Int(int)
    }
}

public class Rows: Sequence, IteratorProtocol {
    var inner: libsql_rows_t

    fileprivate init(from inner: libsql_rows_t) {
        self.inner = inner
    }

    deinit {
        libsql_rows_deinit(self.inner)
    }

    public func next() -> Row? {
        let row = libsql_rows_next(self.inner)
        try! errIf(row.err)
        
        if libsql_row_empty(row) {
            return nil
        }
        
        return Row(from: row)
    }
}

public class Statement {
    var inner: libsql_statement_t

    deinit {
        libsql_statement_deinit(self.inner)
    }

    fileprivate init(from inner: libsql_statement_t) {
        self.inner = inner
    }

    public func execute() throws -> Int {
        let exec = libsql_statement_execute(self.inner)
        try errIf(exec.err)
        
        return Int(exec.rows_changed)
    }

    public func query() throws -> Rows {
        let rows = libsql_statement_query(self.inner)
        try errIf(rows.err)

        return Rows(from: rows)
    }
    
    public func bind(_ params: [String: ValueRepresentable]) throws -> Self {
        for (name, value) in params {
            switch value.toValue() {
            case .integer(let integer):
                let bind = libsql_statement_bind_named(
                    self.inner,
                    name,
                    libsql_integer(integer)
                )
                try errIf(bind.err)
            case .text(let text):
                let len = text.count + 1
                try text.withCString { text in
                    let bind = libsql_statement_bind_named(
                        self.inner,
                        name,
                        libsql_text(text, len)
                    )
                    try errIf(bind.err)
                }
            case .blob(let slice):
                try slice.withUnsafeBytes { slice in
                    let bind = libsql_statement_bind_named(
                        self.inner,
                        name,
                        libsql_blob(slice.baseAddress, slice.count)
                    )
                    try errIf(bind.err)
                }
            case .real(let real):
                let bind = libsql_statement_bind_named(
                    self.inner,
                    name,
                    libsql_real(real)
                )
                try errIf(bind.err)
            case .null:
                let bind = libsql_statement_bind_named(
                    self.inner,
                    name,
                    libsql_value_t(value: .init(), type: LIBSQL_TYPE_NULL)
                )
                try errIf(bind.err)
            }
        }
        
        return self;
    }

    public func bind(_ params: [ValueRepresentable]) throws -> Self {
        for value in params {
            switch value.toValue() {
            case .integer(let integer):
                let bind = libsql_statement_bind_value(
                    self.inner,
                    libsql_integer(integer)
                )
                try errIf(bind.err)
            case .text(let text):
                let len = text.count + 1
                try text.withCString { text in
                    let bind = libsql_statement_bind_value(
                        self.inner,
                        libsql_text(text, len)
                    )
                    try errIf(bind.err)
                }
            case .blob(let slice):
                try slice.withUnsafeBytes { slice in
                    let bind = libsql_statement_bind_value(
                        self.inner,
                        libsql_blob(slice.baseAddress, slice.count)
                    )
                    try errIf(bind.err)
                }
            case .real(let real):
                let bind = libsql_statement_bind_value(self.inner, libsql_real(real))
                try errIf(bind.err)
            case .null:
                let bind = libsql_statement_bind_value(
                    self.inner,
                    libsql_value_t(value: .init(), type: LIBSQL_TYPE_NULL)
                )
                try errIf(bind.err)
            }
        }
        
        return self;
    }
}

public class Transaction: Prepareable {
    var inner: libsql_transaction_t
    
    public consuming func commit() {
        libsql_transaction_commit(self.inner)
    }
    
    public consuming func rollback() {
        libsql_transaction_rollback(self.inner)
    }

    fileprivate init(from inner: libsql_transaction_t) {
        self.inner = inner
    }
    
    public func executeBatch(_ sql: String) throws {
        let batch = libsql_transaction_batch(self.inner, sql)
        try errIf(batch.err)
    }

    public func prepare(_ sql: String) throws -> Statement {
        let stmt = libsql_transaction_prepare(self.inner, sql);
        try errIf(stmt.err)
        
        return Statement(from: stmt)
    }
    
}

public class Connection: Prepareable {
    var inner: libsql_connection_t

    deinit {
        libsql_connection_deinit(self.inner)
    }

    fileprivate init(from inner: libsql_connection_t) {
        self.inner = inner
    }
    
    public func transaction() throws -> Transaction {
        let tx = libsql_connection_transaction(self.inner)
        try errIf(tx.err);

        return Transaction(from: tx)
    }
    
    public func executeBatch(_ sql: String) throws {
        let batch = libsql_connection_batch(self.inner, sql)
        try errIf(batch.err)
    }

    public func prepare(_ sql: String) throws -> Statement {
        let stmt = libsql_connection_prepare(self.inner, sql);
        try errIf(stmt.err)
        
        return Statement(from: stmt)
    }
}

public class Database {
    var inner: libsql_database_t

    deinit {
        libsql_database_deinit(self.inner)
    }

    public func sync() throws {
        let sync = libsql_database_sync(self.inner)
        try errIf(sync.err)
    }

    public func connect() throws -> Connection {
        let conn = libsql_database_connect(self.inner)
        try errIf(conn.err)
        
        return Connection(from: conn)
    }

    public init(_ path: String) throws {
        self.inner = try path.withCString { path in
            var desc = libsql_database_desc_t()
            desc.path = path
            
            let db = libsql_database_init(desc)
            try errIf(db.err)
            
            return db
        }
    }

    public init(url: String, authToken: String, withWebpki: Bool = false) throws {
        self.inner = try url.withCString { url in
            try authToken.withCString { authToken in
                var desc = libsql_database_desc_t()
                desc.url = url
                desc.auth_token = authToken
                desc.webpki = withWebpki
                
                let db = libsql_database_init(desc)
                try errIf(db.err)
                
                return db
            }
        }

    }

    public init(
        path: String,
        url: String,
        authToken: String,
        readYourWrites: Bool = true,
        encryptionKey: String? = nil,
        syncInterval: UInt64 = 0,
        withWebpki: Bool = false
    ) throws {
        self.inner = try path.withCString { path in
            try url.withCString { url in
                try authToken.withCString { authToken in
                    try encryptionKey.withCString { encryptionKey in
                        var desc = libsql_database_desc_t()
                        desc.path = path
                        desc.url = url
                        desc.auth_token = authToken
                        desc.encryption_key = encryptionKey
                        desc.not_read_your_writes = !readYourWrites
                        desc.sync_interval = syncInterval
                        desc.webpki = withWebpki
                        
                        let db = libsql_database_init(desc)
                        try errIf(db.err)
                        
                        return db
                    }
                }
            }
        }
    }
}
