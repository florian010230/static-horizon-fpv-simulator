# Static Horizon FPV Sim — notes for Claude

Free, open-source FPV drone flight simulator in Godot 4 (`gl_compatibility`
renderer). Built to run on weak hardware (4GB RAM, integrated graphics)
and fly with real FPV radios (RadioMaster Pocket, USB joystick mode).
Zero external art/audio assets — everything is procedural (textures,
motor sound, the menu's logo/font rendering, the drone models).

Read `README.md` first for how the project actually works right now
(controls, flight model, map layouts, project structure). Read
`DEVLOG.md` for the story of how it got there — the user is using it as
raw material for a blog, and it should get a new entry after any future
multi-part session, same style as the existing entries.

## Current state (as of 2026-10-02)

All work through DEVLOG Act XVII is committed. Only commit when the
user asks. Act XIV: Freestyle/Race
menu modes, personal bests, a rendered preview picture per map card,
rebuilt freestyle/whoop drone models, the visible border covering the
whole boundary, pilot aids (stick overlay, Betaflight throttle
MID/EXPO, fisheye, line-of-sight view), the "nothing floats" check.
Act XV: Race mode rebuilt (3-lap races, live gate splits, missed-gate
warning, results card with a per-track-layout top 5, timing beeps,
numbered gates), MultiGP-style gate visuals plus a roof-hung gate, all
three race tracks redesigned, a sky shader with sun/clouds (`BuiltMap.cloud_sky()`),
motor sound rebuilt as two layers (tone + prop-wash noise), map cards
that size to their content. Act XVI: the whoop became the "Static
Whoop", modelled on a current 75 mm brushless ducted whoop (75 mm,
32 g, 0802 motors, 1S 480 mAh, ~7:1 thrust-to-weight, 70 km/h estimate)
with a redone ducted-frame model; motor sound rebalanced from flight
feedback (quieter prop-wash punch, louder/brighter idle so armed
motors are audible at 0% throttle).
Act XVII (not committed): a fourth drone, "Static Race" (5" 6S race
build, 440 g, 170 km/h estimate, ~11:1 thrust-to-weight); motor
response lag, prop wash and ground effect added to the flight model;
replay/DVR (`scripts/replay.gd`, `P` to play back the last 60s); three
more radio-assignable controls (mode switch, reset, line-of-sight) done
by a Sonnet subagent and reviewed; water ripples/reflection and a
global colour grade in the shared world shader.
TODO.md is the roadmap: Phases 1 and 3 are done (12 maps), Phase 2
done, then Phase 4.
`--selftest`: ~472 checks, all passing (Act XVII; varies slightly by
which radio paths a run exercises).

InputManager is a *scene* autoload: the editor can't see its return
types, so never write `var x := InputManager.foo()` - type it
explicitly (that was a parse error in the editor once).

`godot` isn't on PATH here: use `/Applications/Godot.app/Contents/MacOS/Godot`.
`InputManager.test_joy` is a virtual radio for tests without hardware.

## Builds (2026-10-02)

`export_presets.cfg` and `builds/` are gitignored. Presets: "Windows
Desktop", "Linux", "macOS" (universal, ad-hoc signed, not notarized;
needs `import_etc2_astc=true`, already set). Templates live in
`~/Library/Application Support/Godot/export_templates/4.7.2.stable/`
(fetched piecewise from the official .tpz by HTTP range requests - the
disk is nearly full). Export: `godot --headless --path . --export-release
"macOS" builds/macos/StaticHorizonFPV.zip`; verify with the exported
binary's `--headless -- --selftest`. Release zips
`builds/StaticHorizonFPV-<ver>-<os>.zip` + `builds/README.txt`, hard-linked
into the website repo's `downloads/` (not committed there either).

## Lighting: the engine sun does nothing on the dev machine

