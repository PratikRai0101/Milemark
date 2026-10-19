# Milemark

A running app for iPhone that turns every route into a printed receipt.

Milemark records a run on a real map, then prints it: a thermal-paper receipt
with your route drawn on it, your distance, pace and time, and an optional note.
Runs are kept in an archive of route silhouettes rather than a dashboard of
numbers, and finished receipts can be collected into a collection or shared
with the ends of the route trimmed.

<!-- The screenshots below are replaced by the release workflow. -->

## Status

**Early development.** The core loop — record a run, review it, print the
receipt, keep it — is implemented and runs on a simulator. Several surfaces are
still provisional.

| Area | State |
|---|---|
| Route recording with Core Location | Working, including pause/resume and background location |
| Route archive | Working |
| Printed receipt with four graphic treatments | Working |
| Review and share preview | Working |
| Photo print treatment | Placeholder |
| Strava import | Not implemented — the archive header is demo data |
| Health / heart rate | Not implemented — the receipt shows `—` |
| Sharing / export | Preview only; nothing is written to disk or sent |

## Requirements

- Xcode 27 or later
- iOS 18 or later
- A physical device to record a real run: the simulator has no location feed

## Building

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonaskolb/XcodeGen), so the project file is never
committed and there are no merge conflicts in it.

```sh
brew install xcodegen
xcodegen generate
open Milemark.xcodeproj
```

Then run the `Milemark` scheme, or from the command line:

```sh
xcodebuild -project Milemark.xcodeproj -scheme Milemark \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Testing

```sh
xcodebuild -project Milemark.xcodeproj -scheme Milemark \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`RouteGeometryTests` covers the parts where a bug would quietly produce a
wrong number rather than a crash: distance accumulation, sample rejection,
splits, pace formatting, route normalisation and endpoint trimming.

## Sample activities

The archive can load nine sample activities so a receipt can be seen before
recording a run of your own. Their routes are **real street loops** — genuine
closed circuits in the OpenStreetMap data bundled in `design/assets`, found by
`design/make-demo-routes.swift`. They are not recordings of anyone's run, and
the archive header says the data is demo data.

Two launch arguments help when capturing screenshots or driving the UI:

```sh
# seed the samples and open the first receipt
xcrun simctl launch booted app.milemark.app -seedDemoData -openReceipt
```

## Continuous integration

GitHub Actions builds the app and runs the tests on every push and pull
request.

## Design

The visual direction is documented in [`design/`](design/):

- [`design/DIRECTION.md`](design/DIRECTION.md) — the brief, the reference
  contract, the content, the tokens and the motion rules.
- [`design/CRITIQUE.md`](design/CRITIQUE.md) — two independent design reviews,
  the fixes they asked for, and the warnings that were deliberately accepted.
- [`design/receipt-motion.prototype.html`](design/receipt-motion.prototype.html)
  — the clickable prototype the app was built from.
- [`design/PROTOTYPE.md`](design/PROTOTYPE.md) — how to open and exercise the
  prototype.

`MILEMARK` is a working title. It is not a settled brand, and it is not
trademark-checked.

## How recording works

Milemark records location with Core Location and draws the route with MapKit.
Neither costs money: Apple's native map display has no usage charge, and
recording a route does not need a routing or directions service.

The recorder is deliberately strict, because a plausible-looking route that is
wrong is worse than no route at all:

- Fixes older than ten seconds, or with an accuracy worse than 40 m, are
  discarded.
- A jump that would imply running faster than 12 m/s is discarded.
- Movement smaller than 40 cm between samples is treated as noise, so standing
  still does not add distance.
- Pausing stops the clock and the distance. Resuming starts a new segment, so
  the route never draws a false straight line across the gap, and the distance
  covered during the pause is never counted.

None of this makes a route guaranteed accurate. It makes the app refuse to
invent distance when the signal is poor.

## Privacy

Runs are stored locally on the device. There is no account and no server.

The share preview leaves out the recorded date, time and location, and can trim
the first and last 15% of the route. That is not anonymity: a distinctive route,
a run title or a personal note can still identify a place or a person. The app
says so rather than implying a guarantee it cannot make.

## Licence

MIT. See [LICENSE](LICENSE).

Map data is drawn by MapKit at runtime. Any bundled or derived geographic data
in `design/` carries its own OpenStreetMap ODbL attribution.
