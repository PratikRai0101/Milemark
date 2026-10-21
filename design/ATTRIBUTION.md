# Asset and map-data attribution

## Demo routes and `design/assets/kallang-map.json`

The sample activities in `App/Sources/Core/Services/DemoRoute.swift` follow
mapped streets and paths around Kallang and the Singapore Sports Hub.

- **Data:** © OpenStreetMap contributors, licensed under the
  [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
- **Attribution:** <https://www.openstreetmap.org/copyright>.
- **Source:** a single bounded Overpass API extract, retrieved 18 October 2026.
  Provenance, checksums, licensing and the gzip-compressed, base64-encoded
  source extract are preserved in `design/assets/kallang-map.json`.

`design/make-demo-routes.swift` reads the embedded extract, builds a graph of
runnable footways, cycleways and streets, and finds closed loops. These are
checked in as Swift source, so the app has no runtime dependency on the JSON.
Keep both the generator and its data so the fixtures can be regenerated:

```sh
swift design/make-demo-routes.swift design/assets/kallang-map.json \
  App/Sources/Core/Services/DemoRoute.swift
```

These are fictional sample workouts, not recorded GPS tracks or navigation
routes. Current access, closures, safety and suitability have not been
validated. The app labels sample activities and credits OpenStreetMap.

The JSON retains historical projection and rendering metadata from the retired
browser prototype, including the former SVG asset name. That SVG is no longer
shipped or used; the native app uses MapKit. The embedded source extract is
still needed for the route generator.

## `App/Resources/SamplePhoto.jpg`

An illustrative Unsplash photograph used by the native receipt's `-demoPhoto`
launch argument and screenshot workflow. It is not a photograph from a
recorded activity.

Source: <https://images.unsplash.com/photo-1502904550040-7534597429ae>
