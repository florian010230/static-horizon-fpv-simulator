class_name Pieces
extends RefCounted

## Stable identity for generated pieces (a village plot with its house
## and garden, a town house, a field): its id, its own seed, and the
## map's overrides for it - so changing one piece never reshuffles the
## others.
##
## Why ids come from position, not from a running index: a creator used
## to seed plot i with first_seed + i and town houses from one shared
## rng, so adding a plot, a pond that knocks one out, or one house that
## draws a number more re-rolled every piece after it. A piece's place
## on the map is what makes it "that house": its id is its kind and its
## street-edge point rounded to the metre ("plot 118,-40"). Pieces of
## one kind stand metres apart (plots 22 m, town houses 9 m), so ids
## never collide, and the id says where to look. Its seed is a hash of
## the id and the map's seed for that kind. Moving a road moves the
## plots along it - those get new houses, which is fair: they are new
## plots. Everything else stays exactly as it was.
##
## Overrides: ONE dictionary per map, BuiltMap.pieces(), id -> options:
##   "plot 118,-40": {"seed": 7}              another house and garden
##   "plot 118,-40": {"remove": true}         leave the plot empty (levelled meadow)
##   "plot 118,-40": {"storeys": 1, "roof": "hip", "garage": "carport", "open": true, "fence": "hedge"}
##   "town 130,-200": {"style": "altbau", "floors": 5, "shop": true, "shop_name": "Café", "balcony": false, "awning": true, "arch": false}
## A pinned option still draws its random number (creators write
## `o.get(key, <the draw>)` - GDScript evaluates the default either
## way), so the rest of that piece keeps its look as far as possible:
## pinning a roof keeps the colours. A pin that adds parts (a shop
## where there was none) can change details drawn after it in the same
## piece - never another piece.
##
## SH_IDS=1 shows every piece's id over it (in game and in lab shots) and
## prints "PIECE <id> <fingerprint>" per piece: a hash of every primitive
## the piece drew (Geo footprints) and the trees it planted - diff two
## runs to see which pieces changed.

## A piece's id: its kind and its anchor point rounded to the metre.
static func id_at(kind: String, p: Vector3) -> String:
	return "%s %d,%d" % [kind, roundi(p.x), roundi(p.z)]

## The piece's own seed: from its id and the map's seed for that kind
## (String.hash is djb2 - the same on every run and platform).
static func seed_of(id: String, base: int) -> int:
	return ("%s#%d" % [id, base]).hash()

## The map's overrides for a piece ({} when none). Marks the id as seen,
## so a mistyped id in the map's list is reported (BuiltMap).
static func override(geo: Geo, id: String) -> Dictionary:
	geo.piece_seen[id] = true
	return geo.pieces.get(id, {})

## Record a piece for SH_IDS: label position, and (between begin and
## end) the primitives it drew, for its fingerprint.
## view: optional [eye, target] to look at the piece from (SH_PIECE_VIEWS).
static func begin(geo: Geo, id: String, label_at: Vector3, view: Array = []) -> void:
	geo.piece_marks.append([id, label_at, view])
	geo.piece_mark_from[id] = geo.support_count()

static func end(geo: Geo, id: String, extra: Variant = null) -> void:
	if not OS.has_environment("SH_IDS"):
		return
	var from: int = geo.piece_mark_from.get(id, 0)
	geo.piece_prints[id] = [geo.support_count() - from, geo.support_hash(from) ^ str(extra).hash()]

## SH_IDS: a Label3D over every piece (always faces the camera, drawn
## through walls, readable from ~150 m) and the fingerprints printed.
static func show_ids(map: Node3D, geo: Geo) -> void:
	for k: String in geo.pieces:
		if not geo.piece_seen.has(k):
			push_warning("Pieces: override for '%s' matches no piece on this map" % k)
	# SH_PIECE_VIEWS="plot 118,-40;town 130,-200": preview views of those
	# pieces (dev_preview_capture shoots them first) - before/after shots
	# of an override.
	if OS.has_environment("SH_PIECE_VIEWS"):
		var want: PackedStringArray = OS.get_environment("SH_PIECE_VIEWS").split(";")
		var pv: Array = []
		for m: Array in geo.piece_marks:
			if m[0] in want and not (m[2] as Array).is_empty():
				pv.append(["piece_" + String(m[0]).replace(" ", "_").replace(",", "_"), m[2][0], m[2][1], "pieces"])
		map.set_meta("piece_views", pv)
	if not OS.has_environment("SH_IDS"):
		return
	var holder := Node3D.new()
	holder.name = "PieceIds"
	map.add_child(holder)
	for m: Array in geo.piece_marks:
		var l := Label3D.new()
		l.text = m[0]
		l.position = m[1]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 22
		l.outline_size = 8
		l.modulate = Color(1.0, 0.95, 0.3) if geo.pieces.has(m[0]) else Color.WHITE
		holder.add_child(l)
	var ids: Array = geo.piece_prints.keys()
	ids.sort()
	for id: String in ids:
		print("PIECE %s %d %08x" % [id, geo.piece_prints[id][0], geo.piece_prints[id][1] & 0xffffffff])
