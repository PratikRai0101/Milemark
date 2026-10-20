# Running app — reference-led motion prototype

## Current brief and correction

The user explicitly rejected the first three directions as too far from the supplied Strava / Run Receipt references. They liked the craft, but wanted the route traces, receipt UI and micro-animations themselves, not an unrelated visual identity.

**This instruction supersedes the provisional Open air recommendation.** Do not offer another three unrelated art directions. The first exploration is preserved in `exploration/DIRECTION-original.md` and `exploration/CRITIQUE-original.md`; its scores did not establish fidelity to the user's actual intent.

Deliver a clickable visual/motion prototype, not a production fitness app. Core: route archive → printed run receipt → route / ASCII / pace / photo views, plus a simulated recording surface. All state is in memory; no GPS, Strava connection, Health access, account, server or persistence is claimed. `MILEMARK` remains a temporary label, not Run Receipt's brand or logo.

## Reference contract: keep

- A dense three-column archive of individual route silhouettes, date and distance.
- Monochrome, neutral-grey app ground, white thermal-paper-like receipt, compact monospaced data.
- A dark physical output slot, paper feeding/revealing down from it, soft paper depth and serrated lower edge.
- Receipt header: activity, place, type and date; large central graphic; a six-value statistics grid; quiet footer.
- Switchable graphic treatments: route trace, ASCII route map, pace-bar chart, photographic halftone.
- Direct chart inspection with a moving crosshair and black pace callout.
- Press response, selected-view transitions, receipt detachment and a clear return to the archive.
- Tracking functionality represented visually with a route on a map, elapsed time, distance, pause / resume and finish.

Do not carry forward the cobalt poster, decorative stopwatch dial, big pre-run typography, unrelated marketing imagery or the assumption that Start run must own the launch screen. Do not copy the reference's logo or imply a working Strava connection.

## Motion study

The re-uploaded first video has the same SHA-1 as the first supplied video. New crop studies: `references/motion/feed-sequence.jpg` (0.25 s sample intervals), `tear-sequence.jpg` (0.333 s), `switch-sequence.jpg` (0.5 s). These are measured sample intervals, not inferred spring constants.

Observed: a route-grid interaction brings in an empty printer slot, paper progressively extends over roughly 1–2 s, content scrolls under the slot, controls stay reachable, tear-off releases the paper and returns to the grid. Graphic styles cross-change within the same fixed image region instead of navigating to unrelated screens.

Prototype timings are tuned approximations, not frame-perfect reproductions:
- Press: 90 ms compress to .97; spring-like release 220 ms.
- Archive → receipt: the new surface settles over 220 ms; paper reveals top-to-bottom in 1100 ms at a steady motor-like rate, with a shadow following its exposed edge. The first 220 ms exposes roughly the header strip. No looping idle animations.
- Route trace: 620 ms draw once when entering the route view.
- Graphic switch: the new graphic resolves over 240 ms with a 4 px / opacity change. The receipt body does not reflow. A fixed upper control band leaves the entire route / ASCII track clear.
- Pace bars: 420 ms from the baseline, at most 120 ms total propagation; scrubbing is immediate and keyboard-operable.
- Tear: short 120 ms lateral release, 430 ms downward departure with 3° rotation, then archive. Interrupted operations cancel pending demo actions.
- Save: 180 ms check / label replacement, in-memory collection state only.
- Tracking: simulated elapsed time and route progression, pause freezes both, finish creates a receipt from those displayed values AND the actually progressed route geometry. The unrun planned segment is not printed.
- Reduced motion: no feed travel, path drawing or paper rotation; 100 ms cross-fades and identical information/actions. No haptics or audio are claimed in the browser.

## Content fixed before layout

