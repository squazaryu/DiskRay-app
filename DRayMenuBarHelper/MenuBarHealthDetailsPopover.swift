import SwiftUI

struct MenuBarHealthDetailsPopoverView: View {
    let issues: [HealthIssue]
    let onOpenPerformance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Health details")
                .font(.headline)
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: issue.severity.icon)
                        .foregroundStyle(issue.severity.color)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.title)
                            .font(.subheadline.weight(.semibold))
                        Text(issue.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 0.6)
                        )
                )
            }
            HStack {
                Spacer()
                Button("Open Performance", action: onOpenPerformance)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 360)
    }
}
