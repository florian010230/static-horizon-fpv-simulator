extends BuiltMap

## Village - Holderbach, a small village in a stream valley, built by the
## creators from a layout laid out here by hand (replaces the hand-made
## scenes/Main.tscn village, 2026-10-04).
##
## Layout (north = -z): the Holderbach runs north-south down a shallow
## valley west of the village. The main road comes in from the
## east-south-east, winds through the village past the church square,
## crosses the stream on a stone arch bridge and follows the west bank
## north, under the railway viaduct, into the haze. Kirchgasse leaves it
## north past the church and ends in a turning circle; the Muehlweg runs
## south toward the farm. The railway crosses the valley on a stone
## viaduct north of the village. East of the village, between the road
## and the railway, the FPV club's field (the spawn: its launch pad).
## North-east beyond the railway, on the hill's foot, the bando: an
## abandoned farmhouse and barn. Farm and fields in the south, woods on
## the hills, a pylon line far in the south.

const LAND := Rect2(-560, -560, 1120, 1120)
const CLUB := Rect2(240, -70, 150, 110) ## the club field (mown, level)
const PAD := Vector3(300, 0, 10) ## the launch pad (spawn)
const CLUB_PARK := Rect2(334, 64, 30, 18) ## the club's car park (gravel)
var _park_y: float = 0.0
const SQUARE := Rect2(10, -100, 72, 56) ## the church square
const CHURCH := Vector3(46, 0, -74) ## middle of the nave's floor
const GREEN := Vector3(-30, 0, 22)
const FARM := Vector2(130, 250)
const BANDO := Vector2(175, -405)
## The fields: crop, corners (x, z), hedgerow edges.
const FIELDS: Array = [
	["wheat", [Vector2(205, 225), Vector2(330, 232), Vector2(328, 345), Vector2(208, 350)], [2]],
	["maize", [Vector2(30, 305), Vector2(110, 300), Vector2(115, 410), Vector2(35, 415)], [3]],
	["rapeseed", [Vector2(-340, 90), Vector2(-225, 85), Vector2(-220, 230), Vector2(-335, 238)], [0]],
	["stubble", [Vector2(-360, -200), Vector2(-280, -205), Vector2(-275, -110), Vector2(-355, -105)], []],
	["ploughed", [Vector2(350, 120), Vector2(450, 115), Vector2(455, 200), Vector2(352, 205)], []],
]
## Garden gnomes (Collectibles): feet positions, filled in by build()
## from the ground there (the bando's floor, a viaduct pier's footing,
## the belfry floor) and kept for after_build (cache too).
var _gnomes: Array = []
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-38, -62, 0), "clouds": 0.5,
		"shadow_region": Rect2(-330, -470, 760, 760)}

func border() -> Array:
	return [430.0, 490.0, 250.0, 310.0, Vector2(40, -60)]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func preview_views() -> Array:
	return _views

func cacheable() -> bool:
	return true

func cache_state() -> Dictionary:
	return {"views": _views, "land": land.grid_state(), "gnomes": _gnomes}

func restore_state(state: Dictionary) -> void:
	_views = state.views
	land = TerrainCreator.from_grid_state(state.land)
	_gnomes = state.gnomes

func after_build() -> void:
	if OS.has_environment("SH_GLITCH"):
		var sg: Array = surface_glitches()
		print("GLITCH %s: %d %s" % [name, sg.size(), str(sg.slice(0, 12))])
	for i in range(_gnomes.size()):
		var g: Array = _gnomes[i]
		Collectibles.gnome(self, "village", i, Transform3D(Basis(Vector3.UP, g[1]), g[0]))

## Per-piece overrides (Pieces): fly with SH_IDS=1 to see the ids.
## Glitch check for the self-test: terrain coming up through a road or
## the railway (RoadCreator.buried). Empty on a cached load.
var _lines: Array = []

func surface_glitches() -> Array:
	var out: Array = []
	for l: LandLine in _lines:
		out.append_array(RoadCreator.buried(land, l, LAND.grow(-16.0)))
	return out

func pieces() -> Dictionary:
	return {}

## Level ground for a yard at its own natural height (like FarmCreator.plan).
func _yard(c: Vector2, size: Vector2, yaw_dir: Vector2 = Vector2(1, 0)) -> float:
	var sum: float = 0.0
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			sum += land.staged(c.x + fx * size.x, c.y + fz * size.y, TerrainCreator.RIVERS)
	var y: float = snappedf(sum / 9.0, 0.1)
	var m: float = land.road_bed()
	land.flat_plot(c, yaw_dir, size.x * 0.5 + m, size.y * 0.5 + m, y, 25.0, [c, size.x * 0.5, size.y * 0.5])
	land.keep_clear(c, size.length() * 0.5 + 8.0, true)
	return y

