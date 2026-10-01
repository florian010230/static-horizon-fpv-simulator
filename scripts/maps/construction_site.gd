extends BuiltMap

## Construction Site (High performance) - a city-centre building site
## the size of a whole block, seen at a busy moment. North = -z.
##
##   The high-rise: 18 storeys of concrete frame up, the core walls
##   climbing three storeys ahead, the top floors wrapped in the
##   climbing-formwork screen, glass facade panels on the lower floors
##   only - every open floor is a fly-through (3.3 m clear).
##   Two flat-top tower cranes (85 m and 62 m lattice masts, jibs to
##   60 m), a concrete pump truck with its boom up to the working deck.
##   The excavation pit for the second building: 12 m deep behind sheet
##   pile walls with walers and struts, an earth ramp down, excavators,
##   tippers queuing, bored-pile rigs and rebar cages.
##   A four-storey steel frame (the car park building) - bare beams to
##   thread. Site cabins stacked three high, material yards, fences
##   with hoardings, gates to the streets.
## Around it: the city grid (streets run out of the map into the haze),
## perimeter blocks, a finished tower, and the elevated S-Bahn on brick
## arches along the south with its station - fly under the arches.

const XS: Array = [-450.0, -290.0, -150.0, 150.0, 290.0, 450.0]
const XW: Array = [12.0, 12.0, 16.0, 16.0, 12.0, 12.0]
const ZS: Array = [-370.0, -230.0, -110.0, 110.0, 230.0]
const ZW: Array = [12.0, 12.0, 16.0, 16.0, 12.0]
const SITE := Rect2(-138, -98, 276, 196)
const PIT := Rect2(-128, -80, 105, 130)
const PIT_DEPTH: float = 12.0
const TOWER := Vector3(55, 0, -35)
const FLOOR_H: float = 3.6
const FLOORS: int = 18
const VIADUCT_Z: float = 300.0
const VIADUCT_Y: float = 8.5

var rng := RandomNumberGenerator.new()
var rails: Rails
var roads: Roads
var city: City

func map_env() -> Dictionary:
	# Late afternoon: warm, fairly low sun - the cranes and the steel
	# frame throw long shadows across the site.
	return {"sun_rot": Vector3(-21, -58, 0), "sun_color": Color(1.0, 0.82, 0.62), "sun_energy": 1.4, "fog_begin": 350.0,
		"sky_top": Color(0.28, 0.45, 0.74), "sky_horizon": Color(0.92, 0.82, 0.72),
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-520, -460, 1040, 900)}

func border() -> Array:
	return [560.0, 640.0, 220.0, 280.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(210, 110, 200), Vector3(0, 10, -20)],
		["tower_floors", Vector3(20, 30, -35), Vector3(90, 30, -35)],
		["tower_top", Vector3(100, 75, 20), Vector3(55, 62, -35)],
		["cranes", Vector3(-40, 50, 60), Vector3(40, 80, -60)],
		["pit", Vector3(-20, 14, 60), Vector3(-90, -8, -40)],
		["steel_frame", Vector3(140, 8, 70), Vector3(100, 8, 45)],
		["site_yard", Vector3(130, 6, 90), Vector3(40, 3, 60)],
		["viaduct", Vector3(-60, 4, 280), Vector3(60, 5, 300)],
		["street", Vector3(0, 10, 110), Vector3(-300, 3, 110)],
		["horizon", Vector3(0, 80, -300), Vector3(0, 0, -1800)],
	]

