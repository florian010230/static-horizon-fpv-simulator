extends BuiltMap

## Race Arena - an indoor league race in a dark exhibition hall
## (Medium performance): LED gates that light themselves (bloom on
## High), a scaffold tower gate, a tunnel, spectator stands.
## Hall 120 x 60 x 22 m. Course (fly order):
##   START (-30,20) east -> gate (0,20) -> tunnel (12..32, 20)
##   -> ladder top (48,5) north -> dive gate (40,-20)
##   -> scaffold gate 8 m up (15,-22) west -> double gate lower (-12,-22)
##   -> hurdle (-38,-12) south -> gate (-50,6) south -> START.

const HALL := AABB(Vector3(-60, 0, -30), Vector3(120, 22, 60))

var course: RaceCourse

func map_env() -> Dictionary:
	# The "sun" points straight down: the hall's ceiling lights. It lights
	# floors and the tops of things, leaves the black walls dark.
	return {"sun_rot": Vector3(-80, -30, 0), "sun_energy": 1.0, "ambient_energy": 0.7,
		"fog": false, "shadows": false, "sky_top": Color(0.05, 0.05, 0.07), "sky_horizon": Color(0.05, 0.05, 0.07)}

func check_border() -> void:
	WorldBorder.check_box(drone, ui, HALL.position, HALL.end, 10.0, get_tree())

func preview_views() -> Array:
	return [
		["overview", Vector3(-55, 18, 28), Vector3(10, 0, -5)],
		["start", Vector3(-40, 1.3, 20), Vector3(0, 1.3, 20)],
		["tunnel", Vector3(8, 1.2, 20), Vector3(40, 1.2, 20)],
		["scaffold", Vector3(35, 10, -22), Vector3(0, 8, -22)],
	]

