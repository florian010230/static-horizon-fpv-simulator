class_name Rails
extends RefCounted

## Railway builder for the generated maps, on top of Route + Geo.sweep:
## standard gauge track (ballast bed, sleepers, rails) that follows real
## alignments - straights joined by curves of railway radii (no kinks,
## no right angles), and real turnouts where tracks divide: the
## diverging track leaves the main one tangentially through the switch
## on a curve (1:9 turnout, R 190 m - the common yard/station turnout),
## with a point machine at the toe, a frog where the inner rails cross
## and check rails opposite. Plus buffer stops, signals, overhead line
## and trains standing on any track, curved or not.
##
## Stacked ground surfaces (formation, ballast, sleeper beds of two
## tracks meeting in a turnout) are Geo ground layers, so nothing
## flickers where they overlap (see geo_layer.gdshader).
##
## Heights: a route runs along the formation (the ground under the
## ballast). Rail top = formation + RAIL_TOP.

const GAUGE_HALF: float = 0.75 ## rail head centre, 1435 mm gauge
const BED_TOP: float = 0.42
const RAIL_TOP: float = 0.6
const TURNOUT_R: float = 190.0
const TURNOUT_ANGLE: float = 6.34 ## 1:9
const RAIL_PROFILE := [Vector2(-0.07, 0.0), Vector2(0.07, 0.0), Vector2(0.036, 0.18), Vector2(-0.036, 0.18)]
## Rail sides and the polished head as separate open profiles (a closed
## profile's top would lie right under the shiny head and flicker).
const RAIL_SIDE_L := [Vector2(-0.07, 0.0), Vector2(-0.036, 0.18)]
const RAIL_SIDE_R := [Vector2(0.036, 0.18), Vector2(0.07, 0.0)]
const RAIL_HEAD := [Vector2(0.036, 0.18), Vector2(-0.036, 0.18)]
const BALLAST_PROFILE := [Vector2(3.1, -0.05), Vector2(1.9, BED_TOP - 0.02), Vector2(-1.9, BED_TOP - 0.02), Vector2(-3.1, -0.05)]

var geo: Geo
var turnouts: Array = []

