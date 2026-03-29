import SwiftUI

struct BubbleMapView: View {
    let root: FileNode
    @Binding var hoveredPath: String?
    @Binding var selectedPaths: Set<String>
    @State private var navigation: [FileNode] = []
    @State private var zoomPulse = false
    @State private var didInitialReset = false
    @State private var cachedLayout: [BubbleLayoutItem] = []
    @State private var cachedNodeID: FileNode.ID?
    @State private var cachedSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let current = navigation.last ?? root
            let coreRadius = centerCoreRadius(for: geo.size)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.96, blue: 0.98), Color(red: 0.90, green: 0.92, blue: 0.96)],
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
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .overlay(alignment: .center) {
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
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .scaleEffect(zoomPulse ? 1.0 : 0.94)
                    .opacity(zoomPulse ? 1.0 : 0.82)
                    .animation(.spring(response: 0.42, dampingFraction: 0.82), value: zoomPulse)

                ForEach(cachedLayout, id: \.node.id) { item in
                    let isSelected = selectedPaths.contains(item.node.url.path)
                    let isHovered = hoveredPath == item.node.url.path
                    let fillColor = isSelected ? Color(red: 0.82, green: 0.88, blue: 1.0) : Color.white.opacity(0.84)
                    let strokeColor: Color = {
                        if isSelected { return Color.blue.opacity(0.6) }
                        if isHovered { return Color.black.opacity(0.28) }
                        return Color.black.opacity(0.12)
                    }()
                    let strokeWidth: CGFloat = isSelected ? 2 : 1
                    Circle()
                        .fill(fillColor)
                        .overlay(Circle().stroke(strokeColor, lineWidth: strokeWidth))
                        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 9 : 5, x: 0, y: 2)
                        .frame(width: item.radius * 2, height: item.radius * 2)
                        .position(x: item.center.x, y: item.center.y)
                        .overlay(alignment: .center) {
                            VStack(spacing: 4) {
                                Image(systemName: item.node.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(.black.opacity(0.75))
                                Text(item.node.name)
                                    .font(.system(size: fontSize(for: item.radius), weight: .semibold))
                                    .foregroundStyle(.black.opacity(0.92))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: item.radius * 1.55)
                                if item.radius > 48 {
                                    Text(item.node.formattedSize)
                                        .font(.system(size: max(10, fontSize(for: item.radius) - 2)))
                                        .foregroundStyle(.black.opacity(0.70))
                                }
                            }
                            .position(x: item.center.x, y: item.center.y)
                        }
                        .onTapGesture {
                            handlePrimaryTap(on: item.node)
                        }
                        .onHover { inside in
                            hoveredPath = inside ? item.node.url.path : nil
                        }
                        .scaleEffect(zoomPulse ? 1.0 : 0.94)
                        .opacity(zoomPulse ? 1.0 : 0.82)
                        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: zoomPulse)
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
                animateZoom()
            }
            .onAppear {
                if !didInitialReset {
                    selectedPaths.removeAll()
                    hoveredPath = nil
                    didInitialReset = true
                }
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
            }
            .onChange(of: current.id) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: true)
                animateZoom()
            }
            .onChange(of: geo.size.width) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
            .onChange(of: geo.size.height) {
                recalcLayoutIfNeeded(current: current, size: geo.size, force: false)
            }
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

        let maxSize = Double(max(items.first?.sizeInBytes ?? 1, 1))
        let baseRadii: [CGFloat] = items.map { child in
            let factor = sqrt(Double(max(child.sizeInBytes, 1)) / maxSize)
            let maxR = min(84, minCanvas * 0.16)
            return CGFloat(24 + factor * maxR)
        }

        // Deterministic ring layout is much faster than iterative force relaxation and keeps
        // bubbles distributed around the center in a predictable way.
        let ringCaps = [6, 10, 14, 18]
        var output: [BubbleLayoutItem] = []
        var index = 0
        var ring = 0

        while index < items.count {
            let cap = ring < ringCaps.count ? ringCaps[ring] : (18 + ring * 2)
            let count = min(cap, items.count - index)
            let ringDistance = coreRadius + 26 + CGFloat(ring) * (minCanvas * 0.12 + 18)
            let stagger = ring.isMultiple(of: 2) ? 0.0 : (Double.pi / Double(max(count, 1)))
            let yScale: CGFloat = width > height ? 0.82 : 1.0

            for slot in 0..<count {
                let node = items[index]
                let shrink = max(0.72, 1.0 - CGFloat(ring) * 0.08)
                let radius = baseRadii[index] * shrink
                let angle = (-Double.pi / 2) + (2 * Double.pi * Double(slot) / Double(max(count, 1))) + stagger
                var x = center.x + CGFloat(cos(angle)) * ringDistance
                var y = center.y + CGFloat(sin(angle)) * ringDistance * yScale

                x = min(max(x, radius + 10), width - radius - 10)
                y = min(max(y, radius + 10), height - radius - 10)
                output.append(BubbleLayoutItem(node: node, center: CGPoint(x: x, y: y), radius: radius))
                index += 1
            }
            ring += 1
        }

        return output
    }

    private func animateZoom() {
        zoomPulse = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            zoomPulse = true
        }
    }

    private func recalcLayoutIfNeeded(current: FileNode, size: CGSize, force: Bool) {
        let nodeChanged = cachedNodeID != current.id
        let widthChanged = abs(size.width - cachedSize.width) > 24
        let heightChanged = abs(size.height - cachedSize.height) > 24
        guard force || nodeChanged || widthChanged || heightChanged else { return }
        cachedLayout = packedLayout(for: current, in: size, maxItems: 24)
        cachedNodeID = current.id
        cachedSize = size
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
