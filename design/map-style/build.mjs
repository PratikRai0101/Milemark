// Builds the map-style figure: a proofing press where the basemap is a
// stack of inked plates and the app's route is inked on the top plate.
//
// The idea the figure explains: a map is not one picture but a stack of
// layers, and a style is a decision about which of them are fitted and how
// much ink each one gets. The route has its own ink pot, so it never fades
// when the basemap is held back.
//
// The kit lives with the anatomy skill rather than in this repository, the
// same way the frame renderer borrows Playwright.
//
// Usage: node design/map-style/build.mjs
import { writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SKILL = "/Users/pratikrai/.agents/skills/anatomy";
if (!existsSync(join(SKILL, "kit/iso-kit.mjs"))) {
  console.error("The anatomy kit is not at " + SKILL + ". Nothing was written.");
  process.exit(1);
}
const k = await import(join(SKILL, "kit/iso-kit.mjs"));
const { kitScript } = await import(join(SKILL, "scripts/inline-kit.mjs"));

const HERE = dirname(fileURLToPath(import.meta.url));
const theme = process.argv.includes("--light") ? "light" : "dark";

const WIDTH = 700;
const HEIGHT = 520;

// --- the machine -----------------------------------------------------------

const BASE = { x: -150, y: -92, w: 300, d: 172, r: 12 };
const BASE_H = 10;
const FOOT_H = 8;

const TRAY = { x: -124, y: -60, w: 196, d: 122, r: 7 };
const TRAY_Z = BASE_H;
const TRAY_H = 5;

const PAPER = { x: -118, y: -54, w: 184, d: 110, r: 3 };
const PAPER_Z = TRAY_Z + TRAY_H;
const PAPER_H = 1.4;

const PLATE = { x: -112, y: -48, w: 178, d: 102, r: 4 };
const PLATE_H = 2.6;
const PLATE_GAP = 7;
const PLATE_Z0 = PAPER_Z + PAPER_H + 2;
const PLATE_FAN_X = 1.5;
const PLATE_FAN_Y = -0.9;

const COLUMN = { x: 122, y: 32, w: 22, d: 22, r: 4 };
const COLUMN_Z = BASE_H;
const COLUMN_H = 104;

const ARM = { x: -104, y: 36, w: 250, d: 20, r: 5 };
const ARM_Z = COLUMN_Z + COLUMN_H;
const ARM_H = 11;

const HEAD = { x: -68, y: 6, w: 104, d: 56, r: 8 };
const HEAD_H = 15;
const HEAD_Z = ARM_Z - HEAD_H;
// The head is a platen that runs along the arm: it parks to the right when
// the press is idle, and comes over the stack to print.
const HEAD_TRAVEL_X = 78;
const HEAD_TRAVEL_Z = 26;

const LEVER = { x: 98, y: -58, w: 48, d: 44, r: 8 };
const LEVER_Z = BASE_H;
const SLOT_Y = -38;
const SLOT_X0 = 106;
const SLOT_X1 = 140;

const POT_BASE = [70, -64];
const POT_ROUTE = [84, -68];

// --- the plates ------------------------------------------------------------
//
// Each plate is one layer of the map. The order is the order the map is
// built in: the ground, then the things on it, then the names, then the
// things that are only useful if you are driving, and the route last.

const PLATES = [
  { key: "water", name: "Water", tone: "blue" },
  { key: "land", name: "Land and parks", tone: "green" },
  { key: "roads", name: "Roads", tone: "hi" },
  { key: "buildings", name: "Buildings", tone: "mid" },
  { key: "labels", name: "Labels", tone: "mid" },
  { key: "pins", name: "Points of interest", tone: "red" },
  { key: "traffic", name: "Traffic", tone: "green" },
  { key: "route", name: "The route", tone: "signal" },
];

// The route, as a closed loop with a kink in it, in world units.
const ROUTE = [
  [-104, 8], [-86, 22], [-62, 26], [-40, 16], [-20, 22], [4, 30],
  [28, 24], [48, 12], [58, -4], [46, -22], [24, -30], [2, -28],
  [-16, -34], [-38, -30], [-58, -36], [-78, -28], [-96, -16], [-104, 8],
];

const P = k.fitProjection(
  [
    ...k.boxCorners(BASE, -FOOT_H, BASE_H),
    ...k.boxCorners(COLUMN, COLUMN_Z, ARM_Z + ARM_H),
    [HEAD.x + HEAD.w, HEAD.y, HEAD_Z + HEAD_H],
    [LEVER.x, LEVER.y, LEVER_Z + 4],
  ],
  WIDTH,
  HEIGHT,
  { pad: 34, azimuth: 40, elevation: 26 },
);

const at = (point) => k.iso(point, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);
const byDepth = (points) =>
  [...points].sort(
    (a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P),
  );

// The plan of a plate, moved along with the fan.
const platePlan = (index) => ({
  x: PLATE.x + index * PLATE_FAN_X,
  y: PLATE.y + index * PLATE_FAN_Y,
  w: PLATE.w,
  d: PLATE.d,
  r: PLATE.r,
});
const plateZ = (index) => PLATE_Z0 + index * PLATE_GAP;
const plateTop = (index) => plateZ(index) + PLATE_H;

// --- the ink on each plate -------------------------------------------------

// A line drawn on the top of a plate, in world units.
const onPlate = (index, points, closed = false) =>
  k.onTop(points.map(([x, y]) => [x, y, plateTop(index)]), plateTop(index), P, closed);

// The marks each plate carries. They are drawn on the plate's top face, and
// each one is the thing that plate is for.
const MARKS = {
  water(index) {
    const river = [
      [-110, 26], [-72, 18], [-30, 24], [12, 14], [52, 18],
    ];
    const bank = river.map(([x, y], i) => [x, y + 9 + i * 0.4]);
    return [
      L(onPlate(index, river), { tone: "blue" }),
      L(onPlate(index, bank), { tone: "blue", dotted: true }),
    ];
  },
  land(index) {
    const park = [
      [-58, -18], [-34, -26], [-12, -16], [-16, 2], [-38, 6], [-58, -6], [-58, -18],
    ];
    return [
      L(onPlate(index, park, true), { tone: "green" }),
      L(onPlate(index, [[-46, -14], [-26, -18], [-18, -8]]), { tone: "green" }),
      L(onPlate(index, [[-50, -2], [-30, -6]]), { tone: "green" }),
    ];
  },
  roads(index) {
    const out = [];
    for (const y of [40, 4, -30]) {
      out.push(L(onPlate(index, [[-112, y], [62, y]]), { tone: "hi" }));
    }
    for (const x of [-92, -44, 8, 56]) {
      out.push(L(onPlate(index, [[x, -48], [x + 6, 54]]), { tone: "hi" }));
    }
    // One road carries more traffic than the rest, so it is drawn heavier.
    out.push(L(onPlate(index, [[-112, 4], [62, 4]]), { tone: "lit" }));
    return out;
  },
  buildings(index) {
    const out = [];
    for (const [x, y, w, d] of [
      [-86, 14, 22, 16], [-58, 16, 18, 12], [-20, 10, 26, 18],
      [16, 16, 20, 14], [-72, -26, 24, 12], [26, -24, 22, 16],
    ]) {
      out.push(
        L(
          onPlate(
            index,
            [[x, y], [x + w, y], [x + w, y + d], [x, y + d], [x, y]],
            true,
          ),
          { tone: "mid" },
        ),
      );
    }
    return out;
  },
  labels(index) {
    // Street names: short rules of different lengths, set beside the roads.
    return [
      L(onPlate(index, [[-96, 8], [-70, 8]]), { tone: "mid" }),
      L(onPlate(index, [[-38, 8], [-16, 8]]), { tone: "mid" }),
      L(onPlate(index, [[-60, 48], [-34, 48]]), { tone: "mid" }),
      L(onPlate(index, [[14, -22], [40, -22]]), { tone: "mid" }),
      L(onPlate(index, [[-88, -38], [-66, -38]]), { tone: "mid" }),
    ];
  },
  pins(index) {
    const red = [[-74, 22], [-26, 30], [18, 22], [44, -14], [-50, -24], [12, -36]];
    const blue = [[-86, -12], [32, 8], [-8, 20]];
    return [
      D(red.map(([x, y]) => at([x, y, plateTop(index)])), { size: 2.1, tone: "hi" }),
      D(blue.map(([x, y]) => at([x, y, plateTop(index)])), { size: 2.1, tone: "mid" }),
    ];
  },
  traffic(index) {
    // Traffic is only worth showing if you are driving. The marks sit along
    // the main road.
    const out = [];
    for (let i = 0; i < 5; i += 1) {
      const x = -96 + i * 34;
      out.push(L(onPlate(index, [[x, 6], [x + 14, 6]]), { tone: "red" }));
    }
    for (let i = 0; i < 4; i += 1) {
      const x = -70 + i * 34;
      out.push(L(onPlate(index, [[x, 2], [x + 12, 2]]), { tone: "green" }));
    }
    return out;
  },
  route(index) {
    // The route is printed like a road: a wide dark casing with the bright
    // line laid over it.
    return [
      L(onPlate(index, ROUTE, true), { tone: "signalDeep" }),
      L(onPlate(index, ROUTE, true), { tone: "signal" }),
    ];
  },
};

// --- the machine ------------------------------------------------------------

function base() {
  const out = [`<path class="iso-halo" d="${k.haloOf(BASE, -FOOT_H, BASE_H, P)}"/>`];
  for (const [x, y] of byDepth(k.corners(BASE, 18))) {
    out.push(S(k.cylinder(x, y, 8, -FOOT_H, 1.8, P, 28), { tone: "lo" }));
    out.push(S(k.cylinder(x, y, 6.2, -FOOT_H + 1.8, FOOT_H - 1.8, P, 28), { tone: "mid" }));
  }
  out.push(S(k.slabOf(BASE, 0, BASE_H, P, 10, 1.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(BASE, 6), 0, P), { tone: "lo" }));
  const screws = k.corners(BASE, 12);
  out.push(L(screws.map(([x, y]) => k.ring(x, y, 2.4, 0, P, 16)).join(""), { tone: "lo" }));
  out.push(D(screws.map(([x, y]) => at([x, y, 0])), { size: 0.55 }));

  // A ruler strip along the front edge, so the machine has a scale.
  const strip = { x: BASE.x + 16, y: BASE.y + BASE.d - 17, w: 168, d: 8, r: 1 };
  out.push(S(k.slabOf(strip, BASE_H, 0.8, P, 3), { tone: "lo", crease: "none" }));
  const ticks = k.topTicks(
    strip.x + 5, strip.x + strip.w - 5, 6, 5, strip.y + 0.8, BASE_H + 0.8,
    [2.2, 3.8], P,
  );
  out.push(L(ticks.minor, { tone: "lo" }), L(ticks.major, { tone: "mid" }));

  // The maker's plate.
  const label = { x: BASE.x + 200, y: BASE.y + BASE.d - 19, w: 62, d: 12, r: 1.5 };
  out.push(S(k.slabOf(label, BASE_H, 1, P, 3), { tone: "mid" }));
  for (let i = 0; i < 3; i += 1) {
    out.push(
      L(
        k.lineOnTop(
          [label.x + 6, label.y + 3 + i * 3],
          [label.x + 56 - i * 14, label.y + 3 + i * 3],
          BASE_H + 1,
          P,
        ),
        { tone: "lo" },
      ),
    );
  }
  return out.join("");
}

function trayAndPaper() {
  const out = [];
  out.push(S(k.slabOf(TRAY, TRAY_Z, TRAY_H, P, 8, 1.2), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(TRAY, 4), TRAY_Z, P), { tone: "lo" }));
  out.push(S(k.slabOf(PAPER, PAPER_Z, PAPER_H, P, 4, 0.3), { tone: "hi" }));
  return out.join("");
}