func build() -> void:
	rng.seed = 5150
	geo.ao_height = 2.5
	geo.add_material("ground", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 8.0, 0, 0.45))
	geo.add_material("site", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(1.05, 1.0, 0.92), 4.0, 1, 0.5))
	geo.add_material("mud", Geo.tex_mat(MapTextures.get_tex("gravel_verge"), Color(0.75, 0.65, 0.52), 4.0))
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("formwork"), Color.WHITE, 2.5))
	geo.add_material("concrete_old", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.1, 1.1, 1.08), 4.0))
	geo.add_material("crane", Geo.flat_mat(Color(0.95, 0.72, 0.08)))
	geo.add_material("crane_red", Geo.flat_mat(Color(0.78, 0.16, 0.12)))
	geo.add_material("steel", Geo.flat_mat(Color(0.38, 0.4, 0.43), 0.5, 0.5))
	geo.add_material("steel_red", Geo.flat_mat(Color(0.55, 0.22, 0.16), 0.6, 0.3))
	geo.add_material("rebar", Geo.tex_mat(MapTextures.get_tex("rust"), Color(0.9, 0.8, 0.75), 2.0))
	geo.add_material("sheet_pile", Geo.tex_mat(MapTextures.get_tex("corrugated_rust"), Color(0.8, 0.8, 0.8), 1.5))
	geo.add_material("screen", Geo.flat_mat(Color(0.85, 0.18, 0.14)))
	geo.add_material("glass_panel", Geo.tex_mat(MapTextures.get_tex("curtain_wall"), Color(1.05, 1.08, 1.12), 3.0))
	geo.add_material("net", Geo.flat_mat(Color(0.95, 0.8, 0.1)))
	geo.add_material("hoarding", Geo.flat_mat(Color(0.2, 0.36, 0.55)))
	geo.add_material("hoarding_w", Geo.flat_mat(Color(0.9, 0.9, 0.88)))
	geo.add_material("cabin", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.92, 0.92, 0.9), 2.4))
	geo.add_material("cabin_blue", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.3, 0.45, 0.7), 2.4))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.0))
	geo.add_material("sand", Geo.tex_mat(MapTextures.get_tex("sand"), Color.WHITE, 3.0))
	geo.add_material("gravel_pile", Geo.tex_mat(MapTextures.get_tex("ballast"), Color.WHITE, 2.0))
	geo.add_material("dark", Geo.flat_mat(Color(0.12, 0.12, 0.13)))
	geo.add_material("brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.15, 1.0, 0.95), 3.0))
	geo.add_material("lamp", Geo.glow_mat(Color(1.0, 0.95, 0.8), 1.2))
	Vehicles.ensure_materials(geo)
	rails = Rails.new(geo)
	roads = Roads.new(geo, rng, fleet)
	city = City.new(geo, rng, fleet)

	_ground()
	_streets_and_blocks()
	_tower()
	_tower_crane(TOWER + Vector3(-26, 0, 22), 85.0, 60.0, 35.0)
	_tower_crane(Vector3(-70, -PIT_DEPTH, -45), 62.0 + PIT_DEPTH, 55.0, 150.0)
	_pit()
	_steel_frame(Vector3(88, 0, 30))
	_site_yard()
	_viaduct()
	# Site clutter wherever there's room left (not in the pit).
	YardProps.scatter(geo, SITE.grow(-5.0), 0.05, 70, rng, [PIT])
	Forest.plant(self, city.trees, self)

# --- ground ---------------------------------------------------------------------

func _ground() -> void:
	# Grass to the horizon with the pit left open, the site surface.
	var big := Rect2(-3200, -3200, 6400, 6400)
	var holes: Array = [PIT]
	geo.slab(Rect2(big.position.x, big.position.y, big.size.x, PIT.position.y - big.position.y), 0.0, 4.0, "ground")
	geo.slab(Rect2(big.position.x, PIT.end.y, big.size.x, big.end.y - PIT.end.y), 0.0, 4.0, "ground")
	geo.slab(Rect2(big.position.x, PIT.position.y, PIT.position.x - big.position.x, PIT.size.y), 0.0, 4.0, "ground")
	geo.slab(Rect2(PIT.end.x, PIT.position.y, big.end.x - PIT.end.x, PIT.size.y), 0.0, 4.0, "ground")
	for r in _minus(SITE, holes):
		geo.slab(r, 0.0, 1.0, "site", false)
	# Pit floor and its sheet pile walls.
	geo.slab(PIT, -PIT_DEPTH, 1.0, "mud")

## Rect minus rects (grid split on the holes' edges).
func _minus(r: Rect2, holes: Array) -> Array[Rect2]:
	var xs: Array[float] = [r.position.x, r.end.x]
	var zs: Array[float] = [r.position.y, r.end.y]
	for h: Rect2 in holes:
		xs.append_array([clampf(h.position.x, r.position.x, r.end.x), clampf(h.end.x, r.position.x, r.end.x)])
		zs.append_array([clampf(h.position.y, r.position.y, r.end.y), clampf(h.end.y, r.position.y, r.end.y)])
	xs.sort()
	zs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var c := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if c.size.x < 0.01 or c.size.y < 0.01:
				continue
			var inside: bool = false
			for h: Rect2 in holes:
				if h.has_point(c.get_center()):
					inside = true
			if not inside:
				out.append(c)
	return out

# --- the city round the site -------------------------------------------------------

func _streets_and_blocks() -> void:
	var blocks: Array[Rect2] = roads.grid(XS, ZS, XW, ZW, 4.0, 0.0, {"n": 1800.0, "s": 1800.0, "w": 1900.0, "e": 1900.0}, {"traffic": 16.0, "lamps": 30.0})
	for r: Rect2 in blocks:
		var c: Vector2 = r.get_center()
		if SITE.grow(20.0).has_point(c):
			continue
		if c.distance_to(Vector2(220, -170)) < 60.0:
			city.tower(r, 0.0, 96.0)
		elif c.distance_to(Vector2(-220, 170)) < 60.0:
			city.park(r, 0.0)
		elif c.distance_to(Vector2(370, 170)) < 60.0:
			city.car_park(r, 0.0)
		elif c.y > VIADUCT_Z - 40.0 and c.y < VIADUCT_Z + 40.0:
			continue
		else:
			city.perimeter_block(r, 0.0, 4, 7)
	# Past the grid: cheap blocks on the same street pattern, fading out.
	var xs: Array = XS.duplicate()
	while xs[0] > -1900.0:
		xs.push_front(xs[0] - 150.0)
	while xs[-1] < 1900.0:
		xs.append(xs[-1] + 150.0)
	var zs: Array = ZS.duplicate()
	while zs[0] > -1900.0:
		zs.push_front(zs[0] - 130.0)
	while zs[-1] < 1900.0:
		zs.append(zs[-1] + 130.0)
	geo.add_material("far_asphalt", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 1, 0.3))
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var x0: float = xs[i]
			var x1: float = xs[i + 1]
			var z0: float = zs[j]
			var z1: float = zs[j + 1]
			if x0 >= XS[0] - 1.0 and x1 <= XS[-1] + 1.0 and z0 >= ZS[0] - 1.0 and z1 <= ZS[-1] + 1.0:
				continue
			var cc := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			if cc.length() > 2000.0:
				continue
			var inner := Rect2(x0 + 11.0, z0 + 11.0, x1 - x0 - 22.0, z1 - z0 - 22.0)
			if inner.grow(6.0).intersects(Rect2(-4000, VIADUCT_Z - 12.0, 8000, 24.0)):
				continue
			var on_grid_street: bool = (x0 >= XS[0] - 1.0 and x1 <= XS[-1] + 1.0) or (z0 >= ZS[0] - 1.0 and z1 <= ZS[-1] + 1.0)
			if not on_grid_street:
				geo.slab(Rect2(x0, z0, x1 - x0, z1 - z0), 0.0, 0.5, "far_asphalt", false)
			city.filler_block(inner, 0.0)