### Archive
MILEMARK. STRAVA IMPORT · DEMO DATA. 486.2 km this year. October 2026. Twelve sample runs:
- Sat 17: Interval, Singapore, 29.00 km, 03:24:25, 07′03″/km, 160 bpm, 101 m, 2303 kcal.
- Thu 15: Riverside easy, Singapore, 6.42 km, 00:37:14, 05′48″/km, 146 bpm, 26 m, 438 kcal.
- Tue 13: Track repeats, Singapore, 7.01 km, 00:39:22, 05′37″/km, 157 bpm, 12 m, 492 kcal.
- Sun 11: Recovery, Singapore, 4.86 km, 00:31:08, 06′24″/km, 133 bpm, 18 m, 316 kcal.
- Fri 09: Canal loop, Singapore, 6.01 km, 00:34:11, 05′41″/km, 148 bpm, 24 m, 412 kcal.
- Wed 07: Long run, Singapore, 10.01 km, 01:02:18, 06′13″/km, 151 bpm, 48 m, 734 kcal.
- Mon 05: Hill repeats, Singapore, 5.14 km, 00:32:09, 06′15″/km, 162 bpm, 96 m, 388 kcal.
- Sat 03: Park loop, Singapore, 6.51 km, 00:38:17, 05′53″/km, 145 bpm, 31 m, 451 kcal.
- Thu 01: Lunch run, Singapore, 3.05 km, 00:18:41, 06′08″/km, 140 bpm, 14 m, 203 kcal.
- Tue 29 Sep: Evening run, Singapore, 6.01 km, 00:35:18, 05′52″/km, 144 bpm, 22 m, 417 kcal.
- Sun 27 Sep: Sunday long, Singapore, 9.40 km, 00:59:04, 06′17″/km, 150 bpm, 42 m, 682 kcal.
- Fri 25 Sep: Shakeout, Singapore, 2.98 km, 00:18:22, 06′10″/km, 136 bpm, 9 m, 194 kcal.

### Receipt
Temporary original mark + Run receipt. Activity name and Singapore. OUTDOOR RUN and activity date. Central modes Route / ASCII map / Pace trend / Photo print. Distance, Avg pace, Avg HR, Duration, Elevation, Calories. KEEP FOR YOUR RECORDS. SAT–OCT 07:08 (date changes with record). A route worth keeping. Actions Save, Tear off, Replay. Back returns to archive. A save confirms collection only within this visual demo. Replay or navigation clears prior feedback. On compact phones the receipt scrolls in a viewport above the fixed action controls and home region.

### Tracking
Outdoor run. DEMO GPS. Kallang riverside. The original mid-run fixture is superseded by the extension below: ready at zero; optional mid-run playback at 0.842 km / 00:04:38 / approximately 05′30″ per km, on a roughly 1.043 km geographic Stadium Park Connector sample. Start, Pause / Resume, protected Finish, Review, then Print. Review and print derive their distance/duration/pace and progressed geometry from that session, never the unrelated 29 km activity.

## Tokens and intentional reference fidelity

Ground #EDEDEC; paper #FFFFFF; graphic #F7F7F5; primary ink #191A19; secondary #62645F; quiet ink #72746F; separators #D5D6D2. Black is the primary-action colour. Only live recording uses signal orange #DC522A. Background map water is a muted, low-saturation grey-blue, not a second UI accent.

Night ground #181A1A; archive tiles #282B2A; light labels #F1F1EC; secondary #B8BBB5; paper remains low-luminance ivory #DFDED6 with dark ink. It is a lit physical object on a dark app ground, not a negative-image receipt.

Typography: system monospace for printed data and archive (SF Mono / Menlo fallback); system sans only for native navigation / surrounding prototype instructions. Sizes 28, 22, 17, 15, 13, 11; live distance display 56. System-tab labels may use 10. Side margins 16–20 pt; paper inset 24; paper padding 20. Shape family: archive tile radius 13; slot capsule; content paper square with a serrated end; navigation capsules. Richness comes from actual route geometry, ASCII / halftone and the print interaction, not an unrelated photo banner.

The user-requested paper/mono/neutral look is intentional and overrides the earlier anti-default refusal of a receipt-led app. History distance is not a reason to ignore this explicit reference-fidelity correction. No final icon or new brand identity is in this iteration.

## Extension brief — 18 October 2026

User asked to build the next prototype pass, not production GPS. Keep the single reference-led direction and existing archive/receipt. Add ready/running/paused map states, GPS/empty-state demonstrations, finish review with optional title/note, print continuity, stronger direct-manipulation paper, and a privacy-conscious sharing preview. No new unrelated directions, social feed, paid API, real permissions or persistence.

Content before layout: Ready to run; Start sample run; Sample playback · not live GPS; Recording; Paused; Resume; Pause to finish; Review run; Back to run; Run title (40 characters); Run note (100 characters, optional); Print receipt; Share preview; Trim route ends (15% at each end, not guaranteed anonymity); Include note; Preview only — no file is sent; No routes yet; Record a run; Import demo activity; GPS unavailable · simulated; Restore demo GPS. Review and receipt use identical full-precision distance, duration and geometry. Very short runs print without division-by-zero. A share preview omits exact date/time and location, defaults to a trimmed route silhouette, and does not reuse the full route in hidden preview markup. This is illustrative privacy, not a production privacy guarantee.

