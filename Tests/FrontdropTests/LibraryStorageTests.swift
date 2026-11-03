import Foundation

@main
struct LibraryStorageTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("frontdrop-storage-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let values = try root.resourceValues(forKeys: [.volumeURLKey, .volumeUUIDStringKey])
        let volume = values.allValues[.volumeURLKey] as! URL
        let uuid = values.volumeUUIDString!
        let valid = LibraryStorage(directory: root, volumeRoot: volume, volumeUUID: uuid)
        try valid.requireAvailable()
        let suite = "frontdrop-storage-tests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let initial = try LibraryStorage.configured(defaults: defaults)
        precondition(initial == nil, "Fresh installs keep their existing default until configured")
        defaults.set(["directory": root.path, "volumeRoot": volume.path, "volumeUUID": uuid], forKey: LibraryStorage.preferenceKey)
        let restored = try LibraryStorage.configured(defaults: defaults)!
        precondition(restored.directory.path == root.path && restored.volumeUUID == uuid, "Storage choice persists without changing the destination")
        func rejects(_ location: LibraryStorage) -> Bool {
            do { try location.requireAvailable(); return false } catch { return true }
        }
        let missing = root.appendingPathComponent("DisconnectedCard")
        precondition(rejects(LibraryStorage(directory: missing.appendingPathComponent("Library"), volumeRoot: missing, volumeUUID: uuid)), "An internal directory must never impersonate a disconnected external mount")
        precondition(!FileManager.default.fileExists(atPath: missing.path), "Validation must not create a missing mount point")
        precondition(rejects(LibraryStorage(directory: root, volumeRoot: volume, volumeUUID: "wrong-card")), "Reject a different volume reusing the same mount name")
        precondition(rejects(LibraryStorage(directory: root.appendingPathComponent("MissingLibrary"), volumeRoot: volume, volumeUUID: uuid)), "A missing library must not silently become an empty replacement")
        defaults.set(["directory": root.path], forKey: LibraryStorage.preferenceKey)
        var malformedRejected = false
        do { _ = try LibraryStorage.configured(defaults: defaults) } catch { malformedRejected = true }
        precondition(malformedRejected, "A broken saved location must not silently revert to internal storage")
        print("PASS: configured library, actual volume identity, disconnected mount, missing library and malformed-config checks")
    }
}
