extends BuiltMap

## Mountain Lake - Kaltensee, an alpine reservoir in a cirque of peaks
## (High performance). Laid out by hand here, built by the creators.
##
## North = -z. The lake (~300 m across, water at y 0) fills the middle;
## its southern arm runs to a concrete arch dam closing a rock gorge
## (the 1950s power scheme - the station still stands at the dam's
## foot). The valley road comes up from the south on the shelf west of
## the gorge, passes the dam, runs through the village on the west
## shore and along the north shore - under an avalanche gallery below a
## rock wall - to the cabin's car park and its pier (the spawn). A
## chapel on an island in the lake; a chalet hotel on the south-west
## shore; a campground on the east meadow under the cliffs; above the
## cliffs a hanging valley with an alpine farm and a spring, its creek
## dropping through a gully into the lake as a waterfall; a cable car
## from the north shore to the summit station, its restaurant and the
## summit cross.
## Wow spots: the dam and the gorge, the gallery, the island chapel, the
## waterfall gully. Hidden: a toilet in the power station at the bottom
## of the gorge, a lost drone in a spruce by the dam, a DO NOT FLY sign
## by the spawn, three garden gnomes (GNOMES).

const LAND := Rect2(-1100, -1100, 2200, 2200)
const WATER_Y: float = 0.0
const LAKE_R: float = 150.0
## The dam: z of its crest line at the abutments, crest height.
const DAM_Z: float = 214.0
const CREST_Y: float = 3.2
const ISLAND := Vector2(48, 18)
const VILLAGE := Vector2(-262, 30)
const VILLAGE_Y: float = 5.0
const HOTEL := Vector2(-173, 129)
const HOTEL_Y: float = 7.5
const CAMP := Vector2(168, 96)
## The alpine farm on the hanging valley's pasture (TARN: where the tarn was, kept for the dev dump).
const ALM := Vector2(292, -132)
const TARN := Vector2(352, -40)
const SPRING := Vector2(322, -32) ## the creek's spring at the head of its gully (2026-10-15: no tarn any more)
## The waterfall: the lip of the gully on the cliff top, its foot at the lake.
const FALL_TOP := Vector2(198, -35)
const FALL_FOOT := Vector2(140, -32)
const SUMMIT := Vector2(-440, -340)
## Cable car: valley station by the north road, top station under the summit.
const CABLE_A := Vector2(-62, -214)
const CABLE_B := Vector2(-404, -316)
## The cabin (its pier runs south past the spawn at (0, -140)).
const CABIN := Vector2(0, -182)
const DECK_Y: float = 1.16
## The rock wall above the north road (the gallery runs under it).
const WALL_LINE: Array = [Vector2(-228, -88), Vector2(-196, -136), Vector2(-138, -172), Vector2(-84, -190)]

## Garden gnome spots (Collectibles): feet on the spot, facing +z.
## 0: on the ledge behind the waterfall curtain; 1: at the foot of the
## summit cross; 2: up on a tie beam in the boathouse.
const GNOMES: Array[Transform3D] = [
	Transform3D(Basis(Vector3.UP, -1.57), Vector3(166.1, 54.1, -33.35)),
	Transform3D(Basis(Vector3.UP, 0.6), Vector3(-439.45, 286.6, -339.45)),
	Transform3D(Basis(Vector3.UP, 3.14), Vector3(8.6, 4.285, -113.0)),
]

var land: TerrainCreator
var _views: Array = []
var _noise := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _shore := FastNoiseLite.new()

func map_env() -> Dictionary:
	# Evening alpenglow: the sun low in the west over the ridge, warm light
	# on the peaks and the east shore.
	return {"sun_rot": Vector3(-24, 118, 0), "sun_color": Color(1.0, 0.8, 0.6), "sun_energy": 1.6, "fog_begin": 450.0,
		"sky_top": Color(0.24, 0.38, 0.66), "sky_horizon": Color(0.95, 0.8, 0.68),
		"ambient": Color(0.72, 0.72, 0.8), "ambient_energy": 0.86,
		"shadow_region": Rect2(-600, -600, 1200, 1200)}

func border() -> Array:
	return [950.0, 1050.0, 530.0, 610.0]

func preview_views() -> Array:
	return _views

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

## Loaded from the map cache after the first build (MapCache): the
## script keeps only the land's height grid and the preview views.
func cacheable() -> bool:
	return true

func cache_state() -> Dictionary:
	return {"views": _views, "land": land.grid_state()}

func restore_state(state: Dictionary) -> void:
	_views = state.views
	land = TerrainCreator.from_grid_state(state.land)

func after_build() -> void:
	for i in range(GNOMES.size()):
		Collectibles.gnome(self, "mountain_lake", i, GNOMES[i])

## The land: this map's own mountains (the lake basin, the cirque, the
## gorge, the east cliffs) behind TerrainCreator's interface, so the
## creators (roads, plots, farm, rocks, power line) work on it unchanged.
class AlpLand extends TerrainCreator:
	var fn: Callable
	var tint_fn: Callable
	var lake_fn: Callable
	func _land(x: float, z: float) -> float:
		return fn.call(x, z)
	func tint(_geo: Geo, n: Vector3, p: Vector3) -> Color:
		return tint_fn.call(n, p)
	## The lake counts as a pond for everything that keeps off water.
	func in_pond(x: float, z: float, margin: float = 0.0) -> bool:
		return lake_fn.call(x, z) < margin + 3.0

## Signed distance (roughly, m) from the lake's shore line: negative in
## the water. The shore wanders (noise on the angle), the southern arm
## narrows to the dam, the island is a hole in it.
func _lake_d(x: float, z: float) -> float:
	var th: float = atan2(z, x)
	var R: float = LAKE_R + _shore.get_noise_2d(cos(th) * 90.0, sin(th) * 90.0) * 45.0
	var d: float = Vector2(x, z).length() - R
	if z > 40.0:
		var hw: float = lerpf(78.0, 36.0, smoothstep(70.0, DAM_Z, z))
		d = minf(d, maxf(absf(x) - hw, z - DAM_Z - 4.0))
	d = maxf(d, 24.0 - Vector2(x, z).distance_to(ISLAND))
	return d

## The gorge's axis below the dam (it bends a little on its way south).
func _gorge_x(z: float) -> float:
	return sin(maxf(z - DAM_Z, 0.0) / 160.0) * 30.0

## The gorge floor's level.
func _gorge_floor(z: float) -> float:
	return -34.0 - maxf(z - DAM_Z, 0.0) * 0.012

## Natural ground (before roads and levelled areas).
func _alp(x: float, z: float) -> float:
	var d: float = _lake_d(x, z)
	var n: float = _noise.get_noise_2d(x, z)
	var h: float
	var ridge: float = 1.0 - absf(_ridge.get_noise_2d(x, z))
	if d < 0.0:
		h = -0.7 - 10.0 * smoothstep(0.0, 60.0, -d) + n * 0.6
	else:
		var mountain: float = smoothstep(40.0, 420.0, d) * (95.0 + ridge * ridge * 140.0)
		h = minf(d * 0.11 + mountain + n * 6.0 * smoothstep(0.0, 40.0, d), 430.0 + ridge * 120.0)
		h = maxf(h, 0.3 + d * 0.1) # a beach before the slope (a step at the water's edge: no flat film of water over the ground)
	# The island: a wooded knoll, 7 m over the water.
	var di: float = Vector2(x, z).distance_to(ISLAND)
	if di < 30.0:
		h = maxf(h, lerpf(7.0, -3.0, smoothstep(6.0, 30.0, di)) + n * 0.4)
	# The outlet valley south of the lake: a shelf ~14 m over the water
	# beside the arm and the dam, falling gently south; the mountains
	# stand back from it.
	var gx: float = _gorge_x(z)
	var vx: float = absf(x - gx)
	var v: float = (1.0 - smoothstep(90.0, 260.0, vx)) * smoothstep(110.0, 200.0, z)
	if v > 0.0:
		var floor_y: float = 14.0 - 7.0 * smoothstep(50.0, 150.0, vx) * smoothstep(300.0, 160.0, z) - maxf(z - DAM_Z, 0.0) * 0.022 + maxf(vx - 140.0, 0.0) * 0.1
		var shelf: float = minf(floor_y, maxf(d, 0.0) * 0.7 + minf(d, 0.0) * 0.3 - 0.7)
		h = lerpf(h, shelf, v)
	# The gorge under the dam: rock walls ~45 m down to the river (2026-10-16:
	# a flat floor 15 m each side, so the 8 m terrain grid never lifts the water's banks).
	if z > DAM_Z - 6.0:
		var gf: float = _gorge_floor(z)
		var wall: float = gf + smoothstep(15.0, 34.0, vx + n * 3.0) * (h - gf)
		h = lerpf(h, minf(h, wall), smoothstep(DAM_Z - 6.0, DAM_Z + 2.0, z))
	# The east cliffs and the hanging valley above them (~72 m), with the
	# gully the creek has cut down through the cliff.
	var ex: float = smoothstep(120.0, 175.0, x) * (1.0 - smoothstep(110.0, 190.0, absf(z + 50.0)))
	if ex > 0.0 and d > 0.0:
		var step: float = 72.0 * smoothstep(2.0, 50.0, d) + maxf(d - 50.0, 0.0) * 0.05
		h = lerpf(h, maxf(h, step + n * 2.0), ex)
		var gq: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(x, z), SPRING, FALL_FOOT)
		var gd: float = gq.distance_to(Vector2(x, z))
		h -= 7.0 * (1.0 - smoothstep(3.0, 13.0, gd)) * ex * smoothstep(0.0, 30.0, d)
	# The rock wall above the north road.
	var wd: float = _wall_d(x, z)
	if wd > 0.0:
		h += 46.0 * smoothstep(6.0, 40.0, wd) * (1.0 - smoothstep(90.0, 160.0, wd))
	# The summit the cable car climbs to.
	h += 70.0 * (1.0 - smoothstep(0.0, 160.0, Vector2(x, z).distance_to(SUMMIT)))
	return h

