# Verification — 19 October 2026

## Release check — 1.5.3 (3 November 2026)

Prepared an Apple silicon DMG with the repeatable `scripts/package-dmg.sh` workflow. This build is ad-hoc signed, not Developer ID signed or notarized. Historical checks below remain dated records, not claims of current coverage.

- Reproduced a failed-removal metadata write deleting its managed video. Added an integration regression that blocks `library.json` writes, checks that media and library/playback state survive, reopens the saved library, and then verifies successful removal preserves the original. It failed before the fix and passed afterward.
- Reproduced retained browser video resuming behind the source directory, and repeated hide calls leaving visible video suspended. The new real-WebKit regression uses an embedded local H.264 fixture, cancels fixture HTTPS navigation, and checks directory/hidden-load suspension and idempotent show/hide. Both original failures were observed before the fix.
- A disposable probe compiled the production DesktopEngine with a test-only same-file extension to seed an expired rotation interval. One favourite produced three state publications on three immediate ticks before the fix; afterward it produced one. No production test hooks or five-minute waits were added.
- `scripts/test.sh` passed all standalone harnesses. `scripts/integration-test.sh` passed real video import/loop/pause/framing, persistence, failed import/removal commits, Workshop import, preview selection, and browser media lifecycle checks with isolated temporary data.
- Built version 1.5.3, build 12. The compressed DMG passed `hdiutil verify`, read-only attachment, strict app signature verification, Applications-link and payload checks, executable hash comparison against the build, SHA-256 sidecar verification, and clean detach.
- Ran `--render-previews` from the mounted app: all eight scenes rendered and changed over time. Raw investigation captures are excluded from the shipping app, including when rebuilding an existing `dist/` bundle.
- Native read-only inspection of the existing installed app covered library controls, source directory, an embedded provider page, and settings. It did not change saved wallpaper preferences or imported media. Playback policies and close/reopen behavior remain covered by their automated harnesses.

Not covered: Intel runtime, older macOS runtime, every remote provider download flow, every hardware/power/display transition, or a notarized first-install path. No claim of exhaustive bug freedom is made. The GitHub release must be verified separately after publication.

Environment: Apple silicon Mac, macOS 26.6.2 (25G83), Swift 6.4 command-line tools. Built against the installed macOS 26.5 SDK, deployment target 14.0. The 27 preview SDK lacks the new SwiftUI macro plugin in this command-line-tool installation. No toolchain installation or global configuration change was needed.

## Passed automated checks

- `./scripts/test.sh`: 20 assertions covering manual/sleep/lock pause precedence, battery and Low Power preferences, fullscreen preference, display routing, fallback after missing target, same-size untargeted displays, AppKit/CG coordinate conversion, and Codable library round-trip.
- `./scripts/integration-test.sh /tmp/Frontdrop-Test-Loop.mp4`: actual H.264 test video import, managed copy, thumbnail generation, favourites, persisted reload, active state, real looping beyond the 2-second duration, pause frame stability, muted audio, rejection of invalid media, and removal preserving the original.
- `Frontdrop --render-previews --output docs/previews`: all eight built-in scenes render through the production Metal pipeline; each differs at time 20 and 25 seconds. Output thumbnails are in `docs/previews/`.
- `codesign --verify --deep --strict --verbose=2`: packaged and installed app both satisfy their ad-hoc signatures.
- Initial 1.0 executable SHA-256: `070d7034ce39d4da060acced76e0c08431ffa5a6ed0ec95a09bc90a326f3c7ac`.

## Passed native UI checks

The installed app opens and displays eight original scenes. Search for `silk` shows one result; clearing restores eight. Favourite toggling and Favourites filtering work. The native MP4 picker imported the generated test clip, and Apply/Pause/Resume/Stop produced the expected status changes. Settings exposes all playback/rotation/login controls; Start at Login remained off.

The window-server records show:

- **All displays**: full-size wallpaper windows on the built-in display (1470 × 956 points) and Dell P2723DE (2560 × 1440 points), layer `-2147483622`.
- **Main display**: exactly one full-size wallpaper window.
- **After Stop and Quit**: no Frontdrop wallpaper windows remain.

Records: `docs/evidence/frontdrop-windows.json`, `frontdrop-single-display.json`, `frontdrop-after-stop.json`.

