# Static Horizon FPV Sim

A free, open-source FPV drone flight simulator built in [Godot 4](https://godotengine.org)
(free forever, no revenue cap, MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

This is a first playable slice: a main menu (with a small live 3D
preview of the drone hanging off a wall hook, and a procedurally-drawn
"Static Horizon" wordmark - no image assets) that lets you pick between
**two maps** - a small flying park (a little Wohngebiet with a tower and
two houses you can actually fly *into*, each with a real punched-open
door and window and a wall splitting the inside into two rooms; a
street with curbs and a dashed centerline; an FPV field with a tunnel,
three fly-through gates, a slalom row of poles, a ring "loop" gate, and
a fly-through pipe; two in-map hills; 80 individually-placed,
individually-movable trees; distant backdrop hills; an invisible border
wall) and a factory yard (big fly-through halls, tall lattice masts with
warning lights, and large pipes strung between them, under a hazier
industrial sky) - with both Angle (self-level) and Acro flight modes
(Acro by default), live-tunable PID/rates/camera/throttle response, a
menu with real settings (fullscreen, crosshair, shadows, max FPS, and
persisted Acro rates), and a procedurally synthesized motor sound (no
audio or image assets needed anywhere in the project). Not a Betaflight-accurate
simulation — a simplified rigid-body model, sized/weighted/geared to
match a real drone (the [DeepSpace Seeker3](https://oscarliang.com/deepspace-seeker3/),
a ~245g 3" freestyle quad with a claimed 150 km/h top speed) and
grounded in Betaflight's real default rate curve and mode behavior,
good enough to feel like flying, and to build on. Deliberately no
crash/damage simulation - the drone is a normal rigid body that
collides and tumbles like everything else in the scene, nothing more.

## Previewing it

There's no way to get an actual rendered screenshot in headless mode -
`--headless` never starts a real GPU context. `scripts/dev_preview_capture.gd`
is a tiny dev tool (registered as an autoload, but does nothing at all
unless invoked) that automates a real windowed run and saves screenshots:

```
godot --path . -- --dev-preview
```

Needs a real display (it's genuinely playing the game for a few seconds,
just moving the camera around and taking screenshots), and it isn't
headless-compatible. Saves several `previews/preview_*.png` shots -
menu, settings, village gameplay/topdown, inside/outside a house, and
factory overview/hall/topdown - each from a frozen debug camera dropped
at a fixed spot. That folder has a `.gdignore` so Godot doesn't treat
the screenshots as game assets, and it's gitignored too, since they go
stale the moment the map changes - regenerate anytime.

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
- Shadows are off by default (toggle in the menu's Settings — one of the
  more expensive things a weak GPU does; everything still reads fine
  under the ambient + direct lighting alone).
- Physics runs at 60Hz, not higher.
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
- Motor sound is a one-time ~40ms pre-rendered loop, not synthesized
  every frame — see `scripts/motor_audio.gd` for why that distinction
  matters on weak hardware specifically.
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

## Controls

**Keyboard (no radio needed):**
- `W`/`S` pitch, `A`/`D` roll, `Q`/`E` yaw
- `Shift`/`Ctrl` throttle up/down (holds its value, like a real stick)
- `Enter` arm / disarm
- `L` toggle Angle (self-level) / Acro mode — starts in **Acro**
- `R` reset drone to spawn
- `O` show/hide the tuning panel
- `Esc` return to the main menu

The menu has a **Settings** button: fullscreen, crosshair, shadows, a
max FPS slider (50 up to "Unlimited" — drag it all the way right), and
Acro Rates (Center Sensitivity / Max Rate) - set your preferred feel
once and it's what a freshly spawned drone starts from every flight,
rather than re-tuning it every time via the in-flight `O` panel.
**Play** leads to a map choice: **Village** or **Factory**.

**RadioMaster Pocket (or any radio in USB Joystick mode):**
1. Plug in via USB-C. On the Pocket, make sure USB mode is set to
   "Joystick" (EdgeTX: on boot, choose the Joystick USB mode, or set it
   under System -> Hardware).
2. Launch the sim. It auto-detects the first connected joystick and
   switches off the keyboard fallback.
3. Press `O` to open the tuning panel — it shows live raw axis values
   for the connected device at the bottom.
4. Move one stick at a time and note which "axis N" value changes. Open
   `scenes/InputManager.tscn` in Godot, select the `InputManager` node,
   and set `axis_roll` / `axis_pitch` / `axis_throttle` / `axis_yaw` in
   the Inspector to match. Save the scene.
5. If a control moves the opposite way you expect, tick the matching
   `invert_*` box on the same node.
6. Arm with `Enter`, or configure `arm_button_index` to match a switch
   on your radio. Arming is blocked while throttle reads above ~8%
   (`arm_throttle_safety_threshold`), same as a real flight controller —
   this exists specifically so a throttle stick that wasn't left at idle
   can't cause a surprise spin-up the instant you arm.

The default axis mapping (0=roll, 1=pitch, 2=throttle, 3=yaw) is a
best guess for EdgeTX joystick mode — it has **not yet been verified
against real Pocket hardware**. If you test it, please report back what
worked so the defaults can be fixed for everyone else.

**If a control drifts or fires on its own with nothing touched:** open
the `O` panel and check the device name/axis values shown there first.
Godot can enumerate a joystick that's technically connected but not
actually being held/flown (including the Pocket itself, sitting idle),
and a raw axis reading of exactly `0.0` on a "centered -1..1" channel
gets read as 50% on that channel (e.g. 50% throttle) — this is also
exactly why the arm-safety check above exists. Raising `deadzone` (now
0.06 by default) helps if a stick shows small persistent drift instead
of a true 0.

## Crashing into things

Tested this directly (headless, a drone launched at 25 m/s into a wall,
logging position/velocity every physics frame): the collision itself is
clean — velocity drops close to zero in a single step, a modest angular
kick that damps out fast, no explosive bounce. Two things can still look
"strange" after a hard crash:

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

Default gains were pushed noticeably snappier in this pass, which only
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
  `run/main_scene`). A small live `SubViewport` preview (the drone model
  hanging off a wall hook, slowly turning) and a procedurally-drawn logo
  sit above Play (-> map choice: Village/Factory) / Settings (fullscreen,
  crosshair, shadows, max FPS, Acro rates) / Quit, all built at runtime
  (`scripts/main_menu.gd`) - the menu itself stays flat 2D UI, so the
  tiny 3D preview is the only real rendering cost added.
- `scenes/Main.tscn` — the village: ground, sky, a Wohngebiet (roofed
  tower + two fly-into houses with rooms, street with curbs and a
  dashed centerline, sidewalks), an FPV field (tunnel, pipe, three
  gates, a ring loop, six slalom poles), two in-map hills, 80 trees, 8
  distant backdrop hills, an invisible border wall, the drone, the UI.
  `scripts/main.gd` applies its procedural textures.
- `scenes/Main2.tscn` — the factory yard: a concrete ground, three big
  `HollowBuilding` halls with floor-to-ceiling openings on opposite
  walls (straight fly-throughs), three tall lattice masts
  (`scenes/Mast.tscn`) with a warning light on top, two large pipes
  strung between them, the same border-wall pattern as the village, a
  hazier/grayer sky. `scripts/main2.gd` applies its textures.
- `scripts/hollow_building.gd` (`HollowBuilding`, a `StaticBody3D`) —
  the reusable primitive behind both fly-into buildings: a floor,
  ceiling, and four walls, each independently punchable with a single
  rectangular opening (door/window - width 0 leaves that wall solid),
  plus an optional full-height interior partition. `scenes/SmallHouse.tscn`
  configures it as a house (one door, one window, a partition splitting
  it into two rooms, a peaked roof); `Main2.tscn`'s halls configure it
  as a big hangar (openings on opposite walls, no partition).
- `scenes/Tree.tscn` — a single low-poly tree (trunk + foliage, no
  collision); `Main.tscn` instances it 80 times at fixed, hand-tweakable
  positions/scales.
- `scripts/dev_preview_capture.gd` — dev-only screenshot tool, see
  "Previewing it" above.
- `scenes/Drone.tscn` — the quadcopter: collision shape (a small sphere,
  not a thin box - see Performance above), visuals, camera mount, motor
  sound, `scripts/drone.gd` (the flight physics).
- `scenes/Gate.tscn` / `scenes/Pole.tscn` — reusable fly-through
  obstacles; instance either one multiple times in `Main.tscn` (with a
  different position/rotation/scale) to add more.
- `scenes/InputManager.tscn` — autoloaded singleton for radio/keyboard
  input and calibration (`scripts/input_manager.gd`).
- `scripts/settings.gd` — autoloaded singleton holding options that
  need to survive the menu <-> gameplay scene change (crosshair,
  shadows, fullscreen, max FPS, Acro rates).
- `scenes/UI.tscn` — HUD, crosshair, and tuning panel, built at runtime
  (`scripts/ui.gd`).
- `scripts/pid.gd` — small reusable, D-term-filtered PID controller
  class.
- `scripts/motor_audio.gd` — procedurally synthesized motor whine (4
  detuned sawtooth oscillators, one per motor, plus tremolo and a touch
  of noise). Rendered ONCE into a short loop at startup (~40ms), then
  pitch/volume follow throttle via native `pitch_scale`/`volume_db` -
  earlier versions synthesized sample-by-sample every frame in GDScript,
  which is a real, measurable CPU cost on weak hardware; this doesn't.
- `scripts/procedural_textures.gd` — generates the grass/brick+window/
  siding+window/concrete/asphalt textures at runtime, so no image assets
  are needed either. Doors are separate small quads (`main.gd`), since a
  door is one-off, not something that should tile.

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

## Frame: DeepSpace Seeker3

Mass, arm length, and thrust are set to match a real drone rather than
picked arbitrarily: ~245g flying weight, ~60mm motor arm (3" class), and
a thrust-to-weight ratio of ~7:1 (total thrust ≈ 7× weight) - typical for
a high-KV 4S 3" freestyle build, matching reviewer accounts of the
Seeker3 "ripping" with instant, crisp throttle response. A smaller,
lighter frame has much less rotational inertia than the old 5"-scale
placeholder this used to use, so PID gains were scaled down to match -
same torque now produces a noticeably bigger angular acceleration.

**Top speed is calibrated to the Seeker3's claimed 150 km/h**, which
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

## The world: bounded but not obviously so

The 500x500 flat play area (where the gates/tunnel/buildings are
calibrated) is ringed by an invisible-ish (faint, semi-transparent)
collider wall at ±230. Past that, 8 large flattened spheres stand in as
distant hills out to ±280-ish, under a real sky (`ProceduralSkyMaterial`,
cheapest radiance/process settings), so the world reads as continuing
past where you can actually fly rather than visibly stopping at a wall -
"you can see the edge of the map, but you can't fly into it," same idea
as the boundary in most FPV/racing sims.

Two smaller hills (`HillNear1`/`HillNear2`, around (-70, 20) and
(85, -90)) sit inside the actual flight zone, with real collision this
time - unlike the 8 backdrop hills, which are unreachable, these are
meant to be flown around/over.

## Layout

- **Wohngebiet** around (-15..55, 82): the tower and two houses, facing
  a street that runs east-west at z=70 with curbs, a dashed centerline,
  and sidewalks bridging each door to it. Each house's front wall has a
  real door-shaped opening and a side wall has a real window opening -
  both fly-through, not decorative - with a partition wall splitting the
  inside into two rooms. The street continues out past the houses
  toward the denser tree line - "a road out of the neighborhood into the
  forest."
- **FPV field** around (5..35, 45..70): the slalom poles, plus a ring
  loop gate and a small square-ish "pipe" tunnel, near the three square
  gates further out.
- The 80 trees are hand-positioned (`Main.tscn`) to stay clear of both
  areas above.

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

## Known gaps (before this is really ready for the FPV world)

- No lap timing/scoring for the gates yet — flying through the frame
  just collides like any other obstacle.
- Single drone, no prop visuals/spin, no cockpit — simple placeholder
  shapes throughout.
- No Steam/export packaging yet.
- Radio axis mapping still needs verification against real Pocket
  hardware (see Controls above).

## License

MIT — do whatever you want with it, contributions welcome.
