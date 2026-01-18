import SwiftUI

struct BubbleMapView: View {
    let root: FileNode

    var body: some View {
        GeometryReader { geo in
            let items = Array(root.largestChildren.prefix(12))
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.14, green: 0.03, blue: 0.42), Color(red: 0.28, green: 0.10, blue: 0.63)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ForEach(Array(items.enumerated()), id: \.element.id) { idx, node in
                    let radius = max(40.0, min(180.0, CGFloat(node.sizeInBytes) / 150_000_000.0))
                    let x = (geo.size.width * 0.2) + CGFloat((idx % 4)) * (geo.size.width * 0.18)
                    let y = (geo.size.height * 0.25) + CGFloat((idx / 4)) * (geo.size.height * 0.25)

                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 1))
                        .frame(width: radius * 2, height: radius * 2)
                        .position(x: x, y: y)
                        .overlay(alignment: .center) {
                            VStack(spacing: 6) {
                                Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                                    .foregroundStyle(.white.opacity(0.9))
                                Text(node.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(node.formattedSize)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .position(x: x, y: y)
                        }
                }
            }
        }
    }
}
