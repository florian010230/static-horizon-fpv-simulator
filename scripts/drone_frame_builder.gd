class_name DroneFrameBuilder
extends RefCounted

## Builds the quad models from code (no external model files, like the
## rest of the project), shared by the flying Drone and the main menu's
## turntable preview.
##
## Freestyle quads (Static Three, Static Five), after a typical 5" true-X
## build: a carbon bottom plate with four arms and motor pads, a smaller
## top plate on aluminium standoffs, the flight-controller stack between
## them, the FPV camera in TPU side plates tilted up 25 deg, a LiPo strapped
## on top with its XT60 lead, the VTX antenna on a TPU mount at the back
## and the receiver's two whip antennas, motors (base, stator gap,
## anodised bell, prop nut) and 3-blade props with real blade pitch.
## Static Whoop (a 75 mm brushless ducted whoop): one-piece frame with
## closed ducts (thin wall, flared top lip, inner floor lip), braces from
## each motor mount to its duct and bridges between neighbouring ducts,
## an angular canopy with the camera behind its front window, the 1S
## pack in a holder behind it, a copper-pipe antenna, 3-blade 41 mm props.
##
## Everything of one material is merged into one mesh (a dozen draw calls
## per quad), lit by shaders/drone_studio.gdshader.
##
## profile keys: arm_length, body_radius, body_height, arm_thickness,
## motor_radius, motor_height, prop_radius, has_prop_guards, frame_color.

static var _weave: ImageTexture
static var _shader: Shader
static var _shader_alpha: Shader

static func build(parent: Node3D, profile: Dictionary) -> void:
	var b := {}
	if profile.has_prop_guards:
		_whoop(b, profile)
	else:
		_freestyle(b, profile)
	var accent: Color = profile.frame_color
	var mats := {
		"carbon": [Color(0.27, 0.27, 0.29), 0.0, 0.6, true],
		"accent": [accent, 0.0, 0.35, false],
		"anodised": [profile.get("bell_color", accent.darkened(0.15)), 0.85, 0.75, false],
		"metal": [Color(0.62, 0.63, 0.66), 0.9, 0.8, false],
		"dark": [Color(0.07, 0.07, 0.08), 0.1, 0.4, false],
		"board": [Color(0.06, 0.16, 0.1), 0.2, 0.6, false],
		"battery": [Color(0.12, 0.12, 0.13), 0.0, 0.5, false],
		"label": [Color(0.95, 0.74, 0.08), 0.0, 0.5, false],
		"strap": [Color(0.75, 0.08, 0.08), 0.0, 0.2, false],
		"lens": [Color(0.04, 0.08, 0.14), 0.3, 1.0, false],
		"copper": [Color(0.72, 0.42, 0.2), 0.9, 0.7, false],
		"led": [Color(0.3, 0.9, 1.0), 0.0, 0.2, false],
		"plastic": [accent.lerp(Color.WHITE, 0.12), 0.0, 0.55, false],
		"duct": [accent.lerp(Color.WHITE, 0.06), 0.0, 0.55, false],
		"prop": [profile.get("prop_color", Color(accent.lerp(Color.WHITE, 0.25), 0.78)), 0.0, 0.7, false],
	}
	for key in b:
		var st: SurfaceTool = b[key]
		var mi := MeshInstance3D.new()
		mi.name = key.capitalize()
		mi.mesh = st.commit()
		var m: Array = mats[key]
		mi.material_override = _material(m[0], m[1], m[2], m[3])
		parent.add_child(mi)

static func _material(c: Color, metallic: float, gloss: float, weave: bool) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/drone_studio.gdshader")
		_shader_alpha = Shader.new()
		_shader_alpha.code = _shader.code.replace("render_mode unshaded,", "render_mode unshaded, blend_mix, depth_draw_opaque,").replace("// ALPHA_LINE", "ALPHA = albedo.a; //")
	var m := ShaderMaterial.new()
	m.shader = _shader_alpha if c.a < 0.99 else _shader
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("gloss", gloss)
	if weave:
		m.set_shader_parameter("use_weave", true)
		m.set_shader_parameter("weave", _weave_tex())
	return m