# --- the high-rise ------------------------------------------------------------------

## 36 x 28 m floor plate, columns on a 6 x 7 m grid, a 10 x 8 m core
## (lift and stair shafts - hollow, with door openings), slabs every
## 3.6 m. Lower floors glazed, the top three wrapped in the red
## climbing-formwork screen, yellow edge nets below it.
func _tower() -> void:
	var w: float = 36.0
	var d: float = 28.0
	var o: Vector3 = TOWER
	for f in range(FLOORS + 1):
		var y: float = f * FLOOR_H
		if f > 0:
			geo.box(o + Vector3(0, y - 0.15, 0), Vector3(w, 0.3, d), "concrete")
		if f == FLOORS:
			break
		for ix in range(7):
			for iz in range(5):
				var cx: float = -w * 0.5 + 0.4 + ix * (w - 0.8) / 6.0
				var cz: float = -d * 0.5 + 0.4 + iz * (d - 0.8) / 4.0
				if absf(cx) < 5.5 and absf(cz) < 4.5:
					continue
				geo.box(o + Vector3(cx, y + FLOOR_H * 0.5 - 0.15, cz), Vector3(0.6, FLOOR_H - 0.3, 0.6), "concrete")
		# Facade: glass on the finished lower floors, gaps left on some.
		if f < 7:
			for side in range(4):
				if rng.randf() < 0.15 and f > 1:
					continue
				var along_x: bool = side < 2
				var s: float = 1.0 if side % 2 == 0 else -1.0
				var pos: Vector3 = o + (Vector3(0, y + FLOOR_H * 0.5, s * (d * 0.5 + 0.1)) if along_x else Vector3(s * (w * 0.5 + 0.1), y + FLOOR_H * 0.5, 0))
				geo.box(pos, Vector3(w, FLOOR_H - 0.35, 0.12) if along_x else Vector3(0.12, FLOOR_H - 0.35, d), "glass_panel")
		elif f >= FLOORS - 3:
			# Climbing formwork screen round the top floors (open at the
			# top: you can dive into the working deck).
			for side in range(4):
				var along_x: bool = side < 2
				var s: float = 1.0 if side % 2 == 0 else -1.0
				var pos: Vector3 = o + (Vector3(0, y + FLOOR_H * 0.5 + 1.0, s * (d * 0.5 + 1.2)) if along_x else Vector3(s * (w * 0.5 + 1.2), y + FLOOR_H * 0.5 + 1.0, 0))
				geo.box(pos, Vector3(w + 2.6, FLOOR_H, 0.2) if along_x else Vector3(0.2, FLOOR_H, d + 2.6), "screen")
		else:
			# Edge protection: posts and a yellow net band at waist height.
			for side in range(4):
				var along_x: bool = side < 2
				var s: float = 1.0 if side % 2 == 0 else -1.0
				var pos: Vector3 = o + (Vector3(0, y + 0.6, s * (d * 0.5 - 0.05)) if along_x else Vector3(s * (w * 0.5 - 0.05), y + 0.6, 0))
				geo.box(pos, Vector3(w, 1.1, 0.05) if along_x else Vector3(0.05, 1.1, d), "net", 0.0, false, false)
	# The core, three storeys above the top slab.
	var core_h: float = (FLOORS + 3) * FLOOR_H
	for s in [-1.0, 1.0]:
		geo.box(o + Vector3(s * 5.0, core_h * 0.5, 0), Vector3(0.35, core_h, 8.0), "concrete")
	for s in [-1.0, 1.0]:
		for f in range(FLOORS + 3):
			var y: float = f * FLOOR_H
			geo.box(o + Vector3(-3.0, y + FLOOR_H * 0.5, s * 4.0), Vector3(4.0, FLOOR_H, 0.35), "concrete")
			geo.box(o + Vector3(3.8, y + FLOOR_H * 0.5, s * 4.0), Vector3(2.4, FLOOR_H, 0.35), "concrete")
			geo.box(o + Vector3(0.9, y + FLOOR_H - 0.45, s * 4.0), Vector3(3.4, 0.9, 0.35), "concrete")
	# Rebar starter bars sticking up from the top slab's columns.
	var top: float = FLOORS * FLOOR_H
	for ix in range(7):
		for iz in [0, 4]:
			var cx: float = -w * 0.5 + 0.4 + ix * (w - 0.8) / 6.0
			var cz: float = -d * 0.5 + 0.4 + iz * (d - 0.8) / 4.0
			for k in range(4):
				var q: Vector3 = o + Vector3(cx + (k % 2) * 0.4 - 0.2, top, cz + (k / 2) * 0.4 - 0.2)
				geo.cylinder(q, q + Vector3(0, 1.4, 0), 0.03, "rebar", 4, false, false, false)
	# Formwork tables and props on the top deck.
	for k in range(6):
		geo.box(o + Vector3(-12 + k * 4.5, top + 0.1, 9), Vector3(4.0, 0.2, 2.5), "wood")
	# Construction hoist on the north face: mast and a cage.
	var hx: Vector3 = o + Vector3(8, 0, -d * 0.5 - 2.2)
	geo.box(hx + Vector3(0, top * 0.5 + 2.0, 0), Vector3(0.8, top + 4.0, 0.8), "crane")
	geo.box(hx + Vector3(0, 28.0, -1.8), Vector3(2.0, 2.6, 3.0), "cabin_blue")
	# Scaffolding on the low east wing (a podium being clad).
	_scaffold(o + Vector3(w * 0.5 + 1.2, 0, 0), d, 7, true)

