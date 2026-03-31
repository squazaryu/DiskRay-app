import SwiftUI

struct GlassShellBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.10, green: 0.13, blue: 0.20)]
                : [Color(red: 0.95, green: 0.97, blue: 1.00), Color(red: 0.89, green: 0.92, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(red: 0.10, green: 0.14, blue: 0.21).opacity(0.6), .clear]
                : [Color.white.opacity(0.75), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.28 : 0.18), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 560
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [secondaryAccent.opacity(colorScheme == .dark ? 0.16 : 0.12), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
    }

    private var accent: Color {
        colorScheme == .dark ? Color.cyan : Color.blue
    }

    private var secondaryAccent: Color {
        colorScheme == .dark ? Color.purple : Color.indigo
    }
}

struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let strokeOpacity: Double
    let shadowOpacity: Double
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? AnyShapeStyle(.thinMaterial) : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.38),
                                Color.clear,
                                Color.black.opacity(colorScheme == .dark ? 0.22 : 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor.opacity(strokeOpacity + 0.05), lineWidth: 0.9)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.33), lineWidth: 0.6)
                            .blur(radius: 0.3)
                    )
                    .shadow(color: .black.opacity(shadowOpacity), radius: colorScheme == .dark ? 22 : 16, y: 10)
            )
    }

    private var borderColor: Color {
        colorScheme == .dark ? .white : .black
    }
}

extension View {
    func glassSurface(
        cornerRadius: CGFloat = 18,
        strokeOpacity: Double = 0.14,
        shadowOpacity: Double = 0.15,
        padding: CGFloat = 12
    ) -> some View {
        modifier(GlassSurfaceModifier(
            cornerRadius: cornerRadius,
            strokeOpacity: strokeOpacity,
            shadowOpacity: shadowOpacity,
            padding: padding
        ))
    }
}

struct ModuleHeaderCard<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                actions
            }
        }
        .glassSurface(cornerRadius: 16, strokeOpacity: 0.12, shadowOpacity: 0.08, padding: 14)
    }
}

struct GlassPillBadge: View {
    let title: String
    var tint: Color = .blue

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 0.8)
            )
    }
}

struct MinimalGlassButtonStyle: ButtonStyle {
    let isActive: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive
                          ? AnyShapeStyle(
                            LinearGradient(
                                colors: colorScheme == .dark
                                ? [Color.cyan.opacity(0.30), Color.blue.opacity(0.22)]
                                : [Color.white.opacity(0.86), Color.blue.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                          : AnyShapeStyle(Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor.opacity(isActive ? 0.42 : 0.16), lineWidth: 0.9)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
}