Measured 2026-09-27: on the Intel Iris 6100 (macOS, Compatibility
renderer) a DirectionalLight3D has **zero effect** - pixel-identical
screenshots at sun energy 0 and 3, in every map (a known class of
Intel/macOS GL driver bugs, godotengine/godot#74763). Everything was
lit by ambient alone. So light is **baked into vertex colours with
unshaded materials**: `Geo.shade()` for generated maps, `LightBaker`
(scripts/light_baker.gd) for the hand-made ones (called in each
main*.gd before `Settings.apply_graphics_settings()`). Never rely on
engine lights for how a map looks; the Sun node is still needed (its
direction drives the baking, the shadow map and the drone shadow).

## Generated maps (scripts/maps/)

New maps are code, not baked .tscn content: a script extending
`BuiltMap` (environment, border, `build()`, `after_build()`,
`preview_views()`), drawing through `Geo` (batched primitives per
material and 64 m cell, collision incl. hollow pipes/towers, shadow
outlines, baked light), `Terrain`, `Forest` (MultiMesh), `MapTextures`,
and `RaceCourse` for race maps (gates + lap timing + records). The
.tscn holds only Drone (= spawn, movable in the editor) and UI. Every
map is listed once in `MapCatalog` (tier, forced drone). Add a
self-test case per map. The roadmap is TODO.md - keep it current.

The user's standing requirements for maps (2026-09-30), all built in:
- **No visible world edge**: outdoor maps use depth fog ending at the
  far plane in the sky's horizon colour (`BuiltMap`, `Settings._fit_fog`;
  `BuiltMap.apply_depth_fog` for the hand-made maps). Ground must reach
  the horizon (slabs to +-3000 m, `Terrain.far_ring`).
- **Nothing flickers**: never stack ground surfaces a few cm apart with
  plain materials - use `Geo.ground_mat`/`ground_flat` with a layer
  (0 terrain, 1 paving/ballast, 2 roads, 3 markings, 4-6 sleeper beds).
- **Things connect**: rails, roads and pipes are `Route`s (straights +
  arcs, no kinks) drawn with `Rails`/`Roads`/`Geo.pipe_path`. Rails
  never cross at angles: tracks divide through `Rails.turnout`/
  `crossover`; no 90 degree turns (R >= 120 m). Every track and road
  either leaves the map (runs on 2-3 km into the fog) or ends at a
  buffer stop / junction / gate / car park. On hilly maps, carve the
  terrain to the line's grade (see steel_mill.gd `_corridors`).
- **Scattered things are placed last**: Geo records every solid
  primitive's footprint and every road/rail lane; Fleet cars and
  Forest trees planted during build() are queued and dropped if they
  would stand inside something (BuiltMap._plant_trees, Fleet.commit).
  Use `geo.blocked()` / `geo.on_lane()` for any other scatter.
- **Cars go through `Fleet`** (BuiltMap.fleet), not Vehicles.car, when
  there are more than a handful - and keep materials shared, or every
  car becomes its own draw call. Check `SH_PERF=1` draw calls after
  big additions (aim < ~600 at spawn).
- **Nothing floats**: every solid piece must touch the ground or
  another piece - the self-test checks it (`BuiltMap.floating_pieces()`,
  backed by `Geo.floating()`, which also counts non-colliding primitives
  and route-sweep segments as support, and a rectangle-overlap test
  rather than a circle, to avoid false positives on roofs/cornices and
  long thin parts). `SH_FLOAT=1` prints flagged pieces while a map
  builds. `--dev-preview floatcheck` runs the equivalent check by mesh
  bounding box for the hand-made scene maps (village/factory/school).
- **Race tracks**: when you change a track layout, bump its
  `MapCatalog` `"track"` number (fresh records).

## Hard rules (from direct user feedback)

- **Never reposition anything in a `.tscn` file that isn't the specific
  target of your current change**, even content you or a past session
  baked in (trees, buildings, etc.). The user drags things around by
  hand in the Godot editor. Read the current file, touch only what the
  task needs. If a task seems to require moving something else, ask
  first.
