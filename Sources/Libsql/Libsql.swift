import CLibsql

enum LibsqlError: Error {
  case runtimeError(String)
}

class Database {
  var inner: libsql_database_t

  deinit {
    print("closing")
    libsql_close(self.inner)
  }

  init?(path: String) throws {
    var db: libsql_database_t? = nil
    var err: UnsafePointer<CChar>? = nil

    try path.withCString { path in
      if libsql_open_file(path, &db, &err) != 0 {
        throw LibsqlError.runtimeError(String(cString: err!))
      }
    }

    if let db = db {
      self.inner = db
    } else {
      return nil
    }
  }

  init?(url: String, authToken: String) throws {
    var db: libsql_database_t? = nil
    var err: UnsafePointer<CChar>? = nil

    try url.withCString { url in
      try authToken.withCString { authToken in
        if libsql_open_remote(url, authToken, &db, &err) == 0 {
          defer { libsql_free_string(err) }
          throw LibsqlError.runtimeError(String(cString: err!))
        }
      }
    }

    if let db = db {
      self.inner = db
    } else {
      return nil
    }
  }
}
