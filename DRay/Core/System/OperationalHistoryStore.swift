import Foundation
import SQLite3

struct OperationalHistoryStore {
    private let fileManager: FileManager
    private let userDefaults: UserDefaults
    private let directoryURL: URL
    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard,
        directoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults

        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            self.directoryURL = appSupport
                .appendingPathComponent("DRay", isDirectory: true)
                .appendingPathComponent("History", isDirectory: true)
        }

        self.databaseURL = self.directoryURL.appendingPathComponent("history.sqlite3", isDirectory: false)
    }

    func load<Value: Codable>(
        _ type: Value.Type,
        fileName: String,
        legacyDefaultsKey: String? = nil
    ) -> Value? {
        if let rowData = readPayload(for: fileName),
           let value = try? decoder.decode(Value.self, from: rowData) {
            return value
        }

        if let legacyFileData = readLegacyFilePayload(fileName: fileName),
           let legacyValue = try? decoder.decode(Value.self, from: legacyFileData) {
            save(legacyValue, fileName: fileName)
            deleteLegacyFilePayload(fileName: fileName)
            return legacyValue
        }

        guard let legacyDefaultsKey,
              let legacyData = userDefaults.data(forKey: legacyDefaultsKey),
              let legacyValue = try? decoder.decode(Value.self, from: legacyData) else {
            return nil
        }

        save(legacyValue, fileName: fileName)
        userDefaults.removeObject(forKey: legacyDefaultsKey)
        return legacyValue
    }

    func save<Value: Codable>(_ value: Value, fileName: String) {
        guard let data = try? encoder.encode(value) else { return }
        _ = writePayload(data, for: fileName)
    }

    private func readLegacyFilePayload(fileName: String) -> Data? {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }

    private func deleteLegacyFilePayload(fileName: String) {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    private func readPayload(for key: String) -> Data? {
        withDatabase { db in
            let sql = "SELECT payload FROM history_blobs WHERE key = ? LIMIT 1;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            let bindKeyResult = key.withCString { keyCString in
                sqlite3_bind_text(statement, 1, keyCString, -1, sqliteTransient)
            }
            guard bindKeyResult == SQLITE_OK else {
                return nil
            }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            let length = Int(sqlite3_column_bytes(statement, 0))
            guard length > 0 else { return Data() }
            guard let bytes = sqlite3_column_blob(statement, 0) else { return nil }
            return Data(bytes: bytes, count: length)
        }
    }

    private func writePayload(_ data: Data, for key: String) -> Bool {
        withDatabase { db in
            let sql = """
            INSERT INTO history_blobs (key, payload, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                payload = excluded.payload,
                updated_at = excluded.updated_at;
            """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                return false
            }
            defer { sqlite3_finalize(statement) }

            let bindKeyResult = key.withCString { keyCString in
                sqlite3_bind_text(statement, 1, keyCString, -1, sqliteTransient)
            }
            guard bindKeyResult == SQLITE_OK else {
                return false
            }

            let result = data.withUnsafeBytes { rawBuffer in
                let bytes = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self)
                return sqlite3_bind_blob(statement, 2, bytes, Int32(data.count), sqliteTransient)
            }
            guard result == SQLITE_OK else { return false }

            guard sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970) == SQLITE_OK else {
                return false
            }

            return sqlite3_step(statement) == SQLITE_DONE
        } ?? false
    }

    private func withDatabase<T>(_ body: (OpaquePointer) -> T?) -> T? {
        guard ensureDirectoryExists() else { return nil }

        var db: OpaquePointer?
        let openResult = sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )
        guard openResult == SQLITE_OK, let db else {
            if let db { sqlite3_close(db) }
            return nil
        }
        defer { sqlite3_close(db) }

        guard initializeSchema(on: db) else {
            return nil
        }

        return body(db)
    }

    private func initializeSchema(on db: OpaquePointer) -> Bool {
        let sql = """
        CREATE TABLE IF NOT EXISTS history_blobs (
            key TEXT PRIMARY KEY,
            payload BLOB NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func ensureDirectoryExists() -> Bool {
        if fileManager.fileExists(atPath: directoryURL.path) {
            return true
        }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
