import SwiftUI

enum BubbleTapMode: String, CaseIterable, Identifiable {
    case select
    case openFolders

    var id: String { rawValue }
    var title: String {
        switch self {
        case .select: return "Select"
        case .openFolders: return "Open folders"
        }
    }
}

struct BubbleMapView: View {
    let root: FileNode
    @Binding var hoveredPath: String?
    @Binding var selectedPaths: Set<String>
    @Binding var tapMode: BubbleTapMode
    @State private var navigation: [FileNode] = []
    @State private var didInitialReset = false
    @State private var cachedLayout: [BubbleLayoutItem] = []
    @State private var cachedNodeID: FileNode.ID?
    @State private var cachedSize: CGSize = .zero
    private let maxVisibleBubbles = 20

    var body: some View {
        GeometryReader { geo in
            let current = navigation.last ?? root
            let coreRadius = centerCoreRadius(for: geo.size)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.92, green: 0.94, blue: 0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture(count: 2) { goUp() }
                .onTapGesture { selectedPaths.removeAll() }

                Circle()
                    .fill(Color.white.opacity(0.90))
                    .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
                    .frame(width: coreRadius * 2, height: coreRadius * 2)
                    .position(x: center.x, y: center.y)
                VStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.black.opacity(0.75))
                    Text(current.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.black.opacity(0.9))
                        .lineLimit(1)
                    Text(current.formattedSize)
                        .font(.subheadline)
                        .foregroundStyle(.black.opacity(0.65))
                }
                .frame(maxWidth: 170)
                .position(x: center.x, y: center.y)

                ForEach(cachedLayout, id: \.node.url.path) { item in
                    bubbleView(for: item)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            resetToRoot()
                        } label: {
                            Label("Root", systemImage: "house")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.black.opacity(0.08))

                        Button {
                            goUp()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        .disabled(navigation.isEmpty)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(breadcrumbNodes(), id: \.url.path) { node in
                                Button {
                                    jumpTo(node)
                                } label: {
                                    Text(node.name == "/" ? "Root" : node.name)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Text(current.url.path)
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.65))
                        .lineLimit(1)
                    Text(tapMode == .select ? "Tap bubble: select item" : "Tap folder bubble: open level")
                        .font(.caption2)
                        .foregroundStyle(.black.opacity(0.55))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .onChange(of: root.id) {
                navigation = []
                selectedPaths.removeAll()
                hoveredPath = nil
                cachedLayout = []
                cachedNodeID = nil
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onAppear {
                if !didInitialReset {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                    didInitialReset = true
                }
                sanitizeSelection(for: current)
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: current.id) {
                sanitizeSelection(for: current)
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: geo.size.width) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
            .onChange(of: geo.size.height) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
        }
    }

