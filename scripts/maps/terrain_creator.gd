class_name TerrainCreator
extends RefCounted

## Creator: the land a map stands on - rolling countryside, hills or a
## valley from a seed, levelled wherever the map builds (house plots,
## streets, fields), with ponds, ground colours (lush hollows, dry
## crowns, bare earth on steep banks) and woods for TreeCreator.
##
##   var land := TerrainCreator.make(seed, "rolling")
##   land.flat_rect(Rect2(...), 0.0)            # plots, squares: level ground
##   land.flat_line(a, b, half_width, 0.0)      # a street running on into the fog
##   land.pond(Vector2(x, z), radius)
##   RiverCreator.plan(land, ...)               # rivers carve their channel and valley
##   RoadCreator.plan(land, ...)                # roads cut/fill to their grade, bridge the rivers
##   land.build(map, geo, Rect2(...))           # mesh, collision, horizon ring, pond water
##   (then the rivers' and roads' draw())
##   trees += land.woods(rng, Rect2(...))       # [pos, species, seed] for TreeCreator.plant
##   land.ground(x, z)                          # ground height (cached grid after build)
##
## The first flat area also sets the land's datum: the hills are shifted
## so the natural ground there is at its level, and the levelled areas
## blend in over `blend` metres instead of sitting in a pit or on a
## plinth. Ponds take their water level from the ground round them.

const STYLES := {
	# amp: hill height (m, crest to hollow); freq: hills per metre; ridge:
	# share of sharp crests; rise: valley sides climbing away from the
	# first flat area (m at 600 m out).
	"rolling": {"amp": 30.0, "freq": 0.0032, "ridge": 0.0, "rise": 0.0},
	# For designed maps: a light undulation under the landforms the map
	# places itself (hill, hollow, valley).
	"gentle": {"amp": 6.0, "freq": 0.0035, "ridge": 0.0, "rise": 0.0},
	"hills": {"amp": 70.0, "freq": 0.0026, "ridge": 0.45, "rise": 0.0},
	"valley": {"amp": 22.0, "freq": 0.0036, "ridge": 0.3, "rise": 110.0},
}
## Woods: tree spacing inside a wood (m), and which share of the land is wooded.
const WOOD_STEP: float = 8.5
const WOOD_SHARE: float = 0.22
## Chance per wood tree of a lost drone / kite in it.
const WOOD_DRONE: float = 0.001
const WOOD_KITE: float = 0.001
## Wood species mix (TreeCreator names) and the share of lone field trees.
const WOOD_MIX := ["maple", "maple", "maple", "birch", "spruce", "spruce"]
const FIELD_TREES := ["maple", "apple", "maple", "birch"]

var style: Dictionary
var _hills := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _wood := FastNoiseLite.new()
var _flats: Array = [] # [kind "rect"/"line", data..., y, blend]
var _ponds: Array = [] # [centre: Vector2, r: float, water_y: float, depth: float]
var _datum: float = 0.0
var _has_datum: bool = false
var _axis_a := Vector2.ZERO
var _axis_b := Vector2(1, 0)

static func make(seed_value: int, style_name: String = "rolling") -> TerrainCreator:
	var t := TerrainCreator.new()
	t.style = STYLES.get(style_name, STYLES.rolling)
	t._hills.seed = seed_value
	t._hills.frequency = t.style.freq
	t._hills.fractal_octaves = 4
	t._fine.seed = seed_value + 1
	t._fine.frequency = 0.035
	t._fine.fractal_octaves = 2
	t._patch.seed = seed_value + 2
	t._patch.frequency = 0.006
	t._patch.fractal_octaves = 3
	t._wood.seed = seed_value + 3
	t._wood.frequency = 0.0036
	t._wood.fractal_octaves = 3
	return t

## The area build() will cover in detail, and its grid spacing - set it
## before planning roads (they follow the coarse horizon terrain past
## it, and their flat bed is sized to the grid). build() sets it too.
func set_extent(rect: Rect2, spacing: float = 8.0) -> void:
	_rect = rect
	_step = spacing

## Level round area (a house plot on a curved street), centre c, radius r.
func flat_circle(c: Vector2, r: float, y: float = 0.0, blend: float = 15.0) -> void:
	_set_datum(c, c + Vector2(1, 0))
	_flats.append(["circle", c, r, y, blend, Rect2(c - Vector2.ONE * (r + blend), Vector2.ONE * (r + blend) * 2.0)])

