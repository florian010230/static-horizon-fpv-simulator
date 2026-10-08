class_name TreeCreator
extends RefCounted

## Creator: garden and street trees - maple (one variant a copper
## beech), apple with fruit, birch, spruce and flowering bushes. Each species has VARIANTS seeded shapes; a tree is
## one of them, turned, scaled and tinted, so a street never repeats
## visibly. Now and then a tree holds something to find: a birdhouse, a
## tyre swing, a kite caught in the crown - or an FPV drone stuck in it,
## as happens to every pilot once.
##
##   TreeCreator.plant(map, geo, trees) -> {"kept": int, "extras": [[name, pos, eye], ...],
##                                          "placed": [[transform, shape key], ...]}
## trees: Array of [pos: Vector3, species: String ("" = garden mix),
##        seed: int, extra: String ("random" default, "none", or one of EXTRAS),
##        plain: bool (true = no odd variants such as the copper beech - woods),
##        size: float (1.0 default; scales the tree - tall woodland spruces)]
## Trees standing in something solid (geo.blocked) or on a road are
## dropped. Call it from build(), after the buildings.
##
## Cost: meshes are built once per species variant (cached for the whole
## game) and drawn as MultiMesh - one draw call per variant and 128 m
## chunk, with Forest's tree shader (lit in the shader, takes the
## sun shadow map). Beyond the near range a merged stand-in (a trunk and
## one blob) per 512 m chunk. Collision: trunk + crown cylinder.
## Sizes: garden maples 7-11 m, apple 4-5.5 m, birch 9-12 m, garden spruce 6-10 m, bushes 1-1.8 m.

const SPECIES := ["maple", "apple", "birch", "spruce", "bush"]
## The "" garden mix: relative weights.
const MIX := {"maple": 3.0, "apple": 2.0, "birch": 2.0, "spruce": 1.0, "bush": 3.0}
const VARIANTS: int = 3
const CHUNK: float = 128.0
const FAR_CHUNK: float = 512.0
const NEAR_RANGE: Array[float] = [140.0, 220.0, 320.0]
## Surprises: chance per tree of a species that can carry it.
const EXTRAS := {"birdhouse": 0.08, "swing": 0.05, "kite": 0.03, "drone": 0.025}
const EXTRA_ON := {"birdhouse": ["maple", "apple", "birch"], "swing": ["maple"],
	"kite": ["maple", "birch", "spruce"], "drone": ["maple", "birch", "spruce", "apple"]}
const COPPER_SHARE: float = 0.1 ## maples that are copper beeches (variant 2)
const PLAIN: float = 0.4 ## vertex alpha for plain colour (fruit, flowers) in tree.gdshader

const BARK := {"maple": Color(0.38, 0.33, 0.28), "apple": Color(0.4, 0.33, 0.26), "birch": Color(0.88, 0.87, 0.82),
	"spruce": Color(0.33, 0.25, 0.19), "bush": Color(0.3, 0.25, 0.2)}

## "species/variant" -> {near, far, trunk_h, trunk_r, crown (centre), crown_r, crown_h}
static var _variants: Dictionary = {}