The initial layout clipped the sidebar and playback footers. Both columns are now explicitly constrained to the available height. The [final screenshot](frontdrop.png) shows the complete controls. REA passive capture: `ev_d7cb75606250eee6e4b66d5952f5b76620fe1e63d95dfc29c37aeb634911f311`, retained in `docs/evidence/frontdrop-final-ui-rea.json`.

An independent review scored all three material findings resolved: clipped footers, fullscreen matching on equal-sized displays, and explicit SDK override handling. Its **ship** verdict covers those scored fixes; it is not a claim of exhaustive testing.

## Untested or intentionally excluded

Actual power consumption and GPU energy use were not benchmarked. Physical display hot-unplug/reconnect, fullscreen transitions after the final geometry correction, enforced sleep/unlock transitions, automatic time-based rotation, login-service registration, and older macOS releases were not exhaustively exercised. Pause and geometry decisions are covered by automated policy checks; runtime support is bounded by the checks above.

Desktop icons remain above the configured window level, and source sets `ignoresMouseEvents = true`; a separate interactive desktop-icon click test was not performed. Lock Screen animation is not implemented.

The generated MP4 was removed from the user's Frontdrop library after testing. Initial 1.0 handoff state: eight bundled scenes, no imported test clips, no test favourites, all displays selected, wallpaper stopped, Start at Login off. The installed library window is open ready for **Set Wallpaper**.


## Community catalogue update — Frontdrop 1.1.0

Browse embeds live MotionBGS and DesktopHut pages in WKWebView, with native source selection, navigation, search, progress/cancel and import completion controls. Space wallpapers opens MotionBGS’s dedicated collection. Downloaded videos retain the original page URL, and downloads from the Space source are tagged Space. Web pages keep provider ads and consent controls. Frontdrop’s player supports videos, not interactive packages.

Fresh verification for this update:

- `scripts/test.sh`: 20 existing playback/display/persistence checks plus 11 catalogue URL, supported MIME/extension, HTML rejection and title checks passed.
- `scripts/integration-test.sh /tmp/Frontdrop-Test-Loop.mp4`: real import, thumbnail, muted loop/pause, removal, metadata persistence and legacy JSON without sourceURL passed.
- Native Browse search for Cloudscape loaded MotionBGS’s actual search result. Switching Space → Browse reset to MotionBGS home.
- DesktopHut’s SPACE download imported through WKDownload: 37,782,731 bytes, H.264 3840×2160, 25.13 seconds. Source retained as `https://www.desktophut.com/space-vqhz`.
- MotionBGS’s Cosmic Violet Nebula HD imported through its extensionless `/dl/hd/10314` endpoint: 18,789,006 bytes, H.264 1920×1080, 25.13 seconds. Original source retained as `https://motionbgs.com/cosmic-violet-nebula`, category Space. It played in the native library preview.
- Both downloads survived installed-app relaunch. Incoming staging was empty afterward. Existing activeID aurora, enabled true, all displays and user preferences remained intact. The two downloaded videos remain ready to use; Northern Lights continues playing.
- Build completed without warnings. Installed 1.1.0 app passed strict codesign verification; packaged and installed executable SHA-256 both `582499971cb3fb971a82c40eb24041d94733803b71997d3de780d55ef669613b`.
- Independent code/native UI review: ship at the tested 1120×820 window. Corrected source attribution during provisional download navigation and Space/Browse source reset; no remaining material P1/P2 findings.

Screenshots: [downloaded nebula](browse-download.png), [installed Space Browse](browse-space.png). REA passive evidence records: `docs/evidence/catalogue-download-ui-rea.json` and `catalogue-installed-ui-rea.json` (installed capture `ev_d0a6dbd3124ab07093f95e0662f11fa544a0f05a56f880cb408a4e4155736843`).

Cancellation and error handling were reviewed in code; URL and file-type policies were tested. Network interruption, forced termination mid-transfer, all provider formats and future provider changes were not exhaustively exercised. Catalogue pages require internet; imported videos play offline.


## Logo update — Frontdrop 1.1.1

