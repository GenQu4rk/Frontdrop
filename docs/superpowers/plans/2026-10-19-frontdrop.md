# Frontdrop implementation plan

Goal: deliver a buildable, locally installed native Mac app and an evidence report.
Architecture: Codable local library and pure playback policy; desktop-level AppKit windows host Metal or AVPlayerLayer; SwiftUI library and menu bar own controls. No third-party packages.

- [x] Capture REA binary and renderer identity, dependencies and service configuration; distinguish observed imports from execution.
- [x] Add tests for pause precedence, display selection and safe library persistence. Run before implementation, then implement Models.swift and LibraryStore.swift.
- [x] Build original Metal scenes and a shared renderer, plus looped muted video playback. Compile shader and render thumbnails using the real pipeline.
- [x] Build desktop engine with noninteractive windows behind icons, all Spaces, monitor changes, pause/resume, battery/sleep/lock handling, and teardown.
- [x] Build native library: preview, apply, favourites, video import/delete, display selector, rotation, login launch and menu controls.
- [x] Package an ad-hoc signed .app with a reproducible build script. Run tests, launch, verify actual window levels and animation, exercise video playback and stop/restore. Passed automated and native UI checks are listed in docs/Verification.md.
- [x] Write evidence report, use instructions, limitations and verification results; install into ~/Applications and open library without automatically changing the user's wallpaper.