## Distance from the north road's rock-wall line, on its far side from
## the lake (0 on the lake side and past its ends).
func _wall_d(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best: float = INF
	var side: float = 0.0
	var fade: float = 1.0
	for i in range(WALL_LINE.size() - 1):
		var a: Vector2 = WALL_LINE[i]
		var b: Vector2 = WALL_LINE[i + 1]
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var dd: float = q.distance_to(p)
		if dd < best:
			best = dd
			var t: Vector2 = (b - a).normalized()
			side = (p - q).dot(Vector2(t.y, -t.x)) # +: away from the lake (north-west)
			var u: float = (p - a).dot(t) / a.distance_to(b)
			fade = 1.0
			if i == 0:
				fade = smoothstep(-0.6, 0.2, u)
			if i == WALL_LINE.size() - 2:
				fade = minf(fade, 1.0 - smoothstep(0.8, 1.6, u))
	if side <= 0.0:
		return 0.0
	return best * fade

func _tint(n: Vector3, p: Vector3) -> Color:
	var steep: float = 1.0 - n.y
	var c: Color
	var snow_line: float = 165.0 + _noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 25.0
	if p.y < 0.9 and _lake_d(p.x, p.z) < 3.0:
		c = Color(0.74, 0.72, 0.68) # shore pebbles
	elif p.y > snow_line and steep < 0.5:
		c = Color(1.5, 1.52, 1.6) # snow
	elif steep > 0.38:
		c = Color(0.86, 0.84, 0.82).lerp(Color(0.66, 0.64, 0.62), clampf(_noise.get_noise_2d(p.z, p.x) + 0.5, 0.0, 1.0)) # rock
	elif steep > 0.22:
		c = Color(0.74, 0.74, 0.6) # scree and thin turf
	else:
		var hi: float = clampf(p.y / 150.0, 0.0, 1.0)
		c = Color(0.56, 0.74, 0.38).lerp(Color(0.74, 0.72, 0.5), hi) # alpine meadow, drier higher up
		c = c.lerp(Color(0.68, 0.74, 0.4), clampf(_noise.get_noise_2d(p.x * 2.0, p.z * 2.0), 0.0, 0.6))
	return geo.shade(n, p.y + 50.0) * c

func build() -> void:
	var t0: int = Time.get_ticks_msec()
	_noise.seed = 3
	_noise.frequency = 0.012
	_ridge.seed = 9
	_ridge.frequency = 0.004
	_ridge.fractal_octaves = 5
	_shore.seed = 17
	_shore.frequency = 0.02
	var al := AlpLand.new()
	al.fn = _alp
	al.tint_fn = _tint
	al.lake_fn = _lake_d
	land = al
	land.set_extent(LAND)
	# The ground: one neutral texture, the colours from the tint.
	geo.add_material("tr_ground", Geo.ground_mat(MapTextures.get_tex("ground_neutral"), Color.WHITE, 7.0, 0, 0.5))
	geo.add_material("tr_water", Geo.water_mat(Color(0.07, 0.28, 0.32), 0.9)) # (the tarn)
	_materials()
	# --- levelled ground ---
	land.flat_circle(VILLAGE, 70.0, VILLAGE_Y, 70.0)
	land.flat_line(Vector2(-236, 110), Vector2(-240, -90), 8.0, VILLAGE_Y, 60.0) # the village street, level
	land.flat_circle(HOTEL, 30.0, HOTEL_Y, 22.0)
	land.flat_circle(CAMP, 34.0, 2.4, 25.0)
	land.flat_circle(CABIN + Vector2(-4, -6), 18.0, 4.0, 18.0)
	land.flat_circle(CABLE_A, 13.0, _alp(CABLE_A.x, CABLE_A.y), 14.0)
	land.flat_circle(CABLE_B, 15.0, _alp(CABLE_B.x, CABLE_B.y), 16.0)
	var farm: Dictionary = FarmCreator.plan(land, ALM, Vector2(56, 44), -1.0)
	land.keep_clear(VILLAGE, 80.0)
	land.keep_clear(CAMP, 45.0)
	land.keep_clear(ISLAND + Vector2(-6, 2), 9.0)
	var meadows: Array = [
		[Vector2(240, -205), Vector2(330, -200), Vector2(335, -165), Vector2(245, -165)],
		[Vector2(215, -110), Vector2(258, -112), Vector2(262, -60), Vector2(222, -62)],
	]
	for mq: Array in meadows:
		land.keep_clear_poly(FieldCreator.poly(mq))
	# --- the valley road and its branches ---
	var main := RoadCreator.plan(land, Vector3(-72, 0, 2700), -90.0, [Vector2(-72, 900), Vector2(-78, 420), Vector2(-92, 260), Vector2(-150, 182), Vector2(-218, 114), Vector2(-246, 40), Vector2(-240, -50), Vector2(-205, -118), Vector2(-142, -160), Vector2(-80, -182), Vector2(-40, -192)], 6.5, {"radius": 70.0, "end": "turning", "verge": 1.2})
	var lane_w := RoadCreator.branch(land, main, Vector2(-246, 4), 1.0, [Vector2(-330, 0)], 5.0, {"end": "turning", "radius": 40.0, "lead": 15.0})
	var hotel_ln := RoadCreator.branch(land, main, Vector2(-160, 170), 1.0, [Vector2(-150, 140)], 5.0, {"end": "entrance", "radius": 30.0, "lead": 10.0})
	# --- plots along the road through the village ---
	var plots: Array = []
	var v0: float = main.dist_at(Vector2(-240, 96))
	var v1: float = main.dist_at(Vector2(-238, -84))
	var np: Array = []
	np.append(VillageKit.plots_along(land, lane_w, 10.0, 90.0, 1.0, plots, {"depth": 28.0, "width": 20.0}))
	np.append(VillageKit.plots_along(land, lane_w, 10.0, 90.0, -1.0, plots, {"depth": 28.0, "width": 20.0}))
	np.append(VillageKit.plots_along(land, main, v0, v1, 1.0, plots, {"depth": 30.0, "width": 21.0}))
	np.append(VillageKit.plots_along(land, main, v0, v1, -1.0, plots, {"depth": 30.0, "width": 21.0}))
	if OS.has_environment("SH_DUMP"):
		print("ML plots ", np, " lane length ", lane_w.line.length(), " main v0..v1 ", v0, " ", v1)
	var t1: int = Time.get_ticks_msec()
	land.build(self, geo, LAND)
	var t2: int = Time.get_ticks_msec()
	if OS.has_environment("SH_DUMP"):
		_dump()
		for q: Vector3 in hotel_ln.line.pts:
			print("ML lane %s g=%.2f" % [q, land.ground(q.x, q.z)])
		for a in range(0, 360, 30):
			var rq: Vector3 = hotel_ln.line.pts[-1] + Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 7.0
			print("ML rim %d g=%.2f" % [a, land.ground(rq.x, rq.z)])
	# --- drawing ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 8848
	var roads := Roads.new(geo, rng, fleet)
	for rd: RoadCreator in [main, hotel_ln, lane_w]:
		_views.append_array(rd.draw(geo, roads, rng).views)
	_lake_water()
	VillageKit.lamps(roads, main, v0, v1, 32.0)
	VillageKit.lamps(roads, lane_w, 12.0, 76.0, 30.0)
	var trees: Array = []
	var vinfo: Dictionary = VillageKit.build_plots(geo, plots, 77)
	trees.append_array(vinfo.trees)
	var t3: int = Time.get_ticks_msec()
	_dam()
	_gorge()
	_gallery(main)
	_cabin_and_pier()
	_chapel()
	_hotel(hotel_ln)
	_camp(rng)
	_cable_car()
	_quad_rocks()
	_waterfall()
	_street(main, lane_w, hotel_ln)
	var t4: int = Time.get_ticks_msec()
	# --- the alpine farm and its meadows ---
	var fv: Dictionary = FarmCreator.build(geo, land, farm, 91)
	trees.append_array(fv.trees)
	_views.append_array(fv.views.slice(0, 1))
	for mq: Array in meadows:
		var frng := RandomNumberGenerator.new()
		frng.seed = Pieces.seed_of(Pieces.id_at("field", Vector3(mq[0].x, 0, mq[0].y)), 5)
		trees.append_array(FieldCreator.build(geo, land, mq, "meadow", frng).trees)
	# --- power line up the valley into the village ---
	var pl: Array = []
	var mr: Route = Route.from_pts(main.line.pts)
	var d_pl: float = main.dist_at(Vector2(-78, 600))
	for k in range(7):
		var s: Array = mr.sample(d_pl + k * 72.0)
		var tn: Vector3 = s[1]
		var q: Vector3 = (s[0] as Vector3) + Vector3(tn.z, 0, -tn.x) * 13.0
		pl.append(Vector2(q.x, q.z))
	pl.append(Vector2(-226, 120))
	_views.append_array(PowerLineCreator.build(geo, land, pl, "poles").views.slice(0, 1))
	# --- rocks, before the trees ---
	var rk := RandomNumberGenerator.new()
	rk.seed = 4711
	var rinfo: Dictionary = RockCreator.scatter(self, geo, land, rk, [
		[Vector2.ZERO, 205.0, 80, 0.8, 4.5], # round the shore (the water rejects most of the disc)
		[Vector2(150, -40), 70.0, 40, 1.0, 6.0], # scree under the east cliffs
		[Vector2(-160, -205), 90.0, 50, 1.2, 7.0], # fallen from the rock wall
		[Vector2(-300, -300), 160.0, 70, 1.2, 8.0], # the cable car slope
		[Vector2(260, 260), 150.0, 60, 1.2, 8.0], # the south-east slope
		[Vector2(-330, 320), 130.0, 40, 1.2, 7.0], # south-west
		[Vector2(40, -430), 140.0, 60, 1.5, 9.0], # the north wall
		[Vector2(300, -90), 80.0, 30, 0.6, 3.0], # the pasture
		[SPRING + Vector2(3.0, 0), 3.0, 9, 2.2, 4.0], # the spring comes out between them
		[Vector2(0, 300), 70.0, 20, 0.8, 3.5], # the gorge rim
	], meadows.map(func(m: Array) -> PackedVector2Array: return FieldCreator.poly(m)))
	_views.append_array(rinfo.views.slice(0, 2))
	_forest(trees, rng)
	var tinfo: Dictionary = TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("MOUNTAINLAKE plan %d ms, land %d ms, roads+houses %d ms, landmarks %d ms, farm+rocks+trees %d ms; %d plots, %d trees" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3, Time.get_ticks_msec() - t4, plots.size(), tinfo.kept])
	_views.append_array([
		["overview", Vector3(0, 160, 430), Vector3(0, 20, -60)],
		["spawn", Vector3(0, 1.6, -141), Vector3(0, 1.0, -100)],
		["dam_face", Vector3(20, 6, 290), Vector3(0, -12, DAM_Z)],
		["dam_crest", Vector3(-60, 18, 190), Vector3(20, 0, 225)],
		["gorge", Vector3(_gorge_x(330.0), -28, 330), Vector3(0, -20, DAM_Z)],
		["power_station", Vector3(_gorge_x(236.0) - 3.0, -31.5, 252), Vector3(_gorge_x(236.0) + 4.0, -32, 236)],
		["gallery", Vector3(-226, 14, -70), Vector3(-160, 10, -160)],
		["island", Vector3(110, 18, 60), Vector3(ISLAND.x, 6.0, ISLAND.y)],
		["village", Vector3(-150, 45, 60), Vector3(-260, 5, 20)],
		["hotel", Vector3(-90, 20, 150), Vector3(HOTEL.x, 8, HOTEL.y)],
		["waterfall", Vector3(90, 30, -10), Vector3(170, 35, -34)],
		["behind_falls", Vector3(150.0, 52.0, -31.0), Vector3(166.1, 54.0, -33.4)],
		["pasture", Vector3(180, 110, -40), Vector3(300, 75, -110)],
		["cable_car", Vector3(-80, 60, -150), Vector3(-260, 120, -260)],
		["summit", Vector3(-400, 300, -300), Vector3(SUMMIT.x, 280, SUMMIT.y)],
		["camp", Vector3(110, 15, 130), Vector3(CAMP.x, 3, CAMP.y)],
		["north_shore", Vector3(0, 40, 120), Vector3(-120, 10, -180)],
		["lost_drone", Vector3(-50, 18, 240), Vector3(-58, 16, 232)],
	])

func _materials() -> void:
	geo.add_material("ml_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.02, 1.0, 0.96), 5.0))
	geo.add_material("ml_stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.95, 0.92, 0.88), 3.0))
	geo.add_material("ml_plaster", Geo.tex_mat(MapTextures.get_tex("plaster"), Color(1.02, 1.0, 0.96), 3.0))
	geo.add_material("ml_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.05, 0.88, 0.68), 1.6))
	geo.add_material("ml_deck", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.25, 1.18, 1.08), 1.4)) # weathered silver-grey boards
	geo.add_material("ml_log", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.86, 0.66, 0.48), 1.2))
	geo.add_material("ml_shingle", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.58, 0.52, 0.5), 0.9))
	geo.add_material("ml_paint", Geo.flat_mat(Color.WHITE, 0.6))
	geo.add_material("ml_glass", Geo.flat_mat(Color(0.16, 0.2, 0.24), 0.2))
	geo.add_material("ml_steel", Geo.flat_mat(Color(0.55, 0.57, 0.6), 0.5, 0.5))
	geo.add_material("ml_cable", Geo.flat_mat(Color(0.12, 0.12, 0.13)))
	var falls := StandardMaterial3D.new()
	falls.albedo_color = Color(0.92, 0.96, 1.0, 0.8)
	falls.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	falls.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	falls.vertex_color_use_as_albedo = true
	falls.cull_mode = BaseMaterial3D.CULL_DISABLED
	falls.albedo_texture = MapTextures.get_tex("ground_neutral")
	falls.uv1_triplanar = true
	falls.uv1_world_triplanar = true
	falls.uv1_scale = Vector3(0.5, 0.05, 0.5)
	falls.set_meta("keep_material", true)
	if Geo.unified_water:
		geo.add_material("ml_falls", _falls_mat())
		geo.add_material("ml_spill", _falls_mat(Vector2(0, 1))) # (the dam's: its own flow direction)
	else:
		geo.add_material("ml_falls", falls)
		geo.add_material("ml_spill", falls)
	geo.add_material("ml_lot", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color(0.95, 0.95, 0.95), 7.0, 1, 0.3))
	geo.add_material("ml_foam", Geo.flat_mat(Color(0.9, 0.94, 0.96))) # (on water, not ground)

