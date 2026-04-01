import Foundation

struct OperationLogEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: String
    let message: String
}

@MainActor
final class OperationLogStore: ObservableObject {
    @Published private(set) var entries: [OperationLogEntry] = []

    private let key = "dray.operation.logs"
    private let maxEntries = 500

    init() {
        load()
    }

    func add(category: String, message: String) {
        let entry = OperationLogEntry(id: UUID(), timestamp: Date(), category: category, message: message)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    func exportJSON(to directory: URL? = nil) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return nil }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let fileName = "dray-operation-log-\(stamp).json"
        let fm = FileManager.default

        var candidateDirs: [URL] = []
        if let directory {
            candidateDirs.append(directory)
        }
        candidateDirs.append(contentsOf: fm.urls(for: .downloadsDirectory, in: .userDomainMask))
        candidateDirs.append(contentsOf: fm.urls(for: .desktopDirectory, in: .userDomainMask))
        candidateDirs.append(contentsOf: fm.urls(for: .documentDirectory, in: .userDomainMask))
        candidateDirs.append(URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true))

        for baseDir in candidateDirs {
            let url = baseDir.appendingPathComponent(fileName)
            do {
                try data.write(to: url, options: [.atomic])
                return url
            } catch {
                continue
            }
        }
        return nil
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([OperationLogEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
