# Static Horizon FPV Sim

A free, open-source FPV drone flight simulator built in [Godot 4](https://godotengine.org)
(free forever, no revenue cap, MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

This is a first playable slice: a small flying park (a textured tower,
two houses, three fly-through gates, and a slalom row of poles) with
both Angle (self-level) and Acro flight modes, live-tunable PID/rates/
camera/throttle response, and a procedurally synthesized motor sound
(no audio assets needed). Not a Betaflight-accurate simulation — a
simplified rigid-body model, grounded in Betaflight's real default rate
curve and mode behavior, good enough to feel like flying, and to build on.

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
   on your radio.

The default axis mapping (0=roll, 1=pitch, 2=throttle, 3=yaw) is a
best guess for EdgeTX joystick mode — it has **not yet been verified
against real Pocket hardware**. If you test it, please report back what
worked so the defaults can be fixed for everyone else.

## Tuning

Press `O` in-game for live sliders: acro rate curve (Center Sensitivity /
Max Rate — Betaflight's real defaults, 70/670 deg/s), Angle mode's max
tilt and correction gain, Roll/Pitch/Yaw P/I/D gains, FPV camera tilt
angle, camera FOV, and throttle response curve. Changes apply
immediately, no restart needed.

## Project layout

- `scenes/Main.tscn` — the world: ground, a tower, two houses, three
  gates, six slalom poles, the drone, the UI.
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
  of noise), no audio file needed. Pitch/volume follow throttle.
- `scripts/procedural_textures.gd` — generates the grass/brick/siding
  textures at runtime, so no image assets are needed either.

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

## Known gaps (before this is really ready for the FPV world)

- No crash/damage model or lap timing for the gates yet — flying through
  the frame just collides like any other obstacle, no scoring.
- Single drone, no prop visuals/spin, no cockpit — simple placeholder
  shapes throughout.
- No Steam/export packaging yet.

## License

MIT — do whatever you want with it, contributions welcome.
