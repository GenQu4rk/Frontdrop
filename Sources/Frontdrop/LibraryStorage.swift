import Foundation

/// A saved library location is tied to its actual mounted volume, never a fallback path.
struct LibraryStorage {
    static let preferenceKey = "wallpaperLibraryStorage"
    let directory: URL
    let volumeRoot: URL
    let volumeUUID: String

    struct StorageError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
    static func configured(defaults: UserDefaults = .standard) throws -> Self? {
        guard let value = defaults.object(forKey: preferenceKey) else { return nil }
        guard let record = value as? [String: String],
              let path = record["directory"], path.hasPrefix("/"),
              let volume = record["volumeRoot"], volume.hasPrefix("/"),
              let uuid = record["volumeUUID"], !uuid.isEmpty else {
            throw StorageError("The saved wallpaper library location is incomplete. Restore its storage configuration before importing videos; Frontdrop will not switch to internal storage.")
        }
        return Self(directory: URL(fileURLWithPath: path, isDirectory: true), volumeRoot: URL(fileURLWithPath: volume, isDirectory: true), volumeUUID: uuid)
    }
    func requireAvailable() throws {
        let mounted = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeUUIDStringKey], options: []) ?? []
        guard let volume = mounted.first(where: { $0.standardizedFileURL.path == volumeRoot.standardizedFileURL.path }),
              let actualUUID = try? volume.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString,
              actualUUID.caseInsensitiveCompare(volumeUUID) == .orderedSame else {
            throw StorageError("Connect \(volumeRoot.lastPathComponent) and reopen Frontdrop to use your wallpaper library. Downloads and imports will not be saved to internal storage.")
        }
        let resolved = directory.resolvingSymlinksInPath().standardizedFileURL
        let prefix = volumeRoot.path == "/" ? "/" : volumeRoot.standardizedFileURL.path + "/"
        var isDirectory: ObjCBool = false
        guard resolved.path.hasPrefix(prefix),
              FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let libraryUUID = try? resolved.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString,
              libraryUUID.caseInsensitiveCompare(volumeUUID) == .orderedSame else {
            throw StorageError("Your wallpaper library is unavailable at \(directory.path). Restore that folder and reopen Frontdrop. No replacement library will be created on internal storage.")
        }
    }
}