- Only commit when the user explicitly asks. Never `git commit` on your
  own initiative after a work turn, even a big one.
- Only use emojis if explicitly asked (none anywhere in this project).

## Methodology this project actually follows

- **Physics-only tests are not enough.** "The drone doesn't take off"
  twice passed physics tests that set the throttle directly - the real
  bug was in the input path (a silent radio read as 50% throttle). Run
  `--selftest` (scripts/self_test.gd), which goes through the real
  input path, and extend it when a new kind of bug shows up.
- **Never trust a fix without reproducing it first.** The standard
  pattern: write `scripts/physics_test.gd` + `scenes/PhysicsTest.tscn`
  (a throwaway `Node3D` script driving one or more `Drone` instances,
  setting `InputManager.armed`/`self_level` directly, logging
  frame-by-frame state), run via
  `godot --headless --path . scenes/PhysicsTest.tscn --quit-after N`,
  then **delete both files** afterward. Frame-by-frame logging matters —
  multi-frame sampling has hidden real bugs before (D-term oscillation,
  the `asin()` blind spot) by aliasing them into a false steady state.
- **Ground subjective/tunable numbers in something real**, not feel
  alone: Betaflight's actual rate curve, a real drone's actual
  mass/thrust/drag, researched real specs for the Tiny Whoop. Cite
  sources in code comments when you look something up.
- **`--headless` never starts a real GPU context** — it's blind to
  anything visual (a bug already crushed the ground to near-black once,
  another overlapped two UI panels, another left drone arms literally
  invisible from a bad transform). For any visual change, also run
  `godot --path . -- --dev-preview` (needs a real display; see
  `scripts/dev_preview_capture.gd`) and actually look at the
  `previews/*.png` output before calling it done.
- **New scripts with `class_name` aren't visible to other scripts until
  Godot rescans the project.** After adding a new global class, run
  `godot --headless --editor --path . --quit` once to force the
  rescan/reimport (also picks up new font/image imports), *then* run
  your test — otherwise you'll get a spurious "Identifier not declared."
- **Never hand-derive a `Transform3D`'s basis columns for a rotation.**
  This project has been burned by it twice (the factory map's connecting
  pipes, then a hula-hoop gate's rotation in the school map — the second
  time while writing a comment warning against the first). Use
  `Basis.looking_at(direction, up)` for "point this local axis at a
  direction," or plain `position =` / `rotation = Vector3(rx, ry, rz)`
  (radians) properties in `.tscn` files for a simple known-angle
  rotation, instead of writing out 9 basis numbers by hand.
- **Commit messages**: heredoc-style `git commit -m "$(cat <<'EOF' ...)"`
  has intermittently failed with "unexpected EOF" in this environment.
  Write the message to a scratchpad file and use `git commit -F <path>`.
- **`.uid` sidecar files** (e.g. `drone.gd.uid`) are real Godot-managed
  files that should be committed alongside their `.gd`/`.tscn` — don't
  delete them as if they were clutter.

## Architecture cheat sheet

- Autoloads (`project.godot`): `InputManager` (radio/keyboard input +
  calibration + persistence), `Settings` (in-memory options that survive
  scene changes — crosshair/shadows/fullscreen/FPS/Acro rates/selected
  drone), `DevPreviewCapture` (no-op unless `--dev-preview` passed).