func build() -> void:
	var t0: int = Time.get_ticks_msec()
	# --- the land ---
	land = TerrainCreator.make(44, "gentle")
	land.set_extent(LAND)
	land.flat_circle(Vector2(40, -10), 120.0, 0.0, 80.0) # the village (the datum)
	land.flat_rect(CLUB, 0.0, 50.0)
	land.flat_rect(SQUARE, 0.0, 20.0)
	land.valley(Vector2(-260, -1500), Vector2(-60, 1500), 170.0, 11.0)
	land.hill(Vector2(330, -580), 230.0, 28.0)
	land.hill(Vector2(-520, -80), 230.0, 24.0)
	land.hill(Vector2(430, 400), 200.0, 16.0)
	land.keep_clear(Vector2(CLUB.get_center()), 100.0, true)
	land.keep_clear(Vector2(SQUARE.get_center()), 45.0, true)
	land.keep_clear(Vector2(GREEN.x, GREEN.z), 22.0, true)
	land.keep_clear(Vector2(40, -10), 150.0)
	var farm: Dictionary = FarmCreator.plan(land, FARM, Vector2(64, 48), -1.0)
	var bando_y: float = _yard(BANDO, Vector2(46, 40))
	var avoid: Array = []
	for fd: Array in FIELDS:
		land.keep_clear_poly(FieldCreator.poly(fd[1]))
		avoid.append(FieldCreator.poly(fd[1]))
	# --- water, railway, roads ---
	var river := RiverCreator.plan(land, [Vector2(-300, -1500), Vector2(-215, -520), Vector2(-178, -260), Vector2(-150, -60), Vector2(-132, 120), Vector2(-100, 330), Vector2(-40, 560), Vector2(60, 1500)], 9.0, {"seed": 3, "meander": 16.0})
	var rail := RailCreator.plan(land, Vector3(-1600, 0, -300), 0.0, [Vector2(-600, -300), Vector2(-100, -305), Vector2(300, -300), Vector2(700, -270), Vector2(1600, -190)], {"hold": [[Vector2(-170, -303), 2.5, 260.0]]})
	var main := RoadCreator.plan(land, Vector3(1600, 0, 520), -169.0, [Vector2(450, 300), Vector2(280, 190), Vector2(170, 80), Vector2(90, 12), Vector2(0, -22), Vector2(-80, -32), Vector2(-200, -75), Vector2(-240, -200), Vector2(-258, -420), Vector2(-320, -1500)], 6.5, {"radius": 90.0, "bridge": "arch"})
	var kirch := RoadCreator.branch(land, main, Vector2(120, 34), 1.0, [Vector2(135, -50), Vector2(150, -150)], 5.5, {"end": "turning", "radius": 60.0, "lead": 20.0})
	var muehl := RoadCreator.branch(land, main, Vector2(40, -8), -1.0, [Vector2(30, 80), Vector2(40, 180)], 5.0, {"end": "turning", "radius": 60.0, "lead": 20.0})
	var farm_lane := RoadCreator.branch(land, main, Vector2(215, 135), -1.0, [Vector2(175, 205), Vector2(FARM.x + 40.0, FARM.y)], 4.5, {"end": "turning", "radius": 40.0, "lead": 12.0})
	var club_lane := RoadCreator.branch(land, main, Vector2(330, 222), 1.0, [Vector2(330, 120), Vector2(325, 70)], 4.5, {"end": "turning", "radius": 40.0, "lead": 12.0})
	# The club's car park, level with the lane's turning circle beside it
	# (the hillside and the lane's bank rose through its gravel).
	_park_y = club_lane.line.pts[-1].y
	var pc: Vector2 = CLUB_PARK.get_center()
	var pm: float = land.road_bed()
	land.flat_plot(pc, Vector2(1, 0), CLUB_PARK.size.x * 0.5 + pm, CLUB_PARK.size.y * 0.5 + pm, _park_y, 12.0, [pc, CLUB_PARK.size.x * 0.5, CLUB_PARK.size.y * 0.5])
	# --- plots ---
	var plots: Array = []
	var m0: float = main.dist_at(Vector2(205, 115))
	var m1: float = main.dist_at(Vector2(0, -22)) # (west of here the road falls 7 % to the bridge: plots there lifted the terrain over its edge)
	VillageKit.plots_along(land, main, m0, m1, 1.0, plots)
	VillageKit.plots_along(land, main, m0, m1, -1.0, plots)
	VillageKit.plots_along(land, kirch, 14.0, kirch.line.length() - 12.0, -1.0, plots)
	VillageKit.plots_along(land, kirch, 14.0, kirch.line.length() - 12.0, 1.0, plots)
	VillageKit.plots_along(land, muehl, 14.0, muehl.line.length() - 12.0, -1.0, plots)
	var w0: float = main.dist_at(Vector2(-222, -110))
	VillageKit.plots_along(land, main, w0, main.dist_at(Vector2(-248, -235)), -1.0, plots) # across the bridge
	var t1: int = Time.get_ticks_msec()
	land.build(self, geo, LAND)
	for rd: RoadCreator in [main, kirch, muehl, farm_lane, club_lane]:
		_lines.append(rd.line)
	_lines.append(rail.line)
	var t2: int = Time.get_ticks_msec()
	# --- drawing ---
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 45
	var roads := Roads.new(geo, lrng)
	var rinfo: Dictionary = river.draw(geo, LAND, lrng)
	var road_views: Array = []
	for rd: RoadCreator in [main, kirch, muehl, farm_lane, club_lane]:
		road_views.append_array(rd.draw(geo, roads, lrng).views)
	var rails := Rails.new(geo)
	var rail_info: Dictionary = rail.draw(geo, rails, lrng)
	# A goods train standing on the viaduct.
	var rr: Route = rail_info.route
	rails.train(rr, rail.dist_at(Vector2(-250, -303)), ["loco", "box", "box", "tank", "tank", "tank", "hopper", "hopper"], lrng)
	VillageKit.lamps(roads, main, m0, m1, 32.0)
	VillageKit.lamps(roads, kirch, 10.0, kirch.line.length() - 10.0, 30.0)
	VillageKit.lamps(roads, muehl, 10.0, muehl.line.length() - 10.0, 30.0)
	var trees: Array = VillageKit.green(geo, Vector3(GREEN.x, land.ground(GREEN.x, GREEN.z), GREEN.z))
	var t3: int = Time.get_ticks_msec()
	var vinfo: Dictionary = VillageKit.build_plots(geo, plots, 52)
	var t4: int = Time.get_ticks_msec()
	trees.append_array(vinfo.trees)
	# --- street furniture ---
	var street_views: Array = []
	for br: RoadCreator in [kirch, muehl, farm_lane, club_lane]:
		StreetKit.give_way(geo, br)
	street_views.append_array(StreetKit.town_sign(geo, main, main.dist_at(Vector2(255, 170)), 1.0, "Holderbach", "Gemeinde Talheim"))
	StreetKit.town_sign(geo, main, main.dist_at(Vector2(-228, -150)), -1.0, "Holderbach", "Gemeinde Talheim")
	street_views.append_array(StreetKit.bus_stop(geo, main, main.dist_at(Vector2(60, 0)), -1.0, "Holderbach Kirche"))
	# --- the church square and the church ---
	var church_views: Array = _church_square(roads)
	# --- the club field ---
	var club_views: Array = _club(trees)
	# --- the bando ---
	if OS.has_environment("SH_PERF"):
		print("BANDO level %.2f ground %.2f; pad ground %.2f, gate %.2f" % [bando_y, land.ground(BANDO.x, BANDO.y), land.ground(PAD.x, PAD.z), land.ground(278, 4)])
	var bando_views: Array = _bando(Vector3(BANDO.x, bando_y, BANDO.y), lrng)
	trees.append_array(_square_trees)
	# A gnome on a viaduct pier's footing, by the stream.
	if not rail.piers.is_empty():
		var best: Array = rail.piers[0]
		for pr: Array in rail.piers:
			if (pr[0] as Vector3).distance_to(Vector3(-200, 0, -300)) < (best[0] as Vector3).distance_to(Vector3(-200, 0, -300)):
				best = pr
		var pt: Vector3 = best[1]
		var gpos: Vector3 = (best[0] as Vector3) + Vector3(-pt.z, 0, pt.x) * (RailCreator.HALF + 0.75)
		gpos.y = land.ground(gpos.x, gpos.z)
		_gnomes.append([gpos, atan2(pt.x, pt.z)])
		rail_info.views.append(["gnome_viaduct", gpos + Vector3(-pt.z, 0, pt.x) * 4.0 + pt * 2.0 + Vector3(0, 1.2, 0), gpos])
	# --- farmland ---
	var fv: Dictionary = FarmCreator.build(geo, land, farm, 81)
	trees.append_array(fv.trees)
	var farm_views: Array = fv.views
	for fd: Array in FIELDS:
		var fc := Vector3.ZERO
		for q: Vector2 in fd[1]:
			fc += Vector3(q.x, 0, q.y) * 0.25
		var fid: String = Pieces.id_at("field", fc)
		var fov: Dictionary = Pieces.override(geo, fid)
		var fr_rng := RandomNumberGenerator.new()
		fr_rng.seed = fov.get("seed", Pieces.seed_of(fid, 61))
		var fy: float = land.ground(fc.x, fc.z)
		Pieces.begin(geo, fid, fc + Vector3(0, fy + 8.0, 0), [fc + Vector3(-40.0, fy + 25.0, 40.0), fc + Vector3(0, fy, 0)])
		var fi: Dictionary = FieldCreator.build(geo, land, fd[1], fov.get("crop", fd[0]), fr_rng, {"hedges": fd[2]})
		Pieces.end(geo, fid, fi.trees)
		trees.append_array(fi.trees)
		farm_views.append_array(fi.views)
	# --- power lines ---
	var line_views: Array = []
	line_views.append_array(PowerLineCreator.build(geo, land, [Vector2(620, 352), Vector2(445, 290), Vector2(292, 178), Vector2(214, 112)], "poles").views)
	line_views.append_array(PowerLineCreator.build(geo, land, [Vector2(-600, 480), Vector2(-150, 468), Vector2(250, 470), Vector2(600, 450)], "pylons").views)
	# --- rocks, before the trees ---
	var rk := RandomNumberGenerator.new()
	rk.seed = 71
	var rocks: Dictionary = RockCreator.scatter(self, geo, land, rk, [
		[Vector2(-420, -120), 90.0, 24, 0.5, 2.8],
		[Vector2(330, -470), 90.0, 22, 0.6, 3.2],
		[Vector2(-175, -200), 60.0, 14, 0.3, 1.2], # stones along the stream
		[Vector2(BANDO.x + 40.0, BANDO.y - 25.0), 25.0, 6, 0.4, 1.4],
	], avoid)
	var woods: Array = [[Vector2(-470, -60), 170.0], [Vector2(330, -540), 200.0], [Vector2(460, 420), 150.0], [Vector2(-420, 400), 140.0], [Vector2(-330, -460), 120.0]]
	trees.append_array(land.woods(lrng, LAND.grow(-60.0), 2200, 110.0, woods))
	var info: Dictionary = TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("VILLAGE plan %d ms, land %d ms, river+roads+rail %d ms, houses %d ms (%d plots, %d open), rest %d ms, trees %d" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3, plots.size(), vinfo.open, Time.get_ticks_msec() - t4, info.kept])
	# --- preview views ---
	_views.append(["overview", Vector3(420, 95, 260), Vector3(20, 0, -80)])
	_views.append(["top", Vector3(40, 420, -59), Vector3(40, 0, -60)])
	_views.append(["spawn_view", PAD + Vector3(0, 2.0, 6.0), PAD + Vector3(-60, 3.0, -10.0)])
	_views.append(["main_street", Vector3(150, 4.0, 62), Vector3(60, 2.0, -5)])
	_views.append(["from_south", Vector3(60, 30, 260), Vector3(40, 0, -60)])
	_views.append_array(church_views)
	_views.append_array(club_views)
	_views.append_array(bando_views)
	_views.append_array(rail_info.views)
	_views.append_array(vinfo.views)
	for k in [2, 6, 10, 15]:
		if k < plots.size():
			var fr: Transform3D = plots[k].frame
			_views.append(["plot%d" % k, fr * Vector3(-16, 9, 8), fr * Vector3(0, 0, -15)])
			_views.append(["low%d" % k, fr * Vector3(-15, 1.1, 5), fr * Vector3(2, 0.6, -12)])
	_views.append_array(farm_views)
	_views.append_array(line_views)
	_views.append_array(street_views)
	_views.append_array(rinfo.views)
	_views.append_array(road_views)
	_views.append_array(rocks.views)
	var shown: Dictionary = {}
	for e: Array in info.extras:
		if not shown.has(e[0]):
			shown[e[0]] = true
			_views.append(["tree_" + e[0], e[2], e[1]])
	if OS.has_environment("SH_ROADCHECK"):
		_views.clear()
		for rd: RoadCreator in [main, kirch, muehl, farm_lane, club_lane]:
			var rp: Array[Vector3] = rd.line.pts
			for i in range(0, rp.size() - 6, 10):
				if not LAND.grow(60.0).has_point(Vector2(rp[i].x, rp[i].z)):
					continue
				var a: Vector3 = rp[i]
				var b: Vector3 = rp[i + 5]
				var sd: Vector3 = Vector3(-(b - a).z, 0, (b - a).x).normalized() * 5.0
				_views.append(["road%02d_%03d" % [_views.size(), i], a + sd + Vector3(0, 1.6, 0), b + Vector3(0, 0.3, 0)])