## Façade scaffold along a wall: standards every 2.5 m, ledgers and
## boards on each 2 m lift, diagonal braces; open to fly along.
func _scaffold(o: Vector3, length: float, lifts: int, along_z: bool) -> void:
	var n: int = int(length / 2.5)
	var ax: Vector3 = Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var out: Vector3 = Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
	var a: Vector3 = o - ax * length * 0.5
	for i in range(n + 1):
		for k in [0.0, 1.0]:
			var b: Vector3 = a + ax * i * 2.5 + out * k * 1.1
			geo.cylinder(b, b + Vector3(0, lifts * 2.0 + 1.0, 0), 0.03, "steel", 4, true, false, false)
	for l in range(1, lifts + 1):
		var y: float = l * 2.0
		for k in [0.0, 1.0]:
			geo.beam(a + out * k * 1.1 + Vector3(0, y, 0), a + ax * n * 2.5 + out * k * 1.1 + Vector3(0, y, 0), Vector2(0.05, 0.05), "steel", false, false)
		geo.box(a + ax * n * 1.25 + out * 0.55 + Vector3(0, y - 0.03, 0), (Vector3(1.0, 0.05, n * 2.5) if along_z else Vector3(n * 2.5, 0.05, 1.0)), "wood", 0.0, true, false)
	for i in range(0, n, 2):
		geo.beam(a + ax * i * 2.5 + out * 1.1, a + ax * (i + 2) * 2.5 + out * 1.1 + Vector3(0, lifts * 2.0, 0), Vector2(0.05, 0.05), "steel", false, false)

# --- tower cranes ----------------------------------------------------------------------

