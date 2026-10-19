# Running → review → printed receipt

**Throwaway visual / motion prototype. Not production application code.**

## Open

No install or API key is needed. On this Mac:

```sh
open design/receipt-motion.prototype.html
```

For a local browser / T3 collaborative preview:

```sh
node design/serve-prototype.mjs
```

Open <http://127.0.0.1:4177/prototype>. The local-only server serves only this HTML and its two image assets. Stop with Ctrl-C. It does not expose the workspace or accept uploads.

## Main flow

1. **Tracking opens ready**, at zero distance/time. Start sample run progresses the location marker, distance, and elapsed time. It is not real GPS.
2. For a quicker review, use **Load a mid-run sample** outside the phone. This loads a paused 0.842 km / 00:04:38 sample on a roughly 1.043 km mapped waterfront path.
3. Resume → Pause. Finish is disabled while recording, and on a zero-distance run.
4. **Finish opens Review**, not an immediately committed activity. Edit the title (40 characters) and optional note (100 characters). Back returns to the same paused session and keeps the draft.
5. **Print receipt** creates one in-memory activity, preserving full-precision distance, elapsed time, and the actually progressed geometry. The unrun section is not printed.
6. Open the receipt's labelled graphic picker for Route / ASCII / Pace / Photo. The adjacent route icon cycles as a shortcut. Pace supports pointer and left/right keyboard inspection.
7. Save confirms in-memory collection. Pull the bottom grip; its hint/progress changes with the pull. Release early to restore, or past the threshold to detach and return to the archive. Tear off is the button/keyboard alternative.
8. **Share** opens a separate preview. It defaults to a route silhouette with the first and last 15% removed; date/time/location labels are omitted. Include note can be toggled. This is not a production anonymity guarantee: distinctive geometry or a personal note can identify a place. Nothing is exported or sent. Done returns to the existing receipt without reprinting.
9. Map drag/recenter is a bounded visual demonstration, not a full navigable map SDK. The geographic background and track transform together.

## Other scenarios

Expand **Try other states** outside the phone:
- Reset to ready.
- GPS unavailable / Restore demo GPS: an error illustration, not an actual OS permission prompt. Start is disabled until restored.
- Empty archive → Record a run or Import demo activity. Import loads fictional fixtures without an account.
- Short run + long title: a 24-metre / eight-second fixture to inspect wrapping and tiny geometry.

The receipt walkthrough, paper replay, night mode, reduced motion and direct screen/mode controls remain available. Existing archive activities are still fictional examples. New activities appear in that archive. State is lost on reload.

## Geographic map provenance

`assets/kallang-map.svg` contains actual OpenStreetMap street, water, building and park geometry, rendered locally with an original muted style. It is not Apple Maps, Google Maps, CARTO, or a live map API. No raster tile prefetch or runtime map requests are involved.

`assets/kallang-map.json` contains bounds, Web Mercator registration, the route's mapped coordinates, source timestamp, attribution/license, and compressed source extract. Data: **ODbL 1.0**, OpenStreetMap contributors. Original styling: CC0. The sample follows mapped Stadium Park Connector geometry; access, safety and navigation suitability are **not validated**. Visible attribution links to OSM copyright/licensing.

The photo treatment uses the existing illustrative `assets/run-candidate-2.jpg`, not a photo from the selected activity. HTML image paths point at this workspace; the local server resolves those allowlisted paths, and T3 image inlining supports publication.

## Limits

No live GPS, permission request, Health/Strava integration, authentication, backend, persistent storage, downloads, sharing integration, audio or native haptics. Heart rate, elevation, calories and pace charts are demo fixtures. Background location, battery use, native keyboard/safe-area behaviour and actual-device motion/haptics are not verified by browser captures. The fixed geographic extract is not an offline mapping product.

## Validation / captures

```sh
node design/check-run-flow.mjs run-flow-final
node design/check-receipt-motion.mjs run-flow-regression-final
node /Users/pratikrai/.pi/agent/skills/app-designer/scripts/shoot.mjs design/run-flow-storyboard.html --out design/shots/run-flow-final-scan --scale 3
node /Users/pratikrai/.pi/agent/skills/app-designer/scripts/shoot.mjs design/run-flow-storyboard.html --out design/shots/run-flow-final-small --width 375 --height 667 --scale 3
```

Final results: 56 passing flow checks, existing receipt regressions passing, and zero scan FAILs at both sizes/3×. Two independent review rounds scored 43→45/60; all five requested fixes confirmed. These are prototype checks, not production tracking certification.

Harnesses reuse the skill's existing Playwright/Chrome installation, with no app runtime dependency. `run-flow-storyboard.html` and `receipt-storyboard.html` are generated static companions, not the clickable deliverable. Repeated IDs in them are snapshot artifacts.

Queries: `?view=record` (also default), `?view=archive`, `?view=receipt&mode=ascii&static=1`, `?mode=pace&reduced=1`, `?view=receipt&theme=dark&static=1`.

## Decision

The user asked to build this extension. That is not final approval of product architecture, naming, receipt-first versus tracking-first launch, or reference fidelity. The ready screen is the presentation entry for this review, not a settled launch decision.
