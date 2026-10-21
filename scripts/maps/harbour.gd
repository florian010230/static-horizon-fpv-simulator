extends BuiltMap

## Harbour & Central Station (High performance) - a compact port city
## where everything is connected the way it is in a real one. North =
## -z, the sea is south (+z).
##
##   Container terminal (quay, 4 ship-to-shore cranes, a 300 m ship,
##   stacking blocks with RTG cranes and straddle carriers) -> its rail
##   loading tracks under two rail gantry cranes -> a branch that curves
##   (R 250 m) up to the double-track main line -> the main line runs
##   west-east through the whole map and out into the haze both ways ->
##   Central Station: a through station, four platform tracks reached
##   through proper 1:9 turnouts in each throat, a 280 m glass train
##   shed, the station building with clock tower on the city side.
##   Freight sidings with a loco shed east of the station.
##   Roads: the waterfront road (out of the map west, ends at the
##   terminal gate east), two road bridges over the railway into the
##   city, and the city's street grid whose edge streets run on out of
##   the map. Bulk berth with grain silos by the spawn, the old harbour
##   basin with the marina and brick warehouses, an oil tank farm and a
##   jetty east, a breakwater with a lighthouse, a wind farm at sea.
## Real sizes: ISO containers 12.2 x 2.44 x 2.59 m, 4.5 m track
## centres, 0.76 m platforms, 1:9 turnouts (R 190 m), ~26 m coaches.

const WATER_Y: float = -3.0
const CONT := Vector3(12.2, 2.59, 2.44)
const BASIN := Rect2(-560, -130, 300, 130)
const MAIN_Z: float = -420.0 ## centre line of the double main line
const WF_Z: float = -215.0 ## waterfront road
const XS: Array = [-650.0, -530.0, -410.0, -290.0, -130.0, -30.0, 90.0, 210.0]
const XW: Array = [12.0, 12.0, 12.0, 30.0, 16.0, 12.0, 12.0, 12.0]
const ZS: Array = [-940.0, -840.0, -740.0, -640.0, -540.0] ## north to south; -540 = the avenue
const ZW: Array = [12.0, 16.0, 12.0, 12.0, 20.0]
const AVENUE_S: float = -530.0 ## south edge of the avenue's carriageway

var rng := RandomNumberGenerator.new()
var rails: Rails
var roads: Roads
var city: City
var _colors: Array[String] = []
var _tc_trees: Array = [] ## TreeCreator entries (the lost drone's tree)

## Garden gnome spots (Collectibles): 0 on a pallet in the open warehouse
## on the basin, 1 on the machinery house of the first ship-to-shore
## crane, 2 under the fish market's roof on a crate stack.
const GNOMES: Array[Transform3D] = [
	Transform3D(Basis(Vector3.UP, 0.4), Vector3(-386.0, 10.3, -186.0)),
	Transform3D(Basis(Vector3.UP, 3.1), Vector3(62.0, 48.0, -40.0)),
	Transform3D(Basis(Vector3.UP, 1.0), Vector3(-612.0, 1.4, -84.0)),
]

func after_build() -> void:
	for i in range(GNOMES.size()):
		Collectibles.gnome(self, "harbour", i, GNOMES[i])

func map_env() -> Dictionary:
	# Sunset over the port: the sun low in the west, long shadows down
	# the streets and across the container stacks, an orange haze.
	return {"sun_rot": Vector3(-9, -95, 0), "sun_color": Color(1.0, 0.62, 0.36), "sun_energy": 1.75, "fog_begin": 380.0,
		"sky_top": Color(0.2, 0.3, 0.52), "sky_horizon": Color(0.98, 0.68, 0.46),
		"ambient": Color(0.74, 0.64, 0.66), "ambient_energy": 0.72,
		"ground_horizon": Color(0.3, 0.45, 0.55), "ground_bottom": Color(0.12, 0.25, 0.32),
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-760, -1000, 1400, 1260)}

func border() -> Array:
	return [760.0, 850.0, 310.0, 370.0, Vector2(-100, -380)]

## Loaded from the map cache after the first build (MapCache): nothing
## the script keeps is needed after build().
func cacheable() -> bool:
	return true

func preview_views() -> Array:
	return [
		["overview", Vector3(-330, 140, 180), Vector3(-120, 0, -330)],
		["cranes", Vector3(70, 22, 40), Vector3(200, 30, -10)],
		["stacks", Vector3(60, 5, -117), Vector3(260, 4, -117)],
		["throat", Vector3(-640, 14, -412), Vector3(-450, 3, -422)],
		["station_shed", Vector3(-180, 7, -420), Vector3(-430, 7, -420)],
		["station_square", Vector3(-240, 30, -600), Vector3(-300, 8, -470)],
		["boulevard", Vector3(-290, 25, -560), Vector3(-290, 8, -900)],
		["downtown", Vector3(-160, 90, -520), Vector3(-350, 40, -660)],
		["bridge", Vector3(-150, 4, -330), Vector3(-150, 7, -440)],
		["branch", Vector3(420, 40, -230), Vector3(620, 0, -390)],
		["sidings", Vector3(80, 18, -480), Vector3(420, 0, -440)],
		["basin", Vector3(-300, 18, 12), Vector3(-440, 0, -110)],
		["silos", Vector3(-205, 5, -40), Vector3(-110, 18, -90)],
		["tanks", Vector3(400, 40, -120), Vector3(570, 8, -150)],
		["horizon", Vector3(-100, 90, -820), Vector3(-100, 0, -2200)],
		["town_houses", Vector3(-250, 30, -700), Vector3(-200, 10, -790)],
		["town_street", Vector3(-290, 6, -640), Vector3(-290, 8, -800)],
		["speicher", Vector3(-405, 12, -125), Vector3(-405, 9, -170)],
		["speicher_in", Vector3(-405, 6.4, -170), Vector3(-445, 5.6, -182)],
		["fish_market", Vector3(-560, 8, -110), Vector3(-600, 4, -60)],
		["transit_shed", Vector3(-150, 4, -185), Vector3(-215, 3, -185)],
		["workshops", Vector3(30, 15, -440), Vector3(-15, 5, -500)],
		["depot", Vector3(-515, 15, -290), Vector3(-515, 4, -338)],
		["gnome_crane", Vector3(62, 51, -30), Vector3(62, 48, -40)],
	]

