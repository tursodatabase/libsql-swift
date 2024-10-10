<p align="center">
  <a href="https://tur.so/turso-swift">
    <picture>
      <img src="/.github/cover.png" alt="libSQL Swift" />
    </picture>
  </a>
  <h1 align="center">libSQL Swift</h1>
</p>

<p align="center">
  Databases for Swift multi-tenant AI Apps.
</p>

<p align="center">
  <a href="https://tur.so/turso-swift"><strong>Turso</strong></a> ·
  <a href="https://docs.turso.tech"><strong>Docs</strong></a> ·
  <a href="https://docs.turso.tech/sdk/swift/quickstart"><strong>Quickstart</strong></a> ·
  <a href="https://docs.turso.tech/sdk/swift/reference"><strong>SDK Reference</strong></a> ·
  <a href="https://turso.tech/blog"><strong>Blog &amp; Tutorials</strong></a>
</p>

<p align="center">
  <a href="LICENSE">
    <picture>
      <img src="https://img.shields.io/github/license/tursodatabase/libsql-swift?color=0F624B" alt="MIT License" />
    </picture>
  </a>
  <a href="https://tur.so/discord-swift">
    <picture>
      <img src="https://img.shields.io/discord/933071162680958986?color=0F624B" alt="Discord" />
    </picture>
  </a>
  <a href="#contributors">
    <picture>
      <img src="https://img.shields.io/github/contributors/tursodatabase/libsql-swift?color=0F624B" alt="Contributors" />
    </picture>
  </a>
  <a href="/examples">
    <picture>
      <img src="https://img.shields.io/badge/browse-examples-0F624B" alt="Examples" />
    </picture>
  </a>
</p>

## Features

- 🔌 Works offline with [Embedded Replicas](https://docs.turso.tech/features/embedded-replicas/introduction)
- 🌎 Works with remote Turso databases
- ✨ Works with Turso [AI & Vector Search](https://docs.turso.tech/features/ai-and-embeddings)
- 📱 Works with macOS, iPadOS, tvOS, watchOS & iOS

> [!WARNING]
> This SDK is currently in technical preview. <a href="https://tur.so/discord-swift">Join us in Discord</a> to report any issues.

## Install

Add `tursodatabase/libsql-swift` to your SwiftPM dependencies:

```swift
import PackageDescription

let package = Package(
    // ...
    dependencies: [
        .package(url: "https://github.com/tursodatabase/libsql-swift", from: "0.1.1"),
    ],
    // ...
)
```

## Quickstart

The example below uses Embedded Replicas and syncs data every 1000ms from Turso.

```swift
import Libsql

let db = try Database(
    path: "./local.db",
    url: "TURSO_DATABASE_URL",
    authToken: "TURSO_AUTH_TOKEN",
    syncInterval: 1000
)

let conn = try db.connect()

try conn.execute("
  CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT
  );
  INSERT INTO users (name) VALUES ('Iku');
")

try conn.query("SELECT * FROM users WHERE id = ?", 1)
```

## Documentation

Visit our [official documentation](https://docs.turso.tech/sdk/swift).

## Support

Join us [on Discord](https://tur.so/discord-swift) to get help using this SDK. Report security issues [via email](mailto:security@turso.tech).

## Contributors

See the [contributing guide](CONTRIBUTING.md) to learn how to get involved.

![Contributors](https://contrib.nn.ci/api?repo=tursodatabase/libsql-swift)

<a href="https://github.com/tursodatabase/libsql-swift/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22">
  <picture>
    <img src="https://img.shields.io/github/issues-search/tursodatabase/libsql-swift?label=good%20first%20issue&query=label%3A%22good%20first%20issue%22%20&color=0F624B" alt="good first issue" />
  </picture>
</a>
