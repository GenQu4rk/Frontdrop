---
name: Frontdrop
description: A native macOS gallery for a desktop in motion.
colors:
  accent: "rgb(68% 85% 75%)"
  canvas: "rgb(8.5% 9.5% 10.5%)"
  surface: "rgb(12% 13.5% 14.5%)"
rounded:
  button: "9pt"
  card: "12pt"
  preview: "14pt"
  inspector: "18pt"
---

# Frontdrop design

## Overview

Frontdrop is a native macOS media gallery. A dark canvas lets the wallpapers carry the colour; system typography, SF Symbols, a standard titlebar and familiar controls keep the interface quiet and usable. Sage identifies actions and meaningful selection states. Artwork previews use actual renderer output. Select, preview and apply are separate steps, and selected and applied states remain visibly distinct.

The library opens at **All wallpapers**. Local wallpapers lead the navigation; online discovery is a second group. Users can always stop playback and reveal their saved macOS wallpaper. Closing the library keeps playback and the menu-bar item running.

The brand mark is the user-supplied purple twin-ribbon F on charcoal, retained in `FrontdropLogo.png`. Use the revised Canva artwork for the Dock icon. The sidebar uses `FrontdropLogoTransparent.png` with genuine alpha, without a tile or clipping; the menu bar uses a monochrome template rendered from the revised silhouette. `scripts/build.sh` regenerates every icon size from the canonical artwork.

## Colors

`InterfaceStyle.swift` owns the shared palette recorded above. Use sage for prominent actions, selection borders, focus and active wallpaper status. Use the dark canvas behind the gallery and the slightly lighter surface for the selected wallpaper, card captions, browser controls and playback bar. Text uses native primary and secondary styles. White at low opacity supplies secondary control fills and quiet borders. Keep decorative app gradients out of the interface.

## Typography

Use the macOS system font and native semantic text styles. Gallery headings use a semibold display size (28pt); the selected wallpaper title is semibold (22pt). Section headings are semibold (17–18pt), card titles are semibold (13pt), and supporting copy uses callout or caption styles. Buttons use medium text (13pt, or 12pt for compact controls). Long selected titles and descriptions wrap; compact card titles and playback status truncate. Visible labels explain the purpose of pickers even where the native picker label is hidden.

## Layout

The default library window is 1120 × 820pt, with a minimum of 920 × 660pt. A `NavigationSplitView` gives the sidebar a 210–260pt width, ideally 228pt. Both column stacks are explicitly constrained to the `GeometryReader`'s available content height. Keep the sidebar footer outside its scrolling list and the playback bar outside the gallery or browser content so both remain visible at the bottom.

The sidebar places branding above a native scrolling list, then a fixed Add Video File action and Help & Sources footer. **Your library** contains All wallpapers, Favourites, Nature, Abstract, Anime & Games, Space, Scenes, Downloaded and Imported. **Discover online** contains Browse and eleven collection shortcuts: Anime, Gaming, Space, Nature, Fantasy, Movies & TV, Animals, City & landscapes, Cars, Abstract and Cyberpunk. The source picker and sidebar selection stay synchronized.

The gallery is one scrolling column with a title and count, a selected-wallpaper area, then an adaptive thumbnail grid. Gallery padding is 26pt; the grid uses 18pt gaps and a minimum card width of 180pt. Cards grow with the available width and reflow into additional columns. Each artwork region remains 132pt high. The selected area uses a flexible preview at left and a 220pt control column at right, separated by 22pt. Keep the preview host at a stable **260pt height**; framing and aspect-ratio changes must not resize the host.

Browse opens a native source directory, with content capped at 940pt and 28pt outer padding. Integrated video libraries come first; Steam Workshop and Backdrop are separate, expandable references with their access and format limits visible. Inside a provider, browser controls use two primary rows: navigation, Sources, collection home and Open in Browser above; visibly labelled Website and Collection pickers with Block ads below. A compact host/instruction line and optional series/game menu follow. Native pagination sits below the provider web view. The persistent playback bar stays below both the directory and browser.

## Elevation & Depth

Use tonal layering and restrained borders to distinguish regions. Gallery cards are flat at rest and gain a small shadow on hover (black at 22%, 10pt radius, 5pt downward offset). Preview playback controls sit on a dark translucent fill over the artwork. Import progress uses native material; avoid decorative shadows on ordinary panels.

## Shapes

Use gently rounded, clipped media and controls: shared buttons use the button radius, cards the card radius, preview media the preview radius and the selected-wallpaper container the inspector radius. The card favourite control uses an 8pt radius; its Preview hint is a capsule. Selection and keyboard focus use a clear sage outline (2pt). Preserve the logo silhouette rather than enclosing it in an extra tile.

## Components

### Actions and interaction feedback

`FluidButtonStyle` is the shared action treatment. Prominent actions have a sage fill and dark text; secondary actions use a translucent white fill. Standard padding is 14pt horizontally and 10pt vertically; compact actions use 10pt and 7pt. Hover brightens the prominent fill or strengthens the secondary fill. Enabled buttons scale to 1.015 on hover and 0.97 while pressed, using a spring with a 0.26-second response and 0.86 damping fraction. Disabled controls dim to 40% opacity. Preserve native button keyboard semantics and visible focus.

