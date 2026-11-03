import Foundation

@main
struct UpdateCheckerTests {
    static func main() throws {
        func release(_ tag: String, assets: [String] = ["Frontdrop-1.6.0-arm64.dmg"]) -> Data {
            let payload: [String: Any] = [
                "tag_name": tag,
                "assets": assets.map { ["name": $0] }
            ]
            return try! JSONSerialization.data(withJSONObject: payload)
        }

        let newer = try UpdateChecker.evaluate(release("v1.6.0"), currentVersion: "1.5.3", architecture: "arm64")
        precondition(newer == .available(version: "1.6.0", url: URL(string: "https://github.com/GenQu4rk/Frontdrop/releases/tag/v1.6.0")!))
        let same = try UpdateChecker.evaluate(release("v1.6.0"), currentVersion: "1.6.0", architecture: "arm64")
        let older = try UpdateChecker.evaluate(release("v1.5.3"), currentVersion: "1.6.0", architecture: "arm64")
        let universal = try UpdateChecker.evaluate(release("v1.10.0", assets: ["Frontdrop-1.10.0-universal.dmg"]), currentVersion: "1.9.9", architecture: "arm64")
        let intel = try UpdateChecker.evaluate(release("v1.6.0", assets: ["Frontdrop-1.6.0-arm64.dmg"]), currentVersion: "1.5.3", architecture: "x86_64")
        precondition(same == .current && older == .current)
        precondition(universal == .available(version: "1.10.0", url: URL(string: "https://github.com/GenQu4rk/Frontdrop/releases/tag/v1.10.0")!))
        precondition(intel == .noCompatibleDownload(version: "1.6.0"))
        do {
            _ = try UpdateChecker.evaluate(release("bad/../../../other"), currentVersion: "1.5.3", architecture: "arm64")
            preconditionFailure("Malformed tags must be rejected")
        } catch UpdateChecker.UpdateError.invalidRelease { }
        print("PASS: update versions, release links, architecture and malformed tags")
    }
}
