# Map design: how we build maps

How map content gets made in this project, and what it is for. Read
this before working on maps, creators, or details.

## The goal: things worth finding

The player flies a drone through the world. Everything that makes
exploring fun counts: places you can fly into, small realistic touches,
and above all **details that make the player smile**. Humour is wanted,
the more absurd the better, but as a *surprise*: most things are
plainly normal, and only now and then is something odd. A battleship in
every toilet is a gimmick; a battleship in one toilet out of five is a
discovery.

Rules of thumb:
- **Normal first, odd rarely.** Every surprise has a chance (a constant
  in its creator, e.g. `ToiletCreator.FLOATER_CHANCE = 0.2`) and an
  "off" outcome that is perfectly ordinary.
- **Reward looking closely.** Surprises sit where a curious pilot looks:
  inside houses, through open windows, in a toilet bowl, behind things.
- **Believable base.** The ordinary version is grounded in real sizes
  (cite them in the creator's header), so the odd thing stands out.
- **Always a way in.** Interiors are only fun if you can reach them:
  open windows/doors, nothing blocking doorways or stairs.

The user feeds in ideas over time ("a duck in the toilet"). Each one
becomes an option in a creator, not a one-off placement, so it shows up
across the maps.

## Designed layout, generated detail (decided 2026-10-03)

Generate the small things, design the big ones. Self-contained things
(a house and its plot, a garden, a tree, a toilet, a bridge for a given
span) are creators: variety for free, failures local and visible in a
lab. The big picture of a map - the shape of the land, where the river
runs, where roads go, which stretches of road get houses, where the
green and the woods are - is written by hand in the map script as a
short, readable layout (a few dozen numbers). TerrainCreator,
RiverCreator and RoadCreator are builders that turn that layout into
geometry; they don't choose it. An automatic village planner was built
and retired: letting generators place the layout made them fight over
it (a pond's level taken before a village levelled the land round it,
side roads burying main roads), and it still didn't look designed.

## Creators

A creator is a script that builds one kind of thing from a seed or rng:
a different variant every time, many details, without hand-placed
coordinates. They are written once, tuned in a lab until every seed
looks right, then reused by every map. Hand-made coordinates are kept
for landmarks only.

| Creator | Script | Builds | Status |
|---|---|---|---|
| HouseCreator | scripts/maps/house_creator.gd | detached family house, furnished, 1-2 storeys, open patio door + windows; or a closed shell whose windows show painted room niches | lab + Test Valley |
| TerrainCreator | scripts/maps/terrain_creator.gd | the land: "rolling", "hills" or "valley" from a seed; levelled plots and streets, ponds, ground colours, woods for TreeCreator | lab + Test Valley |
| RiverCreator | scripts/maps/river_creator.gd | a meandering river between given points, always flowing downhill, mud banks, reeds | lab (TerrainLab) + Test Valley |
| RoadCreator | scripts/maps/road_creator.gd | a road through given points: rounded corners, graded (cut/fill), bridges every river it meets; branches start at a junction on another road; ends at a junction, a turning circle, or runs on into the haze | TerrainLab, Test Valley |
| VillageKit | scripts/maps/village_kit.gd | helpers for a designed village: plots along a stretch of road (checked, levelled), building them via HouseCreator.build_plot, street lamps, a village green | Test Valley |
| GardenCreator | scripts/maps/garden_creator.gd | a plot's boundary - one kind all round, one height (trimmed hedge, picket, post-and-rail, low wall), gates at the path and drive - and its garden: flower beds (MultiMesh clumps: bedding cushions in front, tulips / marguerites / lupins behind, in drifts of the garden's colours; `shaders/flower.gdshader`), trees, bushes, flower border, shed with stepping stones, bench, bird bath, small pond, washing line, vegetable beds, trampoline, sandpit, gnomes | called by HouseCreator.build_plot |
| BridgeCreator | scripts/maps/bridge_creator.gd | a road bridge on the road's own deck points: concrete beam (piers on long spans), stone arch, steel through-truss | called by RoadCreator |
| TreeCreator | scripts/maps/tree_creator.gd | garden/street trees: maple (rare copper beech), apple with fruit, birch, spruce, flowering bushes; 3 seeded shapes each, MultiMesh | lab + Test Valley gardens |
| ToiletCreator | scripts/maps/toilet_creator.gd | US two-piece toilet; sometimes something swims in it | every HouseCreator bath/WC (own rng per toilet; lab views `toilet_<room>_<floater>`) |
| FieldCreator | scripts/maps/field_creator.gd | a field on four corners the map gives: wheat, maize, rapeseed (a canopy over the land at the crop's height, rows, a wall of stalks, tramlines - not solid: fly into it and you are among see-through rows of stalks (one 4 m patch, MultiMesh) under the crop's shaded underside), ploughed, stubble, mown meadow (a layer on the ground); round bales (golden straw, yellow-green hay, the rolled layers as rings on their ends) and a stack; hedgerows along chosen edges | Test Valley |
| FarmCreator | scripts/maps/farm_creator.gd | a farmstead on its own levelled yard: timber barn with doors open at both ends (fly through; loft, hay), grain silo, open machine shed, the farmhouse (HouseCreator, closed), a tractor with a trailer of bales; `tractor()` alone for a field | Test Valley |
| StreetKit | scripts/maps/street_kit.gd | street furniture: give-way sign at a branch, yellow place-name board (Label3D text), bus stop (shelter, bench, H sign, bin), letter box, litter bin, wheelie bins (gardens), notice board | Test Valley, GardenCreator |
| PowerLineCreator | scripts/maps/power_line_creator.gd | an overhead line along a hand-laid course: wooden poles (3 wires, stays at corners) or steel lattice pylons (6 conductors + earth wire, insulator strings); masts step off roads and water; wires sag in a parabola; all solid | Test Valley |
| CityHouseCreator | scripts/maps/city_house_creator.gd | town houses in rows along a street (plan_row levels the lots, build_row builds them): "altbau" (~1900: pastel plaster, framed windows, string courses, steep roof with dormers, iron balconies, sometimes an archway through to the courtyard - fly through), "fifties" (plain, small windows, loggias, low roof), "modern" (big windows, glass balconies, flat roof with a set-back top floor); shops on the ground floor with name boards and awnings; closed | Test Valley town; meant to replace `City.building` near the flight area in Harbour, Construction Site, Parking Garage, Playground, Office |
| IndustryCreator | scripts/maps/industry_creator.gd | an industrial estate's pieces: production hall (sawtooth roof, roller doors - one open, crane runway and overhead crane inside -, loading docks, office annex), tank farm in a bund, pipe rack (fly under), chimney with aviation bands, grain silos with a conveyor gallery open at its low end (fly up it), mesh fence with gatehouse and barrier | Test Valley; meant for Factory, Harbour, Steel Mill |
| RockCreator | scripts/maps/rock_creator.gd | boulders and stones: 6 faceted shapes, MultiMesh + shared convex hulls, half buried, scattered in areas the map names (mostly small, a few big), off roads, water, levelled ground and fields | Test Valley |

