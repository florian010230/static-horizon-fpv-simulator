# Static Horizon FPV Sim

A free, open-source FPV drone flight simulator built in [Godot 4](https://godotengine.org)
(free forever, no revenue cap, MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

This is a first playable slice: a small flying park (a textured tower
with a roof, two houses with roofs, a tunnel, three fly-through gates,
and a slalom row of poles) with both Angle (self-level) and Acro flight
modes, live-tunable PID/rates/camera/throttle response, and a
procedurally synthesized motor sound (no audio assets needed). Not a
Betaflight-accurate simulation — a simplified rigid-body model, sized
and weighted to match a real drone (the [DeepSpace Seeker3](https://oscarliang.com/deepspace-seeker3/),
a ~245g 3" freestyle quad) and grounded in Betaflight's real default
rate curve and mode behavior, good enough to feel like flying, and to
build on.

## Requirements

- [Godot 4.x](https://godotengine.org/download) — free, no account needed.
- Optional: an FPV transmitter with USB joystick mode (e.g. RadioMaster
  Pocket). Without one, the sim runs fully on keyboard.

## Running it

1. Install Godot 4.
2. Open Godot -> Import -> select this folder's `project.godot`.
3. Press F5 (or the Play button, top right) to run.

The project is set to the "Compatibility" (GL) renderer by default, which
is the lightest option and runs on old/integrated GPUs. If you have a
decent GPU and want better visuals later, this can be changed in
Project Settings -> Rendering -> Renderer.

## Controls

**Keyboard (no radio needed):**
- `W`/`S` pitch, `A`/`D` roll, `Q`/`E` yaw
- `Shift`/`Ctrl` throttle up/down (holds its value, like a real stick)
- `Enter` arm / disarm
- `L` toggle Angle (self-level) / Acro mode — starts in Angle mode
- `R` reset drone to spawn
- `O` show/hide the tuning panel
- `Esc` quit (the game launches in fullscreen by default)

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

## Project layout

- `scenes/Main.tscn` — the world: ground, a roofed tower, two roofed
  houses, a tunnel, three gates, six slalom poles, the drone, the UI.
- `scenes/Drone.tscn` — the quadcopter: collision shape, visuals, camera
  mount, motor sound, `scripts/drone.gd` (the flight physics).
- `scenes/Gate.tscn` / `scenes/Pole.tscn` — reusable fly-through
  obstacles; instance either one multiple times in `Main.tscn` (with a
  different position/rotation/scale) to add more.
- `scenes/InputManager.tscn` — autoloaded singleton for radio/keyboard
  input and calibration (`scripts/input_manager.gd`).
- `scenes/UI.tscn` — HUD + tuning panel, built at runtime
  (`scripts/ui.gd`).
- `scripts/pid.gd` — small reusable PID controller class.
- `scripts/motor_audio.gd` — procedurally synthesized motor whine (4
  detuned sawtooth oscillators, one per motor, plus tremolo and a touch
  of noise). Rendered ONCE into a short loop at startup (~40ms), then
  pitch/volume follow throttle via native `pitch_scale`/`volume_db` -
  earlier versions synthesized sample-by-sample every frame in GDScript,
  which is a real, measurable CPU cost on weak hardware; this doesn't.
- `scripts/procedural_textures.gd` — generates the grass/brick/siding/
  concrete textures at runtime, so no image assets are needed either.

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
it should: "how many degrees below the horizon do I look when hovering."
Typical real values: 15-30° for beginners/cinematic, 25-35° for
freestyle, 45-60° for racing (higher angle = more forward-tilted cruise
attitude = less of your thrust point straight down, which is also why a
high angle makes throttle feel less twitchy at speed).

## Frame: DeepSpace Seeker3

Mass, arm length, and thrust are set to match a real drone rather than
picked arbitrarily: ~245g flying weight, ~60mm motor arm (3" class), and
a thrust-to-weight ratio of ~7:1 (total thrust ≈ 7× weight) - typical for
a high-KV 4S 3" freestyle build, matching reviewer accounts of the
Seeker3 "ripping" with instant, crisp throttle response. A smaller,
lighter frame has much less rotational inertia than the old 5"-scale
placeholder this used to use, so PID gains were scaled down to match -
same torque now produces a noticeably bigger angular acceleration.

## Known gaps (before this is really ready for the FPV world)

- No crash/damage model or lap timing for the gates yet — flying through
  the frame just collides like any other obstacle, no scoring.
- Single drone, no prop visuals/spin, no cockpit — simple placeholder
  shapes throughout.
- No Steam/export packaging yet.

## License

MIT — do whatever you want with it, contributions welcome.
