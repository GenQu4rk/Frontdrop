import AppKit
import WebKit

@MainActor
final class FixtureNavigation: NSObject, WKNavigationDelegate {
    var completion: CheckedContinuation<Void, Error>?
    func load(_ html: String, in web: WKWebView) async throws {
        web.navigationDelegate = self
        try await withCheckedThrowingContinuation { continuation in
            completion = continuation
            web.loadHTMLString(html, baseURL: URL(string: "https://motionbgs.com/"))
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { completion?.resume(); completion = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { completion?.resume(throwing: error); completion = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { completion?.resume(throwing: error); completion = nil }
}

@main
struct AdBlockerTests {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        let rules = try JSONSerialization.jsonObject(with: Data(CatalogueAdBlocker.rules.utf8)) as! [[String: Any]]
        let blocked = rules.filter { ($0["action"] as? [String: Any])?["type"] as? String == "block" }
        func matches(_ url: String) -> Bool {
            blocked.contains {
                let pattern = ($0["trigger"] as! [String: Any])["url-filter"] as! String
                return url.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
            }
        }
        precondition(matches("https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"))
        precondition(matches("https://securepubads.g.doubleclick.net/tag/js/gpt.js"))
        precondition(!matches("https://motionbgs.com/dl/hd/10314"))
        precondition(!matches("https://www.desktophut.com/files/cool.mp4"))
        precondition(!matches("https://images.example/advertising-art.mp4"))
        let list = try await CatalogueAdBlocker.compile()
        let config = WKWebViewConfiguration()
        config.userContentController.add(list)
        let web = WKWebView(frame: NSRect(x:0,y:0,width:800,height:600), configuration:config)
        let fixture = """
        <html><body><h1>Wallpaper gallery</h1>
        <div class="dh-ad-slot" id="slot">Advertisement</div>
        <ins class="adsbygoogle" id="ad">Ad</ins>
        <div class="google-auto-placed" id="auto">Auto ad</div>
        <section class="ads" id="wrapper">Advertisement placeholder</section>
        <video id="preview" controls></video>
        <a id="download" href="https://motionbgs.com/dl/hd/10314">Download HD</a>
        <button id="consent">Privacy choices</button>
        </body></html>
        """
        let navigation = FixtureNavigation()
        try await navigation.load(fixture, in: web)
        let result = try await web.evaluateJavaScript("""
        ['slot','ad','auto','wrapper','preview','download','consent'].map(id=>getComputedStyle(document.getElementById(id)).display)
        """) as! [String]
        precondition(Array(result.prefix(4)) == ["none","none","none","none"], "Compiled WebKit rules must hide ad slots and their empty wrappers")
        precondition(result.dropFirst(4).allSatisfy { $0 != "none" }, "Previews, downloads and consent controls must remain visible")
        config.userContentController.remove(list)
        try await navigation.load(fixture, in: web)
        let restored = try await web.evaluateJavaScript("getComputedStyle(document.getElementById('slot')).display") as! String
        precondition(restored != "none", "Disabling blocking must restore the original page")
        print("PASS: real WebKit blocker compiles, hides ad slots, preserves media/download/consent; ad hosts blocked and wallpaper URLs allowed")
    }
}
