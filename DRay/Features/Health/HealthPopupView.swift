import SwiftUI

struct HealthPopupView: View {
    @ObservedObject var model: RootViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mac Health: \(healthState)")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(Host.current().localizedName ?? "Mac")
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan.opacity(0.85))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                card("Storage", detail: storageValue, action: "Free Up")
                card("Memory", detail: memoryValue, action: "Check")
                card("Startup", detail: startupValue, action: "Optimize")
                card("Privacy", detail: privacyValue, action: "Review")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Recommendation")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                Text(recommendation)
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

            HStack {
                Button("Run Full Smart Scan") { model.runUnifiedScan() }
                    .buttonStyle(.borderedProminent)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(width: 700, height: 520)
        .background(
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.06, blue: 0.42), Color(red: 0.09, green: 0.02, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            if model.performanceReport == nil {
                model.runPerformanceScan()
            }
            if model.privacyCategories.isEmpty {
                model.runPrivacyScan()
            }
        }
    }

    private func card(_ title: String, detail: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(.white)
            Text(detail).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            Text(action)
                .font(.headline)
                .foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(14)
        .frame(height: 120)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private var storageValue: String {
        guard let report = model.performanceReport, let free = report.diskFreeBytes else { return "No data" }
        return "Available: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))"
    }

    private var memoryValue: String {
        "Pressure: baseline check"
    }

    private var startupValue: String {
        guard let report = model.performanceReport else { return "No data" }
        return "\(report.startupEntries.count) startup entries"
    }

    private var privacyValue: String {
        "\(model.privacyCategories.count) categories detected"
    }

    private var healthState: String {
        let startup = model.performanceReport?.startupEntries.count ?? 0
        if startup > 40 { return "Needs Attention" }
        if startup > 20 { return "Fair" }
        return "Good"
    }

    private var recommendation: String {
        if model.privacyCategories.count > 2 {
            return "Privacy traces detected. Run privacy cleanup after review."
        }
        if let startup = model.performanceReport?.startupEntries.count, startup > 20 {
            return "Disable non-essential startup entries to improve boot performance."
        }
        return "Run full smart scan to keep storage and system health in optimal state."
    }
}
