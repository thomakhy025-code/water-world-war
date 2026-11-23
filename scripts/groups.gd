extends RefCounted

## Group queries return Array[Node], and GDScript then rejects game-specific
## properties. Copying into an untyped Array keeps those call sites on the
## real objects instead of a parallel lookup table.


static func get_all(tree: SceneTree, group_name: String) -> Array:
	var loose: Array = []
	loose.assign(tree.get_nodes_in_group(group_name))
	return loose