## Flat-top tower crane: square lattice mast (chords + zigzag bracing)
## on a concrete base, slewing unit with the cab, the jib (triangular
## lattice) out to `jib`, counter-jib with ballast blocks, trolley and
## a hook with a load. yaw_deg = jib heading.
func _tower_crane(base: Vector3, height: float, jib: float, yaw_deg: float) -> void:
	var s: float = 1.0
	geo.box(base + Vector3(0, 0.6, 0), Vector3(6, 1.2, 6), "concrete_old")
	var corners: Array[Vector3] = [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]
	for c in corners:
		geo.beam(base + c + Vector3(0, 1.2, 0), base + c + Vector3(0, height, 0), Vector2(0.18, 0.18), "crane")
	var y: float = 1.2
	var step: float = 3.0
	var flip: bool = false
	while y + step <= height:
		for k in range(4):
			var c0: Vector3 = corners[k]
			var c1: Vector3 = corners[(k + 1) % 4]
			var y0: float = y if not flip else y + step
			var y1: float = y + step if not flip else y
			geo.beam(base + c0 + Vector3(0, y0, 0), base + c1 + Vector3(0, y1, 0), Vector2(0.08, 0.08), "crane", false, false)
			geo.beam(base + c0 + Vector3(0, y, 0), base + c1 + Vector3(0, y, 0), Vector2(0.08, 0.08), "crane", false, false)
		flip = not flip
		y += step
	var top: Vector3 = base + Vector3(0, height, 0)
	var b := Basis(Vector3.UP, deg_to_rad(-yaw_deg))
	geo.box_xf(Transform3D(b, top + Vector3(0, 1.0, 0)), Vector3(3.0, 2.0, 3.0), "crane")
	geo.box_xf(Transform3D(b, top + b * Vector3(1.8, 1.8, 1.0)), Vector3(1.6, 2.2, 2.0), "cabin")
	geo.box_xf(Transform3D(b, top + b * Vector3(2.62, 1.9, 1.0)), Vector3(0.05, 1.3, 1.6), "dark", false, false)
	# Jib: triangular lattice, 1.6 m wide, 1.8 m deep, along local +x.
	var jy: float = 2.2
	for side in [-0.8, 0.8]:
		geo.beam(top + b * Vector3(0, jy, side), top + b * Vector3(jib, jy, side), Vector2(0.14, 0.14), "crane")
	geo.beam(top + b * Vector3(0, jy + 1.8, 0), top + b * Vector3(jib - 1.0, jy + 1.8, 0), Vector2(0.14, 0.14), "crane")
	var x: float = 0.0
	while x < jib - 2.0:
		for side in [-0.8, 0.8]:
			geo.beam(top + b * Vector3(x, jy, side), top + b * Vector3(x + 1.5, jy + 1.8, 0), Vector2(0.06, 0.06), "crane", false, false)
			geo.beam(top + b * Vector3(x + 1.5, jy + 1.8, 0), top + b * Vector3(x + 3.0, jy, side), Vector2(0.06, 0.06), "crane", false, false)
		x += 3.0
	# Counter-jib with ballast.
	var cj: float = jib * 0.33
	for side in [-1.0, 1.0]:
		geo.beam(top + b * Vector3(0, jy, side), top + b * Vector3(-cj, jy, side), Vector2(0.2, 0.3), "crane")
	geo.box_xf(Transform3D(b, top + b * Vector3(-cj * 0.5, jy + 0.1, 0)), Vector3(cj, 0.1, 2.0), "steel", false, false)
	for k in range(4):
		geo.box_xf(Transform3D(b, top + b * Vector3(-cj + 1.2 + k * 0.9, jy - 1.0, 0)), Vector3(0.8, 2.4, 2.4), "concrete_old")
	geo.box_xf(Transform3D(b, top + b * Vector3(-cj * 0.4, jy + 0.7, 0)), Vector3(2.5, 1.2, 1.6), "steel")
	# Trolley, hoist rope, hook and a load (a rebar bundle / skip).
	var tx: float = jib * rng.randf_range(0.45, 0.8)
	var trolley: Vector3 = top + b * Vector3(tx, jy - 0.3, 0)
	geo.box(trolley, Vector3(1.2, 0.5, 1.4), "crane_red")
	var hook_y: float = maxf(base.y + 8.0, trolley.y - rng.randf_range(20.0, height * 0.7))
	geo.beam(trolley, Vector3(trolley.x, hook_y, trolley.z), Vector2(0.04, 0.04), "dark", false, false)
	geo.box(Vector3(trolley.x, hook_y - 0.3, trolley.z), Vector3(0.5, 0.6, 0.3), "crane_red", 0.0, false, false)
	geo.box(Vector3(trolley.x, hook_y - 2.8, trolley.z), Vector3(2.2, 1.3, 1.6), "rebar")

# --- the pit ---------------------------------------------------------------------------