# --- materials -------------------------------------------------------------------

func _materials() -> void:
	if geo.has_material("vg_plaster"):
		return
	geo.add_material("vg_plaster", Geo.tex_mat(MapTextures.get_tex("plaster"), Color(1.08, 1.06, 1.0), 3.0))
	geo.add_material("vg_stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(1.1, 1.05, 0.95), 1.6))
	geo.add_material("vg_roof", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color(0.95, 0.75, 0.68), 2.0))
	geo.add_material("vg_slate", Geo.flat_mat(Color(0.3, 0.36, 0.38), 0.7))
	geo.add_material("vg_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.9, 0.78, 0.62), 1.2))
	geo.add_material("vg_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.05, 0.92, 0.85), 2.5))
	geo.add_material("vg_paint", Geo.flat_mat(Color.WHITE, 0.5))
	geo.add_material("vg_glass", Geo.flat_mat(Color(0.5, 0.62, 0.7), 0.1, 0.3))
	geo.add_material("vg_lamp", Geo.flat_mat(Color(1.5, 1.4, 1.1), 0.5))
	geo.add_material("vg_paving", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color(1.05, 1.02, 0.96), 3.0, 1, 0.2))
	geo.add_material("vg_gravel", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(1.0, 0.95, 0.85), 2.5, 1, 0.3))
	geo.add_material("vg_mat", Geo.ground_flat(Color(0.16, 0.17, 0.18), 3))
	# Inside the church and the ruin: lit by the build (light_fn), not
	# darkened again by the sun's shadow map under their roofs.
	geo.add_material("vgi_plaster", Geo.tex_mat(MapTextures.get_tex("plaster"), Color(1.0, 0.98, 0.94), 3.0))
	geo.add_material("vgi_floor", Geo.tex_mat(MapTextures.get_tex("paving_slabs"), Color(0.95, 0.9, 0.82), 2.0))
	geo.add_material("vgi_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.85, 0.68, 0.5), 1.2))
	geo.add_material("vgi_paint", Geo.flat_mat(Color.WHITE, 0.5))
	for m in ["vgi_plaster", "vgi_floor", "vgi_wood", "vgi_paint", "vg_lamp"]:
		geo.material(m).set_meta("no_shadow", true)
	geo.detail_prefixes.append("vgi_")

## Light for inside a building: dim daylight, darker low down and in
## corners - set as geo.light_fn while an interior is drawn.
func _inside_light(level: float, strength: float) -> Callable:
	return func(n: Vector3, p: Vector3) -> Color:
		var up: float = 0.5 + 0.5 * n.y
		var f: float = clampf((p.y - level) / 4.0, 0.0, 1.0)
		var v: float = strength * (0.62 + 0.18 * up) * lerpf(0.75, 1.0, f)
		return Color(v * 1.04, v, v * 0.92)

# --- the church ------------------------------------------------------------------

## Church on the square: nave (east-west, the altar east), west tower with
## a hollow shaft - fly in the tower door, up the shaft, through the hatch
## into the belfry, out through its arches -, the nave open through the
## south porch door and the arch from the tower. Square: paving, a
## fountain, a lime tree, benches, a path down to the main road.
## Real numbers: village church nave ~20-25 m x 10-12 m, eaves ~9 m;
## west tower 6 m square, 30-35 m to the cornice, spire to 45-50 m;
## belfry openings 1-1.3 m wide.
func _church_square(_roads: Roads) -> Array:
	_materials()
	var views: Array = []
	var y0: float = 0.0
	geo.polygon([Vector3(SQUARE.position.x, y0 + 0.03, SQUARE.position.y), Vector3(SQUARE.end.x, y0 + 0.03, SQUARE.position.y),
		Vector3(SQUARE.end.x, y0 + 0.03, SQUARE.end.y), Vector3(SQUARE.position.x, y0 + 0.03, SQUARE.end.y)], "vg_paving", false)
	# Path from the square down to the main road.
	var road_z: float = -16.0
	geo.polygon([Vector3(38, land.ground(38, SQUARE.end.y) + 0.03, SQUARE.end.y), Vector3(44, land.ground(44, SQUARE.end.y) + 0.03, SQUARE.end.y),
		Vector3(44, land.ground(44, road_z) + 0.03, road_z), Vector3(38, land.ground(38, road_z) + 0.03, road_z)], "vg_paving", false)
	var xf := Transform3D(Basis(), CHURCH)
	var L: float = 22.0
	var B: float = 11.0
	var T: float = 0.8
	var H: float = 9.0
	# Floor inside.
	geo.light_fn = _inside_light(y0, 1.0)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(L - T, 0.16, B - T), "vgi_floor")
	geo.light_fn = Callable()
	# Walls: long walls along x (the frame), end walls turned.
	var south := xf * Transform3D(Basis(), Vector3(0, 0, B * 0.5 - T * 0.5))
	var north := xf * Transform3D(Basis(), Vector3(0, 0, -B * 0.5 + T * 0.5))
	var wins: Array = []
	for wx in [-3.5, 1.5, 6.5]:
		wins.append(Rect2(wx - 0.8, 3.2, 1.6, 4.4))
	BuildKit.wall(geo, south, -L * 0.5, L * 0.5, y0, H, T, wins + [Rect2(-8.6, 0.2, 2.4, 3.4)], "vg_plaster", y0)
	BuildKit.wall(geo, north, -L * 0.5, L * 0.5, y0, H, T, wins.duplicate(), "vg_plaster", y0)
	var east := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(L * 0.5 - T * 0.5, 0, 0))
	var west := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-L * 0.5 + T * 0.5, 0, 0))
	BuildKit.wall(geo, east, -B * 0.5 + T, B * 0.5 - T, y0, H, T, [Rect2(-1.0, 4.0, 2.0, 3.2)], "vg_plaster", y0)
	BuildKit.wall(geo, west, -B * 0.5 + T, B * 0.5 - T, y0, H, T, [Rect2(-1.5, 0.2, 3.0, 5.0)], "vg_plaster", y0)
	# Glass in the windows (and a frame bar), recessed a little.
	for w: Rect2 in wins:
		for wall_xf: Transform3D in [south, north]:
			geo.box_xf(wall_xf * Transform3D(Basis(), Vector3(w.get_center().x, w.get_center().y, 0)), Vector3(w.size.x, w.size.y, 0.06), "vg_glass")
			geo.box_xf(wall_xf * Transform3D(Basis(), Vector3(w.get_center().x, w.get_center().y, 0)), Vector3(0.08, w.size.y, 0.12), "vg_stone", false)
	geo.box_xf(east * Transform3D(Basis(), Vector3(0, 5.6, 0)), Vector3(2.0, 3.2, 0.06), "vg_glass")
	# Plinth band and cornice.
	geo.tint = Color(0.85, 0.8, 0.72)
	for wall_xf: Transform3D in [south, north]:
		geo.box_xf(wall_xf * Transform3D(Basis(), Vector3(0, H - 0.25, 0)), Vector3(L + 0.3, 0.4, T + 0.3), "vg_stone", false) # (top 5 cm under the wall's: level with it, they flickered)
	geo.tint = Color.WHITE
	# Gable over the east end, the roof (ridge along x).
	var pitch: float = deg_to_rad(50.0)
	BuildKit.gable(geo, east, -B * 0.5, B * 0.5, H, B * 0.5 * tan(pitch), T, "vg_plaster")
	BuildKit.gable(geo, west, -B * 0.5, B * 0.5, H, B * 0.5 * tan(pitch), T, "vg_plaster")
	BuildKit.roof(geo, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.6, 0, 0)), B * 0.5, L + 1.2, H, pitch, 0.25, 0.6, "vg_roof")
	# Porch over the south door.
	var pc := Vector3(-7.4, 0, B * 0.5 + 1.6)
	geo.box_on(xf * Transform3D(Basis(), pc + Vector3(-1.7, 1.6, 0)), Vector3(0.5, 3.2, 3.2), "vg_plaster", y0)
	geo.box_on(xf * Transform3D(Basis(), pc + Vector3(1.7, 1.6, 0)), Vector3(0.5, 3.2, 3.2), "vg_plaster", y0)
	BuildKit.roof(geo, xf * Transform3D(Basis(), pc + Vector3(0, 0, 0)), 1.95, 3.6, 3.2, deg_to_rad(40.0), 0.15, 0.2, "vg_roof")
	# Inside: pews either side of the aisle, the altar on its step, two
	# hanging lamps, the pulpit.
	geo.light_fn = _inside_light(y0, 0.95)
	for k in range(8):
		var px: float = -7.0 + k * 1.6
		for side in [-1.0, 1.0]:
			var pz: float = side * 2.6
			geo.box_xf(xf * Transform3D(Basis(), Vector3(px, 0.62, pz)), Vector3(0.45, 0.07, 3.4), "vgi_wood")
			geo.box_xf(xf * Transform3D(Basis(), Vector3(px - 0.25, 0.85, pz)), Vector3(0.06, 0.55, 3.4), "vgi_wood")
			for e in [-1.6, 1.6]:
				geo.box_xf(xf * Transform3D(Basis(), Vector3(px - 0.05, 0.5, pz + e)), Vector3(0.6, 0.7, 0.06), "vgi_wood")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(8.6, 0.25, 0)), Vector3(3.2, 0.2, B - T * 2.0 - 0.2), "vgi_floor")
	geo.tint = Color(0.95, 0.94, 0.9)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(9.2, 0.85, 0)), Vector3(1.0, 1.0, 2.4), "vgi_paint")
	geo.tint = Color(0.85, 0.7, 0.25)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(9.2, 1.4, 0)), Vector3(0.12, 0.6, 0.06), "vgi_paint", false)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(9.2, 1.55, 0)), Vector3(0.12, 0.06, 0.35), "vgi_paint", false)
	geo.tint = Color.WHITE
	geo.box_xf(xf * Transform3D(Basis(), Vector3(5.5, 1.6, -B * 0.5 + T + 0.6)), Vector3(1.0, 1.2, 1.0), "vgi_wood")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(5.5, 0.5, -B * 0.5 + T + 0.6)), Vector3(0.4, 1.0, 0.4), "vgi_wood")
	for lx in [-4.0, 3.0]:
		geo.cylinder(xf * Vector3(lx, H + 1.5, 0), xf * Vector3(lx, 5.6, 0), 0.02, "vgi_paint", 4, false)
		geo.tint = Color(0.75, 0.6, 0.3)
		geo.cylinder(xf * Vector3(lx, 5.5, 0), xf * Vector3(lx, 5.65, 0), 0.7, "vgi_paint", 12, false)
		geo.tint = Color.WHITE
		for k in range(6):
			var a: float = TAU * k / 6.0
			geo.cylinder(xf * Vector3(lx + cos(a) * 0.65, 5.65, sin(a) * 0.65), xf * Vector3(lx + cos(a) * 0.65, 5.85, sin(a) * 0.65), 0.04, "vg_lamp", 6, false)
	geo.light_fn = Callable()
	# The tower at the west end: hollow shaft, door to the west, arch to the nave.
	var tw: float = 6.4
	var tt: float = 0.9
	var tc := Vector3(-L * 0.5 - tw * 0.5 + tt, 0, 0)
	var top: float = 31.0
	var bel0: float = 24.5
	var bel1: float = 28.6
	var openings: Array = [Rect2(-2.1, bel0, 1.2, bel1 - bel0), Rect2(0.9, bel0, 1.2, bel1 - bel0)]
	for k in range(4):
		var a: float = PI * 0.5 * k
		var dirv := Vector3(cos(a), 0, sin(a))
		var wxf := xf * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), tc + dirv * (tw * 0.5 - tt * 0.5))
		var holes: Array = openings.duplicate()
		if k == 2: # west face: the door
			holes.append(Rect2(-1.3, 0.16, 2.6, 3.8))
			holes.append(Rect2(-0.5, 14.0, 1.0, 1.8))
		elif k == 0: # east face: inside the nave's roof below, a window above it
			holes.append(Rect2(-0.5, 18.0, 1.0, 1.6))
		else:
			holes.append(Rect2(-0.5, 9.0, 1.0, 1.8))
		var hw: float = tw * 0.5 - (tt if k % 2 == 1 else 0.0)
		BuildKit.wall(geo, wxf, -hw, hw, y0, top, tt, holes, "vg_plaster", y0)
		# Clock face.
		var clock: Vector3 = xf * (tc + dirv * (tw * 0.5 + 0.06) + Vector3(0, 21.0, 0))
		geo.tint = Color(0.15, 0.2, 0.3)
		geo.disc(clock, xf.basis * dirv, 1.15, "vg_paint", 20)
		geo.tint = Color(0.95, 0.95, 0.9)
		geo.disc(clock + xf.basis * dirv * 0.02, xf.basis * dirv, 1.0, "vg_paint", 20)
		geo.tint = Color(0.1, 0.1, 0.1)
		var side := Vector3(-dirv.z, 0, dirv.x)
		geo.beam(clock + dirv * 0.05, clock + dirv * 0.05 + Vector3(0, 0.75, 0), Vector2(0.06, 0.03), "vg_paint", false)
		geo.beam(clock + dirv * 0.05, clock + dirv * 0.05 + side * 0.5 - Vector3(0, 0.2, 0), Vector2(0.08, 0.03), "vg_paint", false)
		geo.tint = Color.WHITE
	# Cornice and the corner stones.
	geo.tint = Color(0.85, 0.8, 0.72)
	geo.box_xf(xf * Transform3D(Basis(), tc + Vector3(0, top + 0.2, 0)), Vector3(tw + 0.5, 0.4, tw + 0.5), "vg_stone")
	geo.box_xf(xf * Transform3D(Basis(), tc + Vector3(0, bel0 - 0.25, 0)), Vector3(tw + 0.3, 0.3, tw + 0.3), "vg_stone", false)
	geo.tint = Color.WHITE
	# The belfry floor with its hatch (north-west corner), the bell on its beam.
	var inner: float = tw * 0.5 - tt
	var fy: float = bel0 - 0.3
	geo.box_xf(xf * Transform3D(Basis(), tc + Vector3(0.6, fy, 0)), Vector3(inner * 2.0 - 1.2, 0.25, inner * 2.0), "vg_wood")
	geo.box_xf(xf * Transform3D(Basis(), tc + Vector3(-inner + 0.6, fy, 0.9)), Vector3(1.2, 0.25, inner * 2.0 - 1.8), "vg_wood")
	geo.beam(xf * (tc + Vector3(0, 28.2, -inner)), xf * (tc + Vector3(0, 28.2, inner)), Vector2(0.3, 0.3), "vg_wood")
	geo.tint = Color(0.62, 0.48, 0.25)
	geo.lathe_xf(xf * Transform3D(Basis(), tc + Vector3(0, 26.6, 0)), [Vector2(0.0, 1.45), Vector2(0.32, 1.45), Vector2(0.42, 1.2), Vector2(0.48, 0.6), Vector2(0.62, 0.15), Vector2(0.72, 0.0)], "vg_paint", 16, false)
	geo.tint = Color.WHITE
	geo.cylinder(xf * (tc + Vector3(0, 28.05, 0)), xf * (tc + Vector3(0, 28.2, 0)), 0.08, "vg_paint", 6, false)
	# The spire: an octagonal slate cone with a gilt ball and cross.
	geo.cone(xf * (tc + Vector3(0, top + 0.4, 0)), xf * (tc + Vector3(0, top + 15.0, 0)), tw * 0.55, 0.15, "vg_slate", 8)
	geo.tint = Color(0.95, 0.75, 0.25)
	geo.cylinder(xf * (tc + Vector3(0, top + 15.0, 0)), xf * (tc + Vector3(0, top + 17.4, 0)), 0.05, "vg_paint", 6, false)
	geo.cylinder(xf * (tc + Vector3(0, top + 16.6, -0.5)), xf * (tc + Vector3(0, top + 16.6, 0.5)), 0.04, "vg_paint", 6, false)
	geo.lathe_xf(xf * Transform3D(Basis(), tc + Vector3(0, top + 15.4, 0)), [Vector2(0.0, 0.3), Vector2(0.15, 0.25), Vector2(0.2, 0.1), Vector2(0.15, -0.05), Vector2(0.0, -0.1)], "vg_paint", 10, false)
	geo.tint = Color.WHITE
	# The gnome waits by the bell.
	var bg: Vector3 = xf * (tc + Vector3(1.6, fy + 0.125, -1.4))
	_gnomes.append([bg, 2.4])
	# --- the square ---
	# Fountain: a round stone basin with a column.
	var fc := Vector3(30, y0, -56)
	geo.lathe(fc, [Vector2(2.4, 0.0), Vector2(2.4, 0.6), Vector2(2.1, 0.6), Vector2(2.1, 0.25), Vector2(0.0, 0.25)], "vg_stone", 24)
	geo.cylinder(fc, fc + Vector3(0, 1.8, 0), 0.25, "vg_stone", 10)
	geo.cylinder(fc + Vector3(0, 1.8, 0), fc + Vector3(0, 2.0, 0), 0.5, "vg_stone", 12)
	geo.tint = Color(0.6, 0.85, 0.95)
	geo.cylinder(fc + Vector3(0, 0.25, 0), fc + Vector3(0, 0.5, 0), 2.1, "vg_glass", 24, false)
	geo.tint = Color.WHITE
	for b: Array in [[Vector3(18, y0, -60), PI * 0.5], [Vector3(60, y0, -52), 0.0], [Vector3(70, y0, -52), 0.0]]:
		var p: Vector3 = b[0]
		geo.box(p + Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), "vg_wood", b[1])
		geo.box(p + Vector3(0, 0.75, 0) + Basis(Vector3.UP, b[1]) * Vector3(0, 0, -0.22), Vector3(1.8, 0.4, 0.06), "vg_wood", b[1])
		for sx in [-0.8, 0.8]:
			geo.box(p + Vector3(0, 0.22, 0) + Basis(Vector3.UP, b[1]) * Vector3(sx, 0, 0), Vector3(0.08, 0.44, 0.45), "vg_wood", b[1])
	_square_trees = [[Vector3(20, y0, -84), "maple", 501, "none"], [Vector3(76, y0, -50), "maple", 502, "none"], [Vector3(16, y0, -50), "birch", 503, "none"]]
	var tower_w: Vector3 = xf * tc
	views.append(["church", Vector3(CHURCH.x + 45, 18, CHURCH.z + 40), CHURCH + Vector3(-6, 10, 0)])
	views.append(["church_square", Vector3(60, 2.2, -48), Vector3(30, 4, -70)])
	views.append(["church_inside", xf * Vector3(-8.0, 2.0, 0), xf * Vector3(9.0, 1.5, 0)])
	views.append(["church_porch", xf * Vector3(-7.4, 1.8, B * 0.5 + 7.0), xf * Vector3(-7.4, 1.6, 0)])
	views.append(["tower_door", tower_w + Vector3(-12, 2.0, 0), tower_w + Vector3(0, 2.0, 0)])
	views.append(["tower_shaft", tower_w + Vector3(0.5, 1.5, 0.3), tower_w + Vector3(0, 30, 0)])
	views.append(["belfry", tower_w + Vector3(-1.5, 26.5, 1.6), tower_w + Vector3(0, 26.4, 0)])
	views.append(["belfry_out", tower_w + Vector3(-14, 26.5, 1.5), tower_w + Vector3(0, 26.5, 1.5)])
	views.append(["gnome_belfry", tower_w + Vector3(-1.0, fy + 1.2, 0.5), bg])
	return views