func build() -> void:
	rng.seed = 2024
	geo.ao_height = 2.5
	geo.add_material("ground", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 8.0, 0, 0.45))
	geo.add_material("paving", Geo.ground_mat(MapTextures.get_tex("old_concrete"), Color(0.95, 0.95, 0.92), 8.0, 1, 0.35))
	geo.add_material("gravel", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color.WHITE, 4.0, 1, 0.35))
	geo.add_material("quay", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 5.0))
	geo.add_material("water", Geo.water_mat(Color(0.1, 0.28, 0.36)))
	geo.add_material("crane", Geo.flat_mat(Color(0.2, 0.42, 0.72)))
	geo.add_material("crane_red", Geo.flat_mat(Color(0.75, 0.2, 0.15)))
	geo.add_material("hull", Geo.flat_mat(Color(0.12, 0.14, 0.18)))
	geo.add_material("hull_red", Geo.flat_mat(Color(0.55, 0.14, 0.12)))
	geo.add_material("white", Geo.flat_mat(Color(0.92, 0.92, 0.9)))
	geo.add_material("glass", Geo.flat_mat(Color(0.1, 0.13, 0.16)))
	geo.add_material("steel", Geo.flat_mat(Color(0.35, 0.33, 0.3)))
	geo.add_material("warehouse", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.62, 0.66, 0.7), 4.0))
	geo.add_material("rock", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.8, 0.78, 0.74), 4.0))
	geo.add_material("yellow", Geo.flat_mat(Color(0.95, 0.72, 0.1)))
	geo.add_material("line", Geo.ground_flat(Color(0.95, 0.85, 0.3), 3))
	geo.add_material("sandstone", Geo.tex_mat(MapTextures.get_tex("facade_b"), Color(1.12, 0.98, 0.78), 7.0))
	geo.add_material("brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.1, 0.95, 0.9), 3.0))
	geo.add_material("tank_white", Geo.flat_mat(Color(0.86, 0.86, 0.84)))
	geo.add_material("platform", Geo.tex_mat(MapTextures.get_tex("paving_slabs"), Color(0.9, 0.9, 0.9), 3.0))
	geo.add_material("platform_edge", Geo.flat_mat(Color(0.92, 0.92, 0.9)))
	geo.add_material("groove", Geo.ground_flat(Color(0.14, 0.14, 0.15), 4)) # (over the road's lines where rails cross)
	var shed_glass := Geo.flat_mat(Color(0.75, 0.85, 0.9, 0.35))
	shed_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shed_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	geo.add_material("shed_glass", shed_glass)
	var ctex: Texture2D = MapTextures.get_tex("corrugated_plain")
	for c in [["c_red", Color(0.72, 0.16, 0.12)], ["c_blue", Color(0.12, 0.3, 0.62)], ["c_green", Color(0.18, 0.45, 0.25)],
		["c_orange", Color(0.9, 0.45, 0.12)], ["c_grey", Color(0.55, 0.56, 0.58)], ["c_white", Color(0.92, 0.92, 0.9)], ["c_brown", Color(0.45, 0.25, 0.16)]]:
		geo.add_material(c[0], Geo.tex_mat(ctex, c[1], 2.44))
		_colors.append(c[0])
	Vehicles.ensure_materials(geo)
	rails = Rails.new(geo)
	roads = Roads.new(geo, rng, fleet)
	city = City.new(geo, rng, fleet)
	# Real town houses (CityHouseCreator) in the blocks around the spawn; the
	# cheap boxes stay further out. ~22 ms a house, so a capped count.
	city.house_centre = Vector2(-290, -790)
	city.house_radius = 110.0
	city.house_cap = 40

	_land_and_water()
	_railway()
	_station()
	_terminal()
	_open_container()
	_bulk_berth()
	_basin()
	_tank_farm()
	_road_network()
	_city()
	_south_district()
	_sidings_district()
	_far_filler()
	_east_logistics()
	_wind_farm()
	_breakwater()
	for p in [Vector3(120, 0, 90), Vector3(-150, 0, 70)]:
		_tug(p)
	# Port clutter in the terminal wherever there's room: cabins, reels,
	# pallets, barriers, skips.
	YardProps.scatter(geo, Rect2(-40, -300, 510, 300), 0.0, 60, rng)
	Forest.plant(self, city.trees, self)
	TreeCreator.plant(self, geo, _tc_trees)

# --- land ------------------------------------------------------------------------

func _land_and_water() -> void:
	geo.slab(Rect2(-3200, BASIN.position.y, 6400, 3200), WATER_Y, 0.3, "water", false)
	# Ground everywhere north of the shore, the basin left open.
	geo.slab(Rect2(-3200, -3200, 6400, 3200 + BASIN.position.y), 0.0, 4.0, "ground")
	geo.slab(Rect2(-3200, BASIN.position.y, 3200 + BASIN.position.x, -BASIN.position.y), 0.0, 4.0, "ground")
	geo.slab(Rect2(BASIN.end.x, BASIN.position.y, 3200 - BASIN.end.x, -BASIN.position.y), 0.0, 4.0, "ground")
	# Quay walls: the shore and the basin.
	for seg in [[Vector3(-3200, 0, 0), Vector3(BASIN.position.x, 0, 0)], [Vector3(BASIN.end.x, 0, 0), Vector3(3200, 0, 0)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		geo.box((a + b) * 0.5 + Vector3(0, -1.8, 0.3), Vector3(b.x - a.x, 3.8, 0.6), "quay", 0.0, true, false)
	geo.box(Vector3(BASIN.position.x - 0.3, -1.8, BASIN.get_center().y), Vector3(0.6, 3.8, BASIN.size.y), "quay", 0.0, true, false)
	geo.box(Vector3(BASIN.end.x + 0.3, -1.8, BASIN.get_center().y), Vector3(0.6, 3.8, BASIN.size.y), "quay", 0.0, true, false)
	geo.box(Vector3(BASIN.get_center().x, -1.8, BASIN.position.y - 0.3), Vector3(BASIN.size.x + 1.2, 3.8, 0.6), "quay", 0.0, true, false)
	# Paved port areas.
	geo.slab(Rect2(-40, -300, 510, 300), 0.0, 1.0, "paving")                # container terminal
	geo.slab(Rect2(BASIN.end.x, -205, -40 - BASIN.end.x, 205), 0.0, 1.0, "paving") # bulk berth
	geo.slab(Rect2(-640, -205, 380, 75), 0.0, 1.0, "paving")                # warehouse quay
	geo.slab(Rect2(-640, -130, 80, 130), 0.0, 1.0, "paving")                # west bank
	geo.slab(Rect2(470, -250, 200, 250), 0.0, 1.0, "gravel")                # tank farm

# --- railway ---------------------------------------------------------------------

var main_n: Route
var main_s: Route

func _railway() -> void:
	# Centre line of the double main line: in from the west on a gentle
	# curve, straight through the port city, curving away north-east.
	var centre := Route.from(Vector3(-3000, 0, MAIN_Z - 2000.0 * (1.0 - cos(deg_to_rad(10.0)))), 10.0)
	centre.arc(2000.0, -10.0, 12.0)
	centre.straight(900.0 - centre.end().x, 12.0)
	centre.arc(2000.0, -12.0, 12.0)
	centre.straight(900.0, 12.0)
	main_n = Route.from_pts(centre.offset(-2.25))
	main_s = Route.from_pts(centre.offset(2.25))
	rails.field(centre, 8.3, 1)
	rails.track(main_n, 0, false)
	rails.track(main_s, 0, false)
	rails.catenary(main_n, -1.0)
	rails.catenary(main_s, 1.0)
	# Crossovers between the main tracks, west and east of the station.
	rails.crossover(main_s, main_s.dist_at_x(-800.0), -1.0)
	rails.crossover(main_n, main_n.dist_at_x(10.0), 1.0)
	for x in [-900.0, 150.0]:
		rails.signal_at(main_n, main_n.dist_at_x(x), true)
		rails.signal_at(main_s.reversed(), main_s.reversed().dist_at_x(x), false)
	_branch_to_terminal()
	_freight_sidings()
	# Trains on the open line: a container train heading east beyond the
	# station, a regional train coming in from the west.
	var kinds: Array = ["flat_empty"]
	for i in range(14):
		kinds.append("flat")
	kinds.append("loco")
	rails.train(main_s, main_s.dist_at_x(120.0), kinds, rng, _colors)
	rails.train(main_n.reversed(), main_n.reversed().dist_at_x(-760.0), ["loco", "coach", "coach", "coach", "coach"], rng)

## Station tracks: the outer platform tracks leave the main tracks
## through a turnout in each throat, swing out 12.5 m and run parallel
## along the platforms (built from both ends, they meet in the middle).
var outer_n: Route
var outer_s: Route
const THROAT_W: float = -564.0
const THROAT_E: float = -36.0
const PLAT_X0: float = -428.0
const PLAT_X1: float = -172.0

func _station_track(main: Route, side: float) -> Route:
	var halves: Array = []
	var a: float = deg_to_rad(Rails.TURNOUT_ANGLE)
	var run: float = (12.5 - 2.0 * Rails.TURNOUT_R * (1.0 - cos(a))) / sin(a)
	var mid: float = (THROAT_W + THROAT_E) * 0.5
	for end in [0, 1]:
		var r: Route = main if end == 0 else main.reversed()
		var x: float = THROAT_W if end == 0 else THROAT_E
		var s: float = side if end == 0 else -side
		var t: Route = rails.turnout(r, r.dist_at_x(x), s)
		t.straight(run, 4.0)
		t.arc(Rails.TURNOUT_R, -Rails.TURNOUT_ANGLE * s, 3.0)
		t.straight(absf(mid - t.end().x), 12.0)
		halves.append(t)
	var back: Array[Vector3] = halves[1].pts.duplicate()
	back.reverse()
	var full: Array[Vector3] = halves[0].pts.duplicate()
	full.append_array(back.slice(1))
	var route := Route.from_pts(full)
	rails.track(route, 1)
	return route

# --- the station -------------------------------------------------------------------

func _station() -> void:
	outer_n = _station_track(main_n, -1.0)
	outer_s = _station_track(main_s, 1.0)
	var zn: float = MAIN_Z - 2.25 - 12.5
	var zs: float = MAIN_Z + 2.25 + 12.5
	# Island platforms between each main track and its outer track.
	for pz in [(zn + MAIN_Z - 2.25) * 0.5, (zs + MAIN_Z + 2.25) * 0.5]:
		var c := Vector3((PLAT_X0 + PLAT_X1) * 0.5, 0.38, pz)
		geo.box(c, Vector3(PLAT_X1 - PLAT_X0, 0.76, 9.0), "platform")
		for s in [-1.0, 1.0]:
			geo.box(c + Vector3(0, 0.41, s * 4.1), Vector3(PLAT_X1 - PLAT_X0, 0.06, 0.35), "platform_edge", 0.0, false, false) # (proud of the paving: flush, it flickered)
		for k in range(12):
			var px: float = PLAT_X0 + 12.0 + k * 21.5
			geo.cylinder(Vector3(px, 0.76, pz), Vector3(px, 4.2, pz), 0.08, "steel", 6)
			geo.box(Vector3(px, 4.3, pz), Vector3(0.3, 0.12, 1.6), "rd_lamp", 0.0, false, false)
			if k % 3 == 1:
				geo.box(Vector3(px + 4.0, 3.2, pz), Vector3(2.4, 0.7, 0.15), "cty_dark") # departure board
				geo.box(Vector3(px + 4.0, 2.0, pz), Vector3(0.12, 2.4, 0.12), "steel")
			if k % 2 == 0:
				geo.box(Vector3(px + 9.0, 1.2, pz), Vector3(2.0, 0.08, 0.5), "boat_wood", 0.0, true, false)
				for lx in [-0.8, 0.8]: # its legs (the seat hung in the air)
					geo.box(Vector3(px + 9.0 + lx, 0.96, pz), Vector3(0.08, 0.4, 0.4), "steel", 0.0, false, false)
		# Stairs down to the passenger tunnel (a dark opening).
		geo.box(Vector3(-300, 0.77, pz), Vector3(10.0, 0.02, 2.8), "cty_dark", 0.0, false, false)
	# Trains at the platforms.
	var ice: Array = ["ice_tail"]
	for c in range(8):
		ice.append("ice")
	ice.append("ice_head")
	rails.train(main_n.reversed(), main_n.reversed().dist_at_x(PLAT_X1 - 2.0), ice, rng)
	rails.train(outer_s, outer_s.dist_at_x(PLAT_X0 + 30.0), ["coach", "coach", "coach", "coach", "coach", "coach", "loco"], rng)
	rails.train(outer_n.reversed(), outer_n.reversed().dist_at_x(PLAT_X1 - 20.0), ["coach", "coach", "coach", "loco"], rng)
	_train_shed()
	_station_building()

## Train shed: one barrel vault over all four platform tracks - steel
## arch ribs every 14 m, glass between, an opaque ridge lantern, open
## at both ends. Fly straight through it between the trains.
func _train_shed() -> void:
	var x0: float = -440.0
	var x1: float = -160.0
	var z0: float = MAIN_Z - 26.0
	var z1: float = MAIN_Z + 26.0
	var spring: float = 9.0
	var rise: float = 15.0
	var half: float = (z1 - z0) * 0.5
	var arc: Array = []
	for k in range(17):
		var a: float = PI * k / 16.0
		arc.append(Vector2(-cos(a) * half, spring + sin(a) * rise))
	var x: float = x0
	while x <= x1 + 0.1:
		var rib: Array[Vector3] = []
		for q: Vector2 in arc:
			rib.append(Vector3(x, q.y, MAIN_Z + q.x))
		geo.sweep(rib, [Vector2(0.25, 0.5), Vector2(0.25, -0.5), Vector2(-0.25, -0.5), Vector2(-0.25, 0.5)], "crane", true, true, true)
		for s in [-1.0, 1.0]:
			geo.box(Vector3(x, spring * 0.5, MAIN_Z + s * half), Vector3(0.9, spring, 0.9), "crane")
		x += 14.0
	for s in [-1.0, 1.0]:
		geo.box(Vector3((x0 + x1) * 0.5, spring + 0.3, MAIN_Z + s * half), Vector3(x1 - x0, 0.6, 1.0), "crane")
	var along := Route.from(Vector3(x0, 0, MAIN_Z), 0.0).straight(x1 - x0, 14.0)
	var glass: Array = []
	for k in range(3, 14):
		glass.append(arc[k] + Vector2(0, 0.05))
	var left: Array = []
	for k in range(2, 4):
		left.append(arc[k] + Vector2(0, 0.05))
	var right: Array = []
	for k in range(13, 15):
		right.append(arc[k] + Vector2(0, 0.05))
	# Glass mid section (both faces - transparent from inside and out),
	# solid roofing low down on each side.
	geo.sweep(along.pts, glass, "shed_glass", false, true, false)
	for side in [left, right]:
		geo.sweep(along.pts, side, "cty_metal", false, true, true)
		geo.sweep(along.pts, side, "cty_metal", false, false, false, 0.0, false, true)
	var lantern := Route.from(Vector3(x0 + 2.0, spring + rise + 0.2, MAIN_Z), 0.0).straight(x1 - x0 - 4.0, 14.0)
	geo.sweep(lantern.pts, [Vector2(-3.0, 0.0), Vector2(-2.5, 1.6), Vector2(2.5, 1.6), Vector2(3.0, 0.0)], "cty_metal", false, true, true)

## Station building on the city side (north): a long sandstone front
## with a high central hall, glazed arch, clock tower on the west end,
## the station square with taxi rank, bus bays and a tram stop.
func _station_building() -> void:
	var z: float = MAIN_Z - 43.0
	geo.box(Vector3(-290, 9, z), Vector3(190, 18, 26), "sandstone")
	geo.box(Vector3(-290, 18.4, z), Vector3(192, 0.8, 27), "cty_cornice", 0.0, false, false)
	geo.box(Vector3(-290, 14, z), Vector3(56, 28, 30), "sandstone")
	geo.box(Vector3(-290, 28.4, z), Vector3(58, 0.8, 31), "cty_cornice", 0.0, false, false)
	geo.frustum(Transform3D(Basis(), Vector3(-290, 31, z)), Vector3(56, 5, 30), 40, 18, 0.0, "cty_slate")
	# The glazed arch over the main entrance, facing the square.
	var arch: Array = []
	for k in range(13):
		var a: float = PI * k / 12.0
		arch.append(Vector2(-cos(a) * 18.0, 4.0 + sin(a) * 16.0))
	arch.append(Vector2(18.0, 0.8))
	arch.append(Vector2(-18.0, 0.8))
	geo.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-290, 0, z - 15.1)), arch, 0.3, "glass", false, false)
	for k in range(10):
		var wx: float = -375.0 + k * 9.0 if k < 5 else -250.0 + (k - 5) * 9.0
		for fy in [5.0, 12.0]:
			geo.box(Vector3(wx, fy, z - 13.02), Vector3(3.0, 4.0, 0.1), "glass", 0.0, false, false)
	var tower := Vector3(-400, 0, z)
	geo.box(tower + Vector3(0, 27, 0), Vector3(13, 54, 13), "sandstone")
	geo.box(tower + Vector3(0, 54.4, 0), Vector3(14.5, 0.8, 14.5), "cty_cornice", 0.0, false, false)
	for s in [-1.0, 1.0]:
		geo.cylinder(tower + Vector3(0, 44, s * 6.55), tower + Vector3(0, 44, s * 6.75), 4.0, "white", 24)
		geo.box(tower + Vector3(0, 45.2, s * 6.8), Vector3(0.3, 2.6, 0.06), "cty_dark", 0.0, false, false)
	geo.cone(tower + Vector3(0, 54.8, 0), tower + Vector3(0, 68, 0), 9.5, 0.3, "cty_slate", 4)
	# Station square.
	var sq := Rect2(-420, AVENUE_S + 4.0, 260, (z - 13.0) - (AVENUE_S + 4.0))
	geo.slab(sq, 0.05, 0.1, "cty_court", false)
	for k in range(6):
		fleet.car(Vector3(-200.0 - k * 6.0, 0.05, sq.end.y - 5.0), PI * 0.5, Vehicles.PAINTS[7], "taxi")
	for k in range(3):
		Vehicles.bus(geo, Vector3(-370.0 + k * 16.0, 0.05, sq.position.y + 8.0), -PI * 0.5, "veh_paint11" if k % 2 else "veh_paint7")
	for k in range(8):
		city.trees.append([Vector3(-410.0 + k * 30.0, 0.05, sq.get_center().y + 4.0), 1, 0.8])

