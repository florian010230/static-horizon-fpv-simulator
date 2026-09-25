# Static Horizon FPV Sim

A free, open-source FPV drone flight simulator built in [Godot 4](https://godotengine.org)
(free forever, no revenue cap, MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

This is a first playable slice: a proper main menu outside gameplay, and
a small flying park - a textured tower and two houses (with roofs,
windows, and doors), a tunnel, three fly-through gates, a slalom row of
poles, ~80 trees, a sky, distant hills, and an invisible border wall
around the flight zone - with both Angle (self-level) and Acro flight
modes, live-tunable PID/rates/camera/throttle response, an optional
crosshair, and a procedurally synthesized motor sound (no audio or image
assets needed anywhere in the project). Not a Betaflight-accurate
simulation — a simplified rigid-body model, sized and weighted to match
a real drone (the [DeepSpace Seeker3](https://oscarliang.com/deepspace-seeker3/),
a ~245g 3" freestyle quad) and grounded in Betaflight's real default
rate curve and mode behavior, good enough to feel like flying, and to
build on. Deliberately no crash/damage simulation - the drone is a
normal rigid body that collides and tumbles like everything else in the
scene, nothing more.

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
- Shadows are off by default (toggle in the menu's Options — one of the
  more expensive things a weak GPU does; everything still reads fine
  under the ambient + direct lighting alone).
- Physics runs at 60Hz, not higher.
- Trees are instanced with `MultiMeshInstance3D` - ~80 trees (160 mesh
  instances across trunk + foliage) cost exactly 2 draw calls total, not
  160.
- All textures (grass/brick/siding/concrete) are generated once at
  startup (a few tens of ms) rather than loaded from image files.
- Motor sound is a one-time ~40ms pre-rendered loop, not synthesized
  every frame — see `scripts/motor_audio.gd` for why that distinction
  matters on weak hardware specifically.

## Controls

**Keyboard (no radio needed):**
- `W`/`S` pitch, `A`/`D` roll, `Q`/`E` yaw
- `Shift`/`Ctrl` throttle up/down (holds its value, like a real stick)
- `Enter` arm / disarm
- `L` toggle Angle (self-level) / Acro mode — starts in Angle mode
- `R` reset drone to spawn
- `O` show/hide the tuning panel
- `Esc` return to the main menu (the game launches in fullscreen by
  default — toggle that, the crosshair, and shadows from the menu's
  Options)

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
  `run/main_scene`). Play / Options (fullscreen, crosshair, shadows) /
  Quit, built at runtime (`scripts/main_menu.gd`) - flat 2D UI only, no
  3D scene behind it, so it's essentially free to render.
- `scenes/Main.tscn` — the flying park: ground, sky, a roofed/windowed/
  doored tower, two roofed/windowed/doored houses, a tunnel, three
  gates, six slalom poles, ~80 trees, 8 distant hills, an invisible
  border wall, the drone, the UI.
- `scenes/Drone.tscn` — the quadcopter: collision shape, visuals, camera
  mount, motor sound, `scripts/drone.gd` (the flight physics).
- `scenes/Gate.tscn` / `scenes/Pole.tscn` — reusable fly-through
  obstacles; instance either one multiple times in `Main.tscn` (with a
  different position/rotation/scale) to add more.
- `scenes/InputManager.tscn` — autoloaded singleton for radio/keyboard
  input and calibration (`scripts/input_manager.gd`).
- `scripts/settings.gd` — autoloaded singleton holding options that
  need to survive the menu <-> gameplay scene change (crosshair,
  shadows, fullscreen).
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
  siding+window/concrete textures at runtime, so no image assets are
  needed either. Doors are separate small quads (`main.gd`), since a
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

## The world: bounded but not obviously so

The 500x500 flat play area (where the gates/tunnel/buildings are
calibrated) is ringed by an invisible-ish (faint, semi-transparent)
collider wall at ±230. Past that, 8 large flattened spheres stand in as
distant hills out to ±280-ish, under a real sky (`ProceduralSkyMaterial`,
cheapest radiance/process settings), so the world reads as continuing
past where you can actually fly rather than visibly stopping at a wall -
"you can see the edge of the map, but you can't fly into it," same idea
as the boundary in most FPV/racing sims.

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
