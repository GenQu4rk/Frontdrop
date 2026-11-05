import SwiftUI

struct PlaybackSettings: View {
    @EnvironmentObject var model: LibraryStore
    @State private var checkingForUpdates = false
    @State private var updateStatus: String?
    @State private var updateURL: URL?
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }

    var body: some View {
        TabView {
            Form {
                Section("Playback") {
                    Picker("Scene animation", selection: $model.state.fps) {
                        Text("24 fps · economical").tag(24)
                        Text("30 fps · balanced").tag(30)
                        Text("60 fps · smooth").tag(60)
                    }
                    Text("Applies to original scenes. Videos use their original frame rate.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Automatically pause") {
                    Toggle("On battery power", isOn: $model.state.pauseOnBattery)
                    Toggle("In Low Power Mode", isOn: $model.state.pauseInLowPower)
                    Toggle("Behind fullscreen apps", isOn: $model.state.pauseInFullscreen)
                    Text("Locking your Mac or putting its display to sleep always pauses playback.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Wallpaper rotation") {
                    Picker("Change wallpaper", selection: $model.state.rotationMinutes) {
                        Text("Never").tag(0)
                        Text("Every 5 minutes").tag(5)
                        Text("Every 15 minutes").tag(15)
                        Text("Every 30 minutes").tag(30)
                        Text("Every hour").tag(60)
                    }
                    Text("Cycles through favourites, or your whole library if none are saved. Rotation waits while playback is paused.").font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Playback", systemImage: "play.circle") }

            Form {
                Section("Startup") {
                    Toggle("Start Frontdrop at login", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                }
                Section("Your video library") {
                    Text("Imported videos are copied here, so moving an original file won’t break its wallpaper.").font(.callout)
                    Text(model.directory.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    Button { NSWorkspace.shared.open(model.directory.appendingPathComponent("Videos")) } label: {
                        Label("Show Videos in Finder", systemImage: "folder")
                    }.buttonStyle(FluidButtonStyle())
                }
                Section("Using Frontdrop") {
                    Text("Closing the library keeps your wallpaper running. Use the menu bar to reopen Frontdrop, pause, or stop playback.")
                    Text("Stop or quit to reveal your saved macOS wallpaper. Your Lock Screen stays under macOS control.").foregroundStyle(.secondary)
                }
            }.formStyle(.grouped).tabItem { Label("Library", systemImage: "folder") }

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    Image(nsImage: BrandAssets.logo).resizable().scaledToFit().frame(width: 54, height: 54).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Frontdrop").font(.title2.weight(.semibold))
                        Text("Installed version \(version)").font(.callout).foregroundStyle(.secondary)
                    }
                }
                Text("Keep your desktop moving.").font(.title3.weight(.medium))
                Text("Check for the latest release, then download the new app. Quit Frontdrop and replace your installed copy to update.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(action: checkForUpdates) {
                    HStack(spacing: 8) {
                        if checkingForUpdates { ProgressView().controlSize(.small) }
                        else { Image(systemName: "arrow.triangle.2.circlepath") }
                        Text(checkingForUpdates ? "Checking…" : "Check for Updates")
                    }
                }.buttonStyle(FluidButtonStyle(prominent: true)).disabled(checkingForUpdates)
                if let updateStatus {
                    Text(updateStatus).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
                if let updateURL {
                    Link(destination: updateURL) { Label("Download New Version", systemImage: "arrow.down.circle") }
                        .buttonStyle(FluidButtonStyle(prominent: true))
                }
                Spacer()
                Link("View All Releases on GitHub ↗", destination: URL(string: "https://github.com/GenQu4rk/Frontdrop/releases")!).font(.callout)
            }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .tint(InterfaceStyle.accent).frame(width: 540, height: 540)
        .preferredColorScheme(.dark)
    }

    private func checkForUpdates() {
        checkingForUpdates = true
        updateStatus = nil
        updateURL = nil
        Task {
            defer { checkingForUpdates = false }
            #if arch(arm64)
            let architecture = "arm64"
            #else
            let architecture = "x86_64"
            #endif
            do {
                switch try await UpdateChecker.check(currentVersion: version, architecture: architecture) {
                case .current: updateStatus = "You’re up to date. No newer release is available."
                case .available(let latest, let url):
                    updateStatus = "Frontdrop \(latest) is ready to download."
                    updateURL = url
                case .noCompatibleDownload(let latest): updateStatus = "Frontdrop \(latest) is available, but a download for this Mac isn’t ready yet."
                }
            } catch { updateStatus = "Couldn’t check for updates. \(error.localizedDescription)" }
        }
    }
}
