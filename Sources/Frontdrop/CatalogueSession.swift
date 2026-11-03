import AppKit
import WebKit
import Combine

@MainActor
final class CatalogueSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    @Published var source: CatalogueSource = .all { didSet { if source != oldValue { home() } } }
    @Published var provider: CatalogueProvider = .liveWallpapers4Free { didSet { if provider != oldValue { load(source.searchURL(searchTerm, provider: provider)) } } }
    @Published private(set) var showsDirectory = true
    private var searchTerm = ""
    @Published private(set) var nextPage: URL?
    @Published private(set) var previousPage: URL?
    @Published private(set) var pageTitle = "Browse wallpapers"
    @Published private(set) var pageURL: URL?
    @Published private(set) var loading = false
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var downloadStatus: String?
    @Published private(set) var fraction: Double?
    @Published private(set) var validating = false
    @Published var message: String?
    @Published var completed: Wallpaper?
    @Published private(set) var adBlockingAvailable = false
    @Published var blocksAds = UserDefaults.standard.object(forKey: "catalogueBlocksAds") as? Bool ?? true {
        didSet {
            guard blocksAds != oldValue else { return }
            UserDefaults.standard.set(blocksAds, forKey: "catalogueBlocksAds")
            guard let adRules else { return }
            let controller = webView.configuration.userContentController
            controller.remove(adRules)
            if blocksAds { controller.add(adRules) }
            load(documentURL ?? catalogueHome)
        }
    }
    let webView: WKWebView
    private weak var store: LibraryStore?
    private var observations: [NSKeyValueObservation] = []
    private var transfer: Transfer?
    private var loaded = false
    private var documentURL: URL?
    private var documentTitle: String?
    private var adRules: WKContentRuleList?
    private var browserReady = false
    private var pendingURL: URL?
    private var visible = false
    private var mediaSuspended = false

    @MainActor private final class Transfer {
        let download: WKDownload
        let origin: URL?
        let title: String?
        let category: String
        var destination: URL?
        var filename = "video.mp4"
        var observation: NSKeyValueObservation?
        init(download: WKDownload, origin: URL?, title: String?, category: String) {
            self.download = download; self.origin = origin; self.title = title; self.category = category
        }
    }

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .audio
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.loading = view.isLoading } },
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.pageTitle = view.title ?? "Browse wallpapers" } },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.pageURL = view.url } },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoBack = view.canGoBack } },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoForward = view.canGoForward } }
        ]
        Task { [weak self] in
            do {
                let rules = try await CatalogueAdBlocker.compile()
                guard let self else { return }
                self.adRules = rules
                if self.blocksAds { self.webView.configuration.userContentController.add(rules) }
                self.adBlockingAvailable = true
                self.finishPreparingBrowser()
            } catch {
                guard let self else { return }
                self.finishPreparingBrowser()
                self.message = "Ad blocking could not start: \(error.localizedDescription)"
            }
        }
    }
    private func finishPreparingBrowser() {
        browserReady = true
        if let url = pendingURL {
            pendingURL = nil
            guard !showsDirectory else { loaded = false; loading = false; return }
            load(url)
        }
    }
    func connect(_ store: LibraryStore) { self.store = store }
    func show() {
        visible = true
        syncMediaPlayback()
        if !showsDirectory && !loaded { load(catalogueHome) }
    }
    func hide() { visible = false; syncMediaPlayback() }
    private func syncMediaPlayback() {
        let suspended = !visible || showsDirectory
        // WebKit counts suspension requests; duplicate hides need no extra request.
        guard suspended != mediaSuspended else { return }
        mediaSuspended = suspended
        webView.setAllMediaPlaybackSuspended(suspended, completionHandler: nil)
    }
    func load(_ url: URL) {
        guard CataloguePolicy.isWebURL(url) else { return }
        loaded = true
        showsDirectory = false
        syncMediaPlayback()
        nextPage = nil; previousPage = nil
        message = nil
        guard browserReady else { pendingURL = url; loading = true; return }
        webView.load(URLRequest(url: url))
    }
    var catalogueHome: URL { source.home(provider: provider) }
    func search(_ query: String) { searchTerm = query; load(source.searchURL(query, provider: provider)) }
    func home() { searchTerm = ""; load(catalogueHome) }
    func showSources() { showsDirectory = true; syncMediaPlayback() }
    func browse(_ provider: CatalogueProvider) {
        if self.provider == provider { load(source.searchURL(searchTerm, provider: provider)) }
        else { self.provider = provider }
        show()
    }
    func retry() { message = nil; if let pageURL { load(pageURL) } else { home() } }
    func cancelDownload() {
        guard let job = transfer, !validating else { return }
        transfer = nil
        job.download.cancel { _ in if let url = job.destination { try? FileManager.default.removeItem(at: url) } }
        downloadStatus = nil; fraction = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.absoluteString == "about:blank" { decisionHandler(.allow); return }
        guard CataloguePolicy.isWebURL(url) || url.scheme == "blob" else { decisionHandler(.cancel); return }
        if action.shouldPerformDownload || CataloguePolicy.isVideoLink(url) {
            guard transfer == nil else { message = "A download is already running. Finish or cancel it first."; decisionHandler(.cancel); return }
            decisionHandler(.download)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let mime = response.response.mimeType ?? ""
        let attachment = (response.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().contains("attachment") == true
        if response.isForMainFrame && (mime.hasPrefix("video/") || attachment || !response.canShowMIMEType) {
            guard transfer == nil else { message = "A download is already running."; decisionHandler(.cancel); return }
            decisionHandler(.download)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { attach(download) }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { attach(download) }
    private func attach(_ download: WKDownload) {
        guard transfer == nil else { download.cancel(nil); return }
        let context = (documentURL, documentTitle ?? webView.title)
        let job = Transfer(download: download, origin: context.0, title: context.1, category: source.libraryCategory ?? "Downloaded")
        transfer = job
        downloadStatus = "Starting download…"; fraction = nil; completed = nil; message = nil
        download.delegate = self
        job.observation = download.progress.observe(\.fractionCompleted, options: [.new]) { [weak self, weak job] progress, _ in
            DispatchQueue.main.async {
                guard let self, let job, self.transfer === job, !self.validating else { return }
                self.fraction = progress.totalUnitCount > 0 ? progress.fractionCompleted : nil
            }
        }
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard let job = transfer, job.download === download, let store else { completionHandler(nil); return }
        guard let ext = CataloguePolicy.downloadExtension(filename: suggestedFilename, mime: response.mimeType) else {
            completionHandler(nil)
            finishWithError("This download is \(suggestedFilename) (\(response.mimeType ?? "unknown type")). Choose a desktop MP4 or MOV video; images, installers and interactive wallpaper packages cannot play in Frontdrop.", job: job)
            return
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            completionHandler(nil); finishWithError("The provider returned HTTP \(http.statusCode). Try its download button again.", job: job); return
        }
        do {
            let incoming = try store.prepareIncomingDirectory()
            let destination = incoming.appendingPathComponent(UUID().uuidString+"."+ext)
            job.destination = destination
            job.filename = (suggestedFilename as NSString).lastPathComponent
            downloadStatus = "Downloading \(CataloguePolicy.title(pageTitle: job.title, filename: job.filename))"
            completionHandler(destination)
        } catch { completionHandler(nil); finishWithError(error.localizedDescription, job: job) }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let job = transfer, job.download === download, let url = job.destination, let store else { return }
        validating = true; downloadStatus = "Checking video and adding to your library…"; fraction = nil
        Task {
            defer {
                try? FileManager.default.removeItem(at: url)
                if transfer === job { transfer = nil; validating = false; downloadStatus = nil; fraction = nil }
            }
            do {
                let videoURL: URL
                if url.pathExtension == "zip" {
                    try store.requireStorageAvailable()
                    downloadStatus = "Opening the video download…"
                    videoURL = try await Task.detached(priority: .userInitiated) { try VideoArchive.extractVideo(url, into: url.deletingLastPathComponent()) }.value
                } else { videoURL = url }
                defer { if videoURL != url { try? FileManager.default.removeItem(at: videoURL) } }
                completed = try await store.importVideo(videoURL, title: CataloguePolicy.title(pageTitle: job.title, filename: job.filename), sourceURL: job.origin, category: job.category)
            } catch {
                message = "The download could not be imported: \(error.localizedDescription)"
            }
        }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        guard let job = transfer, job.download === download else { return }
        finishWithError("Download failed: \(error.localizedDescription). Try again or use Open in Browser and Import Video.", job: job)
    }
    func download(_ download: WKDownload, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest, decisionHandler: @escaping (WKDownload.RedirectPolicy) -> Void) {
        decisionHandler(newRequest.url.map(CataloguePolicy.isWebURL) == true ? .allow : .cancel)
    }
    private func finishWithError(_ text: String, job: Transfer) {
        guard transfer === job else { return }
        if let url = job.destination { try? FileManager.default.removeItem(at: url) }
        transfer = nil; validating = false; downloadStatus = nil; fraction = nil; message = text
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        documentURL = webView.url
        documentTitle = nil
        nextPage = nil; previousPage = nil
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        documentURL = webView.url
        documentTitle = webView.title
        let page = webView.url
        // Read only the live page's navigation links; wallpaper content remains
        // on its credited provider page.
        webView.evaluateJavaScript(#"""
        (() => {
            const links = Array.from(document.querySelectorAll('link[rel], a[rel], .pag a, .dh-pager a, .pagination a, .pagination-wrapper a, .nav-links a'));
            const find = (rel, label) => links.find(a =>
                (a.rel || '').split(/\s+/).includes(rel) || label.test(a.textContent.trim()))?.href || '';
            return {next: find('next', /^next\b/i), previous: find('prev', /^(previous|prev)\b/i)};
        })()
        """#) { [weak self] result, _ in
            guard let self, self.webView.url == page, let page,
                  let links = result as? [String: String] else { return }
            func validated(_ key: String) -> URL? {
                guard let raw = links[key], let url = URL(string: raw),
                      CataloguePolicy.isWebURL(url), url.host == page.host else { return nil }
                return url
            }
            self.nextPage = validated("next")
            self.previousPage = validated("previous")
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { navigationFailed(error) }
    private func navigationFailed(_ error: Error) {
        let code = (error as NSError).code
        guard code != NSURLErrorCancelled, code != 102 else { return }
        message = "This page could not be loaded: \(error.localizedDescription)"
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { message = "The catalogue page stopped responding. Reload to continue." }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Keep catalogue links in this view. Do not open advertising pop-up windows.
        if action.navigationType == .linkActivated, let url = action.request.url, CataloguePolicy.isWebURL(url) { load(url) }
        return nil
    }
}