## The lake's water: quads over every cell that is under water,
## following the shore, stopping at the dam's upstream face.
func _lake_water() -> void:
	geo.add_material("water", Geo.water_mat(Color(0.07, 0.3, 0.36), 0.9))
	var s: float = 10.0
	geo.light_fn = func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0)
	for iz in range(-30, 24):
		for ix in range(-30, 30):
			var x0: float = ix * s
			var z0: float = iz * s
			var wet: bool = false
			for q: Vector2 in [Vector2(x0, z0), Vector2(x0 + s, z0), Vector2(x0, z0 + s), Vector2(x0 + s, z0 + s), Vector2(x0 + s * 0.5, z0 + s * 0.5)]:
				if q.y < DAM_Z + 2.0 and land.ground(q.x, q.y) < WATER_Y + 0.05:
					wet = true
			if not wet:
				continue
			var z1: float = minf(z0 + s, _dam_face_z(x0 + s * 0.5) + 0.3)
			if z1 <= z0:
				continue
			# (a thin slab: boats and piers rest on it for the floating check)
			geo.water_slab(Rect2(x0, z0, s, z1 - z0), WATER_Y, 0.2, "water")
	geo.light_fn = Callable()

## z of the dam's upstream face at x (the arch bows north, into the lake).
func _dam_face_z(x: float) -> float:
	return DAM_Z - 2.5 - 9.0 * (1.0 - clampf((x / 50.0) * (x / 50.0), 0.0, 1.0))

## The arch dam: segments along the arch, each from the gorge floor (or
## the rock under it) to the crest - 4 m thick at the crest, thickening
## toward the foot - a parapet on both sides of the crest walk, a valve
## tower on the lake side, the spillway falling down the middle of the face.
func _dam() -> void:
	var step: float = 4.0
	var x: float = -52.0
	while x < 52.0:
		var xa: float = x
		var xb: float = x + step
		var corners: Array = []
		var lo: float = INF
		for xx in [xa, xb]:
			for dz in [0.0, 14.0]:
				lo = minf(lo, land.ground(xx, _dam_face_z(xx) + dz))
		lo -= 1.0
		if lo > CREST_Y - 0.5:
			x += step
			continue
		# (corner bit 0 = +x, bit 1 = +y, bit 2 = +z (downstream))
		for i in range(8):
			var xx: float = xb if i & 1 else xa
			var top: bool = i & 2
			var down: bool = i & 4
			var y: float = CREST_Y if top else lo
			var thick: float = 4.0 + (CREST_Y - y) * 0.22
			corners.append(Vector3(xx, y, _dam_face_z(xx) + (thick if down else 0.0)))
		geo.hexa(corners, "ml_concrete")
		x += step
	# Parapets and the crest's lamp posts.
	x = -44.0
	while x < 44.0:
		for dz in [0.15, 3.85]:
			var a := Vector3(x, CREST_Y + 0.55, _dam_face_z(x) + dz)
			var b := Vector3(x + 4.0, CREST_Y + 0.55, _dam_face_z(x + 4.0) + dz)
			geo.beam(a, b, Vector2(0.3, 1.1), "ml_concrete")
		x += 4.0
	for lx in [-30.0, 0.0, 30.0]:
		var p := Vector3(lx, CREST_Y + 1.1, _dam_face_z(lx) + 3.85)
		geo.cylinder(p, p + Vector3(0, 3.5, 0), 0.07, "ml_steel", 6)
		geo.box(p + Vector3(0, 3.55, -0.3), Vector3(0.25, 0.15, 0.6), "ml_paint", 0.0, false)
	# Valve tower: a round shaft standing in the lake by the crest,
	# a little house on top, a footbridge to the crest.
	var vt := Vector3(-18, 0, _dam_face_z(-18) - 12.0)
	geo.cylinder(Vector3(vt.x, land.ground(vt.x, vt.z) - 1.0, vt.z), Vector3(vt.x, CREST_Y + 1.0, vt.z), 3.2, "ml_concrete", 18)
	geo.box(Vector3(vt.x, CREST_Y + 2.6, vt.z), Vector3(5.0, 3.2, 5.0), "ml_plaster")
	geo.tint = Color(0.45, 0.3, 0.25)
	geo.box(Vector3(vt.x, CREST_Y + 4.35, vt.z), Vector3(5.6, 0.3, 5.6), "ml_paint")
	geo.tint = Color.WHITE
	geo.box(Vector3(vt.x, CREST_Y + 2.3, vt.z + 2.52), Vector3(1.0, 2.0, 0.06), "ml_glass", 0.0, false)
	var fb0 := Vector3(vt.x, CREST_Y + 0.9, vt.z + 3.2)
	var fb1 := Vector3(vt.x, CREST_Y + 0.9, _dam_face_z(vt.x))
	geo.beam(fb0, fb1, Vector2(1.6, 0.25), "ml_steel")
	for sx in [-0.8, 0.8]:
		geo.beam(fb0 + Vector3(sx, 1.0, 0), fb1 + Vector3(sx, 1.0, 0), Vector2(0.06, 0.06), "ml_steel", false)
	_spillway()
	_views.append(["spillway", Vector3(6, -24, 248), Vector3(0, -10, DAM_Z)])
	_views.append(["pool_top", Vector3(0, -8, DAM_Z + 14.0), Vector3(0, -34, DAM_Z + 14.1)])
	_views.append(["river_top", Vector3(_gorge_x(DAM_Z + 90.0), 0, DAM_Z + 90.0), Vector3(_gorge_x(DAM_Z + 90.0), -34, DAM_Z + 90.1)])
	_views.append(["river_low", Vector3(-1.0, -31.0, DAM_Z + 24.0), Vector3(_gorge_x(DAM_Z + 120.0) - 3.0, -33.5, DAM_Z + 120.0)])
	_views.append(["spillway_side", Vector3(16, -12, DAM_Z + 16.0), Vector3(0, -16, DAM_Z - 2.0)])

## The spillway (2026-10-15, user: it ran sideways, was a flat sheet and
## stopped short): water over the crest between two training walls, out
## over the downstream edge in a falling arc - two sheets, the underside
## leaving slower, so it thickens as it falls - into a plunge pool at the
## river's level; the waterfall's shader (flowing +z here), foam and mist.
var _spill_land := Vector3.ZERO
const SPILL_POOL_END: float = DAM_Z + 16.0 ## the plunge pool; the river starts here
func _spillway() -> void:
	# (2026-10-16, user: over the crest the water came from above the
	# lake - it leaves through an outlet in the face below the waterline.)
	var hw: float = 3.0
	var zu: float = _dam_face_z(0.0)
	var zd: float = zu + 4.0
	var pool_y: float = _gorge_floor(DAM_Z) + 0.3
	var out_top: float = WATER_Y - 2.0
	var out_bot: float = out_top - 1.6
	var face: float = zd + (CREST_Y - out_top) * 0.22 # the downstream face at the outlet's top
	# The outlet: a concrete portal on the face, the dark mouth in it.
	var lip: float = face + 1.2
	geo.box(Vector3(0, (out_top + out_bot) * 0.5, face + 0.45), Vector3(hw * 2.0 + 1.6, out_top - out_bot + 1.4, 1.5), "ml_concrete")
	if not geo.has_material("ml_mouth"):
		geo.add_material("ml_mouth", Geo.flat_mat(Color(0.04, 0.05, 0.06)))
	geo.box(Vector3(0, (out_top + out_bot) * 0.5, lip + 0.01), Vector3(hw * 2.0, out_top - out_bot, 0.04), "ml_mouth", 0.0, false, false)
	var col: Dictionary = {}
	var row := func(zs: float, y: float, f: float, fade: float, bulge: float, w: float) -> PackedVector3Array:
		var r := PackedVector3Array()
		for j in range(7):
			var u: float = (j - 3) / 3.0
			var q := Vector3(u * w, y, zs + bulge * (1.0 - u * u))
			r.append(q)
			col[q] = Color(1.0 - absf(u), f, fade)
		return r
	var v0: float = 6.0 # m/s over the edge: lands ~8 m out from the foot
	var drop: float = out_top - pool_y
	var t_end: float = sqrt(drop / 4.9)
	var front: Array = []
	var back: Array = []
	# Out of the mouth.
	front.append(row.call(lip - 0.05, out_top - 0.05, 0.0, 1.0, 0.0, hw - 0.05))
	back.append(row.call(lip - 0.05, out_bot + 0.05, 0.0, 1.0, 0.0, hw - 0.05))
	# The arc: thrown out at v0 and falling, the underside 15 % slower.
	var n: int = 16
	for k in range(1, n + 1):
		var t: float = t_end * pow(float(k) / n, 0.8)
		var f: float = float(k) / n
		var yf: float = out_top - 0.05 - 4.9 * t * t
		var yb: float = out_bot + 0.05 - 4.9 * t * t
		var face_at: Callable = func(y: float) -> float: return zd + maxf(CREST_Y - y, 0.0) * 0.22 + 0.3
		var w: float = hw - 0.05 + 1.5 * f
		front.append(row.call(maxf(lip + v0 * t, face_at.call(yf) + 0.6), maxf(yf, pool_y - 0.2), f, 1.0, 0.25 * f, w))
		back.append(row.call(maxf(lip + v0 * 0.85 * t, face_at.call(yb)), maxf(yb, pool_y - 0.2), f, 1.0, 0.0, w))
	# Down through the pool's surface (ends under it).
	for rows: Array in [front, back]:
		var last: PackedVector3Array = rows[rows.size() - 1]
		var under := PackedVector3Array()
		for q: Vector3 in last:
			var q2 := Vector3(q.x, pool_y - 0.6, q.z + 0.3)
			under.append(q2)
			col[q2] = col.get(q, Color(0, 1, 1))
		rows.append(under)
	var lf: PackedVector3Array = front[front.size() - 1]
	_spill_land = Vector3(0.0, pool_y, lf[3].z)
	geo.light_fn = func(_nn: Vector3, pp: Vector3) -> Color: return col.get(pp, Color(0, 1, 1))
	geo.strip(back, "ml_spill")
	geo.strip(front, "ml_spill")
	geo.light_fn = Callable()
	if Geo.unified_water:
		_falls_mist(Vector3(0.0, pool_y + 1.0, _spill_land.z), Vector2(0, 1))

## The plunge pool and the river below it as one ribbon of water
## (2026-10-16, user: the pool was a square, the river looked buggy): a
## round pool under the jet that narrows into the river, edges wobbling
## a little, one surface following the floor's fall - no second water
## plane to flicker against.
func _river_rows() -> Array:
	var zd: float = _dam_face_z(0.0) + 4.0
	var za: float = zd + (CREST_Y - _gorge_floor(DAM_Z)) * 0.22 - 0.5
	var zb: float = DAM_Z + 28.0
	var rows: Array = []
	var z: float = za
	while z < 1200.0:
		var t: float = clampf((z - za) / (zb - za), 0.0, 1.0)
		var bulge: float = 4.8 * (1.0 - smoothstep(0.25, 1.0, t))
		var cap: float = clampf((z - za) / 5.0, 0.0, 1.0)
		var hw: float = (3.4 + bulge) * sqrt(1.0 - (1.0 - cap) * (1.0 - cap))
		var cx: float = (_gorge_x(z) - 3.0) * smoothstep(DAM_Z + 4.0, DAM_Z + 40.0, z)
		var y: float = _gorge_floor(maxf(z, DAM_Z)) + 0.3
		var wob: float = 0.1 * (1.0 + bulge * 0.1)
		var wl: float = hw * (1.0 + wob * sin(z * 0.37 + 1.0))
		var wr: float = hw * (1.0 + wob * sin(z * 0.29 + 4.0))
		rows.append(PackedVector3Array([Vector3(cx + wr, y, z), Vector3(cx - wl, y, z)]))
		z += 1.0 if z < zb else 8.0
	return rows

