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
            if session.showsDirectory {
                sourceDirectory
            } else {
            HStack(spacing: 12) {
                Button { session.showSources() } label: { Label("Sources", systemImage: "square.grid.2x2") }
                Picker("Provider", selection: $session.provider) {
                    ForEach(CatalogueProvider.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 180).labelsHidden().help("Search this collection on another wallpaper site")
                Picker("Catalogue", selection: $session.source) {
                    ForEach(CatalogueSource.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 180).labelsHidden().help("Choose a wallpaper collection")
                Button { session.home() } label: { Image(systemName: "house") }.help("Catalogue home")
                Spacer()
                Button { session.webView.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!session.canGoBack).help("Back")
                Button { session.webView.goForward() } label: { Image(systemName: "chevron.right") }.disabled(!session.canGoForward).help("Forward")
                Button { session.retry() } label: { Image(systemName: "arrow.clockwise") }.help("Reload catalogue")
                Button { NSWorkspace.shared.open(session.pageURL ?? session.catalogueHome) } label: { Image(systemName: "safari") }.help("Open in Browser")
            }.buttonStyle(.borderless).padding(.horizontal,20).padding(.vertical,14)
            HStack {
                Image(systemName: session.source.symbol)
                Text(session.pageURL?.host ?? session.catalogueHome.host ?? "").font(.caption.weight(.medium))
                Text("· Preview the motion, then choose the desktop video download. Animation varies by wallpaper.").font(.caption).foregroundStyle(.secondary).lineLimit(3)
                Spacer(minLength: 0)
                if session.loading { ProgressView().controlSize(.small) }
                Toggle("Block ads", isOn: $session.blocksAds)
                    .toggleStyle(.switch).controlSize(.small).fixedSize()
                    .disabled(!session.adBlockingAvailable)
                    .help("Block known ad networks and hide advertisement slots. Changing this reloads the page.")
            }.padding(.horizontal,20).padding(.bottom,12)
            if !session.source.topics.isEmpty {
                HStack {
                    Menu(session.source == .anime ? "Choose an anime series" : "Choose a game") {
                        ForEach(session.source.topics, id: \.self) { topic in
                            Button(topic) { session.search(topic) }
                        }
                    }.fixedSize()
                    Text("Or search any title in the toolbar. Searches cover the full provider library.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }.padding(.horizontal,20).padding(.bottom,12)
            }
            Divider()
            CatalogueWebView(session: session).frame(maxWidth: .infinity,maxHeight: .infinity)
            if session.nextPage != nil || session.previousPage != nil {
                Divider()
                HStack {
                    Text("More wallpapers in this collection").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Previous page") { if let url = session.previousPage { session.load(url) } }.disabled(session.previousPage == nil || session.loading)
                    Button("Next page") { if let url = session.nextPage { session.load(url) } }.disabled(session.nextPage == nil || session.loading)
                }.padding(.horizontal,20).padding(.vertical,10)
            }
            }
            if let message = session.message {
                Divider()
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle")
                    Text(message).font(.callout).textSelection(.enabled)
                    Spacer()
                    Button("Retry") { session.retry() }
                    Button { session.message = nil } label: { Image(systemName: "xmark") }.help("Dismiss message")
                }.padding(14)
            }
            if let status = session.downloadStatus {
                Divider()
                HStack(spacing: 12) {
                    if let fraction = session.fraction { ProgressView(value: fraction).frame(width:100) }
                    else { ProgressView().controlSize(.small) }
                    Text(status).font(.callout).lineLimit(2)
                    Spacer()
                    Button("Cancel") { session.cancelDownload() }.disabled(session.validating)
                }.padding(14)
            } else if let completed = session.completed {
                Divider()
                HStack {
                    Label("\(completed.title) added to your library",systemImage: "checkmark.circle").font(.callout).lineLimit(1)
                    Spacer()
                    Button("Show in Library") { showLibrary(completed) }
                    Button("Set Wallpaper") { model.apply(completed) }.buttonStyle(.borderedProminent)
                    Button { session.completed = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless).help("Dismiss download confirmation")
                }.padding(14)
            }
        }
        .onAppear { session.connect(model); session.show() }
        .onDisappear { session.hide() }
    }
    private var sourceDirectory: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find your next wallpaper").font(.system(size: 28, weight: .semibold))
                    Text("Explore full wallpaper libraries, search a favourite series, or bring a video from your Steam collection.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Download videos in Frontdrop").font(.headline).padding(.bottom, 8)
                    ForEach(CatalogueProvider.allCases) { provider in
                        HStack(alignment: .center, spacing: 20) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(provider.rawValue).font(.headline)
                                Text(provider.detail).font(.callout).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Button("Browse " + provider.rawValue) { session.browse(provider) }
                        }.padding(.vertical, 16)
                        Divider()
                    }
                    Text("Choose a category in the sidebar or search above. Switch providers to compare results for the same search. Some collections overlap; preview each video to check how much the scene moves.")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Explore the original communities").font(.headline)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Wallpaper Engine · Steam Workshop").font(.headline)
                            Text("Creator-made video, scene and interactive wallpapers. Steam handles downloads for your owned copy of Wallpaper Engine. Import a downloaded Video project here; Scene, Web and Application projects need its renderer.")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Link("Explore Workshop", destination: URL(string: "https://steamcommunity.com/app/431960/workshop/")!)
                    }
                    HStack {
                        Button("Import Workshop Video…") {
                            model.chooseWorkshopVideo { scene in showLibrary(scene) }
                        }.disabled(model.importing)
                        Link("Where Steam stores downloads", destination: URL(string: "https://help.wallpaperengine.io/en/steam/backup.html")!).font(.caption)
                    }
                    Text("On your Windows Steam installation: Installed → Open in Explorer. Copy that wallpaper’s folder to this Mac, then import it. This does not download Workshop subscriptions on macOS.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider().padding(.vertical, 2)
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Backdrop · public gallery").font(.headline)
                            Text("Browse its community’s anime, gaming, space and dynamic-motion filters. Full downloads go through Backdrop; this gallery is a reference, not a free Frontdrop download source.")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Link("Explore Backdrop", destination: URL(string: "https://cindori.com/backdrop/wallpapers")!)
                    }
                }
            }.padding(28).frame(maxWidth: 900, alignment: .leading).frame(maxWidth: .infinity)
        }
    }

}