// What the paper looks like once the plates have been printed onto it.
function composite() {
  const z = PAPER_Z + PAPER_H;
  const out = [];
  const flat = (points, closed = false) => k.onTop(points.map(([x, y]) => [x, y, z]), z, P, closed);
  out.push(L(flat([[-110, 26], [-72, 18], [-30, 24], [12, 14], [52, 18]]), { tone: "blue" }));
  out.push(L(flat([[-58, -18], [-34, -26], [-12, -16], [-16, 2], [-38, 6], [-58, -6], [-58, -18]], true), { tone: "green" }));
  for (const y of [40, 4, -30]) out.push(L(flat([[-112, y], [62, y]]), { tone: "mid" }));
  for (const x of [-92, -44, 8, 56]) out.push(L(flat([[x, -48], [x + 6, 54]]), { tone: "mid" }));
  out.push(L(flat(ROUTE, true), { tone: "signalDeep" }));
  out.push(L(flat(ROUTE, true), { tone: "signal" }));
  return out.join("");
}

function plates() {
  const out = [];
  for (let index = 0; index < PLATES.length; index += 1) {
    const plan = platePlan(index);
    const z = plateZ(index);
    const isRoute = PLATES[index].key === "route";
    out.push(
      S(k.slabOf(plan, z, PLATE_H, P, 8, 0.7), {
        tone: isRoute ? "lit" : "hi",
        lit: isRoute,
        crease: "none",
      }),
    );
    out.push(L(k.planOutline(plan, z + PLATE_H, P), { tone: isRoute ? "lit" : "lo" }));

    // A tab on the near edge, carrying the layer's colour and a mark.
    const tab = { x: plan.x + 9, y: plan.y + plan.d - 9, w: 38, d: 8, r: 2 };
    out.push(S(k.slabOf(tab, z + PLATE_H, 1.1, P, 3), { tone: "lo", crease: "none" }));
    out.push(
      L(
        k.lineOnTop(
          [tab.x + 4, tab.y + 4],
          [tab.x + 14, tab.y + 4],
          z + PLATE_H + 1.1,
          P,
        ),
        { tone: PLATES[index].tone },
      ),
    );
    for (let i = 0; i < 2; i += 1) {
      out.push(
        L(
          k.lineOnTop(
            [tab.x + 18, tab.y + 2.4 + i * 3.2],
            [tab.x + 34 - i * 6, tab.y + 2.4 + i * 3.2],
            z + PLATE_H + 1.1,
            P,
          ),
          { tone: "faint" },
        ),
      );
    }
  }
  return out.join("");
}

