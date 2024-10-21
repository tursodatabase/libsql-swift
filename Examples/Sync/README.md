# Sync

This example demonstrates how to use libSQL with a synced database (local file synced with a remote database).

## Running

Execute the example:

```bash
TURSO_DATABASE_URL="..." TURSO_AUTH_TOKEN="..." swift run Sync
```

This will connect to a remote SQLite database, insert some data, and then query the results.
