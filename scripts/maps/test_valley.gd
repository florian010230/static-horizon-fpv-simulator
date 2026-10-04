extends BuiltMap

## Test Valley - test bed for the map creators, laid out by hand: a
## village in the floor of a river valley, houses on both banks, joined
## by a stone arch bridge. Not a finished map.
##
## Layout (north = -z): a valley runs north-south, its sides rising ~30 m
## to wooded hills. The river runs down its floor (x about -20). The
## main road follows the east bank north-south and on into the haze both
## ways; the bridge street leaves it westward over the river on an arch
## bridge to the west-bank houses, ending in a turning circle; a lane
## climbs east toward the hill. The green is on the east bank by the
## bridge, a pond on the west-bank meadow to the north, woods on the
## valley sides. Around the village, farmland: a farmstead on the valley
## floor south of it (its lane off the main road), fields on the floor
## and up both slopes, a high-voltage line crossing the valley in the
## north, wooden poles bringing power up the road to the farm, boulders
## on the slopes and round the pond. North of the village the main road
## becomes a little town street - rows of town houses with shops, a
## cross street - and beyond it, under the pylons, an industrial estate.

const LAND := Rect2(-600, -600, 1200, 1200)
const GREEN := Vector3(170, 0, 62)
const FARM := Vector2(60, 230)
## The industrial estate north of the town, on the valley floor.
const WORKS := Vector2(65, -470)
## The fields: corners (x, z) round each, the crop, and which edges
## (corner i to i + 1) have a hedgerow.
const FIELDS: Array = [
	["wheat", [Vector2(165, 240), Vector2(300, 235), Vector2(305, 350), Vector2(170, 355)], [3]],
	["maize", [Vector2(175, -330), Vector2(300, -320), Vector2(300, -210), Vector2(170, -200)], [3]],
	["rapeseed", [Vector2(-240, 90), Vector2(-230, 255), Vector2(-80, 240), Vector2(-90, 85)], [0]],
	["ploughed", [Vector2(35, 285), Vector2(35, 380), Vector2(110, 375), Vector2(105, 280)], []],
	["stubble", [Vector2(-210, -160), Vector2(-70, -170), Vector2(-65, -55), Vector2(-205, -50)], [0, 3]],
	["meadow", [Vector2(-245, 275), Vector2(-240, 370), Vector2(-110, 365), Vector2(-105, 270)], []],
]
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-42, -58, 0), "fog_density": 0.0012, "clouds": 0.5,
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-320, -560, 640, 900)}

func border() -> Array:
	return [500.0, 560.0, 90.0, 120.0] # out to the industrial estate in the north

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func preview_views() -> Array:
	return _views