Older builders that work the same way: `City`, `MapProps`, `Vehicles`,
`YardProps`, `Forest`, `Fleet`, `HollowBuilding`, `RaceCourse`.

Conventions for creators:
- `static func build(geo, <frame or pos/yaw>, <seed or rng>, opts := {}) -> Dictionary`.
  Options choose variants explicitly ("floater": "duck"); the default is
  "random". Return what callers need (views, positions, what was chosen).
- Local frame for objects that stand against a wall: origin on the
  floor at the wall, +z into the room (same as HouseCreator furniture).
- Draw through `Geo` and keep the material count small: one flat
  material tinted per part (`geo.tint`) instead of a material per colour.
  Materials of small or interior things get a prefix registered in
  `geo.detail_prefixes` ("hcd_", "tc_"), so they stop drawing far away.
- `Geo.lathe_xf` is the shape tool for round and elliptical things
  (bowls, seats, ducks, bottles); see its comment for the profile order.
- Bake AO per storey (`geo.ao_ground_y`) for interiors; restore what you
  change on `geo`.
- No floating pieces: run the lab once with `SH_FLOAT=1` headless
  (`SH_FLOAT=0.05` for a stricter gap than the default 10 cm).
- Anything standing on the ground goes down into it: draw it with
  `geo.box_on(xf, size, mat, level)` (a box whose bottom is at the
  creator's own level - a plot, a house base - is stretched down to
  `Geo.SINK` (8 cm) under the real ground beneath every corner) or put
  its foot at `geo.sunk(points, y)`. A creator's level is only ever
  "level" as far as the 8 m terrain grid can show it; at a plot's edge
  the land may already fall away. `Geo.floor_fn` is the real ground
  (TerrainCreator sets it; unlike `ground_fn` it stays on while a house
  builds).