## Level oriented rectangle (a house plot along a curved street):
## centre c, `along` = unit direction of its x side, half sizes hx, hz.
## `real`: [centre, hx, hz] of the plot itself inside that levelled
## area - its ground then belongs to the plot alone: no later levelled
## area and no road's earthworks change it (the area round it, e.g. a
## grid cell's margin so no terrain triangle lifts the plot's edge,
## stays soft).
func flat_plot(c: Vector2, along: Vector2, hx: float, hz: float, y: float, blend: float = 10.0, real: Array = []) -> void:
	_set_datum(c, c + along)
	var reach: float = Vector2(hx, hz).length() + blend
	var rl: Array = real if not real.is_empty() else [c, hx, hz]
	_flats.append(["orect", c, along.normalized(), hx, hz, y, blend, rl[0], rl[1], rl[2], Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0)])

## Somewhere woods don't grow (a village, a field); with `no_plots`
## VillageKit keeps plots out too (a green, a square).
func keep_clear(c: Vector2, r: float, no_plots: bool = false) -> void:
	_clear.append([c, r, "keep_plots_out" if no_plots else ""])

var _clear: Array = []

## A polygon (x, z points) no wood or meadow tree grows in - a field.
func keep_clear_poly(pts: PackedVector2Array) -> void:
	_clear_polys.append(pts)

var _clear_polys: Array = []

## Level ground over a rectangle at height y, easing into the land over `blend` m.
func flat_rect(r: Rect2, y: float = 0.0, blend: float = 40.0) -> void:
	_set_datum(r.get_center(), r.get_center() + Vector2(r.size.x, 0) if r.size.x >= r.size.y else r.get_center() + Vector2(0, r.size.y))
	_flats.append(["rect", r, y, blend, r.grow(blend)])

## Level strip along a to b (a road): flat within `half`, easing out over `blend`.
func flat_line(a: Vector2, b: Vector2, half: float, y: float = 0.0, blend: float = 70.0) -> void:
	_set_datum((a + b) * 0.5, b)
	_flats.append(["line", a, b, half, y, blend, Rect2(a, Vector2.ZERO).expand(b).grow(half + blend)])

## A pond: a round basin; its water level is settled when the land is
## built (a little under the lowest ground round it - the finished
## ground, after every levelled area, so it can't end up standing above
## land that was levelled later). It draws its own shore.
func pond(c: Vector2, r: float, depth: float = 2.2) -> void:
	_ponds.append([c, r, NAN, depth])

func _resolve_ponds() -> void:
	for pd: Array in _ponds:
		var low: float = INF
		for i in range(32):
			var a: float = TAU * i / 32.0
			var q: Vector2 = (pd[0] as Vector2) + Vector2(cos(a), sin(a)) * pd[1] * POND_RING
			low = minf(low, staged(q.x, q.y, FLATS))
		pd[2] = low - 0.4

## Designed landforms, added to the natural ground: a rounded hill
## (height h, radius r), a hollow (the same, downward), a valley along
## a-b (depth, half width - its floor is flat for a third of that).
## Add landforms before planning rivers and roads (the land is read then).
func hill(c: Vector2, r: float, h: float) -> void:
	_forms.append(["round", c, r, h])

func hollow(c: Vector2, r: float, depth: float) -> void:
	_forms.append(["round", c, r, -depth])

func valley(a: Vector2, b: Vector2, half_width: float, depth: float) -> void:
	_forms.append(["valley", a, b, half_width, depth])

var _forms: Array = []

## Pond shore: out to POND_RING x radius the pond's own banks lie on top.
const POND_RING: float = 1.6

## The first levelled area is the land's datum: the natural ground
## there becomes height 0 - noise AND landforms, so the datum is taken
## when the land is first read (landforms added after the first flat
## must count, else the levelled area sits on a terrace above them).
func _set_datum(at: Vector2, toward: Vector2) -> void:
	if _has_datum:
		return
	_datum_at = at
	_axis_a = at
	_axis_b = toward
	_has_datum = true
	_datum_pending = true

var _datum_at := Vector2.ZERO
var _datum_pending: bool = false

func _forms_at(p: Vector2) -> float:
	var h: float = 0.0
	for f: Array in _forms:
		if f[0] == "round":
			h += f[3] * (1.0 - smoothstep(0.0, f[2], p.distance_to(f[1])))
		else:
			var d: float = Geometry2D.get_closest_point_to_segment(p, f[1], f[2]).distance_to(p)
			h -= f[4] * (1.0 - smoothstep(f[3] * 0.33, f[3], d))
	return h