func build() -> void:
	var t0: int = Time.get_ticks_msec()
	# --- the land ---
	land = TerrainCreator.make(21, "gentle")
	land.set_extent(LAND)
	land.flat_circle(Vector2(110, 10), 130.0, 0.0, 90.0) # east-bank village terrace (the datum)
	land.flat_circle(Vector2(-150, 25), 75.0, 0.0, 60.0) # west-bank houses
	land.valley(Vector2(-60, -1500), Vector2(40, 1500), 340.0, 30.0)
	land.hill(Vector2(430, -120), 230.0, 26.0)
	land.hill(Vector2(-440, 230), 240.0, 22.0)
	land.hollow(Vector2(-250, -230), 80.0, 5.0)
	land.keep_clear(Vector2(GREEN.x, GREEN.z), 30.0, true)
	land.keep_clear(Vector2(80, 20), 210.0)
	var farm: Dictionary = FarmCreator.plan(land, FARM, Vector2(64, 48), 1.0)
	var avoid: Array = []
	for fd: Array in FIELDS:
		land.keep_clear_poly(FieldCreator.poly(fd[1]))
		avoid.append(FieldCreator.poly(fd[1]))
	# --- water and roads ---
	var river := RiverCreator.plan(land, [Vector2(-70, -1500), Vector2(-35, -400), Vector2(-20, -100), Vector2(-30, 130), Vector2(0, 450), Vector2(60, 1500)], 12.0, {"seed": 5, "meander": 22.0})
	var main := RoadCreator.plan(land, Vector3(160, 0, 1700), -90.0, [Vector2(140, 600), Vector2(120, 200), Vector2(112, 0), Vector2(125, -200), Vector2(165, -600), Vector2(210, -1700)], 6.5, {"radius": 160.0})
	var bridge_st := RoadCreator.branch(land, main, Vector2(112, 25), -1.0, [Vector2(0, 28), Vector2(-120, 22), Vector2(-195, 10)], 6.0, {"end": "turning", "radius": 70.0, "lead": 30.0, "bridge": "arch"})
	var lane_e := RoadCreator.branch(land, main, Vector2(118, -90), 1.0, [Vector2(220, -92), Vector2(285, -70)], 5.0, {"end": "turning", "radius": 55.0, "lead": 30.0})
	var farm_lane := RoadCreator.branch(land, main, Vector2(122, 230), -1.0, [Vector2(86, 230)], 4.5, {"end": "turning", "radius": 40.0, "lead": 10.0})
	var cross_st := RoadCreator.branch(land, main, Vector2(130, -275), -1.0, [Vector2(40, -280)], 6.0, {"end": "turning", "radius": 40.0, "lead": 20.0})
	var works_rd := RoadCreator.branch(land, main, Vector2(152, -470), -1.0, [Vector2(100, -470)], 6.0, {"end": "turning", "radius": 40.0, "lead": 15.0})
	var works: Dictionary = IndustryCreator.plan(land, WORKS, Vector2(100, 130))
	# --- the town: rows of houses behind pavements, gaps at the cross street ---
	var town_lots: Array = []
	var tz0: float = main.dist_at(Vector2(127, -168))
	var tzx: float = main.dist_at(Vector2(130, -275))
	var tz1: float = main.dist_at(Vector2(137, -385))
	town_lots.append_array(CityHouseCreator.plan_row(land, main, tz0, tzx - 11.0, -1.0, {"seed": 3}))
	town_lots.append_array(CityHouseCreator.plan_row(land, main, tzx + 11.0, tz1, -1.0, {"seed": 4}))
	town_lots.append_array(CityHouseCreator.plan_row(land, main, tz0, main.dist_at(Vector2(134, -335)), 1.0, {"seed": 5}))
	town_lots.append_array(CityHouseCreator.plan_row(land, cross_st, 6.0, 80.0, -1.0, {"seed": 6, "styles": {"altbau": 0.4, "fifties": 0.4, "modern": 0.2}}))
	town_lots.append_array(CityHouseCreator.plan_row(land, cross_st, 6.0, 80.0, 1.0, {"seed": 7}))
	# --- plots ---
	var plots: Array = []
	var m0: float = main.dist_at(Vector2(118, 110))
	var m1: float = main.dist_at(Vector2(118, -115))
	VillageKit.plots_along(land, main, m0, m1, 1.0, plots)   # east side of the main road
	VillageKit.plots_along(land, main, m0, m1, -1.0, plots)  # west side, toward the river
	var b0: float = bridge_st.dist_at(Vector2(-85, 26))
	VillageKit.plots_along(land, bridge_st, b0, b0 + 140.0, -1.0, plots)
	VillageKit.plots_along(land, bridge_st, b0, b0 + 140.0, 1.0, plots)
	VillageKit.plots_along(land, lane_e, 15.0, 70.0, -1.0, plots) # only where the lane is still level
	land.pond(Vector2(-250, -230), 26.0)
	var t1: int = Time.get_ticks_msec()
	land.build(self, geo, LAND)
	var t2: int = Time.get_ticks_msec()
	# --- drawing ---
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 23
	var roads := Roads.new(geo, lrng)
	var rinfo: Dictionary = river.draw(geo, LAND, lrng)
	var road_views: Array = []
	for rd: RoadCreator in [main, bridge_st, lane_e, farm_lane, cross_st, works_rd]:
		road_views.append_array(rd.draw(geo, roads, lrng).views)
	# Pavements along the town's streets (broken at the cross street).
	var main_r: Route = Route.from_pts(main.line.pts)
	var cross_r: Route = Route.from_pts(cross_st.line.pts)
	for seg: Array in [[tz0 - 2.0, tzx - 9.0, -1.0], [tzx + 9.0, tz1 + 2.0, -1.0], [tz0 - 2.0, main.dist_at(Vector2(134, -335)) + 2.0, 1.0]]:
		roads.pavement(Route.from_pts(main_r.slice(seg[0], seg[1])), seg[2], main.line.half, CityHouseCreator.WALK)
	for sd in [-1.0, 1.0]:
		roads.pavement(Route.from_pts(cross_r.slice(2.0, 82.0)), sd, cross_st.line.half, CityHouseCreator.WALK)
	VillageKit.lamps(roads, main, tz0, tz1, 28.0)
	VillageKit.lamps(roads, cross_st, 8.0, 80.0, 26.0)
	VillageKit.lamps(roads, main, m0, m1)
	VillageKit.lamps(roads, bridge_st, 10.0, bridge_st.line.length() - 10.0, 30.0)
	VillageKit.lamps(roads, lane_e, 15.0, 110.0, 30.0)
	var trees: Array = VillageKit.green(geo, GREEN)
	var t3: int = Time.get_ticks_msec()
	var vinfo: Dictionary = VillageKit.build_plots(geo, plots, 31)
	var t4: int = Time.get_ticks_msec()
	trees.append_array(vinfo.trees)
	# --- street furniture ---
	var street_views: Array = []
	for br: RoadCreator in [bridge_st, lane_e, farm_lane]:
		StreetKit.give_way(geo, br)
	street_views.append_array(StreetKit.town_sign(geo, main, main.dist_at(Vector2(121, 150)), 1.0, "Talbach", "Gemeinde Testtal"))
	StreetKit.town_sign(geo, main, main.dist_at(Vector2(140, -400)), -1.0, "Talbach", "Gemeinde Testtal")
	StreetKit.give_way(geo, cross_st)
	StreetKit.give_way(geo, works_rd)
	# --- the town's houses ---
	var tt0: int = Time.get_ticks_msec()
	var town_views: Array = CityHouseCreator.build_row(geo, town_lots, 41).views
	var tt1: int = Time.get_ticks_msec()
	# --- the industrial estate ---
	var works_views: Array = _works(works, lrng)
	if OS.has_environment("SH_PERF"):
		print("TESTVALLEY town %d ms (%d houses), industrial estate %d ms" % [tt1 - tt0, town_lots.size(), Time.get_ticks_msec() - tt1])
	street_views.append_array(StreetKit.bus_stop(geo, main, main.dist_at(Vector2(122, -138)), -1.0, "Talbach Nord"))
	var gy: float = land.ground(GREEN.x - 14.0, GREEN.z - 10.0)
	StreetKit.notice_board(geo, Vector3(GREEN.x - 14.0, gy, GREEN.z - 10.0), -PI * 0.5)
	StreetKit.post_box(geo, Vector3(GREEN.x - 15.0, land.ground(GREEN.x - 15.0, GREEN.z - 5.0), GREEN.z - 5.0), -PI * 0.5)
	StreetKit.bin(geo, Vector3(GREEN.x - 11.0, land.ground(GREEN.x - 11.0, GREEN.z + 9.0), GREEN.z + 9.0), -PI * 0.5)
	street_views.append(["give_way", farm_lane.line.pts[3] + Vector3(0, 1.8, 0), farm_lane.line.pts[0] + Vector3(0, 1.5, 0)])
	# --- farmland ---
	var fv: Dictionary = FarmCreator.build(geo, land, farm, 77)
	trees.append_array(fv.trees)
	var frng := RandomNumberGenerator.new()
	frng.seed = 51
	var farm_views: Array = fv.views
	for fd: Array in FIELDS:
		var fi: Dictionary = FieldCreator.build(geo, land, fd[1], fd[0], frng, {"hedges": fd[2]})
		trees.append_array(fi.trees)
		farm_views.append_array(fi.views)
	# A tractor out on the stubble, loading the bales.
	var tq := Vector2(-140, -105)
	FarmCreator.tractor(geo, Vector3(tq.x, land.ground(tq.x, tq.y) + 0.02, tq.y), 0.4, "fm_green", true, frng)
	farm_views.append(["tractor_field", Vector3(tq.x - 9, land.ground(tq.x, tq.y) + 3.5, tq.y + 9), Vector3(tq.x, land.ground(tq.x, tq.y) + 1.0, tq.y)])
	# --- power lines: the high-voltage line across the valley, and the
	# village supply up the road to the farm ---
	var barn: Vector3 = fv.barn
	var line_views: Array = []
	line_views.append_array(PowerLineCreator.build(geo, land, [Vector2(-590, -500), Vector2(-300, -480), Vector2(0, -470), Vector2(300, -470), Vector2(590, -450)], "pylons").views)
	line_views.append_array(PowerLineCreator.build(geo, land, [Vector2(118, 590), Vector2(114, 330), Vector2(112, 262), Vector2(64, 262)], "poles",
		{"end_into": barn + Vector3(7.0, 5.0, FarmCreator.BARN_B * 0.5 + 0.2)}).views)
	var t5: int = Time.get_ticks_msec()
	# --- rocks, before the trees (they keep off them) ---
	var rk := RandomNumberGenerator.new()
	rk.seed = 61
	var rinfo2: Dictionary = RockCreator.scatter(self, geo, land, rk, [
		[Vector2(-250, -230), 75.0, 25, 0.5, 2.6], # round the pond's hollow
		[Vector2(330, -30), 70.0, 20, 0.6, 3.2], # under the north-east wood
		[Vector2(-330, 50), 90.0, 30, 0.5, 3.0], # the west slope
		[Vector2(380, 180), 80.0, 22, 0.6, 3.5], # the east slope
		[Vector2(-420, -330), 80.0, 20, 0.8, 4.0], # in the north-west wood
		[Vector2(-25, -250), 70.0, 16, 0.3, 1.0], # stones by the river
		[Vector2(230, 40), 8.0, 1, 4.5, 5.0], # a lone erratic on the slope
	], avoid)
	var t6: int = Time.get_ticks_msec()
	if OS.has_environment("SH_PERF"):
		print("TESTVALLEY street, farm, fields, power lines %d ms; rocks %d ms (%d)" % [t5 - t4, t6 - t5, rinfo2.placed])
	var woods: Array = [[Vector2(430, -130), 210.0], [Vector2(-430, 240), 220.0], [Vector2(-330, -460), 170.0], [Vector2(360, 420), 160.0], [Vector2(-470, -60), 110.0]]
	trees.append_array(land.woods(lrng, LAND.grow(-60.0), 2400, 100.0, woods))
	var info: Dictionary = TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("TESTVALLEY plan %d ms, land %d ms, river+roads %d ms, houses %d ms (%d plots, %d open), trees %d ms (%d)" % [t1 - t0, t2 - t1, t3 - t2, t4 - t3, plots.size(), vinfo.open, Time.get_ticks_msec() - t6, info.kept])
	if OS.has_environment("SH_PLOTCHECK"):
		# Dev check: ground under each plot vs its level; pond water vs the ground at its edge.
		# Every metre inside each plot (its fence line included).
		var worst: float = 0.0
		for pl: Dictionary in plots:
			var fr: Transform3D = pl.frame
			var pw: float = 0.0
			var at := Vector2.ZERO
			for u in range(int(pl.width) + 1):
				for v in range(int(pl.depth) + 1):
					var q: Vector3 = fr * Vector3(u - pl.width * 0.5, 0, -v)
					var dev: float = absf(land.ground(q.x, q.z) - fr.origin.y)
					if dev > pw:
						pw = dev
						at = Vector2(u - pl.width * 0.5, -v)
			if pw > 0.05:
				print("  plot at %s: ground off its level by %.2f m at x %.0f z %.0f (plot frame)" % [fr.origin, pw, at.x, at.y])
			worst = maxf(worst, pw)
		print("PLOTCHECK %d plots: worst ground vs plot level %.2f m" % [plots.size(), worst])
		for pd: Array in land._ponds:
			var low: float = INF
			for k in range(64):
				var a: float = TAU * k / 64.0
				var q: Vector2 = (pd[0] as Vector2) + Vector2(cos(a), sin(a)) * pd[1] * 1.08
				low = minf(low, land.ground(q.x, q.y))
			print("PONDCHECK water %.2f, lowest ground at the water's edge %.2f" % [pd[2], low])
	# --- preview views ---
	var bp: Vector3 = bridge_st.line.pts[bridge_st.line.pts.size() / 3]
	_views.append(["valley", Vector3(330, 90, 260), Vector3(0, 0, -20)])
	_views.append(["valley_top", Vector3(0, 340, 1), Vector3(0, 0, 0)])
	_views.append(["from_south", Vector3(60, 25, 330), Vector3(20, 0, 0)])
	_views.append(["green", GREEN + Vector3(24, 2.5, 18), GREEN])
	_views.append(["bridge_street", Vector3(100, 3.0, 30), Vector3(-60, 2.0, 25)])
	var pond_c := Vector3(-250, land.ground(-250, -230), -230)
	_views.append(["pond", pond_c + Vector3(60, 7, 30), pond_c])
	_views.append_array(vinfo.views)
	for k in [1, 4, 7, 10, 14]:
		if k < plots.size():
			var fr: Transform3D = plots[k].frame
			_views.append(["plot%d" % k, fr * Vector3(-16, 9, 8), fr * Vector3(0, 0, -15)])
	# Low along the street (light under a fence or a house shows from
	# here) and close to the flower beds by the front doors.
	for k in [1, 7, 14, 18]:
		if k < plots.size():
			var fr: Transform3D = plots[k].frame
			_views.append(["low%d" % k, fr * Vector3(-15, 1.1, 5), fr * Vector3(2, 0.6, -12)])
			_views.append(["beds%d" % k, fr * Vector3(-3.5, 1.5, -2.0), fr * Vector3(1.0, 0.2, -6.8)])
	if plots.size() > 1:
		var fc: Transform3D = plots[1].frame
		_views.append(["garden_close", fc * Vector3(-6, 1.9, 6), fc * Vector3(2, 0.4, -8)])
	# The river from far away (it has to read as a river at a distance too).
	_views.append(["river_far", Vector3(380, 70, -520), Vector3(-30, 0, 200)])
	_views.append(["town", Vector3(215, 55, -190), Vector3(90, 0, -290)])
	_views.append_array(town_views)
	_views.append_array(works_views)
	_views.append_array(farm_views)
	_views.append_array(line_views)
	_views.append_array(street_views)
	_views.append_array(rinfo2.views)
	_views.append_array(rinfo.views)
	_views.append_array(road_views)
	var shown: Dictionary = {}
	for e: Array in info.extras:
		if not shown.has(e[0]):
			shown[e[0]] = true
			_views.append(["tree_" + e[0], e[2], e[1]])
	if OS.has_environment("SH_ROADCHECK"):
		# Dev check: low views along every road (terrain vs road surface).
		_views.clear()
		for rd: RoadCreator in [main, bridge_st, lane_e, farm_lane, cross_st, works_rd]:
			var rp: Array[Vector3] = rd.line.pts
			for i in range(0, rp.size() - 6, 10):
				if not LAND.grow(100.0).has_point(Vector2(rp[i].x, rp[i].z)):
					continue
				var a: Vector3 = rp[i]
				var b: Vector3 = rp[i + 5]
				var sd: Vector3 = Vector3(-(b - a).z, 0, (b - a).x).normalized() * 5.0
				_views.append(["road%02d_%03d" % [_views.size(), i], a + sd + Vector3(0, 1.6, 0), b + Vector3(0, 0.3, 0)])