# --- the terminal branch and the freight sidings ---------------------------------

var loading: Array = []

## From main S heading west at x 700: a turnout to the south, R 250 m
## round into the terminal, then a ladder of turnouts to four loading
## tracks that end at buffer stops.
func _branch_to_terminal() -> void:
	var back: Route = main_s.reversed()
	var br: Route = rails.turnout(back, back.dist_at_x(700.0), -1.0)
	br.arc(250.0, -(45.0 - Rails.TURNOUT_ANGLE), 4.0)
	br.straight(9.4, 4.0)
	br.arc(250.0, 45.0, 4.0)
	br.straight(br.end().x - 40.0, 12.0)
	rails.track(br, 1)
	loading.append(br)
	# Ladder: each new track leaves the previous one and swings 4.5 m
	# over (turnout, short straight, reverse curve) - north twice, south once.
	var prev: Route = br
	for k in range(2):
		var t: Route = rails.crossover(prev, prev.dist_at_x(330.0 - k * 80.0), 1.0, 4.5, 2, false)
		t.straight(t.end().x - 40.0, 12.0)
		rails.track(t, 2)
		loading.append(t)
		prev = t
	var south: Route = rails.crossover(br, br.dist_at_x(290.0), -1.0, 4.5, 2, false)
	south.straight(south.end().x - 40.0, 12.0)
	rails.track(south, 2)
	loading.append(south)
	for t: Route in loading:
		rails.buffer_stop(t)
	# Container trains being loaded.
	for i in [0, 1, 3]:
		var t: Route = loading[i]
		var kinds: Array = []
		for w in range(rng.randi_range(9, 13)):
			kinds.append("flat" if rng.randf() < 0.85 else "flat_empty")
		rails.train(t.reversed(), 8.0, kinds, rng, _colors)
	# Two rail-mounted gantry cranes spanning the loading tracks.
	for x in [120.0, 250.0]:
		for z in [-282.0, -252.0]:
			for dx in [-8.0, 8.0]:
				geo.box(Vector3(x + dx, 12, z), Vector3(1.2, 24, 1.2), "yellow")
			geo.box(Vector3(x, 1.0, z), Vector3(20, 2.0, 2.4), "yellow")
			geo.box(Vector3(x, 0.05, z), Vector3(360, 0.1, 0.3), "steel", 0.0, false, false)
		for dx in [-7.0, 7.0]:
			geo.box(Vector3(x + dx, 25, -267), Vector3(1.6, 2.4, 34), "yellow")
		geo.box(Vector3(x, 27, -265), Vector3(15, 2.6, 5), "crane_red")
		geo.beam(Vector3(x, 26, -265), Vector3(x, 7.5, -265), Vector2(0.12, 0.12), "steel", false)
		geo.box(Vector3(x, 7.2, -265), Vector3(12.4, 0.5, 2.6), "yellow")

## Freight sidings north of the main line east of the station: a ladder
## off main N into four sidings with buffer stops, wagons waiting, a
## diesel shunter, the loco shed over the two northern ones.
func _freight_sidings() -> void:
	var s1: Route = rails.turnout(main_n, main_n.dist_at_x(60.0), -1.0)
	var a: float = deg_to_rad(Rails.TURNOUT_ANGLE)
	s1.straight((9.0 - 2.0 * Rails.TURNOUT_R * (1.0 - cos(a))) / sin(a), 4.0)
	s1.arc(Rails.TURNOUT_R, Rails.TURNOUT_ANGLE, 3.0)
	s1.straight(640.0 - s1.end().x, 12.0)
	rails.track(s1, 1)
	var sid: Array = [s1]
	var prev: Route = s1
	for k in range(3):
		var t: Route = rails.crossover(prev, prev.dist_at_x(200.0 + k * 50.0), -1.0, 4.5, 2)
		t.straight(640.0 - t.end().x, 12.0)
		rails.track(t, 2)
		sid.append(t)
		prev = t
	for t: Route in sid:
		rails.buffer_stop(t)
	var mix: Array = ["tank", "box", "hopper", "box", "tank", "flat", "box"]
	for k in range(3):
		var kinds: Array = []
		for w in range(rng.randi_range(8, 16)):
			kinds.append(mix[rng.randi() % mix.size()])
		rails.train(sid[k], sid[k].dist_at_x(260.0 + k * 30.0), kinds, rng, _colors)
	rails.train(sid[3], sid[3].dist_at_x(540.0), ["shunter"], rng)
	rails.train(sid[2], sid[2].dist_at_x(560.0), ["loco"], rng)
	# Loco shed over the northern two sidings' ends.
	var zc: float = MAIN_Z - 2.25 - 9.0 - 6.75 - 4.5 * 0.5 + 2.25
	zc = (MAIN_Z - 2.25 - 9.0 - 9.0 + MAIN_Z - 2.25 - 9.0 - 13.5) * 0.5
	for s in [-1.0, 1.0]:
		geo.box(Vector3(585, 5.5, zc + s * 5.3), Vector3(90, 11, 0.4), "brick")
	geo.box(Vector3(632, 5.5, zc), Vector3(0.5, 11, 11.0), "brick")
	geo.frustum(Transform3D(Basis(), Vector3(585, 12.0, zc)), Vector3(92, 2.0, 12.0), 92, 2.0, 0.0, "cty_slate")

# --- container terminal --------------------------------------------------------------

func _terminal() -> void:
	for dz in [-3.0, -33.0]:
		geo.box(Vector3(215, 0.02, dz), Vector3(490, 0.04, 0.3), "steel", 0.0, false, false)
	for x in range(-30, 461, 15):
		geo.cylinder(Vector3(x, 0, -1.0), Vector3(x, 0.6, -1.0), 0.25, "steel", 8)
	for i in range(4):
		_sts_crane(Vector3(60 + i * 80, 0, -18), i % 2 == 1)
	_ship(Vector3(170, 0, 36))
	for bx in range(4):
		for bz in range(3):
			_stack_block(Vector3(10 + bx * 110, 0, -70 - bz * 55))
	# Rubber-tyred gantries over two of the blocks.
	for b in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 0)]:
		_rtg(Vector3(48.4 + b.x * 110 + rng.randf_range(-20, 20), 0, -79.9 - b.y * 55))
	# Straddle carriers in the aisles, trucks under the cranes.
	for i in range(10):
		_straddle(Vector3(20 + i * 42, 0, -110.0 if i % 2 == 0 else -165.0))
	for k in range(8):
		Vehicles.semi(geo, Vector3(40 + k * 42, 0.02, -26), -PI * 0.5 if k % 2 else PI * 0.5, Vehicles.random_paint(rng), _colors[rng.randi() % _colors.size()])
	for x in [-20.0, 110.0, 230.0, 350.0, 455.0]:
		_floodlight(Vector3(x, 0, -45))
		_floodlight(Vector3(x, 0, -236))
	# Gate: canopy over four lanes where the waterfront road ends,
	# the admin building beside it, trucks queueing.
	var g := Vector3(-30, 0, WF_Z)
	geo.box(g + Vector3(0, 6.2, 0), Vector3(12, 0.6, 24), "white")
	for dz in [-11.0, -3.7, 3.7, 11.0]:
		geo.box(g + Vector3(0, 3.1, dz), Vector3(0.5, 6.2, 0.5), "steel")
		geo.box(g + Vector3(2.0, 1.3, dz), Vector3(2.4, 2.6, 1.4), "white")
	geo.box(Vector3(10, 7.5, -250), Vector3(40, 15, 18), "sandstone")
	geo.box(Vector3(10, 15.4, -250), Vector3(41, 0.8, 19), "cty_cornice", 0.0, false, false)
	for k in range(5):
		Vehicles.semi(geo, Vector3(-60.0 - k * 19.0, 0.03, WF_Z + 2.5), -PI * 0.5, Vehicles.random_paint(rng), _colors[rng.randi() % _colors.size()])
	# Empty-container depot and a reefer stack along the east fence.
	for k in range(6):
		for lvl in range(rng.randi_range(3, 6)):
			geo.box(Vector3(440, lvl * CONT.y + CONT.y * 0.5, -60 - k * 14.0), Vector3(CONT.z, CONT.y, CONT.x), _colors[rng.randi() % _colors.size()])

## Rubber-tyred gantry crane straddling a stacking block: legs on
## tyres either side of the block's six rows, 28 m span, 21 m high.
func _rtg(p: Vector3) -> void:
	for dz in [-14.0, 14.0]:
		for dx in [-5.0, 5.0]:
			geo.box(p + Vector3(dx, 10.5, dz), Vector3(0.9, 21, 0.9), "yellow")
			geo.cylinder(p + Vector3(dx, 0.7, dz - 0.5), p + Vector3(dx, 0.7, dz + 0.5), 0.7, "veh_tyre", 10)
		geo.box(p + Vector3(0, 1.4, dz), Vector3(11, 1.0, 1.0), "yellow")
	for dx in [-5.0, 5.0]:
		geo.box(p + Vector3(dx, 21.5, 0), Vector3(1.2, 1.6, 29), "yellow")
	geo.box(p + Vector3(0, 21.5, 4), Vector3(10, 2.4, 4), "crane_red")
	geo.box(p + Vector3(5.6, 17, -14), Vector3(2, 2.2, 2), "glass")

func _straddle(p: Vector3) -> void:
	for dx in [-2.6, 2.6]:
		for dz in [-4.0, 4.0]:
			geo.box(p + Vector3(dx, 6.5, dz), Vector3(0.5, 13, 0.5), "yellow")
		geo.box(p + Vector3(dx, 0.8, 0), Vector3(0.9, 1.6, 9.4), "yellow")
	geo.box(p + Vector3(0, 13.4, 0), Vector3(6.2, 1.4, 9.4), "yellow")
	geo.box(p + Vector3(2.8, 12, -4.6), Vector3(1.4, 2, 1.6), "glass")
	if rng.randf() < 0.6:
		# The container hangs from the spreader, the spreader on four
		# ropes from the top frame.
		geo.box(p + Vector3(0, 4.0, 0), Vector3(2.44, 2.59, 12.2), _colors[rng.randi() % _colors.size()])
		geo.box(p + Vector3(0, 5.5, 0), Vector3(2.6, 0.4, 12.4), "yellow")
		for dz in [-4.5, 4.5]:
			for dx in [-1.0, 1.0]:
				geo.beam(p + Vector3(dx, 5.7, dz), p + Vector3(dx, 12.7, dz), Vector2(0.06, 0.06), "steel", false, false)

## A floodlight tower: a 30 m mast with a lamp head.
func _floodlight(p: Vector3) -> void:
	geo.cylinder(p, p + Vector3(0, 30, 0), 0.35, "steel", 8)
	geo.box(p + Vector3(0, 30.5, 0), Vector3(4, 1.4, 1.2), "white")