## Natural ground: noise hills (+ crests, + valley sides), zeroed at the datum.
func _raw(x: float, z: float) -> float:
	var n: float = _hills.get_noise_2d(x, z)
	var h: float = style.amp * clampf(n * 0.85 + 0.5, 0.0, 1.0)
	if style.ridge > 0.0:
		var r: float = 1.0 - absf(_hills.get_noise_2d(z * 0.7 + 311.0, x * 0.7))
		h += style.amp * style.ridge * r * r * 1.5
	if style.rise > 0.0:
		var d: float = absf(Geometry2D.get_closest_point_to_segment_uncapped(Vector2(x, z), _axis_a, _axis_b).distance_to(Vector2(x, z)))
		h += style.rise * smoothstep(70.0, 600.0, d)
	return h + _fine.get_noise_2d(x, z) * 0.45

## Natural ground: the noise land plus the designed landforms, zeroed at the datum.
func _land(x: float, z: float) -> float:
	if _datum_pending:
		_datum_pending = false
		_datum = _raw(_datum_at.x, _datum_at.y) + _forms_at(_datum_at)
	var h: float = _raw(x, z) - _datum
	if _forms.is_empty():
		return h
	return h + _forms_at(Vector2(x, z))

## The finished ground: everything below, in order.
func height(x: float, z: float) -> float:
	return staged(x, z, ROADS)

## Build stages - later ones see the ground the earlier ones left:
## the natural land (noise + landforms), + rivers (channel and valley),
## + level areas (village, plots, squares), + ponds (their level from
## the levelled ground), + roads (cut and fill to their grade).
enum { NATURAL, RIVERS, FLATS, PONDS, ROADS }

## Ground up to and including `stage` (creators plan against the stage
## before their own: a river against NATURAL, a road against FLATS).
func staged(x: float, z: float, stage: int, gi: int = -1) -> float:
	var h: float = _land(x, z)
	if stage < RIVERS:
		return h
	var p := Vector2(x, z)
	var channels: Array = [] # rivers this point is in reach of: [nearest, line]
	for li in range(rivers.size()):
		var l: LandLine = rivers[li]
		var n: Array = _near(l, li, p, gi)
		if n.is_empty():
			continue
		h = _river_carve(h, n[0], n[1], l)
		channels.append([n, l])
	if stage < FLATS:
		return h
	var in_plot: bool = false # inside a levelled plot: it belongs to the house
	for f: Array in _flats:
		if in_plot:
			break # claimed by a plot: nothing later changes it
		if not (f[-1] as Rect2).has_point(p):
			continue # out of its reach (bounding box): it can't change h
		var d: float
		var y: float
		var blend: float
		if f[0] == "rect":
			var r: Rect2 = f[1]
			var dx: float = maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
			var dz: float = maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
			d = sqrt(dx * dx + dz * dz)
			y = f[2]
			blend = f[3]
		elif f[0] == "circle":
			d = maxf(p.distance_to(f[1]) - f[2], 0.0)
			if d >= f[4]:
				continue
			y = f[3]
			blend = f[4]
		elif f[0] == "orect":
			d = _orect_dist(p, f)
			if d >= f[6]:
				continue
			y = f[5]
			blend = f[6]
			if _orect_dist(p, ["", f[7], f[2], f[8], f[9]]) <= 0.0:
				in_plot = true
		else:
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, f[1], f[2])
			d = maxf(q.distance_to(p) - f[3], 0.0)
			y = f[4]
			blend = f[5]
		if d < blend:
			h = lerpf(y, h, smoothstep(0.0, blend, d))
	if stage < PONDS:
		return h
	for pd: Array in _ponds:
		var wy: float = pd[2]
		if is_nan(wy):
			continue # not settled yet (planning before build)
		var d: float = p.distance_to(pd[0])
		var r: float = pd[1]
		if d < r:
			h = minf(h, wy - 0.3 - pd[3] * (1.0 - (d / r) * (d / r)))
		elif d < r * (POND_RING - 0.05):
			h = minf(h, wy - 0.5) # under the pond's own shore
		elif d < r * (POND_RING + 0.8):
			h = minf(h, lerpf(wy + 0.4, h, smoothstep(r * (POND_RING - 0.05), r * (POND_RING + 0.8), d)))
	if stage < ROADS:
		return h
	# Where roads come close (a junction, two roads side by side) the
	# NEAREST one shapes the ground - applying them one after the other
	# let a side road's bed bury the main road it leaves.
	var best: Array = []
	var best_edge: float = INF
	var best_l: LandLine = null
	for li in range(roads.size()):
		var l: LandLine = roads[li]
		var n: Array = _near(l, rivers.size() + li, p, gi)
		if n.is_empty():
			continue
		# A railway viaduct (RailCreator) stands on its piers: the land
		# under it is shaped by whatever else is there (a road under its
		# arches keeps its bed). Road bridges keep their old rule.
		if l.kind == "rail" and l.bridge[n[2]] == 1:
			continue
		var edge: float = n[0] - l.half
		if edge < best_edge:
			best_edge = edge
			best = n
			best_l = l
	# Under a bridge the river's ground stays; inside a plot the plot's
	# level stays (a road climbing past it would re-shape its garden and
	# leave fences and trees in the air - its earthworks stop at the plot).
	if best_l != null and best_l.bridge[best[2]] == 0 and not in_plot:
		# Flat bed a few cm under the road surface, wide enough that every
		# grid triangle touching the road has all its corners on it (a
		# narrower bed let triangles from the hillside bite into the road's
		# edge), then cut or fill easing back into the land.
		var core: float = best_l.half + road_bed()
		h = lerpf(best[1] - ROAD_SINK, h, smoothstep(core, core + ROAD_SLOPE, best[0]))
	# A road never dams a river: its fill stops at the channel (the bridge
	# spans it), so the channel and its banks are carved again on top.
	# And out to the river's grass banks (RiverCreator draws them landing
	# on the terrain GRASS_OUT past the water): a levelled area (the
	# village) or a grid triangle reaching from a filled point buried
	# them - except under a road's own bed (its approach to the bridge).
	for ch: Array in channels:
		var n: Array = ch[0]
		var l: LandLine = ch[1]
		if n[0] < l.half + BANK + 2.0 or (n[0] < l.half + RiverCreator.GRASS_OUT + 2.0 and best_edge > road_bed() and not in_plot):
			h = _river_carve(h, n[0], n[1], l)
	return h