## 12 m deep: sheet pile walls with a waler and cross struts, an earth
## ramp from the north-east corner, two excavators, tippers on the ramp,
## a piling rig, rebar cages, a pump sump.
func _pit() -> void:
	var p: Rect2 = PIT
	var d: float = PIT_DEPTH
	for seg in [[Vector3(p.position.x, 0, p.position.y), Vector3(p.end.x, 0, p.position.y)], [Vector3(p.position.x, 0, p.end.y), Vector3(p.end.x, 0, p.end.y)],
			[Vector3(p.position.x, 0, p.position.y), Vector3(p.position.x, 0, p.end.y)], [Vector3(p.end.x, 0, p.position.y), Vector3(p.end.x, 0, p.end.y)]]:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var along_x: bool = absf(b.x - a.x) > 1.0
		var c: Vector3 = (a + b) * 0.5
		geo.box(c + Vector3(0, -d * 0.5 + 0.4, 0), Vector3(absf(b.x - a.x) + 0.4 if along_x else 0.4, d + 0.8, absf(b.z - a.z) + 0.4 if not along_x else 0.4), "sheet_pile")
		for wy in [-3.0, -8.0]:
			var inward: Vector3 = Vector3(0, 0, 1 if a.z < p.get_center().y else -1) if along_x else Vector3(1 if a.x < p.get_center().x else -1, 0, 0)
			geo.box(c + Vector3(0, wy, 0) + inward * 0.6, Vector3(absf(b.x - a.x) if along_x else 0.8, 0.9, absf(b.z - a.z) if not along_x else 0.8), "steel_red")
	# Struts across the pit at the upper waler level (fly between them).
	for k in range(4):
		var z: float = p.position.y + 20.0 + k * 30.0
		geo.cylinder(Vector3(p.position.x + 1.0, -3.0, z), Vector3(p.end.x - 1.0, -3.0, z), 0.35, "steel_red", 10)
	# Earth ramp down from the site road (north-east corner, heading south).
	var ramp := Route.from(Vector3(p.end.x - 10.0, 0.0, p.position.y - 18.0), 90.0).straight(p.size.y * 0.8 + 18.0, 4.0)
	for k in range(ramp.pts.size()):
		var t: float = clampf((ramp.pts[k].z - p.position.y) / (p.size.y * 0.8), 0.0, 1.0)
		ramp.pts[k].y = -d * t
	geo.sweep(ramp.pts, [Vector2(4.5, -d - 1.0), Vector2(4.0, 0.05), Vector2(-4.0, 0.05), Vector2(-4.5, -d - 1.0)], "mud", false, true, false)
	Vehicles.excavator(geo, Vector3(p.position.x + 25.0, -d, p.position.y + 35.0), 0.8, 0.6)
	Vehicles.excavator(geo, Vector3(p.position.x + 55.0, -d, p.end.y - 25.0), -2.2, 0.3, "site_orange")
	Vehicles.tipper(geo, Vector3(p.end.x - 10.0, -d * 0.55, p.position.y + 55.0), PI, "veh_paint2", "mud")
	Vehicles.tipper(geo, Vector3(p.position.x + 40.0, -d, p.position.y + 45.0), -1.2, "veh_paint0", "mud")
	# Piling rig: tracked base, 22 m leader mast.
	var pr := Vector3(p.position.x + 70.0, -d, p.position.y + 30.0)
	geo.box(pr + Vector3(0, 1.0, 0), Vector3(4.5, 2.0, 6.0), "site_orange")
	geo.box(pr + Vector3(0, 3.0, 0.8), Vector3(3.5, 2.2, 4.0), "site_orange")
	geo.box(pr + Vector3(0, 13.0, -3.2), Vector3(0.9, 22.0, 0.9), "steel")
	geo.beam(pr + Vector3(0, 4.0, 1.0), pr + Vector3(0, 16.0, -3.0), Vector2(0.3, 0.3), "steel")
	for k in range(5):
		var cage: Vector3 = Vector3(p.position.x + 12.0 + k * 3.0, -d + 0.6, p.end.y - 8.0)
		geo.pipe(cage + Vector3(0, 0, -5), cage + Vector3(0, 0, 5), 0.6, 0.06, "rebar", 8)
	for k in range(12):
		var bp := Vector3(p.position.x + 60.0 + (k % 4) * 8.0, -d, p.position.y + 60.0 + (k / 4) * 8.0)
		geo.cylinder(bp, bp + Vector3(0, 0.4, 0), 0.6, "concrete", 10) # cut-off bored piles
	geo.cylinder(Vector3(p.position.x + 4.0, -d - 0.5, p.position.y + 4.0), Vector3(p.position.x + 4.0, -d + 0.2, p.position.y + 4.0), 1.2, "dark", 10, false)
	geo.pipe_path(Route.rounded([Vector3(p.position.x + 4.0, -d + 0.5, p.position.y + 4.0), Vector3(p.position.x + 4.0, 1.0, p.position.y + 4.0), Vector3(p.position.x + 4.0, 1.0, p.position.y - 6.0), Vector3(p.position.x + 40.0, 0.3, p.position.y - 6.0)], 1.0), 0.12, "dark", 0.0, 8, false, false)
	# Guard rail round the pit edge.
	for side in range(4):
		var along_x: bool = side < 2
		var s: float = 1.0 if side % 2 == 0 else -1.0
		var c := Vector3(p.get_center().x, 1.0, p.get_center().y) + (Vector3(0, 0, s * (p.size.y * 0.5 + 0.8)) if along_x else Vector3(s * (p.size.x * 0.5 + 0.8), 0, 0))
		geo.box(c, Vector3(p.size.x, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, p.size.y), "hoarding_w", 0.0, false, false)

# --- steel frame ---------------------------------------------------------------------

## The car-park building's steel skeleton: 4 storeys of columns and
## beams on a 7.5 m grid, bracing in the end bays, decking on two floors.
func _steel_frame(o: Vector3) -> void:
	var nx: int = 5
	var nz: int = 7
	var g: float = 7.5
	var h: float = 3.4
	for f in range(5):
		var y: float = f * h
		for ix in range(nx):
			for iz in range(nz):
				var p: Vector3 = o + Vector3((ix - (nx - 1) * 0.5) * g, 0, (iz - (nz - 1) * 0.5) * g)
				if f < 4:
					geo.box(p + Vector3(0, y + h * 0.5, 0), Vector3(0.35, h, 0.35), "steel_red")
				if f > 0:
					if ix < nx - 1:
						geo.box(p + Vector3(g * 0.5, y - 0.2, 0), Vector3(g, 0.4, 0.2), "steel_red")
					if iz < nz - 1:
						geo.box(p + Vector3(0, y - 0.2, g * 0.5), Vector3(0.2, 0.4, g), "steel_red")
		if f in [1, 2]:
			geo.box(o + Vector3(0, y + 0.02, 0), Vector3((nx - 1) * g, 0.1, (nz - 1) * g * 0.5), "steel")
	for s in [-1.0, 1.0]:
		for f in range(4):
			var a: Vector3 = o + Vector3(s * (nx - 1) * g * 0.5, f * h, -(nz - 1) * g * 0.5)
			geo.beam(a, a + Vector3(0, h, g), Vector2(0.15, 0.15), "steel_red", true, false)

