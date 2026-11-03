import AppKit
import AVFoundation

/// Command-line verification uses the production GPU pipeline; no desktop changes.
enum RendererVerification {
    static func run() throws {
        let args = CommandLine.arguments
        let output = args.firstIndex(of: "--output").flatMap { $0+1 < args.count ? args[$0+1] : nil } ?? NSTemporaryDirectory()+"frontdrop-previews"
        let root = URL(fileURLWithPath: output, isDirectory: true)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        let gpu = try SceneGPU.shared.get()
        for scene in Wallpaper.builtins {
            let first = try gpu.thumbnail(for: scene,time: 20)
            let second = try gpu.thumbnail(for: scene,time: 25)
            guard let a = first.tiffRepresentation, let b = second.tiffRepresentation, a != b else {
                throw RenderError.unavailable("\(scene.title) did not animate")
            }
            guard let bitmap = NSBitmapImageRep(data: a), let png = bitmap.representation(using: .png,properties: [:]) else { throw RenderError.unavailable("Cannot encode \(scene.title)") }
            try png.write(to: root.appendingPathComponent(scene.id+".png"))
            print("PASS: \(scene.title) renders and changes over time")
        }
        print("Saved production-renderer previews to \(output)")
    }
}