## Nearest point of line l to p: from the stamped grid cache when p is
## grid point gi (during build), else searched.
func _near(l: LandLine, li: int, p: Vector2, gi: int) -> Array:
	if gi < 0 or _stamps.is_empty():
		return l.nearest(p)
	var st: Array = _stamps[li]
	var d: float = (st[0] as PackedFloat32Array)[gi]
	if d == INF:
		return []
	var seg: int = (st[2] as PackedInt32Array)[gi]
	return [d, (st[1] as PackedFloat32Array)[gi], seg, 0.0]

## Per line: [distance, level, segment] for every grid point in reach,
## filled segment by segment (each touches only the points round it).
var _stamps: Array = []

func _stamp_lines(rect: Rect2, spacing: float) -> void:
	_stamps.clear()
	var count: int = _nx * _nz
	for l: LandLine in rivers + roads:
		var dist := PackedFloat32Array()
		dist.resize(count)
		dist.fill(INF)
		var lev := PackedFloat32Array()
		lev.resize(count)
		var segs := PackedInt32Array()
		segs.resize(count)
		var r: float = l.half + l.reach
		for i in range(l.pts.size() - 1):
			var a := Vector2(l.pts[i].x, l.pts[i].z)
			var b := Vector2(l.pts[i + 1].x, l.pts[i + 1].z)
			var ab: float = a.distance_to(b)
			var x0: int = maxi(0, floori((minf(a.x, b.x) - r - rect.position.x) / spacing))
			var x1: int = mini(_nx - 1, ceili((maxf(a.x, b.x) + r - rect.position.x) / spacing))
			var z0: int = maxi(0, floori((minf(a.y, b.y) - r - rect.position.y) / spacing))
			var z1: int = mini(_nz - 1, ceili((maxf(a.y, b.y) + r - rect.position.y) / spacing))
			for iz in range(z0, z1 + 1):
				for ix in range(x0, x1 + 1):
					var p := Vector2(rect.position.x + ix * spacing, rect.position.y + iz * spacing)
					var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
					var d: float = q.distance_to(p)
					var gi: int = iz * _nx + ix
					if d < r and d < dist[gi]:
						dist[gi] = d
						var t: float = q.distance_to(a) / ab if ab > 0.001 else 0.0
						lev[gi] = lerpf(l.pts[i].y, l.pts[i + 1].y, t)
						segs[gi] = i
		_stamps.append([dist, lev, segs])

