extends BuiltMap

## Race Arena - an indoor league race in a dark exhibition hall
## (Medium performance): LED gates that light themselves (bloom on
## High), a scaffold tower gate, a tunnel, spectator stands.
## Hall 120 x 60 x 22 m. Course (fly order):
##   START (-30,20) east -> gate (0,20) -> tunnel (12..32, 20)
##   -> ladder top (48,5) north -> dive gate (40,-20)
##   -> scaffold gate 8 m up (15,-22) west -> double gate lower (-12,-22)
##   -> hurdle (-38,-12) south -> gate (-50,6) south -> START.

## Rebuilt 2026-10-10 for the race mode rework (6 tracks per race map,
## DEV_TODO "Race mode rework"): fixed hall furniture every track can use
## (ANCHORS) - a gallery along the south wall with the team pits under it,
## a lighting rig hung over the infield, the video wall on the east wall,
## the commentator booth by the stand; the tunnel and scaffold tower stay.
## Track 1 is the course below, unchanged; the infield stays clear for
## the other tracks' gates.
const HALL := AABB(Vector3(-60, 0, -30), Vector3(120, 22, 60))
const ANCHORS: Dictionary = {
	"tunnel": [Vector3(12, 0, 20), Vector3(32, 0, 20)], ## 3 m inside, open both ends
	"scaffold": Vector3(15, 0, -22), ## 3 x 3 m tower, deck at 8 m
	"gallery": Rect2(-50, 26, 100, 4), ## deck 6 m up on columns every 10 m; pits under it - fly under, over, or along
	"rig": AABB(Vector3(-10, 12, -12), Vector3(20, 0.6, 20)), ## square truss ring hung 12 m up - fly through its middle
	"screen": Vector3(59.6, 11, 0), ## video wall on the east wall, 24 x 9 m
	"booth": Vector3(48, 0, -27), ## commentator booth by the stand, 3.2 m tall
	"infield": Rect2(-30, -12, 60, 22), ## kept clear: gates of the other tracks (under the rig)
}

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
		["gallery", Vector3(-55, 3, 18), Vector3(0, 3, 28)],
		["rig", Vector3(-25, 14, 15), Vector3(0, 12, -2)],
		["screen", Vector3(20, 8, 0), Vector3(59.6, 11, 0)],
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
	geo.add_material("table", Geo.flat_mat(Color(0.85, 0.85, 0.83), 0.6))
	geo.add_material("glass", Geo.flat_mat(Color(0.1, 0.13, 0.16), 0.1, 0.5))

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

	_gallery()
	_rig()
	_screen()
	_booth()

	# The tunnel and the scaffold tower are the hall's (every track's).
	_tunnel(Vector3(12, 0, 20), Vector3(32, 0, 20))
	_scaffold(Vector3(15, 0, -22), 8.0)

func after_build() -> void:
	course = RaceCourse.make(self, tracks(), {"ao_height": 2.0})
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


## Gallery along the south wall: a deck 6 m up on steel columns, a
## railing, stairs at the west end; under it the team pits (tables,
## chairs, battery cases, a flight case or two).
func _gallery() -> void:
	var g: Rect2 = ANCHORS.gallery
	var y: float = 6.0
	geo.box(Vector3(g.get_center().x, y - 0.15, g.get_center().y), Vector3(g.size.x, 0.3, g.size.y), "truss")
	var x: float = g.position.x
	while x <= g.end.x + 0.1:
		geo.box(Vector3(x, (y - 0.3) * 0.5, g.position.y + 0.3), Vector3(0.4, y - 0.3, 0.4), "truss")
		x += 10.0
	geo.box(Vector3(g.get_center().x, y + 0.55, g.position.y + 0.05), Vector3(g.size.x, 0.08, 0.08), "truss")
	x = g.position.x
	while x <= g.end.x + 0.1:
		geo.box(Vector3(x, y + 0.27, g.position.y + 0.05), Vector3(0.06, 0.55, 0.06), "truss", 0.0, false)
		x += 2.5
	geo.box(Vector3(g.get_center().x, y + 0.05, g.position.y + 0.02), Vector3(g.size.x, 0.1, 0.06), "led_blue", 0.0, false, false)
	# Stairs at the west end, against the wall.
	for k in range(15):
		geo.box(Vector3(g.position.x - 1.5 - (14 - k) * 0.4, (0.4 + k * 0.4) * 0.5, g.end.y - 1.0), Vector3(0.4, 0.4 + k * 0.4, 1.6), "truss")
	# Pits under the deck.
	var r := RandomNumberGenerator.new()
	r.seed = 66
	for k in range(9):
		var px: float = g.position.x + 6.0 + k * 10.0
		var q := Vector3(px, 0, g.end.y - 1.4)
		geo.box(q + Vector3(0, 0.74, 0), Vector3(3.0, 0.06, 1.0), "table")
		for sx in [-1.4, 1.4]:
			geo.box(q + Vector3(sx, 0.36, 0), Vector3(0.06, 0.72, 0.9), "truss")
		for j in range(r.randi_range(1, 3)):
			geo.box(q + Vector3(r.randf_range(-1.0, 1.0), 0.77 + 0.1, r.randf_range(-0.2, 0.2)), Vector3(0.4, 0.2, 0.3), ["led_blue", "led_orange", "truss"][r.randi() % 3], r.randf_range(-0.4, 0.4))
		for c in range(2):
			var cp := q + Vector3(-0.8 + c * 1.6, 0, -1.2)
			geo.box(cp + Vector3(0, 0.23, 0), Vector3(0.45, 0.46, 0.45), "seat")
			geo.box(cp + Vector3(0, 0.75, -0.2), Vector3(0.45, 0.6, 0.06), "seat")
		if r.randf() < 0.6:
			geo.box(q + Vector3(2.2, 0.35, -0.4), Vector3(0.9, 0.7, 0.6), "wall") # flight case