Applied the user’s Canva export to the sidebar and Dock icon. Build now regenerates all ten standard iconset PNG sizes, the ICNS, and a monochrome ribbon template for the menu bar. The original 1254×1254 PNG is preserved verbatim. Installed resources match the packaged resources; strict codesign verification passed. Native library opened with the new sidebar logo and Northern Lights still playing on both displays. Library JSON and preferences exactly match the pre-update snapshot. [Native screenshot](frontdrop-branded.png); REA record `ev_0d012f7cd3d63ae74ec2eef33bf1f9fe8da757c569f361cf2beffdaf84039aff` in `evidence/frontdrop-logo-ui-rea.json`. This cosmetic update did not change player logic.

Independent branding finish review: **ship**, scoped to the supplied default-size native screenshot and icon assets. Logo fidelity, monochrome menu template and sidebar layout passed with no material defects.


## Revised logo and close-to-menu-bar — Frontdrop 1.1.2

Replaced Dock artwork with the revised Canva export. Sidebar uses an image-tool background-removal edit with actual alpha, no background tile; menu template uses that revised silhouette. Build and strict installed signature verification passed.

`./scripts/test.sh` passed 20 playback/display/persistence checks, 11 catalogue checks, and a real AppKit window-lifecycle test. The lifecycle test was first observed failing on closing the final user window while a wallpaper window remains; it passes with the observer controller. It also verifies reopening, retaining regular policy with Settings open, and accessory policy after the final Settings close.

Native X-button check: installed app became activationPolicy=1 (accessory) and only both wallpaper windows remained onscreen. Reopening using the native Window → Frontdrop command restored the library and activationPolicy=0 (regular). The explicit menu-bar Open Frontdrop action uses the same open-window scene and restores regular policy before opening; that specific status-item click was not exercised because the computer-use tree does not expose the status item. Library/preferences JSON matched the pre-update snapshot exactly, including the user’s active Yuta Okkotsu Summer Sky video.

Native screenshot [revised UI](frontdrop-revised.png), REA capture `ev_34fe33994e31757977f3ade779ba1474a64978d8f664c1ff52b47339ad160f71` in `evidence/frontdrop-revised-ui-rea.json`; post-close window record `evidence/frontdrop-after-close-revised.json`.

Independent finish review: **ship**, scoped to the native default-size screenshot, revised assets and window lifecycle. The small transparent logo renders cleanly without a tile, halo or clipping. No material defects identified.


## Discover collections — Frontdrop 1.2.0

Added Anime, Gaming, Nature, Cars, Abstract and Cyberpunk alongside Space. All six new shortcuts were clicked in the installed native app and loaded their matching live MotionBGS galleries. Collection searches retain a theme keyword: Nature + forest loaded nature forest results. Browse resets collection selection to MotionBGS; source picker and sidebar stay synchronized. New downloads inherit the selected collection category and remain accessible through Downloaded.

Fresh checks: 20 playback/display/persistence assertions, 26 catalogue assertions and the AppKit close/reopen/settings lifecycle test passed. Build completed and the installed app passed strict codesign verification. Library/preferences JSON matched the pre-update snapshot exactly. Actual remote response titles are retained in `evidence/discover-collections.json`. The default-size sidebar scrolls while branding/help stay fixed; smaller window sizes were not visually tested. Native capture: [Discover categories](discover-categories.png), REA `ev_319de05860b0bb48dc10bf956cd00a31d344e098b4beaab679251db87e725d9d` in `evidence/discover-ui-rea.json`. Downloads were not repeated for every collection; they use the previously verified shared transfer/import path.

Independent Discover finish review: **ship** at 1120×820. Seven collection shortcuts, matching selected source/page and fixed footer reviewed with no material defects.


## Catalogue ad blocking — Frontdrop 1.2.1

Added bundled WKContentRuleList network rules for known advertising hosts and provider-scoped hiding of ad slots and empty wrappers. Rules compile and attach before the first catalogue navigation, retaining the latest pending destination during compilation. Block ads defaults on, is saved locally, and reloads the current committed page when toggled. No external extension, service, broad content injection, or system-wide settings are used. This is a small targeted blocker, not a guarantee against every future advertisement.

Fresh `scripts/test.sh` passed 20 playback/display/persistence checks, 26 catalogue checks, the AppKit window lifecycle test, and a real WebKit test. That test compiles the shipping rules, verifies four ad elements/wrappers hidden, media/download/consent controls visible, disabling restores a slot, ad-host patterns match and wallpaper URLs remain allowed. Initial unsupported regex alternation was caught and changed to separate host rules; the fixture navigation race was corrected to wait for WKNavigationDelegate didFinish. Final build and installed strict codesign verification passed.