## River channel: bed below the water; under the river's own bank
## meshes (RiverCreator draws the banks finer than this grid could)
## the ground is kept just below the water; then a valley floor easing
## back into the land. Only ever lowers the ground.
func _river_carve(h: float, d: float, wy: float, l: LandLine) -> float:
	var w: float = l.half
	if d < w:
		return minf(h, wy - 0.35 - l.depth * (1.0 - (d / w) * (d / w)))
	if d < w + BANK + 2.0:
		return minf(h, wy - 0.5)
	var floor_y: float = wy + 0.45 + (d - w - BANK - 2.0) * 0.02
	return minf(h, lerpf(floor_y, h, smoothstep(w + BANK + 2.0, w + BANK + 2.0 + l.valley, d)))

## Half the flat road bed beyond the road's edge: a grid cell's diagonal.
func road_bed() -> float:
	return _step * 1.45

## The ground under a road, below its surface (m) - also the level a plot
## by the road gets, so the grid triangles between the two lie flat.
const ROAD_SINK: float = 0.12

## Width (m) of a road's cut or fill slope past its flat bed.
const ROAD_SLOPE: float = 14.0

## Bank width (m) from the water's edge up to the bank top.
const BANK: float = 3.0

var rivers: Array[LandLine] = []
var roads: Array[LandLine] = []

func add_river(l: LandLine) -> void:
	rivers.append(l)

func add_road(l: LandLine) -> void:
	roads.append(l)

## Is p on a road or in a river (within `margin` of its edge)?
func on_line(x: float, z: float, margin: float) -> bool:
	var p := Vector2(x, z)
	for l: LandLine in rivers + roads:
		var n: Array = l.nearest(p)
		if not n.is_empty() and n[0] < l.half + margin:
			return true
	return false