# --- site yard -------------------------------------------------------------------------

## Cabins, laydown areas, heaps, the pump truck and mixers, the gates,
## the hoarding round the site, floodlights.
func _site_yard() -> void:
	# Site office: containers 6 x 2.4 x 2.6 m, three high with stairs.
	var co := Vector3(40, 0, 78)
	for lvl in range(3):
		for k in range(5):
			var m: String = "cabin" if (k + lvl) % 3 else "cabin_blue"
			geo.box(co + Vector3(-12 + k * 6.1, 1.3 + lvl * 2.62, 0), Vector3(6.0, 2.6, 2.44), m)
			geo.box(co + Vector3(-12 + k * 6.1, 1.4 + lvl * 2.62, -1.23), Vector3(1.2, 1.0, 0.03), "dark", 0.0, false, false)
	for lvl in range(2):
		geo.beam(co + Vector3(17.0, lvl * 2.62, 2.5), co + Vector3(20.0, (lvl + 1) * 2.62, 2.5), Vector2(1.0, 0.15), "steel")
	geo.box(co + Vector3(0, 7.9, -1.9), Vector3(31, 0.1, 1.2), "steel") # walkway
	# Laydown: rebar bundles, formwork panels, pallets, pipes.
	for k in range(8):
		geo.box(Vector3(-10 + k * 3.0, 0.4, 72), Vector3(0.9, 0.8, 12.0), "rebar")
	for k in range(6):
		for lvl in range(rng.randi_range(3, 6)):
			geo.box(Vector3(-5 + k * 3.2, 0.12 + lvl * 0.24, 88), Vector3(2.5, 0.22, 2.7), "wood")
	for k in range(5):
		geo.cylinder(Vector3(100, 0.55, 60 + k * 1.2), Vector3(112, 0.55, 60 + k * 1.2), 0.5, "concrete_old", 10)
	# Heaps.
	geo.cone(Vector3(-15, 0, 58), Vector3(-15, 5.5, 58), 8.0, 0.5, "sand", 12)
	geo.cone(Vector3(22, 0, 59), Vector3(22, 4.0, 59), 6.0, 0.5, "gravel_pile", 12)
	# Concrete pump truck, boom unfolded up to the working deck.
	var pump := TOWER + Vector3(0, 0, 32)
	geo.box(pump + Vector3(0, 1.3, 0), Vector3(2.5, 1.2, 12.0), "hoarding_w")
	geo.prism(Transform3D(Basis(), pump), [Vector2(-6.0, 1.9), Vector2(-6.05, 3.2), Vector2(-4.4, 3.2), Vector2(-4.4, 1.9)], 2.4, "hoarding_w")
	for sx in [-1.0, 1.0]:
		for z in [-4.5, -3.0, 2.0, 3.5]:
			geo.cylinder(pump + Vector3(sx * 1.35, 0.55, z), pump + Vector3(sx * 0.95, 0.55, z), 0.55, "veh_tyre", 10)
		geo.beam(pump + Vector3(sx * 1.2, 1.2, -3.0), pump + Vector3(sx * 4.5, 0.3, -5.0), Vector2(0.3, 0.3), "hoarding_w")
		geo.beam(pump + Vector3(sx * 1.2, 1.2, 3.0), pump + Vector3(sx * 4.5, 0.3, 5.0), Vector2(0.3, 0.3), "hoarding_w")
	var j0: Vector3 = pump + Vector3(0, 3.5, -2.0)
	var j1: Vector3 = j0 + Vector3(0, 22, -5)
	var j2: Vector3 = j1 + Vector3(0, 20, -12)
	var j3: Vector3 = j2 + Vector3(0, 26, -8)
	var j4: Vector3 = Vector3(TOWER.x, FLOORS * FLOOR_H + 6.0, TOWER.z + 6.0)
	for seg in [[j0, j1], [j1, j2], [j2, j3], [j3, j4]]:
		geo.beam(seg[0], seg[1], Vector2(0.5, 0.6), "hoarding_w")
	geo.beam(j4, j4 + Vector3(0, -4, 0), Vector2(0.25, 0.25), "dark", false)
	for k in range(3):
		Vehicles.mixer(geo, Vector3(8.0 + k * 11.0, 0.02, 46.0), PI * 0.5, "veh_paint2")
	Vehicles.mobile_crane(geo, Vector3(95, 0.02, 85), PI * 0.5, 34.0, 58.0)
	Vehicles.wheel_loader(geo, Vector3(-12, 0.02, 64), 0.6)
	# Site roads (packed gravel) are the site ground; parking for staff.
	for k in range(8):
		fleet.car(Vector3(-110.0 + k * 2.8, 0.02, 90.0), 0.0, Fleet.random_paint(rng), ["hatch", "suv", "van", "pickup"][rng.randi() % 4])
	# Hoarding round the site, gates onto the streets, floodlight masts.
	var gates: Array = [Vector2(120.0, SITE.end.y), Vector2(-100.0, SITE.end.y), Vector2(SITE.end.x, 40.0)]
	for side in range(4):
		var along_x: bool = side < 2
		var fixed: float = SITE.position.y - 0.5 if side == 0 else (SITE.end.y + 0.5 if side == 1 else (SITE.position.x - 0.5 if side == 2 else SITE.end.x + 0.5))
		var a0: float = SITE.position.x if along_x else SITE.position.y
		var a1: float = SITE.end.x if along_x else SITE.end.y
		var t: float = a0
		while t < a1 - 0.1:
			var seg: float = minf(3.5, a1 - t)
			var mid: float = t + seg * 0.5
			var gap: bool = false
			for g: Vector2 in gates:
				var gp: float = g.x if along_x else g.y
				var gf: float = g.y if along_x else g.x
				if absf(gf - fixed) < 2.0 and absf(mid - gp) < 6.0:
					gap = true
			if not gap:
				var pos := Vector3(mid, 1.25, fixed) if along_x else Vector3(fixed, 1.25, mid)
				geo.box(pos, Vector3(seg - 0.05, 2.5, 0.08) if along_x else Vector3(0.08, 2.5, seg - 0.05), "hoarding" if int(mid / 7.0) % 3 else "hoarding_w", 0.0, true, false)
			t += seg
	for p in [Vector3(-130, 0, -90), Vector3(130, 0, -90), Vector3(-130, 0, 90), Vector3(130, 0, 90)]:
		geo.cylinder(p, p + Vector3(0, 22, 0), 0.25, "steel", 8)
		geo.box(p + Vector3(0, 22.4, 0), Vector3(2.4, 0.8, 0.8), "lamp", 0.0, false, false)

