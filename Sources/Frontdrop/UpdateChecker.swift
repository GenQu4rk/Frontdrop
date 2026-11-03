import Foundation

enum UpdateChecker {
    enum Result: Equatable {
        case current
        case available(version: String, url: URL)
        case noCompatibleDownload(version: String)
    }

    enum UpdateError: LocalizedError {
        case invalidRelease
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .invalidRelease: "GitHub returned release information Frontdrop could not read. Please try again later."
            case .server(let status): "GitHub could not check for updates (HTTP \(status)). Please try again later."
            }
        }
    }

    private struct Release: Decodable {
        struct Asset: Decodable { let name: String }
        let tag_name: String
        let assets: [Asset]
    }

    private static func components(_ version: String) -> [Int]? {
        let pieces = version.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count == 3 else { return nil }
        let numbers = pieces.compactMap { Int($0) }
        return numbers.count == 3 && numbers.allSatisfy { $0 >= 0 } ? numbers : nil
    }

    static func evaluate(_ data: Data, currentVersion: String, architecture: String) throws -> Result {
        let release = try JSONDecoder().decode(Release.self, from: data)
        let tag = release.tag_name
        guard tag.range(of: #"^v[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil,
              let latest = components(String(tag.dropFirst())),
              let current = components(currentVersion) else { throw UpdateError.invalidRelease }
        guard latest.lexicographicallyPrecedes(current) == false && latest != current else { return .current }
        let version = String(tag.dropFirst())
        let compatible = release.assets.contains {
            $0.name == "Frontdrop-\(version)-\(architecture).dmg" || $0.name == "Frontdrop-\(version)-universal.dmg"
        }
        guard compatible else { return .noCompatibleDownload(version: version) }
        return .available(version: version, url: URL(string: "https://github.com/GenQu4rk/Frontdrop/releases/tag/\(tag)")!)
    }

    static func check(currentVersion: String, architecture: String) async throws -> Result {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/GenQu4rk/Frontdrop/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Frontdrop/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UpdateError.invalidRelease }
        guard response.statusCode == 200 else { throw UpdateError.server(response.statusCode) }
        return try evaluate(data, currentVersion: currentVersion, architecture: architecture)
    }
}