## The gorge under the dam: the river on its floor (its west side),
## foam where the spillway lands, the power station on the east side
## (a toilet inside - door toward the dam).
func _gorge() -> void:
	geo.light_fn = func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0) * Color(0.9, 0.95, 1.0)
	geo.strip(_river_rows(), "water")
	geo.light_fn = Callable()
	var foam := Vector3(0, _gorge_floor(DAM_Z) + 0.36, _spill_land.z + 2.0)
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.0, 1.02, 1.05)
	# (2026-10-16, user: a flat white plate - now the falls' churning
	# splash: boiling core, rings, drifting foam; over the plunge pool.)
	if Geo.unified_water:
		geo.add_material("ml_splash_dam", _splash_mat(Vector2(_spill_land.x, _spill_land.z), Vector2(0, 1)))
		geo.material("ml_splash_dam").set_shader_parameter("fade_r", 5.0) # (gone before the patch's edge)
		geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color.WHITE
		var py: float = _spill_land.y + 0.06
		var disc: Array[Vector3] = []
		for k in range(20):
			var an: float = TAU * k / 20.0
			disc.append(Vector3(cos(an) * 5.4, py, _spill_land.z + 1.5 + sin(an) * 7.0 * (1.0 + 0.1 * sin(an * 3.0))))
		geo.polygon(disc, "ml_splash_dam", false)
	else:
		geo.polygon([foam + Vector3(-5, 0, -3), foam + Vector3(4, 0, -3), foam + Vector3(3, 0, 5), foam + Vector3(-5, 0, 5)], "ml_foam", false)
	geo.light_fn = Callable()
	# The power station: 7 x 11 m, 5.5 m high, door (open) facing north.
	var zc: float = DAM_Z + 30.0
	var c := Vector3(_gorge_x(zc) + 4.6, _gorge_floor(zc), zc)
	var W: float = 7.0
	var L: float = 11.0
	var H: float = 5.5
	var t: float = 0.3
	var lvl: float = c.y
	geo.box_on(Transform3D(Basis(), c + Vector3(0, 0.0, 0)), Vector3(W, 0.3, L), "ml_concrete", lvl - 0.15)
	c.y += 0.15 # the floor's top
	geo.box_on(Transform3D(Basis(), c + Vector3(0, H * 0.5, L * 0.5 - t * 0.5)), Vector3(W, H, t), "ml_concrete", lvl) # south
	geo.box_on(Transform3D(Basis(), c + Vector3(-W * 0.5 + t * 0.5, H * 0.5, 0)), Vector3(t, H, L), "ml_concrete", lvl) # west
	geo.box_on(Transform3D(Basis(), c + Vector3(W * 0.5 - t * 0.5, H * 0.5, 0)), Vector3(t, H, L), "ml_concrete", lvl) # east
	# North wall with the doorway (1.6 m wide, 2.4 m high).
	var pw: float = (W - 1.6) * 0.5
	for sx in [-1.0, 1.0]:
		geo.box_on(Transform3D(Basis(), c + Vector3(sx * (0.8 + pw * 0.5), H * 0.5, -L * 0.5 + t * 0.5)), Vector3(pw, H, t), "ml_concrete", lvl)
	geo.box(c + Vector3(0, 2.4 + (H - 2.4) * 0.5, -L * 0.5 + t * 0.5), Vector3(1.6, H - 2.4, t), "ml_concrete")
	geo.box(c + Vector3(0, H + 0.15, 0), Vector3(W + 0.4, 0.3, L + 0.4), "ml_concrete")
	# A door leaf standing open against the wall, a sign over the door.
	geo.tint = Color(0.25, 0.4, 0.3)
	geo.box(c + Vector3(1.55, 1.2, -L * 0.5 - 0.75), Vector3(0.06, 2.3, 1.5), "ml_paint", 0.0, false)
	geo.tint = Color(0.95, 0.85, 0.1)
	geo.box(c + Vector3(0, 2.9, -L * 0.5 - 0.02), Vector3(1.2, 0.35, 0.03), "ml_paint", 0.0, false)
	geo.tint = Color.WHITE
	# High windows on the east and west walls.
	for sx in [-1.0, 1.0]:
		for kz in [-2.5, 2.5]:
			geo.box(c + Vector3(sx * (W * 0.5 + 0.01), 4.2, kz), Vector3(0.04, 0.9, 2.0), "ml_glass", 0.0, false)
	# Inside: a turbine-generator, a switchgear cabinet row, and in the
	# south-east corner the toilet (it was a long shift down here).
	geo.tint = Color(0.3, 0.45, 0.6)
	geo.cylinder(c + Vector3(-1.2, 0.0, -1.0), c + Vector3(-1.2, 1.6, -1.0), 1.3, "ml_paint", 16)
	geo.cylinder(c + Vector3(-1.2, 1.6, -1.0), c + Vector3(-1.2, 2.4, -1.0), 0.8, "ml_paint", 12)
	geo.tint = Color(0.62, 0.64, 0.6)
	for k in range(4):
		geo.box(c + Vector3(-W * 0.5 + t + 0.35, 1.0, 1.0 + k * 0.9), Vector3(0.6, 2.0, 0.85), "ml_paint")
	geo.tint = Color(0.95, 0.95, 0.92)
	# A WC corner: a partition beside the toilet.
	geo.box(c + Vector3(W * 0.5 - t - 1.6, 1.1, L * 0.5 - t - 0.9), Vector3(0.06, 2.2, 1.8), "ml_paint")
	geo.tint = Color.WHITE
	ToiletCreator.build(geo, Transform3D(Basis(Vector3.UP, PI), c + Vector3(W * 0.5 - t - 0.8, 0.0, L * 0.5 - t)), _local_rng(31), {"floater": "duck"})
	_views.append(["toilet", c + Vector3(-0.5, 1.6, -L * 0.5 + 1.0), c + Vector3(W * 0.5 - 0.8, 0.5, L * 0.5 - 0.6)])
	_views.append(["gorge_floor", c + Vector3(-4, 3, 24), c])

static func _local_rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

## The avalanche gallery on the north road under the rock wall: a
## concrete roof on a back wall (uphill) and pillars (lake side), ~110 m.
func _gallery(main: RoadCreator) -> void:
	var r: Route = Route.from_pts(main.line.pts)
	var d0: float = main.dist_at(Vector2(-212, -104))
	var d1: float = main.dist_at(Vector2(-140, -161))
	var hw: float = main.line.half + 1.6
	var H: float = 5.6
	var d: float = d0
	while d < d1:
		var s0: Array = r.sample(d)
		var s1: Array = r.sample(minf(d + 6.0, d1))
		var p0: Vector3 = s0[0]
		var p1: Vector3 = s1[0]
		var t0: Vector3 = s0[1]
		var t1: Vector3 = s1[1]
		var n0 := Vector3(t0.z, 0, -t0.x) # north-west: uphill side (away from the lake)
		var n1 := Vector3(t1.z, 0, -t1.x)
		# Roof slab: a hexa from road edge to road edge, 0.8 m thick.
		var c: Array = []
		for k in range(8):
			var at1: bool = k & 1
			var up: bool = k & 2
			var uphill: bool = k & 4
			var p: Vector3 = p1 if at1 else p0
			var nn: Vector3 = n1 if at1 else n0
			c.append(p + nn * ((hw + 0.6) if uphill else -(hw + 0.4)) + Vector3(0, H + (0.8 if up else 0.0) + (0.4 if uphill else 0.0), 0))
		geo.hexa(c, "ml_concrete")
		# Back wall, down into the ground.
		var w0: Vector3 = p0 + n0 * (hw + 0.3)
		var w1: Vector3 = p1 + n1 * (hw + 0.3)
		var foot: float = minf(minf(land.ground(w0.x, w0.z), land.ground(w1.x, w1.z)), minf(p0.y, p1.y)) - 0.5
		var wc: Array = []
		for k in range(8):
			var at1: bool = k & 1
			var up: bool = k & 2
			var outer: bool = k & 4
			var w: Vector3 = w1 if at1 else w0
			var nn: Vector3 = n1 if at1 else n0
			wc.append(Vector3(w.x, ((p1.y if at1 else p0.y) + H + 0.4) if up else foot, w.z) + nn * (0.3 if outer else -0.3))
		geo.hexa(wc, "ml_concrete")
		# A pillar on the lake side, every 6 m.
		var pp: Vector3 = p0 - n0 * (hw + 0.1)
		var pf: float = minf(land.ground(pp.x, pp.z), p0.y) - 0.5
		geo.box(Vector3(pp.x, (pf + p0.y + H) * 0.5, pp.z), Vector3(0.6, p0.y + H - pf, 0.8), "ml_concrete", atan2(t0.x, t0.z))
		d += 6.0
	var mid: Array = r.sample((d0 + d1) * 0.5)
	_views.append(["gallery_in", (mid[0] as Vector3) + Vector3(0, 2.5, 0) - (mid[1] as Vector3) * 40.0, (mid[0] as Vector3) + Vector3(0, 2.5, 0)])

## Log cabin on the north shore, a terrace, steps down to the pier; the
## pier (deck at DECK_Y, the spawn on it), the boathouse beside its end,
## and - right next to the spawn - the sign.
func _cabin_and_pier() -> void:
	var y: float = 4.0
	var c := Vector3(CABIN.x, y, CABIN.y)
	geo.box_on(Transform3D(Basis(), c + Vector3(0, 0.3, 0)), Vector3(10.6, 0.6, 8.6), "ml_stone", y)
	geo.box(c + Vector3(0, 2.1, 0), Vector3(10, 3.0, 8), "ml_log")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.RIGHT, s * 0.62), c + Vector3(0, 4.35, s * 2.3)), Vector3(11.4, 0.22, 5.9), "ml_shingle")
	geo.prism(Transform3D(Basis(), c + Vector3(0, 3.6, 0)), [Vector2(-4.0, 0.0), Vector2(4.0, 0.0), Vector2(0.0, 2.9)], 9.9, "ml_log")
	geo.box(c + Vector3(3.2, 5.4, -1.0), Vector3(0.9, 2.4, 0.9), "ml_stone")
	for wx in [-3.0, 3.0]:
		geo.box(c + Vector3(wx, 2.3, 4.02), Vector3(1.6, 1.2, 0.05), "ml_glass", 0.0, false)
	geo.tint = Color(0.35, 0.2, 0.14)
	geo.box(c + Vector3(0, 1.7, 4.03), Vector3(1.1, 2.1, 0.06), "ml_paint", 0.0, false)
	geo.tint = Color.WHITE
	# Terrace in front, stone steps down the bank to the pier.
	geo.box_on(Transform3D(Basis(), c + Vector3(0, 0.25, 7.5)), Vector3(10, 0.5, 7), "ml_wood", y)
	var z: float = c.z + 11.0
	while z < -150.0:
		var g: float = land.ground(0.0, z)
		geo.box_on(Transform3D(Basis(), Vector3(0, g + 0.1, z)), Vector3(2.4, 0.3, 1.2), "ml_stone", g)
		z += 1.4
	# The pier, posts down into the lake bed.
	var pz: float = -151.0
	while pz < -106.0:
		# 3 cm between the sections: with 10 cm the whoop, set down right on
		# a gap at the spawn, fell through under the pier.
		geo.box(Vector3(0, DECK_Y - 0.06, pz), Vector3(2.6, 0.12, 1.97), "ml_deck")
		for sx in [-1.2, 1.2]:
			var bed: float = land.ground(sx, pz) - 0.5
			geo.box(Vector3(sx, (bed + DECK_Y - 0.12) * 0.5, pz), Vector3(0.2, DECK_Y - 0.12 - bed, 0.2), "ml_wood")
		pz += 2.0
	# Boathouse beside the pier's end, open to the lake (south).
	var bh := Vector3(7.0, DECK_Y, -116.0)
	for sx in [-3.0, 3.0]:
		geo.box(bh + Vector3(sx * 0.9, -0.06, 0), Vector3(1.2, 0.12, 8.4), "ml_wood")
		for sz in [-4.0, 0.0, 4.0]:
			var bed: float = land.ground(bh.x + sx, bh.z + sz) - 0.5
			geo.box(Vector3(bh.x + sx, (bed + DECK_Y) * 0.5, bh.z + sz), Vector3(0.25, DECK_Y - bed, 0.25), "ml_wood")
		geo.box(bh + Vector3(sx, 1.6, 0), Vector3(0.2, 3.2, 8.4), "ml_wood")
	geo.box(bh + Vector3(0, 1.6, -4.1), Vector3(6.2, 3.2, 0.2), "ml_wood")
	geo.box(bh + Vector3(0, 3.0, 3.0), Vector3(6.2, 0.25, 0.25), "ml_wood") # tie beam (a gnome's up there)
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s * 0.5), bh + Vector3(s * 1.75, 3.95, 0)), Vector3(4.2, 0.18, 9.2), "ml_shingle")
	geo.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), bh + Vector3(0, 3.2, -4.1)), [Vector2(-3.2, 0.0), Vector2(3.2, 0.0), Vector2(0.0, 1.7)], 0.2, "ml_wood")
	Vehicles.ensure_materials(geo)
	geo.tint = Color(0.75, 0.2, 0.15)
	geo.box(Vector3(bh.x, 0.15, bh.z + 0.5), Vector3(1.5, 0.5, 4.6), "ml_paint") # a rowing boat
	geo.tint = Color.WHITE
	for k in range(3):
		Vehicles.boat(geo, Vector3(-6.0, -0.1, -129.0 + k * 9.0), PI * 0.5, k == 1)
	_sign(Vector3(1.35, DECK_Y, -137.6))
	_views.append(["boathouse", bh + Vector3(-0.5, 1.3, 9.0), bh + Vector3(1.5, 3.0, 2.0)])

