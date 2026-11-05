import SwiftUI

enum InterfaceStyle {
    static let accent = Color(red: 0.68, green: 0.85, blue: 0.75)
    static let canvas = Color(red: 0.085, green: 0.095, blue: 0.105)
    static let surface = Color(red: 0.12, green: 0.135, blue: 0.145)
    static let motion = Animation.spring(response: 0.26, dampingFraction: 0.86)
}

/// A shared interaction vocabulary. The native Button keeps its keyboard semantics.
struct FluidButtonStyle: ButtonStyle {
    var prominent = false
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @State private var hovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .medium))
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 7 : 10)
            .foregroundStyle(prominent ? InterfaceStyle.canvas : Color.primary)
            .background(prominent ? InterfaceStyle.accent : Color.white.opacity(hovering ? 0.13 : 0.065), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(focused ? InterfaceStyle.accent : .clear, lineWidth: 2))
            .brightness(hovering && prominent ? 0.06 : 0)
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(!enabled || reduceMotion ? 1 : configuration.isPressed ? 0.97 : hovering ? 1.015 : 1)
            .animation(reduceMotion ? nil : InterfaceStyle.motion, value: hovering)
            .animation(reduceMotion ? nil : InterfaceStyle.motion, value: configuration.isPressed)
            .onHover { hovering = $0 }
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct SidebarLabel: View {
    let title: String
    let symbol: String
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 13, weight: .medium))
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(hovering ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 6))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
            .onHover { hovering = $0 }
    }
}

struct WallpaperCard: View {
    let scene: Wallpaper
    let thumbnail: NSImage?
    let selected: Bool
    let applied: Bool
    let favourite: Bool
    let select: () -> Void
    let toggleFavourite: () -> Void
    @State private var hovering = false
    @FocusState private var previewFocused: Bool
    @FocusState private var favouriteFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: select) {
                VStack(alignment: .leading, spacing: 0) {
                    GeometryReader { bounds in
                    ZStack(alignment: .bottomLeading) {
                        Color.black
                        if let thumbnail { Image(nsImage: thumbnail).resizable().scaledToFill().frame(width: bounds.size.width, height: 132).clipped() }
                        else { Image(systemName: "film").font(.title).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
                        if hovering {
                            Label("Preview", systemImage: "play.fill")
                                .font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.black.opacity(0.75), in: Capsule()).padding(10)
                                .transition(.opacity)
                        }
                    }.frame(width: bounds.size.width, height: 132).clipped()
                    }.frame(height: 132)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(scene.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        HStack(spacing: 5) {
                            if applied { Image(systemName: "desktopcomputer").foregroundStyle(InterfaceStyle.accent) }
                            Text(applied ? "On desktop" : selected ? "Previewing" : scene.category)
                        }.font(.caption).foregroundStyle(applied || selected ? InterfaceStyle.accent : .secondary)
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(InterfaceStyle.surface)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected || previewFocused ? InterfaceStyle.accent : Color.white.opacity(hovering ? 0.3 : 0.06), lineWidth: selected || previewFocused ? 2 : 1))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).focused($previewFocused)
                .accessibilityLabel("Preview \(scene.title)")
                .accessibilityValue(applied ? "On desktop" : selected ? "Selected for preview" : "")
                .help("Preview \(scene.title). Choose Set Wallpaper to use it on your desktop.")
            Button(action: toggleFavourite) {
                Image(systemName: favourite ? "heart.fill" : "heart")
                    .font(.system(size: 13, weight: .semibold)).frame(width: 30, height: 30)
                    .foregroundStyle(favourite ? InterfaceStyle.accent : .white)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(favouriteFocused ? InterfaceStyle.accent : .clear, lineWidth: 2))
            }.buttonStyle(.plain).focused($favouriteFocused).padding(9)
                .accessibilityLabel("\(favourite ? "Remove" : "Add") \(scene.title) \(favourite ? "from" : "to") favourites")
                .help(favourite ? "Remove from favourites" : "Save to favourites")
        }
        .scaleEffect(hovering && !reduceMotion ? 1.018 : 1)
        .shadow(color: .black.opacity(hovering ? 0.22 : 0), radius: 10, y: 5)
        .animation(reduceMotion ? nil : InterfaceStyle.motion, value: hovering)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selected)
        .onHover { hovering = $0 }
    }
}
