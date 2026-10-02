# Roadmap to a public release

Written 2026-09-27 from the user's "make it public someday" list. Work
top to bottom; tick items off (`[x]`) as they land and are verified
(self-test + screenshots). Each phase is sized to fit one working
session. Keep this file current - it's the hand-off between sessions.

Research notes behind the choices are at the bottom.

## Phase 1 - Foundations (everything later builds on these)

- [x] Rename "Static One" -> **Static Three** (display name only; the
      profile id stays `seeker3` so saved settings keep working).
- [x] **Map registry** (`scripts/map_catalog.gd`): one list with id,
      scene, name, one-line description, performance tier (Low /
      Medium / High), drone restriction, preview colour. The map picker,
      pause menu, loading screen and self-test all read it - adding a
      map becomes one entry, not edits in five files.
- [x] Map picker for 12 maps: grid of cards with a tier badge and a
      filter (All / Low / Medium / High), plus a hint which tier suits
      the current graphics setting.
- [x] **Radio compatibility** (done: 10 axes/128 buttons, auto device pick, Settings picker + deadzone, unusual-layout self-test; not done: per-channel expo, gamepad-specific hints): scan all axes/buttons Godot exposes (not
      just 8/16), pick the radio automatically when several controllers
      are connected (first one that moves; selectable in Settings),
      known-radio notes (EdgeTX/OpenTX: RadioMaster, Jumper, FrSky,
      Betafpv LiteRadio, TBS Tango/Mambo, DJI FPV Remote 2 / FlySky via
      USB HID), gamepad fallback (Xbox/PS pads: standard mapping),
      per-channel deadzone + expo in Settings. Self-test with virtual
      radios of different shapes (8-axis EdgeTX, 6-axis, gamepad).

## Done along the way

- [x] Baked lighting for every map (engine sun is dead on Intel Macs -
      see CLAUDE.md). Old maps look far more 3D now.
- [x] 7. Race Arena (indoor LED gates).

All 12 maps exist. Self-test: 413 checks.
- [x] 2026-09-30: no visible world edge (depth fog), no ground flicker
      (ground layers), connected rails/roads/pipes with real turnouts,
      streets and tracks run out of every map, realistic vehicles,
      cursor hidden in flight, 40+ FPS at spawn on every map.
- [x] 2026-10-01: real sun shadows everywhere (static shadow map,
      WorldShading), cheap shader fog, glow removed, render distance
      setting, five tree species with LOD, overlap filtering for cars and
      trees, the steel mill rebuilt after the Völklinger Hütte, sunsets,
      visible border, Settings in five tabs, Betaflight/Actual/Quick/KISS
      rates per axis. Phase 2 remaining: replay, key/button bindings.
- [x] 2026-10-01 (Act XIV): Freestyle/Race menu modes (personal bests
      per map + drone, saved with the date), a rendered preview picture
      per map card (`--dev-preview thumbs <id>`), rebuilt freestyle and
      whoop drone models lit by a studio shader, the visible border
      extended to the whole boundary plus an instant respawn-at-spawn on
      reset (no more full scene reload), a tidied pause menu (Main menu
      header, Reset drone/Change map/Settings row), three researched
      pilot aids (stick overlay, Betaflight throttle
      MID/EXPO, fisheye lens) plus a line-of-sight view (`V`), honester
      front-page copy, and a "nothing floats" check for every map
      (`BuiltMap.floating_pieces()`, `--dev-preview floatcheck` for the
      hand-made maps). Self-test: 430 checks.
- [x] 2026-10-02 (Act XV): Race mode rebuilt as a real 3-lap race from a
      flying start (results card with per-track-layout top 5, saved in
      `user://race_board.cfg`; live gate splits against the best lap,
      colour-flagged good/bad; "MISSED GATE n" warning; numbered gate
      boards; synthesized timing beeps; records keyed per
      `MapCatalog "track"` number so a redesigned layout starts fresh),
      gates redesigned to look like real MultiGP hardware (pillowed
      fabric panels, piping, PVC frame, sponsor patch, weighted feet)
      plus a roof-hung `RaceCourse.hanging_gate()`, all three race
      tracks re-laid-out (Race Field's 12-gate lap, a hung gate added to
      Race Arena and Office), a sky shader with a sun disc and drifting
      clouds (`BuiltMap.cloud_sky()`, fixed a reflection-cubemap FPS
      regression along the way), motor sound rebuilt as a tone loop plus
      a separate prop-wash noise loop with an rpm-tracking low-pass
      filter (done by a Sonnet subagent, reviewed), and map-choice cards
      that size to their actual content. Self-test: 431 checks.