# --- S-Bahn viaduct ------------------------------------------------------------------

## A double-track city railway on brick arches along the south, straight
## through the map and out both ways, with a station over the site's
## south street (platform and canopy up on the viaduct).
func _viaduct() -> void:
	var centre := Route.from(Vector3(-3000, VIADUCT_Y, VIADUCT_Z), 0.0).straight(6000.0, 12.0)
	# Brick arches: piers every 15 m (streets pass under the wider spans).
	var x: float = -2990.0
	while x < 2990.0:
		var street: bool = false
		for sx in XS:
			if absf(x - sx) < 12.0:
				street = true
		if not street and absf(x) > 3.0:
			geo.box(Vector3(x, VIADUCT_Y * 0.5 - 0.6, VIADUCT_Z), Vector3(2.5, VIADUCT_Y - 1.2, 11.0), "brick", 0.0, true, absf(x) < 700.0)
		x += 15.0
	geo.box(Vector3(0, VIADUCT_Y - 0.6, VIADUCT_Z), Vector3(6000, 1.2, 11.0), "brick")
	# Wider deck through the station, parapets either side of it.
	geo.box(Vector3(0, VIADUCT_Y - 0.6, VIADUCT_Z), Vector3(150, 1.2, 17.0), "brick")
	for s in [-1.0, 1.0]:
		for part in [[-3000.0, -75.0], [75.0, 3000.0]]:
			geo.box(Vector3((part[0] + part[1]) * 0.5, VIADUCT_Y + 0.6, VIADUCT_Z + s * 5.3), Vector3(part[1] - part[0], 1.2, 0.4), "brick")
	var n := Route.from_pts(centre.offset(-2.0))
	var s2 := Route.from_pts(centre.offset(2.0))
	rails.field(centre, 7.5, 1)
	rails.track(n, 0, false)
	rails.track(s2, 0, false)
	rails.catenary(n, -1.0, 2000.0, 4000.0)
	rails.catenary(s2, 1.0, 2000.0, 4000.0)
	# Station: side platforms on cantilevers, canopy.
	for sgn in [-1.0, 1.0]:
		var pz: float = VIADUCT_Z + sgn * 5.9
		var top: float = VIADUCT_Y + Rails.RAIL_TOP + 0.76
		geo.box(Vector3(0, (VIADUCT_Y + top) * 0.5, pz), Vector3(140, top - VIADUCT_Y, 4.4), "concrete_old")
		geo.box(Vector3(0, top + 3.6, pz), Vector3(140, 0.2, 4.8), "steel")
		for k in range(8):
			geo.box(Vector3(-63 + k * 18, top + 1.8, pz + sgn * 1.6), Vector3(0.2, 3.6, 0.2), "steel")
		geo.box(Vector3(0, top + 0.6, pz + sgn * 2.3), Vector3(140, 1.2, 0.1), "steel", 0.0, true, false)
	var kinds: Array = ["ice_tail", "ice", "ice", "ice_head"]
	rails.train(s2, s2.dist_at_x(-40.0), kinds, rng)
	rails.train(n.reversed(), n.reversed().dist_at_x(600.0), kinds, rng)