// The ink on the plates, in groups so that the basemap can be faded as one.
function plateInk() {
  const groups = [];
  for (let index = 0; index < PLATES.length; index += 1) {
    const plate = PLATES[index];
    const marks = MARKS[plate.key](index).join("");
    const isRoute = plate.key === "route";
    groups.push(
      k.groupSvg(marks, {
        class: isRoute ? "ink-route" : "ink-base",
        "data-plate": plate.key,
      }),
    );
  }
  return groups.join("");
}

function press() {
  const out = [];
  // The column, the arm and the head move together, so they are one group.
  out.push(S(k.slabOf(COLUMN, COLUMN_Z, COLUMN_H, P, 6, 1.2), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(COLUMN, 4), COLUMN_Z + COLUMN_H, P), { tone: "lo" }));
  out.push(S(k.slabOf(ARM, ARM_Z, ARM_H, P, 6, 1.2), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(ARM, 5), ARM_Z + ARM_H, P), { tone: "lo" }));

  // A rib on the column, and the bolts that hold the arm to it.
  for (let i = 0; i < 5; i += 1) {
    out.push(
      L(
        k.lineOnTop(
          [COLUMN.x + 4, COLUMN.y + 4],
          [COLUMN.x + COLUMN.w - 4, COLUMN.y + 4],
          COLUMN_Z + 12 + i * 15,
          P,
        ),
        { tone: "lo" },
      ),
    );
  }
  const bolts = [
    [COLUMN.x + 6, COLUMN.y + 6], [COLUMN.x + COLUMN.w - 6, COLUMN.y + 6],
    [COLUMN.x + 6, COLUMN.y + COLUMN.d - 6], [COLUMN.x + COLUMN.w - 6, COLUMN.y + COLUMN.d - 6],
  ];
  out.push(L(bolts.map(([x, y]) => k.ring(x, y, 2.2, ARM_Z + ARM_H, P, 14)).join(""), { tone: "lo" }));
  out.push(D(bolts.map(([x, y]) => at([x, y, ARM_Z + ARM_H])), { size: 0.5 }));
  return out.join("");
}

