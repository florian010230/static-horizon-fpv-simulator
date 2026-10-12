class_name UpdatePack
extends RefCounted

## In-game updates as signed Godot packs (DEV_TODO "Self-updating").
## A release can carry, next to the zips:
##   update-manifest.json      {"version", "engine", "min_base",
##                              "packs": {"windows"|"macos"|"linux":
##                                        {"file", "size", "sha256"}}}
##   update-manifest.json.sig  RSA signature (SHA-256, PKCS#1 v1.5 - what
##                             `openssl dgst -sha256 -sign` writes) made
##                             with the private key on the user's Mac
##   StaticHorizonFPV-<v>-<os>.pck
## Updater downloads them, install() checks the signature with the public
## key built into the game (UpdateKey), the pack's size and SHA-256, and
## files it under user://update/<version>/. At every start the first
## autoload calls load_at_startup(), which checks the newest installed
## pack again (signature + hash: a pack changed on disk is not loaded)
## and loads it over the game's own files; an older good pack is used if
## the newest fails, and none at all if nothing passes - the game then
## runs as installed. Only exported builds load packs (never the editor,
## --selftest or --dev-preview).
## A pack can't bring new autoloads, project settings or class_name
## scripts (the engine reads those before any pack loads): such a release
## sets "min_base" to its own version, so older installs get the release
## page instead (tools/make_update.sh decides).
## This file and UpdateKey are always the installed build's own - a pack
## can't replace the code that checks it.

const ROOT: String = "user://update"
const MANIFEST: String = "update-manifest.json"
const KEEP: int = 2 ## installed versions kept (newest + one to fall back on)

## The version of the installed build (before any pack) and the pack
## loaded at start ({version, path} or {}).
static var base_version: String = ""
static var loaded: Dictionary = {}

static func platform() -> String:
	match OS.get_name():
		"Windows":
			return "windows"
		"macOS":
			return "macos"
		_:
			return "linux"

static func engine_version() -> String:
	var v: Dictionary = Engine.get_version_info()
	return "%d.%d.%d" % [v.major, v.minor, v.patch]

static func installed_base() -> String:
	return base_version if base_version != "" else str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## The built-in public key, or null when there is none yet (updates off).
static func public_key() -> CryptoKey:
	if UpdateKey.PUBLIC_PEM.strip_edges() == "":
		return null
	var k := CryptoKey.new()
	return k if k.load_from_string(UpdateKey.PUBLIC_PEM, true) == OK else null

static func sha256(bytes: PackedByteArray) -> PackedByteArray:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(bytes)
	return c.finish()