## Carbon twill: 2x2 diagonal weave, dark with lighter tow highlights.
static func _weave_tex() -> ImageTexture:
	if _weave:
		return _weave
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in range(32):
		for x in range(32):
			var cell: int = (int(x / 4) + int(y / 4)) % 4
			var along: float = float((x if cell < 2 else y) % 4) / 4.0
			var v: float = 0.55 + 0.45 * sin(along * PI) * (1.0 if cell < 2 else 0.8)
			img.set_pixel(x, y, Color(v, v, v * 1.04))
	img.generate_mipmaps()
	_weave = ImageTexture.create_from_image(img)
	return _weave

static func _st(b: Dictionary, key: String) -> SurfaceTool:
	if not b.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[key] = st
	return b[key]

# --- the freestyle quad ------------------------------------------------------------

static func _freestyle(b: Dictionary, p: Dictionary) -> void:
	var L: float = p.arm_length
	var s: float = L / 0.08 # sizes below are a 5" build's, scaled
	var race: bool = p.get("race", false)
	var t_bot: float = 0.005 * s
	# Race frames are low: short standoffs, the pack hung underneath.
	var y_top: float = t_bot + (0.02 if race else 0.026) * s
	var motors: Array[Vector3] = [Vector3(L, 0, -L), Vector3(-L, 0, -L), Vector3(L, 0, L), Vector3(-L, 0, L)]
	# Bottom plate: body and four tapered arms ending in round motor pads.
	_extrude(_st(b, "carbon"), Transform3D(), _rounded_rect(0.024 * s, 0.05 * s, 0.008 * s), 0.0, t_bot)
	var mr: float = p.motor_radius * 0.85
	for m in motors:
		var dir := Vector2(m.x, m.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var root: Vector2 = dir * 0.012 * s
		var tip := Vector2(m.x, m.z)
		var poly: Array[Vector2] = [root + side * 0.0095 * s, tip + side * mr * 0.72, tip - side * mr * 0.72, root - side * 0.0095 * s]
		_extrude(_st(b, "carbon"), Transform3D(), poly, 0.0, t_bot)
		_extrude(_st(b, "carbon"), Transform3D(Basis(), Vector3(m.x, 0, m.z)), _circle(mr * 1.15, 14), 0.0, t_bot)
	# Top plate on four standoffs, the stack between the plates.
	_extrude(_st(b, "carbon"), Transform3D(), _rounded_rect(0.021 * s, 0.042 * s, 0.006 * s), y_top, y_top + 0.002 * s)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_cyl(_st(b, "anodised"), Transform3D(Basis(), Vector3(c.x * 0.017 * s, t_bot, c.y * 0.034 * s)), 0.0025 * s, 0.0025 * s, y_top - t_bot, 8)
	for k in range(2):
		_box(_st(b, "board"), Transform3D(Basis(), Vector3(0, t_bot + 0.006 * s + k * 0.009 * s, 0.006 * s)), Vector3(0.03 * s, 0.0016 * s, 0.03 * s))
	_cyl(_st(b, "dark"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, t_bot + 0.012 * s, 0.034 * s)), 0.004 * s, 0.004 * s, 0.014 * s, 10)
	# FPV camera between TPU side plates at the front, tilted up.
	# Racers fly a steeper camera (40-50 deg) than freestyle (25-35).
	var cam := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(45.0 if race else 25.0)), Vector3(0, t_bot + 0.011 * s, -0.04 * s))
	_box(_st(b, "dark"), cam, Vector3(0.019 * s, 0.019 * s, 0.018 * s))
	_cyl(_st(b, "dark"), cam * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.009 * s)), 0.0075 * s, 0.0065 * s, 0.009 * s, 14)
	_cyl(_st(b, "lens"), cam * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.0182 * s)), 0.0052 * s, 0.0052 * s, 0.0008 * s, 14)
	_cyl(_st(b, "metal"), cam * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.0165 * s)), 0.0078 * s, 0.0074 * s, 0.0016 * s, 14)
	for sx in [-1.0, 1.0]:
		_box(_st(b, "accent"), Transform3D(Basis(), Vector3(sx * 0.0115 * s, t_bot + 0.013 * s, -0.04 * s)), Vector3(0.003 * s, 0.024 * s, 0.022 * s))
	# LiPo on the top plate: wrap, label band, strap, XT60 lead out back.
	var bat := Vector3(0.036 * s, 0.033 * s, 0.074 * s)
	var bat_y: float = y_top + 0.002 * s
	if race:
		bat = Vector3(0.034 * s, 0.029 * s, 0.07 * s)
		bat_y = -bat.y - 0.001 * s # strapped under the bottom plate
	# Rounded pack: a slimmer core and four edge rods along its length.
	var rr: float = 0.004 * s
	_box(_st(b, "battery"), Transform3D(Basis(), Vector3(0, bat_y + bat.y * 0.5, 0.004 * s)), Vector3(bat.x - 2 * rr, bat.y, bat.z))
	_box(_st(b, "battery"), Transform3D(Basis(), Vector3(0, bat_y + bat.y * 0.5, 0.004 * s)), Vector3(bat.x, bat.y - 2 * rr, bat.z))
	for ex in [-1.0, 1.0]:
		for ey in [0.0, 1.0]:
			_cyl(_st(b, "battery"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(ex * (bat.x * 0.5 - rr), bat_y + rr + ey * (bat.y - 2 * rr), 0.004 * s - bat.z * 0.5)), rr, rr, bat.z, 8)
	_box(_st(b, "label"), Transform3D(Basis(), Vector3(0, bat_y + bat.y * 0.5, 0.004 * s)), Vector3(bat.x + 0.0006 * s, bat.y * 0.42, bat.z * 0.62))
	for dz in [-0.018, 0.022]:
		_box(_st(b, "strap"), Transform3D(Basis(), Vector3(0, bat_y + bat.y * 0.5, dz * s)), Vector3(bat.x + 0.002 * s, bat.y + 0.002 * s, 0.012 * s))
	_cyl(_st(b, "dark"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.008 * s, bat_y + 0.02 * s, 0.041 * s)), 0.0025 * s, 0.0025 * s, 0.018 * s, 6)
	_box(_st(b, "label"), Transform3D(Basis(), Vector3(0.008 * s, bat_y + 0.02 * s, 0.062 * s)), Vector3(0.016 * s, 0.008 * s, 0.006 * s))
	# A small LED strip under the rear of the plate.
	_box(_st(b, "led"), Transform3D(Basis(), Vector3(0, -0.001 * s, 0.045 * s)), Vector3(0.02 * s, 0.002 * s, 0.004 * s))
	# Antennas: VTX on a TPU mount at the back, receiver whips in a V.
	var ant := Vector3(0, y_top, 0.05 * s)
	_box(_st(b, "accent"), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(25.0)), ant + Vector3(0, 0.004 * s, 0)), Vector3(0.012 * s, 0.01 * s, 0.008 * s))
	# (+x rotation tips the antenna toward +z, the back of the quad.)
	var whip := Basis(Vector3.RIGHT, deg_to_rad(8.0 if race else 25.0))
	_cyl(_st(b, "dark"), Transform3D(whip, ant + Vector3(0, 0.008 * s, 0)), 0.0016 * s, 0.0016 * s, 0.05 * s, 6)
	_cyl(_st(b, "accent"), Transform3D(whip, ant + Vector3(0, 0.008 * s, 0) + whip * Vector3(0, 0.05 * s, 0)), 0.004 * s, 0.003 * s, 0.012 * s, 10)
	for sx in [-1.0, 1.0]:
		var v := Basis(Vector3.FORWARD, sx * deg_to_rad(40.0)) * Basis(Vector3.RIGHT, deg_to_rad(60.0))
		_cyl(_st(b, "dark"), Transform3D(v, Vector3(sx * 0.008 * s, t_bot + 0.004 * s, 0.045 * s)), 0.0007 * s, 0.0007 * s, 0.035 * s, 4)
	for i in range(4):
		_motor(b, motors[i] + Vector3(0, t_bot, 0), mr, p.motor_height * 0.85, p.prop_radius, 3, -1.0 if i == 0 or i == 3 else 1.0)