func _init(g: Geo) -> void:
	geo = g
	if geo.has_material("rw_rail"):
		return
	geo.add_material("rw_rail", Geo.flat_mat(Color(0.42, 0.38, 0.34), 0.4, 0.6))
	geo.add_material("rw_rail_top", Geo.flat_mat(Color(0.72, 0.72, 0.74), 0.3, 0.8))
	var ballast: Texture2D = MapTextures.get_tex("ballast")
	for layer in [1, 2, 3]:
		geo.add_material("rw_ballast%d" % layer, Geo.ground_mat(ballast, Color.WHITE, 2.0, layer, 0.25))
	for layer in [4, 5, 6]:
		geo.add_material("rw_bed%d" % layer, Geo.ground_mat(MapTextures.get_tex("sleepers"), Color.WHITE, 1.2, layer, 0.0, true))
	geo.add_material("rw_steel", Geo.flat_mat(Color(0.3, 0.31, 0.33), 0.5, 0.5))
	geo.add_material("rw_mast", Geo.flat_mat(Color(0.5, 0.52, 0.5), 0.6, 0.4))
	geo.add_material("rw_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.05, 1.05, 1.0), 3.0))
	geo.add_material("rw_yellow", Geo.flat_mat(Color(0.9, 0.7, 0.12)))
	geo.add_material("rw_red", Geo.glow_mat(Color(1.0, 0.12, 0.08), 1.5))
	geo.add_material("rw_green", Geo.glow_mat(Color(0.2, 1.0, 0.4), 1.5))
	geo.add_material("rw_black", Geo.flat_mat(Color(0.08, 0.08, 0.09)))
	geo.add_material("rw_white", Geo.flat_mat(Color(0.9, 0.9, 0.88)))

## A track along `route`. layer 0 = main track (bed layer 4), 1-2 for
## tracks that overlap it in turnouts. ballast = false where the track
## lies in a ballast field (yards, stations - see field()).
func track(route: Route, layer: int = 0, ballast: bool = true, from_d: float = 0.0, to_d: float = -1.0) -> void:
	var pts: Array[Vector3] = route.pts if (from_d <= 0.0 and to_d < 0.0) else route.slice(from_d, to_d if to_d >= 0.0 else route.length())
	if ballast:
		geo.sweep(pts, BALLAST_PROFILE, "rw_ballast%d" % (layer + 1), false, true, false)
	geo.sweep(pts, [Vector2(1.4, BED_TOP), Vector2(-1.4, BED_TOP)], "rw_bed%d" % (layer + 4), false, false, false, 1.2)
	for s in [-GAUGE_HALF, GAUGE_HALF]:
		var rp: Array[Vector3] = Route.offset_pts(pts, s)
		for i in range(rp.size()):
			rp[i].y += BED_TOP
		geo.sweep(rp, RAIL_SIDE_L, "rw_rail", false, false, false)
		geo.sweep(rp, RAIL_SIDE_R, "rw_rail", false, false, false)
		geo.sweep(rp, RAIL_HEAD, "rw_rail_top", false, false, false)

## A ballast field under a group of tracks (yard, station throat): a
## polygon-free way to say "all of this is ballast", drawn as a sweep
## `width` wide along `route` (so it follows curves too).
func field(route: Route, width: float, layer: int = 1) -> void:
	var w: float = width * 0.5
	geo.sweep(route.pts, [Vector2(w + 1.2, -0.05), Vector2(w, BED_TOP - 0.02), Vector2(-w, BED_TOP - 0.02), Vector2(-w - 1.2, -0.05)], "rw_ballast%d" % layer, false, true, false)

## A turnout on `main` at distance d: returns the diverging route,
## leaving to `side` (+1 right, -1 left of travel) through the 1:9
## curve. Continue it with straight()/arc(). The switch furniture (point
## machine, frog, check rails) is drawn here; draw the diverging track
## itself with track(route, layer >= 1).
func turnout(main: Route, d: float, side: float, radius: float = TURNOUT_R, angle: float = TURNOUT_ANGLE) -> Route:
	var div: Route = main.fork_at(d)
	div.arc(radius, angle * side, 3.0)
	var toe: Array = main.sample(d)
	var p: Vector3 = toe[0]
	var t: Vector3 = toe[1]
	var right := Vector3(-t.z, 0.0, t.x)
	var base: float = p.y + BED_TOP
	# Point machine beside the switch toe, on the side away from the curve.
	geo.box(p + t * 1.5 - right * side * 2.3 + Vector3(0, base - p.y + 0.18, 0), Vector3(0.5, 0.36, 1.4), "rw_yellow", atan2(-t.x, -t.z), false, false)
	geo.beam(p + t * 1.5 - right * side * 1.9 + Vector3(0, base - p.y + 0.1, 0), p + t * 1.5 + right * side * 0.75 + Vector3(0, base - p.y + 0.1, 0), Vector2(0.06, 0.06), "rw_steel", false, false)
	# Switch blades: short tapered rails where the curve starts.
	# Frog: where the diverging inner rail crosses the main outer rail
	# (centre lines 2 x GAUGE_HALF apart: s^2 / 2R = 1.5 m).
	var s_frog: float = sqrt(2.0 * radius * GAUGE_HALF * 2.0)
	var f: Array = main.sample(d + s_frog)
	var fp: Vector3 = f[0] + right * side * GAUGE_HALF
	geo.box(Vector3(fp.x, base + 0.12, fp.z), Vector3(0.35, 0.24, 2.4), "rw_steel", atan2(-t.x, -t.z), false, false)
	# Check rails opposite the frog, inside each outer running rail.
	for cr in [[main, -side], [div, side]]:
		var r: Route = cr[0]
		var o: float = cr[1] * (GAUGE_HALF - 0.09)
		var cp: Array[Vector3] = Route.offset_pts(r.slice(maxf(d + s_frog - 3.0, 0.0) if r == main else maxf(s_frog - 3.0, 0.0), (d + s_frog + 3.0) if r == main else s_frog + 3.0), o)
		for i in range(cp.size()):
			cp[i].y += BED_TOP
		geo.sweep(cp, RAIL_SIDE_L, "rw_rail", false, false, false)
		geo.sweep(cp, RAIL_SIDE_R, "rw_rail", false, false, false)
	turnouts.append(p)
	return div

## Crossover between two parallel tracks `gap` apart: a turnout on each
## joined by the straight between them. Returns the connecting route
## (drawn unless draw = false - e.g. to extend it into a siding first).
func crossover(main: Route, d: float, side: float, gap: float = 4.5, layer: int = 1, draw: bool = true) -> Route:
	var div: Route = turnout(main, d, side)
	# Lateral offset gained in the curve: R(1 - cos a).
	var a: float = deg_to_rad(TURNOUT_ANGLE)
	var gained: float = TURNOUT_R * (1.0 - cos(a))
	var straight_len: float = maxf((gap - 2.0 * gained) / sin(a), 0.0)
	div.straight(straight_len, 4.0)
	div.arc(TURNOUT_R, -TURNOUT_ANGLE * side, 3.0)
	if draw:
		track(div, layer, false)
	return div

## Buffer stop at the end of a route (track ends that don't leave the
## map): concrete block with two buffers and a red lamp.
func buffer_stop(route: Route) -> void:
	var p: Vector3 = route.end()
	var t: Vector3 = route.dir()
	var yaw: float = atan2(-t.x, -t.z)
	var c: Vector3 = p + t * 1.0
	geo.box(c + Vector3(0, 0.9, 0), Vector3(3.2, 1.8, 1.6), "rw_concrete", yaw)
	for s in [-0.88, 0.88]:
		var q: Vector3 = c - t * 0.8 + Vector3(-t.z, 0, t.x) * s + Vector3(0, 1.05, 0)
		geo.cylinder(q, q - t * 0.45, 0.2, "rw_steel", 8, false)
		geo.cylinder(q - t * 0.45, q - t * 0.5, 0.3, "rw_yellow", 10, false)
	geo.box(c + Vector3(0, 2.0, 0), Vector3(0.3, 0.3, 0.2), "rw_red", yaw, false, false)

## Light signal beside the track at distance d (right side of travel).
func signal_at(route: Route, d: float, green: bool = false) -> void:
	var s: Array = route.sample(d)
	var t: Vector3 = s[1]
	var right := Vector3(-t.z, 0.0, t.x)
	var base: Vector3 = s[0] + right * 2.6
	geo.cylinder(base, base + Vector3(0, 5.2, 0), 0.09, "rw_mast", 8)
	var yaw: float = atan2(-t.x, -t.z)
	geo.box(base + Vector3(0, 5.2, 0), Vector3(0.5, 1.2, 0.3), "rw_black", yaw)
	geo.box(base + Vector3(0, 5.5, 0) - t * 0.16, Vector3(0.22, 0.22, 0.05), "rw_red" if not green else "rw_black", yaw, false, false)
	geo.box(base + Vector3(0, 5.0, 0) - t * 0.16, Vector3(0.22, 0.22, 0.05), "rw_green" if green else "rw_black", yaw, false, false)

## Overhead line along a route: a mast every ~55 m on one side with a
## cantilever out over the track, and the contact wire.
func catenary(route: Route, side: float = 1.0, from_d: float = 0.0, to_d: float = -1.0) -> void:
	var L: float = route.length() if to_d < 0.0 else to_d
	var d: float = from_d
	while d <= L:
		var s: Array = route.sample(d)
		var t: Vector3 = s[1]
		var right := Vector3(-t.z, 0.0, t.x) * side
		var foot: Vector3 = s[0] + right * 3.4
		geo.box(foot + Vector3(0, 3.8, 0), Vector3(0.35, 7.6, 0.35), "rw_mast", atan2(-t.x, -t.z))
		geo.beam(foot + Vector3(0, 6.9, 0), s[0] + Vector3(0, 6.9, 0) - right * 0.4, Vector2(0.1, 0.1), "rw_steel", false)
		geo.beam(foot + Vector3(0, 7.5, 0), s[0] + Vector3(0, 6.9, 0) - right * 0.4, Vector2(0.06, 0.06), "rw_steel", false, false)
		d += 55.0
	var wire: Array[Vector3] = []
	for p in (route.pts if from_d <= 0.0 and to_d < 0.0 else route.slice(from_d, L)):
		wire.append(p + Vector3(0, 6.1, 0))
	geo.sweep(wire, [Vector2(0.03, 0.0), Vector2(0.0, 0.04), Vector2(-0.03, 0.0)], "rw_black", true, false, false)
	var messenger: Array[Vector3] = []
	for p in wire:
		messenger.append(p + Vector3(0, 0.8, 0))
	geo.sweep(messenger, [Vector2(0.025, 0.0), Vector2(0.0, 0.035), Vector2(-0.025, 0.0)], "rw_black", true, false, false)

## A train standing on `route` from distance d: each vehicle sits with
## both bogies on the track (chord between them), so it follows curves.
## kinds: Vehicles.rail_xf kinds in order of increasing distance; every
## vehicle faces along the route (toward larger d) - so a train heading
## that way lists its tail first ("ice_tail", ..., "ice_head"), and
## `reverse` turns them all round. Returns the distance where it ends.
func train(route: Route, d: float, kinds: Array, rng: RandomNumberGenerator, container_mats: Array = [], reverse: bool = false) -> float:
	var total: float = route.length()
	for k in kinds:
		var L: float = Vehicles.RAIL_LENGTH[k]
		if d + L > total:
			break
		var a: Vector3 = route.sample(d + 3.0)[0]
		var b: Vector3 = route.sample(d + L - 3.0)[0]
		var fwd: Vector3 = (b - a).normalized()
		if reverse:
			fwd = -fwd
		var centre: Vector3 = (a + b) * 0.5 + Vector3(0, RAIL_TOP, 0)
		Vehicles.rail_xf(geo, Transform3D(Basis.looking_at(fwd, Vector3.UP), centre), k, rng, container_mats)
		d += L + 0.9
	return d

## Rail-top points of a route (for things riding on the track).
static func rail_top(route: Route) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in route.pts:
		out.append(p + Vector3(0, RAIL_TOP, 0))
	return out