func build() -> void:
	geo.ao_height = 2.0
	RaceCourse.add_materials(geo)
	geo.add_material("floor", Geo.tex_mat(ProceduralTextures.concrete_texture(), Color(0.75, 0.75, 0.8), 6.0, 0.6))
	geo.add_material("wall", Geo.flat_mat(Color(0.16, 0.16, 0.19), 0.9))
	geo.add_material("truss", Geo.flat_mat(Color(0.3, 0.3, 0.32), 0.4, 0.6))
	geo.add_material("seat", Geo.flat_mat(Color(0.12, 0.2, 0.45), 0.7))
	geo.add_material("lamp", Geo.glow_mat(Color(1.0, 0.97, 0.9), 1.6))
	geo.add_material("tunnel", Geo.flat_mat(Color(0.14, 0.14, 0.16), 0.8))
	geo.add_material("banner", Geo.glow_mat(Color(0.12, 0.43, 0.88), 1.2))
	geo.add_material("banner_o", Geo.glow_mat(Color(0.91, 0.33, 0.1), 1.2))

	var h: AABB = HALL
	geo.slab(Rect2(h.position.x, h.position.z, h.size.x, h.size.z), 0.0, 0.4, "floor")
	# Walls and roof, closed - the arena is indoors.
	var c: Vector3 = h.get_center()
	geo.box(Vector3(c.x, h.size.y * 0.5, h.position.z - 0.25), Vector3(h.size.x + 1, h.size.y, 0.5), "wall")
	geo.box(Vector3(c.x, h.size.y * 0.5, h.end.z + 0.25), Vector3(h.size.x + 1, h.size.y, 0.5), "wall")
	geo.box(Vector3(h.position.x - 0.25, h.size.y * 0.5, c.z), Vector3(0.5, h.size.y, h.size.z), "wall")
	geo.box(Vector3(h.end.x + 0.25, h.size.y * 0.5, c.z), Vector3(0.5, h.size.y, h.size.z), "wall")
	geo.box(Vector3(c.x, h.size.y + 0.25, c.z), Vector3(h.size.x + 1, 0.5, h.size.z + 1), "wall")
	# Roof trusses with light strips.
	for i in range(7):
		var x: float = h.position.x + 10 + i * 16.7
		geo.beam(Vector3(x, 19, h.position.z), Vector3(x, 19, h.end.z), Vector2(0.8, 1.6), "truss")
		geo.box(Vector3(x, 18.1, 0), Vector3(1.0, 0.15, 50), "lamp", 0.0, false, false)
	# Glowing sponsor-style banners on the long walls (league colours).
	for i in range(6):
		geo.box(Vector3(-50 + i * 20, 6, h.position.z + 0.05), Vector3(14, 2.2, 0.1), "banner" if i % 2 == 0 else "banner_o", 0.0, false, false)
	# Spectator stand along the north wall: stepped tiers.
	for t in range(6):
		geo.box(Vector3(0, (6 - t) * 0.35, h.position.z + 1.0 + t * 0.9), Vector3(80, (6 - t) * 0.7, 0.9), "seat")

	course = RaceCourse.new()
	course.name = "RaceCourse"
	add_child(course)
	var E: float = -PI * 0.5 # fly toward +x
	var W: float = PI * 0.5  # toward -x
	var S: float = PI        # toward +z
	course.start_gate(geo, Vector3(-30, 0.02, 20), E)
	course.gate(geo, Vector3(0, 0.02, 20), E, 1, 0.0, 0, "led_blue")
	_tunnel(Vector3(12, 0, 20), Vector3(32, 0, 20))
	course.gate_sized(geo, Vector3(12.2, 0.02, 20), E, 2.6, 2.6, 0.15, 0.0, "led_green") # tunnel mouth
	course.gate(geo, Vector3(48, 0.02, 5), 0.0, 3, 0.0, 2, "led_orange")
	course.dive_gate(geo, Vector3(40, 0.02, -20), 0.0, 6.0, "led_pink")
	_scaffold(Vector3(15, 0, -22), 8.0)
	course.gate(geo, Vector3(15, 8.02, -22), W, 1, 0.0, 0, "led_blue")
	course.gate(geo, Vector3(-12, 0.02, -22), W, 2, 0.0, 0, "led_orange")
	course.hurdle(geo, Vector3(-38, 0.02, -12), S, "led_green")
	course.gate(geo, Vector3(-50, 0.02, 6), S, 1, 0.0, 0, "led_pink")
	# Last: a gate hung from the roof between two trusses - left turn out
	# of the pink gate, climb through it, drop back down to START.
	course.hanging_gate(geo, Vector3(-42, 3.4, 20), E, 18.2, "led_blue")

func after_build() -> void:
	course.setup("race_arena", drone, ui)

## A square tunnel, 3 m inside, open at both ends.
func _tunnel(a: Vector3, b: Vector3) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var length: float = a.distance_to(b)
	geo.box(mid + Vector3(0, 3.2, 0), Vector3(length, 0.3, 3.6), "tunnel")
	for dz in [-1.65, 1.65]:
		geo.box(mid + Vector3(0, 1.6, dz), Vector3(length, 3.2, 0.3), "tunnel")
	for i in range(5):
		geo.box(mid + Vector3(-length * 0.5 + 2 + i * 4, 3.0, 0), Vector3(0.3, 0.08, 2.8), "led_green", 0.0, false, false)

## Scaffold tower carrying a gate `h` up: posts, braces, deck.
func _scaffold(o: Vector3, h: float) -> void:
	for dx in [-1.5, 1.5]:
		for dz in [-1.5, 1.5]:
			geo.box(o + Vector3(dx, h * 0.5, dz), Vector3(0.1, h, 0.1), "truss")
	for y in [2.0, 4.0, 6.0]:
		for dz in [-1.5, 1.5]:
			geo.beam(o + Vector3(-1.5, y - 2.0, dz), o + Vector3(1.5, y, dz), Vector2(0.06, 0.06), "truss")
	geo.box(o + Vector3(0, h - 0.05, 0), Vector3(3.3, 0.1, 3.3), "truss")
