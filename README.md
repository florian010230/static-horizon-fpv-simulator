# Static Horizon FPV Simulator

A free FPV drone flight simulator, source code on GitHub, built in
[Godot 4](https://godotengine.org) (free forever, no revenue cap,
MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

**Download** (Windows, macOS, Linux):
[itch.io](https://static-horizon-fpv.itch.io/static-horizon-fpv-simulator)
(the itch.io app keeps the game up to date),
[GitHub releases](../../releases/latest) or
[statichorizonfpv.com](https://statichorizonfpv.com).

This is a first playable slice: a main menu in the companion website's
own dark theme (the artificial-horizon logo, the "STATIC HORIZON FPV
SIMULATOR" wordmark in Oswald, no image assets anywhere) with a live 3D
preview of your drone - pick it right there with the arrows either side
of it - then **Play** -> **Choose a Mode** -> **Choose a Map**:

- **Choose a Mode**: **Freestyle** (every map, including the race
  tracks - no lap timer, next-gate marker or ghost there) or **Race**
  (the three race tracks only - Race Field, Race Arena, Office Whoop
  Race - with a full 3-lap timed race, live splits, a ghost of your own
  best lap, and personal bests). `Settings.game_mode` persists the
  choice; `MapCatalog.is_race()` marks which maps are race tracks and
  `RaceCourse` disables its own timing/marker/ghost entirely in
  Freestyle. Every map card in Choose a Map now shows a real rendered
  preview picture of that map (`images/maps/<id>.jpg`); a race map's
  card also shows each drone's best lap and best 3-lap race once one is
  set.
- **Static Three**, **Static Five**, **Static Race** or **Static
  Whoop** - the Static Three is this sim's own 3-inch freestyle quad (3
  inch, 150 km/h, 245 g; its numbers are grounded in a real
  [DeepSpace Seeker3](https://oscarliang.com/deepspace-seeker3/),
  but it isn't that product); the Static Five is a typical 5-inch 6S
  freestyle build (5 inch, 210 km/h, 650 g, ~9:1 thrust-to-weight); the
  Static Race is a typical 5-inch 6S race build, not a specific product
  (5 inch, 170 km/h estimate, 440 g, 2207 ~1950 KV motors, 11:1
  thrust-to-weight, 225 mm wheelbase - race builds run lighter and
  harder-pushed than freestyle ones, per oscarliang.com and
  x-teamrc.com); the Static Whoop is a 75 mm 1S brushless ducted micro
  (70 km/h estimate, 32 g) modelled on a current 75 mm brushless ducted
  whoop, built for tight indoor spaces. Four real frames with their own
  mass/thrust/drag, and their own model: the three non-whoop quads are
  built like a typical true-X frame - a carbon bottom plate with
  tapered arms and motor pads, a top plate on standoffs, an FC stack, a
  camera in TPU side plates (tilted 25 degrees on the two freestyle
  quads, a race-steep 45 on the Static Race, which also sits lower on
  short standoffs with its pack strapped under the bottom plate instead
  of on top), copper stator windings visible under each spoked motor
  bell, a metal lens ring, a rounded LiPo with a label band, strap and
  XT60 lead, a VTX antenna on a TPU mount (a slim near-vertical whip on
  the Static Race), receiver whips, a small rear LED strip and 3-blade
  pitched props, lime green on the Static Race; the Static Whoop is
  built like a real ducted whoop instead - closed thin-walled ducts
  with a flared top lip and an inner floor lip (the props sit inside
  the upper half), motor mounts braced to the duct floor, arms to a
  centre plate, bridges between neighbouring ducts, an angular black
  canopy with the camera (25 degrees) behind its front window, the 1S
  pack in a holder behind it, a copper-pipe antenna, red motor bells
  and orange 3-blade props. All of it lit by a small view-space studio
  light rig (`shaders/drone_studio.gdshader`: key/fill/rim lights,
  specular highlights, a carbon-twill weave texture) rather than the
  engine's lights, which do nothing useful on this GPU either. Each
  frame also has its own motor sound - the whoop screams high, the
  3-inch whines, the race snarls around 640 Hz, the 5-inch growls lower.
- **Village** (Holderbach) - a small village in a stream valley: a main
  road that winds through the village past the church square, over a
  stone arch bridge and out into the haze; side streets with furnished
  houses and gardens (about one in five can be flown into); a church
  whose tower you can fly up and out through the belfry arches; a
  stone railway viaduct with a goods train on it to slalom through; a
  ruined bando (abandoned farmhouse and barn) beyond the railway; a farm
  with fields; and the FPV club field where you start, with gates,
  hoops, a tunnel, a ladder and a dive gate.
- **Factory** (Werk Lindner) - a working plant on the edge of a town:
  a production hall open at both ends to fly through, a warehouse with
  loading docks and lorries, a boiler house with a tall chimney, a
  tank farm, a pipe rack to fly under, silos with a conveyor gallery, a
  cooling tower you can fly into from below and out of the top, a rail
  siding off a main line, an office and a car park. Fenced, with a gate
  on the public road.
- **School (whoop only, indoors)** - at real scale: a 45 x 27 x 7.5 m sports
  hall (the standard German "Dreifeldhalle") with two handball/indoor
  football goals with nets, handball + volleyball court lines,
  basketball boards, wall bars, climbing ropes, hula hoops, rolled-up
  divider curtains and high windows; a foyer; a 70 m corridor with
  lockers; five classrooms with desk rows, blackboards and teacher's
  desks. Indoors only: the entrance is a glass door and the emergency
  exit is closed, and the flight area is the building's own footprint.
  Hoops, basketball rims and the village's loop are solid rings now -
  only their middle is open. Always flies as the whoop.

The other maps are generated from code (`scripts/maps/`, see "Generated
maps" below), as are the Village and the Factory. The map picker labels every map Low / Medium / High
performance and can filter by it:

| Map | Tier | What it is |
|---|---|---|
| Abandoned Steel Mill | High | Inspired by the great ironworks of the Saarland: a river, a main line through the town station, a row of Cowper stoves, six blast furnaces in one line with dust catchers and cast houses over the iron line, skip hoists up from the Möllerhalle bunker building (a 244 m column slalom underneath), the ore monorail from the ore yard, blower hall, coking and sinter plants, gas holder, the town on the hill and an overgrown wood. Hollow gas and blast mains with open joints to fly through. | Abandoned for thirty years: a collapsed rolling-mill hall with a bando inside, rusting sidings, broken windows, birches growing out of the slag, and something odd in the slag heap.
| Construction Site | High | A city block under construction: an 18-storey concrete frame with open floors, two lattice tower cranes, a 12 m excavation pit with sheet piles and struts, a steel frame, site machines, the city grid round it and an S-Bahn on brick arches. |
| Mountain Lake | High | Kaltensee, an alpine reservoir under rocky peaks: a curved concrete dam with its spillway and a gorge to fly out of, a long avalanche gallery over the shore road, a chapel on an island, a waterfall in a hanging valley, a cable car to a summit station, a lakeside village, a campground and an alpine farm. |
| Parking Garage | Medium | An abandoned multi-storey car park: 2.7 m decks, two-lane ramps, collapsed slabs, broken parapets, stair towers. |
| Harbour & Central Station | High | A compact port city where everything connects: container terminal with ship-to-shore and gantry cranes, a rail branch curving into the terminal's loading tracks, a double-track main line through a through-station (real 1:9 turnouts, a 280 m glass train shed), freight sidings, road bridges over the railway, the old harbour basin with a marina and brick warehouses, grain silos, an oil terminal, and a city grid with towers, a tram boulevard and traffic. Rails and roads run out of the map into the haze. |
| Race Arena (Race mode) | Medium | Indoor league race with glowing LED gates, a tunnel, a scaffold tower gate and a gate hung from the roof trusses before the finish. |
| Race Field (Race mode) | Low | A 12-gate clockwise lap round the whole field: MultiGP-style gates, a ladder, two dive gates, hurdles, a double gate, a tower gate, turn flags at the corners. |
| Office Whoop Race (Race mode) | Low, whoop | 60 cm gates between desks on a 5th floor, one hung from the ceiling, glass meeting room, city below. |
| Playground | Low, whoop | Tower with slide and rope bridge, swings, crawl tubes, sandbox. |

In flight the top left shows one status line (armed state, mode,
throttle, FPS; the key list is in the pause menu). A Betaflight-style
**OSD** shows throttle, altitude, speed and flight time at the right
(metric or imperial - Settings -> Display -> Units); with "Battery
simulation" on, the pack voltage (total and per cell), mAh used and
flight time appear top left, with a LOW BATTERY warning. The High maps
have only light haze now, a coarse terrain ring out to the horizon so
their edge never shows, and are 2-4 times the area they were. Each drone carries a typical real
pack (`scripts/battery.gd`: whoop 1S 480 mAh, Static Three 4S 850 mAh,
Static Five 6S 1300 mAh, Static Race 6S 1100 mAh) that drains with
current and sags under load;
Settings -> "Battery simulation" turns on drain, sag and the readout. Acro
rates (Settings -> Rates) are Betaflight's own: all four rate types
(Betaflight, Actual, Quick, KISS) with Betaflight's formulas from
`rc.c`, per axis, entered as the same numbers the Configurator shows,
with its three-axis preview graph and presets (`scripts/rates.gd`;
default Actual 70 / 670 / 0.54) - copy them from your quad. Optional realism (Settings -> Flight, all off by default):
battery sag with Betaflight-style LOW BATTERY / LAND NOW warnings, prop
damage after hard crashes (less thrust, a yaw pull, jitter), and wind on
outdoor maps (Light / Medium / Strong, 3-10 m/s with gusts and shelter
behind buildings). Camera look (Settings -> Camera & HUD): Clean,
Analog, Digital or HDZero - each breaks up like the real system when
walls, hills or distance come between you and the drone (the OSD shows
the link quality). Settings has
five tabs: Graphics, Camera & HUD, Flight, Rates, Radio (with per-radio
connection tips), every option explained in one line under it.
All settings are saved (`user://settings.cfg`).

In Race mode a race is `RaceCourse.LAPS = 3` laps from a flying start:
the clock starts at the first pass of START, not a countdown, and fly
the gates in order (the next one glows green with an arrow over it,
numbered with a billboard `Label3D` above every gate, START labelled
"S"). Every gate after the first shows a live split against the best
lap's own splits - green `-0.31` when you're ahead, red `+0.42` when
you're behind - and flying through a later gate instead of the next one
shows "MISSED GATE n" rather than silently not counting it. The best
lap flies along as a translucent ghost (`user://race_ghosts.cfg`), and
beating it flashes "NEW PERSONAL BEST LAP" in the HUD. Timing events
(gate, lap, personal best, race start, finish, a missed gate) each get
their own short synthesized beep. At the finish line a results card
lists every lap, the total, "NEW TRACK RECORD" or your rank, and your
local top 5 races for that exact track and drone
(`user://race_board.cfg`, with the date; `RaceCourse.boards(map_id)`);
the next pass of START starts a new race without returning to the menu.
Records are kept per *track layout*: each race map's `MapCatalog` entry
carries a `"track"` number, and `RaceCourse.section(map_id)` turns that
into a key like `race_field@2`, so redesigning a track starts a fresh
record table instead of comparing against times set on the old layout.
In Freestyle the same three maps can still be flown, just without the
timer, splits, next-gate marker or ghost.

Every map's play area is meant to read as endless (distant hills, or
just a big room) rather than visibly walled off - there's no solid
border fence anymore. Fly far enough out and a warning appears first;
keep going past that and the map reloads fresh, the same idea as an FPV
radio losing link range far from the pilot (see "The invisible border"
below).

Both Angle (self-level) and Acro flight modes are available (Acro by
default), with live-tunable PID/rates/camera/throttle response, a menu
with real settings (fullscreen, crosshair, shadows, max FPS, persisted
Acro rates shown with a Betaflight-style rate curve graph, and a
step-by-step radio calibration wizard), and a procedurally synthesized
motor sound (no audio or image assets needed anywhere in the project).
Not a Betaflight-accurate simulation — a simplified rigid-body model,
sized/weighted/geared to match real drones and grounded in Betaflight's
real default rate curve and mode behavior, good enough to feel like
flying, and to build on. Crashes are a normal rigid-body collision; prop damage
is an optional extra (see above).


## More to find and to know

- **Garden gnomes** hide on the maps (one to three each). Fly into one
  to pick it up; the **Achievements** button in the main menu shows
  what you have found and earned (first flight, explorer, race
  finished, personal bests, gnome spotter and collector).
- **Race ghost**: your best lap flies along as a see-through copy of
  your own drone, saved per track and drone (Settings -> Flight ->
  Race mode to switch it off).
- **Update check**: on start the menu asks GitHub once whether a newer
  release exists and shows a small "Version x available" hint in the
  bottom-right corner - no popup. The **Updates** screen shows what's
  new. To switch it off: the Updates screen has a "Check for updates
  when the game starts" toggle (this is the only network request the
  sim ever makes, and it sends nothing about you).
- **Faster loading**: a generated map is built once and cached
  (`user://mapcache`); every later load takes 1-5 seconds instead of
  10-20, and uses less memory. The cache refreshes by itself after an
  update. `SH_NOCACHE=1` turns it off.
- **Closer detail**: ground texture and grass around the drone, sun
  glare, warmer haze toward the sun, better clouds, dust in the air
  indoors.

## First start

The sim is free and not signed with a paid certificate, so your system
warns once:

- **macOS:** open the app once and close the warning, then System
  Settings -> Privacy & Security -> "Open Anyway" (older macOS:
  right-click the app -> Open -> Open).
- **Windows:** if "Windows protected your PC" appears, click "More
  info" -> "Run anyway".
- **Linux:** if it doesn't start, make it executable:
  `chmod +x StaticHorizonFPV.x86_64` (or Properties -> "Allow
  executing").

Plug in your radio in USB joystick mode, then Settings -> Radio ->
Calibrate Radio.

## Previewing it

There's no way to get an actual rendered screenshot in headless mode -
`--headless` never starts a real GPU context. `scripts/dev_preview_capture.gd`
is a tiny dev tool (registered as an autoload, but does nothing at all
unless invoked) that automates a real windowed run and saves screenshots:

```
godot --path . -- --dev-preview
godot --path . -- --dev-preview village school   # only these sections
```

Needs a real display (it's genuinely playing the game for a few seconds,
just moving the camera around and taking screenshots), and it isn't
headless-compatible. Saves `previews/preview_*.png` shots of the menu
screens and about ten views per map (street, house interiors, church,
underpass, farm; factory hall, dock, tank farm; sports hall, goals,
corridor, classroom, schoolyard), each from a
frozen drone aimed with `look_at()` at a fixed spot. It also prints
each map's settled frame rate (`SPAWN_FPS`). That folder has a
`.gdignore` so Godot doesn't treat the screenshots as game assets, and
it's gitignored too, since they go stale the moment a map changes -
regenerate anytime.

The same tool has a few task-specific modes:

- `godot --path . -- --dev-preview borders` - flies the drone just
  outside each map's flight area and prints "BORDER ok/FAIL" per map
  (the visible border grid/hazard stripes must actually show).
- `godot --path . -- --dev-preview thumbs <map id>` - renders one map's
  menu-card preview picture (`images/maps/<id>.jpg`, 1024x512, High
  quality, no HUD, camera tilt 0, border disabled, haze pushed further
  out) and saves it where the map picker reads it from. One map per
  run, deliberately: a single long run over every map sometimes left
  later maps half-rendered (the camera positions live in
  `dev_preview_capture.gd`'s `HERO` dict).
- `godot --path . -- --dev-preview floatcheck` - checks the hand-made
  scene map (the school) for solid pieces floating above
  the ground, the same check the self-test runs for generated maps (see
  "Nothing floats" below).

## Self-test

```
godot --headless --path . -- --selftest
```

Plays the actual game end to end, the way a pilot does - keypresses and
radio stick/button events are injected through the real input path, not
set directly. For every map and drone (and performance mode) it checks:
the right drone loads, the drone rests still at spawn inside the flight
area, arms, takes off with the keyboard and with a simulated radio (if
a joystick is plugged in), W flies forward, D moves right, R resets it;
plus the menu flow into a map (through the loading screen), the About
screen, that a drone dropped on its back ends up upright again, and -
with a virtual radio (`InputManager.test_joy`) standing in for the OS
joypad - the whole calibration wizard (auto-accepting held sticks,
detecting inverted channels, assigning an arm switch on its own
channel or a button) and the arm switch's safety rules. The real
calibration file is backed up and restored around it. One PASS/FAIL
line per check, exit code 1 on any failure. Also covers every generated
map, a radio with an unusual channel layout (sticks on axes 6-9, arm on
button 40), a full timed race lap (plus that cutting the course
doesn't count), both game modes, and that every generated map has no
floating pieces (`BuiltMap.floating_pieces()` - see "Nothing floats"
below). Current result: ~560 checks, 0 failed (the count varies a little with which radio paths a run exercises); `SH_SELFTEST_ONLY=menu,realism,race,cache` runs just those parts.

## Requirements

- [Godot 4.x](https://godotengine.org/download) — free, no account needed.
- Optional: an FPV transmitter with USB joystick mode (e.g. RadioMaster
  Pocket). Without one, the sim runs fully on keyboard.

## Running it

1. Install Godot 4.
2. Open Godot -> Import -> select this folder's `project.godot`.
3. Press F5 (or the Play button, top right) to run. It opens on the
   main menu; Play starts the flying park, `Esc` in-game returns to
   the menu.

## Performance

Built to run on weak hardware (4GB RAM, integrated graphics), and kept
that way deliberately as the project grew:

- "Compatibility" (GL) renderer by default — the lightest Godot 4
  option, for old/integrated GPUs. Change it in Project Settings ->
  Rendering -> Renderer if you have a decent GPU and want more later.
- Shadows are computed by the sim itself (see "Shadows and lighting") -
  a shadow map rendered once per map, not every frame.
- No glow / bloom and no engine fog: measured on the dev machine, glow
  alone cost ~40% of the frame rate on High. The fog is a few
  instructions in the world shader instead.
- **Render distance** (Settings -> Graphics, 300-3000 m, default 1200)
  - the world fades into the haze there; shorter = more FPS.
- **Graphics quality** (Settings -> Graphics: Low / Medium / High,
  Medium by default) scales the 3D render resolution (55% / 75% / 100%
  - the HUD and menu stay sharp), stops drawing small objects (lamps,
  cars, sleepers, desks) beyond 70 / 120 m and medium ones beyond
  180 / 320 m, and draws full trees out to 140 / 220 / 320 m. Matters most on
  HiDPI/Retina screens, where the 3D view otherwise renders several
  times the pixels of a 1080p screen. Measured in the village: GPU
  ~30% on Medium, ~19% on Low.
- Physics runs at 120Hz (the flight controller is verified stable down
  to 60Hz; 240Hz cost CPU for nothing you could feel), and the drone's
  `contact_monitor` is off - it only drives collision *signals*, which
  nothing uses (contacts for prop strike still come through
  `max_contacts_reported`), and it had tripled the cost of a physics
  step. Together with hiding the O tuning panel by default: CPU in the
  village ~60% -> ~35%, factory ~60% -> ~38%, school ~78% -> ~61% of
  one core (at the 60 FPS cap). `max_physics_steps_per_frame` is 16 so
  a machine running at 15 FPS still gets real-time physics.
- **Performance mode** (Settings -> Physics, off by default) puts it
  back to 240 Hz with full collision tracking, for stronger PCs.
- The main menu runs capped at 30 FPS and draws its background from a
  small precomputed gradient image - an earlier version drew large
  translucent circles every frame and kept the GPU at ~50% (fans
  spinning) with nothing but the menu open; now ~8%.
- Every `HollowBuilding` merges all its walls/floor/ceiling into one
  mesh with one surface per material (floor, ceiling, interior wall,
  facade, roof, trim, glass) - a handful of draw calls per building, not
  one per wall segment. Interior surfaces are *unshaded* with their
  lighting baked into vertex colors, which is both the cheapest shader
  Godot has and what makes rooms readable (see "Rooms you can read at a
  glance" below). Classroom desks are `MultiMesh` instances.
- Trees are 80 small, low-poly (`radial_segments` cut to 7-8) individual
  scene instances rather than procedurally spawned at runtime - a
  village-scale map with a handful of buildings and 160 simple tree
  meshes is still comfortably cheap on integrated graphics, and being
  real nodes means they show up in the editor and can be dragged/moved
  like anything else, which a `MultiMeshInstance3D` (the previous
  approach - 2 draw calls total, but opaque, un-editable blobs) couldn't
  offer.
- All textures (grass/brick/siding/concrete/asphalt) are generated once
  at startup (a few tens of ms) rather than loaded from image files.
- Motor sound is two one-time pre-rendered loops per drone class
  (~100-150ms to render, once), not synthesized every frame — see
  `scripts/motor_audio.gd` for why that distinction matters on weak
  hardware specifically.
- `run/max_fps` capped at 60 in `project.godot` - rendering faster than
  that burns CPU/GPU for no visible benefit on most displays, [a general
  Godot low-end-hardware recommendation](https://dev.to/orlalalala_0d2542b48051ed/shipping-a-godot-4-game-to-cheap-android-phones-what-actually-fixed-my-performance-2ofd).
- Draw call count for the village's static world geometry, trees
  included, is a few hundred - comfortably under the range where budget
  integrated graphics starts struggling, since every mesh involved is a
  handful of low-poly boxes/cylinders, not anything dense.
- `Drone`'s `continuous_cd` (continuous collision detection) is on, and
  its collision shape is a small sphere rather than a thin box - a flat
  shape can present a near-zero cross-section to a wall at certain tumble
  angles, which is exactly the kind of edge case that lets a fast body
  tunnel through thin geometry for a frame; a sphere has no thin axis to
  exploit. `drone.gd` also hard-clamps linear/angular velocity to a
  generous safety ceiling (well above anything normal flight produces) -
  measured empirically that a hard corner hit could otherwise spike
  angular velocity to ~2234 deg/s for a single physics step, which read
  as the drone "going haywire" after a crash even with no actual
  clipping happening.
- `project.godot` sets `window/stretch/mode="canvas_items"` with a
  1600x900 reference resolution - without it, Godot sizes its 2D UI in
  raw framebuffer pixels, so on a HiDPI/Retina display (where the actual
  framebuffer is 2x or more the OS's logical resolution) every menu and
  HUD element renders at roughly half its intended size. This scales the
  whole UI to the actual display instead, at no cost to the 3D
  view - `canvas_items` only affects 2D Control/CanvasLayer layout, never
  the 3D viewport's render resolution.

## Controls

**Keyboard (no radio needed):**
- `W`/`S` pitch, `A`/`D` roll, `Q`/`E` yaw
- `Shift`/`Ctrl` throttle up/down (holds its value, like a real stick)
- `Enter` arm / disarm (works alongside a radio's arm switch)
- `L` toggle Angle (self-level) / Acro mode — starts in **Acro**
- `R` reset drone to spawn
- `V` line-of-sight view: the camera jumps to the spawn point, at eye
  height, and turns to keep following the drone - the way a pilot
  without goggles spots their own quad
- `O` show/hide the tuning panel
- `P` replay the last 60 seconds of flight (always recording in the
  background, 30 Hz): `Space` pause/play, `Left`/`Right` jump -/+5 s,
  `Up`/`Down` change speed (1/4x-2x), `C` cycle the camera (chase, FPV,
  line-of-sight from the spawn point), `P` again to resume flying
  exactly where it left off (position, velocity and rotation restored).
  The flying drone freezes and hides while a replay plays; a second
  copy of its model flies the recording. HUD and crosshair are hidden
  during a replay.
- `Esc` pause menu (camera angle/FOV, drone, reset, Settings, main menu)

The menu has a **Settings** button (see above), and the Rates tab works
like Betaflight Configurator's: pick the rates type, type in roll /
pitch / yaw, watch the three curves. The drone reads them live. The
pause menu's header is **Main menu** (its Continue button, and `Esc`
again, resume the flight) with **Reset drone** / **Change map** /
**Settings** in a row below it. The drone is picked with the arrows on
the home screen; **Play** leads to **Choose a Mode** (Freestyle or
Race - see above) and then the map choice, loaded behind a loading
screen (progress bar, a tip, motor sound muted) instead of a frozen
window. **About** shows the version, how the sim is made, the controls,
credits and a link to statichorizonfpv.com.

**Pilot aids** (Settings; a research pass over Liftoff, Velocidrone,
Uncrashed, DRL and TRYP FPV - sources in the code comments):
- **Stick overlay** (Settings -> Camera & HUD, optional, off by default) - a small roll/pitch/yaw/
  throttle overlay in the OSD, the way Liftoff and Velocidrone show what
  your hands are doing.
- **Betaflight throttle curve** (Settings -> Rates) - MID and EXPO,
  `rc.c`'s own formula, so a throttle curve copied from a real quad's
  Betaflight dump behaves the same way here.
- **Fisheye lens** (Settings -> Camera & HUD: Flat / Light / Strong) -
  barrel distortion in the analog-video shader, matching how a real
  wide-FOV FPV lens looks rather than a flat rectilinear projection.
- **Line-of-sight view** (`V`) - see above.

**RadioMaster Pocket (or any radio in USB Joystick mode):**
1. Plug in via USB-C. On the Pocket, make sure USB mode is set to
   "Joystick" (EdgeTX: on boot, choose the Joystick USB mode, or set it
   under System -> Hardware).
2. Launch the sim. It auto-detects the first connected joystick and
   switches off the keyboard fallback.
3. In the menu, go to Settings -> **Calibrate Radio**. This is a
   step-by-step wizard with a live view of every raw axis (rest point
   marked, assigned channels labelled) and a step bar (Rest, Roll,
   Pitch, Yaw, Throttle, Arm, Test) - not manual axis-number guessing,
   and no mouse needed mid-way: a stick held at its end for 0.7 s is
   accepted on its own. First it asks
   you to let go of the sticks (throttle down) and records where every
   axis *rests* - real gimbals are rarely at exactly 0.000 over USB, and
   that offset used to reach the flight controller as a constant small
   stick command (the drone slowly rolling or yawing on its own). Then
   it asks you to hold each of ROLL/PITCH/YAW/THROTTLE at the extreme that should read
   as "positive" here (right/forward/right/max), and figures out both
   which raw axis that is *and* whether it needs inverting from the
   sampled sign alone - no separate "does this feel backwards?" step
   afterward. Throttle gets real end points (rest = low, held = high)
   instead of an invert flag. The arm step asks you to flip whichever
   switch you want to arm with ON and back OFF - a switch EdgeTX reports
   as a button, or one mixed onto its own channel (an axis), even one
   that reads "pressed" when off; "Skip" keeps the current one. The
   last step shows both gimbals and the arm switch exactly as the sim
   now reads them. **Assign Arm Switch** in Settings runs just that step. Everything is saved to
   `user://input_calibration.cfg` and reloaded automatically next launch
   (see `InputManager.save_calibration()`/`load_calibration()` in
   `scripts/input_manager.gd`) - the one setting in this whole project
   that intentionally survives a restart, since it depends on your
   specific hardware rather than preference.
4. The arm switch works like Betaflight's ARM mode on an AUX switch:
   armed while it's ON, disarmed when it goes OFF. Arming is refused
   while throttle reads above ~8% (`arm_throttle_safety_threshold`), and
   a switch that is already ON when a map loads, or went ON with the
   throttle up, has to be flipped off and on again first - the HUD says
   which. Settings has "Arm is a switch" - turn it off for a momentary
   button, where each press toggles.
5. Four more radio controls can be assigned the same way, each
   optional and unassigned by default: Settings -> Radio has **Assign
   Mode Switch** (sets Acro/Angle directly from the switch position,
   like Betaflight's ANGLE on an AUX switch, rather than toggling),
   **Assign Reset Button**, **Assign Line-of-Sight Button** and
   **Assign Restart Switch** (flip it: the map reloads from the start -
   race, timer and drone; Reset only puts the drone back), each
   with its own Clear and a status line, captured by the same
   calibration-wizard step the arm switch uses. Until assigned, nothing
   changes - mode is still `L`, reset still `R`, line-of-sight still
   `V` on the keyboard, and those keys keep working alongside a radio
   binding either way.

If you'd rather set the raw axis numbers by hand, `scenes/InputManager.tscn`'s
`InputManager` node still exposes `axis_roll`/`axis_pitch`/`axis_throttle`/
`axis_yaw`/`invert_*`/`arm_button_index` directly in the Inspector -
the calibration wizard is just a friendlier way to set the same fields.

**If the radio is plugged in but the drone won't arm or take off:** a
radio that is connected over USB but not sending anything (switched
off, not in USB Joystick mode, or macOS not yet allowing input access
for Godot - System Settings -> Privacy & Security -> Input Monitoring)
reports exactly 0.000 on every axis. The sim now notices that: the
radio only takes over once it has actually sent data, the keyboard
stays in control until then, and the HUD says "Radio plugged in but
sending no data". (Before, 0.000 on the throttle channel read as 50%
throttle, which blocked arming - the drone couldn't take off anywhere.)

**If a control drifts or fires on its own with nothing touched:** open
the `O` panel and check the device name/axis values shown there first.
Godot can enumerate a joystick that's technically connected but not
actually being held/flown (including the Pocket itself, sitting idle),
and a raw axis reading of exactly `0.0` on a "centered -1..1" channel
gets read as 50% on that channel (e.g. 50% throttle) — this is also
exactly why the arm-safety check above exists. Re-running the
calibration wizard (which records the rest positions) is the real fix
for a stick that doesn't read a true 0; `deadzone` (0.03, and rescaled -
the output ramps up from 0 at the deadzone edge instead of jumping) only
has to swallow sensor noise now.

**Stick sign convention:** every stick getter in `InputManager` returns
+1 for roll right / pitch forward / yaw right / full throttle, on the
keyboard and on a calibrated radio alike; `Drone` converts that to body
rotations itself. This used to be split across the keyboard, the flight
model and the invert flags, which is how Angle mode's roll ended up
reversed relative to Acro's, and how the calibration wizard reversed
every axis - both fixed.

## In-game menu

`Esc` while flying pauses the game and opens a small menu: camera angle
and field of view (applied live to the frozen view behind it), switching
drone (arrows; locked to the whoop in the school), and - in its own
row at the bottom - **Reset drone**, **Change map** and **Settings**.
The header reads **Main menu** rather than "Back" (it leaves the flight
entirely); `Continue` and `Esc` again both just resume. Settings is the
same screen the main menu opens - Back from it returns to wherever it
was opened from (the pause menu in game, the home screen from the
menu). Camera angle and FOV are kept across maps.

## Shadows and lighting

**The engine's sun does nothing on some GPUs.** Measured on the dev
machine (Intel Iris 6100, macOS, Compatibility renderer): screenshots at
sun energy 0 and 3 were pixel-identical in every map - everything was
lit by ambient light alone, which is why sunny and shaded sides looked
the same (a known class of Intel/macOS driver bugs,
godotengine/godot#74763). So lighting is baked into vertex colours
with unshaded materials: ambient + sky fill + sun x N.L, darkened
toward the ground as cheap ambient occlusion - `Geo.shade()` for the
generated maps, `LightBaker` for the hand-made ones at load time. It
looks the same on every GPU and costs nothing per frame.

Godot's own shadow maps render nothing at all on some GPUs - verified on
the dev machine (Intel Iris 6100 on macOS, Compatibility and Vulkan
renderers): screenshots with the sun's shadows on and off were identical
(matching known engine issues, e.g. godotengine/godot#67866). So the
Shadows setting (on by default) uses shadows made by the sim itself:

- `WorldShading` (`scripts/world_shading.gd`): at load every world
  material is converted to one shader family (`shaders/world.gdshaderinc`,
  same unshaded baked look), and the map renders a **static sun shadow
  map once**: an orthographic camera along the sun, every mesh drawn
  with `shaders/shadow_depth.gdshader` (depth along the sun, packed into
  16 bits), read back into a texture. Every surface compares its own
  depth with it (bilinear 4-tap PCF) and takes out the sun's share of
  its baked light - buildings shadow buildings, bridges shadow roads.
  It also does the distance fog. All of it runs on global shader
  uniforms (`project.godot [shader_globals]`). Moving things (the
  drone, nodes with meta "dynamic") are hidden during the capture.
- `DroneShadow` (`scripts/drone_shadow.gd`): a soft shadow under the
  drone, one raycast along the sun per frame, onto whatever is below -
  the classic FPV height cue for landing.

The outdoor maps also got brighter ambient light (shaded sides of
buildings no longer go dark when looking toward the sun - brightness now
varies about ±1% by view direction instead of ±5%), a green instead of
dark-brown sky "underside", and a large grass plane out to the horizon
(`BuildingStyles.add_far_ground()`), so looking toward the map edge
never shows a dark void.

Every generated map (and, through `Settings`, the hand-made village,
factory and school) renders its sky with `shaders/sky_clouds.gdshader`
instead of the plain `ProceduralSkyMaterial` gradient: same base
colours, plus a sun disc and warm glow around a low sun, and clouds
from a single `FastNoiseLite` texture baked once at load, projected
onto a flat layer that shrinks toward the horizon, lit brighter on the
sun's side and tinted by its colour (orange at sunset), drifting
slowly; an environment key `"clouds"` sets the cover threshold (1.2 =
clear). `BuiltMap.cloud_sky()` is the shared helper. The clouds'
animation (`TIME` in the sky shader) made Godot re-render the sky's
reflection cubemap every frame, which cost real FPS (Race Field 48 ->
29); the fix gives the cubemap render passes the plain static gradient
instead, turns off reflected light (nothing uses it - every material
here is unshaded) and uses a 32 px radiance size, recovering the frame
rate (54 FPS Race Field, 44 Harbour).

Any material named `*water*` (`Geo.water_mat`) gets moving ripples, a
Fresnel sky reflection that strengthens at shallow viewing angles, and
a glint off the sun, in the same shared world shader - toned down from
a first version that made the sunset harbour basin's water read as
sand. A small global colour grade rides along in the same shader pass
over every world surface at no extra cost: contrast 1.08, saturation
1.12, plus an optional per-map warmth, set once by
`WorldShading.set_grade()` and overridable per map via the
environment's `"grade"` meta.

## Crashing into things

A crash behaves like a real quad's (all verified headless, frame by
frame, before and after):

- **Prop strike.** A propeller touching a wall, ceiling or object can't
  move air, so while touching it makes almost no thrust, and it takes a
  quarter second to spin back up. The quad bounces off, tips away from
  the wall and falls - instead of what it did before: stop dead with no
  bounce and stay pinned to the wall by its own thrust (it even crept
  *upward*), or stick to a ceiling motionless. A ceiling above the props
  blocks all four; landing on the floor blocks nothing - only an
  obstacle at the prop disc or above it counts, since a whoop rests on
  its ducts (checking that too broadly once kept the whoop from
  ever lifting off).
- **No seeing through walls.** The collision shape is the drone's real
  outline - one sphere per prop, the body, and a "nose" sphere around
  the FPV camera - so the camera always stays farther from a surface
  than its near clip plane. Before, the camera sat 9 cm in front of a
  single body sphere: nose-first against a wall it was 1 cm *inside*
  the wall. The camera is now at each frame's real camera pod, and the
  drone's own model is on a render layer the FPV camera doesn't draw (so
  its props don't cover the picture).
- A little bounce (`bounce = 0.3`) and no I-term windup while in contact.
- **Flipped over? Wait two seconds, or flip yourself.** A quad resting
  on its back or side (tilted over 60 degrees, not moving) can't take
  off again - real pilots use Betaflight's turtle mode. After 2 s the
  drone turns itself upright where it lies, keeping its heading (the HUD
  counts down), and you can fly straight off
  (`Drone._update_flip_recovery()`). (A stick-triggered turtle mode
  existed briefly and was removed - the 2 s self-righting covers it.)
- **It sits level.** A thin skid under the frame at the lowest point of
  the collision shapes: before, the camera's nose sphere was the lowest
  point and the Static Three rested tipped 22 degrees onto its nose.

Two older notes still apply after a hard crash:

- If the drone stays **armed** and self-leveling while resting against
  something, the flight controller keeps trying to fly back to level
  indefinitely - a slow re-accelerating spin or a drone that keeps
  twitching against whatever it hit. Not a bug so much as it's exactly
  why real FPV pilots disarm the instant they crash - an armed quad
  wedged against something behaves the same way in real life. `Enter`
  (disarm) or `R` (reset) right after a crash, same as a real radio.
- **A real bug, now fixed:** if a tumble left the drone anywhere near
  upside-down, Angle mode's old self-level math could make it spin
  violently while "recovering." It extracted roll/pitch as separate
  angles with `asin()`, which has a blind spot — `asin(sin(x))` folds
  anything past 90 degrees back down, so a drone tilted 170 degrees
  (nearly inverted) read as only 10 degrees off. The controller applied
  a tiny correction when it needed a huge one, and as the true angle
  kept changing the misread swung non-monotonically. Verified with a
  frame-by-frame headless test (178 degrees roll, small initial spin):
  the old method took until t=1.0s to settle and analysis wasn't even
  needed to see it thrashing on the way there. Replaced with a proper
  3D comparison of the body's up vector against the target up vector
  (cross/dot product, not decomposed Euler angles) — well-defined for
  any orientation short of the exact 180-degree singularity every
  attitude representation has. Same test now settles by ~0.6-0.8s, and
  starts correcting at full strength from frame one instead of the old
  method's weak, confused initial response. See
  `_compute_self_level_rates()` in `drone.gd`.

## Tuning

Press `O` in-game for live sliders: acro rate curve (Center Sensitivity /
Max Rate — Betaflight's real defaults, 70/670 deg/s), Angle mode's max
tilt and correction gain, Roll/Pitch/Yaw P/I/D gains, FPV camera tilt
angle, camera FOV, and throttle response curve. Changes apply
immediately, no restart needed.

The PID gains are *normalized*: P is angular acceleration commanded per
rad/s of rate error, and the controller output is multiplied by the
selected frame's real inertia to get a torque. So the same numbers mean
the same feel on both drones (P 30 = a ~33 ms rate-tracking time
constant), and the sliders show sensible values for both - before, the
whoop's raw gains (0.00036) were too small for the sliders to even
display.

An earlier pass pushed the gains snappier, which only
became safe after a real bug got fixed: `pid.gd`'s derivative term was
raw (`(error - prev_error) / delta`), and a raw D-term amplifies any
frame-to-frame noise — a well-known problem real flight controllers
solve with D-term filtering. Without it, even a modest D gain increase
made the drone oscillate at the physics frame rate (verified with a
frame-by-frame headless test: angular velocity was flipping sign every
single step, which naive multi-frame sampling was hiding as a false
"steady state"). `PIDController` now low-pass filters the derivative
(`d_filter_alpha`), which is what made the current, tighter-tracking
gains stable.

## Project layout

- `scenes/MainMenu.tscn` — the real entry point (`project.godot`'s
  `run/main_scene`), styled with the companion website's dark theme
  (drone picked on the home screen with arrows, Play -> map choice):
  every sub-screen is a fixed card whose header (Back, and Esc) is
  always visible, content scrolls if needed. A big Oswald wordmark heading, the real
  artificial-horizon logo mark, and a small live `SubViewport` preview
  (whichever drone is currently selected, hanging off a wall hook,
  slowly turning) sit above Play (-> Choose Your Drone -> Choose a Map)
  / Settings (fullscreen, crosshair, shadows, max FPS, Acro rates + rate
  curve graph) / Quit, all built at runtime (`scripts/main_menu.gd`) -
  the menu itself stays flat 2D UI, so the tiny 3D preview is the only
  real rendering cost added.
- `fonts/Oswald-SemiBold.ttf` — the companion website's own brand font
  (converted locally from its `oswald-600.woff2`, since Godot's `FontFile`
  doesn't load WOFF2 directly), used only for the menu's heading.
- `scenes/maps/Village.tscn` / `Factory.tscn` — the village and the
  factory, generated maps (`scripts/maps/village.gd`, `factory.gd`) since
  Round 2; the hand-made scenes they replaced are gone.
- `scenes/Main3.tscn` — the school (whoop only). `scripts/main3.gd`
  forces the whoop profile on entry, applies the wall-bar/locker
  textures and runs the border check.
- `scenes/HandballGoal.tscn` — a reusable prop (the school).
- `scripts/classroom_furniture.gd` (`ClassroomFurniture`) — rows of desks
  and chairs as `MultiMesh`es, with one collision box per desk.
- `scripts/building_styles.gd` (`BuildingStyles`) — the named interior
  and exterior looks for `HollowBuilding`, a material/texture cache, and
  `apply_ground_surfaces()` (roads, paving, gravel, fields tagged by node
  group get world-space textures).
- `scripts/world_border.gd` (`WorldBorder`) — a static-method utility
  (not a scene node) called once a frame from every map's own
  `_process()`: past a warning radius/altitude it tells the HUD to show
  a warning, past a reset radius/altitude it reloads the current map.
  See "The invisible border" above.
- `scripts/hollow_building.gd` (`HollowBuilding`, a `StaticBody3D`) —
  the reusable primitive behind every fly-into building: floor, ceiling
  and four walls, each with any number of doors (open) and windows
  (glazed, with a collidable pane), optional storeys (intermediate
  floors with a stairwell hole) and an optional partition with a
  doorway. Looks come from `interior_style`/`exterior_style` (see
  "Rooms you can read at a glance").
- `scripts/updater.gd`, `updates_screen.gd`, `changelog.gd` — the update
  check, its screen, and the bundled offline "what's new" notes.
- `scripts/collectibles.gd`, `achievements.gd`, `achievements_screen.gd`
  — the garden gnomes and the achievements list.
- `scripts/fpv_video.gd` + `shaders/fpv_video.gdshader` — the camera
  looks and the video link model; `looks_fx.gd` (sun glare, dust,
  grass tufts near the drone).
- `scripts/battery.gd` — the LiPo pack model (sag, warnings); prop
  damage and wind live in `scripts/drone.gd`.
- `scripts/maps/map_cache.gd`, `pieces.gd`, `surface_check.gd` — the map
  cache, stable piece ids with per-map overrides, and the check that
  maps have no surfaces poking through each other.
- `icon.png`, `icon.ico`, `icon.icns` — the app icon (drawn by
  `tools/make_icon.py` from the logo).
- `scenes/Tree.tscn` — a single low-poly tree (trunk + foliage, no
  collision); used by the school.
- `scripts/dev_preview_capture.gd` — dev-only screenshot tool, see
  "Previewing it" above.
- `scenes/Drone.tscn` — the quadcopter: collision shape (a small sphere,
  not a thin box - see Performance above), camera mount, motor sound,
  `scripts/drone.gd` (the flight physics). Carries no hand-authored
  visual mesh nodes of its own anymore - `Drone.apply_profile()` builds
  those at runtime from whichever real frame is selected (see "Two
  frames" below).
- `scripts/drone_frame_builder.gd` (`DroneFrameBuilder`) — builds a
  recognizable quad frame (center stack, 4 arms, 4 motor bells, 4 prop
  discs, optional ducts) from primitive meshes only. Shared between
  the real flying `Drone` and the menu's preview stand-in, so both places
  always show the same non-brick model for whichever drone is selected.
- `scenes/InputManager.tscn` — autoloaded singleton for radio/keyboard
  input and calibration (`scripts/input_manager.gd`).
- `scripts/settings.gd` — autoloaded singleton holding options that
  need to survive the menu <-> gameplay scene change (crosshair,
  shadows, fullscreen, max FPS, Acro rates, selected drone).
- `scenes/UI.tscn` — HUD, crosshair, and tuning panel, built at runtime
  (`scripts/ui.gd`).
- `scripts/pid.gd` — small reusable, D-term-filtered PID controller
  class.
- `scripts/motor_audio.gd` — two rendered layers per drone class: a tone
  loop (blade-pass harmonics with a per-class spectral tilt, motor whine
  plus an odd-harmonic ESC "buzz", rumble, and four motors with slow,
  independent rpm wander so the beating between them drifts instead of
  looping audibly, built click-free by integrating whole cycles of
  phase) and a broadband prop-wash noise loop on a separate "Wash" child
  player. A "MotorLPF" audio bus low-passes the tone with a cutoff that
  tracks rpm (dull at idle, bright at full throttle); wash volume
  follows rpm and spikes on fast rpm changes (punch-outs, throttle
  chops). Tuned from flight feedback (2026-10-02): the punch-out spike
  is quieter (max +3 dB, was louder), and idle volume and brightness
  are raised so armed motors stay clearly audible at 0% throttle -
  matching airmode and idle thrust, which already kept the props
  physically turning there. Both loops are rendered ONCE at startup
  (~100-150ms per class), then pitch/volume follow throttle via native
  `pitch_scale`/`volume_db` - earlier versions synthesized
  sample-by-sample every frame in GDScript, which is a real, measurable
  CPU cost on weak hardware; this doesn't. Sources cited in the file:
  NASA's AMS 2021 quadcopter aeroacoustics paper (Kelecy), an Acentech
  drone-noise article, the BLHeli_32 ESC guide (uavmodel), and
  halfchrome/tattuworld for per-class character.
- `scripts/procedural_textures.gd` — generates every texture at runtime
  (terrain, roads, facades, floors, ceilings, wall bars, lockers...), so
  no image assets are needed either. Doors are separate small quads
  (`main.gd`), since a door is one-off, not something that should tile.

## How the flight model works

Same cascaded structure a real flight controller uses:

- **Inner loop (always on):** a PID per axis (roll/pitch/yaw) compares a
  target *angular rate* to the drone's actual angular velocity and
  outputs a correction. Roll/pitch corrections are mixed into 4 virtual
  motor thrusts applied at their real positions on the frame, so roll
  and pitch torque emerge from the physics rather than being faked. Yaw
  is applied as a direct reaction torque, since a purely vertical thrust
  force can't produce torque around the vertical axis by itself (only a
  spinning prop's drag can).
- **What sets the target rate depends on flight mode:**
  - **Acro** (`L` to select): the stick position feeds directly into
	Betaflight's real "Actual Rates" curve — soft near center (Center
	Sensitivity, 70 deg/s by default) and steep at full deflection (Max
	Rate, 670 deg/s by default). There's no self-leveling: whatever
	attitude the drone drifts to, it keeps, exactly like real acro mode.
  - **Angle / self-level** (the default): an outer P-loop compares the
	drone's actual tilt to a target tilt (stick position × max angle)
	and produces the rate command that loop needs — the same cascade
	every real FC uses for its beginner-friendly mode. Yaw is always
	rate-controlled, in both modes, same as a real FC (there's no
	"target heading" a stick can set).

- **Airmode**, like Betaflight's: once the throttle has been past 25%
  since arming, the mixer keeps full attitude authority even at zero
  throttle by shifting all four motors together instead of clipping the
  low ones - the quad keeps holding its attitude in a throttle-off dive.
  Before that point the I-term is held at zero, so sitting armed on the
  ground can't wind it up. Armed motors never fully stop (idle thrust).
- **I-term relax**, like Betaflight's (15 Hz cutoff): while the setpoint
  is moving fast, the I-term mostly stops accumulating - otherwise it
  winds up during every flick and keeps pushing after the stick is
  centered. Reproduced headless before the fix: a 0.4 s acro roll flick
  kept rolling the quad from 43 to 53 degrees over two seconds with the
  stick at exactly zero; after the fix it holds its angle within 0.2 s.
  (The other half of that bug: the drone scene had `angular_damp = 4`,
  which fought every rotation, so the quad only reached ~70% of the
  commanded rate and the integrator had to make up the rest.)
- **Drag:** quadratic body drag (dominant at speed, calibrated so both
  frames still hit their real top speeds - 150 km/h and 40 km/h,
  re-verified headless) plus *linear rotor drag* in the rotor plane
  (0.4 s^-1, mass-normalized, the middle of what Faessler, Franchi &
  Scaramuzza measured on a real quadrotor, IEEE RA-L 2018). Rotor drag
  is what makes a real quad bleed off speed once levelled out; without
  it the drone kept sliding - or, at hover throttle, kept climbing - for
  many seconds with the sticks centered.
- **Motor response lag:** each of the four motors follows its commanded
  thrust with a first-order time constant instead of reaching it in the
  same physics step it was commanded in - smaller, lighter props spin
  up faster, so the lag is per frame (`motor_tau`): whoop 15 ms, Static
  Three 20 ms, Static Race 22 ms, Static Five 25 ms.
- **Prop wash** (on by default; Settings -> Flight turns it off): descending through your own downwash - the familiar
  shake on a dive-and-catch - kicks in past 1.5 m/s of descent along the
  thrust axis (full strength by 6 m/s) while the motors are still
  loaded: an ~8 Hz random roll/pitch torque plus up to 20% less thrust.
  Tuned by flying it in a throwaway headless physics test: the first
  version shook the Static Five at up to 28 rad/s on a dive-and-catch -
  far too violent - scaled down until a catch wobbles at most ~3.4 rad/s
  (~190 deg/s) while losing lift on the way through.
- **Ground effect:** up to 12% extra thrust right at the ground, fading
  out by two prop diameters of height - the cushion under a low hover -
  checked with one ground raycast every 50 ms rather than every physics
  step.

**Is gravity right?** Yes - the standard 9.8 m/s² (checked when a pilot
reported falls felt "a bit weak"). A disarmed drop matches a real quad:
7.9 m/s after one second, air resistance capping it around 20 m/s. What
*did* soften falls were two modelling choices, both fixed: idle thrust
was 1% of max per motor (7% of the Static Three's weight - real idle is
~0.3%), and rotor drag applied at its full hover strength even with the
props idling. Rotor drag now scales with rotor speed, so a throttle-chop
fall accelerates at ~0.93 g instead of ~0.9 g easing off to 0.7 g, and
both frames still hit their real top speeds (re-verified).

**Why camera angle felt broken before:** the FPV camera's tilt is a
*fixed* offset from the drone's own body — same as a physical camera
mount on a real frame. In pure Acro mode with no self-leveling, the body
can end up resting at almost any attitude, so the camera tilt combines
with whatever that drift is, unpredictably. In Angle mode, centering the
sticks always returns the body to level, so camera angle now means what
it should: "how many degrees do I look, relative to the horizon, when
hovering." `camera_angle_deg` tilts the view **up** as it increases
(real racing/freestyle rigs mount the camera tilted down instead, to
keep sight of the track while pitched forward at speed — this sim tilts
it up instead since that's what felt right in testing; flip the sign in
`_apply_camera_settings()` in `drone.gd` if you'd rather match the real
convention).

## The frames: Static Three, Static Five, Static Race and Static Whoop

`Drone.PROFILES` (in `drone.gd`) holds four complete, independently-real
frames - mass, arm length, thrust, drag, PID gains, collision size, and
visual model all switch together via `Drone.apply_profile()`, driven by
`Settings.selected_drone` (set by the menu's Choose Your Drone panel).
It's two real drones, not one drone with a costume change.

### DeepSpace Seeker3

Mass, arm length, and thrust are set to match a real drone rather than
picked arbitrarily: ~245g flying weight, ~60mm motor arm (3" class), and
a thrust-to-weight ratio of ~7:1 (total thrust ≈ 7× weight) - typical for
a high-KV 4S 3" freestyle build, matching reviewer accounts of the
Seeker3 "ripping" with instant, crisp throttle response. A smaller,
lighter frame has much less rotational inertia than the old 5"-scale
placeholder this used to use, so PID gains were scaled down to match -
same torque now produces a noticeably bigger angular acceleration.

**Top speed is calibrated to the Static Three's claimed 150 km/h**, which
needed real drag, not just a bigger number. `RigidBody3D.linear_damp`
(the previous approach) barely slows a quad like this down at all -
measured empirically at max thrust in a steady dive: speed was still
climbing past 470 km/h after 10 simulated seconds and hadn't leveled
off. Real air resistance is roughly quadratic in speed
(`F = k * v^2`), so `drone.gd` now applies that directly and
`linear_damp` is 0. `drag_coefficient` is calibrated so a steady,
level-altitude dive at max thrust settles at ~150 km/h (verified: the
same test now cleanly converges to 149.9 km/h and holds there, instead
of climbing indefinitely) - which also makes the acceleration curve
itself more realistic: it's still explosively fast off the line (this
sim's own 0-100 km/h is well under half a second, consistent with
"rips"), but now actually tapers off approaching a real top speed
instead of climbing forever.

### Static Whoop

Modelled on a current 75 mm brushless ducted whoop rather than invented
numbers - sources cited in `drone.gd`: the maker's own product page
(75 mm wheelbase, 20.2-21.3 g dry, 0802 motors at 22,000-28,000 KV,
3-blade props, a 1S 480 mAh pack, ~7 minute flight time) and
oscarliang.com's review of the previous generation ("incredibly
nimble", hovering well under half throttle). From that: all-up weight
32 g (21 g dry plus a ~11.5 g 1S 480 mAh pack - an estimate, no source
states it directly); thrust-to-weight ~7:1 (one secondary source) ->
0.55 N per motor; motor offset 75 / 2 / sqrt(2) = 26.5 mm; 41 mm
3-blade props. No source quotes a single top-speed figure for the
class - whoops aren't marketed on it - so 70 km/h is an ESTIMATE for a
light 75 mm brushless whoop, using the same
`k = horizontal-thrust-at-max / target_speed^2` drag derivation as the
Seeker3 rather than inventing a number. Going from the Static Three's
245g/60mm frame to the whoop's 32g/26.5mm one still drops rotational
inertia sharply (roughly 50× on roll/pitch), so PID gains start scaled
down by that factor rather than left at the Static Three's values, then
verified (not just calculated) with the same frame-by-frame headless
disturbance-recovery test used throughout this project - a 150 deg/s
angular-velocity kick settles under 1 deg/s within 1.5s, on both
frames. At ~7:1 it flies light and snappy, instead of the old ~3:1
floaty micro this profile used to be. Visually, the frame is modelled
like a real ducted whoop: closed thin-walled ducts (the props sit
inside the upper half, inside a flared top lip and a narrow inner
floor lip), motor mounts braced to the duct floor, arms to a centre
plate, bridges between neighbouring ducts, an angular black canopy
with the camera behind its front window, the 1S pack in a holder
behind it, a copper-pipe antenna, red motor bells and orange 3-blade
props - the combination that makes it unmistakably a ducted whoop
rather than just a smaller quad.

## The world: bounded but not obviously so

The 500x500 flat play area (where the gates/tunnel/buildings are
calibrated) used to be ringed by a faint, semi-transparent *solid*
collider wall at ±230 - past that, 8 large flattened spheres stand in as
distant hills out to ±280-ish, under a real sky (`ProceduralSkyMaterial`,
cheapest radiance/process settings), so the world reads as continuing
past where you can actually fly. That's still true, but the solid wall
itself is gone now (see "The invisible border" below) - the world isn't
just *decorated* to look endless anymore, it actually has no physical
edge until you've flown well past where the decoration stops making
sense.

Two smaller hills (`HillNear1`/`HillNear2`, around (-70, 20) and
(85, -90)) sit inside the actual flight zone, with real collision -
unlike the 8 backdrop hills, which are unreachable, these are meant to
be flown around/over.

## The invisible border: warning, then reset

Every map's play area is meant to read as endless rather than visibly
walled off, so there's no solid collision fence at the edge anymore
(the old semi-transparent border walls in the village and factory maps
were removed). Instead, `scripts/world_border.gd` (`WorldBorder`, a
small static-method utility, not a scene node) is called once a frame
from each map's own `_process()` with that map's own radii:

- Past a **warning radius** (and, separately, a **warning altitude** -
  "invisible borders at the top" too, not just the sides), the HUD shows
  a pulsing red "WARNING: LEAVING FLIGHT AREA - TURN BACK" (`ui.gd`'s
  `set_border_warning()`), and the border itself becomes visible: the
  *whole* boundary shows a coarse 16 m grid, with a finer 2 m grid and
  hazard stripes near wherever the drone actually is - a force field you
  can see the shape of, not just a patch that lights up under you.
- Past a **reset radius/altitude**, the drone is put back at its spawn
  point instantly (same as pressing `R`) with a "OUT OF RANGE - BACK TO
  START" message, instead of reloading the whole map behind the loading
  screen - the same idea as an FPV radio losing link range far from the
  pilot, just without the wait.

The village and factory use generous outdoor radii (warning at 200m /
120m altitude, reset at 260m / 170m) - comfortably past every building,
so it only ever triggers once you've genuinely flown off into the
backdrop. The school, fully enclosed, uses `WorldBorder.check_box()`
with the building's own footprint instead of a circle around (0,0),
which didn't even match where the school stands - it only fires if the
drone somehow clips out.

## Rooms you can read at a glance

The old buildings used one flat color (or one texture) on every face,
so with shadows off a ceiling and a wall looked the same - easy to lose
which way is up. `HollowBuilding` now gives every face a role and each
role its own material (`scripts/building_styles.gd`):

- **Floors** have their own pattern and color: planks (houses), a sports
  court drawn to scale (gym), linoleum (school), concrete (factory).
- **Walls** carry bands that always sit at the bottom: a dark skirting
  board, a school's painted lower wall, a gym's wood impact panelling,
  a factory's green dado with a yellow line. They show where the floor
  is even when the floor is out of view.
- **Ceilings** have a pattern nothing else has - timber beams, a 600 mm
  tile grid with lamp panels, skylight strips, gym lamps and trusses -
  and they're the darkest surface except for their lamps.
- Fake ambient occlusion is baked into vertex colors (darker where
  walls meet floor and ceiling), and each wall direction gets its own
  baked brightness, so two walls meeting in a corner never merge.
- The village tunnel and pipe got the same treatment: light floor,
  light concrete walls, dark ceiling (with a lamp line in the tunnel).

## Two bugs only real screenshots caught

Headless testing is great for physics/logic but is blind to anything
visual - `--headless` never starts a real GPU context. Using the preview
tool above surfaced two real bugs no amount of headless testing would
have found:

- The ground rendered almost solid black. Not a lighting bug - the
  ground's `StandardMaterial3D.albedo_color` was still its original flat
  dark green from before it had a texture at all, and `albedo_color`
  *multiplies* with `albedo_texture`. An already-moderate-dark grass
  texture times an already-dark base color crushed it to near-black.
  Fixed by resetting `albedo_color` to white wherever a texture gets
  applied in `main.gd` (buildings/houses had the same latent bug, just
  less visible since their original colors were lighter).
- The tuning panel's debug axis readout, positioned at a fixed y-offset,
  started overlapping the tuning sliders once that panel grew past 14
  rows. Fixed by anchoring it to the top-right corner instead of a
  fixed left-side offset.

## Generated maps

`scripts/maps/`: each map is a script extending `BuiltMap` (sky, fog,
sun, border, `build()`), drawn through `Geo` - boxes, beams, cylinders,
hollow pipes, cones and lathed shapes written straight into one mesh
per material and 64 m cell (a few dozen draw calls for thousands of
pieces), with trimesh collision (hollow things really are hollow), a
shadow outline per piece for the ground shadows, and baked light.
`Terrain` builds chunked heightfields with HeightMapShape3D collision,
`Forest` plants thousands of trees as MultiMeshes with trunk/crown
colliders, `MapTextures` makes rust, concrete, brick, rock and more from
seamless noise, `RaceCourse` adds gates (pillowed fabric panels, white
piping round the opening - the light strip itself on LED gates, dark
panels there instead -, a PVC tube frame, a sponsor patch, weighted
feet or a base plate so nothing floats; `hanging_gate()` hangs one from
roof trusses on wires, any size including whoop) and race timing,
`Vehicles` shapes cars, lorries,
buses, trams, boats, locomotives, intercity trains and freight wagons
like the real thing (sloped bonnets and noses, glass cabins, wheels with
rims, bogies, pantographs), `MapProps` builds houses and small towns. The .tscn holds
only the Drone (its spawn - movable in the editor) and the UI; the map
is registered once in `MapCatalog`.

Things that have to connect are laid out as a `Route` - straights and
circular curves, each piece continuing the last, so nothing kinks - and
extruded with `Geo.sweep`: `Rails` (ballast, sleepers, rails, 1:9
turnouts with frog and check rails, crossovers, buffer stops, signals,
overhead line, trains standing on curved track), `Roads` (junctions,
kerbs and pavements, markings, lamps, parked cars and traffic,
viaducts, whole street grids whose edge streets run out of the map),
pipes with rounded elbows. `City` builds perimeter blocks, towers,
parks, car parks and cheap filler blocks for the far distance; `Fleet`
turns thousands of cars into a few merged meshes per 128 m chunk.
Stacked ground surfaces are ground layers (`shaders/geo_layer.gdshader`)
so they never flicker, and every outdoor map uses depth fog that fades
into the horizon colour just before the view distance - the world has
no visible edge. `SH_PERF=1` prints draw calls and FPS while a
generated map runs.

## Nothing floats

Every solid piece a generated map draws must actually touch the ground
or another piece. `Geo` records the footprint of every primitive it
draws - including non-colliding decoration and the segments of a
`Route` sweep, which both count as support - and `Geo.floating()` /
`BuiltMap.floating_pieces()` lists any solid piece above the ground
that touches nothing (rectangle overlap with 0.15 m of slack, 0.35 m of
vertical tolerance; hanging from something above also counts).
`SH_FLOAT=1` prints them while a map builds, and the self-test checks
every generated map has none. The hand-made scene maps (village,
factory, school) get the same check by mesh bounding box via
`godot --path . -- --dev-preview floatcheck` (see "Previewing it"
above), since they aren't built through `Geo`.

The first pass over the generated maps found 270 flagged pieces, then
375 once sweeps were added to the count - but most were the detector's
own false positives (a roof resting on a non-colliding cornice, a
circle approximated by straight segments reading as a small gap at each
corner); counting non-colliding parts and sweep segments as support and
switching to a rectangle-overlap test cleared those out and left the
real cases, which got fixed: a coke-oven larry car hovering 40 cm
(steel mill), straddle carriers holding containers in mid-air (now with
a spreader and ropes), a ship-to-shore crane's machinery house short of
the girders, a ship's funnel floating above its own deck, a pipe rack
crossbeam that ran along the route instead of across between the posts
(now two crossbeams per frame, the pipes rest on the top one), crane
loads on the construction site with no slings, the village's power-loop
hoop with no stand, and the factory entrance sign hanging 40 cm under
its beam. Every fix was a new node (a stand, a sling, a strap) - nothing
hand-placed was moved.

## Known gaps (before this is really ready for the FPV world)

- No DVR/replay of a flight, physics-tuning sliders exposed to a pilot
  (not just the `O` debug panel), checkpoint-style training challenges,
  signal-loss simulation, structured lesson plans, or
  multiplayer/online leaderboards - a research pass for Act XIV looked
  at what Liftoff, Velocidrone, Uncrashed, DRL and TRYP FPV offer and
  these are the pieces not yet built.
- No prop spin animation or cockpit — the frame itself (arms, motors,
  camera pod, antenna, and ducts on the whoop) is procedural now, but
  the propellers themselves are static discs.
- No Steam/export packaging yet.
- The default axis mapping (before you run the calibration wizard) is
  still an unverified guess for EdgeTX joystick mode - run the wizard
  once with a real radio.

## License

PolyForm Noncommercial 1.0.0 (see `LICENSE`): free to use, study, change and share for
non-commercial purposes; selling it or using it commercially is not allowed.
Contributions welcome.