static func plant(map: Node3D, geo: Geo, trees: Array) -> Dictionary:
	var holder := Node3D.new()
	holder.name = "Trees"
	map.add_child(holder)
	if not geo.has_material("trc_paint"):
		geo.add_material("trc_paint", Geo.flat_mat(Color.WHITE, 0.6))
		geo.add_material("trc_glow", Geo.glow_mat(Color(0.2, 1.0, 0.3), 2.0))
		geo.detail_prefixes.append("trc_")
	var near_range: float = NEAR_RANGE[clampi(Settings.graphics_quality, 0, 2)]
	var chunks: Dictionary = {}
	var far: Dictionary = {}
	var extras: Array = []
	var placed: Array = [] # [transform, shape key] per tree
	var kept: int = 0
	var rng := RandomNumberGenerator.new()
	for t: Array in trees:
		var p: Vector3 = t[0]
		rng.seed = t[2] if t.size() > 2 else hash(p)
		var sp: String = t[1] if t.size() > 1 and t[1] != "" else _mix(rng)
		var vi: int = rng.randi() % VARIANTS
		var plain: bool = t.size() > 4 and t[4]
		if sp == "maple" and vi == 2 and (plain or rng.randf() > COPPER_SHARE * VARIANTS):
			vi = rng.randi() % 2 # the copper beech is the odd one out, not every third tree
		var v: Dictionary = _variant(sp, vi)
		# 5 % steps, the same the collision shapes are shared by - so the
		# hitbox is exactly the drawn tree.
		var sc: float = snappedf(rng.randf_range(0.85, 1.12) * (float(t[5]) if t.size() > 5 else 1.0), 0.05)
		var q := Vector2(p.x, p.z)
		if geo.blocked(q, v.trunk_r * sc + 0.15, p.y + 0.3, p.y + v.trunk_h * sc) or geo.on_lane(q, 1.0):
			continue
		if sp != "bush" and geo.blocked(q, v.crown_r * sc * 0.6, p.y + (v.crown.y - v.crown_h * 0.4) * sc, p.y + (v.crown.y + v.crown_h * 0.5) * sc):
			continue
		# On a slope the trunk's downhill side would stand in the air: the
		# tree goes down until its foot reaches into the ground all round.
		var tr: float = v.trunk_r * sc
		p.y = geo.sunk([p, p + Vector3(tr, 0, 0), p - Vector3(tr, 0, 0), p + Vector3(0, 0, tr), p - Vector3(0, 0, tr)], p.y)
		kept += 1
		placed.append([Transform3D(Basis(Vector3.UP, 0.0), p), v.key])
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p)
		placed[-1][0] = xf
		var tint: float = rng.randf_range(0.88, 1.1)
		var col := Color(tint * rng.randf_range(0.95, 1.05), tint, tint * rng.randf_range(0.92, 1.04))
		var key := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
		var vk: String = v.key
		if not chunks.has(key):
			chunks[key] = {}
		if not chunks[key].has(vk):
			chunks[key][vk] = []
		chunks[key][vk].append([xf, col, v])
		var fk := Vector2i(floori(p.x / FAR_CHUNK), floori(p.z / FAR_CHUNK))
		if v.far != null:
			if not far.has(fk):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				far[fk] = st
			far[fk].append_from(v.far, 0, xf)
		# Footprint: later scatter avoids the tree, and things hung on it
		# count as attached.
		geo.reserve(q, Vector2(1, 0), Vector2.ONE * v.trunk_r * sc, p.y, p.y + v.trunk_h * sc)
		var extra: String = t[3] if t.size() > 3 else "random"
		if extra == "random":
			extra = "none"
			for e: String in EXTRAS:
				if sp in EXTRA_ON[e] and rng.randf() < EXTRAS[e]:
					extra = e
					break
		if extra != "none" and sp in EXTRA_ON.get(extra, []):
			var spot: Array = _extra(geo, xf, v, extra, rng)
			extras.append([extra, spot[0], spot[1]])
	for key in chunks:
		var body := StaticBody3D.new()
		holder.add_child(body)
		for vk in chunks[key]:
			var list: Array = chunks[key][vk]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = (list[0][2] as Dictionary).near
			mm.instance_count = list.size()
			for i in range(list.size()):
				mm.set_instance_transform(i, list[i][0])
				mm.set_instance_color(i, list[i][1])
				_collider(body, list[i][0], list[i][2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			# Coarse cut per chunk; the shader cuts each tree at near_range
			# (see Forest.near_material).
			mmi.material_override = Forest.near_material()
			mmi.visibility_range_end = near_range + Forest.CHUNK_SLACK
			mmi.visibility_range_end_margin = 20.0
			mmi.set_meta("geo_detail", true)
			holder.add_child(mmi)
	for fk in far:
		var mesh: ArrayMesh = far[fk].commit()
		mesh.surface_set_material(0, Forest._material())
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		# Always drawn (a range begin measured from the 512 m chunk's centre
		# hid them while the full trees were already cut - bare gardens);
		# the stand-ins sit inside the full crowns.
		mi.set_meta("geo_detail", true)
		holder.add_child(mi)
	return {"kept": kept, "extras": extras, "placed": placed}

static func _mix(rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for k: String in MIX:
		total += MIX[k]
	var r: float = rng.randf() * total
	for k: String in MIX:
		r -= MIX[k]
		if r <= 0.0:
			return k
	return "maple"

## Collision from the drawn shapes themselves: a convex hull per leaf
## mass (its own jittered points), a tapered prism along each trunk's
## real (leaning) axis, a cone over a spruce's tiers. Shapes are shared
## per shape variant and 5 % scale step; one shape owner per tree,
## turned with it (a cylinder round the crown hit air at its corners and
## let you through the leaves elsewhere).
static var _shapes: Dictionary = {}

static func _collider(body: StaticBody3D, xf: Transform3D, v: Dictionary) -> void:
	var sc: float = snappedf(xf.basis.get_scale().x, 0.05)
	var key: String = "%s@%.2f" % [v.key, sc]
	if not _shapes.has(key):
		var list: Array = []
		for pts: PackedVector3Array in v.hulls:
			var sp := ConvexPolygonShape3D.new()
			var scaled := PackedVector3Array()
			for q: Vector3 in pts:
				scaled.append(q * sc)
			sp.points = scaled
			list.append(sp)
		_shapes[key] = list
	var owner: int = body.create_shape_owner(body)
	for sh: Shape3D in _shapes[key]:
		body.shape_owner_add_shape(owner, sh)
	body.shape_owner_set_transform(owner, Transform3D(xf.basis.orthonormalized(), xf.origin))

# --- meshes ------------------------------------------------------------------
# SurfaceTool, Forest's vertex conventions: colour = species colour x
# ambient occlusion; alpha 1 foliage, 0 bark, PLAIN for fruit/flowers.

static func _variant(sp: String, idx: int) -> Dictionary:
	var key: String = "%s/%d" % [sp, idx]
	if _variants.has(key):
		return _variants[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7100 + SPECIES.find(sp) * 37 + idx
	var v: Dictionary = {"key": key}
	_hulls = []
	match sp:
		"maple":
			_maple(st, rng, v, idx)
		"apple":
			_apple(st, rng, v, idx)
		"birch":
			_birch(st, rng, v)
		"spruce":
			_spruce(st, rng, v)
		"bush":
			_bush(st, rng, v, idx)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, Forest._material())
	v.near = mesh
	v.hulls = _hulls
	_hulls = [] # the stand-in's blob is no collision shape
	v.far = null if sp == "bush" else _far(sp, v)
	_variants[key] = v
	return v

static func _maple(st: SurfaceTool, rng: RandomNumberGenerator, v: Dictionary, idx: int) -> void:
	var h: float = rng.randf_range(7.5, 10.5)
	var fork: float = rng.randf_range(2.2, 3.0)
	var r0: float = rng.randf_range(0.28, 0.38)
	var cr: float = rng.randf_range(2.9, 3.7)
	# Variant 2 is a copper beech: dark red-brown leaves.
	var leaf: Color = Color(0.36, 0.15, 0.12) if idx == 2 else Color(0.26, 0.4, 0.14).lerp(Color(0.32, 0.44, 0.16), rng.randf())
	var cy: float = fork + (h - fork) * 0.52
	var centre := Vector3(0, cy, 0)
	_set_dims(v, fork + 0.6, r0, centre, cr, h - fork + 0.5)
	_stem(st, v, Vector3.ZERO, Vector3(0, fork + 0.8, 0), r0, r0 * 0.6, BARK.maple)
	_mass(st, centre, Vector3(cr * 0.72, (h - fork) * 0.38, cr * 0.72), leaf, centre, h - fork, cr, rng)
	var n: int = rng.randi_range(5, 6)
	for i in range(n):
		var a: float = TAU * i / n + rng.randf_range(-0.35, 0.35)
		var out: float = cr * rng.randf_range(0.5, 0.68)
		var tip := Vector3(cos(a) * out, rng.randf_range(cy - 0.6, cy + 1.3), sin(a) * out)
		Forest._trunk(st, Vector3(0, fork + rng.randf_range(0.0, 0.6), 0), tip * Vector3(0.85, 0.95, 0.85), r0 * 0.45, 0.06, BARK.maple)
		_mass(st, tip * Vector3(1.15, 1.0, 1.15), Vector3.ONE * cr * rng.randf_range(0.46, 0.6), leaf, centre, h - fork, cr, rng)
	_mass(st, Vector3(rng.randf_range(-0.4, 0.4), h - cr * 0.45, rng.randf_range(-0.4, 0.4)), Vector3.ONE * cr * 0.5, leaf, centre, h - fork, cr, rng)

static func _apple(st: SurfaceTool, rng: RandomNumberGenerator, v: Dictionary, idx: int) -> void:
	var h: float = rng.randf_range(4.0, 5.4)
	var fork: float = rng.randf_range(1.3, 1.7)
	var cr: float = rng.randf_range(2.3, 2.9)
	var lean := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	var leaf := Color(0.3, 0.42, 0.15)
	var fruit: Color = [Color(0.85, 0.12, 0.08), Color(0.8, 0.2, 0.1), Color(0.72, 0.8, 0.22)][idx]
	var cy: float = fork + (h - fork) * 0.5
	var centre := Vector3(lean.x, cy, lean.z)
	_set_dims(v, fork + 0.4, 0.18, centre, cr, h - fork + 0.4)
	_stem(st, v, Vector3.ZERO, Vector3(lean.x, fork, lean.z), 0.2, 0.15, BARK.apple)
	var masses: Array[PackedVector3Array] = []
	var n: int = rng.randi_range(5, 7)
	for i in range(n):
		var a: float = TAU * i / n + rng.randf_range(-0.3, 0.3)
		var out: float = cr * rng.randf_range(0.55, 0.8)
		var tip := centre + Vector3(cos(a) * out, rng.randf_range(-0.5, 0.9), sin(a) * out)
		Forest._trunk(st, Vector3(lean.x, fork, lean.z), tip * Vector3(0.9, 0.97, 0.9), 0.1, 0.04, BARK.apple, 5)
		masses.append(_mass(st, tip, Vector3(1.0, 0.8, 1.0) * rng.randf_range(0.95, 1.3), leaf, centre, h - fork, cr, rng))
	_mass(st, centre + Vector3(0, 0.8, 0), Vector3(1.3, 0.9, 1.3), leaf, centre, h - fork, cr, rng)
	# Fruit on the leaves' surface: centred just inside one of a mass's
	# own corner points, so every apple is half in the leaves, half out.
	for i in range(rng.randi_range(26, 38)):
		_dot(st, _on(masses[rng.randi() % masses.size()], rng, 0.985), 0.075, fruit, rng)

static func _birch(st: SurfaceTool, rng: RandomNumberGenerator, v: Dictionary) -> void:
	var h: float = rng.randf_range(9.0, 12.0)
	var top := Vector3(rng.randf_range(-0.5, 0.5), h, rng.randf_range(-0.5, 0.5))
	var leaf := Color(0.38, 0.5, 0.18)
	var centre := Vector3(top.x * 0.6, h * 0.66, top.z * 0.6)
	_set_dims(v, h * 0.45, 0.17, centre, 2.1, h * 0.62)
	_stem(st, v, Vector3.ZERO, top, 0.18, 0.04, BARK.birch)
	var n: int = rng.randi_range(11, 13)
	for i in range(n):
		var f: float = float(i) / (n - 1)
		var y: float = lerpf(h * 0.4, h - 0.5, f)
		var a: float = i * 2.4 + rng.randf_range(-0.3, 0.3)
		# Widest a third of the way up, a loose open crown.
		var out: float = lerpf(1.2, 1.9, sin(minf(f * 1.6, 1.0) * PI * 0.5)) * (1.0 - f * 0.65) * rng.randf_range(0.85, 1.15)
		var on: Vector3 = top * (y / h)
		var c: Vector3 = on + Vector3(cos(a) * out, -0.3, sin(a) * out)
		Forest._trunk(st, on, c, 0.05, 0.02, BARK.birch, 4)
		# Drooping: taller than wide, hanging below the branch.
		_mass(st, c + Vector3(0, -0.35, 0), Vector3(0.85, 1.15, 0.85) * lerpf(1.1, 0.6, f), leaf, centre, h * 0.62, 2.1, rng)

static func _spruce(st: SurfaceTool, rng: RandomNumberGenerator, v: Dictionary) -> void:
	var h: float = rng.randf_range(6.0, 10.0)
	var r: float = h * rng.randf_range(0.22, 0.27)
	var leaf := Color(0.14, 0.27, 0.16)
	_set_dims(v, 1.2, 0.2, Vector3(0, h * 0.5, 0), r, h - 0.6)
	_stem(st, v, Vector3.ZERO, Vector3(0, 1.6, 0), 0.22, 0.19, BARK.spruce)
	Forest._trunk(st, Vector3(0, 1.6, 0), Vector3(0, h, 0), 0.19, 0.04, BARK.spruce)
	var tiers: int = int(h * 0.9)
	var cone := PackedVector3Array()
	for i in range(tiers):
		var f: float = float(i) / (tiers - 1)
		var y: float = lerpf(0.9, h - 1.2, f)
		var tr: float = lerpf(r, r * 0.25, f) * rng.randf_range(0.9, 1.08)
		var droop: float = lerpf(0.6, 0.25, f)
		Forest._skirt(st, y, y + lerpf(1.7, 1.2, f), tr, 8, rng.randf() * TAU, droop, leaf, f, rng)
		# Collision: a ring a little inside the branch tips (between tips
		# the skirt is cut back), at the drooped tip height.
		for k in range(8):
			var ang: float = TAU * k / 8.0
			cone.append(Vector3(cos(ang) * tr * 0.8, y - droop, sin(ang) * tr * 0.8))
	Forest._skirt(st, h - 0.5, h + 0.6, 0.35, 6, 0.0, 0.15, leaf, 1.0, rng)
	cone.append(Vector3(0, h + 0.5, 0))
	_hulls.append(cone)

static func _bush(st: SurfaceTool, rng: RandomNumberGenerator, v: Dictionary, idx: int) -> void:
	var h: float = rng.randf_range(1.0, 1.8)
	var r: float = rng.randf_range(0.7, 1.1)
	var leaf: Color = Color(0.2, 0.36, 0.13) if idx != 1 else Color(0.16, 0.3, 0.12)
	var centre := Vector3(0, h * 0.5, 0)
	_set_dims(v, 0.4, 0.1, centre, r, h)
	Forest._trunk(st, Vector3.ZERO, Vector3(0, 0.4, 0), 0.06, 0.04, BARK.bush, 4)
	var masses: Array[PackedVector3Array] = []
	var n: int = rng.randi_range(4, 6)
	for i in range(n):
		var a: float = TAU * i / n + rng.randf()
		var c := Vector3(cos(a) * r * 0.45, h * rng.randf_range(0.4, 0.6), sin(a) * r * 0.45)
		masses.append(_mass(st, c, Vector3(r * 0.62, h * 0.42, r * 0.62), leaf, centre, h, r, rng))
	masses.append(_mass(st, Vector3(0, h * 0.62, 0), Vector3(r * 0.6, h * 0.4, r * 0.6), leaf, centre, h, r, rng))
	if idx == 0:
		# Hydrangea: flower heads, blue or pink by the bush.
		var fl: Color = Color(0.45, 0.55, 0.95) if rng.randf() < 0.5 else Color(0.95, 0.55, 0.75)
		for i in range(rng.randi_range(9, 14)):
			_dot(st, _on(masses[rng.randi() % masses.size()], rng, 0.97, true), 0.13, fl, rng)

static func _set_dims(v: Dictionary, trunk_h: float, trunk_r: float, crown: Vector3, crown_r: float, crown_h: float) -> void:
	v.trunk_h = trunk_h
	v.trunk_r = trunk_r
	v.crown = crown
	v.crown_r = crown_r
	v.crown_h = crown_h

## Collision hulls of the variant being built (_mass and _stem add to it).
static var _hulls: Array = []

## A trunk (bark, Forest._trunk) that also counts for collision and
## knows its axis (birdhouses sit on it).
static func _stem(st: SurfaceTool, v: Dictionary, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, sides: int = 7) -> void:
	Forest._trunk(st, a, b, r0, r1, col, sides)
	if not v.has("stem"):
		v.stem = [a, b, r0, r1]
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var up: Vector3 = axis.cross(side)
	var pts := PackedVector3Array()
	for i in range(sides):
		var ang: float = TAU * i / sides
		var d: Vector3 = side * cos(ang) + up * sin(ang)
		pts.append(a + d * r0)
		pts.append(b + d * r1)
	_hulls.append(pts)

## Stand-in for distance: a 4-sided trunk and one coarse blob or cone.
static func _far(sp: String, v: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var c: Vector3 = v.crown
	Forest._trunk(st, Vector3.ZERO, Vector3(c.x, c.y, c.z), v.trunk_r, v.trunk_r * 0.6, BARK[sp], 4)
	var col: Color = Color(0.13, 0.25, 0.15) if sp == "spruce" else Color(0.24, 0.36, 0.13)
	if sp == "spruce":
		Forest._skirt(st, 0.8, c.y + v.crown_h * 0.55, v.crown_r * 0.85, 6, 0.0, 0.0, col, 0.5, rng, false)
	else:
		_mass(st, c, Vector3(v.crown_r * 0.82, v.crown_h * 0.4, v.crown_r * 0.82), col, c, v.crown_h, v.crown_r, rng, 1.0, 0)
	return st.commit()

## A lumpy leaf mass (Forest._blob with a choice of surface: alpha 1
## leaves, PLAIN for a plain colour).
static func _mass(st: SurfaceTool, c: Vector3, rad: Vector3, col: Color, crown: Vector3, crown_h: float, crown_r: float, rng: RandomNumberGenerator, alpha: float = 1.0, subdiv: int = 1) -> PackedVector3Array:
	var ico: Array = Forest._ico(subdiv)
	var pts: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	var cols: Array[Color] = []
	for vv: Vector3 in ico[0]:
		var p: Vector3 = c + vv * rad * rng.randf_range(0.82, 1.12)
		pts.append(p)
		var away: Vector3 = (p - crown).normalized()
		nrm.append((vv * 0.45 + away * 0.55).normalized())
		var hf: float = clampf((p.y - (crown.y - crown_h * 0.5)) / crown_h, 0.0, 1.0)
		var rf: float = clampf(Vector2(p.x - crown.x, p.z - crown.z).length() / crown_r, 0.0, 1.0)
		var cc: Color = col * (lerpf(0.55, 1.0, hf) * lerpf(0.72, 1.05, rf) * rng.randf_range(0.94, 1.06))
		cc.a = alpha
		cols.append(cc)
	for f: Vector3i in ico[1]:
		for i in [f.x, f.z, f.y]:
			Forest._vert(st, pts[i], nrm[i], cols[i])
	var hull := PackedVector3Array(pts)
	_hulls.append(hull)
	return hull

## A point on a leaf mass's own surface (one of its vertices), pulled in
## by `inset` toward its centre - fruit and flowers sit on the leaves.
static func _on(mass: PackedVector3Array, rng: RandomNumberGenerator, inset: float, up_only: bool = false) -> Vector3:
	var c := Vector3.ZERO
	for q in mass:
		c += q
	c /= mass.size()
	for _try in range(8):
		var q: Vector3 = mass[rng.randi() % mass.size()]
		if not up_only or q.y > c.y - 0.1:
			return c + (q - c) * inset
	return c + (mass[0] - c) * inset

## A small plain-coloured ball (an apple, a flower head).
static func _dot(st: SurfaceTool, c: Vector3, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	var ico: Array = Forest._ico(0)
	var cc: Color = col * rng.randf_range(0.85, 1.1)
	for f: Vector3i in ico[1]:
		for i in [f.x, f.z, f.y]:
			var d: Vector3 = ico[0][i]
			var shade: Color = cc * lerpf(0.6, 1.05, d.y * 0.5 + 0.5)
			shade.a = PLAIN
			Forest._vert(st, c + d * r, d, shade)

# --- surprises -----------------------------------------------------------------
# Drawn through Geo in the tree's own frame (turned and scaled with it),
# not colliding. Returns [where it is, a spot to look at it from].

static func _extra(geo: Geo, xf: Transform3D, v: Dictionary, what: String, rng: RandomNumberGenerator) -> Array:
	var c: Vector3 = v.crown
	match what:
		"birdhouse":
			# On the trunk's own axis at that height (trunks taper and some
			# lean), its back against the bark: a 7-sided trunk's flat faces
			# sit at 0.9 of its radius.
			var stem: Array = v.stem
			var a0: Vector3 = stem[0]
			var a1: Vector3 = stem[1]
			var y: float = minf(2.3, lerpf(a0.y, a1.y, 0.8))
			var k: float = clampf((y - a0.y) / maxf(a1.y - a0.y, 0.01), 0.0, 1.0)
			var axis: Vector3 = a0.lerp(a1, k)
			var face: float = lerpf(stem[2], stem[3], k) * 0.9
			var f := Transform3D(Basis(), Vector3(axis.x, y, axis.z + face + 0.085))
			var wood: Color = [Color(0.75, 0.55, 0.35), Color(0.35, 0.55, 0.75), Color(0.85, 0.3, 0.25)][rng.randi() % 3]
			_b(geo, xf, f, Vector3(0, 0.13, 0), Vector3(0.18, 0.26, 0.18), wood)
			_b(geo, xf, f, Vector3(0, -0.01, 0.02), Vector3(0.24, 0.02, 0.24), wood * 0.8)
			for sd in [-1.0, 1.0]:
				var r := Transform3D(Basis(Vector3.FORWARD, sd * 0.7), Vector3(sd * 0.06, 0.31, 0))
				_b(geo, xf, f * r, Vector3.ZERO, Vector3(0.16, 0.02, 0.24), Color(0.4, 0.25, 0.18))
			_b(geo, xf, f, Vector3(0, 0.17, 0.092), Vector3(0.06, 0.06, 0.01), Color(0.05, 0.05, 0.05))
			_b(geo, xf, f, Vector3(0, 0.1, 0.12), Vector3(0.015, 0.015, 0.06), wood * 0.7)
			return [xf * f.origin, xf * (f.origin + Vector3(0.4, 0.2, 2.2))]
		"swing":
			var bh: float = c.y - v.crown_h * 0.38
			var tip := Vector3(2.0, bh + 0.15, 0)
			geo.tint = BARK.maple
			geo.cylinder(xf * Vector3(0, bh - 0.4, 0), xf * tip, 0.09 * xf.basis.get_scale().x, "trc_paint", 6, false)
			var rx: float = 1.6
			var ty: float = 0.75
			geo.tint = Color(0.75, 0.65, 0.45)
			geo.cylinder(xf * Vector3(rx, bh, 0), xf * Vector3(rx, ty + 0.35, 0), 0.015, "trc_paint", 4, false)
			geo.tint = Color(0.12, 0.12, 0.13)
			geo.pipe(xf * Vector3(rx, ty, -0.11), xf * Vector3(rx, ty, 0.11), 0.36, 0.13, "trc_paint", 14, false)
			geo.tint = Color.WHITE
			return [xf * Vector3(rx, ty + 0.4, 0), xf * Vector3(rx + 1.5, 1.6, 3.6)]
		"kite":
			var a: float = rng.randf() * TAU
			var d := Vector3(cos(a), 0, sin(a))
			var at: Vector3 = c + d * v.crown_r * 0.92 + Vector3(0, v.crown_h * 0.15, 0)
			# Geo.prism draws in the (z, y) plane: local x is the kite's normal, out along d.
			var f := Transform3D(Basis(Vector3.UP, -a).rotated(d, 0.4), at)
			var cols: Array = [Color(0.9, 0.15, 0.15), Color(1.0, 0.8, 0.1), Color(0.2, 0.45, 0.9)]
			for i in range(4):
				var ang: float = i * PI * 0.5
				var arm: float = 0.72 if i == 3 else (0.42 if i == 1 else 0.36)
				geo.tint = cols[i % 3]
				var p0: Vector3 = Vector3(cos(ang), sin(ang), 0) * arm
				var p1: Vector3 = Vector3(cos(ang + PI * 0.5), sin(ang + PI * 0.5), 0) * (0.72 if i == 2 else (0.42 if i == 0 else 0.36))
				geo.prism(xf * f, [Vector2.ZERO, Vector2(p0.x, p0.y), Vector2(p1.x, p1.y)], 0.01, "trc_paint", false)
			# The tail hangs down out of the crown, bows on the string.
			geo.tint = Color(0.9, 0.9, 0.85)
			var tail0: Vector3 = f * Vector3(0, -0.72, 0)
			var tail1: Vector3 = tail0 + Vector3(0, -1.6, 0)
			geo.cylinder(xf * tail0, xf * tail1, 0.008, "trc_paint", 3, false)
			for k in range(4):
				geo.tint = cols[k % 3]
				geo.box(xf * tail0.lerp(tail1, (k + 1) / 4.5), Vector3(0.14, 0.05, 0.02), "trc_paint", a, false)
			geo.tint = Color.WHITE
			return [xf * at, xf * (at + d * 3.5 + Vector3(0, -0.8, 0))]
		"drone":
			# A 5" quad sitting on top of the crown, a little tipped over.
			var a: float = rng.randf() * TAU
			var at: Vector3 = c + Vector3(cos(a) * v.crown_r * 0.45, v.crown_h * 0.44, sin(a) * v.crown_r * 0.45)
			if v.key.begins_with("spruce"):
				# A cone has no top to land on: caught on a branch tier, half way up.
				var y: float = c.y + v.crown_h * 0.05
				var rr: float = v.crown_r * (1.0 - y / (c.y * 2.0 + 0.6)) * 1.05
				at = Vector3(cos(a) * rr, y + 0.1, sin(a) * rr)
			var f := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.2, 0.45)), at)
			var s: float = 1.0 / xf.basis.get_scale().x # real size whatever the tree's scale
			var carbon := Color(0.12, 0.12, 0.13)
			_b(geo, xf, f, Vector3.ZERO, Vector3(0.05, 0.012, 0.32) * s, carbon, PI * 0.25)
			_b(geo, xf, f, Vector3.ZERO, Vector3(0.05, 0.012, 0.32) * s, carbon, -PI * 0.25)
			_b(geo, xf, f, Vector3(0, 0.03, 0) * s, Vector3(0.05, 0.04, 0.09) * s, Color(0.15, 0.15, 0.17))
			_b(geo, xf, f, Vector3(0, 0.07, -0.01) * s, Vector3(0.04, 0.03, 0.1) * s, Color(0.95, 0.75, 0.1))
			_b(geo, xf, f, Vector3(0, 0.035, 0.055) * s, Vector3(0.025, 0.025, 0.02) * s, Color(0.05, 0.05, 0.05))
			for k in range(4):
				var ang: float = PI * 0.25 + k * PI * 0.5
				var m := Vector3(sin(ang), 0, cos(ang)) * 0.113 * s
				geo.tint = Color(0.6, 0.6, 0.65)
				geo.cylinder(xf * (f * (m + Vector3(0, 0.005, 0) * s)), xf * (f * (m + Vector3(0, 0.025, 0) * s)), 0.013, "trc_paint", 8, false)
				geo.tint = Color(1.0, 0.45, 0.1)
				geo.cylinder(xf * (f * (m + Vector3(0, 0.027, 0) * s)), xf * (f * (m + Vector3(0, 0.031, 0) * s)), 0.064, "trc_paint", 10, false)
			geo.cylinder(xf * (f * (Vector3(0, 0.05, 0.04) * s)), xf * (f * (Vector3(0, 0.11, 0.07) * s)), 0.004, "trc_paint", 4, false)
			# Its LED still glows - the battery hasn't died yet.
			geo.tint = Color.WHITE
			geo.box_xf(xf * f * Transform3D(Basis(), Vector3(0, 0.02, -0.05) * s), Vector3(0.02, 0.01, 0.01), "trc_glow", false)
			return [xf * at, xf * (at + Vector3(cos(a), 0, sin(a)) * 1.6 + Vector3(0, 1.0, 0))]
	return [xf.origin, xf.origin + Vector3(0, 2, 5)]

static func _b(geo: Geo, xf: Transform3D, f: Transform3D, c: Vector3, size: Vector3, col: Color, yaw: float = 0.0) -> void:
	geo.tint = col
	geo.box_xf(xf * f * Transform3D(Basis(Vector3.UP, yaw), c), size, "trc_paint", false)
	geo.tint = Color.WHITE
