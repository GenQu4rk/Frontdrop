import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: LibraryStore
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State<String> private var section = "Browse"
    @StateObject private var catalogue = CatalogueSession()
    @State<String> private var search = ""
    @State<Bool> private var previewPlaying = true
    @State<Wallpaper?> private var pendingDelete: Wallpaper?
    @State private var isDropTargeted = false
    private let accent = Color(red: 0.66, green: 0.83, blue: 0.71)
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
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image(nsImage: BrandAssets.logo).resizable().scaledToFit()
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Frontdrop").font(.headline)
                        Text("A little atmosphere.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal,16).padding(.top,20)
                List(selection: $section) {
                    Section("Discover") {
                        Label("Browse", systemImage: "globe").tag("Browse").padding(.vertical,3)
                        ForEach(CatalogueSource.discoverSources) { source in
                            Label(source.rawValue, systemImage: source.symbol).tag(source.sectionID).padding(.vertical,3)
                        }
                    }
                    Section("Library") {
                        ForEach(sections, id: \.0) { item in
                            Label(item.0, systemImage: item.1).tag(item.0)
                                .padding(.vertical,3)
                        }
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Button { if model.chooseVideos() { section = "Imported" } } label: {
                        Label("Add your own MP4…", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.importing)
                    Text("Choose a file from your Mac, or drop a video anywhere in this window.")
                        .font(.caption).foregroundStyle(.secondary)
                    Label("Yours, without limits", systemImage: "checkmark.seal").font(.callout.weight(.medium))
                    Text("Community videos. Your own collection.\nNo Frontdrop subscription.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Menu("Find free videos") {
                        Link("Anime & games · MotionBGS", destination: URL(string: "https://motionbgs.com/")!)
                        Link("Nature · Pexels", destination: URL(string: "https://www.pexels.com/search/videos/nature/")!)
                    }.font(.caption)
                    Button("How Frontdrop works") { openReport() }.buttonStyle(.link).font(.caption)
                }.padding(16)
            }
            .frame(height: available.size.height)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
        } detail: {
            VStack(spacing: 0) {
                if isBrowsing {
                    CatalogueView(session: catalogue) { scene in
                        model.selectedID = scene.id
                        section = "Downloaded"
                    }
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section).font(.system(size: 28, weight: .semibold))
                            Spacer()
                            Text("\(visible.count) \(visible.count == 1 ? "wallpaper" : "wallpapers")").font(.callout).foregroundStyle(.secondary)
                        }
                        selectedScene
                        HStack {
                            Text("Your collection").font(.title3.weight(.semibold))
                            Spacer()
                            Text("Select a scene to preview").font(.caption).foregroundStyle(.secondary)
                        }
                        if visible.isEmpty {
                            ContentUnavailableView(section == "Favourites" ? "Keep your favourites here" : "No wallpapers found", systemImage: section == "Favourites" ? "heart" : "film", description: Text(section == "Imported" ? "Import an MP4 or MOV to make it your wallpaper." : "Try another category or search. Use the heart to save a favourite."))
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 16)], spacing: 20) {
                                ForEach(visible) { scene in sceneCard(scene) }
                            }
                        }
                    }.padding(24)
                }
                Divider()
                HStack(spacing: 10) {
                    Circle().fill(model.state.enabled ? accent : Color.secondary).frame(width: 6,height: 6)
                    Text(model.status).font(.caption)
                    if model.state.enabled { Text("·  \(model.active.title)").font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    if model.state.enabled {
                        Button { model.togglePause() } label: { Image(systemName: model.state.manuallyPaused ? "play.fill" : "pause.fill") }.help(model.state.manuallyPaused ? "Resume wallpaper" : "Pause wallpaper")
                        Button("Stop") { model.stop() }.help("Return to your macOS wallpaper")
                    }
                }.buttonStyle(.borderless).padding(.horizontal,24).padding(.vertical,12)
                }
            }
            .frame(height: available.size.height)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: available.size.width, height: available.size.height)
        .tint(accent)
        .toolbar {
            ToolbarItem { Button { if model.chooseVideos() { section = "Imported" } } label: { Label("Add Video File…",systemImage: "plus") }.disabled(model.importing).help("Choose an MP4, MOV, or another playable video from your Mac") }
            ToolbarItem { SettingsLink { Image(systemName: "slider.horizontal.3") }.help("Playback settings") }
        }
        .searchable(text: $search, placement: .toolbar, prompt: isBrowsing ? "Search catalogue" : "Search wallpapers")
        .onSubmit(of: .search) { if isBrowsing { catalogue.search(search) } }
        .onChange(of: section) { _, new in
            search = ""
            if let collection = CatalogueSource.discoverSources.first(where: { $0.sectionID == new }) { catalogue.source = collection }
            else if new == "Browse" { catalogue.source = .all; catalogue.showSources() }
        }
        .onChange(of: catalogue.source) { _, new in
            search = ""
            if isBrowsing { section = new.libraryCategory != nil ? new.sectionID : "Browse" }
        }
        .onChange(of: phase) { _, new in
            if isBrowsing { if new == .active { catalogue.show() } else { catalogue.hide() } }
        }
        .overlay {
            if model.importing { ProgressView("Importing video…").padding(24).background(.regularMaterial,in: RoundedRectangle(cornerRadius: 12)) }
        }
        .overlay {
            if isDropTargeted { RoundedRectangle(cornerRadius: 14).strokeBorder(accent, lineWidth: 3).padding(8).allowsHitTesting(false) }
        }
        .alert("Frontdrop needs your attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .confirmationDialog("Remove \(pendingDelete?.title ?? "video") from Frontdrop?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
            Button("Remove Video", role: .destructive) { if let pendingDelete { model.remove(pendingDelete) }; pendingDelete = nil }
        } message: { Text("The copy in your Frontdrop library will be deleted. Your original video will stay where it is.") }
        .onAppear { model.start() }
        .dropDestination(for: URL.self, action: { urls, _ in
            guard !urls.isEmpty, urls.allSatisfy(\.isFileURL) else { return false }
            Task { @MainActor in
                if model.addVideos(urls) { section = "Imported" }
            }
            return true
        }, isTargeted: { isDropTargeted = $0 })
        }
        .frame(minWidth: 920, minHeight: 660)
    }
    private var selectedScene: some View {
        HStack(alignment: .top, spacing: 24) {
            ZStack(alignment: .bottomLeading) {
                ScenePreview(scene: model.selected, url: model.videoURL(for: model.selected), thumbnail: model.thumbnails[model.selected.id], playing: previewPlaying && phase == .active && !reduceMotion, fps: model.state.fps, onError: { model.error = $0.localizedDescription })
                    .aspectRatio(1.6, contentMode: .fit)
                Button { previewPlaying.toggle() } label: {
                    Label(previewPlaying && !reduceMotion ? "Pause preview" : "Preview paused", systemImage: previewPlaying && !reduceMotion ? "pause.fill" : "play.fill")
                        .font(.caption).padding(.horizontal,10).padding(.vertical,7)
                        .background(.ultraThinMaterial,in: Capsule())
                }.buttonStyle(.plain).padding(12).disabled(reduceMotion)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Animated preview of \(model.selected.title)")
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.selected.title).font(.title2.weight(.semibold)).fixedSize(horizontal: false,vertical: true)
                    Text(model.selected.subtitle).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
                }
                HStack(spacing: 6) {
                    Image(systemName: model.selected.shader == nil ? "film" : "sparkles")
                    Text(model.selected.shader == nil ? "Local video" : "Original scene")
                }.font(.caption).foregroundStyle(.secondary)
                Picker("Display", selection: $model.state.target) {
                    Text("All displays").tag("all")
                    Text("Main display").tag("main")
                    ForEach(model.screens, id: \.id) { screen in Text(screen.name).tag(screen.id) }
                    if !["all","main"].contains(model.state.target) && !model.screens.contains(where: { $0.id == model.state.target }) {
                        Text("Disconnected (uses main)").tag(model.state.target)
                    }
                }.labelsHidden().help("Choose which display receives this wallpaper")
                if model.selected.shader == nil {
                    Text("Video framing").font(.caption).foregroundStyle(.secondary)
                    Picker("Video framing", selection: Binding(get: { model.selected.framing }, set: { model.setVideoFraming($0, for: model.selected) })) {
                        ForEach(VideoFraming.allCases) { framing in Text(framing.rawValue).tag(framing) }
                    }.labelsHidden().help("Fit shows the complete video with black bars if needed. Fill covers the display and crops its edges.")
                    Text(model.selected.framing == .fit ? "Shows every edge. Black bars may appear." : "Covers the display. Edges may be cropped.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Button { model.apply() } label: {
                    Text(model.state.enabled && model.state.activeID == model.selected.id ? "Apply Again" : "Set Wallpaper").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.return,modifiers: [.command])
                Button { model.favourite(model.selected) } label: {
                    Label(model.state.favourites.contains(model.selected.id) ? "Saved to favourites" : "Add to favourites",systemImage: model.state.favourites.contains(model.selected.id) ? "heart.fill" : "heart")
                }.buttonStyle(.borderless).font(.callout)
                if let source = model.selected.sourceURL.flatMap(URL.init(string:)), CataloguePolicy.isWebURL(source) {
                    Link("View original page", destination: source).font(.caption)
                }
                Text(model.state.enabled && model.state.activeID == model.selected.id ? "Currently on your desktop" : "Preview only until you set it.")
                    .font(.caption).foregroundStyle(.secondary)
            }.frame(width: 200,alignment: .leading).padding(.top,4)
        }
    }
    private func sceneCard(_ scene: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.selectedID = scene.id } label: {
                ZStack {
                    Color.black
                    if let image = model.thumbnails[scene.id] { Image(nsImage: image).resizable().scaledToFill() }
                    else { Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary) }
                }
                .frame(height: 122).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(scene.id == model.selectedID ? accent : .clear,lineWidth: 2))
                .contentShape(Rectangle())
            }.buttonStyle(.plain).help("Preview \(scene.title)")
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scene.title).font(.callout.weight(.medium)).lineLimit(1)
                    Text(model.state.enabled && model.state.activeID == scene.id ? "On your desktop" : scene.category).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 2)
                Button { model.favourite(scene) } label: {
                    Image(systemName: model.state.favourites.contains(scene.id) ? "heart.fill" : "heart").foregroundStyle(model.state.favourites.contains(scene.id) ? accent : .secondary)
                }.buttonStyle(.borderless).help("Favourite \(scene.title)")
            }
        }
        .contextMenu {
            Button("Set Wallpaper") { model.apply(scene) }
            Button(model.state.favourites.contains(scene.id) ? "Remove Favourite" : "Add Favourite") { model.favourite(scene) }
            if scene.shader == nil { Divider(); Button("Remove Video…",role: .destructive) { pendingDelete = scene } }
        }
    }
    private func openReport() {
        if let url = Bundle.main.url(forResource: "Evidence",withExtension: "md") { NSWorkspace.shared.open(url) }
    }
}

