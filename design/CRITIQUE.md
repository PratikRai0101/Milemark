# Reference-led route / receipt prototype critique

The prior three-direction exploration is archived in `exploration/CRITIQUE-original.md`. Its visual-craft scores did not establish fidelity to the user's actual reference brief. This report covers the corrected, clickable route-and-receipt experience.

## Mechanical QA before independent review

Round 1 caught an incorrectly scaled ASCII hit-test, a hardcoded route start marker, a chart control covering its 0 km axis label, sub-44pt graphic controls, 10pt / clipped map labels, and stale feedback. The first five were corrected before independent review. An SVG fill / CSS colour mismatch also produced a false chart-contrast scan failure; assigning the same actual white to `color` / `currentColor` made the scan measure the visible treatment correctly. A test compared CSS-uppercased `innerText` with a mixed-case title; it was corrected to compare `textContent`.

Round 2, before independent review: all functional checks passed; 402×874 had zero FAILs. 375×667 had one real FAIL: a white night-mode home indicator over light paper. This was explicitly disclosed to the critic, along with the proposed protected bottom region. The archive's three-size warning was retained deliberately.

## Independent review — round 1

Task ID: `node:delegated-task:command%3Amcp%3Ac8445217-bb18-44f2-8acb-88c03f82cfea%3Adelegate-task%3Areceipt-motion-review-r1`

Provider/model: Pi / `openai/gpt-6.1-sol`, high reasoning. Read-only review of four reference studies, all twelve `motion-r2` full-size PNGs and six compact core PNGs, source and functional results. The critic additionally exercised compact scrolling and inspected route continuity. Motion judgments were based on captured frames and implementation, not frame-perfect video or native haptics.

### Six quick tests

- Logo: route archive and printed keepsake remain recognizable without MILEMARK. Recording alone is more conventional.
- Squint: graphic / silhouettes / live distance own their respective screens. Mode pill is comparatively substantial.
- Category: not an ordinary fitness dashboard, deliberately close to Run Receipt.
- Specificity: mono is printed-data language; ivory is physical paper at night; orange is recording. Large graphic overlays less resolved.
- Feature headline: “Your run, printed for keeps.” Compact continuity / presentation defects still prevent an editorially finished claim.
- Subtraction: slot and serration earn their place; duplicated replay and duplicate graphic-switch affordances are optional.

### Scores

| Line | Round 1 | Visible evidence |
|---|---:|---|
| Concept on the pixel | 4 | Route objects, slot, receipt statistics and serration communicate the keepsake. |
| Not the category average | 3 | Avoids fitness dashboards, intentionally inherits reference archive / receipt skeleton. |
| Not this skill's average | 3 | Paper / mono / rules are familiar, but explicitly requested and should remain. |
| Hierarchy | 4 | Receipt graphic, archive distances and live 6.24 each lead correctly. |
| Typography | 4 | Mono labels / bold values / headings are coherent; live distance has real scale contrast. |
| Colour | 4 | Paper separates from both grounds; orange has one recording role. |
| Richness | 4 | Geometry, ASCII, photo print, slot depth and paper edge earn attention. |
| Rhythm and space | 4 | Graphic, six statistics and footer group clearly. Compact layouts legitimately scroll. |
| Craft details | 3 | Finished run changed route; mode pill hid route start; obsolete toast remained. |
| Native fluency | 3 | Back / tabs / actions work, but compact paper painted into the home and action regions. |
| Signature | 4 | Feed → change graphic → inspect → tear is visible and concept-born, borrowed as requested. |
| Feature test | 3 | Screenshot-worthy receipt, but continuity / compact defects remained. |
| **Total / 60** | **43** | **7 / 12 lines ≥4; no line below 3.** |
| Fidelity (additional) | 4 | All requested archive, print, mode, data and return features recognizable; early feed felt more like a wipe. |

Verdict: **Not done by the rubric stop rule. Ready for the narrow user reference/motion review after continuity and safe-area corrections.** Do not invent a new identity to raise lines 2/3 against the user's stated preference.

### Five asks and response

