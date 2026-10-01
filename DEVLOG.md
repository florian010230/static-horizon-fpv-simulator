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
