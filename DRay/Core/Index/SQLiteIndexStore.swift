import Foundation
import SQLite3

enum SQLiteIndexStoreFailurePoint: Hashable {
    case commit
}

final class SQLiteIndexStore {
    private static let schema = """
    CREATE TABLE IF NOT EXISTS file_index_v2(
        root_path TEXT NOT NULL,
        path TEXT NOT NULL,
        parent TEXT,
        name TEXT NOT NULL,
        is_dir INTEGER NOT NULL,
        size_bytes INTEGER NOT NULL,
        PRIMARY KEY(root_path, path)
    );
    CREATE INDEX IF NOT EXISTS idx_file_index_v2_root_parent
        ON file_index_v2(root_path, parent);
    """

    private var db: OpaquePointer?
    private let injectedFailurePoints: Set<SQLiteIndexStoreFailurePoint>
    private(set) var lastErrorMessage: String?

    convenience init?() {
        let fileManager = FileManager.default
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = appSupport.appendingPathComponent("DRay", isDirectory: true)
        self.init(databaseURL: directory.appendingPathComponent("index.sqlite"))
    }

    init?(
        databaseURL: URL,
        recoverCorruptDatabase: Bool = true,
        injectedFailurePoints: Set<SQLiteIndexStoreFailurePoint> = []
    ) {
        self.injectedFailurePoints = injectedFailurePoints
        let directory = databaseURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            lastErrorMessage = "Could not create index directory: \(error.localizedDescription)"
            return nil
        }

        guard openDatabase(at: databaseURL) else {
            closeDatabase()
            return nil
        }

        if createSchema() {
            return
        }

        let errorCode = db.map(sqlite3_errcode) ?? SQLITE_ERROR
        closeDatabase()
        guard recoverCorruptDatabase, errorCode == SQLITE_CORRUPT || errorCode == SQLITE_NOTADB else {
            return nil
        }