### Nothing floats: the check (2026-10-03)

`Geo.floating()` (self-test "nothing floats in the air", `SH_FLOAT=1`)
judges every solid piece within 100 m of the reset border:

- **loose** - a group of pieces that touch each other (within 0.35 m)
  but none of which stands on the ground. A whole house or fence lifted
  off its plot used to pass, because each piece touched the next one.
  A piece only stands on the ground when its bottom is within 10 cm of
  it; a fence hovering 20 cm is loose.
- **gap** - a piece standing on the bare ground at one spot but more
  than 10 cm above it elsewhere under its footprint (a hedge over a
  dip, a hut on a slope), with nothing under that spot. A piece resting
  on another piece (a roof on its walls) is that piece's business.

What it found when it was made strict: hedges and fence posts hovering
up to 27 cm at plot edges (fixed: `box_on`, and plots now lie at the
road's bed level, `TerrainCreator.ROAD_SINK`), trunks on slopes (trees
sink to `sunk`), and in the older maps a bridge truss standing 1.9 m
beside its deck and a crane rope hanging from nothing (Harbour), a
coal bunker's top frame 5 m above its legs (Steel Mill), a hotel, a
chapel and the cable-car stations with their downhill side up to 12 m
in the air, and a boathouse standing on the water (Mountain Lake). Look
from low down too: `low<k>` views in Test Valley run along the street at
1.1 m.

### Interior light

Interiors are lit at build time, never per frame. While a room's
surfaces and furniture are drawn, `geo.light_fn` is set to
HouseCreator's `_room_light`, which computes:
- daylight from the room's own windows and glass doors;
- sun patches through the openings;
- the ceiling lamp;
- darkening into corners, room edges and under furniture.

Walls, floors and ceilings are `Geo.quad_grid` faces split into cells
(0.5 m walls, 0.4 m floors, 0.8 m ceilings) so the light can vary
across them. Interior materials carry meta "no_shadow", because the
runtime shadow map would darken them twice.

Measured cost (4 lab houses): draw calls unchanged (104 surfaces),
+14k vertices and +0.13 s build per house. `SH_FLATLIGHT=1` builds
without the new light for comparison; `SH_PERF=1` on the lab prints
build time, surfaces and vertices.

### Open houses: 1 in 5

Maps furnish only one house in five (`HouseCreator.accessible(i)`, i.e.
`OPEN_EVERY = 5`); the rest are built with `"interior": false`. Closed
houses look the same from outside: every pane shows a shallow painted
room niche with curtains (sometimes a plant on the sill), in shell
materials so it never drops out at distance. Measured on Test Valley (8
houses): 1.4 s to build with 2 open vs 4.1-4.6 s with all 8 open.

### Trees

TreeCreator builds each species shape once per game (cached) and draws
trees as MultiMesh with Forest's tree shader: one draw call per shape
and 128 m chunk, a merged stand-in per 512 m chunk beyond the near
range. Vertex alpha 0.4 is a plain colour in tree.gdshader (apples,
hydrangea heads), so fruit costs no extra draw call. Measured:
57 garden trees in about 90 ms including building all shapes.

### Flowers

The same idea for flowers (GardenCreator): four clump shapes - bedding
cushion, tulips, marguerites, lupins - built once and drawn as MultiMesh
per 64 m cell and shape, out to 110 m. `shaders/flower.gdshader`: vertex
alpha 1 leaves (foliage texture), 0.4 petals coloured per clump from
the instance's custom data (one shape, every colour), 0.2 a plain
colour. A bed's back row is the garden's tall kind, the front row
cushions, in drifts of one colour from the garden's palette. Test
Valley: 944 clumps, ~150k triangles in all, no build time to speak of
(the earlier one-cone-per-flower beds cost ~0.8 s of house building);
`SH_PERF=1` prints the count. On the compatibility renderer a MultiMesh
needs `use_colors` with white instance colours, or it draws black.

### Terrain