Native installed-app checks: Nature banner disappears with Block ads on; switching off brings the actual advertising iframe back; switching on removes it. MotionBGS search, detail video preview and the Cloudscape HD download/import worked while blocking was enabled. DesktopHut catalogue also loaded normally with its ad slots hidden. A final rule hides MotionBGS’s empty .ads wrappers (including the Advertisement placeholder).

Existing imports and playback preferences match the pre-update snapshot, with one new Cloudscape video from the verification download. The user’s active wallpaper was preserved. Block ads remained on after installed-app relaunch. Native final screenshot [ad-blocked Browse](adblock-browse.png), REA `ev_7b7c9b7c3915b70dc154ca853370490d622ebca16d38454720a8f1bfaa6f0e3c` in `evidence/adblock-ui-rea.json`. Default 1120×820 layout reviewed; smaller window sizes and all provider pages were not exhaustively tested.

Independent ad-blocking finish verdict: **ship** at 1120×820. Toggle fits, ad space is removed, and wallpaper content remains visible; no material defects identified in the reviewed scope. Packaged/installed executable SHA-256: `597db4520d41e0d7ad8cc79efca2106818ae00bc51e662b3ef88fffed4824195`.

## Catalogue coverage and responsiveness — Frontdrop 1.3.0

MotionBGS advertises 3,850+ Anime and 3,880+ Gaming wallpapers, but only exposes a page at a time. Both MotionBGS and DesktopHut now work within every Discover collection, with dedicated Anime/Gaming category URLs, 16 anime-series and 20 game search shortcuts, and persistent native Previous page / Next page controls derived only from the live page's same-host pagination links. Frontdrop does not copy or rehost the provider catalogue. Title search no longer injects a category word: a read-only Elden Ring comparison returned 22 wallpaper links for `games elden ring` and 23 for `elden ring` on the checked MotionBGS responses. Counts and remote content change over time.

Reproduced the old X/reopen problem in the installed app: after closing the library, reopening could leave only the wallpaper windows visible. The new window controller hides rather than destroys the library when X/Cmd-W is used, forwards SwiftUI's other delegate callbacks, avoids redundant activation-policy changes, and restores the actual library regardless of AppKit's visible-wallpaper-window flag. Native verification: open Anime, Next page to page 2, X, launch the app again using Finder; the same page 2 and selected sidebar collection returned. Wallpaper windows stayed running. The explicit status-item click remains outside this UI test; its existing Open Frontdrop action uses the same retained SwiftUI window.

A focused optimized production-renderer probe measured 210 ms for initial shader-preview construction and 76 ms for all eight GPU thumbnails on the main thread. Video view construction itself was 0–9 ms in that probe. The new preview paints its cached poster immediately, prepares Metal textures or AVFoundation assets asynchronously, cancels obsolete selections, then displays the renderer. Built-in thumbnails ship as renderer-derived PNGs; fallback thumbnail rendering runs off the main thread, with synchronized Metal texture-cache access. Unchanged playback/status/display values no longer repeatedly reset renderers or invalidate the entire library. The new preview harness measured about 1.3–1.6 ms for the synchronous selection/poster path on this Mac. This is time to immediate visual feedback, **not** time to the first animated/video frame or a general startup benchmark.

Fresh checks passed: 20 playback/display/persistence assertions, 30 catalogue URL/download assertions, AppKit close-to-menu-bar/reopen/settings tests, real WebKit ad-blocker tests, real AVFoundation import/loop/pause/mute/invalid-media/metadata tests, and the preview-host integration harness. The preview harness runs a real AppKit event loop and confirms immediate poster display, latest-selection wins, actual visible video playback, and pause after hiding/removing. It is run by `scripts/integration-test.sh path/to/a/short-video.mp4`. The original window regression was observed failing before the lifecycle change.

Installed-app UI checks covered both providers' Anime/Gaming category pages, MotionBGS page 2, DesktopHut Elden Ring shortcut search, rapid built-in scene selection, and Cloudscape/Yuta video previews. Default-window layout shows all new controls, the fixed help/footer and paging controls. Minimum-size layout and every provider page were not exhaustively reviewed. Provider downloads use the existing previously verified shared import path and were not repeated in this update. The library/preferences JSON matches the pre-update snapshot byte for byte. Strict installed codesign verification passes.

