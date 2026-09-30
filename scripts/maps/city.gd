class_name City
extends RefCounted

## Town and city buildings for the generated maps: European perimeter
## blocks (a ring of separate buildings round a courtyard, each with its
## own height, facade and roof, shops on the ground floor), office
## towers on podiums, parks, car parks, gabled houses, and cheap
## "filler" rows for the far distance so a city fades out instead of
## ending. Trees are collected in `trees` for Forest.plant (one call
## per map). Heights: 3.5 m storeys, facades tiled in 7 m (2 x 2 bays).

var geo: Geo
var rng: RandomNumberGenerator
var fleet: Fleet
var trees: Array = []

const STOREY: float = 3.5
const FACADES := ["cty_plaster", "cty_plaster_warm", "cty_plaster_grey", "cty_brick", "cty_plaster_warm", "cty_plaster"]
## Plaster colours are tints of one material (see Geo.tint).
const PLASTER_TINTS := {"cty_plaster": Color(1.0, 1.0, 1.0), "cty_plaster_warm": Color(1.08, 0.95, 0.78), "cty_plaster_grey": Color(0.82, 0.84, 0.86)}

func _init(g: Geo, r: RandomNumberGenerator, cars: Fleet = null) -> void:
	geo = g
	rng = r
	fleet = cars
	Vehicles.ensure_materials(geo)
	if geo.has_material("cty_plaster"):
		return
	var f: Texture2D = MapTextures.get_tex("facade_b")
	geo.add_material("cty_plaster", Geo.tex_mat(f, Color(1.0, 1.0, 1.0), 7.0))
	geo.add_material("cty_plaster_warm", Geo.tex_mat(f, Color(1.08, 0.95, 0.78), 7.0))
	geo.add_material("cty_plaster_grey", Geo.tex_mat(f, Color(0.82, 0.84, 0.86), 7.0))
	geo.add_material("cty_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.15, 1.05, 1.0), 3.0))
	geo.add_material("cty_shop", Geo.tex_mat(MapTextures.get_tex("shopfront"), Color.WHITE, 7.0))
	geo.add_material("cty_tower", Geo.tex_mat(MapTextures.get_tex("curtain_wall"), Color.WHITE, 3.0))
	geo.add_material("cty_tower_dark", Geo.tex_mat(MapTextures.get_tex("curtain_wall"), Color(0.7, 0.72, 0.75), 3.0))
	geo.add_material("cty_roof", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.85, 0.85, 0.85), 5.0))
	geo.add_material("cty_tiles", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color.WHITE, 2.0))
	geo.add_material("cty_slate", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color(0.45, 0.48, 0.55), 2.0))
	geo.add_material("cty_cornice", Geo.flat_mat(Color(0.86, 0.84, 0.8)))
	geo.add_material("cty_dark", Geo.flat_mat(Color(0.2, 0.21, 0.22)))
	geo.add_material("cty_metal", Geo.flat_mat(Color(0.55, 0.57, 0.6), 0.4, 0.5))
	geo.add_material("cty_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color(1.05, 1.1, 1.0), 6.0, 1, 0.4))
	geo.add_material("cty_path", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(1.1, 1.05, 0.95), 3.0, 2, 0.3))
	geo.add_material("cty_court", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color(0.95, 0.95, 0.95), 3.0, 1, 0.3))
	geo.add_material("cty_lot", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 1, 0.3))
	geo.add_material("cty_bay", Geo.ground_flat(Color(0.85, 0.85, 0.82), 2))
	geo.add_material("cty_water", Geo.water_mat(Color(0.2, 0.36, 0.4), 0.9))