var _square_trees: Array = []

# --- the FPV club field -------------------------------------------------------------

## The club's field: a launch pad (the spawn), a little course of MultiGP
## gates round the meadow, a hoop, the clubhouse (a painted container
## with a deck and a windsock), the car park by the lane - and one lost
## drone in the big maple at the field's edge.
func _club(trees: Array) -> Array:
	_materials()
	var views: Array = []
	RaceCourse.add_materials(geo)
	var rc := RaceCourse.new()
	var y: float = 0.0
	# The mown field: stripes, light and dark, the way a mower leaves them.
	geo.add_material("vg_mown", Geo.ground_mat(MapTextures.get_tex("mown_grass"), Color.WHITE, 4.0, 1, 0.25))
	var n_str: int = int(CLUB.size.x / 6.0)
	for k in range(n_str):
		var x0: float = CLUB.position.x + k * 6.0
		geo.tint = Color(1.08, 1.1, 1.0) if k % 2 == 0 else Color(0.86, 0.9, 0.84)
		geo.polygon([Vector3(x0, y + 0.02, CLUB.position.y), Vector3(x0 + 6.0, y + 0.02, CLUB.position.y), Vector3(x0 + 6.0, y + 0.02, CLUB.end.y), Vector3(x0, y + 0.02, CLUB.end.y)], "vg_mown", false)
	geo.tint = Color.WHITE
	# Launch pad: a rubber mat with a white H... an X, it's a quad.
	# The mat is solid: a whoop resting on the ground below it had its
	# camera (2 cm up) under the mat and saw only its grey underside.
	geo.polygon([PAD + Vector3(-1.8, 0.05, -1.8), PAD + Vector3(1.8, 0.05, -1.8), PAD + Vector3(1.8, 0.05, 1.8), PAD + Vector3(-1.8, 0.05, 1.8)], "vg_mat", true)
	geo.tint = Color(0.95, 0.95, 0.95)
	geo.box(PAD + Vector3(0, 0.055, 0), Vector3(3.0, 0.01, 0.18), "vg_paint", PI * 0.25, false, false)
	geo.box(PAD + Vector3(0, 0.055, 0), Vector3(3.0, 0.01, 0.18), "vg_paint", -PI * 0.25, false, false)
	geo.tint = Color.WHITE
	# The course, flown anticlockwise from the pad: west through the
	# start, north through the ladder, east under the tower gate, the
	# dive gate, back south through the hoop.
	rc.start_gate(geo, PAD + Vector3(-16, 0, -3), PI * 0.5)
	rc.gate(geo, PAD + Vector3(-42, 0, -22), 0.0, 3)
	rc.gate(geo, PAD + Vector3(-20, 0, -48), -PI * 0.5, 1, RaceCourse.GATE, 0, "gate_b")
	rc.dive_gate(geo, PAD + Vector3(12, 0, -50), 0.0, 3.5)
	rc.hurdle(geo, PAD + Vector3(38, 0, -32), PI)
	rc.gate(geo, PAD + Vector3(40, 0, -12), PI, 2, 0.0, 1)
	for fq in [PAD + Vector3(-50, 0, -6), PAD + Vector3(-40, 0, -50), PAD + Vector3(46, 0, -48)]:
		rc.flag(geo, fq, "gate_b")
	# The practice field round the course (visual only, no timing):
	# a tall stack of four gates, a slalom of flags, a lifted gate at the
	# slalom's end, a dive gate on a 6 m stand beside the clubhouse.
	rc.gate(geo, Vector3(248, y, -50), 0.0, 4, 0.0, 3)
	for k in range(8):
		rc.flag(geo, Vector3(282 + k * 9.0, y, -63 + (k % 2) * 5.0), "gate_a" if k % 2 == 0 else "gate_b")
	rc.gate(geo, Vector3(366, y, -60), -PI * 0.5, 1, 3.0)
	rc.dive_gate(geo, Vector3(362, y, 30), 0.0, 6.0, "gate_a")
	rc.gate(geo, Vector3(262, y, 30), PI * 0.5, 2, 1.52, 1, "gate_b")
	rc.free()
	# The hoop on its stand.
	var hc := PAD + Vector3(24, 3.2, 4)
	var ring: Array[Vector3] = []
	for k in range(33):
		var a: float = TAU * k / 32.0
		ring.append(hc + Vector3(0, sin(a) * 1.7, cos(a) * 1.7))
	geo.tint = Color(1.0, 0.5, 0.1)
	geo.pipe_path(ring, 0.1, "vg_paint", 0.0, 8)
	geo.tint = Color(0.3, 0.3, 0.32)
	geo.cylinder(Vector3(hc.x, y - 0.2, hc.z), hc - Vector3(0, 1.75, 0), 0.06, "vg_paint", 8)
	geo.box(Vector3(hc.x, y + 0.05, hc.z), Vector3(1.4, 0.1, 0.5), "vg_paint", PI * 0.5)
	geo.tint = Color.WHITE
	# A ramp of hoops climbing east, 2.5 m to 9 m.
	for k in range(5):
		_hoop(Vector3(288 + k * 10.0, y + 2.5 + k * 1.6, -24), 1.2, y, [Color(1.0, 0.5, 0.1), Color(0.2, 0.55, 1.0)][k % 2])
	# A tunnel: a drainage tube on two cradles - fly through it.
	var ta := Vector3(250, y + 1.5, 16)
	var tb := Vector3(264, y + 1.5, 16)
	geo.tint = Color(0.75, 0.75, 0.72)
	geo.pipe(ta, tb, 1.5, 0.15, "vg_stone", 18)
	for e in [ta, tb]:
		geo.box(Vector3(e.x + (1.0 if e == ta else -1.0), y + 0.2, e.z), Vector3(0.8, 0.4, 3.2), "vg_wood")
	geo.tint = Color.WHITE
	# A bando-style scaffold cube: open frame, a deck halfway up - fly
	# through between the tubes.
	var sc := Vector3(372, y, -30)
	geo.tint = Color(0.7, 0.72, 0.75)
	for cx in [-3.0, 3.0]:
		for cz in [-3.0, 3.0]:
			geo.cylinder(Vector3(sc.x + cx, y - 0.2, sc.z + cz), Vector3(sc.x + cx, y + 6.0, sc.z + cz), 0.07, "vg_paint", 8)
	for h in [3.0, 6.0]:
		for e: Array in [[Vector3(-3, 0, -3), Vector3(3, 0, -3)], [Vector3(-3, 0, 3), Vector3(3, 0, 3)], [Vector3(-3, 0, -3), Vector3(-3, 0, 3)], [Vector3(3, 0, -3), Vector3(3, 0, 3)]]:
			geo.beam(sc + e[0] + Vector3(0, h, 0), sc + e[1] + Vector3(0, h, 0), Vector2(0.1, 0.1), "vg_paint")
	geo.beam(sc + Vector3(-3, 0.1, -3), sc + Vector3(3, 3.0, -3), Vector2(0.07, 0.07), "vg_paint")
	geo.beam(sc + Vector3(3, 0.1, 3), sc + Vector3(-3, 3.0, 3), Vector2(0.07, 0.07), "vg_paint")
	geo.tint = Color.WHITE
	geo.box(sc + Vector3(-1.5, 3.12, 0), Vector3(3.0, 0.1, 6.0), "vg_wood")
	views.append(["club_field", PAD + Vector3(-70, 18, 40), PAD + Vector3(20, 0, -40)])
	# Clubhouse: a container on sleepers, a deck with a table, a windsock.
	var ch := Vector3(372, y, 26)
	geo.tint = Color(0.15, 0.45, 0.3)
	geo.box_on(Transform3D(Basis(), ch + Vector3(0, 1.4, 0)), Vector3(6.06, 2.6, 2.44), "vg_paint", y)
	geo.tint = Color(0.12, 0.35, 0.24)
	for k in range(10):
		geo.box(ch + Vector3(-2.7 + k * 0.6, 1.4, 1.23), Vector3(0.08, 2.4, 0.04), "vg_paint", 0.0, false)
	geo.tint = Color.WHITE
	geo.box(ch + Vector3(-1.0, 1.4, 1.24), Vector3(1.2, 2.1, 0.04), "vg_wood", 0.0, false)
	geo.box(ch + Vector3(1.4, 1.6, 1.24), Vector3(1.4, 0.9, 0.04), "vg_glass", 0.0, false)
	geo.box_on(Transform3D(Basis(), ch + Vector3(0, 0.15, 3.0)), Vector3(6.0, 0.3, 3.4), "vg_wood", y)
	geo.box(ch + Vector3(0.5, 1.05, 3.2), Vector3(1.8, 0.06, 0.8), "vg_wood")
	for sx in [-0.8, 0.8]:
		for sz in [-0.3, 0.3]:
			geo.box(ch + Vector3(0.5 + sx, 0.67, 3.2 + sz), Vector3(0.06, 0.7, 0.06), "vg_wood")
	geo.tint = Color(0.95, 0.95, 0.93)
	StreetKit._label(geo, "FPV CLUB HOLDERBACH", Transform3D(Basis(), ch + Vector3(0, 2.25, 1.26)), 0.01, Color(0.95, 0.95, 0.9))
	geo.tint = Color.WHITE
	var ws := ch + Vector3(-5.0, 0, 3.0)
	geo.cylinder(Vector3(ws.x, y - 0.3, ws.z), ws + Vector3(0, 6.0, 0), 0.06, "vg_paint", 8)
	for k in range(4):
		geo.tint = Color(1.0, 0.45, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.95)
		geo.cone(ws + Vector3(0.1 + k * 0.45, 5.75, 0), ws + Vector3(0.1 + (k + 1) * 0.45, 5.75 - 0.05, 0), 0.32 - k * 0.05, 0.27 - k * 0.05, "vg_paint", 10, false)
	geo.tint = Color.WHITE
	# Car park: gravel beside the lane's turning circle, members' cars.
	var cp := CLUB_PARK
	geo.slab(cp, _park_y + 0.04, 0.1, "vg_gravel", false) # (a slab: the parked cars stand on it)
	var crng := RandomNumberGenerator.new()
	crng.seed = 9
	for k in range(5):
		fleet.car(Vector3(cp.position.x + 3.0 + k * 3.0, _park_y + 0.04, cp.position.y + 4.5), PI, Fleet.random_paint(crng), ["hatch", "estate", "suv", "van", "sedan"][k])
	# Field-edge trees; the big maple holds a lost drone.
	trees.append([Vector3(398, y, -50), "maple", 611, "drone"])
	trees.append([Vector3(396, y, -20), "maple", 612, "none"])
	trees.append([Vector3(236, y, -76), "birch", 613, "none"])
	views.append(["club", PAD + Vector3(30, 14, 30), PAD + Vector3(-25, 0, -30)])
	views.append(["clubhouse", ch + Vector3(-6, 3.0, 14), ch])
	views.append(["lost_drone", Vector3(386, 8, -44), Vector3(398, 7, -50)])
	return views