1. **Preserve recorded geometry on finish. Accepted.** `finishRun()` now samples the actually progressed SVG route, normalizes it into the receipt, and retains the source / fraction / points for validation. The unfinished planned segment is not printed. Route and ASCII reuse that same stored path.
2. **Protect the home region. Accepted and strengthened.** Archive scrolling stops 16pt above the device bottom. Receipt viewport now ends 100pt above the bottom, before its fixed action controls; a quiet bottom material gradient separates the actions. This protects both the home indicator and readable content from painting through the buttons. Full-size paper still fits; compact receipts scroll. No wholesale type or receipt shrink.
3. **Keep route starts clear of mode controls. Accepted.** Plot fitting reserves the first 62 units of a fixed 300×270 graphic coordinate system, then fits actual geometry into 240×176. The same transform is used for route and ASCII. The alternate cycle button moves into the top control band. Redundant lower graphic caption removed.
4. **Clear prior feedback on new receipt / replay. Accepted.** View transitions clear the toast timer and hide obsolete feedback before feeding a new receipt.
5. **Improve emerging-paper timing / edge. Accepted.** The 1100ms feed is now motor-like linear rather than front-loaded: 220ms exposes about 20%, not half the receipt. A subtle shadow tracks the exposed edge. Travel cancels / reduced motion remain supported.

Optional: removed duplicate toolbar replay (bottom Replay and outside replay remain); replaced the mode pill's menu-promising chevron with a cycle glyph. Kept both direct mode-label cycling and a cycle icon for this exploratory interaction; either is discoverable without requiring a new menu or gesture tutorial.

## Independent review — round 2

Task ID: `node:delegated-task:command%3Amcp%3Ac8445217-bb18-44f2-8acb-88c03f82cfea%3Adelegate-task%3Areceipt-motion-review-r2`

Same provider/model and original brief, with all prior findings / responses supplied in the new delegated round as required by the harness. The critic reviewed all twelve `motion-r3` frames, six compact core frames, reference sequences, source and QA. All five asks landed. Deliberate reference-fidelity choices were retained.

| Line | R1 → R2 | Final evidence |
|---|---:|---|
| Concept on the pixel | 4 → 4 | Route archive, output slot, printed statistics and serration retain the keepsake idea. |
| Not the category average | 3 → 3 | Intentionally close to the requested reference skeleton, not an ordinary dashboard. |
| Not this skill's average | 3 → 3 | Familiar paper / mono vocabulary is purposeful and user-requested. |
| Hierarchy | 4 → 4 | Graphic / silhouettes / live distance lead their respective surfaces. |
| Typography | 4 → 4 | Bold values and quiet metadata remain coherent; live distance supplies scale. |
| Colour | 4 → 4 | Lit white / ivory paper remains distinct; orange confined to recording. |
| Richness | 4 → 4 | Geometry, ASCII, photo print, physical slot and edge earn attention. |
| Rhythm and space | 4 → 4 | Groups remain clear; compact scroll rather than illegible compression. |
| Craft details | 3 → 4 | Recorded geometry, route-start clearance and fresh feedback fix conspicuous defects. |
| Native fluency | 3 → 4 | Compact viewport excludes fixed controls / home; navigation and thumb-zone actions remain coherent. |
| Signature | 4 → 4 | Feed / inspect / tear clear; controlled output timing and edge materiality improved. |
| Feature test | 3 → 3 | Strong screenshot-worthy reference study, not an independently editorially finished product. |
| **Total / 60** | **43 → 45** | **9 / 12 lines ≥4; none below 3.** |
| Fidelity (additional) | 4 → 4 | Every required feature retained; continuity / control clearance / feed improve fidelity. |

Verdict: **Done by the stop rule in critique.md. Ready for the narrow user reference/motion review.** User approval, native feel and production readiness remain unverified. Optional mode-control redundancy is not a blocker.

### Concrete defect after “done” — fixed, not independently rescored

The critic caught a one-second pace discontinuity at a rounding boundary: paused 6.25 km / 00:34:19 / 05′30″ became a receipt showing 05′29″ because kilometres had been rounded before deriving pace. `finishRun()` now retains the original precision, just like recording; only the rendered distance is rounded. A boundary fixture (`6.24 + 2/330` km, 2059 seconds) now asserts identical displayed pace. Final PNGs show matching 05′30″. This is a one-line data correction after the last design score, explicitly unrescored; no layout or interaction redesign followed review.

## Final verification

