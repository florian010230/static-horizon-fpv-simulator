# Static Horizon FPV Sim — Development Log

This is raw material for a blog post, not the blog post itself. It's a
chronological record of what got built, what broke, what the actual
root causes turned out to be, and how each fix was verified — pulled
straight from the project's commit history (every commit message in
this repo is written as a small devlog entry already) plus a few notes
that never made it into a commit message. `README.md` is the *current
state* reference (how to run it, how it works right now); this file is
the *story* of how it got there.

Everything below is factual and traceable to a specific commit
(`git log --oneline` for the short version, `git show <hash>` for the
full message). Dates are real commit dates.

## The elevator pitch

A free, open-source FPV drone flight simulator, built in [Godot
4](https://godotengine.org) instead of Unity specifically so it stays
free forever with no revenue cap, runs on weak hardware (4GB RAM,
integrated graphics), and takes input from a real FPV radio
(RadioMaster Pocket) in USB joystick mode — no dongle, no proprietary
sim receiver. Zero external art or audio assets: every texture is
generated in code at startup, the motor sound is synthesized, the logo
is drawn with GDScript `draw_*` calls. Built almost entirely in one
extended AI-pair-programming session (Claude Code) across 2026-09-25
and 2026-09-26 — 13 commits, each one a self-contained problem →
investigation → fix → verification cycle.

## Origin constraints (the "why" behind most decisions)

These were fixed from the start and explain a lot of the choices below:
- **Free, forever, for anyone** → Godot over Unity (MIT-licensed, no
  seat/revenue-based licensing).
- **Runs on weak hardware** → drove the renderer choice
  (`gl_compatibility`), the 60Hz physics/render cap, shadows-off
  default, procedural (not loaded) textures and audio, and later, real
  node instances instead of a black-box `MultiMeshInstance3D` for
  trees, in exchange for being editable.
- **Real FPV radios, not just keyboard** → RadioMaster Pocket in USB
  joystick mode, with in-sim axis calibration and arm-safety logic
  matching how a real flight controller behaves.
- **Feels like flying, not arcade physics** → every "make it feel more
  real" pass grounded itself in a specific real reference: Betaflight's
  actual default rate curve, a specific real drone's mass/thrust/drag
  (the DeepSpace Seeker3), real camera-angle conventions from
  beginner/freestyle/racing setups.

## Timeline

### Act I — First flight (2026-09-25)

**1. Initial playable slice** (`4f34082`)
One drone, one building, a tunable rate-mode PID quadcopter model, live
PID/camera tuning UI, keyboard + radio input with on-screen axis
calibration. Godot chosen up front for Steam eligibility and reliable
HID joystick input.

**2. Fix pitch-black scene** (`3120869`)
First real bug: the scene rendered almost entirely black. Not a sun
angle problem — Godot has *zero* ambient light by default, so anything
not directly facing the sun was rendering unlit. Added a
`WorldEnvironment` with ambient light. Also lowered default rates
(500/250 → 300/180 deg/s) so a first flight was actually flyable, and
verified the roll/pitch torque math against the engine's real
`apply_force`/`apply_torque` semantics via a throwaway headless test —
concluding the physics model itself was already correct and any
remaining weirdness was more likely radio calibration.

**3. Fix inverted controls, camera self-clipping, narrow FOV** (`5b016f0`)
The FPV camera mount sat *inside* the drone's own collision box, so the
near clip plane was slicing through the drone's own geometry — showing
up as stray triangles filling the view. Moved the camera clearly
forward of the body. Also fixed roll/pitch inversion (matched to how
the RadioMaster Pocket actually reports its axes) and dropped FOV from
130→100 (130 with no fisheye correction just looks stretched).

**4. Fix yaw inversion, throttle curve, first gate** (`c6e61d2`)
Yaw needed the same inversion fix as roll/pitch. Added a throttle
response curve (`throttle_curve`, stick raised to a power before
scaling to thrust) to give more resolution around hover instead of
cramming it into a sliver of stick travel. Added the first fly-through
obstacle: a simple orange gate with real box colliders.

### Act II — Flying like a real machine (2026-09-25)

**5. Fullscreen, procedural motor sound, bigger course** (`3b1592b`)
Fullscreen launch (with an Esc-to-quit binding, since a borderless
fullscreen window otherwise has no obvious way out). First version of
the motor sound: two detuned sawtooth oscillators via
`AudioStreamGenerator`, no audio file anywhere. Refactored the gate into
a reusable `Gate.tscn`/`Pole.tscn` pair for cheap obstacle-course
expansion.

**6. Angle mode, real Betaflight rate curve, textures** (`ecaa893`)
Researched actual FPV behavior before touching any numbers: Betaflight's
real default "Actual Rates" (Center Sensitivity 70 deg/s, Max Rate 670
deg/s, soft-center/steep-edge), and real camera-angle conventions
(15–30° beginner, 25–35° freestyle, 45–60° racing). Root-caused "camera
angle feels weird" correctly: the sim only had Acro mode, which has no
attitude reference, so the drone kept whatever tilt it drifted to and
camera angle compounded on top of that unpredictably — which is exactly
why every real flight controller defaults beginners to self-leveling.
Added Angle mode as the new default (outer P-loop on tilt → target
rate → the existing inner rate PID, the same cascade a real FC uses).
Also added the first procedural textures (grass/brick/siding) and a
richer 4-oscillator motor sound.

**7. Real CPU cost fix, real safety gap, match a real drone** (`ed7e3f5`)
Two "the computer strains hard" / "it rolls with no input" reports,
both investigated empirically instead of guessed at:
- The motor sound was synthesizing audio sample-by-sample in GDScript
  at 22050Hz *every frame* — a real, continuous CPU cost directly
  fighting the weak-hardware target. Replaced with a one-time ~40ms
  pre-rendered loop; pitch/volume now ride native `pitch_scale`/
  `volume_db`, effectively free per frame.
- The "rolls with no input" bug wasn't in the control loop at all (both
  self-level convergence and a perfectly-level idle drone tested clean
  headlessly). The real gap: `Input.get_connected_joypads()` can report
  a joystick as connected before its axes have reported any live data,
  and an unset "centered -1..1" throttle axis reads as `0.0` — which a
  centered channel remaps to 50% throttle. Nothing stopped arming at
  that point. Fixed by adding the same safety a real flight controller
  has: refuse to arm unless throttle reads near zero.

Also swapped the drone's specs from an arbitrary placeholder to a real
reference: the [DeepSpace Seeker3](https://oscarliang.com/deepspace-seeker3/)
(~245g, ~60mm arm, 3" class), with thrust-to-weight tuned to a verified
exact 7.00:1.

### Act III — A world worth flying in (2026-09-25)

**8. Flip camera angle direction** (`88254ab`)
Direct testing feedback: tilt direction was just a sign convention, not
a physics fact. Flipped it.

**9. Snappier PID, main menu, crosshair, bigger world** (`d3dc3a2`)
The "make the PID snappier" ask initially caused sustained spin-outs
when gains were naively scaled up. Frame-by-frame headless
testing — deliberately *not* multi-frame sampling, which was aliasing
the problem into looking like a false steady state — showed angular
velocity flipping sign every single physics step: textbook D-term noise
amplification, and this project's `PIDController` had never filtered
its derivative term. Added a low-pass filter on the D-term
(`d_filter_alpha`); only after that fix were higher gains actually
safe, and they ended up converging faster *and* tighter with no
oscillation. Also added the first real main menu (flat 2D, so
effectively free to render), a crosshair, dropped physics from 120Hz to
60Hz, and grew the world (sky, 8 distant backdrop hills beyond an
invisible border wall, ~80 `MultiMeshInstance3D` trees, baked-in window
textures).

**10. Fix undersized hills, fake shadows in the tunnel texture** (`b728504`)
Small but instructive bug: `SphereMesh` defaults to radius 0.5, not
1.0 — the hills had been sized purely by node scale without knowing
that, so they rendered at half the intended size. Also gave the tunnel
texture baked-in AO gradients and per-surface tint (floor brightest,
ceiling darkest) to fake directional shading, since shadows are off by
default on this hardware target.

### Act IV — Ready for a village (2026-09-25)

**11. Real crash/collision robustness, a screenshot tool, village rebuild** (`f668055`)
Investigated "drone behaves strangely after crashing" the same way as
every other bug in this project: logged position/velocity/angular
velocity every physics frame through a 25 m/s wall collision. The
impact itself was already clean. What actually looked strange
afterward was a *realistic* behavior, not a bug: an armed, self-leveling
drone resting against something keeps trying to fly back to level
forever, showing up as a slow reaccelerating spin — exactly what a real
armed quad wedged against a wall does, which is why real pilots disarm
immediately after a crash. Turned on `continuous_cd` regardless, since
a fast small body can genuinely tunnel through thin geometry for a step
or two at 60Hz without it.

Also built `scripts/dev_preview_capture.gd` — the first way to actually
*see* the game, since `--headless` never starts a real GPU context.
This immediately paid for itself by catching two bugs headless testing
structurally could never find: the ground rendering near-solid-black
(`albedo_color` was still its original dark-green default, and
`StandardMaterial3D.albedo_color` *multiplies* with `albedo_texture` —
an already-dark texture times an already-dark base color crushes to
near-black), and a debug readout overlapping the tuning panel once it
grew past 14 rows.

Rebuilt the scattered props into an actual small village: a proper
Wohngebiet with sidewalks bridging each door to the street, a ring
"loop" gate, a small pipe tunnel, two in-map hills with real collision.

**12. Fix upside-down spin, real 150 km/h top speed, Acro default** (`c55ba21`)
The best bug of the project so far. "If the drone is upside down, it
can spin" turned out to be a genuine math blind spot: Angle mode
extracted roll/pitch as separate angles using `asin()`, and
`asin(sin(x))` *folds* anything past 90° back down — so a drone tilted
178° (nearly inverted) read as only ~2° off. The controller applied a
tiny correction when it needed a huge one, and as the true angle kept
changing, the misread swung non-monotonically — reads exactly like
"spinning for no reason" from the cockpit. Fixed by comparing the
body's actual up vector against the target up vector directly
(cross/dot product), which has no such blind spot short of the one true
180° singularity every attitude representation shares. A frame-by-frame
headless test at 178° roll went from "still not settled at t=1.0s" to
"settled by 0.6–0.8s, correcting at full strength from frame one."

Also fixed an unrealistic top speed: the drone was still accelerating
past 470 km/h after 10 simulated seconds and hadn't leveled off,
because `RigidBody3D.linear_damp` barely slows a body like this down at
all. Real air resistance is roughly quadratic in speed, not linear —
added that directly (`drag_coefficient`, `F = k·v²`) and zeroed
`linear_damp`. Calibrated `k` against the Seeker3's claimed 150 km/h;
the same dive test now converges cleanly to 149.9 km/h and holds. Acro
became the new default mode; Settings menu gained a Max FPS slider.

### Act V — Doubling down (2026-09-26)

**13. Crash-proofing round 2, movable trees, fly-into houses, a factory map** (`bcc96e2`)
The biggest single commit — one user request with eight distinct
deliverables, all landed together:

- **Crash-proofing, for real this time.** The drone's collision shape
  was a very thin box (4.5cm tall). Godot's continuous collision
  detection is known to struggle with thin shapes on the *moving* body
  specifically, and a flat box can present a near-zero cross-section to
  a wall at certain tumble angles. Swapped it for a small sphere (no
  thin axis to exploit at all), added a physics material, and — as a
  hard safety net — clamped linear/angular velocity to a generous
  ceiling. That clamp exists because of a very specific measurement: a
  tumbling corner hit could spike angular velocity to **~2234 deg/s**
  for a single physics step, which is what "going haywire after a
  crash" actually was, with no real clipping involved at all. Verified
  with three separate stress scenarios (straight wall hit at 150 km/h,
  angled tumbling corner hit, a hit exactly on the seam between two
  wall segments) — no tunneling in any of them, and the clamp visibly
  engaging within one step.
- **80 trees, now real and movable.** Replaced the `MultiMeshInstance3D`
  tree field with 80 individually-placed `Tree.tscn` instances at the
  exact same baked positions/scales — same visual result, but now real
  editable nodes.
- **A better street.** Procedural asphalt texture, raised curbs, a
  dashed centerline.
- **Houses you can actually fly into.** Built `HollowBuilding`, a
  reusable primitive (floor, ceiling, four walls, each independently
  punchable with a rectangular opening, plus an optional interior
  partition) — one class, two very different-looking uses. The village
  houses got a real door, a real window, and a two-room interior;
  verified this one specifically via real screenshots
  (`previews/preview_house_outside.png`, `preview_house_inside.png`),
  since "does it visually read as a room" isn't something a headless
  node-count check can confirm.
- **A whole second map.** A factory yard reusing the same
  `HollowBuilding` primitive at a much bigger scale (three big
  fly-through halls, no partitions, floor-to-ceiling openings on
  opposite walls), plus three lattice masts with warning lights, two
  connecting pipes, and a hazier industrial sky. Play now opens a
  Village/Factory choice.
- **A real main menu.** A small live `SubViewport` preview (the drone
  model hanging off a wall hook, slowly turning) and a
  procedurally-drawn "Static Horizon" wordmark, both built at runtime
  with zero image assets.
- **Persisted Acro Rates.** Center Sensitivity / Max Rate moved into
  the Settings menu, so a preferred feel survives between flights
  instead of living only in the in-flight debug panel.

### Act VI — A second real drone and a menu that looks like the brand (2026-09-26)

Another single multi-part request, landed together (not yet committed at
the time this entry was written - see `git log` for whether it has
landed since):

- **A real second drone, not a reskin.** `Drone.PROFILES` now holds two
  complete frames - Seeker3 and a new **Tiny Whoop** - each with its own
  mass, arm length, thrust, drag, and PID gains, switched via
  `Drone.apply_profile()`. The whoop's numbers were researched (sub-75mm
  whoops: 18-28g, 1S, 0802-1002 motors, ~40mm props, built for agility
  and indoor safety rather than speed) rather than guessed, using the
  same drag-derivation formula as the Seeker3's own top-speed
  calibration. Moving from the Seeker3's 245g/60mm frame to 25g/23mm
  drops rotational inertia by roughly 65× (`mass * arm_length^2`), so
  PID gains started scaled down by that same factor and were then
  *verified*, not just calculated, with the project's usual
  frame-by-frame headless disturbance-recovery test on both frames.
- **Both drones stopped looking like a brick.** `DroneFrameBuilder` (new)
  builds a real quad silhouette from primitives - a center stack, 4 arms,
  4 motor bells, 4 semi-transparent prop discs, and (whoop only) a
  `TorusMesh` prop guard around each motor - shared between the actual
  flying `Drone` and the menu's preview stand-in, so one class serves
  both drones in both places instead of two hand-built, hand-maintained
  models. First version was broken in a way that's a good lesson on its
  own: the arm meshes were oriented with `look_at_from_position()`, which
  works in *global* space - fine for the real Drone (which usually spawns
  near-level) but silently wrong for the tilted menu preview, and would
  have gone wrong for the real drone too the moment it tumbled mid-flight.
  Fixed by switching to `Basis.looking_at()`, which takes a direction
  rather than a world position and so stays correct in the parent's local
  space regardless of that parent's own rotation - the same category of
  bug as the factory map's hand-derived pipe transforms, this time caught
  by an actual screenshot showing motors floating with no visible arms
  at all, rather than by re-deriving the matrix by hand in advance.
- **The menu was actually rendering at half size.** Investigated "the
  menu is really small" empirically rather than just bumping numbers:
  this machine's display is HiDPI (a 2880x1800 real framebuffer behind a
  much lower logical/OS resolution), and Godot renders 2D UI in raw
  framebuffer pixels by default with no awareness of that distinction -
  every menu and HUD element had likely been rendering at roughly half
  its intended apparent size on this specific machine from the very
  first version of the menu onward, not just since the last pass.
  Confirmed with a real screenshot at each step. Fixed at the project
  level (`window/stretch/mode="canvas_items"`, a 1600x900 reference
  resolution) rather than by further inflating pixel values, since that
  scales correctly across whatever the actual display turns out to be
  instead of guessing one target size - and it fixed the in-flight HUD's
  sizing too, for free, since it uses the same Control-based UI system.
  On top of that fix, the menu's own panel width, fonts, and button
  sizes were still increased directly, and one panel (Settings, now
  taller with the new rate-curve graph) needed its vertical position
  nudged up after a real screenshot showed its Back button rendering
  just past the bottom edge.
