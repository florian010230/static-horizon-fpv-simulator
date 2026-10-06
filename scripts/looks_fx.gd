class_name LooksFx
extends RefCounted

## The looks track's per-map extras, attached once a map's graphics are
## set up (Settings.apply_graphics_settings): sun glare in the camera
## (outdoor maps with a sun), dust motes in the air (indoor and abandoned
## maps), grass tufts round the drone (maps with grass ground). Safe to
## call again (a changed quality rebuilds them).

## Maps with dust in the air besides the indoor ones (MapCatalog ids).
const DUSTY: Array[String] = ["steelmill", "factory", "garage"]

static func attach(scene: Node) -> void:
	if scene == null or not (scene is Node3D):
		return
	var q: int = clampi(Settings.graphics_quality, 0, 2)
	var info: Dictionary = MapCatalog.for_scene(scene.scene_file_path)
	var indoor: bool = info.get("indoor", false)
	for n in ["DustMotes", "GrassTufts"]:
		var old: Node = scene.get_node_or_null(n)
		if old:
			old.free()
	if q > 0 and (indoor or DUSTY.has(info.get("id", "")) or scene.has_meta("dust")):
		scene.add_child(DustMotes.new(q))
	if q > 0 and not indoor:
		scene.add_child(GrassTufts.new(q))
	var ui: Node = scene.get_node_or_null("UI")
	var root: Control = ui.get("_root") if ui else null
	if root:
		var g: Node = root.get_node_or_null("SunGlare")
		if g:
			g.free()
		var sun := scene.find_child("Sun", true, false) as DirectionalLight3D
		if sun and not indoor:
			var glare := SunGlare.new()
			glare.name = "SunGlare"
			glare.setup(sun)
			root.add_child(glare)
			root.move_child(glare, 0) # under the camera look and the OSD