## "DO NOT FLY": a red-ringed plate with a quad crossed out, on a post at
## the pier's edge, facing whoever stands at the spawn.
func _sign(p: Vector3) -> void:
	# (SignCreator's drone-ban plate - 2026-10-14, the user: the old
	# hand-made one didn't look good; the Playground's is the same model.)
	SignCreator.post(geo, p, PI + 0.5, [["no_drones", "DO NOT FLY"]], 1.0)
	_views.append(["do_not_fly", p + Vector3(-1.2, 1.4, -2.8), p + Vector3(0, 1.6, 0)])

## The island chapel: white walls, a shingle roof, a bell tower with an
## onion dome; a little landing stage.
func _chapel() -> void:
	var c := Vector3(ISLAND.x - 4.0, 0, ISLAND.y + 1.0)
	c.y = land.ground(c.x, c.z)
	var lvl: float = c.y
	for o: Array in [[Vector3(0, 0, 0), Vector2(6.4, 10.4)], [Vector3(0, 0, -6.6), Vector2(3.4, 3.4)]]:
		var q: Vector3 = c + o[0]
		var lo: float = INF
		for fx in [-0.5, 0.5]:
			for fz in [-0.5, 0.5]:
				lo = minf(lo, land.ground(q.x + fx * o[1].x, q.z + fz * o[1].y))
		geo.box(Vector3(q.x, (lo - 0.5 + lvl + 0.4) * 0.5, q.z), Vector3(o[1].x, lvl + 0.4 - lo + 0.5, o[1].y), "ml_stone")
	geo.box(c + Vector3(0, 0.4 + 2.8, 0), Vector3(6, 5.6, 10), "ml_plaster")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s * 0.72), c + Vector3(s * 1.75, 7.3, 0.3)), Vector3(4.9, 0.22, 11.0), "ml_shingle")
	geo.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0, 6.0, 5.0)), [Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Vector2(0.0, 2.6)], 0.2, "ml_plaster")
	var tw: Vector3 = c + Vector3(0, 0.4, -6.6)
	geo.box(tw + Vector3(0, 6.5, 0), Vector3(3, 13, 3), "ml_plaster")
	for k in range(4):
		var a: float = k * PI * 0.5
		geo.box(tw + Vector3(cos(a) * 1.51, 10.8, sin(a) * 1.51), Vector3(0.9 if k % 2 == 0 else 0.04, 1.4, 0.04 if k % 2 == 0 else 0.9), "ml_glass", 0.0, false)
	geo.tint = Color(0.32, 0.48, 0.4) # copper gone green
	geo.lathe(tw + Vector3(0, 13.0, 0), [Vector2(1.7, 0.0), Vector2(1.9, 0.6), Vector2(1.5, 1.5), Vector2(0.5, 2.4), Vector2(0.25, 3.2), Vector2(0.4, 3.6), Vector2(0.05, 4.4)], "ml_paint", 12)
	geo.tint = Color(0.85, 0.7, 0.3)
	geo.beam(tw + Vector3(0, 17.3, 0), tw + Vector3(0, 18.5, 0), Vector2(0.06, 0.06), "ml_paint", false)
	geo.beam(tw + Vector3(-0.35, 18.1, 0), tw + Vector3(0.35, 18.1, 0), Vector2(0.06, 0.06), "ml_paint", false)
	geo.tint = Color(0.35, 0.22, 0.15)
	geo.box(c + Vector3(0, 0.4 + 1.2, 5.02), Vector3(1.3, 2.4, 0.06), "ml_paint", 0.0, false)
	geo.tint = Color.WHITE
	for sx in [-1.0, 1.0]:
		for kz in [-2.5, 2.0]:
			geo.box(c + Vector3(sx * 3.02, 3.2, kz), Vector3(0.05, 2.2, 0.9), "ml_glass", 0.0, false)
	# Landing stage on the island's west shore.
	var ls := Vector3(ISLAND.x - 27.0, DECK_Y - 0.4, ISLAND.y + 4.0)
	for k in range(5):
		var q := ls + Vector3(k * 2.0, 0, 0)
		geo.box(q, Vector3(1.9, 0.12, 2.2), "ml_wood")
		for sz in [-1.0, 1.0]:
			var bed: float = land.ground(q.x, q.z + sz) - 0.4
			geo.box(Vector3(q.x, (bed + q.y) * 0.5, q.z + sz), Vector3(0.18, q.y - bed, 0.18), "ml_wood")

## A chalet - the alpine house: stone ground floor, plastered upper
## floors, wooden balconies with geraniums all along the front, shutters,
## a wide shallow roof with deep eaves. Frame: origin on the ground at the
## middle, front (balconies) toward +z, length along x.
func _chalet(xf: Transform3D, L: float, B: float, floors: int, rng: RandomNumberGenerator, title: String = "") -> void:
	var lvl: float = xf.origin.y
	var fh: float = 3.0
	# The stone base down to the lowest ground anywhere under it.
	var lo: float = lvl
	for fx in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			var q: Vector3 = xf * Vector3(fx * (L + 0.4), 0, fz * (B + 0.4))
			lo = minf(lo, land.ground(q.x, q.z))
	lo -= 0.3
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, (0.6 + lo - lvl) * 0.5, 0)), Vector3(L + 0.4, 0.6 - (lo - lvl), B + 0.4), "ml_stone")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.6 + fh * 0.5, 0)), Vector3(L, fh, B), "ml_stone")
	var top: float = 0.6 + fh * floors
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.6 + fh + (top - 0.6 - fh) * 0.5, 0)), Vector3(L, top - 0.6 - fh, B), "ml_plaster")
	# Gable roof along x: two slabs, the gable ends filled with boards.
	var pitch: float = 0.42
	var half: float = B * 0.5 + 1.6
	var rise: float = tan(pitch) * half
	for s in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, s * pitch), Vector3(0, top + rise * 0.5 + 0.1, s * half * 0.5)), Vector3(L + 3.2, 0.3, half / cos(pitch) + 0.1), "ml_shingle")
	for sx in [-1.0, 1.0]:
		geo.prism(xf * Transform3D(Basis(Vector3.UP, 0.0), Vector3(sx * (L * 0.5 - 0.1), top, 0)), [Vector2(-B * 0.5, 0.0), Vector2(B * 0.5, 0.0), Vector2(0.0, tan(pitch) * B * 0.5)], 0.2, "ml_wood")
	# Windows with shutters on every floor, front and back; balconies at the front.
	var n: int = maxi(2, int(L / 3.2))
	var shutter := Color(0.24, 0.4, 0.26) if rng.randf() < 0.6 else Color(0.5, 0.25, 0.18)
	for f in range(floors):
		var wy: float = 0.6 + fh * f + 1.6
		for k in range(n):
			var wx: float = -L * 0.5 + (k + 0.5) * L / n
			for side in [-1.0, 1.0]:
				var door: bool = side > 0.0 and f > 0 and k % 2 == 0
				var wh: float = 2.2 if door else 1.3
				var wcy: float = (0.6 + fh * f + 1.1) if door else wy
				geo.box_xf(xf * Transform3D(Basis(), Vector3(wx, wcy, side * (B * 0.5 + 0.02))), Vector3(1.1, wh, 0.05), "ml_glass", false)
				geo.tint = shutter
				for sx in [-1.0, 1.0]:
					geo.box_xf(xf * Transform3D(Basis(), Vector3(wx + sx * 0.85, wcy, side * (B * 0.5 + 0.06))), Vector3(0.55, wh, 0.05), "ml_paint", false)
				geo.tint = Color.WHITE
		if f > 0:
			# The balcony: deck on brackets, boarded rail, flower boxes.
			var by: float = 0.6 + fh * f
			geo.box_xf(xf * Transform3D(Basis(), Vector3(0, by - 0.1, B * 0.5 + 0.8)), Vector3(L - 0.4, 0.2, 1.6), "ml_wood")
			geo.box_xf(xf * Transform3D(Basis(), Vector3(0, by + 0.55, B * 0.5 + 1.55)), Vector3(L - 0.4, 0.9, 0.08), "ml_wood")
			for sx in [-1.0, 1.0]:
				geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (L * 0.5 - 0.24), by + 0.55, B * 0.5 + 0.8)), Vector3(0.08, 0.9, 1.6), "ml_wood")
			geo.tint = Color(0.86, 0.12, 0.12)
			geo.box_xf(xf * Transform3D(Basis(), Vector3(0, by + 1.2, B * 0.5 + 1.62)), Vector3(L - 0.8, 0.22, 0.24), "ml_paint", false)
			geo.tint = Color(0.3, 0.5, 0.2)
			geo.box_xf(xf * Transform3D(Basis(), Vector3(0, by + 1.04, B * 0.5 + 1.62)), Vector3(L - 0.7, 0.1, 0.3), "ml_paint", false)
			geo.tint = Color.WHITE
	if title != "":
		var gx := xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(L * 0.5 + 0.02, top - 1.2, 0))
		StreetKit._label(geo, title, gx, 0.012, Color(0.25, 0.15, 0.1))
		StreetKit._label(geo, title, xf * Transform3D(Basis(), Vector3(0, 0.6 + fh - 0.45, B * 0.5 + 0.03)), 0.009, Color(0.95, 0.92, 0.85))

func _hotel(lane: RoadCreator) -> void:
	var rng := _local_rng(5)
	var y: float = HOTEL_Y
	var face := Vector2(-1, 1).normalized() # front toward the valley road, long side along it (2026-10-16: a corner stood on it)
	var yaw: float = atan2(face.x, face.y)
	geo.begin_object("hotel", "Seeblick") # (the layout check sees it against roads and houses)
	_chalet(Transform3D(Basis(Vector3.UP, yaw), Vector3(HOTEL.x, y, HOTEL.y)), 40.0, 15.0, 4, rng, "HOTEL SEEBLICK")
	geo.end_object()
	# Cars on the forecourt by the lane's turning circle.
	var e: Vector3 = lane.line.pts[lane.line.pts.size() - 1]
	# (on a paved lot: cars rest on it)
	var lot: Vector3 = e + Vector3(-9.0, 0, -6.0)
	lot.y = land.ground(lot.x, lot.z)
	geo.box_on(Transform3D(Basis(), lot + Vector3(0, 0.03, 0)), Vector3(5.5, 0.14, 16.5), "ml_lot", lot.y)
	for k in range(5):
		var q: Vector3 = e + Vector3(-9.0, 0, -12.0 + k * 3.0)
		q.y = lot.y + 0.1
		fleet.car(q, PI * 0.5, Fleet.random_paint(rng), ["suv", "estate", "hatch"][k % 3])

