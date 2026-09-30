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
      cursor hidden in flight, 40+ FPS at spawn on every map. Phase 2 remaining: classic/KISS rate presets, replay, key/button bindings.

## Phase 2 - Sim features pilots expect (Liftoff / Velocidrone baseline)

- [x] (partly) Rates: exact Betaflight Actual formula incl. expo (Settings slider). Still open: Betaflight classic
      (RC rate / super rate / expo), KISS, Raceflight - enter the same
      numbers as on the real quad.
- [x] OSD in the FPV view (Betaflight style): timer, battery voltage,
      throttle %, speed, altitude, flight mode, arming warnings; each
      element toggleable.
- [x] Battery simulation (real packs per drone, sag, mAh; optional thrust loss).
- [x] Optional analog video look (static, slight colour noise, breakup
      near walls/far away) - on/off.
- [x] Lap timer + checkpoints, best lap saved per map/drone, ghost of the best lap.
- [ ] Replay of the last flight (record transforms, play back from a
      chase camera).
- [ ] Key/button bindings screen (arm, mode, reset, pause on radio
      switches/buttons).
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
5. [x] **Playground** (Tiny Whoop) - Low. Slides, swings, climbing
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
