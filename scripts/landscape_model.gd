extends RefCounted
## Ground, path surfaces and independent outdoor props. Coordinates are absolute grid cells.

const GRID := 8
const REGION := Rect2i(-20, -15, 120, 75)
const WORLD_BOUNDS := Rect2(-160, -120, 960, 600)
const DEFAULT_MAP_PATH := "res://assets/art/landscape_defaults.png"
const DEFAULT_MAP := preload("res://assets/art/landscape_defaults.png")
const DEFAULT_PROPS_PATH := "res://assets/art/landscape_props.json"
const SHORE := preload("res://assets/art/resort_shore.png")
const TERRAIN_CATALOG := {
	"grass": {"label": "Grass", "cost": 1}, "sand": {"label": "Sand", "cost": 1},
	"dirt": {"label": "Dirt", "cost": 1},
}
const PATH_CATALOG := {
	"stone": {"label": "Stone path", "cost": 2},
	"boardwalk": {"label": "Boardwalk", "cost": 3},
}
const PROP_CATALOG := {
	"palm": {"label": "Palm tree", "cost": 15, "size": [1, 1], "visual": [-44, -67, 88, 73]},
	"bush": {"label": "Shrub", "cost": 5, "size": [1, 1], "visual": [-23, -10, 46, 20]},
	"rock": {"label": "Rock", "cost": 3, "size": [1, 1], "visual": [-8, -8, 19, 14]},
	"beach_flag": {"label": "Beach flag", "cost": 10, "size": [1, 1], "visual": [-24, -46, 52, 48]},
	"bench": {"label": "Outdoor bench", "cost": 15, "size": [3, 1], "visual": [-4, -10, 24, 14]},
	"beach_lounge": {"label": "Beach lounge", "cost": 40, "size": [4, 3], "capacity": 2, "overhang": 12},
	"volleyball": {"label": "Volleyball court", "cost": 100, "size": [10, 7], "capacity": 2, "overhang": 10},
	"beach_bar": {"label": "Beach bar", "cost": 100, "size": [6, 4], "capacity": 2, "overhang": 15},
	"stage": {"label": "Evening stage", "cost": 120, "size": [8, 5], "capacity": 4, "overhang": 18},
}
static var _next_prop_id := 2000000
static var _base_map: Image
static var _base_shore := PackedInt32Array()
static var _base_props: Array[Dictionary] = []
static var _loaded := false
var terrain_overrides := {}
var path_overrides := {}
var props: Array[Dictionary] = []
var revision := 0


func _init() -> void:
	_load_defaults()
	props.assign(_base_props.duplicate(true))


static func _load_defaults() -> void:
	if _loaded:
		return
	_loaded = true
	var image := SHORE.get_image()
	for y in range(image.get_height()):
		var color := image.get_pixel(0, y)
		_base_shore.append(-160 + color.r8 + (color.g8 << 8))
	_base_map = DEFAULT_MAP.get_image()
	if FileAccess.file_exists(DEFAULT_PROPS_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_PROPS_PATH))
		if parsed is Array:
			for item in parsed:
				if item is Dictionary and PROP_CATALOG.has(item.get("kind")) and item.get("cell") is Array:
					var prop: Dictionary = item.duplicate(true)
					prop.id = 1000000 + _base_props.size()
					prop.paid_cost = 0
					prop.offset = prop.get("offset", [4, 4])
					prop.rotation = int(prop.get("rotation", 0))
					prop.variant = int(prop.get("variant", 0))
					_base_props.append(prop)
	if _base_props.is_empty():
		push_error("Landscape defaults are missing: include landscape_props.json in the exported package.")


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * GRID, Vector2(GRID, GRID))


func base_terrain_at(cell: Vector2i) -> String:
	if not REGION.has_point(cell):
		return "water"
	if _base_map:
		var code := _base_map.get_pixel(cell.x + 20, cell.y + 15).r8
		return ["", "grass", "sand", "dirt", "water"][clampi(code, 1, 4)]
	var center := cell_rect(cell).get_center()
	var coast := _base_shore[int(center.y) + 120]
	return "water" if center.x >= coast else ("sand" if center.x >= coast - 32 else "grass")


func base_path_at(cell: Vector2i) -> String:
	if not REGION.has_point(cell) or not _base_map:
		return ""
	return ["", "stone", "boardwalk"][clampi(_base_map.get_pixel(cell.x + 20, cell.y + 15).g8, 0, 2)]