## Campground on the east meadow: tents and caravans, a washroom hut.
func _camp(rng: RandomNumberGenerator) -> void:
	for i in range(16):
		var q := Vector3(CAMP.x + rng.randf_range(-26, 26), 0, CAMP.y + rng.randf_range(-24, 24))
		q.y = land.ground(q.x, q.z)
		if geo.blocked(Vector2(q.x, q.z), 3.5, q.y, q.y + 3.0):
			continue
		if i % 3 == 0:
			var yaw: float = rng.randf() * TAU
			geo.tint = Color(0.95, 0.94, 0.9)
			geo.box_on(Transform3D(Basis(Vector3.UP, yaw), q + Vector3(0, 1.3, 0)), Vector3(2.3, 2.6, 6.2), "ml_paint", q.y)
			geo.tint = Color(0.3, 0.5, 0.7)
			geo.box_xf(Transform3D(Basis(Vector3.UP, yaw), q + Vector3(0, 1.0, 0)), Vector3(2.36, 0.25, 6.26), "ml_paint", false) # (2 cm proud: 1 cm flickered)
			geo.tint = Color.WHITE
		else:
			var foot: float = geo.sunk([q + Vector3(1.8, 0, 0), q + Vector3(-1.8, 0, 0), q + Vector3(0, 0, 1.8), q + Vector3(0, 0, -1.8)], q.y)
			geo.tint = [Color(0.85, 0.3, 0.15), Color(0.2, 0.5, 0.3), Color(0.9, 0.75, 0.2), Color(0.25, 0.35, 0.6)][rng.randi() % 4]
			geo.cone(Vector3(q.x, foot, q.z), q + Vector3(0, 1.6, 0), 1.8, 0.05, "ml_paint", 4)
			geo.tint = Color.WHITE
	var hut := Vector3(CAMP.x - 30.0, 2.4, CAMP.y - 10.0)
	geo.box_on(Transform3D(Basis(), hut + Vector3(0, 1.4, 0)), Vector3(8, 2.8, 4), "ml_wood", hut.y)
	geo.box(hut + Vector3(0, 2.95, 0), Vector3(8.8, 0.3, 4.8), "ml_shingle")

## Cable car: the valley station by the north road, five towers up the
## slope, the top station under the summit (with its restaurant), two
## cables, gondolas on the way. Both stations are open where the cables
## run in round the bull wheel - fly through.
func _cable_car() -> void:
	var a3 := Vector3(CABLE_A.x, land.ground(CABLE_A.x, CABLE_A.y), CABLE_A.y)
	var b3 := Vector3(CABLE_B.x, land.ground(CABLE_B.x, CABLE_B.y), CABLE_B.y)
	var dir: Vector3 = (b3 - a3)
	dir.y = 0.0
	dir = dir.normalized()
	var yaw: float = atan2(dir.x, dir.z)
	var side := Vector3(dir.z, 0, -dir.x)
	var heads: Array[Vector3] = []
	for e: Array in [[a3, 1.0], [b3, -1.0]]:
		var p: Vector3 = e[0]
		var xf := Transform3D(Basis(Vector3.UP, yaw), p)
		# Concrete hall, open toward the line, the bull wheel inside.
		geo.box_on(xf * Transform3D(Basis(), Vector3(0, 0.25, 0)), Vector3(14, 0.5, 18), "ml_concrete", p.y)
		for sx in [-1.0, 1.0]:
			geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * 6.7, 4.5, -e[1] * 3.0)), Vector3(0.6, 8.0, 12.0), "ml_concrete")
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 4.5, -e[1] * 8.7)), Vector3(14.0, 8.0, 0.6), "ml_concrete")
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 8.8, -e[1] * 1.0)), Vector3(15.0, 0.6, 20.0), "ml_concrete")
		geo.tint = Color(0.78, 0.14, 0.12)
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 9.3, -e[1] * 1.0)), Vector3(15.2, 0.4, 20.2), "ml_paint")
		geo.tint = Color.WHITE
		var wheel: Vector3 = xf * Vector3(0, 6.2, -e[1] * 2.0)
		geo.cylinder(wheel + Vector3(0, -0.15, 0), wheel + Vector3(0, 0.15, 0), 2.8, "ml_steel", 20, false)
		geo.cylinder(xf * Vector3(0, 0.5, -e[1] * 2.0), wheel, 0.4, "ml_steel", 8)
		heads.append(wheel + dir * e[1] * 2.8)
		_views.append(["station_%s" % ("a" if e[1] > 0.0 else "b"), xf * Vector3(3.0, 6.0, e[1] * 22.0), wheel])
	# Towers: tapered steel legs, a cross arm with the cable saddles.
	var tops: Array[Vector3] = [heads[0]]
	var n: int = 5
	for i in range(1, n + 1):
		var f: float = float(i) / (n + 1)
		var p: Vector3 = a3.lerp(b3, f)
		var g: float = land.ground(p.x, p.z)
		var top := Vector3(p.x, g + 16.0 + 6.0 * sin(f * PI), p.z)
		for sx in [-1.0, 1.0]:
			var foot: Vector3 = Vector3(p.x, 0, p.z) + side * sx * 1.6
			var lo: float = INF
			for o: Vector3 in [Vector3(0.4, 0, 0.4), Vector3(-0.4, 0, 0.4), Vector3(0.4, 0, -0.4), Vector3(-0.4, 0, -0.4)]:
				lo = minf(lo, land.ground(foot.x + o.x, foot.z + o.z))
			geo.box(Vector3(foot.x, (lo - 0.5 + top.y - 0.3) * 0.5, foot.z), Vector3(0.55, top.y - 0.3 - lo + 0.5, 0.55), "ml_steel", yaw)
		geo.box(top, Vector3(0.6, 0.6, 7.0), "ml_steel", yaw + PI * 0.5)
		tops.append(top + Vector3(0, 0.3, 0))
	tops.append(heads[1])
	var cables: Array = []
	for sx in [-2.8, 2.8]:
		var line: Array[Vector3] = []
		for i in range(tops.size()):
			line.append(tops[i] + side * sx)
		cables.append(line)
		for i in range(line.size() - 1):
			# In 10 m pieces (a gondola hangs from them: the floating check
			# skips one long diagonal's bounding box).
			var pieces: int = ceili(line[i].distance_to(line[i + 1]) / 10.0)
			for j in range(pieces):
				geo.beam(line[i].lerp(line[i + 1], float(j) / pieces), line[i].lerp(line[i + 1], float(j + 1) / pieces), Vector2(0.07, 0.07), "ml_cable", false, false)
	# Gondolas: one each way between some towers.
	var k: int = 0
	for i in [1, 3, 4]:
		var line: Array[Vector3] = cables[k % 2]
		var hang: Vector3 = line[i].lerp(line[i + 1], 0.45)
		geo.beam(hang, hang + Vector3(0, -2.6, 0), Vector2(0.1, 0.1), "ml_steel", false)
		geo.tint = Color(0.8, 0.16, 0.12)
		geo.box(hang + Vector3(0, -3.9, 0), Vector3(2.0, 2.4, 2.0), "ml_paint", yaw)
		geo.tint = Color.WHITE
		geo.box(hang + Vector3(0, -3.6, 0), Vector3(2.04, 0.9, 1.6), "ml_glass", yaw, false)
		k += 1
	# Up top: the restaurant (a chalet) and the summit cross.
	var rp := Vector2(CABLE_B.x - 8.0, CABLE_B.y - 26.0)
	var ry: float = land.ground(rp.x, rp.y)
	_chalet(Transform3D(Basis(Vector3.UP, yaw + PI), Vector3(rp.x, ry, rp.y)), 18.0, 10.0, 2, _local_rng(9), "BERGSTATION")
	var sy: float = land.ground(SUMMIT.x, SUMMIT.y)
	var sc := Vector3(SUMMIT.x, sy, SUMMIT.y)
	geo.box_on(Transform3D(Basis(), sc + Vector3(0, 0.4, 0)), Vector3(1.6, 0.8, 1.6), "ml_stone", sy)
	geo.beam(sc + Vector3(0, 0.5, 0), sc + Vector3(0, 6.5, 0), Vector2(0.3, 0.3), "ml_log")
	geo.beam(sc + Vector3(-1.6, 5.0, 0), sc + Vector3(1.6, 5.0, 0), Vector2(0.28, 0.28), "ml_log")
	geo.tint = Color(0.85, 0.7, 0.3)
	geo.box(sc + Vector3(0, 5.0, 0.18), Vector3(0.5, 0.6, 0.08), "ml_paint", 0.0, false) # the summit book's box
	geo.tint = Color.WHITE

## Easter egg (2026-10-14): on the slope below the cable car's top station
## the rocks lie in the shape of a quad seen from above - a boulder body,
## four arms of stones and four round rotors of stones, ~28 m across. From
## the station's windows and the drone's first climb it is just rocks;
## from straight above it is a drone. The spot is the flattest place
## 40-60 m downhill of the station that is off every road (searched
## deterministically, same every build).
func _quad_rocks() -> void:
	var best := Vector2.INF
	var best_score: float = INF
	var zb: float = land.ground(CABLE_B.x, CABLE_B.y)
	for ai in range(24):
		var a: float = TAU * ai / 24.0
		for r in [40.0, 50.0, 60.0]:
			var q: Vector2 = CABLE_B + Vector2(cos(a), sin(a)) * r
			var g: float = land.ground(q.x, q.y)
			if g > zb - 4.0 or g < zb - 45.0 or land.on_line(q.x, q.y, 18.0) or land.in_pond(q.x, q.y, 16.0) or geo.on_lane(q, 18.0):
				continue
			var lo: float = INF
			var hi: float = -INF
			for k in range(12):
				var p: Vector2 = q + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * 14.0
				var h: float = land.ground(p.x, p.y)
				lo = minf(lo, h)
				hi = maxf(hi, h)
			var score: float = hi - lo + absf(g - (zb - 15.0)) * 0.1
			if score < best_score:
				best_score = score
				best = q
	if best == Vector2.INF:
		return
	var rr := RandomNumberGenerator.new()
	rr.seed = 6174
	var stones: Array = [[Vector2.ZERO, 2.0]]
	for k in range(4):
		var d := Vector2(cos(PI * 0.25 + PI * 0.5 * k), sin(PI * 0.25 + PI * 0.5 * k))
		var c: Vector2 = d * 10.0
		for j in range(4):
			stones.append([d * (3.4 + j * 1.5), rr.randf_range(0.6, 0.8)])
		stones.append([c, 1.5])
		for j in range(10):
			var b: float = TAU * j / 10.0 + k
			stones.append([c + Vector2(cos(b), sin(b)) * 4.0, rr.randf_range(0.85, 1.1)])
		for j in range(4):
			var b2: float = TAU * j / 4.0 + 0.4
			stones.append([c + Vector2(cos(b2), sin(b2)) * 1.9, rr.randf_range(0.7, 0.9)])
	for st: Array in stones:
		var p: Vector2 = best + (st[0] as Vector2) + Vector2(rr.randf_range(-0.12, 0.12), rr.randf_range(-0.12, 0.12))
		var rad: float = st[1]
		if land.on_line(p.x, p.y, rad + 1.0) or land.in_pond(p.x, p.y, rad + 1.0):
			continue
		var lo2: float = INF
		var hi2: float = -INF
		# (every point the floating check looks at: the centre, the sides and
		# the corners of the stone's square footprint - a steep slope drops
		# away fastest at the corners)
		for o: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
			var h2: float = land.ground(p.x + o.x * rad, p.y + o.y * rad)
			lo2 = minf(lo2, h2)
			hi2 = maxf(hi2, h2)
		var h: float = (hi2 - lo2) + 0.3 + rad * 0.85
		geo.tint = Color.WHITE.lerp(Color(0.8, 0.82, 0.86), rr.randf())
		geo.lathe(Vector3(p.x, lo2 - 0.3, p.y), [Vector2(rad * 1.05, 0.0), Vector2(rad, h * 0.45), Vector2(rad * 0.7, h * 0.85), Vector2(0.01, h)], "ml_stone", 9)
	geo.tint = Color.WHITE