// The head is an open platen: a frame with ribs across it, so the stack is
// still visible through it while it is over the paper.
function head() {
  const out = [];
  const bar = 11;
  const rails = [
    { x: HEAD.x, y: HEAD.y, w: HEAD.w, d: bar },
    { x: HEAD.x, y: HEAD.y + HEAD.d - bar, w: HEAD.w, d: bar },
    { x: HEAD.x, y: HEAD.y + bar, w: bar, d: HEAD.d - bar * 2 },
    { x: HEAD.x + HEAD.w - bar, y: HEAD.y + bar, w: bar, d: HEAD.d - bar * 2 },
  ];
  for (const rail of rails) {
    out.push(S(k.slabOf(rail, HEAD_Z, HEAD_H, P, 4, 0.8), { tone: "mid" }));
  }
  // Two ribs across the middle, so it is a platen and not a picture frame.
  for (const x of [HEAD.x + 34, HEAD.x + 62]) {
    out.push(S(k.slabOf({ x, y: HEAD.y + bar, w: 8, d: HEAD.d - bar * 2 }, HEAD_Z + 2, HEAD_H - 4, P, 3, 0.5), { tone: "lo" }));
  }
  // The hanger that runs along the arm.
  out.push(S(k.slabOf({ x: HEAD.x + 20, y: HEAD.y + 12, w: HEAD.w - 40, d: 18, r: 3 }, HEAD_Z + HEAD_H, 6, P, 4, 0.6), { tone: "mid" }));
  // Bolts at the corners of the frame.
  const face = [
    [HEAD.x + 5.5, HEAD.y + 5.5], [HEAD.x + HEAD.w - 5.5, HEAD.y + 5.5],
    [HEAD.x + 5.5, HEAD.y + HEAD.d - 5.5], [HEAD.x + HEAD.w - 5.5, HEAD.y + HEAD.d - 5.5],
  ];
  out.push(L(face.map(([x, y]) => k.ring(x, y, 2, HEAD_Z + HEAD_H, P, 14)).join(""), { tone: "lo" }));
  out.push(D(face.map(([x, y]) => at([x, y, HEAD_Z + HEAD_H])), { size: 0.5 }));
  return out.join("");
}