- [x] 2026-10-02 (Act XVI): motor sound tuned from flight feedback
      (prop-wash quieter on throttle-ups, idle volume/brightness raised
      so armed motors are audible at 0% throttle); the Tiny Whoop became
      the **Static Whoop**, modelled on a current 75 mm brushless ducted
      whoop (75 mm, 32 g, 0802 motors, 1S 480 mAh, ~7:1 thrust-to-weight,
      70 km/h estimate) instead of an invented placeholder, flying
      light and snappy instead of floaty; its frame rebuilt to match
      (closed ducts, canopy, pack holder, antenna, red bells, orange
      3-blade props), and finer surface detail added to the freestyle
      quads (stator windings, spoked bell top, lens ring, rounded
      battery, rear LED strip); self-test's indoor takeoff hold
      shortened for the whoop (School 0.6s, Office 0.7s) now that it's
      ~7:1. Self-test: 488 checks.
- [x] 2026-10-02: prop wash on/off (Settings -> Flight) and an
      assignable radio restart switch (reloads the map).
- [x] 2026-10-02 (Act XVII): a fourth drone, **Static Race** (5" 6S
      race build, not a specific product - 440 g, 170 km/h estimate,
      11:1 thrust-to-weight, 225 mm wheelbase, low frame with the pack
      strapped underneath, 45-degree camera, lime green); motor
      response lag, prop wash and ground effect added to the flight
      model, all verified with throwaway frame-by-frame physics tests;
      replay/DVR of the last 60s of flight (`P` to play back); flight
      mode / reset / line-of-sight radio bindings alongside the arm
      switch (done by a Sonnet subagent, reviewed); water ripples,
      Fresnel reflection and sun glint plus a global colour grade in
      the shared world shader. Self-test: 472 checks.

## Phase 2 - Sim features pilots expect (Liftoff / Velocidrone baseline)

- [x] Rates: Betaflight, Actual, Quick and KISS with Betaflight's own
      formulas, per axis, same numbers as the Configurator (Settings ->
      Rates). (Raceflight not done.)
- [x] OSD in the FPV view (Betaflight style): timer, battery voltage,
      throttle %, speed, altitude, flight mode, arming warnings; each
      element toggleable.
- [x] Battery simulation (real packs per drone, sag, mAh; optional thrust loss).
- [x] Optional analog video look (static, slight colour noise, breakup
      near walls/far away) - on/off.
- [x] Lap timer + checkpoints, best lap saved per map/drone, ghost of the best lap.
- [x] Freestyle/Race mode choice at the menu, with race-only timing/ghost
      and personal bests shown on the map card (Act XIV).
- [x] Stick overlay in the OSD (Settings -> Camera & HUD) (Act XIV).
- [x] Betaflight's actual throttle MID/EXPO curve, `rc.c`'s own formula
      (Settings -> Rates; Act XIV).
- [x] Fisheye lens (Flat/Light/Strong barrel distortion in the analog
      video shader; Act XIV).
- [x] Line-of-sight view (`V`): camera at the spawn point, eye height,
      following the quad (Act XIV).
- [x] 2026-10-02 (Act XVII): Replay of the last flight - always records
      the last 60s at 30 Hz, `P` to play back (pause, seek +/-5s, speed
      1/4x-2x, three camera modes), `P` again to resume flying exactly
      where it left off (`scripts/replay.gd`).
- [x] 2026-10-02 (Act XVII): Key/button bindings - besides the arm
      switch, flight mode / reset / line-of-sight can each be assigned
      to a radio switch or button in Settings -> Radio (done by a
      Sonnet subagent, reviewed); keyboard L/R/V still work either way.