Independent code review: no critical or important findings. Updated the README's provider/search guidance and added the preview harness to the integration script. Native screenshot [expanded Gaming catalogue](expanded-catalogue.png), REA capture `ev_39b3070497eef0a0272177a9bb0d0ca2e2eb6a28d04c4f29773ac5039a09babd` in `evidence/responsiveness-ui-rea.json`. That catalogue capture used executable `410c2ef50656356e1afd6dfcc475731df987204fd19910a10678f4db437d723e`; the subsequent display-notification fix leaves the pictured UI unchanged. Final packaged/installed executable SHA-256: `b1059aede530d2c6d5c42476039e5aa7787b834f0692a45d5e82d6e9b2926620`. Installed version 1.3.0, build 7.

A final native lifecycle check exposed an additional source of close/reopen lag: regular/accessory activation-policy changes generate a screen-parameters notification, which previously forced all desktop players to restart. The desktop signature now includes selected display IDs, full frames and backing scales; a Dock-only visible-frame change preserves the players. A real DesktopEngine integration test was observed failing before this fix and passing afterward. Independent focused review found no important regressions.

Final installed-app observation in `evidence/responsiveness-window-lifecycle.json`: activation policy changed 0 → 1 → 0 (regular → accessory → regular), wallpaper window IDs **9012 and 9013** remained unchanged before X, after X, and after Finder reopen, and library window **9011** returned. The earlier pre-fix native observation changed wallpaper IDs on X, corroborating the regression test. Final integration checks (including actual video playback and immediate-poster feedback at 1.56 ms) passed; strict installed signature and byte-for-byte library/preferences preservation were checked again. Physical display reconnection/resolution changes and wake were not repeated in this update.

## Full-motion discovery — Frontdrop 1.4.0 (20 October 2026)

The user's preference is actual anime/game action and moving environments, rather than subtly animated character artwork. Research checked public video samples rather than relying on names: MotionBGS Tengen Uzui Fight and DesktopHut Zoro Sword Fight mostly preserve the same pose with effects; Sakugabooru post 319568 contains a multi-shot swordfight with character/camera motion; Mixkit item 30889 travels through a nebula. Metadata, inspected-media hashes and the rejection/selection observations are retained in `evidence/full-motion-source-checks.json`. These sample files were inspected temporarily and are not bundled in the app or repository.

Added **Animation & action** (Sakugabooru) and **Moving worlds** (Mixkit) above the existing Discover collections. Animation & action is the initial view, with fighting, background animation, running, character animation, effects and three game-animation shortcuts (Genshin Impact, Honkai Star Rail, League of Legends). Series/game searches use archive tags and keep `animated` and `rating:s`. Honkai Star Rail maps to the archive's `honkai:_star_rail` tag. The rating is the provider's classification, not a guarantee about every clip. Moving worlds includes space-flight and planet fly-through examples plus drone, ocean, cloud, traffic and driving collections. Dedicated sources display their own provider name; the old provider picker remains available in the existing collections. Generic live pages retain credits, controls and terms; no remote API, scraping of a catalogue into Frontdrop, or third-party video redistribution was added to the shipping app.

Native integration checks on the installed app: action gallery loads, an actual original MP4 link downloads into Anime & Games, Jujutsu Kaisen toolbar search loads matching animated results, Moving worlds loads Mixkit, Space flight opens the item page, and its free 720p personal-use button downloads into the new local Scenes category. Mixkit's cookie choices remain intact; Reject all was used. Both new imports retain original-page source links and can be found under Downloaded. The existing four imports and all saved preferences, including active Yuta wallpaper, remain unchanged; the two sample additions are recorded in `evidence/full-motion-imports.json`.

Known trade-offs: archive resolutions and loop lengths vary; action scenes can have cuts and may not loop seamlessly; some archive posts are GIFs rather than supported MP4 videos. Mixkit's free resolution and usage terms vary by clip (the checked space-flight download offers free 720p for personal use and paid higher resolution). Frontdrop shows source guidance and uses the provider's normal download flow. SetLiveWallpaper was investigated but not integrated: its home page displayed a defacement-style post and one preview returned invalid media. MoeWalls redirected to MotionBGS in the checked live requests, so it was not treated as a new source. Every catalogue item has not been reviewed.