// The ink lever: the basemap's ink supply, and the only control.
//
// It is a knob in a slot rather than a swinging arm, so that the control
// has one honest dimension: further along the slot is more ink.
function lever() {
  const out = [];
  out.push(S(k.slabOf(LEVER, LEVER_Z, 3, P, 6, 0.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(LEVER, 4), LEVER_Z + 3, P), { tone: "lo" }));

  // The slot itself, recessed into the plate.
  out.push(
    L(
      k.lineOnTop([SLOT_X0, SLOT_Y], [SLOT_X1, SLOT_Y], LEVER_Z + 3, P),
      { tone: "faint" },
    ),
  );
  out.push(
    L(
      k.lineOnTop([SLOT_X0, SLOT_Y - 4], [SLOT_X1, SLOT_Y - 4], LEVER_Z + 3, P),
      { tone: "faint" },
    ),
  );
  // The scale under the slot, from silent to loud.
  for (let i = 0; i <= 8; i += 1) {
    const x = SLOT_X0 + 4 + (i / 8) * (SLOT_X1 - SLOT_X0 - 8);
    out.push(
      L(
        k.lineOnTop([x, SLOT_Y + 6], [x, SLOT_Y + (i % 4 === 0 ? 12 : 10)], LEVER_Z + 3, P),
        { tone: i % 4 === 0 ? "mid" : "lo" },
      ),
    );
  }
  // The end stops, so the knob cannot fall off the slot.
  for (const x of [SLOT_X0, SLOT_X1]) {
    out.push(S(k.cylinder(x, SLOT_Y, 3, LEVER_Z + 3, 4, P, 14), { tone: "mid" }));
    out.push(L(k.ring(x, SLOT_Y, 3, LEVER_Z + 7, P, 14), { tone: "lo" }));
  }
  return out.join("");
}

