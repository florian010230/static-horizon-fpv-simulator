extends Node3D

## The hand-placed trees of the village and factory maps (scenes/Tree.tscn
## - move them freely in the editor). The scene's old cone-and-cylinder
## stays in the file as the editor stand-in; at runtime it's swapped
## for one of Forest's real species, picked by position (conifers and
## broadleaves mixed), sized like the stand-in (~10 m).

func _ready() -> void:
	for n in ["Trunk", "Foliage"]:
		var old := get_node_or_null(n) as Node3D
		if old:
			old.visible = false
	var p: Vector3 = global_position
	var sp: int = Forest._species(0 if fposmod(p.x * 0.37 + p.z * 0.61, 1.0) < 0.45 else 1, p)
	var mi := MeshInstance3D.new()
	mi.name = "Tree"
	mi.mesh = Forest._near_mesh(sp)
	var heights := {Forest.SPRUCE: 16.6, Forest.PINE: 16.6, Forest.BROAD: 11.5, Forest.BIRCH: 13.5, Forest.POPLAR: 19.0}
	mi.scale = Vector3.ONE * (10.5 / heights[sp])
	mi.rotation.y = fposmod(p.x * 1.7 + p.z * 2.3, TAU)
	add_child(mi)