## The industrial estate, laid out in its own frame (x east, z south,
## origin at the site's middle; the access road comes in from the east).
func _works(site: Dictionary, r: RandomNumberGenerator) -> Array:
	var o := Vector3(site.c.x, site.y, site.c.y)
	var v: Array = []
	IndustryCreator.yard(geo, site)
	# The production hall along the west side, its open door to the north.
	var hx := Transform3D(Basis(), o + Vector3(-20, 0, -20))
	v.append_array(IndustryCreator.hall(geo, hx, 56.0, 30.0, 10.0, r, {"docks": 3}))
	# Lorries backed up to the docks.
	var paints: Array = ["veh_paint1", "veh_paint6", "veh_paint9"]
	var k: int = 0
	for d: Vector3 in IndustryCreator.docks(hx, 56.0, 30.0, 3):
		if k != 1:
			Vehicles.semi(geo, d + Vector3(8.4, 0.02, 0), -PI * 0.5, paints[k % paints.size()], "veh_trailer")
		k += 1
	# Boiler house and its chimney; the pipe rack to the tank farm.
	geo.tint = Color.WHITE
	geo.box_on(Transform3D(Basis(), o + Vector3(-38, 3.5, 22)), Vector3(10, 7, 8), "in_brick", o.y)
	geo.tint = Color(0.3, 0.3, 0.32)
	geo.box(o + Vector3(-38, 7.1, 22), Vector3(10.4, 0.2, 8.4), "in_paint")
	geo.tint = Color.WHITE
	IndustryCreator.chimney(geo, o + Vector3(-44, 0, 32), 45.0)
	IndustryCreator.tanks(geo, o + Vector3(28, 0, -40), 2, 2, r)
	IndustryCreator.pipe_rack(geo, land, [Vector2(o.x - 33, o.z + 24), Vector2(o.x + 46, o.z + 24), Vector2(o.x + 46, o.z - 27)], 5.5, o.y)
	# Grain silos with their conveyor up from the hopper.
	v.append_array(IndustryCreator.silos(geo, o + Vector3(12, 0, 45), 3, r, o + Vector3(-28, 0, 45)))
	# Containers waiting by the gate.
	var cmats: Array = ["veh_paint1", "veh_paint2", "veh_paint6", "veh_trailer"]
	for i in range(4):
		for lvl in range(1 + i % 2):
			geo.box(o + Vector3(24 + (i % 2) * 7.0, 1.3 + lvl * 2.6, 14 + (i / 2) * 3.0), Vector3(6.06, 2.59, 2.44), cmats[(i + lvl) % cmats.size()])
	v.append_array(IndustryCreator.fence(geo, site, "e"))
	v.append(["works", o + Vector3(90, 45, 80), o])
	return v

