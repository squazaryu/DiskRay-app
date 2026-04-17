import Foundation
import SQLite3

final class SQLiteIndexStore {
    private let db: OpaquePointer?

    init?() {
        let fm = FileManager.default
        let appSupport = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = appSupport.appendingPathComponent("DRay", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let dbURL = dir.appendingPathComponent("index.sqlite")
        var handle: OpaquePointer?
        guard sqlite3_open(dbURL.path, &handle) == SQLITE_OK else { return nil }
        db = handle
        createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    func saveSnapshot(root: FileNode) {
        guard let db else { return }
        _ = sqlite3_exec(db, "BEGIN TRANSACTION", nil, nil, nil)
        _ = sqlite3_exec(db, "DELETE FROM file_index", nil, nil, nil)

        var stmt: OpaquePointer?
        let sql = "INSERT INTO file_index(path,parent,name,is_dir,size_bytes) VALUES(?,?,?,?,?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }

        for node in flatten(root: root, parentPath: nil) {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            sqlite3_bind_text(stmt, 1, (node.path as NSString).utf8String, -1, nil)
            if let parent = node.parentPath {
                sqlite3_bind_text(stmt, 2, (parent as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(stmt, 2)
            }
            sqlite3_bind_text(stmt, 3, (node.name as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 4, node.isDirectory ? 1 : 0)
            sqlite3_bind_int64(stmt, 5, node.sizeInBytes)
            _ = sqlite3_step(stmt)
        }

        sqlite3_finalize(stmt)
        _ = sqlite3_exec(db, "COMMIT", nil, nil, nil)
    }

    func loadSnapshot(rootPath: String) -> FileNode? {
        guard let db else { return nil }
        let childPrefix = rootPath == "/" ? "/" : rootPath + "/"

        var stmt: OpaquePointer?
        let sql = "SELECT path,parent,name,is_dir,size_bytes FROM file_index"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }

        var records: [FlatNode] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cPath = sqlite3_column_text(stmt, 0),
                  let cName = sqlite3_column_text(stmt, 2) else { continue }

            let path = String(cString: cPath)
            if path != rootPath && !path.hasPrefix(childPrefix) { continue }

            let parent: String?
            if sqlite3_column_type(stmt, 1) == SQLITE_NULL {
                parent = nil
            } else if let cParent = sqlite3_column_text(stmt, 1) {
                parent = String(cString: cParent)
            } else {
                parent = nil
            }

            let name = String(cString: cName)
            let isDirectory = sqlite3_column_int(stmt, 3) == 1
            let size = sqlite3_column_int64(stmt, 4)
            records.append(FlatNode(path: path, parentPath: parent, name: name, isDirectory: isDirectory, sizeInBytes: size))
        }
        sqlite3_finalize(stmt)

        guard !records.isEmpty else { return nil }
        return buildTree(records: records, rootPath: rootPath)
    }

    func clearSnapshotCache() -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, "DELETE FROM file_index", nil, nil, nil) == SQLITE_OK
    }

    private func createSchema() {
        guard let db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS file_index(
            path TEXT PRIMARY KEY,
            parent TEXT,
            name TEXT NOT NULL,
            is_dir INTEGER NOT NULL,
            size_bytes INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_file_index_parent ON file_index(parent);
        """
        _ = sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func flatten(root: FileNode, parentPath: String?) -> [FlatNode] {
        var rows = [FlatNode(path: root.url.path, parentPath: parentPath, name: root.name, isDirectory: root.isDirectory, sizeInBytes: root.sizeInBytes)]
        for child in root.children {
            rows.append(contentsOf: flatten(root: child, parentPath: root.url.path))
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

        func build(from record: FlatNode) -> FileNode {
            let children = (byParent[record.path] ?? []).map(build).sorted { $0.sizeInBytes > $1.sizeInBytes }
            return FileNode(
                url: URL(fileURLWithPath: record.path),
                name: record.name,
                isDirectory: record.isDirectory,
                sizeInBytes: record.sizeInBytes,
                children: children
            )
        }

        return build(from: root)
    }
}

private struct FlatNode {
    let path: String
    let parentPath: String?
    let name: String
    let isDirectory: Bool
    let sizeInBytes: Int64
}