Motion extension: steady paper travel under a fixed slot (~1000 ms), contact/exit shadows only; paper follows the pull immediately with restrained rotation and a progress hint; release below threshold returns, beyond threshold detaches; pointer cancellation restores the sheet; reduced motion preserves all actions without travel/rotation. Save swaps to check without a large overlay. Tracking never pulses on idle. Map can be panned and recentered; this is a bounded geographic sample background, not a navigable/offline map product.

Validation question: Does ready → run → pause → review → print → collect feel coherent, and do the share/privacy choices make sense? Broader platform/native stack and final branding remain undecided.

## Reference relationship

The app was inspired by a running app that prints a receipt for each run. What
was taken is the idea — a run recorded as a physical printout — and the motion
of paper feeding out of a machine. The receipt is **not** a copy.

Deliberate differences, made after reviewing the reference closely:

| | The reference | Here |
|---|---|---|
| Mark | A pair of running figures | A mile marker with a route running through it |
| Masthead | The product's own name | The MILEMARK wordmark |
| Footer | A centred stamp, a slogan, a fine-print line | Left-aligned `LOGGED …` with `PRINTED ON THIS PHONE` opposite |
| Slogan | "You kept the streak going." | "A route, printed." |
| Paper edge | A regular zigzag perforation | A torn edge with shallow fibres |
| Paper source | A black slot | A metal tray rail |
| Picture chrome | Badge top-left, circular control bottom-right | A caption strip along the bottom edge |
| Statistics | Three across, one below | Six in a three-by-two grid |
| Extra | — | Comparison with the last run on the same route |

No artwork, name or copy is taken from the reference app. The generic ideas —
a receipt is a document, and a document about a run can be printed — are not
anyone's.

## Prototype question

Does the route archive → printed, inspectable receipt experience now feel recognizably close to the supplied references, including its movement? Also, does the map/recording branch fit the same product rather than feeling bolted on?

Answer remains for the user. They requested the extension be built, not production implementation or final design approval. Do not promote throwaway HTML to production or claim GPS/haptic/native-device validation from it.

## Original delivery for user review (historical)

Interactive source: `receipt-motion.prototype.html`; usage: `PROTOTYPE.md`; generated static companion: `receipt-storyboard.html`. Nine states plus three feed-time frames rendered at3×; zero FAILs at402×874 and375×667. Independent critique43→45/60, nine of twelve lines≥4; Fidelity4/5. See `CRITIQUE.md` for the deliberately retained reference vocabulary, answered warnings and a final unrescored one-line pace-precision fix.

T3 preview checked opening/resting layouts and photo inlining. Historical interactive HTML attachment: `13a77085-832a-4494-87fa-3416c807d0d1-877b3ff1-1bfd-4dfb-b70c-34c3af848788-html`. The user initially could not see the helper-published output; a direct native render made it visible. Do not rely solely on shell-nested MCP publication for user-visible delivery.

## Current extension delivery — 18 October 2026

Same interactive source: `receipt-motion.prototype.html`. Entry is now the ready tracking state for this review, not an approved product launch decision. Main flow: start/resume/pause → Finish → editable review → Print → inspect/collect/share preview. A mid-run sample makes it quick to inspect without waiting. Added geographic background, bounded map drag/recenter, privacy preview with actual trimmed geometry, empty/import demo, in-phone simulated GPS recovery and short-run/long-title fixture. Optional notes persist through review, print and preview; no persistence across reloads.

Local launch: `node design/serve-prototype.mjs` → http://127.0.0.1:4177/prototype. Or open the HTML directly. The allowlisted local-only server resolves the two image assets and does not expose arbitrary workspace files. Inline comparison contains clearly labelled screenshots and an explicit link to the interactive prototype, so static evidence is not mistaken for the motion deliverable.

Current evidence: 12 states in `shots/run-flow-final/`, zero scan FAILs at both sizes/3× in `shots/run-flow-final-scan/` and `shots/run-flow-final-small/`; 56 browser checks pass. Existing receipt regressions also pass in `shots/run-flow-regression-final/`. Two independent extension reviews scored 43→45/60, nine of twelve lines≥4, none below3; Fidelity4/5. All five concrete review requests confirmed fixed. No source changes after final critique. See `CRITIQUE.md` and `PROTOTYPE.md` for limits and warning responses.

The geographic image is actual OSM data with original styling and visible attribution, not Apple Maps/MapKit, Google Maps, CARTO, live tile access or production GPS. The sample follows mapped Stadium Park Connector geometry but is fictional and not navigationally validated. No account, key, paid API, real import/export, backend or native haptic is involved.
