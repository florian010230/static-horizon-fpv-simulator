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
## cliffs a hanging valley with a tarn and an alpine farm, its creek
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
const HOTEL := Vector2(-176, 136)
const HOTEL_Y: float = 7.5
const CAMP := Vector2(168, 96)
## The alpine farm on the hanging valley's pasture, and its tarn.
const ALM := Vector2(292, -132)
const TARN := Vector2(352, -40)
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
		return lake_fn.call(x, z) < margin + 3.0 or Vector2(x, z).distance_to(TARN) < 36.0 + margin

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
	# The gorge under the dam: rock walls ~45 m down to the river.
	if z > DAM_Z - 6.0:
		var gf: float = _gorge_floor(z)
		var wall: float = gf + smoothstep(8.0, 30.0, vx + n * 3.0) * (h - gf)
		h = lerpf(h, minf(h, wall), smoothstep(DAM_Z - 6.0, DAM_Z + 2.0, z))
	# The east cliffs and the hanging valley above them (~72 m), with the
	# gully the creek has cut down through the cliff.
	var ex: float = smoothstep(120.0, 175.0, x) * (1.0 - smoothstep(110.0, 190.0, absf(z + 50.0)))
	if ex > 0.0 and d > 0.0:
		var step: float = 72.0 * smoothstep(2.0, 50.0, d) + maxf(d - 50.0, 0.0) * 0.05
		h = lerpf(h, maxf(h, step + n * 2.0), ex)
		var gq: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(x, z), Vector2(TARN.x - 30.0, TARN.y + 8.0), FALL_FOOT)
		var gd: float = gq.distance_to(Vector2(x, z))
		h -= 7.0 * (1.0 - smoothstep(3.0, 13.0, gd)) * ex * smoothstep(0.0, 30.0, d)
	# The rock wall above the north road.
	var wd: float = _wall_d(x, z)
	if wd > 0.0:
		h += 46.0 * smoothstep(6.0, 40.0, wd) * (1.0 - smoothstep(90.0, 160.0, wd))
	# The tarn in the hanging valley: a hollow (its water drawn in _tarn).
	var dt: float = Vector2(x, z).distance_to(TARN)
	if dt < 40.0:
		h -= 5.0 * (1.0 - smoothstep(14.0, 38.0, dt))
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
	var hotel_ln := RoadCreator.branch(land, main, Vector2(-160, 170), 1.0, [Vector2(-150, 140)], 5.0, {"end": "turning", "radius": 30.0, "lead": 10.0})
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
	_waterfall()
	_tarn()
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
		["tarn", Vector3(290, 100, -10), Vector3(TARN.x, 66, TARN.y)],
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
	geo.add_material("ml_falls", falls)
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
			geo.slab(Rect2(x0, z0, s, z1 - z0), WATER_Y, 0.2, "water")
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
	# The spillway: water over a lowered stretch of the crest, down the face.
	var rows: Array = []
	var yy: float = CREST_Y - 0.3
	while yy > _gorge_floor(DAM_Z) - 0.5:
		var thick: float = 4.0 + (CREST_Y - yy) * 0.22
		var zf: float = _dam_face_z(0.0) + thick + 0.25
		rows.append(PackedVector3Array([Vector3(-5.0, yy, zf), Vector3(5.0, yy, zf)]))
		yy -= 2.0
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.05, 1.08, 1.12)
	geo.strip(rows, "ml_falls")
	geo.light_fn = Callable()
	_views.append(["spillway", Vector3(6, -24, 248), Vector3(0, -10, DAM_Z)])