Cards show real artwork, title, category or playback state, and a separate favourite button. A sage border identifies the selected preview; **Previewing** and **On desktop** distinguish selection from application. Hover reveals a Preview hint, strengthens the border and scales the card to 1.018. The favourite action has its own keyboard focus and accessible label. Context menus offer Set Wallpaper, favourite changes and removal of imported video copies with confirmation.

Honour macOS Reduce Motion: remove the shared hover/press scale and animated transitions, retain visible colour and focus feedback, and keep library previews still. The preview play control is disabled with an explanation while Reduce Motion is enabled. Sidebar labels and provider rows use restrained hover feedback; provider arrows move only when motion is allowed.

### Selected wallpaper and playback

Local selection uses one stable preview host. Show its thumbnail immediately while media prepares asynchronously; hidden or occluded previews pause. Preview pause/play controls affect only the preview, while **Set Wallpaper** applies the selection to the chosen display (also available with ⌘Return).

Keep **Show on** visible above the display picker. Offer All displays, Main display and connected displays; a disconnected saved choice explains that the main display is used. For videos, keep **Video framing** visible above the native picker. Every imported or downloaded video defaults to **Fit whole video**, including legacy records without a framing field. Fit shows the whole video and may add black bars; **Fill screen** fills the display and may crop edges. The choice belongs to each wallpaper. Preview and desktop update their existing `AVPlayerLayer` gravity without recreating players; Metal shaders remain unchanged.

The fixed playback bar shows the active wallpaper and status, with Pause/Resume and Stop while desktop playback is enabled. When stopped, it explains that the macOS wallpaper is showing. It remains present in the library, source directory and provider browser. Stop or quit reveals the saved macOS wallpaper; the Lock Screen remains under macOS control.

### Discovery and imports

The source directory lists LiveWallpapers4Free, MotionBGS and DesktopHut as integrated video libraries. Each row names a real source and action; do not claim a combined collection size. Results remain on credited provider pages. Search covers the selected provider, retains the term when changing provider and does not add category keywords. Anime/Gaming expose compact native series/game menus. Pagination follows the page's actual next/previous links.

Block ads is on by default and retained locally. Changing it reloads the committed page; targeted content rules are installed before initial navigation. Wallpaper thumbnails, previews, downloads and credits remain part of the live provider page. Error messages offer Retry and dismissal; download progress offers cancellation, and completed downloads offer Show in Library and Set Wallpaper.

Guide users to preview actual motion rather than claiming a universal motion filter. Sakugabooru and Mixkit are excluded from discovery following user feedback; previously imported videos remain available, including the local Scenes filter. Steam handles downloads for an owned Wallpaper Engine copy. Frontdrop imports a user-selected Video project folder and preserves its manifest title and attribution; Scene, Web and Application projects require Wallpaper Engine's renderer. Backdrop's public gallery is an external reference, not a Frontdrop download source.

Some providers deliver desktop video inside a ZIP. Stream only a single supported video into a managed UUID filename; never extract archive paths or executable contents. Local file imports and drag-and-drop lead to naming before adding the video. Contextual empty states explain an empty collection, favourites or search and provide the relevant next action.

### Settings and app lifecycle

Settings is a native dark tabbed window (540 × 540pt) with **Playback**, **Library** and **Updates** tabs. Playback contains original-scene frame rate, automatic pause preferences and wallpaper rotation; videos retain their original frame rate. Locking the Mac or sleeping the display always pauses playback. Rotation uses favourites, or the whole library when no favourites are saved, and waits while paused.

Library contains Start Frontdrop at login, the actual selectable storage path, **Show Videos in Finder**, and the explanation of closing, stopping and quitting. This Mac uses `/Volumes/MicroSD/Frontdrop/Library`; videos, download/archive staging and library metadata share that root. Validate the configured mounted-volume UUID before reading/writing and after asynchronous imports. Unavailable storage must show an error without silently creating a library on another drive. Commit imported metadata before announcing success.

**Settings → Updates → Check for Updates** is the update path. The tab shows the installed version, checking/result/error status and a download action when a compatible newer release is available. Updates are manual: download the new app, quit Frontdrop and replace the installed copy. Keep the link to all GitHub releases visible.

Closing with X hides and preserves the library scene, browser history and scroll positions. Closing the last library/settings window changes activation policy to accessory: wallpaper playback and the menu-bar item continue while Frontdrop leaves the Dock. Open Frontdrop from the menu bar restores a regular app and the library window. Desktop wallpaper windows never count as user windows.

## Do's and Don'ts

- **Do** let real wallpaper artwork lead the gallery and preserve source attribution.
- **Do** keep display/framing labels, preview/application states, keyboard focus and playback controls visible.
- **Do** preserve the stable preview host, native Fit/Fill controls and responsive thumbnail grid.
- **Do** honour Reduce Motion in previews and interaction feedback.
- **Don't** apply a wallpaper merely because its card was selected.
- **Don't** turn browsing into the default starting screen or place discovery ahead of the local library.
- **Don't** imply Lock Screen support, automatic update installation or support for interactive Wallpaper Engine projects.
