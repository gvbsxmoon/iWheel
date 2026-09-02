import SwiftUI

struct WheelView: View {
    /// Overlay panel side; OverlayWindowController sizes the panel from this.
    static let overlaySide: CGFloat = 680

    @ObservedObject var controller: WheelController
    @ObservedObject var snapshots: SnapshotCache
    @ObservedObject var settings: SettingsStore

    private var ringRadius: CGFloat { CGFloat(settings.ringRadius) }

    var body: some View {
        ZStack {
            centerLabel

            ForEach(Array(controller.spaces.enumerated()), id: \.element.id) { index, space in
                card(for: space, at: index)
            }
        }
        .frame(width: Self.overlaySide, height: Self.overlaySide)
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: controller.selectedIndex)
    }

    private var centerLabel: some View {
        Text("\(controller.selectedIndex + 1)")
            .font(.system(size: 56, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .shadow(color: .black.opacity(0.6), radius: 8)
    }

    private func card(for space: SpaceInfo, at index: Int) -> some View {
        let count = max(controller.spaces.count, 1)
        // Desktop 1 at 12 o'clock, clockwise.
        let degrees = (Double(index) / Double(count)) * 360.0 - 90.0
        let rad = degrees * .pi / 180
        let selected = index == controller.selectedIndex

        return ZStack {
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
        .frame(width: 68, height: 42)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(
                    selected ? Color.white : Color.white.opacity(0.15),
                    lineWidth: selected ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(selected ? 0.5 : 0.25), radius: selected ? 12 : 5, y: 3)
        .scaleEffect(selected ? CGFloat(settings.zoomScale) : 1.0)
        .opacity(selected ? 1.0 : 0.85)
        .offset(x: CGFloat(cos(rad)) * ringRadius, y: CGFloat(sin(rad)) * ringRadius)
    }
}