## Lighting rig: a square box truss ring hung on four cables from the
## roof trusses, lamp cans under it.
func _rig() -> void:
	var a: AABB = ANCHORS.rig
	var y: float = a.position.y + 0.3
	var x0: float = a.position.x
	var x1: float = a.end.x
	var z0: float = a.position.z
	var z1: float = a.end.z
	for e: Array in [[Vector3(x0, y, z0), Vector3(x1, y, z0)], [Vector3(x0, y, z1), Vector3(x1, y, z1)],
			[Vector3(x0, y, z0), Vector3(x0, y, z1)], [Vector3(x1, y, z0), Vector3(x1, y, z1)]]:
		for oy in [-0.25, 0.25]:
			geo.beam(e[0] + Vector3(0, oy, 0), e[1] + Vector3(0, oy, 0), Vector2(0.08, 0.08), "truss")
		var d: Vector3 = e[1] - e[0]
		var n: int = int(d.length() / 1.0)
		for k in range(n + 1):
			var q: Vector3 = e[0] + d * (float(k) / n)
			geo.box(q, Vector3(0.05, 0.5, 0.05), "truss", 0.0, false)
	for cx in [x0, x1]:
		for cz in [z0, z1]:
			geo.beam(Vector3(cx, y + 0.25, cz), Vector3(cx, 22.0, cz), Vector2(0.03, 0.03), "truss", false) # (to the roof, between the trusses)
	for k in range(8):
		var t: float = (k + 0.5) / 8.0
		for q: Vector3 in [Vector3(lerpf(x0, x1, t), y - 0.25, z0), Vector3(lerpf(x0, x1, t), y - 0.25, z1)]:
			geo.cylinder(q + Vector3(0, -0.5, 0), q, 0.18, "truss", 8)
			geo.cylinder(q + Vector3(0, -0.52, 0), q + Vector3(0, -0.5, 0), 0.15, "lamp", 8, false, true, false)
	# Its own light: an LED band round the ring.
	for e: Array in [[Vector3((x0 + x1) * 0.5, y, z0), Vector3(x1 - x0, 0.1, 0.1)], [Vector3((x0 + x1) * 0.5, y, z1), Vector3(x1 - x0, 0.1, 0.1)],
			[Vector3(x0, y, (z0 + z1) * 0.5), Vector3(0.1, 0.1, z1 - z0)], [Vector3(x1, y, (z0 + z1) * 0.5), Vector3(0.1, 0.1, z1 - z0)]]:
		geo.box(e[0], e[1], "led_orange", 0.0, false, false)

## Video wall on the east wall: dark screen, the league's horizon mark.
func _screen() -> void:
	if not geo.has_material("screen"):
		geo.add_material("screen", Geo.glow_mat(Color(0.05, 0.1, 0.22), 0.8))
	var c: Vector3 = ANCHORS.screen
	geo.box(c + Vector3(0.15, 0, 0), Vector3(0.3, 9.6, 24.6), "wall", 0.0, false)
	geo.box(c, Vector3(0.1, 9.0, 24.0), "screen", 0.0, false, false)
	# The mark: a ring with the horizon line through it.
	for k in range(32):
		var a: float = TAU * k / 32.0
		geo.box(c + Vector3(-0.06, sin(a) * 3.0, cos(a) * 3.0), Vector3(0.04, 0.6, 0.6), "banner_o", -0.0, false, false)
	geo.box(c + Vector3(-0.07, 0, 0), Vector3(0.04, 0.35, 9.0), "banner", 0.0, false, false)

