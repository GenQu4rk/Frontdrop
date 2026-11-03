import AppKit
import MetalKit
import AVFoundation
import SwiftUI

struct SceneUniforms {
    var resolution: SIMD2<Float>
    var time: Float
    var scene: Int32
}

enum RenderError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? { if case .unavailable(let reason) = self { return reason }; return nil }
}

final class SceneGPU {
    static let shared = Result { try SceneGPU() }
    let device: MTLDevice
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    private var textures: [String: MTLTexture] = [:]
    private let textureLock = NSLock()
    private let fallback: MTLTexture

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw RenderError.unavailable("This Mac cannot create a Metal renderer.")
        }
        self.device = device
        self.queue = queue
        guard let url = AppResources.url("Scenes.metal") else { throw RenderError.unavailable("The scene library is missing. Rebuild Frontdrop.") }
        let library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen")
        descriptor.fragmentFunction = library.makeFunction(name: "wallpaper")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        textureDescriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { throw RenderError.unavailable("Cannot allocate a scene texture.") }
        var pixel: UInt32 = 0xff201810
        texture.replace(region: MTLRegionMake2D(0,0,1,1), mipmapLevel: 0, withBytes: &pixel, bytesPerRow: 4)
        fallback = texture
    }

    func texture(for scene: Wallpaper) throws -> MTLTexture {
        guard scene.shader != nil, let filename = scene.filename else { return fallback }
        textureLock.lock()
        defer { textureLock.unlock() }
        if let cached = textures[filename] { return cached }
        guard let url = AppResources.url(filename) else { throw RenderError.unavailable("Artwork \(filename) is missing. Rebuild Frontdrop.") }
        let texture = try MTKTextureLoader(device: device).newTexture(URL: url, options: [.SRGB: false, .origin: MTKTextureLoader.Origin.topLeft])
        textures[filename] = texture
        return texture
    }

    func encode(to pass: MTLRenderPassDescriptor, buffer: MTLCommandBuffer, scene: Wallpaper, size: CGSize, time: Float) throws {
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        let texture = try texture(for: scene)
        var uniforms = SceneUniforms(resolution: SIMD2(Float(size.width), Float(size.height)), time: time, scene: Int32(scene.shader ?? 0))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<SceneUniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    func thumbnail(for scene: Wallpaper, width: Int = 600, height: Int = 375, time: Float = 20) throws -> NSImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor), let buffer = queue.makeCommandBuffer() else { throw RenderError.unavailable("Cannot create a thumbnail.") }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        try encode(to: pass, buffer: buffer, scene: scene, size: CGSize(width: width, height: height), time: time)
        buffer.commit()
        buffer.waitUntilCompleted()
        if let error = buffer.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width*height*4)
        texture.getBytes(&pixels, bytesPerRow: width*4, from: MTLRegionMake2D(0,0,width,height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(.byteOrder32Little), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw RenderError.unavailable("Cannot read a thumbnail.") }
        return NSImage(cgImage: image, size: NSSize(width: width, height: height))
    }
}

final class AnimatedSceneView: MTKView, MTKViewDelegate {
    let gpu: SceneGPU
    let scene: Wallpaper
    private var elapsed: Double = 20
    private var lastTick = CACurrentMediaTime()
    private var play = true
    private let maxWidth: CGFloat
    var onError: ((Error) -> Void)?

    init(scene: Wallpaper, maxWidth: CGFloat = 1920) throws {
        gpu = try SceneGPU.shared.get()
        self.scene = scene
        self.maxWidth = maxWidth
        _ = try gpu.texture(for: scene)
        super.init(frame: .zero, device: gpu.device)
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0.01,0.01,0.02,1)
        framebufferOnly = true
        autoResizeDrawable = false
        preferredFramesPerSecond = 30
        delegate = self
        enableSetNeedsDisplay = false
    }
    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout()
        let width = max(1,min(maxWidth,bounds.width*(window?.backingScaleFactor ?? 1)))
        let size = CGSize(width: width, height: max(1,width*bounds.height/max(1,bounds.width)))
        if drawableSize != size {
            drawableSize = size
            if isPaused { draw() }
        }
    }
    func setPlaying(_ value: Bool, fps: Int) {
        if preferredFramesPerSecond != fps { preferredFramesPerSecond = fps }
        if play != value || isPaused == value {
            play = value
            lastTick = CACurrentMediaTime()
            isPaused = !value
        }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard let drawable = currentDrawable, let pass = currentRenderPassDescriptor, let buffer = gpu.queue.makeCommandBuffer() else { return }
        let now = CACurrentMediaTime()
        if play { elapsed += min(0.1,now-lastTick) }
        lastTick = now
        do { try gpu.encode(to: pass, buffer: buffer, scene: scene, size: drawableSize, time: Float(elapsed)) }
        catch { isPaused = true; onError?(error); return }
        buffer.present(drawable)
        buffer.commit()
    }
}

final class VideoSceneView: NSView {
    let player: AVQueuePlayer
    let looper: AVPlayerLooper
    let playerLayer: AVPlayerLayer
    private var observation: NSKeyValueObservation?
    private var failureObserver: NSObjectProtocol?
    private var readyObservation: NSKeyValueObservation?
    private var playing: Bool?
    var onError: ((Error) -> Void)?
    var onReady: (() -> Void)?