## How much of the ground at p belongs to a levelled area (1 inside, 0 beyond the blend).
func flatness(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w: float = 0.0
	for f: Array in _flats:
		if not (f[-1] as Rect2).has_point(p):
			continue
		var d: float
		var blend: float
		if f[0] == "rect":
			var r: Rect2 = f[1]
			var dx: float = maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
			var dz: float = maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
			d = sqrt(dx * dx + dz * dz)
			blend = f[3]
		elif f[0] == "circle":
			d = maxf(p.distance_to(f[1]) - f[2], 0.0)
			blend = f[4]
		elif f[0] == "orect":
			d = _orect_dist(p, f)
			blend = f[6]
		else:
			d = maxf(Geometry2D.get_closest_point_to_segment(p, f[1], f[2]).distance_to(p) - f[3], 0.0)
			blend = f[5]
		w = maxf(w, 1.0 - smoothstep(0.0, blend, d))
	return w

## Distance from p to outside an oriented rect flat ["orect", c, along, hx, hz, ...].
static func _orect_dist(p: Vector2, f: Array) -> float:
	var q: Vector2 = p - (f[1] as Vector2)
	var ax: Vector2 = f[2]
	var u: float = absf(q.dot(ax)) - f[3]
	var v: float = absf(q.dot(Vector2(-ax.y, ax.x))) - f[4]
	return Vector2(maxf(u, 0.0), maxf(v, 0.0)).length()

func _cleared(x: float, z: float) -> bool:
	for c: Array in _clear:
		if Vector2(x, z).distance_to(c[0]) < c[1]:
			return true
	for poly: PackedVector2Array in _clear_polys:
		if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
			return true
	return false

func in_pond(x: float, z: float, margin: float = 0.0) -> bool:
	for pd: Array in _ponds:
		if Vector2(x, z).distance_to(pd[0]) < pd[1] * POND_RING + margin:
			return true
	return false

## Ground colour x baked light: grass, lusher in hollows and by water,
## drier on crowns and in sunny patches, bare earth on steep banks,
## pebbles on a pond's shore.
func tint(geo: Geo, n: Vector3, p: Vector3) -> Color:
	var c := Color.WHITE
	var patch: float = _patch.get_noise_2d(p.x, p.z)
	c = c.lerp(Color(1.2, 1.1, 0.72), clampf(patch * 2.2, 0.0, 0.65)) # dry pasture
	c = c.lerp(Color(0.8, 0.93, 0.78), clampf(-patch * 2.2, 0.0, 0.6)) # lush
	var steep: float = 1.0 - n.y
	c = c.lerp(Color(1.05, 0.82, 0.62), smoothstep(0.12, 0.3, steep)) # bare earth
	for pd: Array in _ponds:
		var d: float = Vector2(p.x, p.z).distance_to(pd[0])
		if d < pd[1] * 1.15:
			c = Color(1.15, 1.0, 0.75) # shore
	return geo.shade(n, p.y + 50.0) * c

## Builds the ground: detailed terrain over `rect` (with collision),
## a coarse ring out to the horizon, water on the ponds. Afterwards
## ground() answers from the cached grid (cheap) inside `rect`.
func build(map: Node3D, geo: Geo, rect: Rect2, spacing: float = 8.0) -> void:
	if not geo.has_material("tr_ground"):
		geo.add_material("tr_ground", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
		geo.add_material("tr_water", Geo.water_mat(Color(0.1, 0.27, 0.25), 0.88))
	var t0: int = Time.get_ticks_msec()
	_resolve_ponds()
	_rect = rect
	_step = spacing
	_nx = int(rect.size.x / spacing) + 1
	_nz = int(rect.size.y / spacing) + 1
	_grid.resize(_nx * _nz)
	_stamp_lines(rect, spacing)
	for iz in range(_nz):
		for ix in range(_nx):
			var gi: int = iz * _nx + ix
			_grid[gi] = staged(rect.position.x + ix * spacing, rect.position.y + iz * spacing, ROADS, gi)
	_stamps.clear()
	var t1: int = Time.get_ticks_msec()
	var mat: Material = geo.material("tr_ground")
	var shade := func(n: Vector3, p: Vector3) -> Color: return tint(geo, n, p)
	Terrain.build(map, rect, spacing, ground, mat, shade)
	var t2: int = Time.get_ticks_msec()
	# The horizon ring is FAR_STEP coarse: roads can't show there (they
	# lie on it, see far_ground), rivers' valleys can.
	# Built here rather than with Terrain.far_ring: the same heights
	# far_ground() reports (dips under roads near the edge, river trench).
	Terrain.build(map, rect.grow(FAR_REACH), FAR_STEP, _far_at, mat, shade, 16, false)
	# Everything drawn from here on is shaded against this ground - from
	# the cached grid; out past it (a road running into the haze) no
	# ground darkening at all: computing the ground there per vertex cost
	# seconds, and nobody sees occlusion at a kilometre.
	geo.ground_fn = func(x: float, z: float) -> float: return ground(x, z) if _rect.has_point(Vector2(x, z)) else -1e6
	geo.floor_fn = geo.ground_fn
	if OS.has_environment("SH_PERF"):
		print("TERRAIN heights %d ms, mesh %d ms, horizon ring %d ms" % [t1 - t0, t2 - t1, Time.get_ticks_msec() - t2])
	for pd: Array in _ponds:
		_draw_pond(geo, pd)

## Water, and a shore finer than the 8 m grid could carve: mud just
## above the water, then grass out to POND_RING x radius, landing on the
## terrain there (the ground under it is kept below the water).
func _draw_pond(geo: Geo, pd: Array) -> void:
	if not geo.has_material("tr_mud"):
		geo.add_material("tr_mud", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(0.78, 0.68, 0.55), 2.5, 1, 0.3))
		geo.add_material("tr_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 1, 0.45))
	var c: Vector2 = pd[0]
	var r: float = pd[1]
	var wy: float = pd[2]
	var c3 := Vector3(c.x, wy, c.y)
	geo.light_fn = func(n: Vector3, p: Vector3) -> Color: return geo.shade(n, p.y + 50.0)
	geo.cylinder(c3 + Vector3(0, -0.15, 0), c3, r * 1.08, "tr_water", 48, false)
	var mud: Array = []
	var grass: Array = []
	for k in range(49):
		var a: float = TAU * k / 48.0
		var dv := Vector3(cos(a), 0, sin(a))
		var top: Vector3 = c3 + dv * r * 1.2 + Vector3(0, 0.4, 0)
		mud.append(PackedVector3Array([c3 + dv * r * 0.95 + Vector3(0, -0.3, 0), c3 + dv * r * 1.05 + Vector3(0, 0.12, 0), top]))
		var out: Vector3 = c3 + dv * r * POND_RING
		out.y = ground(out.x, out.z) + 0.03
		grass.append(PackedVector3Array([top, out]))
	geo.light_fn = func(n: Vector3, p: Vector3) -> Color: return geo.shade(n, p.y + 50.0) * Color(1.05, 1.0, 0.9)
	geo.strip(mud, "tr_mud")
	geo.light_fn = func(n: Vector3, p: Vector3) -> Color: return tint(geo, n, p)
	geo.strip(grass, "tr_grass")
	geo.light_fn = Callable()

const FAR_STEP: float = 110.0
const FAR_REACH: float = 5000.0

## Height of the coarse horizon ring's own surface at (x, z) - outside
## the detailed rect, where a road running on into the haze lies on it.
## Mirrors Terrain.far_ring (its grid, its dips under the detailed rect,
## the 10-01 diagonal).
func far_ground(x: float, z: float) -> float:
	var outer: Rect2 = _rect.grow(FAR_REACH)
	var fx: float = (x - outer.position.x) / FAR_STEP
	var fz: float = (z - outer.position.y) / FAR_STEP
	var ix: int = int(fx)
	var iz: int = int(fz)
	var u: float = fx - ix
	var v: float = fz - iz
	var h00: float = _far_vertex(outer, ix, iz)
	var h10: float = _far_vertex(outer, ix + 1, iz)
	var h01: float = _far_vertex(outer, ix, iz + 1)
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	var h11: float = _far_vertex(outer, ix + 1, iz + 1)
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)

## The ring's ground before its dips under the detailed rect.
func _far_natural(x: float, z: float) -> float:
	var h: float = staged(x, z, FLATS)
	# A river running on into the haze: a flat trench along it, so the
	# water laid on the ring (RiverCreator) shows and isn't buried.
	# Every ring vertex within a cell of the river sits under its water,
	# so no ring triangle spans the river from a hillside (the water laid
	# on it would ride over the hills).
	for l: LandLine in rivers:
		h = minf(h, l.lowest_within(Vector2(x, z), FAR_STEP * 1.2) - 0.3)
	return h

func _far_vertex(outer: Rect2, ix: int, iz: int) -> float:
	return _far_at(outer.position.x + ix * FAR_STEP, outer.position.y + iz * FAR_STEP)

## The ring's height at one of its vertices: well under the detailed
## rect inside it, just under it (and under roads/rivers) in the band
## where the two overlap, the land itself outside.
func _far_at(x: float, z: float) -> float:
	var h: float = _far_natural(x, z)
	var p := Vector2(x, z)
	if _rect.grow(-FAR_STEP * 1.5).has_point(p):
		# Well under the detailed ground anywhere its triangles reach: 30 m
		# under the natural land was not enough over a deep gorge (Mountain
		# Lake: the ring lay 16 m over the river, a grass lid seen from the
		# rim - and the grass tufts' capture put tufts on it in mid-air).
		return minf(h - 30.0, _grid_min(p, FAR_STEP) - 5.0)
	if _rect.has_point(p):
		return _far_band(p, h)
	return h

## The lowest detailed ground within r (a square) of p.
func _grid_min(p: Vector2, r: float) -> float:
	var lo: float = INF
	var ix0: int = maxi(0, floori((p.x - r - _rect.position.x) / _step))
	var ix1: int = mini(_nx - 1, ceili((p.x + r - _rect.position.x) / _step))
	var iz0: int = maxi(0, floori((p.y - r - _rect.position.y) / _step))
	var iz1: int = mini(_nz - 1, ceili((p.y + r - _rect.position.y) / _step))
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			lo = minf(lo, _grid[iz * _nx + ix])
	return lo

## A ring vertex in the band where the ring overlaps the detailed rect:
## 1.5 m under the ground, and under any road or river within a ring
## cell - else its 110 m triangles span over a road's cutting and cover
## the road near the edge of the detailed land.
func _far_band(p: Vector2, h: float) -> float:
	var lo: float = h
	for l: LandLine in roads + rivers:
		lo = minf(lo, l.lowest_within(p, FAR_STEP * 1.2) - 0.5)
	return minf(h, lo) - 1.5

## Ground a road at (x, z) lies on: the detailed terrain inside the rect,
## the horizon ring outside.
func visible_ground(x: float, z: float) -> float:
	return ground(x, z) if _rect.has_point(Vector2(x, z)) else far_ground(x, z)

var _grid := PackedFloat32Array()
var _grid_only: bool = false

## The finished ground as plain data, for the map cache (MapCache):
## ground() answers the same inside the built rect; a land restored from
## it (from_grid_state) holds the edge's height outside.
func grid_state() -> Dictionary:
	return {"grid": _grid, "rect": _rect, "step": _step, "nx": _nx, "nz": _nz, "ponds": _ponds}

static func from_grid_state(d: Dictionary) -> TerrainCreator:
	var t := TerrainCreator.new()
	t._grid = d.grid
	t._rect = d.rect
	t._step = d.step
	t._nx = d.nx
	t._nz = d.nz
	t._ponds = d.ponds
	t._grid_only = true
	return t
var _rect := Rect2()
var _step: float = 8.0
var _nx: int = 0
var _nz: int = 0

## Ground height as built: inside the built rect from the cached grid,
## on the mesh's own triangles; elsewhere computed.
func ground(x: float, z: float) -> float:
	var fx: float = (x - _rect.position.x) / _step
	var fz: float = (z - _rect.position.y) / _step
	if _grid.is_empty() or fx < 0.0 or fz < 0.0 or fx >= _nx - 1 or fz >= _nz - 1:
		if _grid_only and not _grid.is_empty(): # restored from the map cache: the edge's height
			fx = clampf(fx, 0.0, _nx - 1.001)
			fz = clampf(fz, 0.0, _nz - 1.001)
		else:
			return height(x, z)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var u: float = fx - ix
	var v: float = fz - iz
	var i: int = iz * _nx + ix
	var h10: float = _grid[i + 1]
	var h01: float = _grid[i + _nx]
	# Terrain (like HeightMapShape3D) splits each cell along the 10-01 diagonal.
	if u + v <= 1.0:
		var h00: float = _grid[i]
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	var h11: float = _grid[i + _nx + 1]
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)