        Self.removeDatabaseFiles(at: databaseURL)
        guard openDatabase(at: databaseURL), createSchema() else {
            closeDatabase()
            return nil
        }
    }

    deinit {
        closeDatabase()
    }

    @discardableResult
    func saveSnapshot(root: FileNode) -> Bool {
        guard let db else { return false }
        lastErrorMessage = nil

        guard execute("BEGIN IMMEDIATE TRANSACTION", operation: "begin snapshot transaction") else {
            return false
        }

        var committed = false
        defer {
            if !committed {
                _ = sqlite3_exec(db, "ROLLBACK", nil, nil, nil)
            }
        }

        let rootPath = Self.normalizedPath(root.url.path)
        guard deleteSnapshot(rootPath: rootPath) else { return false }

        let sql = """
        INSERT INTO file_index_v2(root_path,path,parent,name,is_dir,size_bytes)
        VALUES(?,?,?,?,?,?)
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            recordFailure("prepare snapshot insert")
            return false
        }
        defer { sqlite3_finalize(statement) }

        for node in flatten(root: root, parentPath: nil) {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            guard bind(rootPath, at: 1, to: statement),
                  bind(node.path, at: 2, to: statement),
                  bindOptional(node.parentPath, at: 3, to: statement),
                  bind(node.name, at: 4, to: statement),
                  sqlite3_bind_int(statement, 5, node.isDirectory ? 1 : 0) == SQLITE_OK,
                  sqlite3_bind_int64(statement, 6, node.sizeInBytes) == SQLITE_OK else {
                recordFailure("bind snapshot row")
                return false
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                recordFailure("insert snapshot row")
                return false
            }
        }

        if injectedFailurePoints.contains(.commit) {
            lastErrorMessage = "commit snapshot transaction: injected failure"
            return false
        }
        guard execute("COMMIT", operation: "commit snapshot transaction") else {
            return false
        }
        committed = true
        return true
    }

    func loadSnapshot(rootPath: String) -> FileNode? {
        guard let db else { return nil }
        lastErrorMessage = nil

        let normalizedRootPath = Self.normalizedPath(rootPath)
        let sql = """
        SELECT path,parent,name,is_dir,size_bytes
        FROM file_index_v2
        WHERE root_path = ?
        ORDER BY path
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            recordFailure("prepare snapshot query")
            return nil
        }
        defer { sqlite3_finalize(statement) }

        guard bind(normalizedRootPath, at: 1, to: statement) else {
            recordFailure("bind snapshot root")
            return nil
        }

        var records: [FlatNode] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let pathValue = sqlite3_column_text(statement, 0),
                      let nameValue = sqlite3_column_text(statement, 2) else {
                    lastErrorMessage = "Snapshot query returned a row without a path or name."
                    return nil
                }

                let parentPath: String?
                if sqlite3_column_type(statement, 1) == SQLITE_NULL {
                    parentPath = nil
                } else if let parentValue = sqlite3_column_text(statement, 1) {
                    parentPath = String(cString: parentValue)
                } else {
                    lastErrorMessage = "Snapshot query returned an invalid parent path."
                    return nil
                }

                records.append(FlatNode(
                    path: String(cString: pathValue),
                    parentPath: parentPath,
                    name: String(cString: nameValue),
                    isDirectory: sqlite3_column_int(statement, 3) == 1,
                    sizeInBytes: sqlite3_column_int64(statement, 4)
                ))
            case SQLITE_DONE:
                guard !records.isEmpty else { return nil }
                return buildTree(records: records, rootPath: normalizedRootPath)
            default:
                recordFailure("read snapshot rows")
                return nil
            }
        }
    }

    func clearSnapshotCache() -> Bool {
        guard db != nil else { return false }
        lastErrorMessage = nil
        return execute("DELETE FROM file_index_v2", operation: "clear snapshot cache")
    }

    private func openDatabase(at databaseURL: URL) -> Bool {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(databaseURL.path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            if let handle {
                lastErrorMessage = String(cString: sqlite3_errmsg(handle))
                sqlite3_close(handle)
            } else {
                lastErrorMessage = "Could not open the index database (SQLite error \(result))."
            }
            return false
        }

        db = handle
        sqlite3_busy_timeout(handle, 1_000)
        return true
    }

    private func closeDatabase() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func createSchema() -> Bool {
        execute(Self.schema, operation: "create index schema")
    }

    private func deleteSnapshot(rootPath: String) -> Bool {
        guard let db else { return false }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            db,
            "DELETE FROM file_index_v2 WHERE root_path = ?",
            -1,
            &statement,
            nil
        ) == SQLITE_OK else {
            recordFailure("prepare snapshot delete")
            return false
        }
        defer { sqlite3_finalize(statement) }

        guard bind(rootPath, at: 1, to: statement) else {
            recordFailure("bind snapshot delete")
            return false
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            recordFailure("delete previous snapshot")
            return false
        }
        return true
    }

    private func execute(_ sql: String, operation: String) -> Bool {
        guard let db else { return false }
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            recordFailure(operation)
            return false
        }
        return true
    }

    private func bind(_ value: String, at index: Int32, to statement: OpaquePointer?) -> Bool {
        value.withCString {
            sqlite3_bind_text(statement, index, $0, -1, Self.sqliteTransient) == SQLITE_OK
        }
    }

    private func bindOptional(_ value: String?, at index: Int32, to statement: OpaquePointer?) -> Bool {
        guard let value else {
            return sqlite3_bind_null(statement, index) == SQLITE_OK
        }
        return bind(value, at: index, to: statement)
    }

    private func recordFailure(_ operation: String) {
        let detail = db.map { String(cString: sqlite3_errmsg($0)) } ?? "database unavailable"
        lastErrorMessage = "\(operation): \(detail)"
    }

    private func flatten(root: FileNode, parentPath: String?) -> [FlatNode] {
        let path = Self.normalizedPath(root.url.path)
        var rows = [FlatNode(
            path: path,
            parentPath: parentPath,
            name: root.name,
            isDirectory: root.isDirectory,
            sizeInBytes: root.sizeInBytes
        )]
        for child in root.children {
            rows.append(contentsOf: flatten(root: child, parentPath: path))
        }
        return rows
    }

    private func buildTree(records: [FlatNode], rootPath: String) -> FileNode? {
        var byParent: [String: [FlatNode]] = [:]
        var byPath: [String: FlatNode] = [:]
        for record in records {
            byPath[record.path] = record
            if let parent = record.parentPath {
                byParent[parent, default: []].append(record)
            }
        }

        guard let root = byPath[rootPath] else { return nil }

        func build(from record: FlatNode, ancestors: Set<String>) -> FileNode {
            let nextAncestors = ancestors.union([record.path])
            let children = (byParent[record.path] ?? [])
                .filter { !nextAncestors.contains($0.path) }
                .map { build(from: $0, ancestors: nextAncestors) }
                .sorted { $0.sizeInBytes > $1.sizeInBytes }
            return FileNode(
                url: URL(fileURLWithPath: record.path),
                name: record.name,
                isDirectory: record.isDirectory,
                sizeInBytes: record.sizeInBytes,
                children: children
            )
        }

        return build(from: root, ancestors: [])
    }

    private static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func removeDatabaseFiles(at databaseURL: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            try? fileManager.removeItem(atPath: databaseURL.path + suffix)
        }
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

private struct FlatNode {
    let path: String
    let parentPath: String?
    let name: String
    let isDirectory: Bool
    let sizeInBytes: Int64
}