Fresh validation: 20 playback/display/persistence assertions, 37 catalogue/download assertions, real AppKit window lifecycle and WebKit ad-blocker tests passed, and the release build completed. Independent code review found no critical/important issues in the new source routing, default selection, filtering, sidebar transitions or existing download integration. The final installed app is 1.4.0 build 8, with matching packaged/installed executable SHA-256 `326b77a3b04cf0f0f549081fe0a14c1add37191dde0c9023774149f3fbabbc1c`; strict codesign verification passed. This update does not change the renderer/window engine verified in 1.3.0. Minimum-window layout and all provider pages were not exhaustively tested.

Final native check after the game-shortcut addition: Genshin Impact opens `animated genshin_impact rating:s` and returns video sequence posts in the installed release. The default-size control layout and fixed footer were inspected. Native REA capture `ev_5443d1214a17416fb35d382d130eefb0cf9606331a46389b9a5f935365e84bd9` is saved in `evidence/full-motion-ui-rea.json`; screenshot: [full-motion discovery](full-motion-discovery.png). Packaged and installed hashes match, and all pre-update imported records/playback preferences were rechecked after launch. The two sample clips remain user-local downloads, outside the source tree and app bundle.

## Expanded source directory and Workshop Video import — 1.5.0 (20 October 2026)

Research and the distinction between public browsing and playable downloads are documented in [WallpaperSources.md](WallpaperSources.md). Official Wallpaper Engine documentation identifies Steam Workshop as its creator library and Video projects as ordinary video files; Backdrop documents reviewed community submissions and now exposes a public web gallery. No private Backdrop backend was queried.

Shipped: native Browse source directory; LiveWallpapers4Free alongside MotionBGS/DesktopHut; eleven Discover genres; title searches retained on provider switch; explicit external Steam/Backdrop links; local Workshop Video project import with manifest title/source and AVFoundation validation. Rejected Sakugabooru/Mixkit starting points removed. A source's wallpaper count is not advertised as a guarantee of variety, rights or full-scene motion.

Live checks in the installed app:

- LiveWallpapers4Free loaded in the native WKWebView with blocking enabled. Spyro and Journey download buttons returned actual MP4s, which imported and retained their source URLs. Media: H.264 1920×1080, 11.033 seconds, 1,812,652 bytes; HEVC 1920×1080, 7.674 seconds, 6,080,633 bytes. Both have mostly subtle effects/zoom in sampled frames, so no full-motion recommendations are pinned in the app. See [source-hub-imports.json](evidence/source-hub-imports.json).
- Searching Elden Ring produced site results; switching to MotionBGS retained Elden Ring and opened that provider's matching search page. The native provider menu exposes all three video libraries.
- MyLiveWallpapers loaded/paginated but its tested desktop download was a ZIP containing a custom MLW.VIDEO file, not MP4. It was excluded from the final source list. A new explicit error identifies this format when encountered. REA identified the original ZIP format/hash; local member/header observations are recorded in [mlw-package-check.json](evidence/mlw-package-check.json). No MLW decoder or software installation was attempted.
- Steam's homepage worked, but its own Video filter returned error 10; no native Steam download/search service is advertised. Workshop downloads still need to be obtained separately. The new import button accepts one downloaded Video project folder; Scene/Web/Application projects remain unsupported.
- Backdrop's public gallery and title search loaded in the browser. Detail pages offered previews and app-opening actions; no full asset was obtained.

ZIP handling streams exactly one supported video into a UUID filename. It rejects traversal/glob paths, unsupported/ambiguous archives and excessive expansion, bounds process execution, and never runs or installs archive contents. AVFoundation remains the final playable-video check. Temporary ZIP/media files are cleaned up on completion/failure.

Verification: 20 playback/display/persistence checks; 37 catalogue/download-policy checks; 10 Workshop manifest/path checks; ZIP byte-copy/managed-name/expansion-limit/ambiguity/non-video checks; real WebKit ad-blocker tests; close/reopen lifecycle tests. Integration tests verified actual video import/copy/thumbnails, muted looping/pause, unchanged display-player identity, Workshop manifest plus actual media import/attribution, metadata persistence and legacy compatibility. Preview selection remained immediate (about 1–2 ms to its cached poster), latest selection won, and hidden previews paused. Independent review found two directory/media state issues, fixed before installation; final review found no important remaining issue.