- `Drone` (`scripts/drone.gd`, `scenes/Drone.tscn`) — the flight physics
  (cascaded rate-PID with *normalized* gains x real inertia, Acro/Angle
  modes, Betaflight-style airmode + I-term relax, quadratic body drag +
  linear rotor drag). Physics runs at 120 Hz with `contact_monitor` off (contacts come from `max_contacts_reported`; the monitor tripled physics cost) - `Settings.performance_mode` switches to 240 Hz + monitor on. Prop strike only counts contacts at/above the prop disc (a whoop rests on its guards). Stick convention: every
  `InputManager` getter returns +1 = roll right/pitch forward/yaw
  right; only `drone.gd` converts to body axes - keep it that way (a
  split convention caused reversed Angle-mode roll and a wizard that
  inverted every axis). Collision is a compound of spheres (body, nose
  around the camera, one per prop - shape order matters, see
  `SHAPE_PROP_FIRST`); a prop touching something loses thrust (prop
  strike). The drone's own meshes are on render layer 20, hidden from
  its FPV camera. `PROFILES`
  holds two complete real frames (`"seeker3"`, `"whoop"`);
  `apply_profile(name)` swaps mass/thrust/drag/PID/collision *and* calls
  `DroneFrameBuilder` to rebuild the visual model from primitives. The
  scene itself carries no hand-authored visual mesh nodes anymore.
- `DroneFrameBuilder` (`scripts/drone_frame_builder.gd`) — builds the
  non-brick quad frame (arms, motor bells, prop discs, camera pod,
  antenna, optional prop guards) from primitives. Shared between the
  real `Drone` and the main menu's preview stand-in.
- `HollowBuilding` (`scripts/hollow_building.gd`) — the one reusable
  primitive behind every fly-into structure: floor/ceiling/4 walls with
  any number of doors (`*_doors`) and glazed windows (`*_windows`,
  `PackedVector4Array(offset, width, bottom, top)`), optional storeys
  and a partition. Looks come from `interior_style`/`exterior_style`
  (`scripts/building_styles.gd`); interiors are unshaded with light,
  fake AO and wall bands baked into vertex colors. Building floors sit
  at y=0.56 in outdoor maps (ground top is 0.5; flush floors z-fight
  with the grass and lose).
- Map content is baked, editable nodes. Big layout passes were
  generated by throwaway Python scripts (not kept in the repo) - edit
  the `.tscn` files directly for changes. Road/paving/gravel/field
  meshes are tagged with node groups and textured by
  `BuildingStyles.apply_ground_surfaces()`.
- `WorldBorder` (`scripts/world_border.gd`) — static-method utility
  (not a node), called once a frame from each map's own `_process()`.
  Past a warning radius/altitude it tells `ui.gd` to flash a HUD
  warning; past a reset radius/altitude it reloads the current scene.
  No map has a solid boundary collider anymore.
- Three maps: `Main.tscn`/`main.gd` (village), `Main2.tscn`/`main2.gd`
  (factory), `Main3.tscn`/`main3.gd` (school, forces the whoop profile
  regardless of menu choice). Each applies its own procedural textures
  in `_ready()` and calls `WorldBorder.check()` in `_process()`.