    private func bubbleView(for item: BubbleLayoutItem) -> some View {
        let isSelected = selectedPaths.contains(item.node.url.path)
        let isHovered = hoveredPath == item.node.url.path
        let fillColor = isSelected ? Color(red: 0.82, green: 0.88, blue: 1.0) : Color.white.opacity(0.84)
        let strokeColor: Color = {
            if isSelected { return Color.blue.opacity(0.62) }
            if isHovered { return Color.black.opacity(0.30) }
            return Color.black.opacity(0.13)
        }()

        return ZStack {
            Circle()
                .fill(fillColor)
            Circle()
                .stroke(strokeColor, lineWidth: isSelected ? 2 : 1)
            VStack(spacing: 4) {
                Image(systemName: item.node.isDirectory ? "folder.fill" : "doc.fill")
                    .foregroundStyle(.black.opacity(0.75))
                Text(item.node.name)
                    .font(.system(size: fontSize(for: item.radius), weight: .semibold))
                    .foregroundStyle(.black.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: item.radius * 1.55)
                if item.radius > 50 {
                    Text(item.node.formattedSize)
                        .font(.system(size: max(10, fontSize(for: item.radius) - 2)))
                        .foregroundStyle(.black.opacity(0.70))
                }
            }
            .padding(.horizontal, item.radius * 0.12)
        }
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06), radius: isSelected ? 8 : 4, x: 0, y: 2)
        .frame(width: item.radius * 2, height: item.radius * 2)
        .contentShape(Circle())
        .position(x: item.center.x, y: item.center.y)
        .onTapGesture { handlePrimaryTap(on: item.node) }
        .onHover { inside in
            hoveredPath = inside ? item.node.url.path : nil
        }
    }

    private func fontSize(for radius: CGFloat) -> CGFloat {
        min(30, max(11, radius * 0.2))
    }

    private func toggleSelection(for path: String) {
        if selectedPaths.contains(path) {
            selectedPaths.remove(path)
        } else {
            selectedPaths.removeAll()
            selectedPaths.insert(path)
        }
    }

    private func handlePrimaryTap(on node: FileNode) {
        let path = node.url.path
        if tapMode == .openFolders {
            if node.isDirectory, !node.children.isEmpty {
                diveInto(node)
            } else {
                toggleSelection(for: path)
            }
            return
        }
        if selectedPaths.contains(path) {
            if node.isDirectory, !node.children.isEmpty {
                diveInto(node)
            } else {
                selectedPaths.remove(path)
            }
            return
        }
        toggleSelection(for: path)
    }

    private func diveInto(_ node: FileNode) {
        guard node.isDirectory, !node.children.isEmpty else { return }
        navigation.append(node)
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func goUp() {
        guard !navigation.isEmpty else { return }
        navigation.removeLast()
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func resetToRoot() {
        navigation.removeAll()
        selectedPaths.removeAll()
        hoveredPath = nil
    }

    private func breadcrumbNodes() -> [FileNode] {
        if navigation.isEmpty { return [root] }
        return [root] + navigation
    }

    private func jumpTo(_ node: FileNode) {
        if node.url.path == root.url.path {
            resetToRoot()
            return
        }
        if let idx = navigation.firstIndex(where: { $0.url.path == node.url.path }) {
            navigation = Array(navigation.prefix(through: idx))
            selectedPaths.removeAll()
            hoveredPath = nil
        }
    }

    private func packedLayout(for node: FileNode, in size: CGSize, maxItems: Int) -> [BubbleLayoutItem] {
        let items = Array(node.largestChildren.prefix(maxItems))
        guard !items.isEmpty else { return [] }

        let width = max(size.width, 520)
        let height = max(size.height, 360)
        let center = CGPoint(x: width / 2, y: height / 2)
        let coreRadius = centerCoreRadius(for: size)
        let minCanvas = min(width, height)
        let bounds = CGRect(x: 12, y: 12, width: width - 24, height: height - 24)

        let maxSize = Double(max(items.first?.sizeInBytes ?? 1, 1))
        let minR = max(26.0, minCanvas * 0.055)
        let maxR = min(100.0, minCanvas * 0.18)
        let baseRadii: [CGFloat] = items.map { child in
            let factor = sqrt(Double(max(child.sizeInBytes, 1)) / maxSize)
            return CGFloat(minR + (maxR - minR) * factor)
        }

        var output: [BubbleLayoutItem] = []
        output.reserveCapacity(items.count)
        for (index, node) in items.enumerated() {
            let radius = baseRadii[index]
            let point = bestBubblePosition(
                radius: radius,
                index: index,
                center: center,
                coreRadius: coreRadius,
                bounds: bounds,
                placed: output
            )
            output.append(BubbleLayoutItem(node: node, center: point, radius: radius))
        }
        return output
    }

    private func bestBubblePosition(
        radius: CGFloat,
        index: Int,
        center: CGPoint,
        coreRadius: CGFloat,
        bounds: CGRect,
        placed: [BubbleLayoutItem]
    ) -> CGPoint {
        let goldenAngle = Double.pi * (3 - sqrt(5))
        var bestPoint = CGPoint(x: center.x + coreRadius + radius + 18, y: center.y)
        var bestPenalty = CGFloat.greatestFiniteMagnitude
        let yScale: CGFloat = bounds.width > bounds.height ? 0.82 : 1.0

        for step in 0..<240 {
            let radialDistance = coreRadius + radius + 18 + CGFloat(step) * 4.8
            let angle = Double(index) * goldenAngle + Double(step) * 0.44
            var candidate = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radialDistance,
                y: center.y + CGFloat(sin(angle)) * radialDistance * yScale
            )
            candidate.x = min(max(candidate.x, bounds.minX + radius), bounds.maxX - radius)
            candidate.y = min(max(candidate.y, bounds.minY + radius), bounds.maxY - radius)

            let overlapPenalty = overlapAmount(for: candidate, radius: radius, placed: placed)
            let corePenalty = max(0, (coreRadius + radius + 12) - distance(candidate, center))
            let centerPenalty = distance(candidate, center) * 0.01
            let penalty = overlapPenalty * 30 + corePenalty * 40 + centerPenalty

            if penalty < bestPenalty {
                bestPenalty = penalty
                bestPoint = candidate
            }
            if overlapPenalty <= 0.1 && corePenalty <= 0.1 {
                break
            }
        }
        return bestPoint
    }

    private func overlapAmount(for point: CGPoint, radius: CGFloat, placed: [BubbleLayoutItem]) -> CGFloat {
        var overlap: CGFloat = 0
        for item in placed {
            let minDistance = item.radius + radius + 8
            let currentDistance = distance(point, item.center)
            if currentDistance < minDistance {
                overlap += (minDistance - currentDistance)
            }
        }
        return overlap
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func recalcLayoutIfNeeded(current: FileNode, size: CGSize, force: Bool) {
        let nodeChanged = cachedNodeID != current.id
        let widthChanged = abs(size.width - cachedSize.width) > 24
        let heightChanged = abs(size.height - cachedSize.height) > 24
        guard force || nodeChanged || widthChanged || heightChanged else { return }
        cachedLayout = packedLayout(for: current, in: size, maxItems: maxVisibleBubbles)
        cachedNodeID = current.id
        cachedSize = size
    }

    private func sanitizeSelection(for node: FileNode) {
        let visible = Set(node.largestChildren.prefix(maxVisibleBubbles).map { $0.url.path })
        selectedPaths = selectedPaths.filter { visible.contains($0) }
        if let hoveredPath, !visible.contains(hoveredPath) {
            self.hoveredPath = nil
        }
    }

    private func centerCoreRadius(for size: CGSize) -> CGFloat {
        let minSide = min(max(size.width, 400), max(size.height, 320))
        return min(118, max(84, minSide * 0.15))
    }
}

private struct BubbleLayoutItem {
    let node: FileNode
    let center: CGPoint
    let radius: CGFloat
}