## One building: a box from ground to `floors`, shop fronts on the
## ground floor if `shop`, a cornice, and a roof: "flat" (parapet and
## plant), "mansard", "gable" (ridge along the longer side).
func building(c: Vector3, size: Vector2, yaw: float, floors: int, facade: String, roof: String, shop: bool) -> void:
	var h: float = floors * STOREY
	var b := Basis(Vector3.UP, yaw)
	var old_cell: float = geo.cell
	geo.cell = 128.0
	if PLASTER_TINTS.has(facade):
		var t: Color = PLASTER_TINTS[facade]
		var j: float = rng.randf_range(0.93, 1.05)
		geo.tint = Color(t.r * j, t.g * j * rng.randf_range(0.97, 1.03), t.b * j)
		facade = "cty_plaster"
	if shop:
		geo.box_xf(Transform3D(b, c + Vector3(0, STOREY * 0.5, 0)), Vector3(size.x, STOREY, size.y), "cty_shop")
		geo.box_xf(Transform3D(b, c + Vector3(0, STOREY + (h - STOREY) * 0.5, 0)), Vector3(size.x, h - STOREY, size.y), facade)
	else:
		geo.box_xf(Transform3D(b, c + Vector3(0, h * 0.5, 0)), Vector3(size.x, h, size.y), facade)
	geo.tint = Color.WHITE
	geo.box_xf(Transform3D(b, c + Vector3(0, h + 0.2, 0)), Vector3(size.x + 0.5, 0.4, size.y + 0.5), "cty_cornice", false, false)
	var top: Vector3 = c + Vector3(0, h + 0.4, 0)
	match roof:
		"flat":
			for s in [-1.0, 1.0]:
				geo.box_xf(Transform3D(b, top + b * Vector3(s * (size.x * 0.5 - 0.15), 0.5, 0)), Vector3(0.3, 1.0, size.y), "cty_roof", false, false)
				geo.box_xf(Transform3D(b, top + b * Vector3(0, 0.5, s * (size.y * 0.5 - 0.15))), Vector3(size.x, 1.0, 0.3), "cty_roof", false, false)
			geo.box_xf(Transform3D(b, top + Vector3(0, 0.05, 0)), Vector3(size.x - 0.6, 0.1, size.y - 0.6), "cty_roof", true, false)
			if size.x * size.y > 150.0 and rng.randf() < 0.7:
				geo.box_xf(Transform3D(b, top + b * Vector3(rng.randf_range(-0.2, 0.2) * size.x, 1.2, rng.randf_range(-0.2, 0.2) * size.y)), Vector3(3.0, 2.4, 2.2), "cty_metal")
		"mansard":
			geo.tint = Color(0.5, 0.53, 0.62)
			geo.frustum(Transform3D(b, top + Vector3(0, 1.9, 0)), Vector3(size.x, 3.8, size.y), size.x - 3.0, size.y - 3.0, 0.0, "cty_tiles")
			geo.tint = Color.WHITE
		_:
			var along_x: bool = size.x >= size.y
			var span: float = size.y if along_x else size.x
			var length: float = size.x if along_x else size.y
			var rise: float = span * 0.45
			var pts: Array = []
			for i in range(8):
				var hx: float = length * 0.5 * (1.0 if i & 1 else -1.0)
				var hz: float = span * 0.5 * (1.0 if i & 4 else -1.0)
				var yy: float = 0.0
				if i & 2:
					hz *= 0.02
					yy = rise
				var lp := Vector3(hx, yy, hz) if along_x else Vector3(hz, yy, hx)
				pts.append(top + b * lp)
			var tr: float = rng.randf_range(0.85, 1.05)
			geo.tint = Color(tr, tr * 0.95, tr * 0.95) if roof == "gable" else Color(0.5, 0.53, 0.62)
			geo.hexa(pts, "cty_tiles")
			geo.tint = Color.WHITE
			if rng.randf() < 0.5:
				geo.box_xf(Transform3D(b, top + b * Vector3(size.x * 0.2, rise * 0.7, 0)), Vector3(0.7, rise * 0.9, 0.7), "cty_brick", false, false)
	geo.cell = old_cell

## A European perimeter block filling rect r (ground y): separate
## buildings along all four sides, `depth` deep, courtyard inside
## (paved, a tree or two). Streets are assumed all round (shops face out).
func perimeter_block(r: Rect2, y: float, floors_min: int = 4, floors_max: int = 6, depth: float = 13.0, shops: bool = true) -> void:
	geo.slab(r, y + 0.02, 0.1, "cty_court", false)
	# North and south sides run the full width; east and west between.
	for side in range(4):
		var along: float = r.size.x if side < 2 else r.size.y - 2.0 * depth
		var n: int = maxi(1, int(round(along / rng.randf_range(16.0, 26.0))))
		var seg: float = along / n
		for k in range(n):
			var floors: int = rng.randi_range(floors_min, floors_max)
			var facade: String = FACADES[rng.randi() % FACADES.size()]
			var roof: String = ["flat", "mansard", "gable", "flat", "slate"][rng.randi() % 5]
			var t: float = -along * 0.5 + seg * (k + 0.5)
			var c: Vector3
			var size: Vector2
			match side:
				0:
					c = Vector3(r.position.x + r.size.x * 0.5 + t, y, r.position.y + depth * 0.5)
					size = Vector2(seg - 0.1, depth)
				1:
					c = Vector3(r.position.x + r.size.x * 0.5 + t, y, r.end.y - depth * 0.5)
					size = Vector2(seg - 0.1, depth)
				2:
					c = Vector3(r.position.x + depth * 0.5, y, r.position.y + r.size.y * 0.5 + t)
					size = Vector2(depth, seg - 0.1)
				_:
					c = Vector3(r.end.x - depth * 0.5, y, r.position.y + r.size.y * 0.5 + t)
					size = Vector2(depth, seg - 0.1)
			building(c, size, 0.0, floors, facade, roof, shops and rng.randf() < 0.75)
	var inner: Rect2 = r.grow(-depth - 3.0)
	if inner.size.x > 8.0 and inner.size.y > 8.0:
		for i in range(rng.randi_range(1, 3)):
			trees.append([Vector3(rng.randf_range(inner.position.x, inner.end.x), y, rng.randf_range(inner.position.y, inner.end.y)), 1, rng.randf_range(0.55, 0.85)])

