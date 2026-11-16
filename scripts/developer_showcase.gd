extends RefCounted
## Add the showcase through the same construction APIs used in Build mode.

const Layout = preload("res://scripts/layout_model.gd")
const CAMPUS := [
	["lap_pool", Vector2i(-54, -19), 0],
	["lagoon_pool", Vector2i(-38, -19), 0],
	["waterpark", Vector2i(-22, -19), 0],
	["hot_tub", Vector2i(-52, -5), 0],
	["kids_pool", Vector2i(-43, -5), 0],
	["basketball", Vector2i(-32, -5), 0],
	["climbing_wall", Vector2i(-22, 0), 1],
	["arcade", Vector2i(-53, 11), 0],
	["cafe", Vector2i(-41, 11), 0],
	["nightclub", Vector2i(-27, 11), 0],
]
const SCENERY := [
	["bench", Vector2i(-52, 28), 1],
	["bench", Vector2i(-32, 24), 0],
	["palm", Vector2i(-57, -14), 0],
	["palm", Vector2i(-57, 17), 1],
	["bush", Vector2i(-46, 25), 0],
	["rock", Vector2i(-24, 24), 0],
]
const FURNISHINGS := [
	["lounger", "pool", Vector2i(1, 2)],
	["lounger", "pool", Vector2i(16, 2)],
	["umbrella", "pool", Vector2i(2, 7)],
	["plant", "reception", Vector2i(11, 2)],
	["bench", "reception", Vector2i(1, 6)],
	["table", "buffet", Vector2i(6, 5)],
]


static func build(source: Layout) -> Layout:
	var plan: Layout = source.duplicate_layout()
	for item in CAMPUS + SCENERY:
		var placement := plan.add_prop(item[0], item[1], item[2])
		if not _check_placement(item[0], placement):
			return null
	for item in FURNISHINGS:
		var building_id := _building_id(plan, item[1])
		var placement := plan.add_asset(item[0], building_id, item[2])
		if not _check_placement(item[0], placement):
			return null
	if not _install_paths(plan):
		return null
	var readiness := plan.readiness()
	if not readiness.ok or not readiness.terrace:
		push_warning("The Developer layout is missing a working service or furnished terrace.")
		return null
	for group in Layout.Landscape.FACILITY_GROUPS.values():
		for kind in group:
			if plan.amenities(kind).is_empty():
				push_warning("Developer facility has no guest access: %s." % kind)
				return null
	return plan


static func _install_paths(plan: Layout) -> bool:
	var cells: Array[Vector2i] = []
	_add_path(cells, Vector2i(-56, -7), Vector2i(-56, 34))
	_add_path(cells, Vector2i(-56, -7), Vector2i(-15, -7))
	_add_path(cells, Vector2i(-56, 7), Vector2i(-21, 7))
	_add_path(cells, Vector2i(-56, 22), Vector2i(-22, 22))
	var cross_aisles := [-7, -7, -7, 7, 7, 7, 7, 22, 22, 22]
	for index in range(CAMPUS.size()):
		var row: Array = CAMPUS[index]
		var site: Vector2i = row[1]
		var gate := plan.facility_gate({"kind": row[0], "cell": [site.x, site.y], "rotation": row[2]})
		var entry := Vector2i((gate / Layout.GRID).floor())
		_add_path(cells, entry, Vector2i(entry.x, cross_aisles[index]))
	if not _check_placement("campus boardwalk", plan.paint_landscape_stroke("path", "boardwalk", cells)):
		return false
	cells.clear()
	_add_path(cells, Vector2i(-55, 34), Vector2i(7, 34))
	# Join the existing paths without replacing their original finish.
	var connector := cells.filter(func(cell: Vector2i) -> bool: return plan.landscape.path_at(cell).is_empty())
	return _check_placement("hotel path", plan.paint_landscape_stroke("path", "stone", connector))


static func _add_path(cells: Array[Vector2i], first: Vector2i, last: Vector2i) -> void:
	var difference := last - first
	var direction := difference.sign()
	for offset in range(maxi(absi(difference.x), absi(difference.y)) + 1):
		cells.append(first + direction * offset)


static func _building_id(plan: Layout, kind: String) -> int:
	for building in plan.buildings:
		if building.kind == kind:
			return building.id
	return -1


static func _check_placement(kind: String, result: Dictionary) -> bool:
	if not result.ok:
		push_warning("Developer placement failed for %s. %s" % [kind, result.reason])
	return result.ok