TerrainCreator shapes the land; the existing `Terrain` builds mesh,
collision and the horizon ring from it. Order: `make(seed, style)`,
then `flat_rect` / `flat_line` (the first one sets the datum: the hills
are shifted so natural ground there is at its level), then `pond`
(water level from the ground round it), then `build`, then `woods`.
After build, `ground(x, z)` reads the cached grid (cheap; use it for
anything scattered). Woods are plain (no copper beech, no garden
surprises) except a rare lost drone or kite.

Measured on Test Valley (1.2 km square, 8 m grid, horizon ring at
110 m): land 0.46 s, 1,840 trees incl. woods 0.27 s. `Terrain` itself
got faster for every hilly map: light once per grid point, indexed
chunk meshes (same look, about a sixth of the vertices).

### How the creators hand work to each other

The map script, in this order (later steps see what earlier ones left;
nothing takes a height from the land before the land is final):

    land = TerrainCreator.make(seed, "gentle"); land.set_extent(rect)
    land.flat_circle(...)          the village's level ground (first: the datum)
    land.hill / hollow / valley    the designed landforms
    RiverCreator.plan(land, course, width)
    RoadCreator.plan(...) / .branch(...)       the street plan, junctions
    VillageKit.plots_along(land, road, d0, d1, side, plots)
    land.pond(c, r)                its level is settled at build, from the levelled ground
    land.build(map, geo, rect)
    river.draw(); road.draw() each; VillageKit.lamps(); VillageKit.green()
    VillageKit.build_plots(geo, plots, seed)
      HouseCreator.build_plot(plot) -> the house, set back on the plot
        GardenCreator.build(plot, house) -> fences, gates, garden
    land.woods(rng, rect, n, field_every, areas)   woods in the areas you mark
    TreeCreator.plant(...)

Farmland and the rest fit in like this (Test Valley):

    FarmCreator.plan(land, centre, size, entry)    before the roads: the yard is a level area
    land.keep_clear_poly(FieldCreator.poly(corners))   no woods in a field
    RoadCreator.branch(...)                        the farm lane, ending in the yard
    ... land.build, roads, houses ...
    StreetKit.give_way / town_sign / bus_stop ...  once the roads are drawn
    FarmCreator.build(geo, land, farm, seed)
    FieldCreator.build(geo, land, corners, crop, rng, {"hedges": [...]})
    PowerLineCreator.build(geo, land, course, "poles" | "pylons")   after the
        buildings (masts step off what stands), before the trees
    RockCreator.scatter(map, geo, land, rng, areas, fields)   before the trees
    TreeCreator.plant(...)                         trees keep off rocks and masts