## Motor on its pad: base, stator gap, anodised bell, shaft and prop nut;
## then the prop with `blades` blades, spinning direction `dir`.
static func _motor(b: Dictionary, pos: Vector3, r: float, h: float, prop_r: float, blades: int, dir: float) -> void:
	_cyl(_st(b, "dark"), Transform3D(Basis(), pos), r, r, h * 0.3, 16)
	# The stator's copper windings show in the gap under the bell.
	_cyl(_st(b, "copper"), Transform3D(Basis(), pos + Vector3(0, h * 0.3, 0)), r * 0.9, r * 0.9, h * 0.08, 16)
	_cyl(_st(b, "anodised"), Transform3D(Basis(), pos + Vector3(0, h * 0.38, 0)), r, r * 0.9, h * 0.5, 16)
	# Bell top: dark centre with five bright spokes (the cut-outs that
	# cool a real bell).
	_cyl(_st(b, "dark"), Transform3D(Basis(), pos + Vector3(0, h * 0.88, 0)), r * 0.9, r * 0.7, h * 0.08, 16)
	for k in range(5):
		var a5: float = TAU * k / 5.0
		_box(_st(b, "anodised"), Transform3D(Basis(Vector3.UP, a5), pos + Vector3(0, h * 0.93, 0) + Vector3(cos(a5), 0, -sin(a5)) * r * 0.45), Vector3(r * 0.8, h * 0.06, r * 0.2))
	_cyl(_st(b, "metal"), Transform3D(Basis(), pos + Vector3(0, h, 0)), r * 0.16, r * 0.16, h * 0.55, 8)
	var hub := pos + Vector3(0, h * 1.04, 0)
	_cyl(_st(b, "prop"), Transform3D(Basis(), hub), prop_r * 0.12, prop_r * 0.1, h * 0.28, 12)
	_cyl(_st(b, "metal"), Transform3D(Basis(), hub + Vector3(0, h * 0.28, 0)), r * 0.3, r * 0.22, h * 0.22, 6)
	for k in range(blades):
		var a: float = TAU * k / blades + (0.3 if dir > 0.0 else 0.9)
		# A blade outline in its own plane, pitched about its long axis.
		var blade: Array[Vector2] = []
		var n: int = 7
		for j in range(n + 1):
			var u: float = float(j) / n
			var w: float = prop_r * (0.2 - 0.09 * u) * (1.0 if j < n else 0.6)
			blade.append(Vector2(prop_r * (0.1 + 0.88 * u), w * 0.45))
		for j in range(n, -1, -1):
			var u2: float = float(j) / n
			var w2: float = prop_r * (0.2 - 0.09 * u2) * (1.0 if j < n else 0.6)
			blade.append(Vector2(prop_r * (0.1 + 0.88 * u2), -w2 * 0.55))
		var bx := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, dir * deg_to_rad(14.0))
		_extrude(_st(b, "prop"), Transform3D(bx, hub + Vector3(0, h * 0.14, 0)), blade, -prop_r * 0.006, prop_r * 0.006)

