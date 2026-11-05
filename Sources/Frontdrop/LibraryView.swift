import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: LibraryStore
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section = "All wallpapers"
    @StateObject private var catalogue = CatalogueSession()
    @State private var search = ""
    @State private var previewPlaying = true
    @State private var pendingDelete: Wallpaper?
    @State private var isDropTargeted = false
    private let sections: [(String, String)] = [("All wallpapers", "square.grid.2x2"), ("Favourites", "heart"), ("Nature", "leaf"), ("Abstract", "water.waves"), ("Anime & Games", "sparkles"), ("Space", "moon.stars"), ("Scenes", "video"), ("Downloaded", "arrow.down.circle"), ("Imported", "film")]

    private var isBrowsing: Bool { section == "Browse" || CatalogueSource.discoverSources.contains { $0.sectionID == section } }
    private var visible: [Wallpaper] {
        model.scenes.filter { scene in
            let inSection = section == "All wallpapers" || (section == "Favourites" ? model.state.favourites.contains(scene.id) : (section == "Downloaded" ? scene.sourceURL != nil : scene.category == section))
            return inSection && (search.isEmpty || (scene.title + " " + scene.subtitle).localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        GeometryReader { available in
            NavigationSplitView {
                sidebar.frame(height: available.size.height)
                    .navigationSplitViewColumnWidth(min: 210, ideal: 228, max: 260)
            } detail: {
                VStack(spacing: 0) {
                    if isBrowsing {
                        CatalogueView(session: catalogue) { scene in
                            model.selectedID = scene.id
                            section = scene.sourceURL == nil ? "Imported" : "Downloaded"
                        }
                    } else { gallery }
                    playbackBar
                }
                .frame(height: available.size.height)
                .background(InterfaceStyle.canvas)
            }
            .frame(width: available.size.width, height: available.size.height)
            .tint(InterfaceStyle.accent)
            .toolbar {
                ToolbarItem {
                    Button(action: importFiles) { Label("Add Video…", systemImage: "plus") }
                        .disabled(model.importing).help("Choose MP4 or MOV files from your Mac and name each wallpaper")
                }
                ToolbarItem {
                    SettingsLink { Label("Settings", systemImage: "slider.horizontal.3") }
                        .help("Playback, library and app updates")
                }
            }
            .searchable(text: $search, placement: .toolbar, prompt: isBrowsing ? "Search catalogue" : "Search your library")
            .onSubmit(of: .search) { if isBrowsing { catalogue.search(search) } }
            .onChange(of: section) { _, new in
                search = ""
                if let collection = CatalogueSource.discoverSources.first(where: { $0.sectionID == new }) { catalogue.source = collection }
                else if new == "Browse" { catalogue.source = .all; catalogue.showSources() }
                selectVisibleScene()
            }
            .onChange(of: search) { _, _ in selectVisibleScene() }
            .onChange(of: catalogue.source) { _, new in
                search = ""
                if isBrowsing { section = new.libraryCategory != nil ? new.sectionID : "Browse" }
            }
            .onChange(of: phase) { _, new in
                if isBrowsing { if new == .active { catalogue.show() } else { catalogue.hide() } }
            }
            .overlay {
                if model.importing {
                    HStack(spacing: 12) { ProgressView().controlSize(.small); Text("Adding your video to the library…").font(.callout) }
                        .padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                if isDropTargeted {
                    ZStack {
                        InterfaceStyle.canvas.opacity(0.92)
                        VStack(spacing: 14) {
                            Image(systemName: "arrow.down.doc").font(.system(size: 40))
                            Text("Drop to add your wallpaper").font(.title2.weight(.semibold))
                            Text("You’ll choose a name before it’s added.").foregroundStyle(.secondary)
                        }
                    }.clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(InterfaceStyle.accent, lineWidth: 2))
                        .padding(12).allowsHitTesting(false)
                }
            }
            .alert("Frontdrop needs your attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
            .confirmationDialog("Remove \(pendingDelete?.title ?? "video") from Frontdrop?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Remove Video", role: .destructive) { if let pendingDelete { model.remove(pendingDelete) }; pendingDelete = nil }
            } message: { Text("The copy in your Frontdrop library will be deleted. Your original video will stay where it is.") }
            .onAppear { model.start() }
            .dropDestination(for: URL.self, action: { urls, _ in
                guard !model.importing, !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { return false }
                Task { @MainActor in if model.addVideos(urls) { section = "Imported" } }
                return true
            }, isTargeted: { isDropTargeted = $0 })
        }
        .frame(minWidth: 920, minHeight: 660)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                Image(nsImage: BrandAssets.logo).resizable().scaledToFit().frame(width: 36, height: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Frontdrop").font(.system(size: 17, weight: .semibold))
                    Text("Your desktop, in motion.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20)
            List(selection: $section) {
                Section("Your library") {
                    ForEach(sections, id: \.0) { item in SidebarLabel(title: item.0, symbol: item.1).tag(item.0) }
                }
                Section("Discover online") {
                    SidebarLabel(title: "Browse", symbol: "globe").tag("Browse")
                    ForEach(CatalogueSource.discoverSources) { source in
                        SidebarLabel(title: source.rawValue, symbol: source.symbol).tag(source.sectionID)
                    }
                }
            }.listStyle(.sidebar)
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 10) {
                Button(action: importFiles) { Label("Add Video File…", systemImage: "plus.circle").frame(maxWidth: .infinity) }
                    .buttonStyle(FluidButtonStyle(prominent: true)).disabled(model.importing)
                    .help("Open the file picker to add MP4, MOV or M4V wallpapers")
                Text("Choose an MP4 from your Mac, or drop it into this window.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Menu {
                    Button("How Frontdrop works") { if let url = Bundle.main.url(forResource: "Evidence", withExtension: "md") { NSWorkspace.shared.open(url) } }
                    Link("Find videos on MotionBGS", destination: URL(string: "https://motionbgs.com/")!)
                    Link("Find nature videos on Pexels", destination: URL(string: "https://www.pexels.com/search/videos/nature/")!)
                } label: { Label("Help & Sources", systemImage: "questionmark.circle") }.font(.caption)
            }.padding(16)
        }
    }

    private var gallery: some View {
        GeometryReader { bounds in
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(section).font(.system(size: 28, weight: .semibold))
                        Spacer()
                        Text("\(visible.count) \(visible.count == 1 ? "wallpaper" : "wallpapers")").font(.callout).foregroundStyle(.secondary)
                    }
                    Text("Select a wallpaper to preview it. Apply it when it feels right.").font(.callout).foregroundStyle(.secondary)
                }
                if visible.isEmpty {
                    ContentUnavailableView {
                        Label(search.isEmpty && section == "Favourites" ? "Your favourites start here" : "No wallpapers here yet", systemImage: section == "Favourites" ? "heart" : "film")
                    } description: {
                        Text(!search.isEmpty ? "No titles match “\(search)”. Try a different search." : section == "Favourites" ? "Use the heart on any wallpaper to save it here." : "Add a video from your Mac, or explore another collection.")
                    } actions: {
                        if !search.isEmpty { Button("Clear Search") { search = "" }.buttonStyle(FluidButtonStyle()) }
                        else if section == "Favourites" { Button("Explore Your Library") { section = "All wallpapers" }.buttonStyle(FluidButtonStyle()) }
                        else { Button("Add Video File…", action: importFiles).buttonStyle(FluidButtonStyle(prominent: true)) }
                    }.frame(minHeight: 300)
                } else {
                    selectedScene
                    HStack {
                        Text("Choose a wallpaper").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Label("Hearts save favourites", systemImage: "heart").font(.caption).foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 18)], spacing: 18) {
                        ForEach(visible) { scene in
                            WallpaperCard(scene: scene, thumbnail: model.thumbnails[scene.id], selected: model.selectedID == scene.id, applied: model.state.enabled && model.state.activeID == scene.id, favourite: model.state.favourites.contains(scene.id), select: { model.selectedID = scene.id }, toggleFavourite: { model.favourite(scene) })
                                .contextMenu {
                                    Button("Set Wallpaper") { model.apply(scene) }
                                    Button(model.state.favourites.contains(scene.id) ? "Remove Favourite" : "Add Favourite") { model.favourite(scene) }
                                    if scene.shader == nil { Divider(); Button("Remove Video…", role: .destructive) { pendingDelete = scene } }
                                }
                        }
                    }
                }
            }.frame(width: max(0, bounds.size.width - 52), alignment: .leading).padding(26)
        }
        }
    }

    private var selectedScene: some View {
        HStack(alignment: .top, spacing: 22) {
            ZStack(alignment: .bottomLeading) {
                ScenePreview(scene: model.selected, url: model.videoURL(for: model.selected), thumbnail: model.thumbnails[model.selected.id], playing: previewPlaying && phase == .active && !reduceMotion, fps: model.state.fps, onError: { model.error = $0.localizedDescription })
                    .frame(maxWidth: .infinity).frame(height: 260).accessibilityHidden(true)
                Button { previewPlaying.toggle() } label: {
                    Label(previewPlaying && !reduceMotion ? "Pause Preview" : "Play Preview", systemImage: previewPlaying && !reduceMotion ? "pause.fill" : "play.fill")
                }.buttonStyle(FluidButtonStyle(compact: true)).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 9)).padding(12).disabled(reduceMotion)
                    .help(reduceMotion ? "Animated previews are off because Reduce Motion is enabled in macOS" : "Only controls this preview, not your desktop wallpaper")
            }.clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.selected.title).font(.system(size: 22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(model.selected.subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Label(model.state.enabled && model.state.activeID == model.selected.id ? "On your desktop" : "Preview only", systemImage: model.state.enabled && model.state.activeID == model.selected.id ? "desktopcomputer" : "play.rectangle")
                    .font(.caption.weight(.medium)).foregroundStyle(InterfaceStyle.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Show on").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Picker("Display", selection: $model.state.target) {
                        Text("All displays").tag("all")
                        Text("Main display").tag("main")
                        ForEach(model.screens, id: \.id) { screen in Text(screen.name).tag(screen.id) }
                        if !["all", "main"].contains(model.state.target) && !model.screens.contains(where: { $0.id == model.state.target }) { Text("Disconnected (uses main)").tag(model.state.target) }
                    }.labelsHidden().help("Choose which display receives your wallpaper")
                }
                if model.selected.shader == nil {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Video framing").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        Picker("Video framing", selection: Binding(get: { model.selected.framing }, set: { model.setVideoFraming($0, for: model.selected) })) {
                            ForEach(VideoFraming.allCases) { Text($0.rawValue).tag($0) }
                        }.labelsHidden()
                        Text(model.selected.framing == .fit ? "Shows the whole video. May add black bars." : "Fills the screen. May crop the edges.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Button { model.apply() } label: { Label("Set Wallpaper", systemImage: "desktopcomputer").frame(maxWidth: .infinity) }
                    .buttonStyle(FluidButtonStyle(prominent: true)).keyboardShortcut(.return, modifiers: [.command])
                    .help("Apply \(model.selected.title) to the selected displays (⌘Return)")
                Button { model.favourite(model.selected) } label: {
                    Label(model.state.favourites.contains(model.selected.id) ? "Saved to Favourites" : "Save to Favourites", systemImage: model.state.favourites.contains(model.selected.id) ? "heart.fill" : "heart")
                }.buttonStyle(FluidButtonStyle(compact: true))
                if let source = model.selected.sourceURL.flatMap(URL.init(string:)), CataloguePolicy.isWebURL(source) { Link("View Original Source ↗", destination: source).font(.caption) }
            }.frame(width: 220, alignment: .leading)
        }
        .padding(18).background(InterfaceStyle.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var playbackBar: some View {
        HStack(spacing: 12) {
            Image(systemName: model.state.enabled ? "desktopcomputer" : "display").font(.system(size: 18)).foregroundStyle(model.state.enabled ? InterfaceStyle.accent : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.state.enabled ? model.active.title : "Your macOS wallpaper is showing").font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(model.state.enabled ? model.status : "Choose a wallpaper, then click Set Wallpaper.").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.state.enabled {
                Button { model.togglePause() } label: { Label(model.state.manuallyPaused ? "Resume" : "Pause", systemImage: model.state.manuallyPaused ? "play.fill" : "pause.fill") }
                    .buttonStyle(FluidButtonStyle(compact: true)).help("Pause or resume your desktop wallpaper")
                Button("Stop") { model.stop() }.buttonStyle(FluidButtonStyle(compact: true)).help("Stop playback and reveal your saved macOS wallpaper")
            }
        }.padding(.horizontal, 24).padding(.vertical, 13).background(InterfaceStyle.surface)
    }

    private func importFiles() { if model.chooseVideos() { section = "Imported" } }
    private func selectVisibleScene() {
        if !isBrowsing, !visible.contains(where: { $0.id == model.selectedID }), let first = visible.first { model.selectedID = first.id }
    }
}
