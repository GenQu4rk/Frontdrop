import Foundation
import WebKit

/// Small, bundled rules for the catalogue browser. No extension or external service.
enum CatalogueAdBlocker {
    static let identifier = "FrontdropCatalogueAds-v1"
    static let rules: String = {
        let domains = ["googlesyndication.com", "doubleclick.net", "googleadservices.com", "googletagservices.com", "adtrafficquality.google", "snigelweb.com", "pubgalaxy.com", "publisher-collective.com"]
        let networkRules: [[String: Any]] = domains.map { domain in
            ["trigger": ["url-filter": "^https?://([a-z0-9-]+\\.)*" + domain.replacingOccurrences(of: ".", with: "\\.") + "[:/]"], "action": ["type": "block"]]
        }
        let rules: [[String: Any]] = networkRules + [
            ["trigger": ["url-filter": ".*", "if-domain": ["*motionbgs.com", "*desktophut.com"]],
             "action": ["type": "css-display-none", "selector": ".ads, ins.adsbygoogle, .google-auto-placed, .dh-ad-slot, [id^='google_ads_iframe'], [id^='div-gpt-ad'], #adngin-anchor-0, #adngin-top_leaderboard-0, #adngin-incontent-0"]]
        ]
        return String(data: try! JSONSerialization.data(withJSONObject: rules, options: [.sortedKeys]), encoding: .utf8)!
    }()
    @MainActor static func compile() async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) { list, error in
                if let list { continuation.resume(returning: list) }
                else { continuation.resume(throwing: error ?? NSError(domain: "FrontdropAdBlocker", code: 1, userInfo: [NSLocalizedDescriptionKey: "WebKit could not compile the ad blocker."])) }
            }
        }
    }
}
