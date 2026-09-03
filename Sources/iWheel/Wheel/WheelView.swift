import SwiftUI

struct WheelView: View {
    /// Overlay panel sizes; OverlayWindowController sizes the panel from these.
    static let overlaySide: CGFloat = 680
    static let dockHeight: CGFloat = 320

    static func dockPanelSize(spacing: Double, count: Int, cardWidth: Double, zoom: Double) -> CGSize {
        let row = spacing * Double(max(count, 1)) + cardWidth * zoom + 160
        return CGSize(width: max(900, row), height: dockHeight)
    }

    @ObservedObject var controller: WheelController
    @ObservedObject var snapshots: SnapshotCache
    @ObservedObject var settings: SettingsStore

    private var ringRadius: CGFloat { CGFloat(settings.ringRadius) }

    var body: some View {
        Group {
            if settings.layout == .dock {
                dockBody
            } else {
                wheelBody
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: controller.selectedIndex)
    }

    // MARK: - Wheel layout

    private var wheelBody: some View {
        ZStack {
            centerLabel

            ForEach(Array(controller.spaces.enumerated()), id: \.element.id) { index, space in
                let selected = index == controller.selectedIndex
                let count = max(controller.spaces.count, 1)
                // Desktop 1 at 12 o'clock, clockwise.
                let degrees = (Double(index) / Double(count)) * 360.0 - 90.0
                let rad = degrees * .pi / 180

                card(for: space, at: index, selected: selected)
                    .scaleEffect(selected ? CGFloat(settings.zoomScale) : 1.0)
                    .offset(x: CGFloat(cos(rad)) * ringRadius, y: CGFloat(sin(rad)) * ringRadius)
                    .zIndex(selected ? 1 : 0)
            }
        }
        .frame(width: Self.overlaySide, height: Self.overlaySide)
    }

    // MARK: - Dock layout

    private var dockBody: some View {
        let size = Self.dockPanelSize(
            spacing: settings.dockSpacing,
            count: controller.spaces.count,
            cardWidth: settings.cardWidth,
            zoom: settings.zoomScale
        )
        return ZStack {
            ForEach(Array(controller.spaces.enumerated()), id: \.element.id) { index, space in
                let selected = index == controller.selectedIndex
                let count = controller.spaces.count
                let spacing = CGFloat(settings.dockSpacing)
                // Neighbors move away by the highlight's extra half-width,
                // so the visible gap stays constant while it zooms.
                let zoomShift = CGFloat(settings.cardWidth) * CGFloat(settings.zoomScale - 1) / 2
                let side: CGFloat = index == controller.selectedIndex ? 0 : (index < controller.selectedIndex ? -1 : 1)
                let x = (CGFloat(index) - CGFloat(count - 1) / 2) * spacing + side * zoomShift

                // All unfocused cards share the same size; only the
                // highlight enlarges, centered on the row's axis.
                card(for: space, at: index, selected: selected)
                    .scaleEffect(selected ? CGFloat(settings.zoomScale) : 1.0)
                    .offset(x: x)
                    .zIndex(selected ? 1 : 0)
            }

            Text("\(controller.selectedIndex + 1)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .shadow(color: .black.opacity(0.6), radius: 6)
                .offset(y: 90)
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Shared pieces

    private var centerLabel: some View {
        Text("\(controller.selectedIndex + 1)")
            .font(.system(size: 56, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .shadow(color: .black.opacity(0.6), radius: 8)
    }

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
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.7), radius: 3)
            } else {
                LinearGradient(
                    colors: [Color(white: 0.30), Color(white: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
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