- Source: `receipt-motion.prototype.html`.
- Final captures: `shots/motion-final/`; static skill scans / captures in `shots/motion-final-scan/` and `shots/motion-final-small/`.
- **Zero FAILs** across all nine states at both **402×874** and **375×667**, rendered **3×**.
- Functional results: `shots/motion-final/checks.json`. Route start clear; pointer / keyboard chart scrubbing; photo load; time progression / pause freeze; matching displayed finish distance and pace; progressed geometry retained; save, tear, fresh feedback, reduced motion and walkthrough interruption; every app button at least44pt; no horizontal overflow at728 /390 /320; compact footer / grip reachability; no console or request errors.
- **Answered warnings:** the archive's three-size hierarchy is intentional because silhouette and distance are the primary object hierarchy. Compact safe-area warnings refer to off-viewport text whose DOM boxes still exist in a clipped scroll view. Actual paint stops above the native home region (archive16pt; receipt100pt), screenshots show the protected ground, and runtime checks confirm the paper grip can scroll into the clear area above the controls. These are not hidden inaccessible fields.
- T3 `html_preview` checked the interactive opening and resting layout at728 and390px; the rest preview lands animations solely for the screenshot. Photo-print preview verifies that the local asset is inlined and loads in T3 too. Console output clean. Live published HTML retains its feed animation.

Do not call this App Store feature-ready, native-device-verified or user-approved merely because it is ready to discuss reference fidelity.

## Running-flow extension — 18 October 2026

The user requested implementation of the next visual prototype pass: geographic recording states, finish review → print, more controlled paper manipulation, sharing/privacy preview and meaningful empty/error fixtures. Same reference-led direction; no new exploration or production GPS implementation.

### Independent review rounds

Review provider/model: Pi / `openai/gpt-6.1-sol`, high reasoning. Each round was a new delegated task carrying the original brief and prior findings. Reviewer inspected every full-size frame plus compact review/share/GPS/night frames and source. In round 2 it inspected the recorded browser results; it did not independently rerun all 56 checks.

- Round 1 task: `node:delegated-task:command%3Amcp%3A7a9f401d-99b2-440e-9286-11c6fe8a472e%3Adelegate-task%3Arunning-flow-critique-r1`.
- Round 2 task: `node:delegated-task:command%3Amcp%3A7a9f401d-99b2-440e-9286-11c6fe8a472e%3Adelegate-task%3Arunning-flow-critique-r2`.

| Rubric | Round 1 → 2 | Evidence / reason |
|---|---|---|
| Concept on the pixel | 4 → 4 | Geographic track becomes the same printed keepsake geometry. |
| Not the category average | 3 → 3 | Deliberately reference-led receipt; practical map recording remains familiar. |
| Not this skill's average | 3 → 3 | Required paper / mono / neutral vocabulary retained. |
| Hierarchy | 4 → 4 | Distance leads tracking/review; printed graphic leads receipt. |
| Typography | 4 → 4 | Tabular numerals, quiet metadata, readable native-style form text. |
| Colour | 4 → 4 | Signal orange has a location/recording role; night review uses deliberate materials. |
| Richness | 4 → 4 | Actual OSM geography, physical slot, route silhouettes and ASCII field. |
| Rhythm and space | 4 → 4 | Clear groups and protected fixed actions; compact layouts scroll. |
| Craft details | 3 → 4 | Empty-state totals corrected; privacy claim qualified; long titles wrap. |
| Native fluency | 3 → 4 | In-phone GPS recovery, cancellable tear, reduced map travel, coherent back/primary actions. |
| Signature | 4 → 4 | Feed → inspect → pull to collect is preserved, including interrupted navigation. |
| Feature test | 3 → 3 | A resolved reference-led prototype, not a final ownable editorial identity. |
| **Total / 60** | **43 → 45** | **9 of 12 ≥4, none <3.** |
| Fidelity (separate) | 4 → 4 | Archive, thermal paper, graphic modes, recording continuity and collection retained. |

### All five requests applied and confirmed

1. Retain `tearAnimation`; cancel on navigation/reopen, restore transform/opacity/grip/dragging, invalidate the old callback through the view token. Regression opens a different receipt 80 ms into departure and verifies it remains intact.
2. Disable `#map-geography` transform transitions for both OS reduced motion and the prototype checkbox, including query initialization.
3. Share copy distinguishes omitted recorded metadata from identifying title/note text and distinctive route geometry. Real endpoint trimming remains; this is not an anonymity guarantee.
4. Empty archive hides the imported source line and annual aggregate; demo import restores populated metadata.
5. GPS-error warning contains its own working Restore demo GPS action, rather than requiring the outside scenario rail.

