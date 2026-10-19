# Map data attribution

## `assets/kallang-map.svg`

A geographic background of Kallang and the Singapore Sports Hub, drawn from
real OpenStreetMap data.

- **Data:** © OpenStreetMap contributors, licensed under the
  [Open Database License 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
- **Rendering and styling:** original work by this project, dedicated under
  [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
- **Source:** a single bounded Overpass API extract, retrieved 18 October 2026.
  The response checksum and the compressed extract are recorded in
  `assets/kallang-map.json`.

The attribution "© OpenStreetMap contributors" appears in the app wherever this
background is shown, and links to <https://www.openstreetmap.org/copyright>.

The sample route follows the mapped geometry of the Stadium Park Connector. It
is a fictional sample: current access, closures, safety and suitability have
not been validated, and it is not a navigational route.

### `App/Sources/Core/Services/DemoRoute.swift`

The sample activities in the app follow real streets. `design/make-demo-routes.swift`
reads the same extract, builds a graph of the runnable footways, cycleways and
streets, and searches it for genuine closed loops — the streets a runner would
actually take around a block or a park. Those loops are checked in as Swift
source, so the app has no runtime dependency on the extract.

Regenerate them with:

```sh
swift design/make-demo-routes.swift design/assets/kallang-map.json \
  App/Sources/Core/Services/DemoRoute.swift
```

CARTO was not used. Its current basemap terms require an issued API key.

## `assets/run-candidate-2.jpg`

An illustrative photograph used for the photo print treatment in the visual
prototype. It is not a photograph from any recorded activity.

Source: <https://images.unsplash.com/photo-1502904550040-7534597429ae>