## Easter egg (2026-10-14): one container at the end of the empty-container
## depot stands with its doors swung open - inside, a tiny whoop race
## track: four 0.4 m gates weaving down the box and a start line on the
## floor. Placed (no chance); the spot is the first free one of a few.
func _open_container() -> void:
	EggProps.ensure(geo)
	if not geo.has_material("egg_lamp"):
		geo.add_material("egg_lamp", Geo.glow_mat(Color(1.0, 0.97, 0.85), 1.4))
	var spot := Vector2.INF
	for q: Vector2 in [Vector2(440, -150), Vector2(440, -168), Vector2(420, -150), Vector2(455, -150), Vector2(400, -165)]:
		if geo.claim_free(q, Vector2(1, 0), Vector2(CONT.z * 0.5, CONT.x * 0.5), 1.0):
			spot = q
			break
	if spot == Vector2.INF:
		return
	var mat: String = "c_white"
	var L: float = CONT.x
	var W: float = CONT.z
	var H: float = CONT.y
	var xf := Transform3D(Basis(Vector3.UP, PI), Vector3(spot.x, 0.0, spot.y)) # (the door end, local +z, faces -z)
	var fl: float = 0.15
	geo.begin_object("container")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, fl * 0.5 - 0.02, 0)), Vector3(W, fl + 0.04, L), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, H - 0.03, 0)), Vector3(W, 0.06, L), mat)
	for sx in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (W * 0.5 - 0.03), (H + fl) * 0.5 - 0.03, 0)), Vector3(0.06, H - fl - 0.06, L), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, (H + fl) * 0.5 - 0.03, -L * 0.5 + 0.03)), Vector3(W - 0.12, H - fl - 0.06, 0.06), mat)
	# Corner posts and the header at the door end, where the doors hang.
	geo.tint = Color(0.8, 0.8, 0.8)
	for sx in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (W * 0.5 - 0.06), H * 0.5, L * 0.5 - 0.06)), Vector3(0.12, H, 0.12), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, H - 0.07, L * 0.5 - 0.06)), Vector3(W, 0.14, 0.12), mat)
	geo.tint = Color.WHITE
	# The doors, each swung 100 degrees out round its corner post.
	var phi: float = deg_to_rad(100.0)
	for sx in [-1.0, 1.0]:
		var hinge := Vector3(sx * (W * 0.5 + 0.02), 0.0, L * 0.5 + 0.04)
		var d := Vector3(-sx * cos(phi), 0.0, sin(phi))
		var centre: Vector3 = hinge + d * (W * 0.25) + Vector3(0, (H - 0.2) * 0.5 + 0.1, 0)
		var db := Basis.looking_at(xf.basis * d, Vector3.UP)
		geo.box_xf(Transform3D(db, xf * centre), Vector3(0.05, H - 0.2, W * 0.5 - 0.02), mat)
	# Inside: a strip lamp, the start line on the floor (and its word), four gates.
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, H - 0.08, 0.5)), Vector3(0.7, 0.02, 0.06), "egg_lamp", false, false)
	var top: float = fl + 0.012 # (floor top + a hair: the line and the gates stand 1.2 cm proud of it)
	geo.tint = Color(0.96, 0.96, 0.94)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, fl + 0.006, 4.6)), Vector3(W - 0.5, 0.012, 0.07), "egg_flat", false, false)
	geo.tint = Color.WHITE
	var lbl := xf * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, fl + 0.03, 4.1))
	StreetKit._label(geo, "START", lbl, 0.004, Color(0.96, 0.96, 0.94), 0.5)
	var gates: Array = [[0.25, 2.6, 0.25], [-0.3, 0.2, -0.35], [0.3, -2.2, 0.3], [-0.2, -4.2, -0.2]]
	for gt: Array in gates:
		var gx := xf * Transform3D(Basis(Vector3.UP, gt[2]), Vector3(gt[0], top, gt[1]))
		geo.tint = Color(1.6, 0.8, 0.2)
		for sx in [-1.0, 1.0]:
			geo.box_xf(gx * Transform3D(Basis(), Vector3(sx * 0.2, 0.2, 0.0)), Vector3(0.03, 0.4, 0.03), "egg_flat", false, false)
		geo.box_xf(gx * Transform3D(Basis(), Vector3(0, 0.385, 0.0)), Vector3(0.43, 0.03, 0.03), "egg_flat", false, false)
		geo.box_xf(gx * Transform3D(Basis(), Vector3(0, 0.015, 0.0)), Vector3(0.43, 0.03, 0.03), "egg_flat", false, false)
		geo.tint = Color.WHITE
	geo.end_object()

func _cont(c: Vector3) -> void:
	geo.box(c + Vector3(0, CONT.y * 0.5, 0), CONT, _colors[rng.randi() % _colors.size()])

## Container block: 7 containers long (x), 6 rows (z), stacked 1-4
## high, 1.5 m between rows - wide enough to fly between.
func _stack_block(o: Vector3) -> void:
	for row in range(6):
		for col in range(7):
			if rng.randf() < 0.08:
				continue
			var h: int = rng.randi_range(1, 4)
			for lvl in range(h):
				_cont(o + Vector3(col * (CONT.x + 0.6), lvl * CONT.y, -row * (CONT.z + 1.5)))

## Ship-to-shore crane: legs over the quay rails, a boom out over the
## ship, machinery house, trolley. Rail gauge 30 m.
func _sts_crane(o: Vector3, boom_up: bool) -> void:
	for dx in [-9.0, 9.0]:
		for dz in [-15.0, 15.0]:
			geo.box(o + Vector3(dx, 20, dz), Vector3(1.5, 40, 1.5), "crane")
			geo.box(o + Vector3(dx, 0.8, dz), Vector3(2.4, 1.6, 5.0), "yellow")
		geo.beam(o + Vector3(dx, 12, -15), o + Vector3(dx, 12, 15), Vector2(1.2, 1.5), "crane")
		geo.beam(o + Vector3(dx, 2, -15), o + Vector3(dx, 38, 15), Vector2(0.8, 0.8), "crane")
	for dz in [-15.0, 15.0]:
		geo.beam(o + Vector3(-9, 40, dz), o + Vector3(9, 40, dz), Vector2(1.5, 1.5), "crane")
	var boom_end: Vector3 = o + (Vector3(0, 72, 45) if boom_up else Vector3(0, 42, 70))
	for dx in [-3.5, 3.5]:
		geo.beam(o + Vector3(dx, 42, -35), o + Vector3(dx, 42, 15), Vector2(1.0, 2.0), "crane")
		geo.beam(o + Vector3(dx, 42, 15), boom_end + Vector3(dx, 0, 0), Vector2(1.0, 2.0), "crane")
	geo.beam(o + Vector3(-5, 40, 0), o + Vector3(0, 60, 0), Vector2(1, 1), "crane")
	geo.beam(o + Vector3(5, 40, 0), o + Vector3(0, 60, 0), Vector2(1, 1), "crane")
	geo.beam(o + Vector3(0, 60, 0), boom_end, Vector2(0.3, 0.3), "steel")
	geo.beam(o + Vector3(0, 60, 0), o + Vector3(0, 42, -35), Vector2(0.3, 0.3), "steel")
	geo.box(o + Vector3(0, 45, -25), Vector3(10, 6, 12), "white")
	geo.box(o + Vector3(0, 40.5, 8), Vector3(6.2, 3, 4), "crane_red") # between the boom girders
	if not boom_up:
		# The trolley on the boom girders, its hoist rope and the spreader.
		geo.box(o + Vector3(0, 40.8, 30), Vector3(8.2, 1.6, 3.0), "crane_red")
		geo.beam(o + Vector3(0, 40, 30), o + Vector3(0, 22, 30), Vector2(0.1, 0.1), "steel", false)
		geo.box(o + Vector3(0, 21.5, 30), Vector3(12.4, 0.8, 2.6), "yellow")

## Container ship alongside: hull, bow, bridge aft, deck cargo in bays.
func _ship(o: Vector3) -> void:
	var L: float = 280.0
	var B: float = 40.0
	geo.box(o + Vector3(0, 2, 0), Vector3(L, 12, B), "hull")
	geo.box(o + Vector3(0, -3.5, 0), Vector3(L + 0.1, 1.5, B + 0.2), "hull_red", 0.0, false, false) # (5 cm longer than the hull: flush ends flickered)
	geo.cone(o + Vector3(L * 0.5, 2, 0), o + Vector3(L * 0.5 + 18, 5, 0), B * 0.5, 2, "hull", 4)
	var bridge := o + Vector3(-L * 0.5 + 34, 8, 0)
	geo.box(bridge + Vector3(0, 12, 0), Vector3(14, 24, B - 4), "white")
	geo.box(bridge + Vector3(0, 22, 0), Vector3(14.2, 3, B + 6), "glass")
	geo.box(bridge + Vector3(-9.5, 11, 0), Vector3(5, 22, 6), "hull_red") # funnel, on deck against the superstructure
	for bay in range(12):
		var x: float = o.x - L * 0.5 + 58 + bay * 17
		for row in range(15):
			var h: int = rng.randi_range(2, 6)
			for lvl in range(h):
				var c := Vector3(x, 8 + lvl * CONT.y, o.z - B * 0.5 + 2 + row * CONT.z)
				geo.box(c + Vector3(0, CONT.y * 0.5, 0), CONT, _colors[rng.randi() % _colors.size()], 0.0, true, lvl == h - 1)

# --- bulk berth, basin, tank farm -----------------------------------------------------

## Grain silos at the bulk berth: a battery of concrete bins with the
## head house on top, a truck intake hall, a conveyor gallery out to
## the ship loader over the moored bulk carrier.
func _bulk_berth() -> void:
	var o := Vector3(-125, 0, -95)
	for i in range(3):
		for j in range(5):
			geo.cylinder(o + Vector3(-11 + i * 11, 0, -22 + j * 11), o + Vector3(-11 + i * 11, 44, -22 + j * 11), 5.4, "quay", 18)
	geo.box(o + Vector3(0, 50, 0), Vector3(36, 12, 58), "white")
	geo.box(o + Vector3(0, 30, 32), Vector3(8, 60, 8), "white")
	geo.box(o + Vector3(-28, 6, 0), Vector3(20, 12, 40), "warehouse")
	var a := o + Vector3(0, 52, 32)
	var b := Vector3(-150, 24, -3)
	# The gallery ends open over the loader, on a short frame - fly out of
	# it there (2026-10-14: it ran into the loader's top, a dead end).
	var b_end: Vector3 = b + (a - b).normalized() * 2.5
	geo.pipe(a, b_end, 1.8, 0.2, "white", 12)
	geo.beam(Vector3(b.x, 24, b.z), b_end - Vector3(0, 1.7, 0), Vector2(0.4, 0.4), "yellow")
	geo.box(Vector3(-150, 12, -3), Vector3(6, 24, 6), "yellow")
	geo.beam(Vector3(-150, 24, -3), Vector3(-150, 20, 22), Vector2(2.2, 2.2), "yellow")
	# Bulk carrier.
	var s := Vector3(-150, 0, 24)
	geo.box(s + Vector3(0, 2, 0), Vector3(190, 12, 30), "hull_red")
	for i in range(5):
		geo.box(s + Vector3(-60 + i * 28, 8.6, 0), Vector3(18, 1.2, 22), "hull")
	geo.box(s + Vector3(-85, 16, 0), Vector3(12, 16, 26), "white")
	geo.box(s + Vector3(-85, 22, 0), Vector3(12.2, 2.5, 30), "glass")
	for k in range(4):
		Vehicles.tipper(geo, Vector3(-170.0 + k * 14.0, 0.02, -150), 0.0, Vehicles.random_paint(rng), "")
	# Transit shed for general cargo, steel coils and timber on the quay,
	# a forklift lane - keeping the spawn (-200, -40) clear.
	# (IndustryCreator hall: docks on the quay side, its open door at the
	# east end - fly in from the tipper lane.)
	_port_hall(Vector3(-215, 0, -175), 80.0, 40.0, 11.0, 5, {"office": false, "roof": "gable"}, "")
	for i in range(6):
		for j in range(3):
			var cp := Vector3(-95 + i * 4.2, 1.1, -30 + j * 4.5)
			geo.cylinder(cp - Vector3(0, 0, 0.9), cp + Vector3(0, 0, 0.9), 1.1, "steel", 12)
	for i in range(4):
		for lvl in range(rng.randi_range(2, 4)):
			geo.box(Vector3(-250 + i * 9.0, 0.6 + lvl * 1.2, -100), Vector3(6.0, 1.1, 12.0), "boat_wood")
	for k in range(3):
		Vehicles.semi(geo, Vector3(-60.0, 0.02, -60.0 - k * 25.0), 0.0, Vehicles.random_paint(rng), "veh_trailer")