# --- the whoop ------------------------------------------------------------------------

static func _whoop(b: Dictionary, p: Dictionary) -> void:
	var L: float = p.arm_length
	var pr: float = p.prop_radius
	var mr: float = p.motor_radius
	var ri: float = pr + 0.0012           # duct inner radius: ~1 mm prop tip clearance
	var wall: float = 0.0009
	var dh: float = 0.0105                 # duct height
	var y0: float = -0.0015                # duct bottom (the props sit in its upper half)
	var motors: Array[Vector3] = [Vector3(L, 0, -L), Vector3(-L, 0, -L), Vector3(L, 0, L), Vector3(-L, 0, L)]
	for m in motors:
		var o: Vector3 = m + Vector3(0, y0, 0)
		# The duct: thin wall, a flared lip round the top, a narrow floor
		# lip inside at the bottom (stiffens it, and is what you land on).
		_ring(_st(b, "duct"), Transform3D(Basis(), o), ri + wall, ri, dh, 32)
		_ring(_st(b, "duct"), Transform3D(Basis(), o + Vector3(0, dh - 0.0008, 0)), ri + wall + 0.0012, ri, 0.0008, 32)
		_ring(_st(b, "duct"), Transform3D(Basis(), o), ri, ri - 0.0018, 0.0007, 32)
		# Motor mount: a ring under the motor, braced to the duct floor
		# by two struts at right angles to the arm.
		_cyl(_st(b, "duct"), Transform3D(Basis(), m + Vector3(0, -0.0016, 0)), mr * 1.35, mr * 1.35, 0.0014, 14)
		var radial := Vector3(m.x, 0, m.z).normalized()
		var across := Vector3(-radial.z, 0, radial.x)
		for sgn in [-1.0, 1.0]:
			var d: Vector3 = across * sgn
			_box(_st(b, "duct"), Transform3D(Basis.looking_at(d, Vector3.UP), m + d * (ri * 0.5 + mr * 0.5) + Vector3(0, -0.0012, 0)), Vector3(0.0016, 0.0011, ri - mr))
		# The arm from the centre plate out to the mount.
		_box(_st(b, "duct"), Transform3D(Basis.looking_at(radial, Vector3.UP), radial * (L * 1.414 * 0.5) + Vector3(0, -0.001, 0)), Vector3(0.0042, 0.0018, L * 1.414 - mr))
	# Bridges where neighbouring ducts meet (front pair, back pair, sides).
	for c in [Vector3(0, 0, -L), Vector3(0, 0, L), Vector3(-L, 0, 0), Vector3(L, 0, 0)]:
		var along := Vector3(1, 0, 0) if c.x == 0.0 else Vector3(0, 0, 1)
		var gap: float = 2.0 * L - 2.0 * (ri + wall)
		_box(_st(b, "duct"), Transform3D(Basis.looking_at(along, Vector3.UP), c + c.normalized() * (ri * 0.55) + Vector3(0, y0 + dh * 0.5, 0)), Vector3(0.0012, dh * 0.8, maxf(gap, 0.0) + 0.003))
	# Centre plate (the 5-in-1 board sits on it).
	_extrude(_st(b, "duct"), Transform3D(), _rounded_rect(0.0135, 0.0175, 0.003), -0.002, 0.0)
	_box(_st(b, "board"), Transform3D(Basis(), Vector3(0, 0.0007, 0)), Vector3(0.0205, 0.0012, 0.0205))
	# Canopy: an angular shell over the board, raked forward, the camera
	# behind an open front window.
	var shell: Array[Vector2] = [Vector2(0.004, 0.0), Vector2(0.002, 0.0115), Vector2(-0.008, 0.0135), Vector2(-0.0145, 0.0075), Vector2(-0.0155, 0.0)]
	_side_prism(_st(b, "accent"), Vector3(0, 0.001, 0), shell, 0.017)
	var cam := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(25.0)), Vector3(0, 0.0072, -0.0118))
	_box(_st(b, "dark"), cam, Vector3(0.0105, 0.0105, 0.007))
	_cyl(_st(b, "dark"), cam * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.0035)), 0.0042, 0.0038, 0.0035, 12)
	_cyl(_st(b, "lens"), cam * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.0071)), 0.003, 0.003, 0.0006, 12)
	# 1S pack in its holder behind the canopy, lead to the board.
	_box(_st(b, "duct"), Transform3D(Basis(), Vector3(0, 0.0015, 0.0115)), Vector3(0.014, 0.0025, 0.012))
	_box(_st(b, "battery"), Transform3D(Basis(), Vector3(0, 0.0066, 0.0122)), Vector3(0.0118, 0.0078, 0.0305))
	_box(_st(b, "label"), Transform3D(Basis(), Vector3(0, 0.0066, 0.0122)), Vector3(0.0121, 0.0042, 0.018))
	_cyl(_st(b, "strap"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.003, 0.004, -0.004)), 0.0009, 0.0009, 0.0035, 6)
	# Copper-pipe antenna standing at the back.
	_cyl(_st(b, "copper"), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(15.0)), Vector3(0, 0.0, 0.0165)), 0.0011, 0.0011, 0.016, 8)
	for i in range(4):
		_motor(b, motors[i] + Vector3(0, -0.0005, 0), mr, p.motor_height, pr * 0.97, 3, -1.0 if i == 0 or i == 3 else 1.0)