## Office tower on a two-storey podium filling r.
func tower(r: Rect2, y: float, height: float) -> void:
	var c := Vector3(r.get_center().x, y, r.get_center().y)
	geo.slab(r, y + 0.02, 0.1, "cty_court", false)
	geo.box(c + Vector3(0, STOREY, 0), Vector3(r.size.x - 4.0, STOREY * 2.0, r.size.y - 4.0), "cty_shop")
	var tw: Vector2 = Vector2(minf(r.size.x - 16.0, 34.0), minf(r.size.y - 16.0, 30.0))
	geo.box(c + Vector3(0, STOREY * 2.0 + height * 0.5, 0), Vector3(tw.x, height, tw.y), "cty_tower" if rng.randf() < 0.6 else "cty_tower_dark")
	geo.box(c + Vector3(0, STOREY * 2.0 + height + 1.6, 0), Vector3(tw.x - 6.0, 3.2, tw.y - 6.0), "cty_metal")
	geo.box(c + Vector3(0, STOREY * 2.0 + 0.2, 0), Vector3(r.size.x - 3.5, 0.4, r.size.y - 3.5), "cty_cornice", false, false)
	if rng.randf() < 0.5:
		geo.cylinder(c + Vector3(tw.x * 0.25, STOREY * 2.0 + height + 3.2, 0), c + Vector3(tw.x * 0.25, STOREY * 2.0 + height + 15.0, 0), 0.25, "cty_metal", 6)

## A park: lawn, crossing gravel paths, trees, benches, a fountain.
func park(r: Rect2, y: float) -> void:
	geo.slab(r, y + 0.03, 0.1, "cty_grass", false)
	var c: Vector2 = r.get_center()
	geo.slab(Rect2(r.position.x, c.y - 2.0, r.size.x, 4.0), y + 0.04, 0.1, "cty_path", false)
	geo.slab(Rect2(c.x - 2.0, r.position.y, 4.0, r.size.y), y + 0.04, 0.1, "cty_path", false)
	var fc := Vector3(c.x, y, c.y)
	geo.lathe(fc, [Vector2(5.0, 0.0), Vector2(5.0, 0.6), Vector2(4.6, 0.6), Vector2(4.6, 0.2)], "cty_cornice", 20)
	geo.cylinder(fc + Vector3(0, 0.05, 0), fc + Vector3(0, 0.45, 0), 4.6, "cty_water", 20, false)
	geo.cylinder(fc, fc + Vector3(0, 2.2, 0), 0.5, "cty_cornice", 10)
	for i in range(int(r.size.x * r.size.y / 180.0)):
		var p := Vector3(rng.randf_range(r.position.x + 3, r.end.x - 3), y, rng.randf_range(r.position.y + 3, r.end.y - 3))
		if absf(p.x - c.x) > 5.0 and absf(p.z - c.y) > 5.0:
			trees.append([p, 1 if rng.randf() < 0.8 else 0, rng.randf_range(0.7, 1.1)])
	for k in range(6):
		var bp := Vector3(c.x + (k - 2.5) * 8.0, y, c.y + 3.6)
		if absf(bp.x - c.x) > 6.0:
			geo.box(bp + Vector3(0, 0.45, 0), Vector3(1.8, 0.1, 0.5), "boat_wood", 0.0, true, false)
			geo.box(bp + Vector3(0, 0.22, 0), Vector3(1.6, 0.44, 0.3), "cty_dark", 0.0, false, false)