## The waterfall's water (v3 2026-10-14, on by default; the
## user: "still doesn't look like water"): thin see-through water in the
## lake's colour with fast white streaks running down it, turning to
## aerated white toward the foot - a real fall is mostly white there.
## `flow` = the fall's direction on the ground, `top`/`foot` = its heights.
func _falls_mat(flow: Vector2 = Vector2(-1, 0), top: float = 60.0, foot: float = 0.0) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec3 water = vec3(%f, %f, %f);
uniform vec2 flow = vec2(-1.0, 0.0);
uniform float top_y = 60.0;
uniform float foot_y = 0.0;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// Across the fall, and down it (height, plus distance along the ground
	// where it runs over the shore).
	float across = dot(wpos.xz, vec2(-flow.y, flow.x));
	float down = -wpos.y + dot(wpos.xz, flow) * 0.35;
	// Long thin streaks, stretched down the fall, running fast (two speeds:
	// the water accelerates and the streaks slide over each other).
	float s1 = texture(noise, vec2(across * 0.15, down * 0.005 - TIME * 0.3)).r;
	float s2 = texture(noise, vec2(across * 0.4 + 0.37, down * 0.01 - TIME * 0.6)).r;
	float s3 = texture(noise, vec2(across * 0.9 + 0.71, down * 0.022 - TIME * 1.1)).r;
	float streak = clamp((s1 * 0.4 + s2 * 0.35 + s3 * 0.35 - 0.55) * 1.8 + 0.55, 0.0, 1.0);
	// More air in it toward the foot (COLOR.g: 0 at the lip, 1 at the foot).
	float aer = COLOR.g;
	float foam = smoothstep(0.68 - aer * 0.14, 0.78 - aer * 0.1, streak) * 0.9;
	// The body in the lake's own colour (user: as dark as the lake), white
	// only in the streaks.
	// (Foam, spray and mist: #C2DEEC, a blue-white - user 2026-10-14.)
	ALBEDO = mix(water * 1.05, vec3(0.76, 0.87, 0.93), foam);
	float a = mix(0.72, 0.96, foam);
	// Ragged edges (COLOR.r: 0 at the edge, 1 in the middle), torn more
	// as it falls, and holes opening in the thin water low down.
	// (The noise only spans ~0.3-0.7: stretched to 0-1 first.)
	float tear = clamp((texture(noise, vec2(across * 0.25 + 0.13, down * 0.03 - TIME * 0.8)).r - 0.5) * 2.8 + 0.5, 0.0, 1.0);
	a *= smoothstep(0.0, 0.12, COLOR.r - (tear - 0.5) * (0.35 + aer * 0.75));
	a *= 1.0 - (1.0 - foam) * smoothstep(0.3, 0.1, tear) * aer;
	// A side stream's ends (COLOR.b) fade into the rock.
	a *= COLOR.b;
	ALPHA = clamp(a, 0.0, 0.97);
}
""" % [Geo.WATER_DEEP.r, Geo.WATER_DEEP.g, Geo.WATER_DEEP.b]
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise", _falls_noise(7))
	m.render_priority = 1 # (over the lake, which is see-through too)
	m.set_shader_parameter("flow", flow.normalized())
	m.set_shader_parameter("top_y", top)
	m.set_shader_parameter("foot_y", foot)
	m.set_meta("keep_material", true)
	return m

static func _falls_noise(sd: int) -> NoiseTexture2D:
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.seed = sd
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	nt.noise = fn
	return nt

## Where the fall hits the lake: aerated white
## round the impact, broken up and churning, ripple rings running out
## over the lake and foam drifting off. One disc on the water, drawn by
## a shader round `centre`.
func _splash_mat(centre: Vector2, flow: Vector2) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform vec2 centre;
uniform float fade_r = 1000.0; // (fades out by this radius: a small patch must not end in a rim)
uniform vec2 flow;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 d = wpos.xz - centre;
	// Stretched downstream: the foam drifts off with the current.
	float ds = dot(d, flow);
	vec2 e = vec2(dot(d, vec2(-flow.y, flow.x)), ds > 0.0 ? ds * 0.55 : ds);
	float r = length(e);
	float n1 = texture(noise, d * 0.06 + vec2(TIME * 0.05, -TIME * 0.04)).r;
	float n2 = texture(noise, d * 0.17 - vec2(TIME * 0.11, TIME * 0.07)).r;
	float churn = n1 * 0.5 + n2 * 0.5;
	// The boiling white core.
	float core = (1.0 - smoothstep(1.5, 5.5, r + (churn - 0.5) * 5.0)) * 0.8;
	// Ripple rings running out from it.
	float ph = fract(r * 0.22 - TIME * 0.6);
	float ring = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.08, 0.3, ph));
	ring *= smoothstep(4.0, 7.0, r) * (1.0 - smoothstep(10.0, 19.0, r));
	// Patches of foam drifting off.
	float patch = smoothstep(0.66, 0.8, churn) * (1.0 - smoothstep(6.0, 18.0, r));
	float a = max(core * (0.75 + churn * 0.25), max(ring * 0.32, patch * 0.65));
	a *= 1.0 - smoothstep(fade_r * 0.55, fade_r, length(d));
	ALBEDO = vec3(0.76, 0.87, 0.93);
	ALPHA = clamp(a, 0.0, 0.97);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise", _falls_noise(23))
	m.render_priority = 2
	m.set_shader_parameter("centre", centre)
	m.set_shader_parameter("flow", flow.normalized())
	m.set_meta("keep_material", true)
	return m

## Mist and spray where the fall lands: soft white puffs
## rising and drifting off, and drops thrown up. Not solid, no shadow.
func _falls_mist(at: Vector3, flow: Vector2) -> void:
	var soft := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.2, 1.0, r));
}
"""
	soft.shader = sh
	soft.set_meta("keep_material", true)
	var puff := QuadMesh.new()
	puff.size = Vector2(5.0, 5.0)
	puff.material = soft
	var node := Node3D.new()
	node.name = "FallsMist"
	node.set_meta("dynamic", true)
	add_child(node)
	var f3 := Vector3(flow.x, 0, flow.y).normalized()
	var mist := CPUParticles3D.new()
	mist.name = "Mist"
	mist.mesh = puff
	mist.amount = 20
	mist.lifetime = 4.0
	mist.preprocess = 4.0
	mist.position = at
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 3.0
	mist.direction = Vector3(0, 1, 0) + f3 * 0.6
	mist.spread = 35.0
	mist.initial_velocity_min = 0.8
	mist.initial_velocity_max = 2.0
	mist.gravity = Vector3(0, 0.15, 0)
	mist.damping_min = 0.2
	mist.damping_max = 0.4
	mist.scale_amount_min = 0.7
	mist.scale_amount_max = 1.8
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.6))
	mist.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.76, 0.87, 0.93, 0.0))
	fade.add_point(0.2, Color(0.76, 0.87, 0.93, 0.24))
	fade.set_color(fade.get_point_count() - 1, Color(0.76, 0.87, 0.93, 0.0))
	mist.color_ramp = fade
	mist.visibility_aabb = AABB(Vector3(-25, -5, -25), Vector3(50, 30, 50))
	node.add_child(mist)
	# Spray: small drops thrown up and falling back.
	var drop := QuadMesh.new()
	drop.size = Vector2(0.35, 0.35)
	drop.material = soft
	var spray := CPUParticles3D.new()
	spray.name = "Spray"
	spray.mesh = drop
	spray.amount = 36
	spray.lifetime = 1.4
	spray.preprocess = 1.4
	spray.position = at
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 2.5
	spray.direction = Vector3(0, 1, 0) + f3 * 0.4
	spray.spread = 40.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 6.5
	spray.gravity = Vector3(0, -9.8, 0)
	var fade2 := Gradient.new()
	fade2.set_color(0, Color(0.76, 0.87, 0.93, 0.7))
	fade2.set_color(1, Color(0.76, 0.87, 0.93, 0.0))
	spray.color_ramp = fade2
	spray.visibility_aabb = AABB(Vector3(-15, -3, -15), Vector3(30, 15, 30))
	node.add_child(spray)

## The creek (2026-10-15, user: the water above the falls wasn't clean;
## start it at a spring): out of the rocks at the head of its gully, a
## clear stream to the lip of the falls in the falls' own flowing water,
## laid on the ground every metre along and across (the old ribbon cut in
## and out of the 8 m terrain grid), a little meander, ragged banks.
func _creek() -> void:
	var col: Dictionary = {}
	var L: float = SPRING.distance_to(FALL_TOP)
	var dir: Vector2 = (FALL_TOP - SPRING) / L
	var side := Vector2(-dir.y, dir.x)
	var rows: Array = []
	var d: float = 0.0
	while d <= L + 0.01:
		var k: float = d / L
		var c: Vector2 = SPRING + dir * d + side * (2.2 * sin(d / 15.0) * smoothstep(0.0, 12.0, d) * smoothstep(L, L - 15.0, d))
		var hw: float = lerpf(0.5, 2.4, smoothstep(0.0, 25.0, d)) + 0.3 * k
		# (lifted to meet the falls' first row at the lip)
		var lift: float = lerpf(0.1, 0.3, smoothstep(L - 6.0, L, d))
		var row := PackedVector3Array()
		for j in range(5):
			var u: float = (j - 2) / 2.0
			var q: Vector2 = c + side * (u * hw)
			var p := Vector3(q.x, land.ground(q.x, q.y) + lift, q.y)
			row.append(p)
			col[p] = Color(1.0 - absf(u), 0.0, smoothstep(0.0, 2.5, d))
		rows.append(row)
		d += 1.0
	geo.light_fn = func(_nn: Vector3, pp: Vector3) -> Color: return col.get(pp, Color(1, 0, 1))
	geo.strip(rows, "ml_falls")
	for k in range(0, rows.size() - 4, 4): # (no tree or rock in the creek)
		var a0: Vector3 = rows[k][2]
		var a1: Vector3 = rows[k + 4][2]
		var al := Vector2(a1.x - a0.x, a1.z - a0.z)
		geo.reserve(Vector2((a0.x + a1.x) * 0.5, (a0.z + a1.z) * 0.5), al.normalized(), Vector2(al.length() * 0.5 + 0.5, 3.2), minf(a0.y, a1.y) - 6.0, maxf(a0.y, a1.y) + 8.0)
	geo.light_fn = Callable()
	var gy: float = land.ground(SPRING.x, SPRING.y)
	_views.append(["spring", Vector3(SPRING.x - 14.0, gy + 7.0, SPRING.y), Vector3(SPRING.x + 2.0, gy + 0.5, SPRING.y)])
	_views.append(["creek", Vector3(SPRING.x - 20.0, gy + 30.0, SPRING.y + 40.0), Vector3(SPRING.x - 55.0, gy - 6.0, SPRING.y)])