func terrain_at(cell: Vector2i) -> String:
	return terrain_overrides.get(cell, base_terrain_at(cell))


func path_at(cell: Vector2i) -> String:
	return path_overrides.get(cell, base_path_at(cell))


func is_water_pixel(point: Vector2) -> bool:
	if not WORLD_BOUNDS.has_point(point):
		return true
	return point.x >= _base_shore[clampi(int(floor(point.y)) + 120, 0, 599)]


func cell_is_dry(cell: Vector2i) -> bool:
	if not REGION.has_point(cell):
		return false
	for y in range(cell.y * GRID, (cell.y + 1) * GRID):
		if (cell.x + 1) * GRID > _base_shore[y + 120]:
			return false
	return true


func rect_is_dry(rect: Rect2) -> bool:
	if not WORLD_BOUNDS.encloses(rect):
		return false
	for y in range(floori(rect.position.y / GRID), ceili(rect.end.y / GRID)):
		for x in range(floori(rect.position.x / GRID), ceili(rect.end.x / GRID)):
			if not cell_is_dry(Vector2i(x, y)):
				return false
	return true


func prop_rect(prop: Dictionary) -> Rect2:
	var size: Array = PROP_CATALOG[prop.kind].size
	var extent := Vector2(size[0], size[1]) if int(prop.rotation) % 2 == 0 else Vector2(size[1], size[0])
	return Rect2(Vector2(prop.cell[0], prop.cell[1]) * GRID, extent * GRID)


func prop_visual_rect(prop: Dictionary) -> Rect2:
	if PROP_CATALOG[prop.kind].has("capacity"):
		var footprint := prop_rect(prop)
		var lift := Vector2(0, PROP_CATALOG[prop.kind].overhang)
		return Rect2(footprint.position - lift, footprint.size + lift)
	if prop.kind == "bench":
		var footprint := prop_rect(prop)
		return Rect2(footprint.position - Vector2(0, 6), footprint.size + Vector2(0, 6))
	var extent: Array = PROP_CATALOG[prop.kind].visual
	var anchor := Vector2(prop.cell[0], prop.cell[1]) * GRID + Vector2(prop.offset[0], prop.offset[1])
	return Rect2(anchor + Vector2(extent[0], extent[1]), Vector2(extent[2], extent[3]))


func prop_by_id(id: int) -> Dictionary:
	for prop in props:
		if int(prop.id) == id:
			return prop
	return {}


func touch() -> void:
	revision += 1


func set_terrain(cell: Vector2i, kind: String) -> void:
	if TERRAIN_CATALOG.has(kind) and cell_is_dry(cell):
		terrain_overrides[cell] = kind


func set_path(cell: Vector2i, kind: String) -> void:
	if base_path_at(cell) == kind:
		path_overrides.erase(cell)
	else:
		path_overrides[cell] = kind


func restore_cell(cell: Vector2i) -> void:
	terrain_overrides.erase(cell)
	path_overrides.erase(cell)


func ground_signature(cell: Vector2i) -> String:
	if terrain_overrides.has(cell):
		var kind: String = terrain_overrides[cell]
		# Full-land and full-water tiles with identical material are real no-ops.
		if kind == base_terrain_at(cell):
			if kind != "water" and _base_cell_dry(cell):
				return "base:" + kind
			if kind == "water" and _base_cell_water(cell):
				return "base:water"
		return "paint:" + kind
	return "base:" + base_terrain_at(cell)


func _base_cell_dry(cell: Vector2i) -> bool:
	for y in range(cell.y * GRID, (cell.y + 1) * GRID):
		if (cell.x + 1) * GRID > _base_shore[y + 120]:
			return false
	return true


func _base_cell_water(cell: Vector2i) -> bool:
	for y in range(cell.y * GRID, (cell.y + 1) * GRID):
		if cell.x * GRID < _base_shore[y + 120]:
			return false
	return true


func surface_quote(active: RefCounted) -> int:
	var changed_ground := terrain_overrides.duplicate()
	changed_ground.merge(active.terrain_overrides)
	var changed_paths := path_overrides.duplicate()
	changed_paths.merge(active.path_overrides)
	var cost := 0
	for cell in changed_ground:
		if ground_signature(cell) != active.ground_signature(cell):
			cost += int(TERRAIN_CATALOG[terrain_at(cell)].cost)
	for cell in changed_paths:
		var kind := path_at(cell)
		if kind != active.path_at(cell) and not kind.is_empty():
			cost += int(PATH_CATALOG[kind].cost)
	return cost


