# Original Frontdrop artwork

Generated with the built-in image-generation tool on 19 October 2026. Animation is implemented in Scenes.metal. No Backdrop artwork is bundled.

## anime

Project asset: `Sources/Frontdrop/Resources/anime.png`

Use case: stylized-concept. Asset type: original widescreen wallpaper background for an animated Mac wallpaper app. A cinematic anime-inspired mountain railway halt at blue hour, small warmly lit wooden shelter and empty platform at right, dramatic distant cloud sea and mountains, pink and lavender twilight sky with a few stars, wild grasses in foreground. Beautiful detailed hand-painted background animation art, calm, sophisticated composition, no characters, no franchise references, no writing or logos or watermark. Wide 16:10 landscape. Keep centre and left spacious for desktop icons. No UI. Save as a project asset.

## nature

Project asset: `Sources/Frontdrop/Resources/nature.png`

Use case: photorealistic-natural. Asset type: original widescreen scenic wallpaper background for an animated Mac wallpaper app. A pristine alpine lake at dawn with a dark evergreen forest at its banks, layered mountain silhouettes, soft silver fog, peach light touching distant snow peaks. Still reflective water covers bottom half. Cinematic natural photography, believable fine texture, quiet restrained colours, no people, no buildings, no text or watermark. Wide 16:10 landscape. No UI. Save as a project asset.


## Frontdrop logo

User-supplied Canva export from `~/Downloads/Frontdrop.png`, received 19 October 2026. Preserved verbatim as `Sources/Frontdrop/Resources/FrontdropLogo.png` (SHA-256 `9dfd2d4d472461a73f4510057a1b1f5edd31fd0c6eaff5b596834faf39129641`). The app uses this artwork for the sidebar and produces standard macOS icon sizes using `scripts/make-icon.swift`. That script rounds the background tile and authors a monochrome ribbon silhouette for the system menu-bar template. No wallpaper assets or renderer code changed.

## Revised Frontdrop logo and transparent UI mark

User-supplied `~/Downloads/Frontdrop_Revised.png` replaces the original logo as the canonical Dock artwork, retained verbatim in FrontdropLogo.png. FrontdropLogoTransparent.png is the background-removal edit generated with the built-in image tool from that supplied image on 19 October 2026. The menu template is rendered from its alpha, so it follows the revised mark.

Edit prompt: Remove ONLY the dark charcoal background, including the space between the two purple ribbons. Output the identical two-ribbon purple F mark with a genuine transparent alpha background. Preserve exactly the original silhouette, purple gradient shading, edge highlights, relative placement, proportions and orientation. No new outlines, shadows, glows, text, frame, tile or redesign. Keep both ribbon tips entirely in frame. Center the isolated logo on a square transparent canvas, with about 8% clear margin around the visible artwork. This is a production UI logo asset, not a mockup. Faithfulness to the supplied logo is critical.

The eight `Resources/preview-*.png` files are pre-rendered thumbnails of Frontdrop's own bundled scenes, copied from the existing production-renderer outputs in `docs/previews/`. They avoid running the GPU thumbnail/readback pipeline on the interface thread at launch.
