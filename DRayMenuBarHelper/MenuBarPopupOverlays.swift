import SwiftUI

struct ReliefConfirmOverlayView: View {
    let colorScheme: ColorScheme
    let title: String
    let message: String
    let actionTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(colorScheme == .dark ? 0.30 : 0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onCancel)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button(actionTitle, action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(14)
            .frame(width: 360, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.55), lineWidth: 0.7)
                    )
            )
        }
    }
}

struct ReliefResultBannerView: View {
    let message: String
    let colorScheme: ColorScheme
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Load Reduction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("OK", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.20 : 0.55), lineWidth: 0.7)
                )
        )
    }
}