- **The real brand, not an invented one.** The user pointed at a
  sibling local project - a real static website for "Static Horizon
  FPV," reviews-and-tutorials content, not just a name - and its actual
  logo: an artificial-horizon instrument (sky/ground split circle, a
  horizon line, an outer ring, a center dot, and two flanking "wing"
  dashes, exactly like a real aircraft attitude indicator) plus an Oswald
  600 wordmark, uppercase, skewed -10 degrees. The font file was
  converted locally from the site's own `oswald-600.woff2` to a `.ttf`
  (Godot's `FontFile` doesn't load WOFF2), and both the logo mark and the
  skewed wordmark were redrawn by hand in the menu (`Control.draw` +
  `Transform2D` shear, the same custom-draw idiom this project already
  used for the crosshair) to match the real site pixel-for-concept
  rather than approximate it.
- **The rate settings now look like Betaflight's.** Added a small
  "Rate Curve Preview" panel next to the Acro Rates sliders, styled after
  Betaflight Configurator's own Rate Profile Settings tab (dark plot,
  cross-hair origin, a curve from 0-100% stick to 0-max deg/s) - and
  actually accurate, not just decorative, since it's plotted with the
  exact same cubic curve formula `Drone._actual_rate()` uses to fly.
- **A standing instruction, not a one-off fix.** The user asked that
  future edits stop silently repositioning anything they've manually
  moved in the Godot editor (trees, houses, etc. were deliberately made
  into real movable nodes specifically so this is possible) - recorded
  as a standing rule for every future session, not just followed once
  here.

### Act VII — Real sites, a real border, and a real calibration wizard (2026-09-26)

The biggest single turn so far, by scope: three maps redesigned/added,
a new shared world-boundary mechanic, and an actual radio calibration
flow, all in one request. Landed together, same as Act VI:

- **The factory stopped being three interchangeable sheds.** Redesigned
  around an actual site plan: an entrance gate/sign where the drone
  spawns, a real road network (a Main Road forking to a Warehouse Road)
  connecting the entrance to every building instead of open ground, an
  Office near the gate, a Main Production Hall and a secondary Assembly
  building (the existing halls, now with an actual role), a Warehouse
  fed by a rail spur (two collidable rail beams, 37 sleeper props
  generated by a throwaway Python script and pasted in as baked nodes -
  the same "generate the repetitive transforms, bake them as real
  nodes" approach as the tree conversion in Act V), a raised loading
  dock, two parked boxcars, two banded storage tanks, and two banded
  chimneys. The ground itself got a new `factory_ground_texture()`
  (expansion-joint grid lines plus randomized oil-stain blotches)
  instead of a flat gray plane.
- **A hand-derived transform bug, caught immediately by the pattern that
  exists specifically to catch it.** The three hula-hoop gates in the
  new school map were first written with a hand-picked `Transform3D`
  matrix that looked plausible but was actually a rotation about the
  wrong axis - a mistake made *while writing a code comment explaining
  why `DroneFrameBuilder` avoids exactly this kind of hand-derived
  matrix*. Caught by re-deriving the rotation properly (which world axis
  a local axis maps to under a given rotation, checked via the
  determinant) rather than trusting the first guess - the same category
  of bug as the factory map's pipe transforms in Act V, and a reminder
  that writing the lesson down doesn't automatically prevent repeating
  it under time pressure.
- **A third map, indoor and whoop-only.** A school (Gym -> Hallway ->
  Classroom) built from the same `HollowBuilding` primitive as the
  houses and factory halls, this time configured as three rooms whose
  doorways are positioned to align across separate StaticBody3D
  instances into one connected indoor space - no sky, no ground plane,
  just flat ambient light, since the rooms fully enclose the play area.
  Always forces the Tiny Whoop profile on entry regardless of the menu's
  drone choice, since flying a 245g freestyle quad through a school
  hallway isn't really an option. A basketball hoop (a horizontal ring,
  authentically flown through by diving from above rather than straight
  through) and three vertical hula-hoop gates lean into the "hoops for
  a Tiny Whoop" pun the map concept was chosen for.
- **The border stopped being a wall and became a distance check.** The
  village and factory's semi-transparent solid collision walls at ±230
  are gone - `scripts/world_border.gd` (`WorldBorder`, a static-method
  utility, not a node) is called once a frame from every map's own
  `_process()` instead, checking horizontal distance and altitude
  against a warning threshold (pulses a HUD message) and a reset
  threshold (`get_tree().reload_current_scene()`). This was a deliberate
  reframing, not just a technical swap: the maps were already
  *decorated* to look endless (distant hills, big sky) while being
  physically walled off a little inside that decoration - now there
  really is no physical edge until well past where the illusion would
  have broken down anyway.
- **Radio calibration became a wizard instead of a spec sheet.** Before
  this, setting up a real radio meant opening `InputManager` in the
  editor, watching raw axis numbers in the debug panel, and manually
  matching them to `axis_roll`/`axis_pitch`/etc by hand. The new
  Settings -> Calibrate Radio flow asks the pilot to hold each channel
  at the extreme that should read as "positive" in this sim's own
  convention (right/forward/right/max) and picks both the axis index
  *and* the invert flag from the sampled raw value's sign alone - one
  user action does the work of two manual fields. Ends by asking for a
  button press to use as the arm switch. Persisted to
  `user://input_calibration.cfg` and reloaded automatically next
  launch - deliberately the one setting in the whole project that
  survives a restart, since it depends on the pilot's specific hardware
  rather than a preference that's fine to reset.
- **The village's street got a second destination.** "A street
  shouldn't lead into nothing" was the guiding principle applied here:
  a short paved `ConnectorRoad`, textured the same as the street itself,
  branches off the street's own centerline toward the FPV field, so the
  street now has a real endpoint at both ends (the houses, and the
  practice field) instead of fading into open grass on one side.
- **Both drones got a camera pod and an antenna.** A small, cheap visual
  addition to `DroneFrameBuilder` - a forward-tilted camera pod with a
  dark lens, and a thin whip antenna - closing most of the remaining gap
  between "a recognizable quadcopter" (Act VI) and "an FPV quad
  specifically."

### Act VIII — Flight that stops when you let go, rooms you can read, maps that make sense (2026-09-26)

The request, in the user's own words: the flight "is not good" - the
drone "moves sometimes, even if there is no input"; walls and ceilings
were one color with no shadows so "you can easily mistake one for
another and find the wrong direction"; and the maps should be realistic
- "every street should lead somewhere", "if there are houses, there
should be more than one house", "the factory should make sense", the
school "bigger", with "a big sport[s hall] with two soccer goals".
"Maybe you imagine a layout first." Uncommitted at the time of writing,
landed on top of Act VII.

**Flight: four separate causes of "it moves on its own".** Each one was
reproduced with the usual throwaway frame-by-frame headless test before
anything was changed:

- **The drone kept rolling after the stick was centered.** A 0.4 s acro
  roll flick, then stick at exactly zero: the quad kept rolling from 43
  to 53 degrees over two seconds, then crashed. Two causes stacked. The
  drone scene had `angular_damp = 4`, which fights every rotation - the
  numbers matched exactly: the quad settled at 121 deg/s of a commanded
  171 (`9.2 * (171 - w) = 4 * w` gives 119). The I-term made up the
  difference during the flick, wound up, and kept pushing after release.
  Fix: no engine damping, and Betaflight's own **I-term relax** (the
  integrator mostly pauses while the setpoint moves fast). After: 172
  deg/s tracked within ~0.1 s, and 0.4 deg/s residual 0.2 s after
  release, holding the angle.
- **The controls weren't even consistent with each other.** The same
  test harness, fed exactly what the D key produces, rolled the drone
  right in Acro (+16.5 m) and *left* in Angle mode (-3.9 m). The flight
  model's internal convention (+roll = left, +pitch = nose up, +yaw =
  left) had been papered over with invert flags defaulting to true -
  so Angle mode, written against the "obvious" convention, came out
  reversed. And last session's calibration wizard, also written
  against the obvious convention, reversed *every* axis for anyone who
  ran it. Fix: one convention everywhere (+1 = right/forward/right),
  converted to body axes in exactly one place (`drone.gd`).
- **An off-center radio stick is a constant command.** Real gimbals
  rarely rest at 0.000 over USB. The wizard now starts with a "let go
  of the sticks" step that records every axis's rest position; sticks
  are measured from there, with a rescaled deadzone. It also fixed a
  latent wizard bug: a throttle resting at raw -1.0 looked exactly as
  "deflected" as the roll stick being held right, so the wizard could
  assign the wrong axis.
- **Nothing slowed the drone down at low speed.** Only quadratic drag
  existed, which is ~0 at 1 m/s - at hover throttle it kept climbing for
  seconds, and it slid forever after levelling. Added linear rotor drag
  with the coefficient taken from a real measurement (Faessler, Franchi
  & Scaramuzza, RA-L 2018: dx = 0.49-0.54, dy = 0.24-0.39 s^-1, mass-
  normalized; 0.4 used), then re-derived the quadratic coefficient so
  both frames still hit their real top speeds - re-verified headless:
  41.71 m/s (150.2 km/h) and 11.10 m/s (40 km/h).

Plus Betaflight-style airmode (full attitude authority at zero
throttle once armed-and-flown, I-term held at zero on the ground),
physics at 240 Hz instead of 60, and PID gains in *normalized* units
(multiplied by the frame's real inertia), which also fixed the tuning
panel: the whoop's old raw gains (0.00036) were too small for the
0.002-step sliders and displayed as 0.0.

**Rooms you can read.** `HollowBuilding` was rewritten: every face gets a
role (floor, ceiling, interior wall, facade, roof, trim, glass), each
role its own material, all merged into one mesh. Interiors are unshaded
with light baked into vertex colors - fake AO where walls meet floor and
ceiling, a different brightness per wall direction, ceiling darkest -
plus bands that always sit at the *bottom* of a wall (skirting board,
the painted lower wall of a German school corridor, a gym's wood impact
panelling) and ceilings with a pattern nothing else has (beams, tile
grid with lamp panels, skylights, gym lamps). A first screenshot pass
showed why unshaded was necessary: lit only by the sky's bluish ambient
light (no sun reaches inside), every interior surface had come out the
same blue-gray regardless of its own color.

**Maps, layout first.** Each map was drawn as a top-view plan (in the
generator scripts' docstrings, and in README) before any node was
placed, then generated as real, editable nodes by throwaway Python
scripts - the same "generate the repetitive parts, bake them as nodes"
approach as the trees in Act V:

- **Village:** Main Street now enters and leaves the map, 15 new
  two-storey houses line both sides (door, glass windows, an open
  window per floor, stairs hole), plus sidewalks, lamps, parked cars, a
  zebra crossing and a church on a square. A railway embankment
  crosses the map right over the old free-standing tunnel, which turns
  it into an underpass for a farm track to a farm. The club field got a
  car park and clubhouse at the end of its road.
- **Factory:** laid out around a process flow - rail -> dock ->
  warehouse -> pipe -> production (boiler house + tank farm) ->
  assembly -> gates -> public road - with a perimeter wall, ring road,
  staff car park, trucks, and grass outside the wall instead of
  concrete to the horizon.
- **School:** rebuilt at real scale - a 45 x 27 x 7.5 m sports hall
  with two goals (nets you can get caught in), the court drawn to IHF
  dimensions, wall bars, ropes, curtains; a foyer, a 70 m corridor with
  lockers, five furnished classrooms, and a schoolyard.

Moving existing, possibly hand-placed things was asked first (project
rule); the user approved moving what conflicted: the slalom poles that
stood *on* Main Street, Gate2 and a handful of trees in the
embankment's path, the factory tanks that overlapped the track.

**Bugs the screenshots found (again).** Every one invisible headless:
- House floors sat *exactly* at ground height (or 0.5 m under it) - the
  grass z-fought through the floor and won; the church square's paving
  covered the church's floor the same way. All buildings now sit 6 cm up.
- The factory's rails and sleepers had been buried 0.25-0.45 m under
  the ground since the rail yard was added - never once visible.
- The loading dock stood half inside the warehouse wall; the warehouse
  road ran into the warehouse's side wall.
- Wall bars rendered as lockers: two groups shared one deduplicated
  material, and the second texture overwrote the first.
- The first preview run showed every map at 1 FPS with identical stale
  frames - not a regression, but first-use shader compilation of the new
  material variants on this GPU; the warmed-up run settled at 54-57 FPS
  on every map (now printed by the preview tool as `SPAWN_FPS`).

### Act IX — Feedback round: crashes, falls, a way out of Settings, a real menu (2026-09-26)

The user's verdict on Act VIII: "I am actually very surprised. You did
great." Then a list: no way out of Settings; gravity "a bit too weak.
But I don't know if that's true. Please check that"; a nicer, modern
menu in the website's colors; crashes where "I can see through walls"
or the drone "sticks to a wall or a floor or a ceiling"; the school's
flight area was off; you could fly through the rings; and the school
shouldn't let you fly outside.

- **Settings had a Back button - below the bottom of the window.** The
  settings column was simply taller than 900 px. The menu was rebuilt
  around a rule instead of a patch: every sub-screen is a fixed-size
  card whose header row (Back + title) sits outside the scrolling
  content, plus Esc goes back everywhere.
- **Gravity: checked, and it was right** (9.8 m/s², disarmed drop
  matches a real quad: 7.9 m/s after 1 s). But measuring a throttle
  chop found two things softening falls: idle thrust at 7% of the
  drone's weight (Betaflight's 5.5% idle output is ~0.3% thrust) and
  rotor drag at full hover strength with idling props. Rotor drag now
  scales with rotor speed; the quadratic drag was re-derived so top
  speeds stay real (re-verified: 41.74 and 11.11 m/s).
- **Crashes, reproduced first.** Into a wall at 5.4 m/s: speed to zero
  in one step, no bounce, then pinned to the wall by its own thrust,
  creeping upward. Into a ceiling: stuck there, motionless, for the
  whole test. And the see-through: the camera sat 9 cm in front of the
  single collision sphere, so nose-first at the wall it was 1 cm inside
  it. Fixes: a compound collision shape of the real outline (a sphere
  per prop, body, a nose sphere around the camera), the camera moved to
  each frame's real camera pod, **prop strike** (a touching prop makes
  ~5% thrust, then spins back up over 0.25 s; a ceiling above blocks
  all four), a little bounce, no I-term windup in contact. After: the
  quad bounces off the wall, tips and falls; under a ceiling it bumps
  and drops like a real one with the throttle held up.