## The old harbour basin: marina pontoons with yachts and motorboats,
## brick warehouses along the north quay (5 storeys, gables), the fish
## market on the west bank, a promenade with trees and lamps.
func _basin() -> void:
	for i in range(5):
		var x: float = BASIN.position.x + 40 + i * 55
		geo.box(Vector3(x, -2.4, -60), Vector3(3, 0.6, 110), "boat_wood")
		for k in range(7):
			for s2 in [-1.0, 1.0]:
				if rng.randf() < 0.8:
					Vehicles.boat(geo, Vector3(x + s2 * 8.0, -2.8, -105 + k * 15), PI * 0.5 * s2 + PI * 0.5, rng.randf() < 0.6)
	for k in range(3):
		var c := Vector3(BASIN.position.x + 55 + k * 100, 0, -180)
		if k == 1:
			_speicher(c)
		else:
			geo.box(c + Vector3(0, 9, 0), Vector3(90, 18, 30), "brick")
		for gx in [-30.0, 0.0, 30.0]:
			var pts: Array = []
			for i in range(8):
				var hx: float = 14.5 * (1.0 if i & 1 else -1.0)
				var hz: float = 15.0 * (1.0 if i & 4 else -1.0)
				var yy: float = 18.0
				if i & 2:
					hx *= 0.03
					yy = 27.0
				pts.append(c + Vector3(gx + hx, yy, hz))
			geo.hexa(pts, "cty_slate")
		for wx in range(-40, 41, 8):
			for fy in [4.0, 8.0, 12.0, 16.0]:
				if k == 1 and absf(wx) in [0, 32] and fy > 5.0:
					continue # the open loading doors
				geo.box(c + Vector3(wx, fy, 15.02), Vector3(2.0, 2.2, 0.06), "glass", 0.0, false, false)
	for k in range(14):
		var p := Vector3(BASIN.position.x + 10 + k * 22, 0, -140)
		city.trees.append([p, 1, rng.randf_range(0.7, 0.9)])
		if k % 2 == 0:
			roads.lamp(p + Vector3(8, 0, 4), Vector3(0, 0, 1))
	_fish_market(Vector3(-600, 0, -60))
	# A lost drone in a plane tree on the basin promenade.
	_tc_trees.append([Vector3(BASIN.position.x + 10 + 9 * 22 + 11.0, 0.0, -146.0), "maple", 9, "drone", true, 1.0])

## Oil terminal east of the container terminal: tanks in bunded pairs,
## a pipe rack out along the jetty to a moored tanker.
func _tank_farm() -> void:
	for i in range(3):
		for j in range(2):
			var c := Vector3(510 + i * 60, 0, -210 + j * 70)
			geo.lathe(c, [Vector2(22, 0), Vector2(22, 17), Vector2(20, 18.5), Vector2(0.5, 19.5)], "tank_white", 28)
			var stair: Array[Vector3] = []
			for k in range(9):
				var a: float = k * 0.2
				stair.append(c + Vector3(cos(a) * 22.6, k * 2.1, sin(a) * 22.6))
			geo.sweep(stair, [Vector2(0.6, 0.0), Vector2(-0.6, 0.0)], "steel", false, true, false)
	for z in [-245.0, -175.0, -105.0]:
		geo.box(Vector3(570, 0.8, z), Vector3(190, 1.6, 0.6), "quay")
	for x in [475.0, 665.0]:
		geo.box(Vector3(x, 0.8, -175), Vector3(0.6, 1.6, 140), "quay")
	# Pipe rack from the tanks down the jetty: the pipes bend round the
	# corner instead of meeting at a point.
	var run: Array[Vector3] = Route.rounded([Vector3(480, 7, -100), Vector3(690, 7, -100), Vector3(690, 7, 170)], 6.0)
	for k in range(3):
		geo.pipe_path(Route.offset_pts(run, -0.9 + k * 0.9), 0.35, "tank_white" if k != 1 else "hull", 0.0, 10, true, false)
	var d: float = 0.0
	var rr := Route.new()
	rr.pts = run
	while d < rr.length():
		var q: Vector3 = rr.sample(d)[0]
		var t: Vector3 = rr.sample(d)[1]
		var side := Vector3(-t.z, 0, t.x).normalized()
		for s2 in [-1.4, 1.4]:
			geo.box(Vector3(q.x, 3.3, q.z) + side * s2, Vector3(0.4, 6.6, 0.4), "steel")
		# Crossbeams between the posts: one mid-height, one the pipes rest on.
		for yb in [3.2, 6.45]:
			geo.beam(Vector3(q.x, yb, q.z) - side * 1.6, Vector3(q.x, yb, q.z) + side * 1.6, Vector2(0.4, 0.4), "steel")
		d += 16.0
	geo.box(Vector3(690, 1.2, 60), Vector3(10, 2.4, 240), "quay") # jetty
	geo.box(Vector3(690, 8, 170), Vector3(12, 12, 12), "yellow")
	geo.box(Vector3(740, 2, 150), Vector3(40, 12, 220), "hull_red")
	geo.box(Vector3(740, 12, 245), Vector3(34, 14, 18), "white")
	geo.box(Vector3(740, 17, 245), Vector3(36, 2.5, 18.2), "glass")

# --- roads --------------------------------------------------------------------------

## Waterfront road (out of the map west, ends at the terminal gate),
## the two bridges over the railway into the city.
func _road_network() -> void:
	var jw := Vector3(XS[0], 0, WF_Z)
	var ja := Vector3(XS[4], 0, WF_Z)
	roads.junction(jw, Vector2(XW[0], 12.0), ["e", "w"], 3.0)
	roads.junction(ja, Vector2(XW[4], 12.0), ["e", "w"], 3.0)
	var west := Route.from(Vector3(-3000, 0, WF_Z), 0.0).straight(jw.x - XW[0] * 0.5 + 3000.0, 20.0)
	roads.road(west, 12.0, {"walk": 3.0, "lamps": 36.0})
	roads.traffic(west, 12.0, 1, 18.0, 0.3, _colors)
	var mid := Route.from(Vector3(jw.x + XW[0] * 0.5, 0, WF_Z), 0.0).straight(ja.x - XW[4] * 0.5 - jw.x - XW[0] * 0.5, 12.0)
	roads.road(mid, 12.0, {"walk": 3.0, "lamps": 36.0})
	roads.traffic(mid, 12.0, 1, 15.0, 0.4, _colors)
	var east := Route.from(Vector3(ja.x + XW[4] * 0.5, 0, WF_Z), 0.0).straight(-36.0 - ja.x - XW[4] * 0.5, 12.0)
	roads.road(east, 12.0, {"walk": 3.0, "lamps": 36.0})
	# The two bridges: from the avenue junction south over the rail
	# corridor (8.5 m clear over the catenary) down to the waterfront
	# road. The one at XS[0] carries on south to the basin car park.
	for i in [0, 4]:
		var x: float = XS[i]
		var w: float = XW[i]
		var z0: float = AVENUE_S
		var z1: float = WF_Z - 6.0
		var r := Route.from(Vector3(x, 0, z0), 90.0).straight(z1 - z0, 6.0)
		for k in range(r.pts.size()):
			var z: float = r.pts[k].z
			if z < -470.0:
				r.pts[k].y = 9.0 * smoothstep(z0, -470.0, z)
			elif z <= -370.0:
				r.pts[k].y = 9.0
			else:
				r.pts[k].y = 9.0 * (1.0 - smoothstep(-370.0, z1, z))
		roads.viaduct(r, w, 30.0)
		roads.road(r, w, {"walk": 2.0, "lamps": 30.0})
		roads.traffic(r, w, 1, 25.0, 0.3, _colors)
		# Steel truss sides over the tracks.
		for s in [-1.0, 1.0]:
			var tx: float = x + s * (w * 0.5 + 0.35) # on the deck's edge beam
			for k in range(9):
				var za: float = -466.0 + k * 11.0
				geo.beam(Vector3(tx, 9.0, za), Vector3(tx, 15.0, za + 5.5), Vector2(0.4, 0.4), "crane")
				geo.beam(Vector3(tx, 15.0, za + 5.5), Vector3(tx, 9.0, za + 11.0), Vector2(0.4, 0.4), "crane")
			geo.box(Vector3(tx, 15.0, -416.5), Vector3(0.6, 0.6, 99), "crane")
		for s in [-1.0, 1.0]:
			geo.beam(Vector3(x - w * 0.5 - 0.35, 15.0, -416.5 + s * 30.0), Vector3(x + w * 0.5 + 0.35, 15.0, -416.5 + s * 30.0), Vector2(0.4, 0.6), "crane", true, false)
	var south := Route.from(Vector3(XS[0], 0, WF_Z + 6.0), 90.0).straight(60.0, 12.0)
	roads.road(south, 10.0, {"walk": 2.5, "lamps": 25.0})
	city.car_park(Rect2(XS[0] - 50.0, WF_Z + 66.0, 100.0, 34.0), 0.0)

# --- the city -----------------------------------------------------------------------

func _city() -> void:
	var blocks: Array[Rect2] = roads.grid(XS, ZS, XW, ZW, 4.0, 0.0, {"n": 1400.0, "w": 2300.0, "e": 2600.0}, {"traffic": 14.0, "lamps": 30.0})
	for r: Rect2 in blocks:
		var c: Vector2 = r.get_center()
		var near_station: float = Vector2(c.x - (-290.0), c.y - (-560.0)).length()
		if absf(c.x - (-470.0)) < 50.0 and absf(c.y - (-790.0)) < 40.0:
			city.park(r, 0.0)
		elif absf(c.x - (-90.0)) < 50.0 and absf(c.y - (-890.0)) < 40.0:
			_church(r)
		elif absf(c.x - 150.0) < 50.0 and absf(c.y - (-590.0)) < 40.0:
			city.car_park(r, 0.0)
		elif near_station < 190.0 and c.y > -760.0:
			city.tower(r, 0.0, rng.randf_range(55.0, 115.0))
		else:
			city.perimeter_block(r, 0.0, 4, 7 if near_station < 400.0 else 5)
	# Boulevard: plane trees on both pavements, tram tracks in the middle
	# from the stop on the station square north out of the map.
	var bx: float = XS[3]
	for j in range(ZS.size() - 1):
		var z: float = ZS[j] + ZW[j] * 0.5 + 8.0
		while z < ZS[j + 1] - ZW[j + 1] * 0.5 - 8.0:
			for s in [-1.0, 1.0]:
				city.trees.append([Vector3(bx + s * 17.0, 0.14, z), 1, rng.randf_range(0.75, 0.95)])
			z += 14.0
	for s in [-1.0, 1.0]:
		var groove := Route.from(Vector3(bx + s * 1.6, 0, -490.0), -90.0).straight(2400.0, 20.0)
		roads.line(groove.pts, -0.72, 0.1, "groove")
		roads.line(groove.pts, 0.72, 0.1, "groove")
	Vehicles.tram(geo, Vector3(bx + 1.6, 0.04, -620), PI)
	Vehicles.tram(geo, Vector3(bx - 1.6, 0.04, -780), 0.0)
	Vehicles.tram(geo, Vector3(bx - 1.6, 0.04, -506), 0.0)

func _church(r: Rect2) -> void:
	geo.slab(r, 0.02, 0.1, "cty_court", false)
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.box(c + Vector3(0, 8, 8), Vector3(18, 16, 40), "cty_brick")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s * 0.78), c + Vector3(s * 4.6, 20.5, 8)), Vector3(13.4, 0.5, 41), "cty_slate")
	geo.box(c + Vector3(0, 22, -16), Vector3(9, 44, 9), "cty_brick")
	geo.cone(c + Vector3(0, 44, -16), c + Vector3(0, 62, -16), 6.5, 0.2, "cty_slate", 4)
	for k in range(6):
		city.trees.append([c + Vector3(-26.0 + (k % 2) * 52.0, 0, -18.0 + (k / 2) * 18.0), 1, 0.9])