## Surface car park: bays in rows, cars in most of them, a few lamps.
func car_park(r: Rect2, y: float, fill: float = 0.75) -> void:
	geo.slab(r, y + 0.03, 0.1, "cty_lot", false)
	var z: float = r.position.y + 3.0
	while z + 5.0 < r.end.y:
		var x: float = r.position.x + 2.0
		while x + 2.5 < r.end.x:
			geo.box(Vector3(x, y + 0.035, z + 2.5), Vector3(0.12, 0.01, 5.0), "cty_bay", 0.0, false, false)
			if rng.randf() < fill:
				var kind: String = ["sedan", "hatch", "suv", "estate", "hatch"][rng.randi() % 5]
				var cp := Vector3(x + 1.25, y + 0.03, z + 2.5)
				var yaw: float = 0.0 if rng.randf() < 0.5 else PI
				if fleet:
					fleet.car(cp, yaw, Fleet.random_paint(rng), kind)
				else:
					Vehicles.car(geo, cp, yaw, Vehicles.random_paint(rng), kind)
			x += 2.5
		z += 13.0
	for k in range(int(r.size.x / 30.0)):
		var lp := Vector3(r.position.x + 15.0 + k * 30.0, y, r.get_center().y)
		geo.cylinder(lp, lp + Vector3(0, 9, 0), 0.12, "cty_metal", 6)
		geo.box(lp + Vector3(0, 9.1, 0), Vector3(1.4, 0.2, 0.5), "rd_lamp" if geo.has_material("rd_lamp") else "cty_metal", 0.0, false, false)

## A gabled house (1-2 storeys) at p (ground), turned by yaw.
func house(p: Vector3, yaw: float, w: float, d: float, floors: int = 2) -> void:
	var wall: String = ["cty_plaster", "cty_plaster_warm", "cty_brick", "cty_plaster_grey"][rng.randi() % 4]
	building(p, Vector2(w, d), yaw, floors, wall, "gable" if rng.randf() < 0.75 else "slate", false)

## Cheap distant buildings along a street (no shops, no detail): what
## the far city looks like through the haze. `side` = +1/-1 of route.
func filler(route: Route, side: float, setback: float, floors_min: int, floors_max: int, mats: Array = []) -> void:
	var L: float = route.length()
	var d: float = 8.0
	while d < L - 8.0:
		var w: float = rng.randf_range(14.0, 30.0)
		var s: Array = route.sample(d + w * 0.5)
		var t: Vector3 = s[1]
		var right := Vector3(-t.z, 0.0, t.x)
		var depth: float = rng.randf_range(12.0, 18.0)
		var c: Vector3 = s[0] + right * side * (setback + depth * 0.5)
		var h: float = rng.randi_range(floors_min, floors_max) * STOREY
		var mat: String = (mats[rng.randi() % mats.size()]) if not mats.is_empty() else FACADES[rng.randi() % FACADES.size()]
		geo.box(c + Vector3(0, h * 0.5, 0), Vector3(w - 1.0, h, depth), mat, atan2(-t.x, -t.z), true, false)
		d += w

## A cheap distant city block filling r: two to four plain buildings of
## different heights (no roofs, shops or detail) - enough to read as
## city through the haze.
func filler_block(r: Rect2, y: float, floors_min: int = 3, floors_max: int = 7, mats: Array = []) -> void:
	if not geo.has_material("cty_far"):
		geo.add_material("cty_far", Geo.tex_mat(MapTextures.get_tex("facade_b"), Color(0.95, 0.9, 0.84), 7.0))
		geo.add_material("cty_far_roof", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.62, 0.6, 0.6), 8.0))
	if mats.is_empty():
		mats = ["cty_far"]
	var old_cell: float = geo.cell
	geo.cell = 256.0
	var n: int = rng.randi_range(2, 4)
	var along_x: bool = r.size.x >= r.size.y
	var L: float = r.size.x if along_x else r.size.y
	var seg: float = L / n
	for k in range(n):
		var h: float = rng.randi_range(floors_min, floors_max) * STOREY
		var mat: String = (mats[rng.randi() % mats.size()]) if not mats.is_empty() else FACADES[rng.randi() % FACADES.size()]
		var c: Vector3
		var size: Vector3
		if along_x:
			c = Vector3(r.position.x + seg * (k + 0.5), y + h * 0.5, r.get_center().y)
			size = Vector3(seg - 0.5, h, r.size.y)
		else:
			c = Vector3(r.get_center().x, y + h * 0.5, r.position.y + seg * (k + 0.5))
			size = Vector3(r.size.x, h, seg - 0.5)
		geo.box(c, size, mat, 0.0, true, false)
		geo.box(c + Vector3(0, h * 0.5 + 0.2, 0), Vector3(size.x + 0.4, 0.4, size.z + 0.4), "cty_far_roof", 0.0, false, false)
	geo.cell = old_cell