    init(url: URL, asset: AVAsset? = nil, framing: VideoFraming = .fit) {
        let item = AVPlayerItem(asset: asset ?? AVURLAsset(url: url))
        player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: player, templateItem: item)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = framing == .fit ? .resizeAspect : .resizeAspectFill
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.addSublayer(playerLayer)
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.new]) { [weak self] layer, _ in
            if layer.isReadyForDisplay { DispatchQueue.main.async { self?.onReady?() } }
        }
        observation = looper.observe(\.status, options: [.new]) { [weak self] looper, _ in
            if looper.status == .failed, let error = looper.error { DispatchQueue.main.async { self?.onError?(error) } }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let self, let item = note.object as? AVPlayerItem, self.player.items().contains(item) else { return }
            self.onError?(item.error ?? RenderError.unavailable("This video could not be played."))
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() { super.layout(); playerLayer.frame = bounds }
    func setFraming(_ framing: VideoFraming) {
        let gravity: AVLayerVideoGravity = framing == .fit ? .resizeAspect : .resizeAspectFill
        guard playerLayer.videoGravity != gravity else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.videoGravity = gravity
        CATransaction.commit()
    }
    func setPlaying(_ value: Bool) {
        guard playing != value else { return }
        playing = value
        if value { player.play() } else { player.pause() }
    }
    deinit { if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }; player.pause() }
}

/// One stable preview surface: selection paints a poster immediately, then
/// prepares media asynchronously. Cancellation prevents stale rapid selections.
final class ScenePreviewHost: NSView {
    let poster = NSImageView()
    private(set) var renderer: NSView?
    private(set) var sceneID: String?
    private var preparation: Task<Void, Never>?
    private var playing = false
    private var framing: VideoFraming = .fit
    private var fps = 30
    private var visibilityObserver: NSObjectProtocol?

    init() {
        super.init(frame: .zero)
        poster.imageScaling = .scaleProportionallyUpOrDown
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        addSubview(poster)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func layout() {
        super.layout()
        poster.frame = bounds
        renderer?.frame = bounds
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let visibilityObserver { NotificationCenter.default.removeObserver(visibilityObserver) }
        visibilityObserver = nil
        if let window {
            visibilityObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in self?.updatePlayback() }
        }
        updatePlayback()
    }
    func show(scene: Wallpaper, url: URL?, thumbnail: NSImage?, playing: Bool, fps: Int, onError: @escaping (Error) -> Void) {
        self.playing = playing
        self.framing = scene.framing
        (renderer as? VideoSceneView)?.setFraming(scene.framing)
        self.fps = fps
        poster.image = thumbnail
        guard sceneID != scene.id else { updatePlayback(); return }
        preparation?.cancel()
        stopRenderer()
        renderer?.removeFromSuperview()
        renderer = nil
        sceneID = scene.id
        preparation = Task { @MainActor [weak self] in
            do {
                var asset: AVURLAsset?
                if scene.shader != nil {
                    try await Task.detached(priority: .userInitiated) {
                        let gpu = try SceneGPU.shared.get()
                        _ = try gpu.texture(for: scene)
                    }.value
                } else {
                    guard let url else { throw RenderError.unavailable("This video is missing. Import it again.") }
                    let prepared = AVURLAsset(url: url)
                    guard try await prepared.load(.isPlayable) else { throw RenderError.unavailable("This video could not be played.") }
                    asset = prepared
                }
                guard !Task.isCancelled, let self, self.sceneID == scene.id else { return }
                let view: NSView
                if scene.shader != nil {
                    let animated = try AnimatedSceneView(scene: scene, maxWidth: 1000)
                    animated.onError = onError
                    view = animated
                } else if let url {
                    let video = VideoSceneView(url: url, asset: asset, framing: self.framing)
                    video.isHidden = true
                    video.onError = onError
                    video.onReady = { [weak video] in video?.isHidden = false }
                    view = video
                } else { return }
                self.renderer = view
                view.frame = self.bounds
                self.addSubview(view)
                self.updatePlayback()
            } catch {
                guard !Task.isCancelled else { return }
                onError(error)
            }
        }
    }
    private func updatePlayback() {
        let visible = window.map { $0.isVisible && $0.occlusionState.contains(.visible) } ?? false
        (renderer as? AnimatedSceneView)?.setPlaying(playing && visible, fps: fps)
        (renderer as? VideoSceneView)?.setPlaying(playing && visible)
    }
    private func stopRenderer() {
        (renderer as? AnimatedSceneView)?.setPlaying(false, fps: fps)
        (renderer as? VideoSceneView)?.setPlaying(false)
    }
    func stop() { preparation?.cancel(); sceneID = nil; stopRenderer() }
    deinit {
        preparation?.cancel()
        if let visibilityObserver { NotificationCenter.default.removeObserver(visibilityObserver) }
    }
}

struct ScenePreview: NSViewRepresentable {
    let scene: Wallpaper
    let url: URL?
    let thumbnail: NSImage?
    let playing: Bool
    let fps: Int
    let onError: (Error) -> Void
    func makeNSView(context: Context) -> ScenePreviewHost { ScenePreviewHost() }
    func updateNSView(_ nsView: ScenePreviewHost, context: Context) {
        nsView.show(scene: scene, url: url, thumbnail: thumbnail, playing: playing, fps: fps, onError: onError)
    }
    static func dismantleNSView(_ nsView: ScenePreviewHost, coordinator: ()) { nsView.stop() }
}