// The knob on the lever, which is drawn in its own group so that it can turn.
function knob() {
  const out = [];
  out.push(S(k.cylinder(0, 0, 7, 0, 7, P, 22), { tone: "hi" }));
  out.push(L(k.knurl(0, 0, 7, 0, 7, 20, P, 0.6), { tone: "lo" }));
  out.push(S(k.cylinder(0, 0, 2.6, 7, 3.4, P, 14), { tone: "lit" }));
  out.push(L(k.ring(0, 0, 2.6, 10.4, P, 14), { tone: "lo" }));
  // A pointer line on the top of the knob, so its setting can be read.
  out.push(
    L(
      k.lineOnTop([0, 0], [5, 0], 10.4, P),
      { tone: "lit" },
    ),
  );
  return out.join("");
}

// The two ink pots: one for the basemap, one for the route.
function pots() {
  const out = [];
  for (const [x, y, r, tone] of [
    [POT_BASE[0], POT_BASE[1], 9, "lo"],
    [POT_ROUTE[0], POT_ROUTE[1], 7, "signal"],
  ]) {
    out.push(S(k.cylinder(x, y, r, BASE_H, 11, P, 22), { tone: "mid" }));
    out.push(L(k.ring(x, y, r, BASE_H + 11, P, 22), { tone: tone === "signal" ? "signal" : "lo" }));
    out.push(S(k.cylinder(x, y, r - 2, BASE_H + 8, 3, P, 20), { tone }));
  }
  return out.join("");
}

// --- the figure -------------------------------------------------------------

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label:
    "A proofing press: eight inked plates make the map, and a lever controls how much ink the basemap gets while the route keeps its own",
  body: [
    base(),
    trayAndPaper(),
    k.groupSvg(composite(), { class: "ink-composite" }),
    plates(),
    k.groupSvg(plateInk(), { class: "ink-plates" }),
    press(),
    k.groupSvg(head(), { class: "press-head" }),
    lever(),
    k.groupSvg(knob(), { class: "lever-knob" }),
    pots(),
  ].join(""),
});

