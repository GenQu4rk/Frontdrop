# Community catalogue integration

Goal: browse community-made wallpapers inside Frontdrop, download videos directly into the local library, and provide dedicated Space collections.

Design: retain the native sidebar/library. Add Browse with source/category controls and a WebKit view showing the original providers, including their search, preview, credits and download UI. Use WKDownloadDelegate to save only video downloads into temporary managed staging, validate with AVFoundation, then import with source-page attribution. Show progress, cancel, errors and an Open in Library / Set Wallpaper completion bar. Space opens MotionBGS's dedicated collection, with DesktopHut's space category available too. No scraper, catalogue mirroring, account or API key.

- [x] Add test-first catalogue URL policy, video type handling, and safe suggested filenames.
- [x] Add a WebKit catalogue session and native Browse view, with navigation, source choices, space collections, search, download progress and cancellation.
- [x] Extend managed import with title/source metadata, backward-compatible persistence and source links in the local inspector.
- [x] Build and test a real public download through the app into the managed local library; verify Browse, Space, local playback and existing library behavior.
- [x] Review, package, update the installed app while preserving user data, and document verified boundaries.
