import SwiftUI

struct GlassShellBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.10, green: 0.13, blue: 0.20)]
                : [Color(red: 0.94, green: 0.97, blue: 1.00), Color(red: 0.87, green: 0.91, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: colorScheme == .dark
                ? [Color(red: 0.10, green: 0.14, blue: 0.21).opacity(0.6), .clear]
                : [Color.white.opacity(0.80), Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [accent.opacity(colorScheme == .dark ? 0.30 : 0.23), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 560
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [secondaryAccent.opacity(colorScheme == .dark ? 0.16 : 0.14), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            if colorScheme == .light {
                RadialGradient(
                    colors: [Color.cyan.opacity(0.10), .clear],
                    center: .bottomLeading,
                    startRadius: 30,
                    endRadius: 440
                )
                .ignoresSafeArea()
            }
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
                    .fill(baseFillStyle)
                    .overlay(
                        surfaceOverlay
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor.opacity(strokeOpacity), lineWidth: 0.7)
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 0.6)
                            .blur(radius: 0.3)
                            .allowsHitTesting(false)
                    )
                    .shadow(color: .black.opacity(colorScheme == .dark ? shadowOpacity : shadowOpacity * 0.55), radius: colorScheme == .dark ? 22 : 14, y: 9)
                    .shadow(color: .white.opacity(colorScheme == .dark ? 0.0 : 0.35), radius: 7, x: -2, y: -2)
            )
    }

    private var baseFillStyle: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(.thinMaterial)
        }
        return AnyShapeStyle(.regularMaterial)
    }

    private var surfaceOverlay: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.55),
                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.16),
                Color.black.opacity(colorScheme == .dark ? 0.24 : 0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RadialGradient(
                colors: [
                    (colorScheme == .dark ? Color.cyan : Color.blue).opacity(colorScheme == .dark ? 0.09 : 0.08),
                    .clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 340
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .allowsHitTesting(false)
        )
        .allowsHitTesting(false)
    }

    private var borderColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.30)
        : Color.white.opacity(0.66)
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
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                                : [Color.white.opacity(0.92), Color.blue.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                          )
                          : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.10)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor.opacity(isActive ? 0.26 : 0.08), lineWidth: 0.7)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var strokeColor: Color {
        colorScheme == .dark ? Color.white : Color.blue
    }
}