## A side-on outline (z, y) given thickness `width` across x - a shell
## like the whoop's canopy. Built straight from the points: no rotation
## needed.
static func _side_prism(st: SurfaceTool, at: Vector3, poly: Array, width: float) -> void:
	var pp := PackedVector2Array(poly)
	if Geometry2D.is_polygon_clockwise(pp):
		pp.reverse()
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pp)
	var hw: float = width * 0.5
	for k in range(0, tris.size(), 3):
		for idx in [tris[k], tris[k + 1], tris[k + 2]]:
			_vert(st, at + Vector3(hw, pp[idx].y, pp[idx].x), Vector3.RIGHT)
		for idx in [tris[k + 2], tris[k + 1], tris[k]]:
			_vert(st, at + Vector3(-hw, pp[idx].y, pp[idx].x), Vector3.LEFT)
	for i in range(pp.size()):
		var a2: Vector2 = pp[i]
		var c2: Vector2 = pp[(i + 1) % pp.size()]
		var e: Vector2 = c2 - a2
		var n := Vector3(0, -e.x, e.y).normalized()
		for v in [Vector3(-hw, a2.y, a2.x), Vector3(hw, a2.y, a2.x), Vector3(hw, c2.y, c2.x), Vector3(-hw, a2.y, a2.x), Vector3(hw, c2.y, c2.x), Vector3(-hw, c2.y, c2.x)]:
			_vert(st, at + v, n)