func snapshot() -> Dictionary:
	var terrain: Array = []
	var paths: Array = []
	for cell in terrain_overrides:
		terrain.append([cell.x, cell.y, terrain_overrides[cell]])
	for cell in path_overrides:
		paths.append([cell.x, cell.y, path_overrides[cell]])
	return {"version": 1, "terrain": terrain, "paths": paths, "props": props.duplicate(true)}


func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("terrain") is Array or not data.get("paths") is Array or not data.get("props") is Array:
		return false
	if data.terrain.size() > 9000 or data.paths.size() > 9000 or data.props.size() > 512:
		return false
	if has_protected_water_edits(data):
		return false
	var terrain := {}
	var paths := {}
	for group in [[data.terrain, terrain, false], [data.paths, paths, true]]:
		for item in group[0]:
			if not item is Array or item.size() != 3 or not _integer(item[0], -20, 99) or not _integer(item[1], -15, 59) or not item[2] is String:
				return false
			var kind: String = item[2]
			# Older drafts could explicitly paint an unchanged open-ocean tile.
			# Discard this harmless no-op while rejecting actual shoreline edits.
			if not group[2] and kind == "water" and _base_cell_water(Vector2i(item[0], item[1])):
				continue
			var allowed: bool = (PATH_CATALOG.has(kind) or kind == "") if group[2] else TERRAIN_CATALOG.has(kind)
			if not allowed:
				return false
			var cell := Vector2i(item[0], item[1])
			if group[1].has(cell):
				return false
			group[1][cell] = kind
	var restored_props: Array[Dictionary] = []
	var ids := {}
	for item in data.props:
		if not item is Dictionary or not PROP_CATALOG.has(item.get("kind")) or not _integer(item.get("id"), 1, 999999999):
			return false
		if ids.has(int(item.id)) or not item.get("cell") is Array or item.cell.size() != 2 or not item.get("offset") is Array or item.offset.size() != 2:
			return false
		if not _integer(item.cell[0], -20, 99) or not _integer(item.cell[1], -15, 59) or not _integer(item.offset[0], 0, 7) or not _integer(item.offset[1], 0, 7):
			return false
		if not _integer(item.get("rotation"), 0, 3) or not _integer(item.get("variant"), 0, 63) or not _integer(item.get("paid_cost"), 0, 100000):
			return false
		var prop: Dictionary = item.duplicate(true)
		prop.id = int(prop.id)
		prop.rotation = int(prop.rotation)
		prop.variant = int(prop.variant)
		prop.paid_cost = int(prop.paid_cost)
		ids[prop.id] = true
		restored_props.append(prop)
		_next_prop_id = maxi(_next_prop_id, prop.id + 1)
	terrain_overrides = terrain
	path_overrides = paths
	props = restored_props
	touch()
	return true


static func has_protected_water_edits(data: Dictionary) -> bool:
	_load_defaults()
	var entries: Array = []
	for layer in ["terrain", "paths"]:
		if data.get(layer) is Array:
			for record in data[layer]:
				entries.append([layer, record])
	for entry in entries:
		var item: Variant = entry[1]
		if not item is Array or item.size() != 3 or not item[2] is String:
			continue
		if not (item[0] is float or item[0] is int) or not (item[1] is float or item[1] is int):
			continue
		if not is_finite(float(item[0])) or not is_finite(float(item[1])) or item[0] < -20 or item[0] > 99 or item[1] < -15 or item[1] > 59:
			continue
		if item[0] != int(item[0]) or item[1] != int(item[1]):
			continue
		var cell := Vector2i(item[0], item[1])
		var full_dry := true
		var full_water := true
		for y in range(cell.y * GRID, (cell.y + 1) * GRID):
			full_dry = full_dry and (cell.x + 1) * GRID <= _base_shore[y + 120]
			full_water = full_water and cell.x * GRID >= _base_shore[y + 120]
		if entry[0] == "paths":
			if PATH_CATALOG.has(item[2]) and not full_dry:
				return true
			continue
		if item[2] == "water" and not full_water:
			return true
		if TERRAIN_CATALOG.has(item[2]) and not full_dry:
			return true
	return false


func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and value >= minimum and value <= maximum


func allocate_prop_id() -> int:
	var id := _next_prop_id
	_next_prop_id += 1
	return id
