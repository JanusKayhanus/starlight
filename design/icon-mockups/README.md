# Starlight icon mockups

Candidate macOS app icons for the Starlight rebrand. Each is drawn on
Apple's 1024 × 1024 icon grid (824 pt continuous-corner squircle with the
standard drop shadow) in cream and gold, with translucent glass layers.

| Concept | Look |
| --- | --- |
| `radiance` | Golden glass 5-point star over a frosted halo star and sun rays |
| `twin` | Gold sparkle behind a frosted-glass sparkle (Screen Sharing-style overlap) |
| `orbit` | Gold sparkle on a midnight sky, circled by a translucent ring |
| `flare` | Tall sparkle with a lens-flare streak and glass bokeh discs |
| `flareNight` | Flare on Orbit's midnight sky, with glowing gold bokeh rings |
| `layers` | Three stacked translucent stars receding over a light burst |

- `concepts.mjs` / `lib.mjs`: the SVG generators.
- `render.mjs`: writes `svg/` and 1024 px `png/` (needs Node and Playwright's Chromium).
- `gallery.html`: side-by-side comparison, Dock previews and small-size ladders.

- `make_icns.py`: packs a 1024 px PNG into a `.icns` without `iconutil`.

The app bundle uses Flare Night, built with:

    python3 design/icon-mockups/make_icns.py design/icon-mockups/png/flareNight.png client/starlight.icns
