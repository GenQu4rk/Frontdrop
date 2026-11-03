import AppKit

// Format the user-supplied Canva artwork without changing its composition.
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let source = URL(fileURLWithPath: "Sources/Frontdrop/Resources/FrontdropLogo.png")
guard let logo = NSImage(contentsOf: source) else { fatalError("Missing FrontdropLogo.png") }
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func render(size: Int, draw: (CGContext) -> Void) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    draw(graphics.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let png = render(size: size) { context in
            context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
            NSBezierPath(roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944), xRadius: 210, yRadius: 210).addClip()
            logo.draw(in: NSRect(x: 40, y: 40, width: 944, height: 944), from: .zero, operation: .copy, fraction: 1)
        }
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        try png.write(to: folder.appendingPathComponent(name))
    }
}

// Render the revised transparent logo as a system menu-bar template.
let transparent = NSImage(contentsOfFile: "Sources/Frontdrop/Resources/FrontdropLogoTransparent.png")!
let template = render(size: 144) { context in
    let rect = NSRect(x: 0, y: 0, width: 144, height: 144)
    transparent.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
    context.setBlendMode(.sourceIn)
    context.setFillColor(NSColor.black.cgColor)
    context.fill(rect)
}
try template.write(to: URL(fileURLWithPath: "Sources/Frontdrop/Resources/FrontdropMenuTemplate.png"))
