# Where the wallpaper libraries come from

Research checked on 20 October 2026. This separates the source of a catalogue from whether Frontdrop can obtain and play its media.

| Library | Where the selection comes from | Frontdrop route |
| --- | --- | --- |
| Wallpaper Engine | Creators publish to Steam Workshop. The editor also turns still images into interactive scenes. | Browse the official Workshop; import the actual video from a downloaded **Video** project. No Scene/Web/Application renderer or Steam account/download integration is implemented. |
| Backdrop | Its own community submission and review system. The public website exposes a gallery with categories, motion filters and previews. | Explore the public gallery in a browser. Its full downloads use Backdrop; this is not a free Frontdrop media feed. |
| MotionBGS | Public video wallpaper site. A source credit to MotionBGS was visible on the Backdrop wallpaper inspected earlier. | Browse/download the site's video in Frontdrop. One matching credit does not establish a partnership, bulk sourcing or redistribution permission. |
| LiveWallpapers4Free | Public wallpaper collection with anime, gaming, 3D and environment categories and MP4 resolution choices. | New integrated provider, with live import checks recorded in Verification.md. |
| MyLiveWallpapers | Public archive; the tested desktop package contains MLW media intended for its Windows app. | Excluded from the final provider list after testing; a large page count did not establish Mac compatibility. |
| DesktopHut | Public wallpaper video collection with category and title search. | Existing integrated video provider retained as an alternative. |

## Evidence and limits

Wallpaper Engine's [official site](https://www.wallpaperengine.io/en) identifies Steam Workshop as its community library and says Steam handles uploads/downloads. Its [format guide](https://help.wallpaperengine.io/en/functionality/editingwallpapers.html) distinguishes Video files from Scene packages, HTML/JavaScript projects and applications. The [export guide](https://help.wallpaperengine.io/en/functionality/export.html) explains why an interactive scene is not simply an MP4 export. The [backup guide](https://help.wallpaperengine.io/en/steam/backup.html) identifies `steamapps/workshop/content/431960/<item ID>` as the download location. Owning Wallpaper Engine does not add its renderer to Frontdrop.

Cindori's [community publishing guide](https://cindori.com/support/backdrop/general/publishing-wallpapers) describes user submissions reviewed before publication. Its [public gallery](https://cindori.com/backdrop/wallpapers) is now available outside the app; inspected detail pages provide a preview and an “Open in Backdrop” action, rather than a public full-video download button. The [community guide](https://cindori.com/how-to/backdrop-community-wallpaper-platform-guide) documents iCloud access and trial/licence limits. This does not establish a public integration API or permission to mirror the assets.

Earlier REA evidence remains in [Evidence.md](Evidence.md), including the installed-app screenshot showing a MotionBGS source credit, linked playback frameworks and bundled model fields. Those observations do not reveal the complete backend, licensing arrangements or ingestion pipeline. No private CloudKit catalogue, downloaded Backdrop media or paid service was accessed for this change. The previously inspected Backdrop app path was unavailable during this research pass.

LiveWallpapers4Free has [anime](https://livewallpapers4free.com/category/anime-live-wallpapers/) and [game](https://livewallpapers4free.com/category/games-live-wallpapers/) collections, with additional 3D, nature and sci-fi categories. Its [Spyro example](https://livewallpapers4free.com/spyro-reignited-trilogy-free-live-wallpaper/) offers MP4 resolution choices; [Journey](https://livewallpapers4free.com/a-journey-into-the-endless-green-horizon/) is another environment example. Native WebKit downloads of both examples completed and imported successfully: Spyro is H.264 1080p, 11.03 seconds; Journey is HEVC 1080p, 7.67 seconds. Sampled frames show mostly subtle effects/zoom rather than full-scene action, so they are not highlighted as full-motion recommendations. There is no verified, universal full-motion filter across providers.

## Live checks

- MyLiveWallpapers loaded inside Frontdrop's real WKWebView, including anime results and native next-page navigation. The desktop download was a ZIP containing Read-Me.txt, instructions.jpg and a 35,206,224-byte MLW file. That file starts with MLW.VIDEO and has no observed MP4 ftyp/moov/mdat markers. The included instructions require its Windows software. This is not proof of encryption or a complete format analysis. The provider was removed from the final list. REA open_binary identified the original ZIP and its SHA-256; the temporary inspection copies were removed and the media was not bundled.
- Steam's public Workshop homepage loaded in the browser. Selecting its own Video type filter navigated to a browse URL that returned Steam error 10. This is a provider-side result observed on this date, not proof that the service is permanently unavailable. The app links to the working homepage and does not advertise a functioning native Workshop search/download service.
- Backdrop's public gallery and search loaded in the browser. Anime and gaming details showed duration/resolution and app-opening links. No full asset download was attempted.
- MoeWalls redirected to MotionBGS in earlier checks; counting it as a separate collection would inflate variety. Sakugabooru and Mixkit were removed from primary discovery because the user rejected them as a fit.

## What ships

Browse opens a native source directory. LiveWallpapers4Free, MotionBGS and DesktopHut share eleven subject collections and franchise search. Switching providers retains a submitted search. Steam Workshop and Backdrop are clearly marked external community references, not free direct-download providers. A local Workshop Video importer reads `project.json`, preserves title and a numeric Workshop source link, copies the actual video into managed storage, and validates playback. It rejects unsupported project types, missing files, path traversal and symlink escapes. It never runs scripts or imports a preview in place of the wallpaper.

Provider files remain on their original services. Frontdrop does not bundle, rehost or bulk mirror third-party wallpapers. Existing downloads and the currently applied wallpaper are preserved.