const live = `
const P = ${JSON.stringify(P)};
const stage = document.querySelector(".iso-stage");
const readout = document.querySelector("[data-readout]");
const inkBase = document.querySelectorAll(".ink-base");
const inkComposite = document.querySelector(".ink-composite");
const inkRoute = document.querySelector(".ink-route");
const head = document.querySelector(".press-head");
const knob = document.querySelector(".lever-knob");
const still = matchMedia("(prefers-reduced-motion: reduce)");

let density = 0.32;
let target = 0.32;
let press = 0;
let pressTarget = 0;
let visible = false;
let frame = 0;
let last = 0;
let clock = 0;
let touring = true;
let idleTimer = 0;

const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
const knobAt = (value) => [110 + value * 28, -38, 13];

function draw() {
  const base = 0.1 + density * 0.9;
  inkBase.forEach((node) => { node.setAttribute("opacity", base.toFixed(3)); });
  if (inkComposite) inkComposite.setAttribute("opacity", (0.12 + density * 0.88).toFixed(3));
  if (inkRoute) inkRoute.setAttribute("opacity", "1");
  knob.setAttribute("transform", translateAlong(P, knobAt(density)));
  head.setAttribute("transform", translateAlong(P, [(1 - press) * 78, 0, -press * 26]));
  const percent = Math.round(density * 100);
  const text = "basemap ink " + percent + "% · route ink 100%";
  if (readout.textContent !== text) readout.textContent = text;
  stage.setAttribute("aria-valuenow", String(percent));
  stage.setAttribute("aria-valuetext", text);
}

function tick(now) {
  const dt = last ? Math.min((now - last) / 1000, 1 / 30) : 1 / 60;
  last = now;
  if (touring) {
    clock += dt;
    // A slow cycle: the head comes down, holds, and lifts again.
    const cycle = clock % 9;
    pressTarget = cycle < 3 ? 0 : cycle < 5 ? 1 : cycle < 7 ? 1 : 0;
  }
  const calm = still.matches;
  density = calm ? target : density + (target - density) * (1 - Math.exp(-dt * 6));
  press = calm ? pressTarget : press + (pressTarget - press) * (1 - Math.exp(-dt * 3.2));
  draw();
  frame = visible ? requestAnimationFrame(tick) : 0;
}

const run = () => { if (!frame && visible) { last = 0; frame = requestAnimationFrame(tick); } };
const steer = (next) => {
  touring = false;
  target = clamp(next, 0, 1);
  clearTimeout(idleTimer);
  idleTimer = setTimeout(() => { touring = !still.matches; clock = 0; run(); }, 4200);
  run();
};
new IntersectionObserver((entries) => { visible = entries[entries.length - 1].isIntersecting; run(); }, { rootMargin: "120px 0px" }).observe(stage);
if (still.matches) { touring = false; pressTarget = 0; }
stage.addEventListener("pointerdown", (event) => { stage.setPointerCapture(event.pointerId); });
stage.addEventListener("pointermove", (event) => {
  if (event.buttons === 0) return;
  const box = stage.getBoundingClientRect();
  const share = clamp((event.clientX - box.left) / box.width, 0, 1);
  steer(share);
});
stage.addEventListener("keydown", (event) => {
  if (event.key === "ArrowRight" || event.key === "ArrowUp") steer(target + 0.05);
  else if (event.key === "ArrowLeft" || event.key === "ArrowDown") steer(target - 0.05);
  else if (event.key === "Home") steer(0);
  else if (event.key === "End") steer(1);
  else return;
  event.preventDefault();
});
draw();
`;

const body = k.plateHtml({
  fig: "Fig 1",
  title: "The map press",
  hint: "Drag across the figure to set the basemap ink",
  readout: "basemap ink 32% · route ink 100%",
  keys: [
    { mark: "lit", label: "The route plate: its own ink, never faded" },
    { mark: "raised", label: "The seven basemap plates: one job each" },
  ],
  caption:
    "A map is a stack of layers and a style is a decision about which of them are fitted and how much ink each one gets. The lever sets the basemap's ink: pulled back, the map is a whisper and the route is the only thing on the page. The route has its own pot, so it never fades with the rest.",
  body: `<div class="iso-stage" tabindex="0" role="slider" aria-label="Basemap ink: arrow keys set how much ink the basemap gets" aria-valuemin="0" aria-valuemax="100" aria-valuenow="32">${svg}</div>`,
});

// The app's own signal colour, which the kit does not carry.
const EXTRA_CSS = `
.iso-line[data-tone="signal"]{stroke:#c5451f}
.iso-line[data-tone="signalDeep"]{stroke:#612a12}
.iso-stage{cursor:ew-resize}
.iso-stage:focus-visible{outline:1px solid var(--anatomy-muted);outline-offset:6px}
`;

const page = k
  .pageHtml({ title: "The map press", theme, body, script: kitScript() + live })
  .replace("</style>", EXTRA_CSS + "</style>");

writeFileSync(join(HERE, theme === "light" ? "map-style-light.html" : "map-style.html"), page);
console.log("wrote", theme === "light" ? "map-style-light.html" : "map-style.html");
