# The map press

A figure that explains what a map style is.

A map is not one picture. It is a stack of layers: water, land, roads,
buildings, labels, pins, traffic — and then, on top of them, the route. A
style is a decision about which of those layers are fitted and how much ink
each one gets.

MapKit does not let an app repaint the map itself. Repainting it means
running your own tile server with your own vector style, which is a server
and an account and a bill. What MapKit *does* let an app do is hold Apple's
map back — flat instead of realistic, muted instead of coloured, with the
points of interest and the traffic taken off it — and then draw over it in
its own ink. That is enough to make the map the app's own, and it is what
Milemark does.

The figure shows the stack as a proofing press. The lever sets the basemap's
ink: pulled back, the map is a whisper. The route has its own pot, so it
never fades with the rest.

## Building it

```sh
node design/map-style/build.mjs          # the dark page
node design/map-style/build.mjs --light  # the light page
```

The page is `map-style.html`. Drag across it, or use the arrow keys, to set
the basemap ink.

The anatomy kit is borrowed from the skill of the same name rather than
being vendored here, the same way the frame renderer borrows Playwright.
