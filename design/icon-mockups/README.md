# Starlight icon mockups

Five candidate macOS app icons for the Starlight rebrand. Each is drawn on
Apple's 1024 × 1024 icon grid (824 pt continuous-corner squircle with the
standard drop shadow) in cream and gold, with translucent glass layers.

| Concept | Look |
| --- | --- |
| `radiance` | Golden glass 5-point star over a frosted halo star and sun rays |
| `twin` | Gold sparkle behind a frosted-glass sparkle (Screen Sharing-style overlap) |
| `orbit` | Gold sparkle on a midnight sky, circled by a translucent ring |
| `flare` | Tall sparkle with a lens-flare streak and glass bokeh discs |
| `layers` | Three stacked translucent stars receding over a light burst |

- `concepts.mjs` / `lib.mjs`: the SVG generators.
- `render.mjs`: writes `svg/` and 1024 px `png/` (needs Node and Playwright's Chromium).
- `gallery.html`: side-by-side comparison, Dock previews and small-size ladders.

The app bundle still uses `client/moonlight.icns`. To ship one of these on
macOS, build an `.iconset` from its PNG with `sips` and run `iconutil -c icns`.
