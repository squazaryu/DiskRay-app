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

        let baseDir = directory ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        guard let baseDir else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = baseDir.appendingPathComponent("dray-operation-log-\(stamp).json")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
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
