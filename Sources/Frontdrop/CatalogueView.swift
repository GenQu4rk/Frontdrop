import SwiftUI
import WebKit

struct CatalogueWebView: NSViewRepresentable {
    let session: CatalogueSession
    func makeNSView(context: Context) -> WKWebView { session.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct CatalogueView: View {
    @EnvironmentObject private var model: LibraryStore
    @ObservedObject var session: CatalogueSession
    let showLibrary: (Wallpaper) -> Void
    var body: some View {
        VStack(spacing: 0) {
            if session.showsDirectory { sourceDirectory }
            else {
                browserControls
                Divider()
                CatalogueWebView(session: session).frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.nextPage != nil || session.previousPage != nil {
                    HStack {
                        Text("Keep exploring").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Previous Page") { if let url = session.previousPage { session.load(url) } }.disabled(session.previousPage == nil || session.loading)
                        Button("Next Page") { if let url = session.nextPage { session.load(url) } }.disabled(session.nextPage == nil || session.loading)
                    }.buttonStyle(FluidButtonStyle(compact: true)).padding(.horizontal, 20).padding(.vertical, 10)
                }
            }
            if let message = session.message {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text(message).font(.callout).textSelection(.enabled)
                    Spacer()
                    Button("Retry") { session.retry() }
                    Button { session.message = nil } label: { Image(systemName: "xmark") }.accessibilityLabel("Dismiss message")
                }.buttonStyle(FluidButtonStyle(compact: true)).padding(16).background(InterfaceStyle.surface)
            }
            if let status = session.downloadStatus {
                HStack(spacing: 12) {
                    if let fraction = session.fraction { ProgressView(value: fraction).frame(width: 100) }
                    else { ProgressView().controlSize(.small) }
                    Text(status).font(.callout).lineLimit(2)
                    Spacer()
                    Button("Cancel Download") { session.cancelDownload() }.disabled(session.validating).buttonStyle(FluidButtonStyle(compact: true))
                }.padding(16).background(InterfaceStyle.surface)
            } else if let completed = session.completed {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(InterfaceStyle.accent)
                    Text("\(completed.title) is ready").font(.callout).lineLimit(1)
                    Spacer(minLength: 4)
                    Button("Show in Library") { showLibrary(completed) }.buttonStyle(FluidButtonStyle(compact: true))
                    Button("Set Wallpaper") { model.apply(completed) }.buttonStyle(FluidButtonStyle(prominent: true, compact: true))
                    Button { session.completed = nil } label: { Image(systemName: "xmark") }.buttonStyle(FluidButtonStyle(compact: true)).accessibilityLabel("Dismiss download confirmation")
                }.padding(16).background(InterfaceStyle.surface)
            }
        }
        .onAppear { session.connect(model); session.show() }
        .onDisappear { session.hide() }
    }

