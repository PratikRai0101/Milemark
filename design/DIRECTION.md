# Milemark design direction

Milemark is a native, local-first running app. The core loop is record → review
→ print → keep → share. The receipt is the product, not a metrics dashboard.
`MILEMARK` remains a working title; physical-device verification and release
work are tracked in the root README.

## Screens and interactions

- **Archive:** individual route silhouettes with dates and distances. Recognise
  a run by its shape, not by a basemap or a chart.
- **Recording:** distance leads; the map provides context. The default Milemark
  style uses a flat, muted MapKit basemap without traffic or points of interest,
  with the route and markers drawn by the app. Standard Apple styling is an
  optional setting. There is no custom vector-tile service.
- **Review:** edit a run title and optional note before printing. The recorded
  distance, duration and route geometry must remain continuous into the receipt.
- **Receipt:** paper feeds from a metal tray. Route, ASCII, pace and photo
  treatments share one graphic region; changing treatment must not reflow the
  whole receipt. Six statistics sit beneath it, followed by the note and footer.
- **Tear:** the paper follows a pull only after scrolling to its end. Short
  pulls restore it; a completed pull detaches it. A button provides the same
  action without the gesture.
- **Collection:** kept receipts stay on the phone.
- **Share:** preview the exported composition, defaulting to trimming the first
  and last 15% of the route. Omit recorded date, time and location. Do not claim
  anonymity: a distinctive route or personal note can still identify a place.

## Visual language

`App/Sources/Core/Design/Theme.swift` is the source of truth for colour, type
and layout tokens. Keep the palette narrow: neutral ground, white thermal
paper, near-black printed data, and a single orange signal for live recording.
Dark mode keeps the paper as a lit ivory object rather than a negative image.

Use system monospaced text for printed data and archive content, and system
sans for action labels. Type follows Dynamic Type. At accessibility sizes the
archive becomes one column, receipt statistics become two columns, and actions
stack rather than truncating. The exported share card deliberately retains a
fixed composition.

The distinctive details are the route geometry, printed ASCII and photo
textures, tray, torn paper edge and feed interaction. Do not replace them with
decorative dashboards, multiple accent colours or unrelated imagery. The
mile-marker glyph, MILEMARK masthead and receipt copy are original to this app.

## Motion and platform behaviour

`App/Sources/Core/Design/Motion.swift` owns timing. Paper feed is steady and
motor-like; gesture feedback is immediate. Reduce Motion removes travel while
preserving information and every action. Use native haptics and Liquid Glass
where available, with a fallback action bar on earlier iOS versions. Simulator
captures do not establish real-device haptic or background-recording quality.

Keep routes recognisably identical across archive, receipt and share, apart
from explicit privacy trimming. Pause breaks must not be joined by an invented
line. Demo routes are fictional activities derived from mapped streets; their
source and licence are documented in `ATTRIBUTION.md`.