No requests were declined. Round-2 verdict: **Done by the stop rule in critique.md; no additional blocking defect identified.** Remaining 3s are distinctiveness ceilings, not open implementation asks. No source changes followed the second critique.

### Verification and answered warnings

- `shots/run-flow-final/checks.json`: **56 passing checks**, zero failures. Covers ready/start, geographic asset load, progression/pause, finish protection, non-destructive review, draft retention, exact print data/title/note, explicit graphic picker, actual share trimming and note removal, short pull / cancellation / threshold tear / interruption, GPS recovery, empty metadata, short-run values, compact scroll/reachability, both reduced-motion mechanisms, viewer reflow at 320/390/728 and no browser/request errors.
- `shots/run-flow-final-scan/` and `shots/run-flow-final-small/`: **zero FAILs** across 12 states at 402×874 and 375×667, 3×. Runtime checks verify fixed controls outside the clipped scroll region and reachable final text.
- Existing receipt/chart/photo/walkthrough regressions rerun against the final source in `shots/run-flow-regression-final/`; no failed checks, undersized app buttons or console/request errors.
- Type-scale warning accepted: sizes span the printed-data hierarchy, tracking displays, native-style navigation and 16 px form text (to avoid mobile input zoom), not eleven levels within one screen. Metadata remains at least 11 px.
- Safe-area warnings concern off-viewport DOM text inside explicitly clipped scroll areas; screenshots and runtime reachability/bounds checks confirm protected controls/home region. The missing-pace em dash at zero distance is a meaningful unavailable-value symbol, not prose filler.
- Real geographic asset: `assets/kallang-map.svg`; provenance/projection/license/route/source extract in `assets/kallang-map.json`. OSM data is ODbL, original rendering CC0. Sample route follows Stadium Park Connector; not navigation-validated.

Local interactive delivery: `node design/serve-prototype.mjs`, http://127.0.0.1:4177/prototype. Native inline comparison uses rendered screenshots and clearly distinguishes them from the interactive prototype. A local browser server is required for that link; the HTML can also be opened directly. Neither browser review nor these checks validate native tracking, battery use, background recovery, haptics or real-device keyboard behaviour.

## App build — 20 October 2026

The prototype is now a working iOS app. Two independent review passes were run
against the built app rather than the prototype, and every finding was either
fixed or listed below as remaining work.

### What the reviews found and what was done

The first pass found five defects that would have shipped:

| Finding | Fix |
|---|---|
| Locking the phone stopped the recording | The clock is read from the dates, not from the view's timer, and the view no longer pauses on a scene change |
| "Print receipt" never opened the receipt | The printed run is now the destination, and the recorder is prepared again afterwards |
| Splits were timed from the first sample past the boundary | The crossing is interpolated, and time spent paused is excluded |
| A failed save lost the run silently | The store reports the failure, the recording is kept, and a run that was not written is not in the archive |
| The comparison could state the opposite result | The direction comes from the pace, and the time and the pace are quoted separately when they disagree |

The second pass found the fixes above were incomplete in six places, all now
closed: the clock was still read from a cached value, an automatic pause did
not stop the clock, each piece of a route was normalised separately so a short
leg filled the frame, three renderers still joined a pause with a straight
line, the photograph was anchored at the corner instead of centred, and a route
of the same shape somewhere else counted as the same route.

### Current state

- 33 unit tests and 5 UI tests, passing locally and on CI.
- The receipt prints the route, the ASCII map, the pace chart and a photograph
  in three ways; the ASCII map and the photograph are printed row by row.
- Haptics, Liquid Glass where the system provides it, a zoom from the archive
  into a receipt, and a reduced-motion path that removes travel without
  removing anything.

### Known limits

- The receipt uses fixed type sizes. The paper is meant to be a printed
  artefact, but the app's own text should follow Dynamic Type, and this is not
  done.
- Background recording is verified by construction and by tests, not on a
  locked device.
- The map is Apple's map, muted. A custom style is possible and is not done.