struct PlaybackSettings: View {
    @EnvironmentObject var model: LibraryStore
    @State private var checkingForUpdates = false
    @State private var updateStatus: String?
    @State private var updateURL: URL?
    var body: some View {
        Form {
            Section("Playback") {
                Picker("Scene animation",selection: $model.state.fps) {
                    Text("24 fps · economical").tag(24)
                    Text("30 fps · balanced").tag(30)
                    Text("60 fps · smooth").tag(60)
                }
                Toggle("Pause on battery power",isOn: $model.state.pauseOnBattery)
                Toggle("Pause in Low Power Mode",isOn: $model.state.pauseInLowPower)
                Toggle("Pause behind fullscreen apps",isOn: $model.state.pauseInFullscreen)
                Text("Display sleep and locking your Mac always pause playback. Videos play at their original frame rate.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Rotation") {
                Picker("Change wallpaper",selection: $model.state.rotationMinutes) {
                    Text("Never").tag(0)
                    Text("Every 5 minutes").tag(5)
                    Text("Every 15 minutes").tag(15)
                    Text("Every 30 minutes").tag(30)
                    Text("Every hour").tag(60)
                }
                Text("Cycles through your favourites, or the whole collection if you haven’t saved any. Rotation waits while playback is paused.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Frontdrop") {
                Button(checkingForUpdates ? "Checking for Updates…" : "Check for Updates") {
                    Task {
                        checkingForUpdates = true
                        updateStatus = nil
                        updateURL = nil
                        defer { checkingForUpdates = false }
                        do {
                            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
                            #if arch(arm64)
                            let architecture = "arm64"
                            #else
                            let architecture = "x86_64"
                            #endif
                            switch try await UpdateChecker.check(currentVersion: version, architecture: architecture) {
                            case .current:
                                updateStatus = "Frontdrop \(version) is up to date."
                            case .available(let latest, let url):
                                updateStatus = "Frontdrop \(latest) is available."
                                updateURL = url
                            case .noCompatibleDownload(let latest):
                                updateStatus = "Frontdrop \(latest) is available, but has no compatible Mac download yet."
                            }
                        } catch { updateStatus = error.localizedDescription }
                    }
                }.disabled(checkingForUpdates)
                if let updateStatus { Text(updateStatus).font(.caption).foregroundStyle(.secondary) }
                if let updateURL { Link("View Release and Download", destination: updateURL) }
                Toggle("Start at login",isOn: Binding(get: { model.loginEnabled },set: { model.setLogin($0) }))
                Text("Wallpaper storage").font(.caption).foregroundStyle(.secondary)
                Text(model.directory.path).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Button("Show video library in Finder") { NSWorkspace.shared.open(model.directory.appendingPathComponent("Videos")) }
                Text("Desktop wallpapers only. Your macOS Lock Screen stays under macOS control. Stop or quit Frontdrop to reveal your existing wallpaper.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 480,height: 590)
    }
}