- [ ] Checkpoint-style training challenges (not just race-mode laps).
- [ ] Signal-loss simulation (the real-world reason an FPV radio cuts
      out, distinct from this sim's distance-based border reset).
- [ ] Structured training / lesson plans ("plug in -> calibrate -> fly"
      goes some way; a real curriculum doesn't exist yet).
- [ ] Multiplayer / online leaderboards.
      (All four above: noted as open from the Act XIV research pass over
      Liftoff, Velocidrone, Uncrashed, DRL and TRYP FPV - see DEVLOG.)
- [x] Wind (off / light / gusty) for outdoor maps.
- [x] Settings persisted to disk (user://settings.cfg, auto-saved; off in tests).

## Phase 3 - Maps (12 total, every tier covered)

Existing, to be made more beautiful (lighting, texture variety, detail):
1. [ ] Village - Medium
2. [ ] Factory - Medium
3. [ ] School (whoop) - Low

New:
4. [x] **Abandoned Steel Mill** (first version; polish: more interior detail, rubble, puddles, graffiti, light shafts) - High. Very big, in a forest, holes in
       the walls, laid out along the real process (see research):
       rail yard with hopper wagons + torpedo cars -> ore/coal
       stockyard with ore bridge -> coke oven battery + quench tower ->
       conveyors / skip bridge -> 2 blast furnaces with hot stoves,
       dust catcher, cast house, big gas mains (fly-through pipes) ->
       BOF steel shop -> continuous caster -> long rolling mill hall ->
       finished-goods yard. Plus hyperbolic cooling tower (dive),
       chimneys/exhaust stacks, gas holder, water tower. Forest via
       MultiMesh trees. Best graphics tier: rust/concrete textures,
       baked AO, fog, glow, light shafts.
5. [x] **Playground** (whoop) - Low. Slides, swings, climbing
       frame, sandbox, tunnel tube, benches, fence, a few trees.
6. [x] **Race Track - MultiGP field** - Low. Standard 5x5 ft gates,
       start/finish gate, double gate, ladder (3 stacked), tower gate,
       dive gate, flags, hurdles; numbered course with lap timing and
       a next-gate marker.
7. [x] **Race Arena (indoor, lit gates)** - Medium. DRL-style LED gates
       in a dark hall, multi-level course.
8. [x] Whoop race - Office (Low). Small gates (~40 cm).
9. [x] Parking garage bando - Medium.
10. [x] Construction Site - High (replaced the quarry, 2026-09-30).
11. [x] Harbour & Central Station - High (rebuilt compact and dense 2026-09-30: through station with real turnouts, terminal branch, city grid).
12. [x] Mountain lake & forest - High.

Map building approach (implemented - scripts/maps/): `BuiltMap` base
(environment, border, build hook), `Geo` (batched primitives, collision,
shadow outlines, baked AO), `Terrain`, `Forest`, `MapTextures`,
`RaceCourse` (gates + lap timing, reusable for every race map). A new
map = script extending BuiltMap + a 3-node .tscn + a MapCatalog entry +
preview_views() + a self-test case.

Original note: new maps are generated at load time by a map
builder script from compact layout data (one script per map) - far
smaller and quicker than hand-baking thousands of nodes into a .tscn.
Anything the user will likely want to move by hand (gates, spawn)
stays a real node in the .tscn.

## Phase 4 - Polish for release

- [ ] Menu: map thumbnails rendered at build time, credits/licences,
      first-run tutorial ("plug in radio -> calibrate -> fly").
- [ ] Performance pass on a 4 GB / integrated GPU target per tier.
- [ ] Export presets (Windows / macOS / Linux), app icon, version.
- [ ] README rewritten as a public-facing page; DEVLOG kept for the blog.

## Research notes

- MultiGP standard gate: 5 ft x 5 ft opening (1.52 m), vinyl mesh
  panels on PVC; double gate = two stacked, ladder = three stacked and
  elevated, tower = one gate raised 5 ft; flags mark turns.
  Sources: https://shop.multigp.com/product/standard-multigp-gate-5x5/ ,
  https://www.multigp.com/multigp-drone-race-course-obstacles/
- Integrated steel works: coke ovens (coal -> coke, 14-20 h at
  ~1000 C) -> blast furnace charged from the top with ore/coke/
  limestone, hot blast from the stoves, hot metal tapped in the cast
  house into torpedo cars -> basic oxygen furnace -> continuous caster
  -> rolling mill. Sources:
  https://www.steelonthenet.com/essentials/steel-plant-equipment.html ,
  https://www.osha.gov/sic-manual/3312
- What pilots value in sims: physics that transfer to the real quad,
  matching their real rates, freestyle-friendly environments (Uncrashed's
  industrial/urban maps), racing with lap times and leagues
  (Velocidrone), customisation (Liftoff). Sources:
  https://oscarliang.com/fpv-simulator/ ,
  https://www.flightdivision.com/blog/best-fpv-simulator-2026-compared
