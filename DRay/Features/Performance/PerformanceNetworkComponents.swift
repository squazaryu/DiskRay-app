import SwiftUI

struct NetworkDiagnosticListRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let value: String
    let icon: String
}

struct NetworkDiagnosticListCard: View {
    let title: String
    let icon: String
    let selectedRowID: String?
    let rows: [NetworkDiagnosticListRow]
    let emptyMessage: String
    let contentPadding: CGFloat
    let showingSummary: (Int, Int) -> String
    let onSelect: (NetworkDiagnosticListRow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                DRayQuietIconBadge(systemName: icon, tone: .info, size: 28)
                Text(title)
                    .font(.headline)
            }

            if rows.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            } else {
                let visibleRows = Array(rows.prefix(6))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visibleRows) { row in
                        Button {
                            onSelect(row)
                        } label: {
                            HStack(spacing: 10) {
                                DRayQuietIconBadge(systemName: row.icon, tone: .info, size: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    if !row.subtitle.isEmpty {
                                        Text(row.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(row.value)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        row.id == selectedRowID
                                            ? Color.accentColor.opacity(0.08)
                                            : Color.primary.opacity(0.035)
                                    )
                            )
                            .overlay(alignment: .leading) {
                                if row.id == selectedRowID {
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.62))
                                        .frame(width: 3)
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if rows.count > visibleRows.count {
                        Text(showingSummary(visibleRows.count, rows.count))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(contentPadding)
        .glassSurface(
            cornerRadius: 16,
            strokeOpacity: 0.07,
            shadowOpacity: 0.035,
            padding: 0
        )
    }
}

struct NetworkPrivacyMenuView: View {
    @Binding var publicIPEnabled: Bool
    @Binding var remoteEndpointsEnabled: Bool

    let title: String
    let publicIPTitle: String
    let remoteEndpointsTitle: String
    let disclosure: String
    let clearCacheTitle: String
    let helpText: String
    let onClearCache: () -> Void

    var body: some View {
        Menu {
            Toggle(publicIPTitle, isOn: $publicIPEnabled)
            Toggle(remoteEndpointsTitle, isOn: $remoteEndpointsEnabled)
            Divider()
            Text(disclosure)
            Button(clearCacheTitle, action: onClearCache)
        } label: {
            Label(title, systemImage: "hand.raised")
                .font(.caption.weight(.semibold))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(helpText)
    }
}