## The waterfall: the creek from its spring across the pasture, then down
## the gully in a white curtain, foam where it meets the lake.
func _waterfall() -> void:
	_creek()
	var rows: Array = []
	var dirv: Vector2 = (FALL_FOOT - FALL_TOP).normalized()
	var m: int = 24
	if Geo.unified_water:
		_fall_streams(dirv)
		m = -1 # (the main stream's rows come from _fall_streams)
		rows = _fall_main
	for k in range(m + 1):
		var f: float = float(k) / m
		var q: Vector2 = FALL_TOP + dirv * (f * FALL_TOP.distance_to(FALL_FOOT))
		# Down the gully, standing off its floor in the steep middle (the
		# water leaves the rock there - a ledge behind it).
		var y: float = maxf(land.ground(q.x, q.y) + 0.3 + 2.6 * sin(PI * pow(f, 0.8)), 0.04)
		var w: float = lerpf(2.6, 6.0, f)
		var c := Vector3(q.x, y, q.y)
		var acr := Vector3(-dirv.y, 0, dirv.x)
		rows.append(PackedVector3Array([c - acr * w, c + acr * w]))
	# On over the shore and INTO the lake: the water runs down the last of
	# the rock and dips under the surface - no gap, no fall ending on dry
	# rock (2026-10-14, user). Its foam ring is where it meets the lake.
	var acr2 := Vector3(-dirv.y, 0, dirv.x)
	var entry := Vector2.INF
	var under: bool = false
	var t: float = 1.5
	while t < 45.0:
		var q2: Vector2 = FALL_FOOT + dirv * t
		var g2: float = land.ground(q2.x, q2.y)
		# Clear of the lake's surface either way (within a few cm they
		# flicker): over the rock, or under the water.
		var y2: float = g2 + 0.15
		if y2 < WATER_Y + 0.12:
			y2 = WATER_Y - 0.15
			if not under:
				# Straight down through the surface (a slope would cross it),
				# and that is where it ends: under the water nobody sees it,
				# and it would hang over the lake bed.
				under = true
				var last: PackedVector3Array = rows[rows.size() - 1]
				var down_row := PackedVector3Array()
				for lp: Vector3 in last:
					down_row.append(Vector3(lp.x, y2, lp.z))
					_fall_col[down_row[down_row.size() - 1]] = _fall_col.get(lp, Color.WHITE)
				rows.append(down_row)
				entry = Vector2(last[0].x + last[last.size() - 1].x, last[0].z + last[last.size() - 1].z) * 0.5 + dirv * (0.5 if Geo.unified_water else 2.0)
				break
		if Geo.unified_water:
			rows.append(_fall_row(Vector3(q2.x, y2, q2.y), acr2, 6.2, 6.2, 0.15, 1.0, 1.0))
		else:
			rows.append(PackedVector3Array([Vector3(q2.x, y2, q2.y) - acr2 * 6.2, Vector3(q2.x, y2, q2.y) + acr2 * 6.2]))
		if g2 < WATER_Y - 0.4:
			if entry == Vector2.INF:
				entry = q2
			elif q2.distance_to(entry) > 3.0:
				break
		t += 1.5
	if entry == Vector2.INF:
		entry = FALL_FOOT + dirv * 14.0
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.1, 1.12, 1.16)
	if Geo.unified_water:
		# Per corner: how far in from the edge, how far down, the stream's end.
		geo.light_fn = func(_nn: Vector3, pp: Vector3) -> Color: return _fall_col.get(pp, Color(0, 1, 1))
		for side_rows: Array in _fall_side:
			geo.strip(side_rows, "ml_falls")
	geo.strip(rows, "ml_falls")
	# No tree in the falling water: its strip is kept clear of scatter.
	for k in range(rows.size() - 1):
		var r0: PackedVector3Array = rows[k]
		var r1: PackedVector3Array = rows[k + 1]
		var mid0: Vector3 = (r0[0] + r0[1]) * 0.5
		var mid1: Vector3 = (r1[0] + r1[1]) * 0.5
		var along := Vector2(mid1.x - mid0.x, mid1.z - mid0.z)
		if along.length() < 0.05:
			continue
		geo.reserve(Vector2((mid0.x + mid1.x) * 0.5, (mid0.z + mid1.z) * 0.5), along.normalized(), Vector2(along.length() * 0.5 + 0.5, r0[0].distance_to(r0[1]) * 0.5 + 1.5), minf(mid0.y, mid1.y) - 2.0, maxf(mid0.y, mid1.y) + 8.0)
	if Geo.unified_water:
		var top_y: float = (rows[0][0].y + rows[0][1].y) * 0.5
		geo.material("ml_falls").set_shader_parameter("flow", dirv)
		geo.material("ml_falls").set_shader_parameter("top_y", top_y)
		geo.material("ml_falls").set_shader_parameter("foot_y", WATER_Y)
		geo.add_material("ml_splash", _splash_mat(entry, dirv))
		var disc: Array[Vector3] = []
		for k in range(24):
			var an3: float = TAU * k / 24.0
			disc.append(Vector3(entry.x, WATER_Y + 0.06, entry.y) + Vector3(cos(an3), 0, sin(an3)) * 20.0 + Vector3(dirv.x, 0, dirv.y) * 8.0)
		geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color.WHITE
		geo.polygon(disc, "ml_splash", false)
		geo.light_fn = Callable()
		_falls_mist(Vector3(entry.x, WATER_Y + 1.0, entry.y), dirv)
		return
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.3, 1.32, 1.35) # (foam: bright white in the sun)
	var foam := Vector3(entry.x, WATER_Y + 0.06, entry.y)
	var pts: Array[Vector3] = []
	for k in range(12):
		var an: float = TAU * k / 12.0
		pts.append(foam + Vector3(cos(an) * 7.0, 0, sin(an) * 6.0))
	geo.polygon(pts, "ml_foam", false)
	# Foam drifting off on the lake: a few smaller patches.
	var frng := RandomNumberGenerator.new()
	frng.seed = 41
	for k in range(6):
		var fc: Vector3 = foam + Vector3(dirv.x, 0, dirv.y) * frng.randf_range(7.0, 16.0) + acr2 * frng.randf_range(-7.0, 7.0)
		var fp: Array[Vector3] = []
		var fr: float = frng.randf_range(0.8, 2.2)
		for j in range(8):
			var an2: float = TAU * j / 8.0
			fp.append(fc + Vector3(cos(an2) * fr * frng.randf_range(0.7, 1.2), 0, sin(an2) * fr * frng.randf_range(0.7, 1.2)))
		geo.polygon(fp, "ml_foam", false)
	geo.light_fn = Callable()

## The waterfall's shape (v3 2026-10-14, user: "a natural
## curved sheet that leaves the lip, thins and breaks up as it falls,
## uneven edges, several streams"): a main sheet bowed out from the rock,
## shooting off the lip, with ragged edges, and two thinner side streams
## that split off on the rock and run back into it lower down. Each row
## is five points across; their vertex colours tell the shader how far
## in from the edge (r), how far down (g) and how near the stream's end
## (b) each corner is - the shader tears the edges and opens holes.
var _fall_main: Array = []
var _fall_side: Array = []
var _fall_col: Dictionary = {}

func _fall_row(c: Vector3, acr: Vector3, wl: float, wr: float, bow: float, f: float, fade: float) -> PackedVector3Array:
	var row := PackedVector3Array()
	for j in range(5):
		var u: float = (j - 2) / 2.0 # -1..1 across
		var w: float = wl if u < 0.0 else wr
		var q: Vector3 = c + acr * (u * w) + Vector3(0, bow * (1.0 - u * u), 0)
		row.append(q)
		_fall_col[q] = Color(1.0 - absf(u), f, fade)
	return row

func _fall_streams(dirv: Vector2) -> void:
	_fall_main = []
	_fall_side = []
	_fall_col = {}
	var acr := Vector3(-dirv.y, 0, dirv.x)
	var nz := FastNoiseLite.new()
	nz.seed = 77
	nz.frequency = 0.9
	var L: float = FALL_TOP.distance_to(FALL_FOOT)
	# [across offset at the top, at the foot, width top, width foot,
	#  stand-off from the rock, from f, to f]
	var specs: Array = [[0.0, 0.0, 2.2, 5.6, 3.0, 0.0, 1.0],
		[-6.0, -4.2, 0.8, 1.4, 1.7, 0.1, 0.85],
		[5.5, 4.6, 0.6, 1.2, 2.1, 0.2, 0.92]]
	for si in range(specs.size()):
		var sp: Array = specs[si]
		var out: Array = []
		var m: int = 28
		for k in range(m + 1):
			var f: float = lerpf(sp[5], sp[6], float(k) / m)
			var off: float = lerpf(sp[0], sp[1], f)
			var q: Vector2 = FALL_TOP + dirv * (f * L) + Vector2(acr.x, acr.z) * off
			# (Each stream on the rock under its own middle: the gully's
			# sides rise, a side stream runs on them.)
			var g: float = land.ground(q.x, q.y)
			# Off the lip it shoots out fast, then falls back toward the rock.
			var y: float = maxf(g + 0.3 + sp[4] * sin(PI * pow(f, 0.6)), 0.04)
			var w: float = lerpf(sp[2], sp[3], f)
			# Ragged: each edge wanders on its own, more as it falls.
			var wl: float = w * (1.0 + (0.15 + 0.3 * f) * nz.get_noise_2d(f * L * 0.25, 10.0 + si * 31.0))
			var wr: float = w * (1.0 + (0.15 + 0.3 * f) * nz.get_noise_2d(f * L * 0.25, 50.0 + si * 31.0))
			var fade: float = 1.0
			if si > 0:
				fade = minf(smoothstep(0.0, 0.25, float(k) / m), 1.0 - smoothstep(0.7, 1.0, float(k) / m))
			out.append(_fall_row(Vector3(q.x, y, q.y), acr, wl, wr, w * 0.22, f, fade))
		if si == 0:
			_fall_main = out
		else:
			_fall_side.append(out)

## Street furniture: the village's name boards, the bus stop at the
## cable car.
func _street(main: RoadCreator, lane_w: RoadCreator, hotel_ln: RoadCreator) -> void:
	StreetKit.ensure_materials(geo)
	_views.append_array(StreetKit.town_sign(geo, main, main.dist_at(Vector2(-226, 118)), 1.0, "Kaltensee", "Gemeinde Seetal"))
	StreetKit.town_sign(geo, main, main.dist_at(Vector2(-232, -70)), -1.0, "Kaltensee", "Gemeinde Seetal")
	StreetKit.give_way(geo, lane_w)
	StreetKit.give_way(geo, hotel_ln)
	_views.append_array(StreetKit.bus_stop(geo, main, main.dist_at(Vector2(-104, -186)), -1.0, "Seilbahn"))

## Spruce woods up to the treeline (~120 m), birches and maples low
## down; none on rock, roads, levelled ground or in the water. One
## spruce by the dam's west end holds a lost drone.
func _forest(trees: Array, rng: RandomNumberGenerator) -> void:
	trees.append([Vector3(-58, land.ground(-58, 236) - 0.2, 236), "spruce", 4242, "drone", true, 1.3])
	var attempts: int = 0
	var n: int = 0
	while n < 6000 and attempts < 40000:
		attempts += 1
		var x: float = rng.randf_range(-1090, 1090)
		var z: float = rng.randf_range(-1090, 1090)
		var y: float = land.ground(x, z)
		if y < 1.5 or y > 115.0 + rng.randf() * 25.0:
			continue
		if land.flatness(x, z) > 0.05 or land.on_line(x, z, 4.0) or land.in_pond(x, z, 3.0) or land._cleared(x, z):
			continue
		var slope: float = absf(land.ground(x + 3.0, z) - y) + absf(land.ground(x, z + 3.0) - y)
		if slope > 4.0:
			continue # rock face
		n += 1
		var f: float = rng.randf()
		if f < 0.84 or y > 50.0:
			trees.append([Vector3(x, y - 0.3, z), "spruce", rng.randi(), "none", true, rng.randf_range(1.0, 1.9)])
		else:
			trees.append([Vector3(x, y - 0.3, z), "birch" if rng.randf() < 0.7 else "maple", rng.randi(), "none", true, rng.randf_range(0.9, 1.4)])

func _dump() -> void:
	var gq: Vector2 = FALL_TOP.lerp(FALL_FOOT, 0.55)
	print("ML gnome0 %.2f %.2f %.2f" % [gq.x, land.ground(gq.x, gq.y), gq.y])
	for k in range(25):
		var q: Vector2 = FALL_TOP.lerp(FALL_FOOT, k / 24.0)
		print("ML fall %d %s g=%.2f" % [k, q, land.ground(q.x, q.y)])
	var line: String = "ML x=0:"
	for z in range(-210, -100, 5):
		line += " %d:%.1f" % [z, land.ground(0, z)]
	print(line)
	for nm: String in ["ISLAND", "VILLAGE", "HOTEL", "CAMP", "ALM", "TARN", "FALL_TOP", "FALL_FOOT", "SUMMIT", "CABLE_A", "CABLE_B", "CABIN"]:
		var q: Vector2 = get(nm)
		print("ML %s %s %.1f" % [nm, q, land.ground(q.x, q.y)])
	for z in range(-420, 300, 20):
		var l3: String = "ML row z=%4d:" % z
		for x in range(-520, 400, 20):
			l3 += "%4.0f" % land.ground(x, z)
		print(l3)