## Between the waterfront road and the railway: the station's south
## forecourt with the bus station, a car park, the parcel depot, offices.
func _south_district() -> void:
	var zt: float = MAIN_Z + 2.25 + 12.5 + 12.0 # south of the station fence
	# Rail fence: posts and mesh panels (dark, see-through look from a distance).
	var fx: float = -640.0
	while fx < 60.0:
		geo.box(Vector3(fx, 1.0, zt - 4.0), Vector3(0.1, 2.0, 0.1), "steel", 0.0, true, false)
		fx += 3.0
	for fy in [0.3, 1.95]:
		geo.box(Vector3(-290, fy, zt - 4.0), Vector3(700, 0.06, 0.06), "steel", 0.0, false, false)
	var bs := Rect2(-420, zt + 2.0, 190, 45)
	geo.slab(bs, 0.04, 0.1, "cty_lot", false)
	for k in range(4):
		var pz: float = bs.position.y + 8.0 + k * 11.0
		geo.box(Vector3(bs.get_center().x, 0.12, pz), Vector3(150, 0.2, 2.5), "rd_walk")
		geo.box(Vector3(bs.get_center().x, 3.2, pz), Vector3(150, 0.3, 3.5), "cty_metal")
		for q in range(6):
			geo.box(Vector3(bs.position.x + 25 + q * 28, 1.6, pz), Vector3(0.15, 3.2, 0.15), "steel")
		for q in range(3):
			if rng.randf() < 0.75:
				Vehicles.bus(geo, Vector3(bs.position.x + 40 + q * 45, 0.04, pz + 4.0), PI * 0.5, "veh_paint11" if q % 2 else "veh_paint7")
	city.car_park(Rect2(-215, zt + 2.0, 55, 100), 0.0)
	# Parcel depot: two long sheds with loading docks and lorries.
	for k in range(2):
		var c := Vector3(-560 + k * 90, 0, zt + 55.0)
		_port_hall(c, 70.0, 40.0, 10.0, 6, {"office": false, "roof": "gable"}, "box")
		geo.slab(Rect2(c.x - 38, c.z + 20, 76, 30), 0.03, 0.1, "cty_lot", false)
	# Along the north side of the waterfront road: a row of houses and
	# a hotel with shops, between the two bridges.
	var x: float = -632.0
	while x < -150.0:
		var w: float = rng.randf_range(18.0, 30.0)
		if x + w > -150.0:
			break
		city.building(Vector3(x + w * 0.5, 0, WF_Z - 6.0 - 3.0 - 16.0), Vector2(w - 0.4, 30.0), 0.0, rng.randi_range(4, 7), City.FACADES[rng.randi() % City.FACADES.size()], ["flat", "mansard", "gable"][rng.randi() % 3], true)
		x += w
	# Offices by the east bridge.
	for k in range(2):
		city.tower(Rect2(-108, zt + 5.0 + k * 70.0, 64, 60), 0.0, 30.0 + k * 18.0)

## North of the sidings: workshops and a bus depot along the avenue.
func _sidings_district() -> void:
	for k in range(5):
		var c := Vector3(-15 + k * 120.0, 0, -500.0)
		_port_hall(c, 56.0, 34.0, 10.0, 3, {}, "box")

## Past the playable area: the street grid carries on (the streets
## that run out of the map) with cheap blocks between them, on asphalt,
## so the city fades into the haze instead of ending.
func _far_filler() -> void:
	var xs: Array = XS.duplicate()
	while xs[0] > -2100.0:
		xs.push_front(xs[0] - 120.0)
	while xs[-1] < 2100.0:
		xs.append(xs[-1] + 120.0)
	var zs: Array = ZS.duplicate()
	while zs[0] > -2300.0:
		zs.push_front(zs[0] - 100.0)
	geo.add_material("far_asphalt", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 1, 0.3))
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var x0: float = xs[i]
			var x1: float = xs[i + 1]
			var z0: float = zs[j]
			var z1: float = zs[j + 1]
			var core: bool = x0 >= XS[0] - 1.0 and x1 <= XS[-1] + 1.0 and z0 >= ZS[0] - 1.0
			if core:
				continue
			var cc := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if cc.distance_to(Vector2(-100, -380)) > 2300.0:
				continue
			var il: float = 20.0 if absf(x0 - XS[3]) < 1.0 else 10.0
			var ir: float = 20.0 if absf(x1 - XS[3]) < 1.0 else 10.0
			var inner := Rect2(x0 + il, z0 + 10.0, x1 - x0 - il - ir, z1 - z0 - 20.0)
			var on_rail: bool = false
			for q: Vector3 in main_n.pts:
				if absf(q.x - cc.x) < 90.0 and absf(q.z - cc.y) < 80.0:
					on_rail = true
					break
			if on_rail:
				continue
			# Streets of the core grid already run here; elsewhere the
			# asphalt under the block stands in for the far streets.
			var near_street: bool = (x0 >= XS[0] - 1.0 and x1 <= XS[-1] + 1.0) or z0 >= ZS[0] - 1.0
			if not near_street:
				geo.slab(Rect2(x0, z0, x1 - x0, z1 - z0), 0.0, 0.5, "far_asphalt", false)
			city.filler_block(inner, 0.0)
	var wf := Route.from(Vector3(XS[0] - 30.0, 0, WF_Z), 180.0).straight(1800.0, 20.0)
	city.filler(wf, 1.0, 12.0, 2, 4, ["warehouse", "brick"])

## East of the port: the logistics road from the terminal's east gate
## out of the map, warehouses and truck yards along it.
func _east_logistics() -> void:
	var r := Route.from(Vector3(470, 0, -300), 0.0).straight(2600.0, 20.0)
	roads.road(r, 12.0, {"walk": 2.5, "lamps": 40.0, "detail": 700.0})
	roads.traffic(Route.from_pts(r.slice(0.0, 900.0)), 12.0, 1, 16.0, 0.5, _colors)
	geo.box(Vector3(472, 3.2, -300), Vector3(1.0, 6.4, 14), "white")
	for k in range(6):
		for s in [-1.0, 1.0]:
			if s < 0.0 and k < 2:
				continue # the rail branch passes north of the first two lots
			var c := Vector3(760 + k * 130, 0, -300 + s * 58.0)
			geo.slab(Rect2(c.x - 55, c.z - 40, 110, 80), 0.0, 1.0, "paving")
			geo.box(c + Vector3(0, 7, s * 8.0), Vector3(90, 14, 40), "warehouse" if (k + int(s)) % 2 else "sandstone")
			geo.box(c + Vector3(0, 14.3, s * 8.0), Vector3(91, 0.6, 41), "cty_roof", 0.0, false, false)
			for q in range(7):
				geo.box(c + Vector3(-39 + q * 13, 2.2, s * 8.0 - s * 20.05), Vector3(4, 4.4, 0.1), "cty_dark", 0.0, false, false)
				if rng.randf() < 0.55:
					Vehicles.semi(geo, c + Vector3(-39 + q * 13, 0.02, s * 8.0 - s * 29.0), 0.0 if s > 0.0 else PI, Vehicles.random_paint(rng), "veh_trailer")
	city.filler(Route.from_pts(r.slice(820.0, 2600.0)), 1.0, 30.0, 2, 4, ["warehouse", "sandstone"])
	city.filler(Route.from_pts(r.slice(820.0, 2600.0)), -1.0, 30.0, 2, 4, ["warehouse", "sandstone"])

## Offshore wind farm: 100 m towers, three blades.
func _wind_farm() -> void:
	for i in range(6):
		var p := Vector3(300 + (i % 3) * 260, WATER_Y, 700 + (i / 3) * 280 + (i % 3) * 60)
		geo.cylinder(p + Vector3(0, -2, 0), p + Vector3(0, 6, 0), 5, "yellow", 12)
		geo.cone(p + Vector3(0, 6, 0), p + Vector3(0, 100, 0), 2.6, 1.6, "white", 14)
		var hub := p + Vector3(0, 101, -3)
		geo.box(p + Vector3(0, 101, 2), Vector3(3.5, 3.5, 11), "white")
		for k in range(3):
			var a: float = TAU * k / 3.0 + i * 0.7
			geo.beam(hub, hub + Vector3(cos(a), sin(a), 0) * 55.0, Vector2(2.0, 0.4), "white", true, false)

## A rock breakwater with a lighthouse at its head.
func _breakwater() -> void:
	for i in range(32):
		var p := Vector3(480 + i * 2.0, 0, 20 + i * 7.5)
		geo.box(p + Vector3(0, -1.0, 0), Vector3(12, 5, 9), "rock", rng.randf() * 0.4)
	var lh := Vector3(545, 0, 262)
	geo.cylinder(lh + Vector3(0, -3, 0), lh + Vector3(0, 2, 0), 8, "rock", 12)
	geo.lathe(lh + Vector3(0, 2, 0), [Vector2(3.2, 0), Vector2(2.4, 22)], "white", 16)
	geo.lathe(lh + Vector3(0, 9, 0), [Vector2(3.0, 0), Vector2(3.0, 3)], "crane_red", 16)
	geo.cylinder(lh + Vector3(0, 24, 0), lh + Vector3(0, 27, 0), 2.2, "glass", 12)
	geo.cone(lh + Vector3(0, 27, 0), lh + Vector3(0, 29.5, 0), 2.6, 0.2, "crane_red", 12)

func _tug(p: Vector3) -> void:
	geo.box(p + Vector3(0, -1.5, 0), Vector3(9, 3, 28), "hull_red")
	geo.box(p + Vector3(0, 2, -3), Vector3(7, 4, 9), "white")
	geo.box(p + Vector3(0, 4.5, -3), Vector3(7.2, 1.2, 9.2), "glass")