## SHA-256 of a file as hex, read in 1 MB pieces ("" if unreadable).
static func file_sha256(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		c.update(f.get_buffer(1 << 20))
	return c.finish().hex_encode()

## Same rule as Updater.is_newer (kept here: this file must not load the
## updater's script before a pack is in).
static func is_newer(a: String, b: String) -> bool:
	var pa: PackedStringArray = a.trim_prefix("v").split("-")[0].split(".")
	var pb: PackedStringArray = b.trim_prefix("v").split("-")[0].split(".")
	for i in range(maxi(3, maxi(pa.size(), pb.size()))):
		var x: int = int(pa[i]) if i < pa.size() else 0
		var y: int = int(pb[i]) if i < pb.size() else 0
		if x != y:
			return x > y
	return false

## Checks a manifest and its signature: {ok, error, manifest, pack}.
## `pack` is this platform's entry.
static func check_manifest(bytes: PackedByteArray, sig: PackedByteArray, key: CryptoKey, base: String, engine: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "error": "", "manifest": {}, "pack": {}}
	if key == null:
		out.error = "no key"
	elif sig.is_empty():
		out.error = "unsigned"
	elif not Crypto.new().verify(HashingContext.HASH_SHA256, sha256(bytes), sig, key):
		out.error = "bad signature"
	if out.error != "":
		return out
	var m: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(m) != TYPE_DICTIONARY or not m.has("version") or typeof(m.get("packs")) != TYPE_DICTIONARY:
		out.error = "bad manifest"
	elif not is_newer(str(m.version), base):
		out.error = "not newer"
	elif str(m.get("engine", "")) != engine:
		out.error = "other engine"
	elif is_newer(str(m.get("min_base", "0")), base):
		out.error = "needs full download"
	elif not m.packs.has(platform()):
		out.error = "no pack for " + platform()
	if out.error != "":
		return out
	out.manifest = m
	out.pack = m.packs[platform()]
	out.ok = true
	return out

## Files a downloaded pack (`pck_tmp`, removed either way) under
## root/<version>/ after checking signature, size and hash. "" = done,
## otherwise why not.
static func install(root: String, manifest: PackedByteArray, sig: PackedByteArray, pck_tmp: String, key: CryptoKey, base: String, engine: String) -> String:
	var c: Dictionary = check_manifest(manifest, sig, key, base, engine)
	var err: String = c.error
	if err == "":
		var f := FileAccess.open(pck_tmp, FileAccess.READ)
		if f == null or f.get_length() != int(c.pack.get("size", -1)):
			err = "wrong size"
		elif file_sha256(pck_tmp) != str(c.pack.get("sha256", "")).to_lower():
			err = "wrong hash"
		f = null
	if err != "":
		DirAccess.remove_absolute(pck_tmp)
		return err
	var dir: String = root.path_join(str(c.manifest.version))
	DirAccess.make_dir_recursive_absolute(dir)
	for e: Array in [[MANIFEST, manifest], [MANIFEST + ".sig", sig]]:
		var w := FileAccess.open(dir.path_join(e[0]), FileAccess.WRITE)
		if w == null:
			return "can't write"
		w.store_buffer(e[1])
	DirAccess.remove_absolute(dir.path_join("game.pck"))
	if DirAccess.rename_absolute(pck_tmp, dir.path_join("game.pck")) != OK:
		return "can't write"
	_prune(root)
	return ""

## Installed versions, newest first.
static func installed(root: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(root)
	if d == null:
		return out
	for v in d.get_directories():
		out.append(v)
	out.sort_custom(func(a: String, b: String) -> bool: return is_newer(a, b))
	return out

static func _prune(root: String) -> void:
	var vs: Array[String] = installed(root)
	for i in range(KEEP, vs.size()):
		var dir: String = root.path_join(vs[i])
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)

## The newest installed pack that still checks out: {version, path} or {}.
static func find_loadable(root: String, key: CryptoKey, base: String, engine: String) -> Dictionary:
	for v in installed(root):
		var dir: String = root.path_join(v)
		var c: Dictionary = check_manifest(FileAccess.get_file_as_bytes(dir.path_join(MANIFEST)), FileAccess.get_file_as_bytes(dir.path_join(MANIFEST + ".sig")), key, base, engine)
		if not c.ok or str(c.manifest.version) != v:
			continue
		var pck: String = dir.path_join("game.pck")
		if _size(pck) == int(c.pack.get("size", -1)) and file_sha256(pck) == str(c.pack.get("sha256", "")).to_lower():
			return {"version": v, "path": pck}
	return {}

static func _size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1

## From the first autoload (UserDataMigration), before anything else loads.
static func load_at_startup() -> void:
	base_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var args := OS.get_cmdline_user_args()
	if not OS.has_feature("template") or args.has("--selftest") or args.has("--dev-preview"):
		return
	var found: Dictionary = find_loadable(ROOT, public_key(), base_version, engine_version())
	if found.is_empty():
		return
	if ProjectSettings.load_resource_pack(found.path, true):
		loaded = found
		ProjectSettings.set_setting("application/config/version", found.version)
		print("Update pack %s loaded over %s" % [found.version, base_version])