## Trees for the land: woods where the patch noise says so (a tree
## every ~WOOD_STEP m, thinning at the edge), lone trees in the meadows,
## none on levelled areas, in ponds or on steep banks. Returns
## TreeCreator entries; `limit` caps the count (load time).
## areas: designed woods ([centre: Vector2, radius] each, thinning over
## their last 20 m) instead of the noise patches.
func woods(rng: RandomNumberGenerator, rect: Rect2, limit: int = 2500, field_every: float = 70.0, areas: Array = []) -> Array:
	var out: Array = []
	var edge: float = 0.45 - WOOD_SHARE * 1.6 # noise threshold for about the wooded share
	var nx: int = int(rect.size.x / WOOD_STEP)
	var nz: int = int(rect.size.y / WOOD_STEP)
	var field_p: float = (WOOD_STEP * WOOD_STEP) / (field_every * field_every)
	for iz in range(nz):
		for ix in range(nx):
			var x: float = rect.position.x + (ix + rng.randf()) * WOOD_STEP
			var z: float = rect.position.y + (iz + rng.randf()) * WOOD_STEP
			var wood: bool
			if areas.is_empty():
				var m: float = _wood.get_noise_2d(x, z)
				wood = m > edge and rng.randf() < smoothstep(edge, edge + 0.08, m)
			else:
				var inside: float = 0.0
				for ar: Array in areas:
					inside = maxf(inside, 1.0 - smoothstep(ar[1] - 20.0, ar[1], Vector2(x, z).distance_to(ar[0])))
				wood = rng.randf() < inside
			if not wood and rng.randf() > field_p:
				continue
			if flatness(x, z) > 0.02 or in_pond(x, z, 4.0) or on_line(x, z, BANK + 5.0) or _cleared(x, z):
				continue
			var y: float = ground(x, z)
			if absf(ground(x + 2.0, z) - y) + absf(ground(x, z + 2.0) - y) > 1.8:
				continue
			var mix: Array = WOOD_MIX if wood else FIELD_TREES
			# Garden surprises don't belong in a wood - only now and then a
			# drone or a kite lost in it.
			var r: float = rng.randf()
			var extra: String = "drone" if r < WOOD_DRONE else ("kite" if r < WOOD_DRONE + WOOD_KITE else "none")
			out.append([Vector3(x, y - 0.1, z), mix[rng.randi() % mix.size()], rng.randi(), extra, wood])
			if out.size() >= limit:
				return out
	return out