- Display names: the `"seeker3"` profile is shown as **Static Three** (renamed from Static One on 2026-09-27; the
  user's choice - it's modelled on a Seeker3 but isn't one); the id
  stays `"seeker3"` internally. The `"whoop"` profile is shown as
  **Static Whoop** since 2026-10-02 (modelled on a current 75 mm
  brushless ducted whoop); the id stays `"whoop"` internally. The
  `"race"` profile (added 2026-10-02, Act XVII) is shown as **Static
  Race** - a 5" race build grounded in real specs, not a specific
  product (same pattern as Static Three/Static Five - never name the
  real product the numbers were checked against).
- `Settings.graphics_quality` (Low/Medium/High) -> render scale, per-object
  draw distances, view distance; applied by `Settings.apply_graphics_settings()`
  in every map's `_ready()`.
- Menus: `UIKit` (scripts/ui_kit.gd - theme + widgets, website palette),
  `SettingsScreens` (Settings + Calibrate Radio, emits `closed`; used by
  both the main menu and the in-game `PauseMenu`, each deciding where
  Back returns to), `PauseMenu` (Esc in game, pauses the tree, created
  by ui.gd, PROCESS_MODE_ALWAYS).
- Shadows and fog: `WorldShading` (scripts/world_shading.gd) converts
  every world material at load to one shader family
  (shaders/world.gdshaderinc + world_common.gdshaderinc; ground layers
  and trees include the same common file) and renders a static sun
  shadow map ONCE per map (ortho camera along the sun, depth packed in
  RG8). Parameters are global shader uniforms (project.godot
  [shader_globals]) - no per-material setup. Engine fog and glow are
  switched off (glow cost ~40% FPS on High). NOT the sun's shadow maps
  (they render nothing on the dev machine's Intel GPU).
  `Settings.apply_shadow_setting()` runs it per map; regions come from
  BuiltMap (meta "shadow_region") / `Settings.SHADOW_REGIONS`. A runtime
  StandardMaterial3D you change every frame must carry meta
  "keep_material" (or be a DroneShadow), or the converter freezes it.
  Moving objects need meta "dynamic" (hidden from the shadow capture).
- `MainMenu.tscn`/`main_menu.gd` — everything built at runtime, no
  hand-laid-out UI in the `.tscn`, themed with the website's dark
  palette. Sub-screens are fixed-size cards (`_screen_card`) with an
  always-visible header; never add a screen as a free-growing column
  (the old Settings screen pushed its Back button off-screen). Flow: main panel -> Choose Your Drone
  -> Choose a Map; Settings has the rate-curve graph and the calibration
  wizard as sub-panels (all panels exist simultaneously, just hidden —
  don't search by button text like `"Back"` across the whole tree, it's
  ambiguous; see how `dev_preview_capture.gd` avoids this).
- `ProceduralTextures` (`scripts/procedural_textures.gd`) — every
  texture in the project, generated once at startup. Flat colors are
  used for brightly-lit exterior wall panels instead of the darker
  procedural textures (which were tuned for dim tunnel interiors and
  crush to near-black when tinted/multiplied on a bright surface — this
  has bitten the project twice).
- Companion website project at `/Users/florian/Projekte/website` (a
  separate repo) is the real brand source — logo (an artificial-horizon
  mark), Oswald font, colors. `fonts/Oswald-SemiBold.ttf` here was
  converted locally from that project's `oswald-600.woff2` via Python
  `fontTools` (already installed in this environment with brotli
  support) since Godot's `FontFile` doesn't load WOFF2 directly.
- `window/stretch/mode="canvas_items"` in `project.godot` (1600x900
  reference) — without it, all 2D UI renders in raw framebuffer pixels
  with no HiDPI awareness, so on a Retina-class display everything looks
  roughly half its intended size. This affects the whole UI layer
  (menu + in-game HUD), not just the menu.

## Testing commands

`godot` is not on PATH on the dev machine - the binary is
`/Applications/Godot.app/Contents/MacOS/Godot` (Godot 4.7).

```
# headless smoke test (catches script/parse errors, not visual bugs)
godot --headless --path . scenes/Main2.tscn --quit-after 60

# end-to-end self-test: every map x drone, real input path, takeoff,
# steering, reset, menu flow - run this after ANY gameplay/input change
godot --headless --path . -- --selftest

# force a rescan after adding a new class_name script or font/image asset
godot --headless --editor --path . --quit

# real screenshots (needs a real display); optional sections
godot --path . -- --dev-preview [menu] [village] [factory] [school]
# every map with the drone just outside its flight area: prints
# "BORDER ok/FAIL" per map (the border must show on all of them)
godot --path . -- --dev-preview borders
# render one map's menu-card preview picture (images/maps/<id>.jpg) -
# one map per run: a long run over every map sometimes rendered later
# maps half-empty
godot --path . -- --dev-preview thumbs <map id>
# check the hand-made scene maps (village/factory/school) for solid
# pieces floating above the ground, by mesh bounding box (generated
# maps get the equivalent check for free in --selftest)
godot --path . -- --dev-preview floatcheck
# the first run after new materials can show ~1 FPS stale frames
# (shader compilation) - just run it again
```