## The gorge under the dam: the river on its floor (its west side),
## foam where the spillway lands, the power station on the east side
## (a toilet inside - door toward the dam).
func _gorge() -> void:
	var path: Array[Vector3] = []
	var z: float = DAM_Z + 6.0
	while z < 1200.0:
		path.append(Vector3(_gorge_x(z) - 3.0, _gorge_floor(z) + 0.3, z))
		z += 8.0
	geo.light_fn = func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0) * Color(0.9, 0.95, 1.0)
	geo.sweep(path, [Vector2(3.4, 0.0), Vector2(-3.4, 0.0)], "water", false, false, false)
	geo.light_fn = Callable()
	var foam := Vector3(0, _gorge_floor(DAM_Z) + 0.36, _dam_face_z(0.0) + 4.0 + 37.0 * 0.22 + 7.0)
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.0, 1.02, 1.05)
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
	StreetKit.ensure_materials(geo)
	geo.cylinder(p + Vector3(0, -0.6, 0), p + Vector3(0, 2.1, 0), 0.04, "sk_steel", 8)
	var xf := Transform3D(Basis(Vector3.UP, PI + 0.5), p + Vector3(0, 1.75, 0))
	geo.tint = Color(0.96, 0.96, 0.95)
	geo.box_xf(xf, Vector3(0.62, 0.78, 0.03), "sk_paint", false)
	var face := xf * Transform3D(Basis(), Vector3(0, 0.08, 0.02))
	geo.tint = Color(0.8, 0.08, 0.08)
	for k in range(16):
		var a: float = TAU * k / 16.0
		var b: float = TAU * (k + 1) / 16.0
		geo.beam(face * Vector3(cos(a) * 0.22, sin(a) * 0.22, 0), face * Vector3(cos(b) * 0.22, sin(b) * 0.22, 0), Vector2(0.05, 0.01), "sk_paint", false, false)
	geo.tint = Color(0.08, 0.08, 0.08)
	for s in [-1.0, 1.0]:
		geo.beam(face * Vector3(-0.1, -0.1 * s, 0.0), face * Vector3(0.1, 0.1 * s, 0.0), Vector2(0.025, 0.008), "sk_paint", false, false)
		for t in [-1.0, 1.0]:
			geo.cylinder(face * Vector3(0.1 * t, 0.1 * s * t, -0.004), face * Vector3(0.1 * t, 0.1 * s * t, 0.006), 0.045, "sk_paint", 10, false)
	geo.tint = Color(0.8, 0.08, 0.08)
	geo.beam(face * Vector3(-0.16, 0.16, 0.008), face * Vector3(0.16, -0.16, 0.008), Vector2(0.045, 0.01), "sk_paint", false, false)
	geo.tint = Color.WHITE
	StreetKit._label(geo, "DO NOT FLY", xf * Transform3D(Basis(), Vector3(0, -0.27, 0.02)), 0.0021, Color(0.1, 0.1, 0.1))
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
	var face: Vector2 = (Vector2(-40, 100) - HOTEL).normalized() # toward the lake
	var yaw: float = atan2(face.x, face.y)
	_chalet(Transform3D(Basis(Vector3.UP, yaw), Vector3(HOTEL.x, y, HOTEL.y)), 40.0, 15.0, 4, rng, "HOTEL SEEBLICK")
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
			geo.box_xf(Transform3D(Basis(Vector3.UP, yaw), q + Vector3(0, 1.0, 0)), Vector3(2.32, 0.25, 6.22), "ml_paint", false)
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

## The waterfall: the creek from the tarn across the pasture, then down
## the gully in a white curtain, foam where it meets the lake.
func _waterfall() -> void:
	var creek: Array[Vector3] = []
	var a := Vector2(TARN.x - 30.0, TARN.y + 8.0)
	for k in range(25):
		var q: Vector2 = a.lerp(FALL_TOP, k / 24.0)
		creek.append(Vector3(q.x, land.ground(q.x, q.y) + 0.25, q.y))
	geo.light_fn = func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0) * Color(0.95, 1.0, 1.05)
	geo.sweep(creek, [Vector2(1.6, 0.0), Vector2(-1.6, 0.0)], "water", false, false, false)
	geo.light_fn = Callable()
	var rows: Array = []
	var dirv: Vector2 = (FALL_FOOT - FALL_TOP).normalized()
	var m: int = 24
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
	geo.light_fn = func(_nn: Vector3, _p: Vector3) -> Color: return Color(1.1, 1.12, 1.16)
	geo.strip(rows, "ml_falls")
	var foam := Vector3(FALL_FOOT.x - 14.0, 0.04, FALL_FOOT.y)
	var pts: Array[Vector3] = []
	for k in range(12):
		var an: float = TAU * k / 12.0
		pts.append(foam + Vector3(cos(an) * 5.5, 0, sin(an) * 5.0))
	geo.polygon(pts, "ml_foam", false)
	geo.light_fn = Callable()

## The tarn: water in its hollow, a little under the lowest ground round it.
func _tarn() -> void:
	var lo: float = INF
	for k in range(24):
		var a: float = TAU * k / 24.0
		lo = minf(lo, land.ground(TARN.x + cos(a) * 30.0, TARN.y + sin(a) * 30.0))
	var c := Vector3(TARN.x, lo - 0.4, TARN.y)
	geo.light_fn = func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0)
	geo.cylinder(c + Vector3(0, -0.2, 0), c, 30.0, "tr_water", 32, true)
	geo.light_fn = Callable()

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