## A hoop standing on a pole: ring centre c (flown through along x), radius r.
func _hoop(c: Vector3, r: float, y: float, col: Color) -> void:
	var ring: Array[Vector3] = []
	for k in range(25):
		var a: float = TAU * k / 24.0
		ring.append(c + Vector3(0, sin(a) * r, cos(a) * r))
	geo.tint = col
	geo.pipe_path(ring, 0.08, "vg_paint", 0.0, 8)
	geo.tint = Color(0.3, 0.3, 0.32)
	geo.cylinder(Vector3(c.x, y - 0.2, c.z), c - Vector3(0, r + 0.05, 0), 0.05, "vg_paint", 8)
	geo.box(Vector3(c.x, y + 0.05, c.z), Vector3(0.5, 0.1, 1.0), "vg_paint")
	geo.tint = Color.WHITE

# --- the bando ------------------------------------------------------------------

## An abandoned farmhouse and its barn on the hill's foot beyond the
## railway: brick walls, the windows smashed out, the door gone, a hole
## in the roof and through the upper floor (dive from the roof to the
## ground floor), rubble, graffiti; the barn has lost half its roof.
## In the little back room downstairs, the toilet - seen from inside only.
func _bando(o: Vector3, r: RandomNumberGenerator) -> Array:
	_materials()
	var views: Array = []
	var yaw: float = 0.35
	var xf := Transform3D(Basis(Vector3.UP, yaw), o + Vector3(-6, 0, 2))
	var L: float = 11.0 # along local x
	var B: float = 8.0
	var T: float = 0.36
	var H1: float = 2.9
	var H2: float = 5.6
	var y0: float = o.y
	# Floors: ground slab; the upper floor with a hole by the stairs' place.
	geo.light_fn = _inside_light(y0, 0.75)
	geo.box_on(xf * Transform3D(Basis(), Vector3(0, 0.1, 0)), Vector3(L, 0.2, B), "vgi_floor", y0)
	var fy: float = H1 + 0.12
	# Upper floor in pieces round a 3 x 3 m hole.
	geo.box_xf(xf * Transform3D(Basis(), Vector3(-L * 0.25 - 0.75, fy, 0)), Vector3(L * 0.5 - 1.5 - T, 0.24, B - T * 2.0), "vgi_wood")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(L * 0.25 + 0.75, fy, 0)), Vector3(L * 0.5 - 1.5 - T, 0.24, B - T * 2.0), "vgi_wood")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, fy, -(B * 0.5 - T + 1.5) * 0.5 - 0.75)), Vector3(3.0, 0.24, B * 0.5 - T - 1.5), "vgi_wood")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, fy, (B * 0.5 - T + 1.5) * 0.5 + 0.75)), Vector3(3.0, 0.24, B * 0.5 - T - 1.5), "vgi_wood")
	# Broken joists hanging into the hole.
	geo.beam(xf * Vector3(-1.5, fy, 0.6), xf * Vector3(-0.2, fy - 1.1, 0.5), Vector2(0.12, 0.18), "vgi_wood", false)
	geo.beam(xf * Vector3(1.5, fy, -0.8), xf * Vector3(0.6, fy - 0.7, -0.7), Vector2(0.12, 0.18), "vgi_wood", false)
	geo.light_fn = Callable()
	# Walls: front (+z) with the doorway and windows, back, ends.
	var front := xf * Transform3D(Basis(), Vector3(0, 0, B * 0.5 - T * 0.5))
	var back := xf * Transform3D(Basis(), Vector3(0, 0, -B * 0.5 + T * 0.5))
	var left := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-L * 0.5 + T * 0.5, 0, 0))
	var right := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(L * 0.5 - T * 0.5, 0, 0))
	var wf: Array = [Rect2(-0.6, 0.2, 1.2, 2.2), Rect2(-4.2, 0.95, 1.2, 1.35), Rect2(2.6, 0.95, 1.2, 1.35)]
	var mid: float = H1 + 0.3 # storeys drawn apart: their openings share x ranges (6 cm over the floor: level with it, they flickered)
	BuildKit.wall(geo, front, -L * 0.5, L * 0.5, 0.0, mid, T, wf, "vg_brick", y0)
	BuildKit.wall(geo, front, -L * 0.5, L * 0.5, mid, H2, T, [Rect2(-4.2, 3.7, 1.2, 1.3), Rect2(-0.6, 3.7, 1.2, 1.3), Rect2(2.6, 3.7, 1.2, 1.3)], "vg_brick")
	BuildKit.wall(geo, back, -L * 0.5, L * 0.5, 0.0, mid, T, [Rect2(-3.6, 0.95, 1.0, 1.3), Rect2(2.0, 0.95, 1.6, 1.35)], "vg_brick", y0)
	BuildKit.wall(geo, back, -L * 0.5, L * 0.5, mid, H2, T, [Rect2(-1.8, 3.7, 1.2, 1.3), Rect2(1.4, 3.7, 1.2, 1.3)], "vg_brick")
	# The left end wall has lost a corner: a ragged gap, fly in there.
	BuildKit.wall(geo, left, -B * 0.5 + T, B * 0.5 - T, 0.0, H2, T, [Rect2(-0.6, 3.7, 1.2, 1.3), Rect2(0.9, 0.2, 2.4, 2.1), Rect2(1.5, 2.3, 1.8, 0.7), Rect2(2.2, 3.0, 1.1, 0.5)], "vg_brick", y0)
	geo.tint = Color(0.7, 0.45, 0.38)
	for k in range(6):
		geo.box_xf(left * Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(2.0 + r.randf_range(-0.8, 1.2), 0.12 + (k % 2) * 0.2, -1.0 - r.randf() * 0.8)), Vector3(0.5, 0.24, 0.25), "vg_brick")
	geo.tint = Color.WHITE
	BuildKit.wall(geo, right, -B * 0.5 + T, B * 0.5 - T, 0.0, H2, T, [Rect2(-0.6, 0.95, 1.2, 1.35)], "vg_brick", y0)
	# Gables.
	var pitch: float = deg_to_rad(42.0)
	BuildKit.gable(geo, left, -B * 0.5, B * 0.5, H2, B * 0.5 * tan(pitch), T, "vg_brick")
	BuildKit.gable(geo, right, -B * 0.5, B * 0.5, H2, B * 0.5 * tan(pitch), T, "vg_brick")
	# Roof: the back slope whole, the front slope with a hole - two
	# pieces either end, rafters across the gap.
	var rxf := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	# (rxf's +x is the house's back: the hole is in the front slope, -x.)
	BuildKit.roof(geo, rxf, B * 0.5, L + 0.6, H2, pitch, 0.18, 0.4, "vg_roof", -1)
	var run: float = B * 0.5 + 0.4
	var slope: float = run / cos(pitch)
	for piece: Array in [[-L * 0.5 - 0.3, -1.6], [2.2, L * 0.5 + 0.3]]:
		var len: float = piece[1] - piece[0]
		var cz: float = (piece[0] + piece[1]) * 0.5
		var c := Vector3(-run * 0.5, H2 + B * 0.5 * tan(pitch) - run * 0.5 * tan(pitch) + 0.09, cz)
		geo.box_xf(rxf * Transform3D(Basis(Vector3.FORWARD, -pitch), c), Vector3(slope + 0.05, 0.18, len), "vg_roof")
	for k in range(4):
		var rz: float = -1.2 + k * 1.0
		geo.beam(xf * Vector3(rz, H2 + B * 0.5 * tan(pitch) - 0.1, 0), xf * Vector3(rz, H2 + 0.1, B * 0.5 - 0.1), Vector2(0.1, 0.16), "vg_wood")
	# Window glass: shards left in a couple of frames.
	geo.tint = Color(0.8, 0.9, 0.95)
	geo.tris(PackedVector3Array([front * Vector3(-4.2, 0.95, 0), front * Vector3(-3.4, 0.95, 0), front * Vector3(-4.2, 1.8, 0)]), "vg_glass")
	geo.tris(PackedVector3Array([front * Vector3(3.8, 5.0, 0), front * Vector3(3.0, 5.0, 0), front * Vector3(3.8, 4.4, 0)]), "vg_glass")
	geo.tint = Color.WHITE
	# The back room: a partition with a doorway, the toilet against the back wall.
	geo.light_fn = _inside_light(y0, 0.7)
	var part := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(L * 0.5 - 2.6, 0, 0))
	BuildKit.wall(geo, part, -B * 0.5 + T, B * 0.5 - T, 0.2, H1, 0.12, [Rect2(0.4, 0.2, 0.9, 2.0)], "vgi_plaster")
	geo.light_fn = Callable()
	var trng := RandomNumberGenerator.new()
	trng.seed = 1313
	ToiletCreator.build(geo, xf * Transform3D(Basis(), Vector3(L * 0.5 - 1.3, 0.2, -B * 0.5 + T)), trng, {"lid": "seat_up"})
	# Rubble, a mattress, a chair on its side, the door on the ground outside.
	geo.light_fn = _inside_light(y0, 0.75)
	geo.tint = Color(0.62, 0.55, 0.5)
	for k in range(9):
		var q := Vector3(r.randf_range(-1.6, 1.6), 0.2, r.randf_range(-1.4, 1.4))
		geo.box_xf(xf * Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.4, 0.4)), q + Vector3(0, 0.12, 0)), Vector3(r.randf_range(0.3, 0.8), 0.25, r.randf_range(0.2, 0.5)), "vgi_paint")
	geo.tint = Color(0.75, 0.68, 0.55)
	geo.box_xf(xf * Transform3D(Basis(Vector3.UP, 0.2), Vector3(-3.5, 0.32, -2.2)), Vector3(1.9, 0.22, 1.4), "vgi_paint")
	geo.tint = Color(0.4, 0.3, 0.2)
	geo.box_xf(xf * Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-1.0, 0.45, -2.6)), Vector3(0.9, 0.45, 0.45), "vgi_paint")
	geo.tint = Color.WHITE
	geo.light_fn = Callable()
	geo.tint = Color(0.45, 0.32, 0.22)
	geo.box_xf(xf * Transform3D(Basis(Vector3.UP, 0.4), Vector3(1.4, 0.06 + 0.0, B * 0.5 + 1.6)), Vector3(1.0, 0.06, 2.1), "vg_paint")
	geo.tint = Color.WHITE
	# Graffiti on the walls (Label3D, sprayed colours).
	StreetKit._label(geo, "NO SIGNAL", front * Transform3D(Basis(), Vector3(-2.0, 2.4, T * 0.5 + 0.02)), 0.012, Color(0.85, 0.2, 0.6))
	StreetKit._label(geo, "BANDO", left * Transform3D(Basis(Vector3.UP, PI), Vector3(1.0, 1.6, -T * 0.5 - 0.02)), 0.02, Color(0.2, 0.75, 0.95))
	StreetKit._label(geo, "FAILSAFE", back * Transform3D(Basis(Vector3.UP, PI), Vector3(0.5, 1.8, -T * 0.5 - 0.02)), 0.014, Color(0.95, 0.75, 0.15))
	# The gnome: in the corner behind the rubble.
	var gp: Vector3 = xf * Vector3(-L * 0.5 + 0.8, 0.2, -B * 0.5 + 0.8)
	_gnomes.append([gp, yaw + 0.8])
	# --- the barn ruin beside it ---
	var bx := Transform3D(Basis(Vector3.UP, yaw), o + Basis(Vector3.UP, yaw) * Vector3(12, 0, -8))
	var BL: float = 16.0
	var BB: float = 9.0
	var BH: float = 4.2
	geo.box_on(bx * Transform3D(Basis(), Vector3(0, 0.08, 0)), Vector3(BL, 0.16, BB), "vg_gravel", y0)
	for s in [-1.0, 1.0]:
		var wxf := bx * Transform3D(Basis(), Vector3(0, 0, s * (BB * 0.5 - 0.1)))
		BuildKit.wall(geo, wxf, -BL * 0.5, BL * 0.5, 0.0, BH, 0.2, [Rect2(-5.0, 1.6, 1.4, 1.0), Rect2(2.0, 0.4, 1.8, 2.6)] if s > 0 else [Rect2(-1.0, 1.8, 0.8, 0.8)], "vg_wood", y0)
		var exf := bx * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(s * (BL * 0.5 - 0.1), 0, 0))
		BuildKit.wall(geo, exf, -BB * 0.5 + 0.2, BB * 0.5 - 0.2, 0.0, BH, 0.2, [Rect2(-2.0, 0.16, 4.0, 3.6)], "vg_wood", y0)
		BuildKit.gable(geo, exf, -BB * 0.5, BB * 0.5, BH, BB * 0.5 * tan(deg_to_rad(38.0)), 0.2, "vg_wood")
	var brx := bx * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)
	BuildKit.roof(geo, brx, BB * 0.5, BL + 0.6, BH, deg_to_rad(38.0), 0.14, 0.3, "vg_slate", -1)
	var ridge: float = BH + BB * 0.5 * tan(deg_to_rad(38.0))
	for k in range(7):
		var bz: float = -BL * 0.5 + 1.0 + k * 2.3
		geo.beam(bx * Vector3(bz, ridge - 0.1, 0), bx * Vector3(bz, BH + 0.1, -BB * 0.5 + 0.1), Vector2(0.12, 0.16), "vg_wood")
	geo.beam(bx * Vector3(-BL * 0.5, ridge - 0.1, 0), bx * Vector3(BL * 0.5, ridge - 0.1, 0), Vector2(0.2, 0.2), "vg_wood")
	# Overgrowth.
	for k in range(10):
		var a: float = TAU * k / 10.0 + r.randf() * 0.4
		var q: Vector3 = o + Vector3(cos(a), 0, sin(a)) * r.randf_range(15.0, 22.0)
		_square_trees.append([Vector3(q.x, land.ground(q.x, q.z), q.z), "bush" if k % 3 != 0 else "birch", 700 + k, "none"])
	var hc: Vector3 = xf.origin
	views.append(["bando", hc + Vector3(18, 9, 22), hc + Vector3(4, 2, -2)])
	views.append(["bando_roof_hole", xf * Vector3(0.5, H2 + 6.0, 4.0), xf * Vector3(0, 0, 0)])
	views.append(["bando_inside", xf * Vector3(-3.5, 1.6, 2.2), xf * Vector3(2.0, 1.4, -1.0)])
	views.append(["bando_upstairs", xf * Vector3(-4.0, H1 + 1.7, 2.5), xf * Vector3(1.0, H1 + 0.5, -1.0)])
	views.append(["bando_toilet", xf * Vector3(L * 0.5 - 2.3, 1.5, 1.5), xf * Vector3(L * 0.5 - 1.3, 0.4, -B * 0.5 + 0.6)])
	views.append(["bando_barn", bx * Vector3(-BL * 0.5 - 10.0, 2.5, 0), bx * Vector3(0, 2.0, 0)])
	views.append(["gnome_bando", xf * Vector3(-L * 0.5 + 2.4, 1.0, -B * 0.5 + 2.2), gp])
	return views