    private var browserControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Button { session.webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!session.canGoBack).accessibilityLabel("Previous website page").help("Back")
                Button { session.webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!session.canGoForward).accessibilityLabel("Next website page").help("Forward")
                Button { session.retry() } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Reload website").help("Reload this page")
                Divider().frame(height: 20).padding(.horizontal, 5)
                Button { session.showSources() } label: { Label("Sources", systemImage: "square.grid.2x2") }.help("Return to the wallpaper source directory")
                Button { session.home() } label: { Image(systemName: "house") }.accessibilityLabel("Collection home").help("Open this collection’s first page")
                Spacer(minLength: 4)
                Button { NSWorkspace.shared.open(session.pageURL ?? session.catalogueHome) } label: { Label("Open in Browser", systemImage: "arrow.up.right.square") }
            }.buttonStyle(FluidButtonStyle(compact: true))
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Website").font(.caption).foregroundStyle(.secondary)
                    Picker("Website", selection: $session.provider) { ForEach(CatalogueProvider.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
                }.frame(maxWidth: 210)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Collection").font(.caption).foregroundStyle(.secondary)
                    Picker("Collection", selection: $session.source) { ForEach(CatalogueSource.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden()
                }.frame(maxWidth: 210)
                Spacer(minLength: 0)
                Toggle("Block ads", isOn: $session.blocksAds).toggleStyle(.switch).controlSize(.small).fixedSize()
                    .disabled(!session.adBlockingAvailable).help("Hide known ads. Changing this reloads the page.")
            }
            HStack(spacing: 8) {
                if session.loading { ProgressView().controlSize(.small) }
                else { Image(systemName: "globe").foregroundStyle(InterfaceStyle.accent) }
                Text(session.pageURL?.host ?? session.catalogueHome.host ?? "").font(.caption.weight(.medium))
                Text("Preview the video, then choose its desktop download.").font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            if !session.source.topics.isEmpty {
                HStack {
                    Menu(session.source == .anime ? "Choose an anime series" : "Choose a game") {
                        ForEach(session.source.topics, id: \.self) { topic in Button(topic) { session.search(topic) } }
                    }.fixedSize()
                    Text("Search any title above.").font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }.padding(18).background(InterfaceStyle.surface)
    }

    private var sourceDirectory: some View {
        GeometryReader { bounds in
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Find your next\nwallpaper.").font(.system(size: 30, weight: .semibold))
                        Text("Explore a video library. Preview the motion. Bring it to your desktop.")
                            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if let image = model.thumbnails["last-train"] {
                        Image(nsImage: image).resizable().scaledToFill().frame(width: 210, height: 144).clipped().clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityLabel("The Last Train, an original Frontdrop scene")
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Browse & download").font(.system(size: 18, weight: .semibold))
                    Text("Downloads from these websites can be added directly to your library.").font(.callout).foregroundStyle(.secondary)
                    VStack(spacing: 4) {
                        ForEach(CatalogueProvider.allCases) { provider in
                            ProviderRow(provider: provider) { session.browse(provider) }
                        }
                    }
                    Text("Choose a collection in the sidebar, or search for a title above. Preview each video to check how much it moves. Wallpaper rights and terms belong to each creator.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                VStack(alignment: .leading, spacing: 18) {
                    Text("More ways to build your collection").font(.system(size: 18, weight: .semibold))
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Steam handles downloads for your owned copy of Wallpaper Engine. Copy a downloaded Video project folder from Windows to this Mac, then import it here. Scene, Web and Application projects need Wallpaper Engine’s renderer.")
                            HStack {
                                Button("Import Workshop Video…") { model.chooseWorkshopVideo { showLibrary($0) } }.disabled(model.importing).buttonStyle(FluidButtonStyle())
                                Link("Explore Workshop ↗", destination: URL(string: "https://steamcommunity.com/app/431960/workshop/")!)
                            }
                            Link("Where Steam stores downloads ↗", destination: URL(string: "https://help.wallpaperengine.io/en/steam/backup.html")!)
                            Text("On Windows: Installed → Open in Explorer. Frontdrop does not download Steam subscriptions on macOS.").font(.caption).foregroundStyle(.secondary)
                        }.font(.callout).padding(.top, 12)
                    } label: { Label("Import a Steam Workshop Video project", systemImage: "shippingbox") }
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Explore anime, gaming, space and dynamic-motion filters. Full downloads go through Backdrop; the gallery is a reference rather than a Frontdrop download source.").font(.callout).foregroundStyle(.secondary)
                            Link("Explore Backdrop’s Gallery ↗", destination: URL(string: "https://cindori.com/backdrop/wallpapers")!)
                        }.padding(.top, 12)
                    } label: { Label("Explore Backdrop’s public gallery", systemImage: "globe") }
                }
            }.frame(width: max(0, min(940, bounds.size.width - 56)), alignment: .leading).padding(28).frame(maxWidth: .infinity)
        }
        }
    }
}

private struct ProviderRow: View {
    let provider: CatalogueProvider
    let browse: () -> Void
    @State private var hovering = false
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: browse) {
            HStack(spacing: 16) {
                Image(systemName: "play.rectangle.on.rectangle").font(.system(size: 24, weight: .light)).foregroundStyle(InterfaceStyle.accent).frame(width: 40)
                VStack(alignment: .leading, spacing: 5) {
                    Text(provider.rawValue).font(.system(size: 15, weight: .semibold))
                    Text(provider.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.right").foregroundStyle(hovering ? InterfaceStyle.accent : .secondary).offset(x: hovering && !reduceMotion ? 3 : 0)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(hovering ? 0.08 : 0.035), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(focused ? InterfaceStyle.accent : .clear, lineWidth: 2))
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).focused($focused).onHover { hovering = $0 }
            .animation(reduceMotion ? nil : InterfaceStyle.motion, value: hovering)
            .help("Browse and download wallpapers from \(provider.rawValue)")
    }
}
