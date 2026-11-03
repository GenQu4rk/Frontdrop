import AppKit
import WebKit

@MainActor
final class PlaybackFixtureNavigation: NSObject, WKNavigationDelegate {
    var completion: CheckedContinuation<Void, Error>?
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // The session can navigate normally without making fixture network requests.
        decisionHandler(action.request.url?.scheme == "https" ? .cancel : .allow)
    }
    func load(_ html: String, in web: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            web.loadHTMLString(html, baseURL: nil)
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { completion?.resume(); completion = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { completion?.resume(throwing: error); completion = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { completion?.resume(throwing: error); completion = nil }
}

@main
struct CataloguePlaybackTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let watchdog = Task {
            try await Task.sleep(nanoseconds: 15_000_000_000)
            fputs("FAIL: catalogue playback fixture timed out\n", stderr)
            exit(1)
        }
        defer { watchdog.cancel() }
        let session = CatalogueSession()
        let navigation = PlaybackFixtureNavigation()
        session.webView.navigationDelegate = navigation
        let readyDeadline = Date().addingTimeInterval(5)
        while !session.adBlockingAvailable && Date() < readyDeadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        precondition(session.adBlockingAvailable, "Browser preparation must complete before the fixture")
        session.load(URL(string: "https://fixture.invalid/wallpaper")!)
        let video = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])).base64EncodedString()
        try await navigation.load("<video id='video' autoplay muted loop src='data:video/mp4;base64,\(video)'></video>", in: session.webView)
        session.show()
        _ = try await session.webView.evaluateJavaScript("document.getElementById('video').play(); null")
        func mediaState() async -> WKMediaPlaybackState {
            await withCheckedContinuation { continuation in
                session.webView.requestMediaPlaybackState { continuation.resume(returning: $0) }
            }
        }
        let initial = await mediaState()
        precondition(initial == .playing, "Visible provider video must play")
        session.showSources()
        session.show()
        let reopenedDirectory = await mediaState()
        precondition(reopenedDirectory == .suspended, "Showing the source directory must not resume its retained provider video")
        session.hide()
        session.show()
        let directory = await mediaState()
        precondition(directory == .suspended, "Reopening the source directory must keep its retained video suspended")
        session.load(URL(string: "https://fixture.invalid/wallpaper")!)
        session.show()
        let resumed = await mediaState()
        precondition(resumed == .playing, "One show must resume a visible provider after directory navigation")
        session.hide()
        session.hide()
        session.show()
        let repeated = await mediaState()
        precondition(repeated == .playing, "Repeated hides must not require multiple resumes")
        session.show()
        session.hide()
        let hidden = await mediaState()
        precondition(hidden == .suspended, "Repeated shows must not prevent a later hide from suspending video")
        // A delayed browser load must not resume media after its view disappeared.
        session.load(URL(string: "https://fixture.invalid/next")!)
        let hiddenLoad = await mediaState()
        precondition(hiddenLoad == .suspended, "Loading while hidden must preserve suspension")
        print("PASS: source directory and hidden loads suspend media; repeated show/hide resumes exactly once")
    }
}
