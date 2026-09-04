import SwiftUI

struct WheelView: View {
    /// Overlay panel height; OverlayWindowController sizes the panel from these.
    static let dockHeight: CGFloat = 320

    static func dockContentWidth(spacing: Double, count: Int, cardWidth: Double, zoom: Double) -> CGFloat {
        CGFloat(spacing * Double(max(count, 1)) + cardWidth * zoom + 160)
    }

    static func dockPanelSize(spacing: Double, count: Int, cardWidth: Double, zoom: Double) -> CGSize {
        let row = dockContentWidth(spacing: spacing, count: count, cardWidth: cardWidth, zoom: zoom)
        // Cap at 75% of the screen so many spaces never wall off the desktop;
        // past the cap the row becomes a carousel that follows the highlight.
        let cap = (NSScreen.main?.frame.width ?? 1600) * 0.75
        return CGSize(width: min(max(900, row), cap), height: dockHeight)
    }

    @ObservedObject var controller: WheelController
    @ObservedObject var snapshots: SnapshotStore
    @ObservedObject var settings: SettingsStore

    var body: some View {
        dockBody
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: controller.selectedIndex)
    }

    // MARK: - Dock layout

    private var dockBody: some View {
        let count = controller.spaces.count
        let spacing = CGFloat(settings.dockSpacing)
        let contentWidth = Self.dockContentWidth(
            spacing: settings.dockSpacing, count: count,
            cardWidth: settings.cardWidth, zoom: settings.zoomScale
        )
        let size = Self.dockPanelSize(
            spacing: settings.dockSpacing, count: count,
            cardWidth: settings.cardWidth, zoom: settings.zoomScale
        )
        // Carousel: when the row is wider than the panel, it shifts to keep
        // the highlight centered, clamped so the row's ends stay pinned to
        // the panel's edges.
        let selectedX = (CGFloat(controller.selectedIndex) - CGFloat(count - 1) / 2) * spacing
        let maxShift = max(0, (contentWidth - size.width) / 2)
        let carouselShift = min(max(-selectedX, -maxShift), maxShift)
        let overflowing = maxShift > 0

        return ZStack {
            ZStack {
                ForEach(Array(controller.spaces.enumerated()), id: \.element.id) { index, space in
                    let selected = index == controller.selectedIndex
                    // Neighbors move away by the highlight's extra half-width,
                    // so the visible gap stays constant while it zooms.
                    let zoomShift = CGFloat(settings.cardWidth) * CGFloat(settings.zoomScale - 1) / 2
                    let side: CGFloat = selected ? 0 : (index < controller.selectedIndex ? -1 : 1)
                    let x = (CGFloat(index) - CGFloat(count - 1) / 2) * spacing + side * zoomShift

                    card(for: space, at: index, selected: selected)
                        .scaleEffect(selected ? CGFloat(settings.zoomScale) : 1.0)
                        .offset(x: x)
                        .zIndex(selected ? 1 : 0)
                }
            }
            .offset(x: carouselShift)
            .mask(edgeFade(active: overflowing).frame(width: size.width, height: size.height))

            Text(controller.spaces.indices.contains(controller.selectedIndex) ? controller.spaces[controller.selectedIndex].label : "")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.6), radius: 6)
                .offset(y: CGFloat(settings.cardWidth) * 42.0 / 68.0 / 2 * CGFloat(settings.zoomScale) + 30)
        }
        .frame(width: size.width, height: size.height)
    }

    private func edgeFade(active: Bool) -> LinearGradient {
        let fade: CGFloat = active ? 0.06 : 0
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: fade),
                .init(color: .black, location: 1 - fade),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading, endPoint: .trailing
        )
    }

    // MARK: - Shared pieces

    private func card(for space: SpaceInfo, at index: Int, selected: Bool) -> some View {
        ZStack {
            if let image = snapshots.images[space.id] {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let wallpaper = snapshots.wallpaper {
                // Not visited yet: the desktop wallpaper reads far more
                // native than a flat placeholder.
                Image(decorative: wallpaper, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color(white: 0.30), Color(white: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(width: CGFloat(settings.cardWidth), height: CGFloat(settings.cardWidth) * 42.0 / 68.0)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    selected ? Color.white : Color.white.opacity(0.15),
                    lineWidth: selected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(selected ? 0.5 : 0.25), radius: selected ? 12 : 5, y: 3)
        // Unfocused cards step back: desaturated and dimmed, so overlapping
        // neighbors at high zoom read as background, not clutter.
        .saturation(selected ? 1.0 : 0.55)
        .opacity(selected ? 1.0 : 0.78)
    }
}
