# Static Horizon FPV Sim

A free, open-source FPV drone flight simulator built in [Godot 4](https://godotengine.org)
(free forever, no revenue cap, MIT-licensed engine). Built to run on weak
hardware (4GB RAM, integrated graphics) and to fly with real FPV radios —
starting with the RadioMaster Pocket — over USB.

This is a first playable slice: one drone, one building, a rate-mode
("acro") flight model with live-tunable PID gains and an adjustable FPV
camera angle. Not a Betaflight-accurate simulation — a simplified rigid-body
model good enough to feel like flying, and to build on.

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
- `R` reset drone to spawn
- `O` show/hide the tuning panel

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

Press `O` in-game for live sliders: Roll/Pitch/Yaw P, I, D gains, and the
FPV camera tilt angle. Changes apply immediately, no restart needed.

## Project layout

- `scenes/Main.tscn` — the world: ground, one building, the drone, the UI.
- `scenes/Drone.tscn` — the quadcopter: collision shape, visuals, camera
  mount, `scripts/drone.gd` (the flight physics).
- `scenes/InputManager.tscn` — autoloaded singleton for radio/keyboard
  input and calibration (`scripts/input_manager.gd`).
- `scenes/UI.tscn` — HUD + tuning panel, built at runtime
  (`scripts/ui.gd`).
- `scripts/pid.gd` — small reusable PID controller class.

## How the flight model works

Each stick sets a target **angular rate** per axis (roll/pitch/yaw), same
idea as acro/rate mode on a real flight controller — not a target angle.
A PID loop per axis compares that target rate to the drone's actual
angular velocity and outputs a correction. Roll/pitch corrections are
mixed into 4 virtual motor thrusts (front/back, left/right) applied at
their real positions on the frame, so roll and pitch torque emerge from
the physics rather than being faked. Yaw is applied as a direct reaction
torque, since a purely vertical thrust force can't produce torque around
the vertical axis by itself (only a spinning prop's drag can) — modelling
that individually per motor isn't worth the complexity for now.

## Known gaps (before this is really ready for the FPV world)

- Radio axis defaults are unverified against real hardware.
- No crash/damage model, no race track or gates, no sound.
- Single drone, single building — no variety yet.
- No Steam/export packaging yet.

## License

MIT — do whatever you want with it, contributions welcome.