- **A regression caught by the next screenshot:** with the camera at the
  real pod, the drone's own translucent prop discs covered a big part
  of the picture. The drone's model now lives on a render layer the FPV
  camera doesn't draw (the menu preview still shows it).
- **Rings you could fly *through*.** Torus meshes had no collision at
  all. Each hoop, rim and the village loop now has a ring of box
  segments (rotation from `rotation.y` per segment, never hand-written
  basis numbers) - verified headless: through the middle the whoop
  keeps flying, at tube height it bounces back.
- **School indoors only.** Glass entrance door, a closed emergency-exit
  door (with push bar and exit sign), all classroom windows glazed; the
  border became a box around the building (`WorldBorder.check_box`)
  instead of a circle around a point the school isn't even centered on.
- **The menu, in the website's colors:** its dark palette, 16 px cards
  with soft shadows, a pill "eyebrow", the Oswald wordmark next to the
  artificial-horizon logo, a sky-blue primary button, toggle switches
  and slider knobs drawn in code (still no image assets), a backdrop
  with the logo's own sky-blue and ground-orange glows around a faint
  horizon line, and drone/map choice as cards with descriptions.
- **Round three: "make the whole simulator as [light] as possible so
  you can use it with every PC."** Measured per map first: CPU 50-85% of
  a core, GPU ~30%. Engine monitors pinned the school's physics step at
  3.2 ms - and toggling things one at a time showed *two thirds of it
  was `contact_monitor`*, switched on last round for prop strike but
  only needed for collision signals nothing uses (the contact list still
  arrives with it off - checked). Plus physics 240 -> 120 Hz and the O
  panel hidden by default: CPU down to ~35-60%. A Low/Medium/High
  graphics setting scales the 3D resolution and draw distances (village
  GPU ~30% -> ~19% on Low). Same round, menu: the drone is picked right
  on the home screen with arrows (the extra screen is gone), the
  wordmark reads "STATIC HORIZON FPV simulator", and the 3-inch quad is
  now called **Static One** with tags "3 inch · 150 km/h · 245 g" -
  its physics are still grounded in the real Seeker3, but it isn't that
  product. Tiny Whoop: "1.6 inch · 40 km/h · 25 g".
- **Round four: "the drone doesn't lift off."** Reproduced: the Static
  One climbed fine, the Tiny Whoop sat at y=0.012 at 60% throttle with
  all four props "blocked" - its prop-guard collision spheres reach
  lower than its body, so it rests on them, and prop strike (Act IX)
  counted the floor under a guard as an obstacle in the prop's way. Now
  only a contact at the prop disc or above it blocks a prop; wall and
  ceiling crashes re-verified. Also added on request: a **performance
  mode** (240 Hz physics + contact_monitor back on) as a setting for
  stronger PCs, off by default.