## The old warehouse (Speicher) in the middle of the basin row, open:
## four floors on timber posts, a column of loading doors open on each
## floor of the basin front (fly in on any floor), sacks and crates -
## and on the top floor, in the north-west corner behind a partition,
## the dockers' toilet.
func _speicher(c: Vector3) -> void:
	if not geo.has_material("hb_wood"):
		geo.add_material("hb_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.85, 0.7, 0.55), 1.6))
		geo.add_material("hb_sack", Geo.tex_mat(MapTextures.get_tex("fabric"), Color(0.85, 0.75, 0.55), 1.0))
		# Lamp-lit inside: the floors and goods are not left in the roof's
		# shadow (the shadow map can't tell a lit loft from a dark one).
		for m in ["hb_wood", "hb_sack"]:
			geo.material(m).set_meta("no_shadow", true)
	IndustryCreator.ensure_materials(geo) # in_lamp
	var r := RandomNumberGenerator.new()
	r.seed = 1888
	var L: float = 90.0
	var B: float = 30.0
	var H: float = 18.0
	var t: float = 0.6
	var floors: Array = [0.2, 4.6, 9.0, 13.4]
	# Back and end walls, solid.
	geo.box(c + Vector3(0, H * 0.5, -B * 0.5 + t * 0.5), Vector3(L, H, t), "brick")
	for sx in [-1.0, 1.0]:
		geo.box(c + Vector3(sx * (L * 0.5 - t * 0.5), H * 0.5, 0), Vector3(t, H, B - 2.0 * t), "brick")
	# The basin front: 8 m bays by floor, open where the loading doors are.
	var bay: float = 8.0
	var x: float = -L * 0.5
	while x < L * 0.5 - 0.1:
		var w: float = minf(bay, L * 0.5 - x)
		var mid: float = x + w * 0.5
		for f in range(4):
			var y0: float = 0.0 if f == 0 else floors[f]
			var y1: float = floors[f + 1] if f < 3 else H
			var door: bool = absf(mid) < 4.1 or absf(absf(mid) - 32.0) < 4.1
			if door:
				# a door 3 m wide in the bay, wall either side, lintel over it
				var dh: float = 3.4 if f > 0 else 4.0
				for sd in [-1.0, 1.0]:
					geo.box(c + Vector3(mid + sd * (1.5 + (w - 3.0) * 0.25), (y0 + y1) * 0.5, B * 0.5 - t * 0.5), Vector3((w - 3.0) * 0.5, y1 - y0, t), "brick")
				geo.box(c + Vector3(mid, (y0 + dh + y1) * 0.5, B * 0.5 - t * 0.5), Vector3(3.0, y1 - y0 - dh, t), "brick")
				if f > 0:
					# the door leaf swung open against the wall, a hoist beam over it
					geo.box(c + Vector3(mid + 2.2, y0 + 1.7, B * 0.5 + 0.7), Vector3(0.08, 3.2, 1.4), "hb_wood", 0.0, false)
			else:
				geo.box(c + Vector3(mid, (y0 + y1) * 0.5, B * 0.5 - t * 0.5), Vector3(w, y1 - y0, t), "brick")
		x += w
	for hx in [-32.0, 0.0, 32.0]:
		geo.box(c + Vector3(hx, H + 0.6, B * 0.5 + 1.0), Vector3(0.5, 0.6, 2.6), "hb_wood")
	# Floors and timber posts.
	for f in range(4):
		var fy: float = floors[f]
		geo.box(c + Vector3(0, fy - 0.15, 0), Vector3(L - 2.0 * t, 0.3, B - 2.0 * t), "hb_wood")
	geo.box(c + Vector3(0, H - 0.15, 0), Vector3(L, 0.3, B), "brick") # the top ceiling under the roofs
	for px in range(-40, 41, 10):
		for pz in [-7.0, 7.0]:
			for f in range(3):
				geo.box(c + Vector3(px, (floors[f] + floors[f + 1] - 0.3) * 0.5, pz), Vector3(0.4, floors[f + 1] - floors[f] - 0.3, 0.4), "hb_wood")
			geo.box(c + Vector3(px, (floors[3] + H - 0.3) * 0.5, pz), Vector3(0.4, H - floors[3] - 0.3, 0.4), "hb_wood")
	# A row of lamps under each ceiling, over the middle aisle.
	for f in range(4):
		var top: float = (floors[f + 1] if f < 3 else H) - 0.3
		for lx in range(-36, 37, 12):
			geo.box(c + Vector3(lx, top - 0.5, 0), Vector3(0.6, 0.12, 0.6), "in_lamp", 0.0, false, false)
			geo.box(c + Vector3(lx, top - 0.22, 0), Vector3(0.04, 0.44, 0.04), "steel", 0.0, false, false)
	# Goods: sacks on pallets, crates.
	for f in range(4):
		for k in range(10):
			var q := c + Vector3(r.randf_range(-L * 0.5 + 4.0, L * 0.5 - 4.0), floors[f], r.randf_range(-B * 0.5 + 3.0, B * 0.5 - 5.0))
			if absf(q.x - c.x) < 6.0 or absf(absf(q.x - c.x) - 32.0) < 5.0:
				continue # keep the ways in clear
			geo.box(q + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), "hb_wood")
			var n: int = r.randi_range(1, 4)
			for j in range(n):
				geo.box(q + Vector3(r.randf_range(-0.05, 0.05), 0.14 + 0.15 + j * 0.3, 0), Vector3(1.0, 0.3, 0.75), "hb_sack", r.randf_range(-0.1, 0.1))
	# More clutter: crates, sacks on pallets, pallet stacks, barrels and old
	# machinery, scattered by their own dice, kept off the loading-door aisles,
	# the middle lane (|dz| < 2.5), the posts and the gnome's pallet.
	var r2 := RandomNumberGenerator.new()
	r2.seed = 4711
	var r2_rects: Array = [[], [], [], []] # Rect2(dx, dz) per floor, for the third pass
	for f in range(4):
		var fy2: float = floors[f]
		var placed: Array = [] # Vector3(dx, dz, radius)
		var tries: int = 0
		var made: int = 0
		while made < 24 and tries < 200:
			tries += 1
			var kind: int = r2.randi() % 9
			var rad: float = [1.0, 0.95, 0.9, 1.25, 1.5, 0.75, 1.1, 2.3, 1.2][kind]
			var mag: float = r2.randf_range(6.5, 44.0) if r2.randf() < 0.8 else r2.randf_range(37.0, 44.0)
			var dx: float = mag * (1.0 if r2.randf() < 0.5 else -1.0)
			var dz: float = r2.randf_range(2.5 + rad, 13.8 - rad) * (1.0 if r2.randf() < 0.5 else -1.0)
			if absf(dx) - rad < 6.2 or absf(dx) + rad > 44.2 or absf(absf(dx) - 32.0) < 5.2 + rad:
				continue
			var ok: bool = true
			for px in range(-40, 41, 10):
				for pz in [-7.0, 7.0]:
					if Vector2(dx - px, dz - pz).length() < rad + 0.6:
						ok = false
			for pl in placed:
				if Vector2(dx - pl.x, dz - pl.y).length() < rad + pl.z + 0.4:
					ok = false
			if f == 2 and Vector2(c.x + dx + 386.0, c.z + dz + 186.0).length() < rad + 3.0:
				ok = false
			if not ok:
				continue
			placed.append(Vector3(dx, dz, rad))
			r2_rects[f].append(Rect2(dx - rad, dz - rad, 2.0 * rad, 2.0 * rad))
			made += 1
			var q := Vector3(c.x + dx, fy2, c.z + dz)
			var yaw: float = r2.randf_range(-PI, PI)
			var bs := Basis(Vector3.UP, yaw)
			match kind:
				0: # a stack of crates, 1 to 2 high
					var nc: int = r2.randi_range(1, 2)
					for j in range(nc):
						geo.box(q + Vector3(0, 0.45 + j * 0.9, 0), Vector3(1.0, 0.9, 1.0), "hb_wood", yaw + j * 0.15)
					if r2.randf() < 0.6:
						geo.box(q + bs * Vector3(1.0, 0.3, 0.3), Vector3(0.8, 0.6, 0.7), "hb_wood", yaw + 0.4)
				1: # sacks on a pallet, 3 to 5 layers
					geo.box(q + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), "hb_wood", yaw)
					for j in range(r2.randi_range(3, 5)):
						for sx in [-0.28, 0.28]:
							geo.box(q + bs * Vector3(sx, 0.14 + 0.15 + j * 0.3, 0), Vector3(0.52, 0.3, 0.8), "hb_sack", yaw + r2.randf_range(-0.08, 0.08))
				2: # empty pallets piled up
					for j in range(r2.randi_range(3, 6)):
						geo.box(q + Vector3(0, 0.07 + j * 0.14, 0), Vector3(1.2, 0.14, 1.0), "hb_wood", yaw + r2.randf_range(-0.08, 0.08))
				3: # barrels, upright
					for o in [Vector3(0, 0, 0), Vector3(0.85, 0, 0.1), Vector3(0.4, 0, 0.8), Vector3(-0.4, 0, 0.75)]:
						if o != Vector3.ZERO and r2.randf() < 0.3:
							continue
						var bq: Vector3 = q + bs * o
						geo.cylinder(bq, bq + Vector3(0, 1.0, 0), 0.38, "hb_wood", 10)
						geo.cylinder(bq + Vector3(0, 0.25, 0), bq + Vector3(0, 0.3, 0), 0.4, "steel", 10)
						geo.cylinder(bq + Vector3(0, 0.7, 0), bq + Vector3(0, 0.75, 0), 0.4, "steel", 10)
				4: # a hoist drum on two timber cheeks
					geo.box(q + Vector3(0, 0.06, 0), Vector3(2.4, 0.12, 0.8), "hb_wood", yaw)
					for sx in [-0.95, 0.95]:
						geo.box(q + bs * Vector3(sx, 0.7, 0), Vector3(0.25, 1.2, 0.5), "hb_wood", yaw)
					geo.cylinder(q + bs * Vector3(-1.0, 0.8, 0), q + bs * Vector3(1.0, 0.8, 0), 0.35, "steel", 12)
					geo.cylinder(q + bs * Vector3(1.0, 0.8, 0), q + bs * Vector3(1.5, 0.8, 0), 0.07, "in_steel", 6)
					geo.box(q + bs * Vector3(1.5, 0.8, 0), Vector3(0.08, 0.5, 0.08), "in_steel", yaw)
				5: # an old sack scale
					geo.box(q + Vector3(0, 0.05, 0), Vector3(0.8, 0.1, 0.6), "in_steel", yaw)
					geo.box(q + Vector3(0, 0.7, 0), Vector3(0.12, 1.2, 0.12), "in_steel", yaw)
					geo.box(q + bs * Vector3(0, 1.3, 0), Vector3(0.9, 0.08, 0.1), "in_steel", yaw)
					geo.box(q + bs * Vector3(0.4, 0.12, 0), Vector3(0.7, 0.04, 0.5), "steel", yaw)
				6: # a hand cart with a few sacks
					for wz in [-0.4, 0.4]:
						for wx in [-0.6, 0.6]:
							var wq: Vector3 = q + bs * Vector3(wx, 0.25, wz)
							geo.cylinder(wq - bs * Vector3(0, 0, 0.05), wq + bs * Vector3(0, 0, 0.05), 0.25, "in_steel", 10)
					geo.box(q + Vector3(0, 0.5, 0), Vector3(1.6, 0.1, 0.8), "hb_wood", yaw)
					geo.box(q + bs * Vector3(-1.0, 0.8, 0), Vector3(0.7, 0.05, 0.1), "in_steel", yaw)
					geo.box(q + bs * Vector3(-0.7, 0.75, 0), Vector3(0.06, 0.55, 0.7), "in_steel", yaw)
					for j in range(r2.randi_range(1, 3)):
						geo.box(q + bs * Vector3(0.2, 0.55 + 0.15 + j * 0.3, 0), Vector3(0.9, 0.3, 0.6), "hb_sack", yaw)
				7: # a belt conveyor section
					for sz in [-0.3, 0.3]:
						geo.box(q + bs * Vector3(0, 0.8, sz), Vector3(4.0, 0.15, 0.1), "in_steel", yaw)
					for lx in [-1.8, 1.8]:
						for sz in [-0.3, 0.3]:
							geo.box(q + bs * Vector3(lx, 0.36, sz), Vector3(0.1, 0.72, 0.1), "in_steel", yaw)
					geo.box(q + bs * Vector3(0, 0.84, 0), Vector3(4.0, 0.06, 0.5), "steel", yaw)
					for lx in [-1.8, 1.8]:
						geo.box(q + bs * Vector3(lx, 0.1, 0), Vector3(0.1, 0.06, 0.7), "in_steel", yaw)
				8: # a fallen crate with its lid and a broken slat
					geo.box(q + Vector3(0, 0.3, 0), Vector3(1.1, 0.6, 0.8), "hb_wood", yaw)
					geo.box(q + bs * Vector3(0.8, 0.03, 0.4), Vector3(0.9, 0.06, 0.6), "hb_wood", yaw + 0.5)
					geo.box(q + bs * Vector3(-0.2, 0.03, -0.9), Vector3(1.0, 0.06, 0.12), "hb_wood", yaw - 0.3)
	# Third pass (own dice): density and height. Racks along the back and end
	# walls, crate towers in clusters, a big sack pile. Same keep-clear rules.
	var r3 := RandomNumberGenerator.new()
	r3.seed = 9090
	var p3: Array = [[], [], [], []]
	var can_put := func(f: int, dx: float, dz: float, rx: float, rz: float, lim_x: float, lim_z: float) -> bool:
		if absf(dx) - rx < 6.2 or absf(dx) + rx > lim_x or absf(dz) + rz > lim_z:
			return false
		if absf(dx) + rx > 26.8 and absf(dx) - rx < 37.2:
			return false
		if dz - rz < 2.5 and dz + rz > -2.5:
			return false
		var rect := Rect2(dx - rx, dz - rz, 2.0 * rx, 2.0 * rz)
		for ppx in range(-40, 41, 10):
			for ppz in [-7.0, 7.0]:
				var qx: float = clampf(ppx, rect.position.x, rect.end.x)
				var qz: float = clampf(ppz, rect.position.y, rect.end.y)
				if Vector2(qx - ppx, qz - ppz).length() < 0.8:
					return false
		if f == 2 and Vector2(c.x + dx + 386.0, c.z + dz + 186.0).length() < maxf(rx, rz) + 3.0:
			return false
		if f == 3 and dx - rx < -39.5 and dz - rz < -9.5:
			return false
		var grown: Rect2 = rect.grow(0.3)
		for o in r2_rects[f]:
			if grown.intersects(o):
				return false
		for o in p3[f]:
			if grown.intersects(o):
				return false
		return true
	var build_rack := func(base: Vector3, yaw: float, bays: int) -> void:
		var bs := Basis(Vector3.UP, yaw)
		var ln: float = bays * 2.7
		geo.tint = Color(0.22, 0.36, 0.6)
		for i in range(bays + 1):
			for sz in [-0.5, 0.5]:
				geo.box(base + bs * Vector3(-ln * 0.5 + i * 2.7, 1.775, sz), Vector3(0.1, 3.55, 0.1), "in_steel", yaw)
		geo.tint = Color(0.85, 0.45, 0.12)
		for i in range(bays):
			for ly in [1.35, 2.55]:
				for sz in [-0.5, 0.5]:
					geo.box(base + bs * Vector3(-ln * 0.5 + 1.35 + i * 2.7, ly, sz), Vector3(2.7, 0.12, 0.08), "in_paint", yaw)
		geo.tint = Color.WHITE
		for i in range(bays):
			for sx in [-0.65, 0.65]:
				for lv in range(3):
					if r3.randf() < 0.12:
						continue
					var py: float = 0.07 if lv == 0 else [0.0, 1.35, 2.55][lv] + 0.13
					var lx: float = -ln * 0.5 + 1.35 + i * 2.7 + sx
					geo.box(base + bs * Vector3(lx, py, 0), Vector3(1.2, 0.14, 1.0), "hb_wood", yaw)
					var top: float = py + 0.07
					var hmax: float = [1.0, 0.9, 0.75][lv]
					if r3.randf() < 0.5:
						var h: float = hmax - r3.randf_range(0.05, 0.25)
						geo.box(base + bs * Vector3(lx + r3.randf_range(-0.04, 0.04), top + h * 0.5, 0), Vector3(1.05, h, 0.85), "hb_wood", yaw + r3.randf_range(-0.05, 0.05))
					else:
						for j in range(int(hmax / 0.3 + 0.01)):
							for sk in [-0.26, 0.26]:
								geo.box(base + bs * Vector3(lx + sk, top + 0.15 + j * 0.3, 0), Vector3(0.5, 0.3, 0.8), "hb_sack", yaw + r3.randf_range(-0.05, 0.05))
	for f in range(4):
		var fy3: float = floors[f]
		# Racks on the back wall (inner face at dz = -14.4).
		var got: int = 0
		for tr in range(40):
			if got >= (2 if f % 2 == 0 else 1):
				break
			var mag3: float = r3.randf_range(9.1, 23.9) if r3.randf() < 0.65 else r3.randf_range(40.2, 41.5)
			var dx3: float = mag3 * (1.0 if r3.randf() < 0.5 else -1.0)
			if can_put.call(f, dx3, -13.8, 2.9, 0.6, 44.45, 14.45):
				p3[f].append(Rect2(dx3 - 2.9, -13.8 - 0.6, 5.8, 1.2))
				build_rack.call(Vector3(c.x + dx3, fy3, c.z - 13.8), 0.0, 2)
				got += 1
		# One rack on an end wall.
		for tr in range(30):
			var sd: float = 1.0 if r3.randf() < 0.5 else -1.0
			var dz3: float = r3.randf_range(4.1, 12.9) * (1.0 if r3.randf() < 0.5 else -1.0)
			if can_put.call(f, sd * 43.8, dz3, 0.6, 1.5, 44.45, 14.45):
				p3[f].append(Rect2(sd * 43.8 - 0.6, dz3 - 1.5, 1.2, 3.0))
				build_rack.call(Vector3(c.x + sd * 43.8, fy3, c.z + dz3), -PI * 0.5 * sd, 1)
				break
		# Crate-tower clusters.
		for cl in range(r3.randi_range(5, 6)):
			var cdx: float = (r3.randf_range(8.0, 25.0) if r3.randf() < 0.6 else r3.randf_range(38.5, 42.5)) * (1.0 if r3.randf() < 0.5 else -1.0)
			var cdz: float = r3.randf_range(4.5, 12.5) * (1.0 if r3.randf() < 0.5 else -1.0)
			var nt: int = r3.randi_range(3, 6)
			var made_t: int = 0
			for k in range(nt * 5):
				if made_t >= nt:
					break
				var tdx: float = cdx + r3.randf_range(-3.2, 3.2)
				var tdz: float = cdz + r3.randf_range(-2.8, 2.8)
				var tw: float = r3.randf_range(0.9, 1.2)
				var td: float = r3.randf_range(0.9, 1.2)
				var rr: float = 0.5 * sqrt(tw * tw + td * td) + 0.05
				if not can_put.call(f, tdx, tdz, rr, rr, 44.2, 13.9):
					continue
				p3[f].append(Rect2(tdx - rr, tdz - rr, 2.0 * rr, 2.0 * rr))
				made_t += 1
				var tall: float = r3.randf_range(2.0, 3.3)
				var nn: int = maxi(2, int(round(tall / 0.9)))
				var yaw_t: float = r3.randf_range(-PI, PI)
				var ycur: float = fy3
				var g: float = r3.randf_range(0.8, 1.05)
				geo.tint = Color(g, g, g)
				for j in range(nn):
					var h: float = tall / nn * r3.randf_range(0.9, 1.1)
					geo.box(Vector3(c.x + tdx + r3.randf_range(-0.05, 0.05), ycur + h * 0.5, c.z + tdz + r3.randf_range(-0.05, 0.05)), Vector3(tw, h, td), "hb_wood", yaw_t + r3.randf_range(-0.2, 0.2))
					ycur += h
					tw = maxf(0.75, tw * r3.randf_range(0.9, 1.0))
					td = maxf(0.75, td * r3.randf_range(0.9, 1.0))
				geo.tint = Color.WHITE
		# A big pile of sacks on 2-3 pallets.
		var np: int = r3.randi_range(2, 3)
		var prr: float = sqrt(pow(np * 0.625, 2.0) + 0.25) + 0.05
		for tr in range(40):
			var pdx: float = (r3.randf_range(8.0 + prr, 25.0) if r3.randf() < 0.6 else r3.randf_range(38.5, 42.5)) * (1.0 if r3.randf() < 0.5 else -1.0)
			var pdz: float = r3.randf_range(4.5, 12.5) * (1.0 if r3.randf() < 0.5 else -1.0)
			if not can_put.call(f, pdx, pdz, prr, prr, 44.2, 13.9):
				continue
			p3[f].append(Rect2(pdx - prr, pdz - prr, 2.0 * prr, 2.0 * prr))
			var pyaw: float = r3.randf_range(-PI, PI)
			var pb := Basis(Vector3.UP, pyaw)
			var pq := Vector3(c.x + pdx, fy3, c.z + pdz)
			for i in range(np):
				geo.box(pq + pb * Vector3((i - (np - 1) * 0.5) * 1.25, 0.07, 0), Vector3(1.2, 0.14, 1.0), "hb_wood", pyaw)
			for j in range(np + 3):
				var cnt: int = 2 * np - (j + 1) / 2
				for i in range(cnt):
					geo.box(pq + pb * Vector3((i - (cnt - 1) * 0.5) * 0.53, 0.14 + 0.15 + j * 0.3, 0), Vector3(0.52, 0.3, 0.8), "hb_sack", pyaw + r3.randf_range(-0.04, 0.04))
			break
	# The gnome's pallet (GNOMES[0]): on the second floor.
	geo.box(Vector3(-386.0, floors[2] + 0.07, -186.0), Vector3(1.2, 0.14, 1.0), "hb_wood")
	geo.box(Vector3(-386.0, floors[2] + 0.14 + 0.6, -186.0), Vector3(1.0, 1.2, 0.8), "hb_wood")
	# The toilet: top floor, north-west corner, a partition in front.
	var tx: float = c.x - L * 0.5 + t + 1.6
	geo.box(Vector3(tx + 1.4, floors[3] + 1.2, c.z - B * 0.5 + t + 1.1), Vector3(0.08, 2.4, 2.2), "hb_wood")
	ToiletCreator.build(geo, Transform3D(Basis(), Vector3(tx, floors[3], c.z - B * 0.5 + t)), r, {"floater": "random"})