## Commentator booth by the stand: a glazed box on a plinth.
func _booth() -> void:
	var b: Vector3 = ANCHORS.booth
	geo.box(b + Vector3(0, 0.5, 0), Vector3(6.0, 1.0, 4.0), "wall")
	geo.box(b + Vector3(0, 2.6, -1.0), Vector3(6.0, 2.2, 2.0), "wall")
	geo.box(b + Vector3(0, 3.1, 0.0), Vector3(6.0, 0.2, 4.0), "wall")
	for sx in [-2.9, 2.9]:
		geo.box(b + Vector3(sx, 2.05, 1.0), Vector3(0.2, 2.1, 2.0), "wall")
	geo.box(b + Vector3(0, 1.05, 1.0), Vector3(5.6, 0.1, 1.6), "table", 0.0, false)
	geo.box(b + Vector3(0, 2.0, 1.9), Vector3(5.6, 1.9, 0.04), "glass", 0.0, false, false)
	geo.box(b + Vector3(0, 3.25, 2.05), Vector3(4.0, 0.4, 0.08), "banner", 0.0, false, false)

## The map's tracks (RaceCourse.make builds the one Settings.race_track
## picks, at load time on top of the cached map), easiest first: 2 easy,
## 2 medium, 2 hard (League Night, the old course, moved to medium: stacked
## top opening, a 6 m dive, the 8 m scaffold gate). Records follow "id".
## Yaw: -PI/2 flies east (+x), PI/2 west, 0 north (-z), PI south.
## Roof trusses run north-south at x -50, -33.3, -16.6, 0.2, 16.9, 33.6,
## 50.2: a gate hung from the roof flies east/west, halfway between two.
func tracks() -> Array:
	var E: float = -PI * 0.5
	var W: float = PI * 0.5
	var N: float = 0.0
	var S: float = PI
	var t1: Array = [
		["start", Vector3(-30, 0.02, 20), E],
		["gate", Vector3(0, 0.02, 20), E, 1, 0.0, 0, "led_blue"],
		["sized", Vector3(12.2, 0.02, 20), E, 2.6, 2.6, 0.15, 0.0, "led_green"], # tunnel mouth
		["gate", Vector3(48, 0.02, 5), N, 3, 0.0, 2, "led_orange"],
		["dive", Vector3(40, 0.02, -20), 0.0, 6.0, "led_pink"],
		["gate", Vector3(15, 8.02, -22), W, 1, 0.0, 0, "led_blue"], # on the scaffold
		["gate", Vector3(-12, 0.02, -22), W, 2, 0.0, 0, "led_orange"],
		["hurdle", Vector3(-38, 0.02, -12), S, "led_green"],
		["gate", Vector3(-50, 0.02, 6), S, 1, 0.0, 0, "led_pink"],
		# Last: a gate hung from the roof between two trusses - left turn out
		# of the pink gate, climb through it, drop back down to START.
		["hanging", Vector3(-42, 3.4, 20), E, 18.2, "led_blue"],
	]
	return [
		# Easy: a wide anticlockwise oval round the infield, ground gates only.
		{"id": "warm_up", "name": "Warm-Up Lap", "level": "easy", "calls": [
			["start", Vector3(-25, 0.02, 0), E],
			["gate", Vector3(5, 0.02, 0), E, 1, 0.0, 0, "led_blue"],
			["gate", Vector3(42, 0.02, -8), N, 1, 0.0, 0, "led_orange"],
			["gate", Vector3(25, 0.02, -16), W, 1, 0.0, 0, "led_green"],
			["gate", Vector3(-15, 0.02, -16), W, 1, 0.0, 0, "led_blue"],
			["gate", Vector3(-45, 0.02, -6), S, 1, 0.0, 0, "led_orange"],
			["gate", Vector3(-42, 0.02, 12), E, 1, 0.0, 0, "led_pink"],
		]},
		# Easy: east past the pits under the gallery, through the tunnel, home
		# along the stand.
		{"id": "pit_lane", "name": "Pit Lane", "level": "easy", "calls": [
			["start", Vector3(-40, 0.02, 12), E],
			["gate", Vector3(-15, 0.02, 22), E, 1, 0.0, 0, "led_blue"], # beside the gallery
			["sized", Vector3(12.2, 0.02, 20), E, 2.6, 2.6, 0.15, 0.0, "led_green"], # tunnel mouth
			["gate", Vector3(48, 0.02, 10), N, 1, 0.0, 0, "led_orange"],
			["gate", Vector3(40, 0.02, -15), W, 1, 0.0, 0, "led_pink"],
			["gate", Vector3(0, 0.02, -18), W, 1, 0.0, 0, "led_blue"],
			["gate", Vector3(-45, 0.02, -8), S, 1, 0.0, 0, "led_orange"],
		]},
		{"id": "league_night", "name": "League Night", "level": "medium", "calls": t1},
		# Medium: climb into the lighting rig (a gate hung under its middle,
		# 10.5 m up), a dive, round a flag onto the scaffold deck gate, round
		# a flag along the stand, the upper of a double gate, home.
		{"id": "spotlight", "name": "Spotlight", "level": "medium", "calls": [
			["start", Vector3(-32, 0.02, 0), E],
			["gate", Vector3(-18, 0.02, 0), E, 1, 0.0, 0, "led_blue"],
			["hanging", Vector3(0, 10.5, -2), E, 12.05, "led_orange", 20.1], # under the rig
			["dive", Vector3(22, 0.02, -5), 0.0, 5.0, "led_pink"],
			["turn", Vector3(42, 0.02, -12), N, "right"],
			["gate", Vector3(15, 8.02, -22), W, 1, 0.0, 0, "led_green"], # on the scaffold
			["turn", Vector3(-30, 0.02, -18), PI * 0.75, "right"],
			["gate", Vector3(-48, 0.02, -8), S, 2, 0.0, 1, "led_orange"], # double gate, upper
		]},
		# Hard: south, left under the gallery deck between its columns (a 3 m
		# gate over the pits), out and up over the deck rail (a gate hung
		# above the deck), the split-S ladder at the east end, round a flag,
		# a 6 m dive along the stand, a snake of three gates 8 m apart (two
		# hairpins, the gates yawed into the turns), home.
		{"id": "gallery_run", "name": "Gallery Run", "level": "hard", "calls": [
			["start", Vector3(-50, 0.02, 14), S],
			["turn", Vector3(-44.8, 0.02, 22.8), -PI * 0.75, "right"],
			["sized", Vector3(-28, 0.02, 28), E, 3.0, 3.0, 0.15, 1.5, "led_green"], # under the deck, over the pits
			["hanging", Vector3(8.5, 8.5, 27.5), E, 18.2, "led_blue"], # above the deck
			["ladder", Vector3(50, 0.02, -8), N, 3.5, "led_pink"],
			["turn", Vector3(46, 0.02, -16), PI * 0.25, "right"],
			["dive", Vector3(25, 0.02, -18), 0.0, 6.0, "led_orange"],
			["gate", Vector3(-36, 0.02, -14), W + 0.35, 1, 0.0, 0, "led_blue"], # snake: west, east, west
			["gate", Vector3(-36, 0.02, -6), E - 0.35, 1, 0.0, 0, "led_orange"],
			["gate", Vector3(-36, 0.02, 2), W + 0.35, 1, 0.0, 0, "led_green"],
		]},
		# Hard, a figure of eight: a hurdle, climb into the rig (the high
		# crossing), a gate on a 6 m pole in front of the video wall, round
		# a flag by the booth, the scaffold deck gate, a 6 m dive, back under
		# the rig low (the low crossing) into a snake of three gates (two
		# hairpins), the top of a triple stack, a flag in the U-turn home.
		{"id": "night_shift", "name": "Night Shift", "level": "hard", "calls": [
			["start", Vector3(-42, 0.02, -6), E],
			["hurdle", Vector3(-26, 0.02, -6), E, "led_orange"],
			["hanging", Vector3(0, 10.5, -2), E, 12.05, "led_green", 20.1], # under the rig: high crossing
			["gate", Vector3(54, 0.02, 0), N, 1, 6.0, 0, "led_blue"], # in front of the video wall
			["turn", Vector3(50, 0.02, -18), PI * 0.25, "right"],
			["gate", Vector3(15, 8.02, -22), W, 1, 0.0, 0, "led_pink"], # on the scaffold
			["dive", Vector3(-5, 0.02, -16), 0.0, 6.0, "led_orange"],
			["gate", Vector3(-6, 0.02, 4), S + 0.35, 1, 0.0, 0, "led_blue"], # low crossing; snake: south, north, south
			["gate", Vector3(-14, 0.02, 4), N - 0.35, 1, 0.0, 0, "led_orange"],
			["gate", Vector3(-22, 0.02, 4), S + 0.35, 1, 0.0, 0, "led_green"],
			["gate", Vector3(-34, 0.02, 13), W, 3, 0.0, 2, "led_pink"], # triple stack, top
			["turn", Vector3(-52, 0.02, 3.5), N, "left"],
		]},
	]