- **Round five: "the Seeker3 still doesn't take off in the factory and
  the whoop not in the school - test the sim until there are no bugs."**
  The previous fix had been verified with a physics test that set the
  throttle directly - which is exactly why it missed the real cause.
  Reading the user's actual RadioMaster Pocket through InputManager:
  plugged in, enumerated, and every axis at exactly 0.000 - not sending
  (off, wrong USB mode, or no input permission). A centered throttle
  channel at 0.0 is 50% throttle, so arming was refused, and a
  "connected" radio had switched the keyboard off: no takeoff anywhere,
  whatever the physics did. Now a radio only takes over once it has
  actually sent data, and the HUD says when one is plugged in but
  silent. And a new permanent `--selftest` plays the real game through
  the real input path (injected keypresses and radio events) for every
  map, drone and performance mode: spawn, arm, takeoff (keyboard and
  radio), steering, reset, menu flow - 107 checks, 0 failed. Its first
  run caught a bug in itself (simulated stick values lingering in
  Godot's input state into the next map), which is the point of having
  one.
- **Round six: lighting, shadows, an in-game menu.** "The landscape
  goes dark if the camera is pointed in some directions": measured with
  four-direction screenshots - looking toward the sun you see the
  shaded side of everything, lit only by a weak ambient (~1:3 against
  the sun); brighter ambient + slightly weaker sun, a green sky
  underside and a far grass plane to the horizon brought the per-
  direction brightness spread from ±5% to ±1%. "The shadow mode doesn't
  work": true - screenshots with shadows on/off were pixel-identical,
  even in a minimal cube-on-a-plane scene and under Vulkan; Godot's
  shadow maps simply don't render on this Intel Iris 6100/macOS
  (known engine issues). (One detour worth recording: a minimal probe
  scene's first frames came out stale, which briefly made *that* test
  meaningless too - the reliable evidence came from the real game's
  screenshot tool.) Replaced with shadows the sim computes itself -
  projected bounding boxes merged into one mesh per map, plus a
  raycast drone shadow - which work on any GPU and are now on by
  default. And the in-game menu: Esc pauses, camera angle/FOV live,
  drone switch, reset, Settings (Back returns to the pause menu; from
  the home screen it returns home - one shared SettingsScreens
  component, the caller decides), main menu. The self-test grew to 131
  checks covering all of those paths.
- **Follow-up: "just in the menu the computer is already spinning its
  fans."** Measured, not guessed: GPU utilization went from 13% idle to
  ~50% with only the menu open. The culprit was the new backdrop - 36
  huge translucent circles for the soft glows, which the GPU re-blended
  over the whole 2880x1800 screen every frame. Now the glows are
  computed once into a 160x90 image and stretched, the menu runs capped
  at 30 FPS (the player's own FPS setting applies in-game), and the
  drone preview only renders while visible: GPU ~8%, CPU 12% -> 9%.
  Same round: the preview's little wall hook, which at that size read
  as "a gray thing hovering over" the drone, is gone - the drone just
  turns in the middle of its card, scaled so both frames fill it.

### Act X — A five-inch, a world that holds still, and a radio setup that doesn't need a mouse (2026-09-26/27)

One long list from the user: a five-inch at 210 km/h; "everything
jitters... the structures and the shadows are going on and off"; a
loading screen "instead of just the beeping of the drone"; better and
different motor sounds per size ("the tiny whoop may scream more");
shadows that look like shadows; nicer houses with something inside; an
About page; a better radio calibration; an arm switch; and "if the
drone crashes and it landed in a position which it couldn't take off
again from, turn the drone that it can fly again after two seconds."

- **Static Five.** A typical 5-inch 6S freestyle build, not one product:
  650 g, 2306-class motors at ~1.5 kg thrust each (9:1), 5.1-inch props.
  The drag coefficient was calibrated the same way as the other two -
  a throwaway test holding full throttle at the angle of best speed -
  until the measured top speed read 210.0 km/h (the others re-checked:
  150.3 and 40.0). Keyboard throttle turned out to be a real problem
  with 9:1 thrust: the self-test's standard "hold Shift 1.4 s" climbed
  past the 170 m altitude reset during the steering checks.
- **The jitter was three separate bugs.** (1) Physics ran at 120 Hz
  while the screen ran at 60 or 144 - without physics interpolation
  the camera moved in uneven steps, so everything seemed to shake; now
  on, with `reset_physics_interpolation()` on every teleport. (2)
  Flat layers (road on slab on ground, dashes on road) were 1-2 cm
  apart and z-fought at distance - "structures going on and off"; every
  layer now has 5-6 cm between them and the camera's near plane went
  from 0.01 to 0.05 (0.012 on the whoop), which buys depth precision.
  (3) Visibility ranges without margin popped objects in and out right
  at the edge; now with a 10% hysteresis margin. One side effect found
  only by the self-test, a round later: raising the factory's roads to
  0.68 m left the drone's spawn point (0.6 m) *inside* the road - it
  got pushed out sideways, never came back with R, and the whoop
  couldn't take off. Spawn raised to 0.8 m.
- **Loading screen.** `SceneLoader` (autoload) loads the map on a
  thread behind a card with the map name, a progress bar and a tip,
  mutes the motor sound, and keeps covering the first 6 rendered
  frames, which is where shader compilation stutters. Also used by the
  pause menu and the world border's reset. It waited for those frames
  with `RenderingServer.frame_post_draw` - which never fires under
  `--headless`, so in the self-test the loader stayed "busy" forever and
  silently ignored every later load. That had been hiding a second
  thing: the world-border reset never actually ran in headless tests.
- **Motor sounds per size.** One synthesized loop per class (blade-pass
  tone + harmonics, the motor's electrical whine at pole-pairs x rpm,
  filtered air noise), built once and pitched with `rpm_fraction`
  (from the real thrust, sqrt(thrust/max)). Checked by spectrum, not
  by ear alone: whoop peaks at 1.3-2 kHz, 3-inch ~870 Hz plus a 2 kHz
  whine, 5-inch ~700 Hz. Silent while disarmed.
- **Shadows, second attempt.** The Act IX boxes looked like boxes
  and flickered a few cm above the grass. Now every object's real
  vertices are projected along the sun into one 2048x2048 mask, filled
  as convex polygons (one per building, walls and roof together),
  blurred into a penumbra, and every ground surface samples it in its
  own shader - gable-shaped shadows, falling across roads too.
- **Houses.** Windows got frames, sills and mullions; the glass went
  matte and dark (glossy glass reflected the sky and read as more
  wall). The real reason some windows looked "missing": two openings
  stacked in one wall were built by a wall splitter that filled the
  column between them with sill/lintel pieces - rewritten column by
  column. Inside: a living room, kitchen, bedroom and study with
  furniture, stairs and a railing - one merged mesh per house, every
  piece a real collision box. And a chimney.
- **About page:** version, how it's made, controls, credits, link to
  the website.
- **Radio calibration, rebuilt.** The old wizard showed a text dump of
  raw axes and needed a mouse click on Next while both hands were on
  the radio. Now: a step bar, a live bar per raw axis (rest point
  marked, assigned channels labelled, the one you're holding
  highlighted with a fill-up bar), and each stick step accepts itself
  once a stick has been held at its end for 0.7 s. The arm step is
  "flip it on, flip it back off" - which also tells a switch from a
  bumped stick. Last, a test view: both gimbals and the arm switch as
  the sim now reads them.
- **Arm switch.** A switch can be a joystick button or, if the radio
  mixes it onto its own channel, an axis - both work, as does a button
  that reads pressed when the switch is off. It behaves like
  Betaflight's ARM mode: armed while ON; a switch already ON when a map
  loads, or flipped ON with throttle up, has to be cycled first (the
  HUD says so). To test all this on a machine without a radio, the
  InputManager got a small virtual radio hook (`test_joy`) standing in
  for the OS joypad read only - everything above it runs as for real
  hardware, and the self-test drives the whole wizard with it.
- **Flip recovery.** On its back or side, still, for 2 s: turned
  upright where it lies, same heading, still armed, HUD countdown.
  Testing it turned up an older bug nobody had noticed: the Static One
  never sat level - its camera's clearance sphere was the lowest point,
  so it rested tipped 22 degrees onto its nose, at spawn and after every
  landing. A thin skid under the frame fixed that for all three.
- **Also found by looking at the screenshots:** the Settings card had
  never been centered - it sat in the top-left corner, because the
  shared settings component set full-rect anchors but kept zero-size
  offsets.

The self-test went from 131 to 226 checks, all passing: the five-inch
on every outdoor map, the loading screen, About, the full calibration
wizard, arm-switch safety, and dropping every drone on its back.

### Act XI — Twelve maps, and the sun that was never there (2026-09-27 to 09-30)

The brief: "a total of 12 maps", Low/Medium/High performance ones for
every PC, the flagship "an old abandoned steel factory inside a forest"
that makes sense and has pipes to fly through, towers to dive, exhaust
stacks and trains; a playground for tiny whoops; a race map built on
real racing gates; rename the Static One to Static Three; "make sure
every radio is compatible"; make it look professional, "because we want
to make it public someday". And: watch the token budget. So the first
thing written was a roadmap (TODO.md) - the hand-off between sessions.

- **Maps as code.** Nine new maps would have been tens of thousands of
  hand-baked .tscn nodes. Instead: `BuiltMap` (sky, sun, fog, border)
  and `Geo`, a batched builder - every box, beam, pipe, cone and lathed
  shape goes straight into one mesh per material per 64 m cell, with
  trimesh collision (so a pipe or cooling tower is really hollow) and a
  shadow outline per piece. `Terrain`, `Forest` (MultiMesh trees with
  real colliders), `MapTextures` (rust, brick, rock... from seamless
  noise, milliseconds each), `RaceCourse`. The steel mill - two blast
  furnaces, stoves, skip bridges, a 500 m walk-in gas main, cooling
  tower, rolling mill, 3800 trees - builds in about 7 seconds.
- **Laid out like the real thing.** The steel mill follows the process
  (sources in TODO.md): rail -> stockyard -> coke ovens -> blast
  furnaces -> torpedo cars through the cast houses -> BOF -> rolling
  mill. The first layout had the two furnaces 75 m apart; checking it
  on paper before running it showed stock houses, dust catchers and a
  road all colliding. Mirrored furnaces 120 m apart fixed it.
  Race gates are MultiGP's standard 5 ft opening; passing is a segment
  test against the gate plane, so even a 1000 km/h test pass can't skip
  one.
- **The best bug of the round: there was never any sunlight.** The
  indoor arena came out nearly black whatever the sun did. Rotating it:
  no change. Energy 0.75 -> 4.0: no change. Removing the roof, turning
  fog on, swapping in the playground's whole environment: nothing.
  Printing every property of the light: identical to the factory map's.
  So the factory was measured the same way - and its screenshots at sun
  energy 0 and 3 were identical too. On this Intel Iris 6100 the
  engine's directional light has never lit anything; every map in the
  project had been lit by ambient light alone since the start (a known
  class of Intel/macOS OpenGL driver bugs). That's where "flat", "you
  can't tell walls from ceilings" and "the shadows don't look like
  shadows" had partly come from all along. The fix is in the project's
  own tradition (it already computes its own shadows): bake the sun into
  vertex colours with unshaded materials - `Geo.shade()` for generated
  maps, `LightBaker` converting the hand-made maps at load time. The
  village suddenly had lit and shaded roof slopes.
- **Radios.** All 10 axes and 128 buttons Godot can report are now
  scanned (was 8 and 16), the first controller that actually moves is
  picked when several are plugged in (or one chosen by name in
  Settings), plus a deadzone slider. Self-tested with a virtual radio
  whose sticks sit on axes 6-9, reversed, arm on button 40.
- **Smaller things:** Static One is Static Three; the map picker is a
  filterable grid with performance badges; the Settings screen became
  three columns (it had quietly started scrolling); the next-gate arrow
  scales with the gate (on a 60 cm whoop gate the 1.5 m-gate arrow was
  bigger than the gate).

Self-test: 353 checks, all passing, every map included.

Then the first sim features from the roadmap: settings that survive a
restart (a once-a-second snapshot compare instead of a save call in
every menu - and skipped under the test tools, so a test run can never
overwrite a pilot's settings), a Betaflight-style OSD, a battery model
with real packs per drone, and Betaflight's exact Actual Rates formula.
The last one was a pleasant check: with Betaflight's default expo of
0.54 it lands within 1 deg/s of the cubic curve the sim had flown all
along (109 vs 110 deg/s at half stick), so adding expo changed nothing
for anyone who never touches it. Then an analog video look and wind
(drag now works on airspeed, so wind needed no new force - just moving
air). Settings outgrew one screen for the third time and became tabs.
And a ghost of the best lap on the race maps. 412 checks.

Next round, from the user: the harbour High and much bigger, "with
trains like a big train station"; far less fog on the High maps; those
maps bigger still; battery as an opt-in; and a HUD that says only the
essentials. The harbour became a port city's rail system laid out the
way goods move - quay cranes, stacks, an intermodal terminal under two
gantry cranes, a hump marshalling yard, a depot, a four-track
electrified main line under road bridges, and a central station whose
three arched bays turned out to be the best flying on the map. Tracks
over kilometres would have been tens of thousands of sleeper boxes, so
sleepers became a texture on the ballast. Thin fog exposed the map
edges, so every High map got a coarse terrain ring to the horizon, and
a shared town builder added villages to three of them. 412 checks.

Then "every object should look more real, like cars and trains", and
the High maps fuller still. A `Vehicles` library replaced the plain
boxes (one new Geo primitive made it possible: an 8-corner solid, for
sloped bonnets, raked windscreens and intercity noses). The harbour
grew into a port city - a proper street grid of courtyard blocks,
towers by the station, a tram boulevard, an elevated port highway fed
by the truck gate, silos at the bulk berth, a tank farm, a marina, a
wind farm - each piece placed where a real port city would put it. The
quarry got its haul ramp, screening plant and a levelled works pad (the
first try had the crusher half-buried in the rising rim), the steel
mill a wrecks car park and the gas line that fed its power plant, the
lake boats, a campground and a hotel. OSD gained speed and time, and a
metric/imperial switch. 413 checks.

### Act XII — A world that connects (2026-09-30)

The user flew the new maps and came back with a list that was really
one complaint: nothing *connected*. Huge maps were cut off at the view
distance with a visible edge; rails and pipes met at points instead of
joining; streets stopped in the middle of fields; tracks crossed at
right angles without a switch in sight; there was flicker where grass
lay "inside" another ground; the harbour was huge and empty. Plus: hide
the mouse cursor, replace the quarry with a construction site, better
textures, more realistic trucks and cars, and fill every map.

**The edge of the world.** Generated maps switched to *depth* fog:
clear air near the drone, thickening into exactly the sky's horizon
colour and fully opaque just before the camera's far plane.
`Settings._fit_fog` re-fits the distances whenever the view distance
changes (which it now also can go back up - a Low-then-High quality
switch used to leave the camera stuck at 650 m). The first screenshot
showed a dark band at the horizon anyway: past the far plane you see the
sky's *below-horizon* colour, which was a dark sea blue. Making that
the fog colour too closed the seam. The hand-made village and factory
got the same fog.

**The flicker.** Two causes, both depth precision (near plane 5 cm, so
at 300 m the depth buffer can't separate surfaces ~10 cm apart). The
village and factory had a 6 km "far ground" plane 3 cm under their
500 m ground plate - flickering at every distance, and exactly "grass
in another ground". It became a ring round the plate at the same
height. For the generated maps, stacked ground surfaces (terrain,
paving, roads, markings, sleeper beds) are now *ground layers*: a small
shader (`geo_layer.gdshader`) draws each layer a fraction of its
distance toward the camera, so the upper one always wins, at any range,
while moving it only millimetres up close. It also got FakeShadows'
mask (the old shadow shader would have replaced it) and a large-scale
brightness variation so tiled grass stops reading as a grid.

**Things that connect.** Three new builders on one idea - a `Route` is
laid out like a surveyor would: straights and circular curves, each
piece starting where the last ended, in its direction. `Geo.sweep`
extrudes any cross-section along it, so a rail, a road with kerbs, a
ballast bed or a pipe is one unbroken piece through every bend.
`Rails` adds real turnouts: the diverging track leaves tangentially
through a 1:9 switch (R 190 m, the common station turnout), with the
point machine at the toe, a frog where the inner rails cross and check
rails opposite; crossovers, buffer stops, signals, overhead line, and
trains that stand on curved track (each vehicle on the chord between
its bogies). `Roads` has junctions (roads end at them, never in a
field), pavements, markings, lamps, parked cars and traffic, viaducts,
and a whole street grid whose edge streets run on out of the map; past
a few hundred metres they keep only their surface. Pipes get rounded
elbows (`Route.rounded`).

**The harbour, smaller and full.** Rebuilt at about a quarter of the
area: a container terminal, a rail branch that curves round at R 250 m
into four loading tracks reached through a ladder of turnouts, a
double-track main line through a *through* station (both throats real
turnouts, a 280 m glass barrel vault over four platform tracks), freight
sidings with a loco shed, two steel truss road bridges over the tracks,
the old harbour basin with brick warehouses, the city grid with towers
by the station and a tram boulevard, and cheap filler blocks on the
continued street pattern so the city fades into the haze instead of
ending. Every rail and road leaves the map or ends at a buffer stop, a
junction, a gate or a car park.

**Construction Site** replaced the quarry: an 18-storey concrete frame
with open floors to fly through, the core three storeys ahead, the
climbing-formwork screen on top, two lattice tower cranes, a 12 m pit
behind sheet piles with struts and a ramp, a steel frame, a pump truck
reaching the deck, the site yard, and an S-Bahn on brick arches.

The steel mill's branch line had simply ended in a hill 400 m west; now
a valley is carved along it (and along the roads south and east, and
the access road up to the town) so they run on to the horizon. Its
torpedo line used to meet the main line at a right angle; now it
leaves through a turnout and two reverse curves. The mountain lake got
a valley road cut into the hillside, from the south past the dam,
through the village to the cabin. The small maps got ground to the
horizon and streets that go somewhere.

**Vehicles** are now real silhouettes (`Geo.prism` extrudes a side
outline across the width - bonnet, windscreen, roof, boot and wheel
arches in one polygon) with a glass greenhouse, pillars, mirrors,
bumpers, plates and lights; cab-over lorries with fuel tanks and side
skirts; coaches with window rows; site machines.

**Performance, measured.** The first harbour took 52 s to build: every
car was ~10 ms of GDScript geometry, and there were thousands. Cars now
go through `Fleet`: each kind built once per heading (the baked light
depends on it) and tinted once per paint colour, then copied into
merged chunk meshes with `SurfaceTool.append_from` - C++, fast. The
construction site then ran at 15 FPS; `SH_PERF=1` printed 1769 draw
calls. The biggest single cause was a one-liner: each car model had
been built with its *own copies* of the vehicle materials, so no two
cars could share a mesh - 1930 separate draws. Sharing the materials,
batching long surfaces and small details in 256 m cells (and not
drawing details past 450 m), and one tinted plaster material for all
house colours (`Geo.tint`) took it to 482 draws and 41 FPS. Harbour
~10 s to load, 47 FPS at spawn; every map 40+.

413 checks, all passing (the construction map's reset check failed
once - the spawn was 30 cm up and the drone settled more than the
test's 20 cm; the spawn now sits at rest height).

### Act XIII — Shadows for free, a steelworks from a real one, rates like the real thing (2026-10-01)

The next list: objects inside each other; everything should run better;
a render distance setting; prettier maps - real shadows, sunsets on
some; realistic trees; maps built for freestyle; show the border when
the "leaving flight area" warning flashes; fill the maps, make them
smaller if they are empty; layouts that make sense, with the
Völklinger Hütte as the model for the steel mill; the fog costs FPS;
a clearer menu and settings; and rates that work like Betaflight's.

**Measure first.** On the user's own settings (High, fullscreen Retina)
the harbour ran at 28 FPS. Switching things off one at a time: fog
alone was worth about 2 FPS - but *glow*, a full-screen post pass that
had been on for every High map, was worth 20. Glow is gone; the harbour
went to 46 FPS before anything else changed.

**One shader for the whole world.** Every surface in every map was an
unshaded StandardMaterial3D with the light baked into vertex colours.
`WorldShading` now converts them all at load into one small shader
family (`world.gdshaderinc`): same look, plus two things the engine
couldn't give us on this GPU:
- *Fog* computed in that shader (a few instructions), replacing the
  Environment's fog with its aerial-perspective sky lookups. All
  parameters are global shader uniforms, so the view distance changes
  one value, not hundreds of materials.
- *Real sun shadows.* Godot's shadow maps render nothing on the Intel
  Iris (Act XI), and FakeShadows only darkened the ground. Now each map
  renders its own shadow map **once**, at load: an orthographic camera
  looking down the sun, every mesh temporarily drawn with a material
  that writes its depth along the sun into red/green (16 bits), read
  back into a texture. Every surface then compares its own sun-depth
  with it - one to four texture reads a pixel, nothing else per frame.
  Buildings shadow each other, bridges shadow roads, crane booms throw
  lines across the container stacks. Two traps: first, the shadows were
  there but invisible - the baked light is ambient-heavy, so taking out
  the exact sun share only darkened ground by 30% and the textures ate
  it (boosted to a believable ~50%); second, a guess that the GL
  renderer would sRGB-encode the depth bytes, settled by reading pixels
  back - it doesn't. FakeShadows and its two shaders are deleted.

**Sunsets.** With shadows that work, low suns pay off: the harbour got a
sunset (sun 9 degrees up in the west, orange haze, long shadows down
the streets), the mountain lake evening alpenglow on the peaks with the
valley already in shade, the construction site late-afternoon light.

**Trees.** Five species instead of two cones: spruce (ten tiers of
drooping star-shaped branch skirts), Scots pine (bare orange trunk,
umbrella crown), a round broadleaf (lumpy leaf masses on real
branches), birch and poplar. One material for leaves and bark (vertex
alpha says which), lit in the shader so randomly turned MultiMesh
trees still face the sun correctly, a leaf-cluster texture, a slight
breeze. Full trees within 140-320 m (by quality), crude 40-triangle
stand-ins beyond - drawn always and smaller than the real crowns, so
up close they're just the dense inside of the foliage. The hand-placed
trees of the village and factory became the new species too, without
moving one (the scene swaps its own mesh at runtime).

**Nothing inside anything.** Rather than hunting overlaps map by map,
Geo now records every solid primitive's footprint and every road/rail
sweep's lane. Parked cars and trees are placed *after* the map is
built and dropped if they'd stand inside a building, a truck, a pillar
or another car - or, for trees, on a road or track. The first run
found 23 such cars in the harbour, 34 on the construction site.

**The steelworks, rebuilt after Völklingen.** The old mill was a 2 km
forest map with two furnaces. The new one is compact (border 430 m)
and laid out like the Völklinger Hütte along the Saar: river and
riverside road, the main line through Völklingen station, the Cowper
stoves in a row, the iron line under the cast houses, six blast
furnaces in one line, the inclined skip hoists rising from the
Möllerhalle bunker building, the ore monorail chasing over from the
ore yard, coking and sinter plants, the blower hall, the old town on
the hill, and the "Paradies" corner gone back to birch wood. It's
built for freestyle: a 244 m column slalom under the bunkers, hollow
gas and blast mains with open joints, the skip hoists to follow up to
the furnace tops, gaps between legs, catchers and pipes everywhere.

**The border shows itself** while the warning flashes: a glowing grid
with hazard stripes on the wall (and ceiling), visible only within
~30 m of the drone - a force field, not a fence round the map.

**Menus.** Settings became five tabs - Graphics, Camera & HUD, Flight,
Rates, Radio - with a one-line explanation under every option, a new
render distance slider (300-3000 m), and visible keyboard focus. The
pause menu gained "Change map". (A "Fly again: <last map>" button on
the home screen lasted one round - the user didn't want it.)

**Rates like Betaflight.** All four of Betaflight's rate types -
Betaflight, Actual, Quick, KISS - ported formula for formula from
`rc.c`, per axis (roll, pitch, yaw), entered as the same numbers the
Configurator shows, with the Configurator's coloured three-axis
preview, presets, and "pitch follows roll". Switching type converts
the numbers so the feel stays close. Old saved settings migrate.


### Act XIV — Two modes, real quads, and nothing in the air (2026-10-01)

The list this time: a proper way to choose between casual flying and
timed racing instead of lumping them together; a picture on each map
card instead of a flat color swatch; drone models that actually look
like a 5" build instead of a primitive skeleton; the leaving-flight-area
border should show itself properly, not just light up a patch under the
drone; a tidier pause menu; a round of pilot-aid features grounded in
what the established sims (Liftoff, Velocidrone, Uncrashed, DRL, TRYP
FPV) actually offer; honester front-page copy; and "make sure nothing is
floating in the air anywhere" as a standing check, not a one-off map
review. Uncommitted at the time of writing. Sonnet (a subagent) did the
research pass behind the pilot aids; Opus did the rest of the round and
reviewed Sonnet's findings before building on them.

**Two modes.** Play now opens **Choose a Mode** before the map list:
**Freestyle** (every map, including the race tracks - just without
their timer, next-gate marker or ghost) or **Race** (only the three
built-for-it tracks - Race Field, Race Arena, Office Whoop Race - with
all of that switched on). `Settings.game_mode` persists the choice
(`MODE_FREESTYLE`/`MODE_RACE`); `MapCatalog` entries got a `"race"` flag
and `MapCatalog.is_race()`; `RaceCourse.setup` simply disables its own
timing in Freestyle rather than the map needing to know which mode it's
in. Personal bests are saved per map *and* drone, with the date, in
`user://race_records.cfg`; `RaceCourse.records(map_id)` feeds a race
map's card in Choose a Map ("Personal best: <drone> <time>"), and
beating your own time flashes "NEW PERSONAL BEST" in the HUD.

**A picture per map, and the run that quietly half-rendered itself.**
Map cards swapped their flat tier-colored swatch for an actual render of
the map (`images/maps/<id>.jpg`, 1024x512), produced by
`godot --path . -- --dev-preview thumbs <map id>` - camera positions per
map in `dev_preview_capture.gd`'s `HERO` dict, High quality, no HUD,
camera tilt zeroed, the border disabled, haze pushed further out so the
shot doesn't read as foggier than the real map. The first renders came
back all sky: the FPV camera's standing 25-degree uptilt, fine for
flying, pointed the preview camera at nothing but cloud, and - once that
was leveled - the flight-area border tripped anyway because the hero
camera positions sat higher up than any pilot actually flies, past the
warning radius on more than one map. After both of those, a second
problem looked like a rendering bug: an fog-distance override meant to
push haze back for the screenshot instead seemed to blank entire scenes
white. It wasn't the fog - it was that the first version rendered every
map's thumbnail in one long run, and by the time it reached the later
maps in the list, something in the accumulated state (loaded textures,
shader variants, GPU memory, never pinned down more precisely than
that) had started producing half-empty frames for maps later in the
sequence - reliably reproducible by position in the list, not by which
map it was. The fix sidesteps the question entirely rather than
answering it: `thumbs <map id>` renders exactly one map and exits, so
each map's shot comes from its own clean process.

**Real quads, not a primitive skeleton.** `DroneFrameBuilder` was
rebuilt around an actual typical 5" true-X build: a carbon bottom plate
with tapered arms and motor pads, a top plate on standoffs, an FC stack
between them, the camera in TPU side plates tilted 25 degrees, a LiPo
with a printed label band, a strap and an XT60 lead, a VTX antenna on
its own TPU mount, receiver whips, motors with anodised bells, and
3-blade pitched props - the Static Three and Static Five both read as
real builds now, not a shared generic frame scaled up. The Tiny Whoop
got its own pass: translucent prop ducts, a canopy with a camera, a
visible 1S cell, 4-blade props. All of it merged per material (so the
part count stayed free) and lit by a new small shader,
`shaders/drone_studio.gdshader` - a view-space studio light rig
(key/fill/rim lights plus specular highlights, a carbon-twill weave
texture) built specifically because the engine's own lights still do
nothing on this GPU (Act XI), and the project's existing baked-vertex-
light approach doesn't read well on a small, close-up, turntable-lit
subject the way it does on a building or a landscape. The menu's preview
camera moved to look from above-front, which suits the new, more
detailed top plate and camera pod far better than the old side-on view.

**The border shows itself, properly, this time.** Act XIII's visible
border only lit up within about 30 m of the drone - correct, but it
meant you couldn't actually see the shape of the boundary you were
approaching, just a patch that followed you. Past the warning line the
*whole* border now draws: a coarse 16 m grid over the entire boundary,
with the finer 2 m grid and hazard stripes layered on top near wherever
the drone actually is. And past the reset line, the drone no longer
triggers a full scene reload behind the loading screen - it's put back
at its spawn point instantly, exactly like pressing `R`, with a "OUT OF
RANGE - BACK TO START" message in the HUD. Reloading the whole map was
always overkill for what's functionally the same reset `R` already did
in one frame.

**Pause menu, tidied.** The header's "Back" became "Main menu" - it
leaves the flight entirely, which "Back" undersold next to `Continue`
and `Esc` (both of which already just resume). The bottom row is now
Reset drone / Change map / Settings, matching how those three are
actually used in practice.

**Pilot aids, from a research pass, not a guess.** Sources: a Liftoff
Steam forum thread asking for stick overlays, fpvcraft.com's
Liftoff/Velocidrone settings guides, velocidrone.co.uk's desktop manual
on fisheye/True Lens, oscarliang.com/fpv-simulator, and the demonixis
DVR Simulator's auto turtle mode. Four features stayed: an optional stick
overlay in the OSD (Settings -> Camera & HUD, off by default) showing
roll/pitch/yaw/throttle live;
Betaflight's actual throttle MID/EXPO formula from `rc.c` (Settings ->
Rates, `Settings.throttle_curve`); a fisheye lens (barrel distortion in
`shaders/analog_video.gdshader`, Settings -> Camera & HUD: Flat / Light
/ Strong); and a line-of-sight view (`V`) - the camera jumps to the
spawn point at eye height and turns to keep following the quad, the way
a pilot without goggles actually watches their own flying. What the
research turned up but didn't land this round, noted as open in
TODO.md: DVR/replay of a flight, physics-tuning sliders exposed to a
pilot (not just the `O` debug panel), checkpoint-style challenges,
signal-loss simulation, structured lesson plans, and multiplayer/online
leaderboards.

**Honester front-page copy.** The start screen used to claim "real-world
quads" - not true, and said so nowhere. It now reads "Practise FPV with
your own radio and your own Betaflight rates..."; the About text
explains instead that the quads' mass/thrust/drag are taken from real
ones and that it's a simulation - close, but never quite the real thing.

**Nothing floats, and the detector that lied about 270 bugs.** The
standing map requirements already demanded nothing flicker and
everything connect; this round added a third: nothing floats. `Geo` now
records every primitive it draws as "support" - including pieces with
no collision and the individual segments of a `Route` sweep, which
hadn't counted before - and `Geo.floating()` / `BuiltMap.floating_pieces()`
walk every solid piece looking for one that touches no ground and no
other support (rectangle overlap with 0.15 m of slack, 0.35 m of
vertical tolerance; hanging from something above counts as supported
too). The first run flagged 270 pieces across the generated maps, 375
once sweep segments were added to the count - and reading through them,
almost all were the detector lying to itself: a roof resting on a
cornice that had deliberately been built without collision (so it was
invisible as "support"), and long thin parts (railings, cables)
approximated by the circle check as having small gaps at every corner
where the real geometry had none. Only after non-colliding parts and
sweep segments started counting as support, and the test switched from
a circle to a rectangle overlap, did the noise clear out and the real
cases stay standing: a coke-oven larry car hovering 40 cm over its
track in the steel mill; straddle carriers in the harbour holding
containers in mid-air (fixed with an actual spreader and ropes); a
ship-to-shore crane whose machinery house didn't reach down to its own
girders; a ship's funnel floating above its deck; a pipe rack whose
crossbeam ran *along* the route instead of *across* between the posts
(now two crossbeams per frame, with the pipes actually resting on the
top one); crane loads on the construction site with no slings holding
them; the village's power-loop hoop, which had never had a stand under
it; and the factory entrance sign, hanging 40 cm under its beam. Every
fix added a new node - a stand, a spreader, a pair of straps - rather
than moving anything already there. `SH_FLOAT=1` prints the list while a
map builds; the self-test now checks every generated map has none, and
`godot --path . -- --dev-preview floatcheck` runs the hand-made scene
maps' equivalent by mesh bounding box.

**More detail, kept cheap.** `YardProps` site clutter (cabins, cable
reels, pallets, barriers, skips) now also dresses the harbour's
container terminal, not just the construction site and steel mill. Its
materials batch in coarse 256 m cells and stop drawing past 450 m, the
same discipline the vehicle fleets already follow, so the extra detail
didn't cost the draw-call budget back. Measured FPS on High/fullscreen
at spawn: Harbour 44, Construction Site 42, Steel Mill 50.

Self-test: 430 checks, all passing.

A turtle mode (flip back over with a full stick) was built too and
removed again the next day at the user's word: the quad already turns
itself upright two seconds after landing on its back, so a second way
to do the same thing was only clutter.

### Act XV — A real race, real gates, real sky (2026-10-02)

The list this time: Race mode rebuilt around an actual race instead of
a single timed lap; gates redesigned to look like the real MultiGP
hardware they were only gesturing at before; all three race tracks
re-laid-out; a sky with a sun disc and drifting clouds instead of the
plain gradient, plus the frame-rate regression it caused and the fix;
the motor sound rebuilt from scratch, handed to a Sonnet subagent and
reviewed afterward; and a small menu-card layout fix. Self-test: 431
checks, all passing.

**A real race, not a stopwatch on a single lap.** `RaceCourse` used to
time one lap and call it done; a race is now `RaceCourse.LAPS = 3`
laps, started from a flying start - the clock starts on the first pass
of START, not on a countdown - and finishing brings up a results card
(`ui.show_race_results`) listing every lap, the total, "NEW TRACK
RECORD" or a rank, and the pilot's own local top 5 for that exact track
and drone (`user://race_board.cfg`, with the date; `RaceCourse.boards(map_id)`).
The next pass of START simply starts a new race - no menu round-trip
needed to go again. Every gate now shows a live split against the best
lap's own splits (saved alongside the best lap as `"<drone>_splits"` in
`race_records.cfg`): green `-0.31` when ahead, red `+0.42` when behind,
which needed `ui.set_race_info` to grow a good/bad colour flag. Flying
through a later gate instead of the next one in order now says "MISSED
GATE n" rather than silently not counting it. The HUD line reads `LAP
n/3`, the current lap time, `GATE n/N`, and `BEST`, with a "NEW
PERSONAL BEST LAP" flash on top; number boards (`Label3D`, billboard)
sit above every gate, with START labelled "S"; and every timing event -
gate, lap, personal best, race start, the finish fanfare, a missed gate
- gets its own tiny synthesized beep, no audio files involved. Records
are kept per *track layout*, not per map: `MapCatalog` entries carry a
`"track": n`, and `RaceCourse.section(map_id)` turns that into a key
like `"race_field@2"` - so redesigning a track (as this round did, to
all three) starts a clean record table instead of comparing fresh laps
against times set on a layout that no longer exists. The map choice
cards for all three tracks now show each drone's best lap and best
3-lap race, not just a single number.

**Gates that actually look like MultiGP gates.** The old gate geometry
was a flat frame; it's now a pillowed fabric panel on each side (a
thicker strip down the middle of each panel, the way a real quilted
gate panel sits), white piping around the opening - on the LED gates
the piping doubles as the light strip and the panels go dark instead -
a PVC tube frame around the outer edge, a dark sponsor patch on the top
panel, and weighted feet / base plates so nothing in a race track reads
as floating, which the project's own "nothing floats" rule (Act XIV)
would otherwise flag. The small whoop-sized gates got piping and a base
plate too. A new builder, `RaceCourse.hanging_gate()`, hangs a gate of
any size - including whoop scale - from the ceiling on two wires slung
from bars spanning between roof trusses, for courses where a gate needs
to be in the air with nothing underneath it.

**Three tracks, redesigned.** Race Field became a full 12-gate
clockwise lap around the whole field instead of a short out-and-back:
START facing east at (0, 30), then gate, gate, a ladder (fly the top
opening), a 5 m dive gate, a hurdle to the west, a double gate (upper
opening), a tower gate, a gate to the south, a second dive gate at 4 m,
a hurdle to the east, one more gate, and back through START - with turn
flags at the four corners and the spawn point moved behind START facing
east to match. Race Arena gained a gate hung from the roof trusses as
the last gate before START: a left turn out of the pink gate, a climb,
then a drop down to the start line. Office got a whoop gate hung from
the ceiling between the existing high gate and the desk gate, so the
line is climb, duck under the ceiling, drop onto the desk.

**A sky with clouds, and the FPS regression that came with it.** Every
generated map (and, through `Settings`, the hand-made village, factory
and school) swapped the plain `ProceduralSkyMaterial` gradient for
`shaders/sky_clouds.gdshader`: same base colours, but now a sun disc
with a warm glow around a low sun, and clouds generated from a single
`FastNoiseLite` texture baked once at load, projected onto a flat cloud
layer that shrinks toward the horizon, lit brighter on the sun's side
and tinted by the sun's colour (orange at sunset), drifting slowly
across the sky; an environment key `"clouds"` sets the cover threshold
(1.2 reads as clear). `BuiltMap.cloud_sky()` is the one shared helper
every map calls. The first version shipped and immediately cost real
frame rate: Race Field dropped from 48 to 29 FPS. The cause wasn't the
noise texture or the extra fragment work in the visible sky - it was
that the drifting clouds read `TIME` in the sky shader, and Godot
re-renders the sky's reflection cubemap every frame when anything in
the sky material is time-varying. Nothing in the project actually uses
reflected light (every material is the project's own unshaded baked
kind), so the fix was to give the cubemap render passes
(`AT_CUBEMAP_PASS`) the plain static gradient instead of the animated
one, turn off reflected light entirely, and drop the radiance size to
32 px. FPS came back to 54 on Race Field and 44 on Harbour.

**Motor sound, rebuilt - by a subagent.** The motor audio
(`scripts/motor_audio.gd`) was rebuilt from the ground up by a Sonnet
subagent and reviewed afterward: two rendered layers per drone class
instead of one - a tone loop (blade-pass harmonics with a spectral tilt
per class, motor whine plus an odd-harmonic ESC "buzz", rumble, and
four motors with slow, independent rpm wander so the beating between
them drifts instead of locking into an audible loop, built click-free
by integrating whole cycles of phase) and a separate broadband prop-wash
noise loop on its own "Wash" child player. A new "MotorLPF" audio bus
carries a low-pass filter whose cutoff tracks rpm - dull at idle,
bright at full throttle - and the wash layer's volume follows rpm and
spikes on fast rpm changes (punch-outs, throttle chops), the way prop
noise actually behaves rather than just getting louder with throttle.
Render time is about 100-150 ms per drone class, once, not per frame.
Sources cited directly in the file: NASA's AMS 2021 quadcopter
aeroacoustics paper (Kelecy), an Acentech article on drone noise, the
BLHeli_32 ESC guide (uavmodel), and halfchrome / tattuworld for what
actually distinguishes a whoop's scream from a 5-inch's growl.

**Menu cards that fit what's actually in them.** The map-choice cards
in Choose a Map were sized off the button alone, which doesn't grow
with its children, so once a card's tags wrapped onto a second line or
a per-drone personal-best list grew past a couple of entries, the
bottom got cut off. The card's minimum height now follows its actual
content, tags wrap through an `HFlowContainer` instead of overflowing,
and personal bests are one line per drone - nothing at the bottom of a
card is cut off anymore.

Self-test: 431 checks, all passing. Uncommitted at the time of writing.

### Act XVI — The whoop gets real (2026-10-02)

The list this time: flight feedback on the motor sound, and the whoop
itself stopped being an invented placeholder and became a researched
real frame, the same way the Seeker3 and the Static Five already were.
Both landed in one round, plus a model rebuild to match and a couple of
finer details on the two freestyle quads while the model code was
open. Self-test: 488 checks, all passing.

**Motor sound, tuned from actually flying it.** The prop-wash layer was
too loud on throttle-ups, so it's now roughly 8 dB quieter with a
smaller punch spike (max +3 dB, down from a louder one). The other way:
armed and sitting at 0% throttle the motors were too quiet, even though
airmode and idle thrust already keep the props physically spinning
there - idle volume is raised about 13 dB (`db_min` is now only ~8 dB
under `db_max`, instead of a much bigger gap) and idle brightness is
raised too (the low-pass idle cutoff moved up), so the idle hum reads
as "motors are live" instead of as silence.

**A toy whoop becomes a real one.** The old Tiny Whoop was an invented
placeholder sized off a generic "sub-75mm class" research pass: 1.6
inch, 25 g, translucent prop ducts doing double duty as guards, 1S
300 mAh, an estimated 40 km/h, ~3:1 thrust-to-weight. It's now the
**Static Whoop**, grounded the same way the Seeker3 and Static Five
were - real sources cited directly in `drone.gd`: a current 75 mm
brushless ducted whoop's own product page, and oscarliang.com's review
of the previous generation ("incredibly nimble", hovers well under half
throttle). New numbers: 75 mm wheelbase (motor offset 26.5 mm), 32 g
all-up (21 g dry plus a ~11.5 g 1S 480 mAh pack - an estimate, no
source states it directly), 0802 motors, 0.55 N thrust per motor
(~7:1 thrust-to-weight from one secondary source), 41 mm 3-blade props,
a 1S 480 mAh / 12 A pack, and a top speed of 70 km/h - still an
ESTIMATE, since no source anywhere quotes a measured number for the
class, derived with the same drag formula used for the other two
frames rather than invented. The display name changes to Static Whoop
in the menu; the id stays `"whoop"` internally, same pattern as the
seeker3 -> Static Three rename back in Phase 1, so saved settings and
personal bests keep working. At ~7:1 instead of ~3:1 it flies light and
snappy rather than floaty. The motor sound's own per-class table moved
with it: 3-blade, ~66,000 rpm loaded (0802 at roughly 25,000 KV on 1S),
grounded in the same numbers as the flight model instead of left over
from the old spec.

**The model rebuilt to match - closed ducts, not open rings.** The old
whoop model's prop guards were simple open `TorusMesh` rings; the new
one is built like an actual ducted whoop's frame: closed thin-walled
ducts (10.5 mm tall, a flared top lip and a narrow inner floor lip,
with the props sitting inside the upper half instead of hanging below
an open ring), motor mounts braced straight to the duct floor, arms
running in to a centre plate, and bridges between neighbouring ducts so
the four ducts read as one frame rather than four separate rings. On
top: an angular black canopy with the camera (25 degrees) behind its
front window, the 1S pack in a holder behind it, a copper-pipe antenna,
red motor bells, and orange 3-blade props.

**The freestyle quads got finer while the code was open.** Static
Three and Static Five picked up copper stator windings visible under
the bell, a spoked bell top, a metal lens ring around the camera, a
rounded battery pack instead of a plain box, and a small rear LED
strip - detail passes alongside the whoop rebuild, same primitives and
materials, nothing that adds a meaningful draw call on weak hardware.

**One self-test number moved for a real reason, not a flaky retry.**
The Static Whoop's new ~7:1 thrust-to-weight meant the indoor takeoff
hold in self-test - which only has to clear the School gym and Office
ceilings before steering - now punched straight into them. Shortened
just for the whoop indoors: School 0.6 s, Office 0.7 s, both
re-verified against the new frame rather than loosened until the test
passed.

Self-test: 488 checks, all passing. Uncommitted at the time of writing.

### Act XVII — A race quad, a replay, and air that pushes back (2026-10-02)

The list this time: a fourth drone built for the race tracks instead of
borrowing a freestyle quad's feel; three physics effects a real quad
has and this sim didn't (motor lag, prop wash, ground effect); a replay
system - the single most-requested feature from Act XIV's research
pass - built and then flown before being trusted; radio switch
bindings for flight mode, reset and line-of-sight, handed to a Sonnet
subagent and reviewed; and a water shader plus a global colour grade,
both toned down from their first pass after a look at the real
screenshots. Self-test: 472 checks, all passing (the exact count
depends on which radio paths a given run exercises). Uncommitted at the
time of writing.

**Static Race.** The fourth frame, alongside the Static Three, Static
Five and Static Whoop in `Drone.PROFILES`/`PROFILE_ORDER` - a 5" race
build, not a specific product, the same "grounded in real numbers, not
one real product" rule the other three frames already follow. All-up
weight 440 g: a race 5" dries out at 250-300 g against a freestyle
build's 300-450 g (oscarliang.com's prop/motor/LiPo weight table), plus
a 6S 1000-1300 mAh pack at roughly 150-180 g (intofpv.com) - 2207-class
motors at ~1950 KV on 6S, 5.1" tri-blade props, 11.9 N per motor, an
11:1 thrust-to-weight ratio (race builds run 8-12:1 per x-teamrc.com;
bench tables show up to ~19 N per motor at full power, dronehitech.com's
F60 Pro IV test - 11:1 sits comfortably inside the real range rather
than at its edge), 225 mm wheelbase. Top speed 170 km/h is an ESTIMATE -
a league racer was measured at ~137 km/h (drl.io), but a tuned personal
race build goes faster than a league-regulated one - and, same as every
other frame's top speed, it wasn't just typed in: a throwaway physics
test (`scripts/physics_test.gd` + `scenes/PhysicsTest.tscn`, deleted
after) flew it level at full throttle and tuned `drag_coefficient`
until that settled at the target speed, converging on 171 km/h - the
same session's version of that test also reproduced the Static Five's
210 km/h exactly, which was the actual evidence the method still
works, not just a one-off result for the new frame. Look: a low frame
on short standoffs, the 6S pack strapped under the bottom plate instead
of on top, the camera tilted a race-steep 45 degrees (vs. 25 on the
freestyle quads), a slim near-vertical antenna, lime green. Its own
motor sound profile in `motor_audio.gd`'s per-class table (~640 Hz
rotation, tuned by the same ear that rebuilt the whole sound system in
Act XV).

**Three things a real quad does that this one didn't - motor lag, prop
wash, ground effect.** All three went into `drone.gd` and were checked
with the project's standard tool, a throwaway frame-by-frame physics
test deleted right after: motors don't change thrust instantly, so each
of the four now follows its commanded thrust through a first-order lag
(`motor_tau`: whoop 15 ms, Static Three 20 ms, Static Race 22 ms,
Static Five 25 ms - smaller, lighter props spin up faster) instead of
responding in the same physics step it was commanded in. Prop wash:
descending through your own downwash - the shake on a dive-and-catch
every FPV pilot knows - now exists; past 1.5 m/s of descent along the
thrust axis (full effect by 6 m/s) with the motors still loaded, it
adds an ~8 Hz random roll/pitch torque and costs up to 20% of the
thrust. The first version of this was wrong in an instructive way: it
shook the Static Five at up to 28 rad/s on a dive-and-catch test - so
violent it would have read as a bug, not a feature - and was scaled
down until a catch wobbles at most ~3.4 rad/s (about 190 deg/s) while
losing lift on the way through, which is what frame-by-frame logging of
the test run actually showed rather than a number picked by feel. Ground
effect adds up to 12% extra thrust right at the ground, fading out by
two prop diameters of height, checked with one raycast every 50 ms
rather than every physics step - the cushion that makes a low hover
feel different from a mid-air one, cheap enough not to matter.

**Replay - the thing the Act XIV research pass flagged as the top
request and this round finally built.** `scripts/replay.gd`, created by
`ui.gd`, always keeps the last 60 seconds of flight recorded at 30 Hz.
`P` plays it back: `Space` pauses, `Left`/`Right` jump 5 s, `Up`/`Down`
change speed from 1/4x to 2x, `C` cycles the camera (chase, FPV, or
line-of-sight from the spawn point), and `P` again hands control back
exactly where it was left - position, velocity and rotation restored,
not just the camera cut back. The flying drone itself freezes and
hides for the duration; what's actually on screen during a replay is a
second copy of the same drone model (built by the same
`DroneFrameBuilder` the real drone uses) flying the recorded path, with
the HUD and crosshair hidden so a replay doesn't look like it's still
being flown live. Self-test checks that stopping a replay really does
hand control back.

**Radio switch bindings - done by a Sonnet subagent, reviewed.** Besides
the arm switch, three more controls can now be assigned to a radio
switch or button in Settings -> Radio: **Assign Mode Switch** (sets
Acro/Angle directly from the switch position, the same way Betaflight
puts ANGLE on an AUX switch - not a toggle), **Assign Reset Button**,
and **Assign Line-of-Sight Button**, each with its own Clear and status
line, captured by the same calibration-wizard step the arm switch
already used (`InputManager`'s `_control_on()`/`_control_name()`/
`_clear_control()` generalize the one arm-switch pattern across all
three instead of three near-copies of it). All three are optional and
start unassigned - until assigned, behaviour is exactly what it always
was (`L` for mode, `R` for reset, `V` for line-of-sight on the
keyboard), and those keyboard keys keep working alongside a radio
binding either way. Saved in the same radio config as the arm switch.
Built by a Sonnet subagent and reviewed afterward rather than written
directly.

**Water that looks like water, and a colour grade for the whole world -
both pulled back from their first pass.** The shared world shader
(`shaders/world.gdshaderinc`, `shaders/world_common.gdshaderinc`) gives
any material named `*water*` (`Geo.water_mat`) moving ripples, a
Fresnel sky reflection that strengthens at shallow viewing angles, and
a glint off the sun - the first version of this made the sunset
harbour basin's water read as sand, so the reflection and glint
strength were both toned down until the basin looked wet again rather
than lit wrong. Alongside it, a small global colour grade
(`sh_grade`: contrast 1.08, saturation 1.12, plus an optional per-map
warmth) runs in the same shader pass over every world surface - set
once in `WorldShading.set_grade()`, overridable per map via the
environment's `"grade"` meta - at no extra per-frame cost since it
rides along with work the shader was already doing.

**FPS, measured again.** On High/fullscreen at spawn, frame rate on the
dev machine varies run to run now (thermal throttling and background
load, not a regression) - representative numbers from this round:
Steel Mill 34-49, Harbour ~40, Mountain Lake 49, Race Field 55.

Self-test: 472 checks, all passing. Uncommitted at the time of writing.

**Two follow-ups the same day.** Prop wash got its own switch
(Settings -> Flight, on by default) for pilots who want a clean catch
every time, and a fifth assignable radio control: a **restart switch**
that reloads the map from the start - race, timer and drone - for
flying a whole session without touching the keyboard. Edge-triggered,
and it starts out "on", so a switch already up when a map loads has to
be flipped again rather than restarting the map forever.

**Shipping it: Windows, Linux, macOS, and a page to download from.**
After the commit (f82939d) came the first real builds. The disk was
nearly full, so instead of downloading Godot's 1.3 GB export-template
archive, a small Python script read the archive's zip directory over
HTTP range requests and pulled out only the three templates needed
(Windows, Linux, macOS), checking each one's CRC. Windows and Linux are
single executables with the game packed inside; macOS is a universal
app (Intel and Apple Silicon in one bundle), which Godot only exports
once the project allows ETC2/ASTC texture compression - free here,
since every texture in the sim is generated at runtime. Each build was
checked the way the game itself is: the exported pack runs the full
`--selftest` (474 checks, the windowless subset of the suite), and the
macOS app also started with a window on the dev machine's Intel GPU.
The builds aren't code-signed (Windows) or notarized (macOS), so the
README in each zip explains the one-time "Run anyway" / right-click ->
Open step. The website session - a second Claude working on the
Static Horizon website at the same time - got a brief with the facts,
wording rules and 38 pictures, wrote the simulator article and the
home-page teaser, and linked the three zips. Public hosting is still
open: the downloads work on localhost for now.

### Act XVIII — Creators: houses, a toilet, trees and land from a seed (2026-10-02/03)

This one started as a question rather than a feature request: how has
map design worked so far, and could Claude write tools for itself that
make it cheaper? Cheaper in a specific sense - fewer tokens. Every map
so far was built by writing out its content by hand, coordinate by
coordinate, and a house with furniture in every room is thousands of
lines of that. The answer became a new way of making map content:
**creators**, seeded generators that build one kind of thing with all
its detail, are tuned once in a **lab** until every seed looks right,
and are then reused by every map. The session built four of them - a
house, a toilet, trees, and the land itself - plus a test map to fly
them in. Self-test: 495 checks, all passing. Uncommitted at the time of
writing.

**The lab: a feedback loop for a human and for Claude.** Each creator
has a lab scene (`scenes/labs/*.tscn`, not in the menu) that lays out a
few variants and names its camera views. One command
(`--dev-preview lab <Scene>`) renders every view to a PNG, stitches
contact sheets of four views across, and writes an `index.html` with a
lightbox for the user - open it, reload after each run. The contact
sheets are the token trick: one sheet is a single image read, about
1.5k tokens for a whole house seen from a dozen angles, where the old
way was a screenshot at a time. `map_design.md` records the process,
the creators table and a catalogue of surprises, and `CLAUDE.md` points
every future session at it.

**HouseCreator: a detached family house, furnished.** From one seed:
one or two storeys, gable or hip roof, plaster or brick, shutters or
roller blinds, a garage or carport or neither, a terrace with a parasol
and garden furniture, and inside a real floor plan - kitchen, hall with
stairs, WC, living room across the back; bathroom, bedrooms and a
study or kids' room upstairs (a bungalow plan for one storey). Every
room is furnished by a small placement solver (`_spot`) that knows
which wall stretches are blocked by doors and windows and what's
already standing. Half the seeds are mirrored - the whole frame, which
is safe because `Geo` orders each triangle's winding from its intended
normal. And there's always a way in: a patio door or window left open
at the back, because an interior is only fun if you can fly into it.
The lab renders each house from the street, the back, the air, through
every way in, and from the doorway of every room.

**Light indoors, baked, for free at runtime.** The first houses looked
flat and grey inside - the engine sun does nothing on the dev machine's
GPU, so all light here is baked into vertex colours, and the interiors
only had the outdoor formula. `Geo` got a `light_fn` hook, and while a
room is drawn HouseCreator lights it: daylight from that room's own
windows and glass doors, sun patches where a ray through an opening
reaches the floor, a warm glow round the ceiling lamp, and darkening
into corners, along edges and under furniture. Walls, floors and
ceilings are split into cells (`Geo.quad_grid`) so the light can vary
across them. Measured on four houses: draw calls unchanged (104),
+14k vertices and +0.13 s build per house, nothing per frame. Interior
materials carry a `no_shadow` meta, because the runtime sun shadow map
would darken them a second time.

**ToiletCreator: the first surprise.** The user's brief: a really
well-made American toilet with plenty of water in it, where mostly
nothing floats - and sometimes something does. An elongated bowl
(`Geo.lathe_xf`, a new revolve-a-profile tool for round things), a
tank with the flush lever front left, seat and lid down or up, bolt
caps, a shut-off valve, and a paper roll hung "over" in 70% of homes.
In one toilet in five there's a rubber duck, a battleship, a swan or a
message in a bottle. The first lab round had a shark fin too; the user
took it out of the random draw (it still exists on request) and
pointed out that the raised seat merged into the cistern - the hinges
moved forward to the back of the rim and the raised angle became 91
degrees, leaning just clear of the tank. Then into the houses: every
bathroom and WC now gets one, with its own random generator so the
rest of the house keeps its layout, and a frame un-mirrored so the
lever stays on the left even in mirrored houses. They came out dark
grey at first - the toilet's materials took the outdoor shadow map
indoors, the same double-darkening the house materials had already
been protected from - and the fix was the same meta.

**A seed library instead of a perfect generator.** The user's idea,
mid-session: every seed gives the same house, so rather than making
the generator robust against every bad seed, keep a list of good ones -
500 is plenty. The catch is that any change to the generator reshuffles
what every seed produces, so the decision recorded in `map_design.md`
is about 10 hand-picked designs during development and the real
library built once, right before release.

**Test Street, and only one house in five you can enter.** A map in
the menu to fly the creators in: a street with sidewalks and eight
houses. Then the user's load-time rule: 20% of houses enterable, the
rest empty - but they must look as good from outside. A closed house
now shows a shallow painted room niche behind every pane: back wall,
sides, curtains drawn to the sides in a fabric colour, now and then a
plant on the sill, built in shell materials so it never drops out at
distance and leaves a see-through window. `HouseCreator.accessible(i)`
opens every fifth. Eight houses went from 4.1-4.6 s to 1.4 s to build.

**TreeCreator: trees that cost almost nothing.** Maples, apple trees
with fruit, birches, spruces and bushes (hydrangeas in blue or pink),
three seeded shapes per species, each tree turned, scaled and tinted.
Built on the existing tree shader and drawn as MultiMesh: one draw call
per shape and 128 m chunk however many trees use it, and a simple
stand-in beyond the near range. One small shader change made fruit and
flowers free: vertex alpha 0.4 now means "plain colour" next to 1
(leaves) and 0 (bark), so apples are part of the tree's own mesh. The
garden surprises: a birdhouse (8%), a tyre swing (5%), a kite caught in
the crown (3%), and the one every FPV pilot will recognise - a quad
stuck in a tree with its LED still on (2.5%). A cherry in blossom was
built too and left out at the user's request; a copper beech among the
maples turned out to be one tree in three and is now one in ten.

**TerrainCreator: the land itself.** Test Street's flat green plane to
the horizon had become the weakest thing in the picture. The project
already had `Terrain` (heightfield to mesh, collision and horizon
ring), but each hilly map hand-wrote its own height formula.
TerrainCreator supplies that part: "rolling", "hills" or "valley" from
a seed, level ground wherever the map builds (plots, a street running
on into the fog) that eases into the hills over 40-70 m, ponds that
take their water level from the ground around them, ground colours
(dry pasture, lush patches, bare earth on steep banks), and woods -
real patches of wood plus lone field trees - handed to TreeCreator.
The first lab round showed hills too flat to notice (the noise only
used half its range) and trees spread evenly instead of in woods; both
needed a second look at real pictures, not a number.

**Two seconds down to 0.6.** The first terrain-plus-woods version cost
about 2 s of load time; the rest of the session went into profiling it
section by section rather than guessing. Three findings. `Terrain` lit
every grid point six times (once per triangle corner) and pushed every
vertex through several script calls; it now lights each point once and
builds indexed chunk meshes - and since that touches every hilly map,
Mountain Lake was rendered with the old and the new code and the two
pictures compared pixel by pixel: the ground was identical, only
swaying trees and drifting clouds differed. The terrain caches its
height grid, so placing a few thousand trees no longer re-evaluates the
noise. And the biggest single item was a design bug, not a slow
function: wood trees used the garden surprise chances, so a 2,500-tree
wood carried about 200 birdhouses, drones and kites, each built in full
detail. That was also exactly what the surprise rule forbids - a drone
in every twelfth tree isn't a discovery. Woods now get no garden
surprises and no copper beeches, only a rare lost drone (0.2%) or kite
(0.1%). Tree collision moved from a node per tree to shared shapes on
the chunk's body. Test Street now builds its land in 0.46 s and about
1,840 trees in 0.27 s.

**Three bugs the user found by flying it.** After a crash into a hill
you could see through the ground; birdhouses and some apples hung in
the air next to their trees; and tree hitboxes didn't match the trees.
The first was the best one, and old: `Terrain` drew each 8 m grid cell
as two triangles split along one diagonal, while Godot's
`HeightMapShape3D` - the collision - splits along the other. A
throwaway probe on a single cell showed it (0.0 vs 0.4 m at the same
point), and 389 random raycasts on the "hills" landscape measured it:
7.5 cm off on average, 1.55 m at worst, enough for a crashed drone to
come to rest with its camera under the visible hillside. That mismatch
had been in Mountain Lake and the Steel Mill since they were built;
one flipped index order fixed all three maps, and the same raycasts
afterwards agreed to 0.1 mm. The birdhouse sat at the trunk's base
radius, but trunks taper and some lean - it now sits on the trunk's
real axis at its height. Apples were placed on a nominal crown, while
the leaf masses are jittered - they now sit on the masses' own corner
points. And trees collided as two upright cylinders, whose corners
stuck out of round crowns while other parts of the leaves let you
through; they now collide as a convex hull per leaf mass (its own
jittered points), a prism along each real trunk, and a cone over a
spruce's tiers. A ray test against the drawn meshes first gave
nonsense - it turned out that headless Godot doesn't store multimesh
transforms, so the test read every tree as unturned - and, once fixed,
showed 419 of 441 tree hits matching within 8 cm.

**Rivers, roads and bridges - creators that talk to each other.** The
user asked for a road generator and a river generator that interact.
The design: the land is the shared plan. Every line is a `LandLine`
registered with TerrainCreator before it builds, and the ground is
built in stages - natural land, ponds, rivers, level plots, roads -
each seeing what the earlier ones left. Rivers only flow downhill by
construction (the water level along the course can only fall; where
the land rises in the way, the river carves its own valley). A
crossing is decided by the later line: the road finds the river, holds
its deck 4.5 m above the water, ramps up at 7 %, marks those segments
as bridge, and a third creator builds the bridge - a concrete beam, a
stone arch or a steel through-truss you can fly through. Two first-run
failures made the rules sharper: the road's embankment buried the
river beside a skewed crossing (now: a road never dams a river - the
channel is carved again on top of any fill), and the first bridge was
6 m long because the span search measured in 3D while the road points
had no height yet. The river's banks are drawn as their own surfaces,
finer than the 8 m terrain grid, and the terrain is carved just below
them. And everything on the hills had been shaded as if it lay on the
ground at y = 0 - a bridge 15 m down a valley came out nearly black -
until `Geo` learned the ground height under each point. Surprises: a
rubber-duck race drifting down a river (5%) and a shopping trolley
under a bridge (12%). Test Street got a river across the north and a
country road off the end of the street, over a green truss bridge and
up into the hills.

**Junctions, a village, and roads that don't break.** Next round: road
junctions, a village generator, and "the streets are bugged in the
terrain sometimes". Low cameras along every road found two separate
bugs. Roads stopped dead where the detailed terrain ended, and past it
the cameras were underground - the coarse horizon ring isn't cut for a
road. Roads now lie on the ring out there (`far_ground()` mirrors its
triangles exactly) and run on into the haze as plain carriageway. And on
hillsides the road's edge was bitten by grass triangles: the flat bed
under the road was only a metre wider than the road, so an 8 m grid
triangle with one corner up the slope rose through the edge. The bed is
now a grid cell's diagonal wider on each side - every triangle touching
the road lies flat. One more surfaced at the edge of the detailed land:
the horizon ring overlapping it was kept 1.5 m under the natural
ground, and where the road ran in a deeper cutting the ring's 110 m
triangles spanned it and buried the road; the ring is now kept under
any road or river within one of its cells. Junctions: a branch road
starts square-on at the edge of the road it leaves, at that road's
level, through a mouth with 7 m rounded corners and a give-way line,
laid edge to edge with both roads (overlapping asphalt flickers). Side
lanes end in turning circles. The village generator puts it together:
a main road in from the haze past a village green (lime tree, benches,
a maypole), two or three lanes on junctions, house plots dealt out in
turn along every road (levelled to the road, the house facing it, one
in five open), gardens and street lamps. Test Street became a village.
Loading was 7.3 s at first; markings built dash by dash along 3.4 km of
main road that mostly lies in the haze cost 1.1 s of it (now plain
there), and switching off the new terrain shading hook while a house is
built (a house sets its own levels - and the hook was wrong upstairs)
took closed houses from 90 to 64 ms. About 6 s remain, 2.3 s of them
the 16 houses.

**The generators, made to work together.** The user's verdict on the
village round was blunt: the road looked bad at the junctions, still
broke in the terrain, rivers stood above the land, the village didn't
look good - and the generators should hand work to each other, the
village telling the house generator where its plot is and the house
generator building the house, its fences and its garden. Close views
of every junction found the real road bug: roads carved the ground one
after another, so a side road's flat bed - at its own junction level -
flattened the main road beside it, burying the main road where it
sloped. Now only the nearest road shapes a point. The junction mouth
had been laid flat at one height on a sloping road; it now follows the
main road along its edge, and the main road's edge lines break at
every mouth. Rivers: smoothing the water level averaged pools with the
higher water upstream and lifted them above hollows; the level is now
capped under the ground again after smoothing, and in the haze the
water had been laid over the coarse hills - every horizon vertex near
the river now sits under it. The village now claims its land first
(levelled over its whole area, easing into the hills over 110 m), lays
out real rectangular plots square to their roads (checked against
every road, the green, water and each other), and hands each to
`HouseCreator.build_plot`, which sets the house back on it, reports
where its path and driveway reach the street, and calls the new
`GardenCreator`: a picket fence, low hedge or low wall to the street
with a gate at the path and an opening for the drive, hedges or
post-and-rail round the rest, and a garden behind - trees, bushes, a
shed, a washing line with laundry, vegetable beds, a trampoline or a
sandpit; a gnome by the path in one plot in sixteen, and in one in a
hundred an army of fifteen. Along the way `Geo` got a fast path for
consecutive pieces in the same batch (boxes 115 -> 85 us) and the
levelled areas a bounding box each (the land went back from 1.7 to
1.1 s with 18 of them).

**Stepping back: design the layout, generate the detail.** After
another round of reports - houses floating, a pond standing high with
its water not enclosed, the road layout not good, the land glitchy -
the user asked the real question: does it make sense to generate the
big things at all? The answer was no. Every generator that builds one
self-contained thing (house, garden, tree, toilet, bridge) had worked;
nearly every bug of the last rounds came from generators deciding the
layout together - the pond, for instance, took its water level from
the land before the village levelled the land round it. So the
automatic village planner was retired, and the big ones became
builders: Test Street's layout is now written by hand in its script -
a village on level ground, a valley with the river 250 m north, three
hills with woods, a pond in a hollow, the street, two lanes and a
country road over the river - and the creators build it. The terrain
gained designed landforms (hill, hollow, valley) over a gentle noise,
a fixed stage order (natural, rivers, level areas, ponds, roads), ponds
whose level is settled when the land is built and which draw their own
shore, and woods only in areas the map marks. The old planner's useful
parts became `VillageKit` (plots along a named stretch of road,
building them, lamps, the green). Then measured rather than eyeballed:
the ground under all 21 plots is within 0.27 m of their level (the
road-bed strip at the front edge), every pond's water edge lies under
its shore, and low views along all four roads are clean.

**Test Valley, and a standing rule about ideas.** The user asked to be
told plainly when one of their ideas is technically bad - the village
planner had been one, and it should have been said before it was built.
Then Test Street was deleted and a different map designed by hand on
the current creators: Test Valley, a village in the floor of a
north-south river valley with houses on both banks and a stone arch
bridge between them. Building it found three more ordering bugs, each
measured before fixing: the land's height 0 was taken before the
valley landform existed (the village sat on a terrace 28 m above the
river); a road climbing past a plot re-shaped its garden; and plots
stepping up a slope 2 m apart fought over each other's edges. Now the
datum is taken on first read, a plot's ground belongs to the plot (no
later levelled area or road earthworks change it), and plots are
levelled a grid cell past their sides and back. Result: 22 plots, the
ground under every one within 0.27 m of its level, nothing floating.

**A river that vanished at a distance, and nicer gardens.** From far
away the river looked "not loaded yet": all its materials, water
included, had been given the prefix that culls small detail beyond
450 m, so from afar only the carved trench was left. Now only the reeds
carry it. Measuring the load time on the way found that the road verges
running on into the haze cost a second - every vertex out there asked
for the ground height, which past the detailed land meant the full
terrain calculation; occlusion is now simply off out there (roads and
river 2.5 s -> 1.0 s). The gardens: one kind of boundary all round each
plot and one height (the user's call - half hedge, half fence looked
wrong), the hedge rebuilt as rounded, trimmed sections that vary a
little, and flower beds by the front door, flower borders, benches,
bird baths, little ponds and stepping stones to the shed - flowers as
one coloured clump each rather than stalk and bloom, keeping the extra
cost at about 10 ms a garden.

**The check that said nothing floats, while houses floated.** The user
flew Test Valley and saw houses and fences hanging in the air - with
the self-test's "nothing floats" check passing. The check asked every
piece one question: does it touch something? A fence post touches its
rail, the rail the next post; a house's plinth touches its wall. A
whole fence lifted 20 cm off the ground held itself up, piece by piece.
And "on the ground" meant within 35 cm, which from a drone at
fence-height is a clear strip of sky. The new check follows each group
of touching pieces until one of them really stands on the ground
(within 10 cm), and looks under everything that stands on the ground
for more than 10 cm of air. Made strict, it found 111 hedge sections,
fence posts by the hundred, garages and front steps in Test Valley -
and, in older maps that had passed for weeks, a bridge truss standing
1.9 m beside its deck and a crane rope hanging from nothing at the
harbour, a coal bunker frame 5 m above its legs at the steelworks, and
at the mountain lake a hotel, a chapel and the cable-car stations with
their downhill side up to 12 m in the air. The cause in the village was
a grid: the land is a mesh with a point every 8 m, the plots were set
15 cm above the road and the ground under a road 12 cm below it, so the
first grid row of every plot sloped 27 cm down to the street - right
where the front steps, the drive and the garage stand. Plots now lie at
the road's bed level, and everything that stands on a creator's own
level (posts, hedges, walls, plinths, steps, lamp posts, tree trunks)
is stretched 8 cm down into the real ground beneath each of its
corners. The rule now written into the project notes: never loosen
that check to make a map pass.

**Flowers.** The beds' one-cone-per-flower clumps looked like candles.
Now there are four real clump shapes - bedding cushions dotted with
open flowers, tulips with their strap leaves and closed cups,
marguerites on stems, lupin spikes - built once and drawn as MultiMesh
like the trees, coloured per clump by the shader so one shape serves
every colour, planted tall at the back and low in front in drifts of
the garden's colours. 944 clumps, about 150k triangles, out to 110 m;
the houses-and-gardens step got 0.8 s faster, since the old cones had
been real geometry. (First render: every flower pitch black - the
compatibility renderer multiplies a MultiMesh's instance colour in even
when the mesh has none, unless it is given white ones.)

**Farmland, wires and stones.** Asked what generators were still
missing, the honest answer was: things to fill the empty grass round
the village, small things that make it lived in, and something to fly
between - not another planner. The user said build them, and five
creators came out of it, all small and self-contained, the layout
still drawn by hand in the map script. FieldCreator lays a field on
four corners: wheat, maize and rapeseed as a canopy over the land at
the crop's height with rows, a wall of stalks and tractor tramlines -
deliberately not solid, so you can skim the wheat - and ploughed,
stubble and mown fields as a layer on the ground, with round bales and
a stack by the gate. The first version sampled its surface on a grid of
its own and the land poked green patches through the ploughed field
near the river; now every field surface is cut out of the terrain's own
triangles, so it lies exactly parallel to the ground. FarmCreator puts a
farmstead on a levelled yard: a red timber barn with its doors slid
open at both ends (fly straight through, under the hay loft), a silo,
an open machine shed, the farmhouse, a tractor with a trailer of
bales. The first spot for it, up the east slope, would have needed a
lane at 20 % - it moved to the valley floor. PowerLineCreator strings
a line along a hand-laid course: wooden poles with three wires and a
stay at every corner up the road to the farm, the last wire into the
barn wall, and 36 m lattice pylons carrying six conductors and an earth
wire across the valley, every wire solid and sagging as real ones do.
StreetKit: give-way signs at the junctions, yellow place-name boards
(the village is Talbach now), a bus stop with its H sign, a letter box
and a notice board on the green, wheelie bins inside the garden gates.
RockCreator: six faceted boulder shapes drawn as MultiMesh with shared
collision hulls, half buried, on the slopes, by the river, round the
pond, and one five-metre erratic alone on a meadow. Together about
0.6 s of load time - most of it went at first into a per-pixel loop
generating a texture the meadow could borrow from the crops instead.

**Inside the wheat, and the throttle that had to be wiggled.** Flying
into a field (it doesn't collide, on purpose) showed nothing: the crop's
top faced only up and its walls only out, so from inside it simply
wasn't there. Now its top has a shaded underside and rows of stalks
stand under it - one 4 m patch of see-through stalks and leaves, copied
across the field as MultiMesh, tilted with the land. A first try with
solid stalk walls made the inside of a wheat field look like a maze of
yellow corridors; the cut-out texture with gaps between the stalks
fixed that. The bales became golden straw and yellow-green hay with
their rolled layers as rings on the ends, the plastic-wrapped ones gone.
And a radio bug the user hit on every map: after opening a world the
drone wouldn't arm until the throttle had been pushed up and back down.
The OS only reports a stick when it moves, so until then every axis
reads exactly 0.000 - and on a centred throttle channel that's 50 %,
"lower throttle to arm". The radio's first arm-switch flip also counted
as "switch already on at load". An axis that has never reported is now
unknown, not centred: the throttle reads zero and the switch off until
they move. A self-test case reproduces it first (the old code: "armed
false, throttle 0.50") and passes now.

**Generators for the old maps: town houses and industry.** Looking at
all twelve maps' pictures for what was missing, the honest answer was
mostly "use what we have" - the new trees, rocks and houses in the older
maps - plus two new creators, because they would lift several maps at
once: the city maps are all flat boxes with painted windows, and the
Factory is a few grey blocks on a slab. CityHouseCreator builds rows of
town houses in three styles a German town has side by side - around
1900 (pastel plaster, framed windows, cornices, steep roofs with
dormers, iron balconies, now and then an archway through to the
courtyard to fly through), 1950s, and modern with a set-back top floor -
with shops on the ground floor, their names on boards, awnings over the
pavement. IndustryCreator builds an estate's pieces: a sawtooth-roofed
hall with one roller door open and an overhead crane inside, docks with
lorries backed up to them, tanks in a bund, a pipe rack to fly under, a
banded chimney, grain silos with a conveyor gallery to fly up. Both went
into Test Valley first (a town on the main road north of the village,
the estate under the pylons) for the user to judge before any old map
changes. The first renders: facades in a camouflage pattern (the
weathered-concrete texture, fine on a ruin, wrong on fresh plaster - now
a plaster texture of its own) and shop windows as flat navy slabs (now
the shop-window texture the old city builder already had).

**Where the load time goes.** The user asked what limits loading -
CPU, disk, graphics card - before talking about loading dynamically.
Measured on five maps: almost all of it is the CPU, on one core (wall
time and CPU time come out the same, and there are no files to read):
4-9 s generating, 2-3 s in the first frame while the graphics driver
compiles shaders and takes the geometry, about 1 s rendering the shadow
map. Two quick wins came out of it. Parked cars cost 7-8 s in Harbour and
Construction Site: 2,900 cars, each copied into the chunk meshes with
SurfaceTool.append_from, which re-reads the source mesh every time - now
each car model's arrays are read once and copied in bulk (Harbour 6.9 s
-> 2.2 s). The first try was fast because it was empty: a packed array
kept inside a GDScript Array is a value, so appending to it appended to a
copy - the cars had vanished, and a vertex count caught it before a
screenshot did. And the generated textures (1.2 s a map, per-pixel loops)
are now kept on disk after the first run: 28 ms. Caching whole built
maps and "fly first, build the rest" are planned next.

Self-test: 562 checks, all passing. Uncommitted at the time of writing.

## Recurring engineering themes

A few patterns repeat often enough across all 13 commits to be the
actual "how this project gets built," more than any individual fix:

- **Never fix what you haven't reproduced.** Nearly every bug fix
  starts with "investigated empirically" — a temporary headless test
  script (`scripts/physics_test.gd` + a throwaway scene), always
  deleted afterward, that logs the actual physics state frame-by-frame
  rather than trusting a guess about the cause. The D-term bug and the
  `asin()` blind spot were both found *only* because frame-by-frame
  logging was used instead of multi-frame sampling, which was actively
  hiding both problems.
- **Ground subjective feel in real numbers.** "Make it snappier" or
  "make it feel real" always got anchored to something external and
  checkable — Betaflight's actual default rate curve, a real drone's
  actual mass/thrust/drag, real camera-angle conventions from beginner
  vs. racing setups — rather than tuned by feel alone.
- **Weak hardware is a design constraint, not an afterthought.**
  Renderer choice, physics tick rate, shadow defaults, procedural
  (never loaded) textures and audio, and later the sphere-vs-thin-box
  collision fix were all decided with "does this run acceptably on 4GB
  RAM and integrated graphics" as a first-class question, not a
  cleanup pass at the end.
- **Zero external assets, on principle.** No texture files, no audio
  files, no font files for the logo — everything is generated in code
  at startup. This shows up as its own genre of bug (e.g. `albedo_color`
  silently multiplying with a freshly-generated texture) that a
  traditional asset pipeline wouldn't produce.
- **Creators instead of hand-placed content (Act XVIII on).** Map
  detail is generated by seeded creators tuned in a lab - contact
  sheets for Claude, an index.html for the user - and reused by every
  map; surprises are options with a chance, never one-off placements.
  The point is as much cost as quality: describing a generator once is
  cheaper than describing every house.
- **Screenshots catch a whole category of bugs headless tests
  structurally cannot.** `--headless` never starts a real GPU context,
  so anything about how something actually *looks* (a near-black
  ground, an overlapping UI panel, whether a "room" reads as a room) is
  invisible to it. `dev_preview_capture.gd` exists specifically to close
  that gap, and did so almost immediately after being built.

## The best bugs (a highlight reel)

If the blog needs a "weirdest bug" post, these are the strongest
candidates, roughly ranked:

1. **The `asin()` blind spot** (`c55ba21`) — a drone tumbled past 90°
   read as *less* tilted than it actually was, because `asin(sin(x))`
   folds large angles back down. The fix (compare 3D up-vectors instead
   of decomposed Euler angles) is a genuinely instructive lesson about
   why attitude math should avoid extracted Euler angles near their
   singularities.
2. **The un-filtered D-term** (`d3dc3a2`) — "make the PID snappier"
   caused spin-outs, and the actual cause (angular velocity flipping
   sign every single physics step) was invisible to anything but
   frame-by-frame logging; multi-frame sampling was aliasing it into a
   false steady state.
3. **The self-multiplying albedo** (`f668055`) — a near-black ground
   that had nothing to do with lighting: an old default `albedo_color`
   silently multiplying against a brand-new procedural texture.
4. **The 2234 deg/s crash spike** (`bcc96e2`) — "the drone goes haywire
   after a crash" had a precise, measured number behind it, and the
   root cause (a 4.5cm-tall collision box, not a physics engine
   failure) is a nice concrete example of "thin shapes and continuous
   collision detection don't mix," applicable to any Godot/Bullet-style
   physics project.
5. **The drone that kept rolling after you let go** (Act VIII) — two
   causes that each looked harmless alone: engine angular damping that
   capped the achievable rate at ~70% of the command (the numbers
   matched the steady-state formula to within 2 deg/s), and an I-term
   that wound up covering the gap and kept pushing after the stick
   centered. Plus, found by the same harness: Angle mode had always
   rolled the opposite way from Acro.
6. **The joystick that lies about being centered** (`ed7e3f5`) — a
   connected-but-not-yet-reporting joystick axis reads as `0.0`, which
   a "-1..1 centered" throttle channel remaps to 50% thrust — solved the
   same way real flight controllers solve it (refuse to arm above a
   throttle safety threshold).

## Behind the scenes (didn't make it into a commit message)

Two smaller anecdotes from the last session that are true and might be
worth a paragraph, even though they're not in the git history:

- Deriving the two connecting pipes' rotation matrices for the factory
  map (`Main2.tscn`) by hand was fiddlier than expected — a `Transform3D`
  is stored as three basis column vectors, and it's easy to write a
  matrix that looks plausible but actually leaves the cylinder's height
  axis untouched (still vertical) or points it along the wrong world
  axis. Both pipes were wrong on the first attempt and corrected before
  ever committing, by re-deriving the basis vectors by hand rather than
  trusting the first guess.
- After the first real screenshots of the factory map came back, they
  were initially (and incorrectly) read as still showing leftover
  village content — trees, hills, the wrong sky. Rather than trust that
  read, the actual scene state was checked directly (which scene was
  current, whether the drone's parent was really `Main2`) — which
  confirmed the scene switch had in fact worked correctly the whole
  time, and the "village content" impression had simply been a
  misreading of the screenshot. A small example of the same
  "verify, don't guess" habit applied to a debugging session's own
  conclusions, not just the code.

## Screenshots & media available

`previews/*.png`, generated by `godot --path . -- --dev-preview`
(needs a real display — regenerate anytime the maps change, since
they go stale):

- `preview_menu.png`, `preview_settings.png` — the main menu (drone
  preview + logo) and Settings panel.
- `preview_gameplay.png`, `preview_topdown.png` — the village, at
  flight height and from directly above.
- `preview_house_outside.png`, `preview_house_inside.png` — a small
  house's door/window openings and its two-room interior.
- `preview_factory_overview.png`, `preview_factory_hall.png`,
  `preview_factory_topdown.png`, `preview_factory_rail.png`,
  `preview_factory_entrance.png` — the factory from outside, inside a
  hall, from above, the rail/tank yard, and the entrance gate/road.
- `preview_calibration.png`, `preview_drone_choice.png`,
  `preview_map_choice.png` — the new menu panels.
- `preview_school_gym.png`, `preview_school_hoop.png`,
  `preview_school_hallway.png`, `preview_school_classroom.png` — the
  third map, from spawn, facing the basketball hoop, down the
  locker-lined hallway, and in the classroom.

## Possible angles for the blog

A few ways this could split into a series, if one long post feels like
too much:

1. **"Why Godot, and what 'runs on weak hardware' actually meant in
   practice"** — the renderer/tick-rate/procedural-asset decisions in
   Origin Constraints + Recurring Themes.
2. **"The bugs only a real screenshot could catch"** — Act IV's
   albedo-multiply and UI-overlap bugs, framed around the general point
   that `--headless` has a real blind spot.
3. **"Making a sim drone fly like a real 245g quad"** — Act II/IV's
   Betaflight rate curve, quadratic drag, and Seeker3 spec-matching.
4. **"The `asin()` bug that made an upside-down drone spin forever"** —
   a self-contained deep dive on Act IV's best bug, light on
   project-specific context, portable to a general dev-blog audience.
5. **"One AI pair-programming session, 13 commits"** — a meta post about
   the project's actual build process: empirical-verification-first,
   temporary headless test scripts, commit messages written as devlog
   entries.
6. **"Making the world lie about being endless"** — Act VII's border
   rework: why a visible wall undercuts a world that's otherwise
   decorated to look boundless, and the warning-then-reset mechanic that
   replaced it.

## Keeping this up to date

This file should get a new entry (or a new Act, if it's another big
multi-part request) after each future work session — ask for it
explicitly if it doesn't happen automatically.