## The fish market by the basin: an open hall (cast-iron columns, a
## glazed ridge roof), rows of stalls under it, crates stacked about.
func _fish_market(fm: Vector3) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	geo.box(fm + Vector3(0, 0.1, 0), Vector3(40, 0.2, 80), "sandstone")
	for x in [-19.0, 19.0]:
		for z in range(-40, 41, 8):
			geo.cylinder(fm + Vector3(x, 0.2, z), fm + Vector3(x, 9.0, z), 0.3, "crane", 8)
	for z in range(-40, 41, 8):
		geo.beam(fm + Vector3(-19, 9.0, z), fm + Vector3(0, 13.0, z), Vector2(0.3, 0.5), "crane")
		geo.beam(fm + Vector3(0, 13.0, z), fm + Vector3(19, 9.0, z), Vector2(0.3, 0.5), "crane")
	for s2 in [-1.0, 1.0]:
		geo.beam(fm + Vector3(s2 * 19.0, 9.0, -40), fm + Vector3(s2 * 19.0, 9.0, 40), Vector2(0.4, 0.6), "crane")
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s2 * 0.21), fm + Vector3(s2 * 13.0, 11.2, 0)), Vector3(12.5, 0.3, 82), "crane_red")
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s2 * 0.21), fm + Vector3(s2 * 3.4, 13.2, 0)), Vector3(7.0, 0.1, 82), "shed_glass", false, false)
	for row in [-9.0, 9.0]:
		for z in range(-34, 35, 6):
			var q: Vector3 = fm + Vector3(row, 0.2, z)
			geo.box(q + Vector3(0, 0.45, 0), Vector3(2.0, 0.9, 4.6), "white")
			geo.box(q + Vector3(0, 0.93, 0), Vector3(1.9, 0.06, 4.4), "steel", 0.0, false, false)
			geo.box(q + Vector3(0, 2.3, 0), Vector3(2.4, 0.06, 5.0), ["c_red", "c_blue", "c_green", "c_white"][r.randi() % 4], 0.0, false, false)
			for sz in [-2.2, 2.2]:
				geo.box(q + Vector3(row * 0.1, 1.2, sz), Vector3(0.06, 2.1, 0.06), "steel", 0.0, true, false)
	# Crate stacks (the gnome's on the one at the south-west).
	for k in range(6):
		var q: Vector3 = fm + Vector3(-12.0 + (k % 2) * 24.0, 0.2, -24.0 + (k / 2) * 24.0)
		for j in range(3):
			geo.box(q + Vector3(0, 0.2 + j * 0.4, 0), Vector3(1.1, 0.4, 0.8), "hb_wood")

## An IndustryCreator hall lying along x at c (floor middle), docks on
## its south (+z) side, the open roller door at the east end; `trucks`
## "box" | "semi" | "" backs lorries up to some of the docks. Own dice
## per hall (seeded from its place), so the map's rng runs as before.
func _port_hall(c: Vector3, L: float, B: float, H: float, n_docks: int, opts: Dictionary, trucks: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(c.x * 31.0 + c.z * 7.0)
	# Local z (length) = world -x, local +x (the docks) = world +z.
	var xf := Transform3D(Basis(Vector3.UP, -PI * 0.5), c)
	var o: Dictionary = opts.duplicate()
	o["docks"] = n_docks
	IndustryCreator.hall(geo, xf, L, B, H, r, o)
	if trucks == "":
		return
	for d: Vector3 in IndustryCreator.docks(xf, L, B, n_docks):
		if r.randf() < 0.6:
			if trucks == "semi":
				Vehicles.semi(geo, d + Vector3(0, 0.02, 8.4), PI, Vehicles.random_paint(r), "veh_trailer")
			else:
				Vehicles.box_truck(geo, d + Vector3(0, 0.02, 4.6), PI, Vehicles.random_paint(r))