A field's surfaces lie on the terrain's own triangles (cut at the
field's edge, `FieldCreator._drape`): a surface on a grid of its own,
even 4 m, cut into the land wherever the land curved between its
points - green patches through a ploughed field near the river.

Terrain stages: natural (noise + landforms), rivers, level areas,
ponds, roads. Add landforms before planning anything (the datum - the
height 0 of the first levelled area - is taken when the land is first
read, landforms included). A plot lies at the level of the ground under
its road (the road's surface minus `ROAD_SINK`): the road's bed reaches
into the plot's first grid row, and a plot set even 15 cm higher sloped
down to it there - under the front steps and the garage. A plot's own ground belongs to it: no later
levelled area or road changes it, and it is levelled a grid cell past
its sides and back so no terrain triangle lifts its edge. Keep plots
off steep slopes: neighbours 2 m apart can't step more than the 8 m
grid can show. Dev checks on Test Valley: `SH_ROADCHECK=1` (low views
along every road), `SH_PLOTCHECK=1` (ground under every plot vs its
level, and every pond's water vs the ground at its edge).

A plot is `{"frame", "width", "depth"}`: the frame's origin is the
middle of the plot's street edge, +z toward the street, x along it.
VillageKit lays plots out along the stretches the map names (skipping
any spot that would touch a road, water, a no-plots zone or another
plot); the house generator places the house and reports where its path
and driveway reach the street, so the garden's fence has its gate and
opening there.

### Lines on the land: rivers, roads, bridges

Creators interact through the land. Every line (river, road) is a
`LandLine` registered with TerrainCreator before `build()`, and the
terrain is built in fixed stages, each seeing what the earlier ones
left: natural land, ponds, rivers (channel + valley), level plots and
streets, roads (cut and fill). Rules:
- **Order:** make, flat areas, ponds, `RiverCreator.plan`,
  `RoadCreator.plan`, `land.build`, then the creators' `draw()`, then
  woods/scatter (which ask `land.on_line()` to keep off them).
- **Rivers only flow downhill:** the water level along the course can
  only fall; where land rises in the way, the river carves its valley
  through it.
- **A crossing is decided by the later line.** A road planned after a
  river finds the crossing, holds its deck 4.5 m above the water, ramps
  to it at max 7 %, flags those segments as bridge (the terrain leaves
  the river's ground alone there) and BridgeCreator builds the bridge.
- **A road never dams a river:** in the final stage the river channel
  is carved again on top of any road fill.
- **Fine detail the 8 m grid can't carry is drawn by the creator:** the
  river's banks are their own surfaces landing on the terrain at their
  outer edge; the terrain is carved just below them.
- Anything drawn after `land.build` is shaded against the ground below
  it (`Geo.ground_fn`), not against y = 0.

- **Roads meet at junctions.** `RoadCreator.branch(land, main, at,
  side, ...)` starts a road square-on at the edge of `main`, at its
  level, with a rounded mouth (7 m corners) and a give-way line. Every
  road ends at a junction, a turning circle, or runs on into the haze.
- **Roads run on into the haze** over the coarse horizon ring: past the
  detailed rect they lie on it (`land.far_ground()`, which mirrors the
  ring's own triangles) with plain carriageway (no markings). Call
  `land.set_extent(rect)` before planning roads. Where the ring overlaps
  the detailed rect it is kept under every road and river within a
  ring cell, or its 110 m triangles span a cutting and bury the road.
  Rivers run on the same way, in a trench the ring carves along them.
  Only small things may use a detail prefix (culled past 450 m): the
  river's water and banks once did, and from afar the river looked
  unloaded. Past the detailed rect `Geo.ground_fn` returns "no ground"
  (no occlusion out there; computing it per vertex cost a second).
- **The road bed is as wide as a grid cell's diagonal** past the road
  edge (`land.road_bed()`): every terrain triangle touching the road has
  all its corners on the bed. With a narrower bed, triangles from the
  hillside bit into the road's edge.
- **The nearest road shapes the ground.** Where roads come close (a
  junction, two parallel roads), only the road whose edge is nearest
  carves a point; applying them one after another let a side road's
  bed bury the main road it leaves. A junction mouth follows the main
  road's slope along its edge and blends to the branch's start level;
  the main road's edge lines break at every mouth.
- **Rivers never stand above the land:** the water level is capped at a
  metre under the ground again after smoothing (averaging pulled pools
  above hollows), and out on the horizon ring every vertex within a
  cell of the river sits under its water.
- Overlapping asphalt surfaces flicker: a junction mouth, a road and a
  turning circle meet edge to edge, never on top of each other.
- Dev check on Test Valley: `SH_ROADCHECK=1` renders low views along
  every road (terrain vs road surface).

Next candidates on the same model: crossroads (two branches facing
each other), culverts for small streams, a railway (same LandLine,
gentler grade), farms off the country roads.

Measured (TerrainLab, 1.2 km square): planning river + road 35 ms;
terrain with both 0.54 s (lines are stamped onto the grid once, not
searched per point); drawing river ~0.3 s and road + bridge ~0.5 s on a
cold start, most of it generating textures once per session.

### Seed libraries (decided 2026-10-02)

A creator gives the same result for the same seed and options, but
only for one version of the code: any change to the generator reshuffles
what every seed produces. So we don't try to make every seed perfect.
Maps use a curated list of good seeds instead:
- **Development:** about 10 hand-picked designs per creator, re-checked in
  the lab after generator changes.
- **Before release:** generate and review the real library (about 500
  approved seeds) once, after the generator is frozen. After that, a
  generator change means rebuilding the library.

### Surprises catalogue

| Where | Surprise | Chance |
|---|---|---|
| Toilet bowl | rubber duck, battleship, swan, message in a bottle (a shark fin exists but only on request: "floater": "shark") | 20% for one of them |
| Toilet | seat left up | 15% |
| Toilet paper | hung "under" instead of "over" | 30% |
| Tree | birdhouse on the trunk | 8% (maple, apple, birch) |
| Tree | tyre swing on a low limb | 5% (maple) |
| Tree | kite caught in the crown, tail hanging down | 3% (garden), 0.1% (wood) |
| Tree | an FPV drone stuck in it, LED still on | 2.5% (garden), 0.1% (wood) |
| Maple | a copper beech among the green ones | 10% (gardens only) |
| River | a rubber-duck race: 25-45 big rubber ducks strung out downstream | 5% per river |
| Bridge | a shopping trolley on its side in the shallows underneath | 12% per bridge |
| Garden | a garden gnome by the front path | 6% per plot |
| Garden | a gnome army: 15 gnomes in formation on the front lawn | 1% per plot (`SH_GNOMES=1` forces it) |

Add every new one here.

## Labs: the feedback loop

Each creator has a lab scene (`scenes/labs/<Name>.tscn` +
`scripts/labs/<name>.gd`, not in the menu) that lays out a few variants
and names camera views in `preview_views()` as `[name, eye, target, group]`.

```
SH_SHOT_DIR=/tmp/sh_lab/<name> godot --path . -- --dev-preview lab <SceneName>
#   SH_SEED=<n>  other variants;  SH_FOV=<deg>  camera FOV (default 95; 60 for close-ups)
```

Output: one PNG per view, `sheet_<group>.png` contact sheets (4 views
across), and `index.html` (click to enlarge, arrow keys). Open it for
the user (`open .../index.html`); they reload after each run.

For Claude: look at the contact sheets, not single shots. One sheet is
one image read, about 1.5k tokens for a whole house. Crop/stitch sheets
with PIL when only some columns matter. Go to single PNGs only for a
specific problem.

A whole map works with the same command (`lab TestValley` looks in
scenes/maps/ when there is no lab of that name).

Test map: `Test Valley` (scenes/maps/TestValley.tscn, in the map menu)
replaced Test Street on 2026-10-03: a village in the floor of a river
valley, houses on both banks joined by a stone arch bridge (22 plots, 5
open), a pond on the west-bank meadow, woods on the valley sides - laid
out by hand in scripts/maps/test_valley.gd, built by the creators.
Farmland round it (2026-10-04): the farm on the valley floor south of
the village, six fields (wheat and maize up the slopes, rapeseed and
stubble on the west bank, a ploughed field and a mown meadow on the
floor), a pylon line across the valley in the north, poles up the road
to the farm, boulders on the slopes and round the pond, the village
named Talbach on its boards, a bus stop at its north end.
North of it (2026-10-04) a small town on the main road - 38 town
houses in rows with pavements, a cross street - and an industrial estate
under the pylons; the flight border was widened to 560 m for them.
Town houses cost about 22 ms each (38: 0.8 s) - for the city maps with
hundreds of buildings they belong near the flight area only, the cheap
`City` boxes further out. Industrial estate 0.14 s.
Load (before the town): about 7.5 s (the houses with gardens 3.5 s of it; street
furniture, farm, fields and power lines 0.6 s, rocks 25 ms). 335 draw
calls at the spawn. Known: where a
road leaves the detailed land for the horizon ring there is a step of
up to a metre (600 m out, beyond the flight border).

Labs: `TerrainLab` (one landscape per run: `SH_TERRAIN=rolling|hills|valley`, `SH_SEED`; with a river, a road and a bridge - `SH_BRIDGE=beam|arch|truss`, `SH_DUCKS=1`, `SH_TROLLEY=1` force those), `TreeLab` (every species x shape, one tree per surprise), `HouseLab` (4 houses, about 13 views each: outside, the ways in,
every room), `ToiletLab` (one toilet per floater + lid states, front /
bowl / close-up).

## Idea backlog

Ideas from the user that are not built yet go here, with the date.

- 2026-10-04, flagged by the user: **stable seeds and per-piece overrides.**
  Today one change ripples: VillageKit.build_plots seeds plot i with
  first_seed + i (insert or drop a plot and every later house changes),
  and CityHouseCreator.build_row draws every house from one shared rng
  (change one house and the rest of the row reshuffles). Give every
  piece its own fixed seed (from its position or its own number), and
  give each map one place to write overrides - "plot 7: new seed",
  "town house 12: altbau with a cafe", "plot 3: remove". Related: an
  option that pins a detail should still draw its random number, so
  the house's other details don't shift.
- (the tree generator was built 2026-10-02)