All six pre-existing imports and all playback settings, including the active wallpaper, were preserved. Two verified source videos were added to the user's library. No third-party media was added to app resources or the repository.

Final binary SHA-256: `b86e1af3ef0ba0bbd0eef3310e4f769fd20b06c2b9a08e42a469a520265927b3`. Both dist and installed app passed strict deep signature verification. Version 1.5.0, build 9.

Final installed native source-directory UI was captured by REA: `ev_e17641e62160e67ccc03f7b9eb6a0c4b5a8a56681f33ae47510d7f36c894cca3`. See [source-hub-ui-rea.json](evidence/source-hub-ui-rea.json) and [source-hub.png](source-hub.png).

## Uncropped video framing — 1.5.1 (20 October 2026)

The reported wallpaper, Aoi Todo, Itadori Yuji & Mahito, is a 3840×2160 video displayed on a 2940×1912 MacBook screen. The hardcoded AVPlayerLayer resizeAspectFill setting enlarged it to cover the taller display and cropped the sides. Imported/downloaded videos now default to Fit whole video (resizeAspect), with a per-wallpaper Fill screen override in the library inspector. Missing framing fields in existing libraries default to Fit without rewriting saved media/settings. The original video remains untouched; any edge framing already present in the source remains.

Tests verified legacy/default framing and saved overrides, live desktop changes without rebuilding windows/players, and same-video preview updates without rebuilding the decoder. Asynchronous preview preparation uses the current framing value. Existing video import, muted looping/pause, desktop lifecycle, catalogue, archive and Workshop checks passed. Independent review found no actionable issue.

Installed 1.5.1 build 10 and verified its strict deep signature. Native UI showed Fit whole video for the active wallpaper. After closing the library back to the menu bar, the actual desktop-player screenshot showed the full source width with black bars above/below, matching the original video's proportions. All nine imported videos, the active wallpaper and saved preferences were preserved exactly. See [video-framing-checks.json](evidence/video-framing-checks.json). Final executable SHA-256: `535937db79ed00f9f19d02f73deccd0ddfdc0cdf28a27aa02c41a11f8346c8dd`.

## MicroSD wallpaper storage — 1.5.2 (20 October 2026)

Migrated all 11 managed videos and library.json (12 files, 178,982,905 bytes) from the internal Application Support directory to `/Volumes/MicroSD/Frontdrop/Library`. Copied while the app was stopped, verified SHA-256 and byte count for every file before removing redundant internal copies, and replaced the old root with a compatibility symlink. The complete per-file migration manifest stays beside the user's library on the card; no third-party media was added to source/resources. The saved locator binds this path to the card's actual volume UUID.

Configured libraries reject missing drives, wrong UUIDs, missing roots and malformed preferences without creating an internal replacement. Import validates before and after asynchronous media preparation/copy, commits metadata before announcing success, and rejects metadata-write failures without publishing a phantom item. Downloads and ZIP extraction stage within the same library's Incoming directory. Settings displays the selected root. Other unconfigured installs keep their previous default; the small locator and normal WebKit cache are outside the managed media library.

Unit/policy, catalogue, window lifecycle, WebKit ad-blocker, archive, Workshop and storage-configuration checks passed. Full AVFoundation/desktop/preview integration passed after the change. The metadata-write failure test was observed failing before its fix and passing after it. An additional real-video integration run with TMPDIR on the actual microSD card passed import/copy/loop/playback/framing, metadata failure/restart and unavailable-directory checks; it cleaned up its own isolated library. Physical ejection of the user's active card was not attempted. Independent final review found no blocker.

Installed-app UI verified all 19 wallpapers, active Gojo vs Sukuna playback and the user's Fill screen choice, plus the new Settings path. All original media hashes and library.json remained identical after relaunch. [Settings screenshot](microsd-storage.png); [storage verification](evidence/microsd-storage-checks.json). Strict deep signature verification passed; packaged/installed executable SHA-256: `cd8271b11698594ea0b241dd4ed593b7972fa75eb86deccf44fcaa0572f15e7d`. Installed version 1.5.2, build 11.