# --- shape helpers (local transform xf; normals from each face) --------------------------

static func _vert(st: SurfaceTool, p: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.add_vertex(p)

static func _quad(st: SurfaceTool, xf: Transform3D, a: Vector3, bb: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var wn: Vector3 = (xf.basis * n).normalized()
	for v in [a, bb, c, a, c, d]:
		_vert(st, xf * v, wn)

static func _box(st: SurfaceTool, xf: Transform3D, size: Vector3) -> void:
	var h: Vector3 = size * 0.5
	for ax in range(3):
		for sgn in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = sgn
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = h[(ax + 1) % 3]
			var v := Vector3.ZERO
			v[(ax + 2) % 3] = h[(ax + 2) % 3]
			var c: Vector3 = n * h[ax]
			_quad(st, xf, c - u - v, c + u - v, c + u + v, c - u + v, n)

## Tapered cylinder along local +Y from 0 to h, capped.
static func _cyl(st: SurfaceTool, xf: Transform3D, r0: float, r1: float, h: float, sides: int) -> void:
	var nb: Basis = xf.basis
	for i in range(sides):
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var slope: float = (r0 - r1) / maxf(h, 0.0001)
		var n0: Vector3 = (nb * (d0 + Vector3(0, slope, 0))).normalized()
		var n1: Vector3 = (nb * (d1 + Vector3(0, slope, 0))).normalized()
		var p00: Vector3 = xf * (d0 * r0)
		var p10: Vector3 = xf * (d1 * r0)
		var p01: Vector3 = xf * (d0 * r1 + Vector3(0, h, 0))
		var p11: Vector3 = xf * (d1 * r1 + Vector3(0, h, 0))
		for v in [[p00, n0], [p10, n1], [p11, n1], [p00, n0], [p11, n1], [p01, n0]]:
			_vert(st, v[0], v[1])
		var up: Vector3 = (nb * Vector3.UP).normalized()
		for v in [xf * Vector3(0, h, 0), p01, p11]:
			_vert(st, v, up)
		for v in [xf * Vector3.ZERO, p10, p00]:
			_vert(st, v, -up)

## A flat ring (duct): outer and inner walls, top and bottom.
static func _ring(st: SurfaceTool, xf: Transform3D, ro: float, ri: float, h: float, sides: int) -> void:
	for i in range(sides):
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var top := Vector3(0, h, 0)
		_quad(st, xf, d0 * ro, d1 * ro, d1 * ro + top, d0 * ro + top, (d0 + d1).normalized())
		_quad(st, xf, d0 * ri, d1 * ri, d1 * ri + top, d0 * ri + top, -(d0 + d1).normalized())
		_quad(st, xf, d0 * ri + top, d1 * ri + top, d1 * ro + top, d0 * ro + top, Vector3.UP)
		_quad(st, xf, d0 * ri, d1 * ri, d1 * ro, d0 * ro, Vector3.DOWN)

## Upper half of an ellipsoid (canopy).
static func _dome(st: SurfaceTool, xf: Transform3D, rx: float, ry: float, rz: float, rings: int, sides: int) -> void:
	var pt := func(i: int, j: int) -> Array:
		var th: float = PI * 0.5 * float(i) / rings
		var ph: float = TAU * float(j) / sides
		var d := Vector3(cos(th) * cos(ph), sin(th), cos(th) * sin(ph))
		return [xf * Vector3(d.x * rx, d.y * ry, d.z * rz), (xf.basis * Vector3(d.x / rx, d.y / ry, d.z / rz)).normalized()]
	for i in range(rings):
		for j in range(sides):
			var a: Array = pt.call(i, j)
			var bb: Array = pt.call(i, j + 1)
			var c: Array = pt.call(i + 1, j + 1)
			var d: Array = pt.call(i + 1, j)
			for v in [a, bb, c, a, c, d]:
				_vert(st, v[0], v[1])

## A polygon (x, z) extruded from y0 to y1.
static func _extrude(st: SurfaceTool, xf: Transform3D, poly: Array, y0: float, y1: float) -> void:
	var pp := PackedVector2Array(poly)
	if Geometry2D.is_polygon_clockwise(pp):
		pp.reverse()
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(pp)
	for k in range(0, tris.size(), 3):
		for idx in [tris[k], tris[k + 1], tris[k + 2]]:
			_vert(st, xf * Vector3(pp[idx].x, y1, pp[idx].y), (xf.basis * Vector3.UP).normalized())
		for idx in [tris[k + 2], tris[k + 1], tris[k]]:
			_vert(st, xf * Vector3(pp[idx].x, y0, pp[idx].y), (xf.basis * Vector3.DOWN).normalized())
	for i in range(pp.size()):
		var a: Vector2 = pp[i]
		var c: Vector2 = pp[(i + 1) % pp.size()]
		var e: Vector2 = c - a
		var n := Vector3(e.y, 0, -e.x).normalized()
		_quad(st, xf, Vector3(a.x, y0, a.y), Vector3(c.x, y0, c.y), Vector3(c.x, y1, c.y), Vector3(a.x, y1, a.y), -n)

static func _circle(r: float, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(n):
		out.append(Vector2(cos(TAU * i / n), sin(TAU * i / n)) * r)
	return out

static func _rounded_rect(hx: float, hz: float, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for c in [[Vector2(hx - r, hz - r), 0.0], [Vector2(-hx + r, hz - r), 0.5], [Vector2(-hx + r, -hz + r), 1.0], [Vector2(hx - r, -hz + r), 1.5]]:
		for k in range(4):
			var a: float = PI * (c[1] + 0.5 * k / 3.0)
			out.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return out
