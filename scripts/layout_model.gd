extends RefCounted
## Serializable construction geometry. Money is committed by the main controller.

const GRID := 8
const WORLD_BOUNDS := Rect2(-160, -120, 960, 600)
const ENTRY := Vector2(60, 276)
const SHORE := preload("res://assets/art/resort_shore.png")
const Landscape = preload("res://scripts/landscape_model.gd")
const MAX_BUILDING_NAME_LENGTH := 24
const DEFAULT_FINISHES := {"floor": "default", "wall": "default", "ceiling": "default"}
const FINISH_CATALOG := {
	"floor": {
		"default": {"label": "Original", "cost": 12}, "tile": {"label": "Tile", "cost": 12},
		"wood": {"label": "Wood", "cost": 12}, "stone": {"label": "Stone", "cost": 12},
	},
	"wall": {
		"default": {"label": "Original", "cost": 10}, "plaster": {"label": "Plaster", "cost": 10},
		"brick": {"label": "Brick", "cost": 10}, "timber": {"label": "Timber", "cost": 10},
	},
	"ceiling": {
		"default": {"label": "Original", "cost": 8}, "plaster": {"label": "Plaster", "cost": 8},
		"beams": {"label": "Beams", "cost": 8}, "panels": {"label": "Panels", "cost": 8},
	},
}
const BUILDING_CATALOG := {
	"bedroom": {"label": "Bedroom", "cost": 160, "min_size": [6, 6]},
	"reception": {"label": "Reception", "cost": 120, "min_size": [8, 6]},
	"buffet": {"label": "Buffet", "cost": 180, "min_size": [10, 8]},
	"pool": {"label": "Pool", "cost": 220, "min_size": [12, 10]},
}
const ASSET_CATALOG := {
	"bed": {"label": "Bed", "cost": 40, "size": [2, 3], "allowed": ["bedroom"]},
	"desk": {"label": "Reception desk", "cost": 30, "size": [3, 2], "allowed": ["reception"]},
	"counter": {"label": "Buffet counter", "cost": 40, "size": [4, 2], "allowed": ["buffet"]},
	"table": {"label": "Dining table", "cost": 20, "size": [2, 2], "allowed": ["buffet"]},
	"lounger": {"label": "Lounger", "cost": 30, "size": [1, 3], "allowed": ["pool"]},
	"umbrella": {"label": "Umbrella", "cost": 40, "size": [2, 2], "allowed": ["pool"]},
	"plant": {"label": "Plant", "cost": 8, "size": [1, 1], "allowed": []},
	"bench": {"label": "Bench", "cost": 15, "size": [3, 1], "allowed": []},
}
static var _next_id := 1
var buildings: Array[Dictionary] = []
var assets: Array[Dictionary] = []
var landscape := Landscape.new()
var _graph: AStarGrid2D
var _dirty := true
var _shore: Image
var _routes := {}
var _readiness_cache := {}
var _rooms_cache: Array[Vector2] = []
var _rooms_cached := false
var _stations_cache := {}
var _dining_cache: Array[Dictionary] = []
var _dining_cached := false


func _init() -> void:
	_shore = SHORE.get_image()
	var default_props := landscape.props.duplicate(true)
	landscape.props.clear()
	for i in range(4):
		var result := add_building("bedroom", Rect2(24 + 72 * i, 48, 64, 80))
		add_asset("bed", result.id, Vector2i(1, 1))
	var reception := add_building("reception", Rect2(32, 160, 112, 72))
	add_asset("desk", reception.id, Vector2i(3, 2))
	var buffet := add_building("buffet", Rect2(160, 160, 120, 72))
	add_asset("counter", buffet.id, Vector2i(2, 2))
	add_asset("table", buffet.id, Vector2i(9, 3))
	add_building("pool", Rect2(312, 160, 144, 80))
	_install_default_props(default_props, false)
	# Starter hotel is owned, but carries no refundable construction expenditure.


func snapshot() -> Dictionary:
	return {"version": 3, "buildings": buildings.duplicate(true), "assets": assets.duplicate(true), "next_id": _next_id, "landscape": landscape.snapshot()}


func duplicate_layout() -> RefCounted:
	var copy = get_script().new()
	copy.restore(snapshot())
	return copy


func restore(data: Dictionary) -> bool:
	var version: Variant = data.get("version", 1)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != int(version) or int(version) not in [1, 2, 3]:
		return false
	if not data.get("buildings") is Array or not data.get("assets") is Array:
		return false
	if data.buildings.size() > 11 or data.assets.size() > 512:
		return false
	var old_buildings := buildings.duplicate(true)
	var old_assets := assets.duplicate(true)
	var old_landscape := landscape
	var restored_landscape := Landscape.new()
	var legacy := not data.has("landscape")
	if not legacy and (not data.landscape is Dictionary or not restored_landscape.restore(data.landscape)):
		return false
	var restored_props := restored_landscape.props.duplicate(true)
	restored_landscape.props.clear()
	landscape = restored_landscape
	buildings.clear()
	assets.clear()
	var valid := true
	var ids := {}
	for entity in data.buildings:
		if not entity is Dictionary or not _valid_id(entity.get("id")) or not _numeric_array(entity.get("rect"), 4) or ids.has(int(entity.id)):
			valid = false
			break
		var r: Array = entity.rect
		var result := add_building(str(entity.get("kind", "")), Rect2(r[0], r[1], r[2], r[3]))
		if not result.ok or not _valid_paid(entity.get("paid_cost", 0)):
			valid = false
			break
		buildings[-1].id = int(entity.id)
		buildings[-1].paid_cost = int(entity.get("paid_cost", 0))
		if int(version) == 3 and (not entity.has("display_name") or not entity.has("finishes")):
			valid = false
			break
		if entity.has("display_name"):
			if not entity.display_name is String or not set_building_name(int(entity.id), entity.display_name).ok:
				valid = false
				break
		if entity.has("finishes"):
			if not entity.finishes is Dictionary or entity.finishes.size() != 3:
				valid = false
				break
			for surface in DEFAULT_FINISHES:
				if not entity.finishes.get(surface) is String or not set_building_finish(int(entity.id), surface, entity.finishes[surface]).ok:
					valid = false
					break
			if not valid:
				break
		ids[int(entity.id)] = true
		_next_id = maxi(_next_id, int(entity.id) + 1)
	if valid:
		for entity in data.assets:
			if not entity is Dictionary or not _valid_id(entity.get("id")) or ids.has(int(entity.id)) or not _numeric_array(entity.get("cell"), 2) or not _valid_id(entity.get("building_id")):
				valid = false
				break
			var rotation = entity.get("rotation", 0)
			if not _valid_paid(entity.get("paid_cost", 0)) or not rotation is float and not rotation is int:
				valid = false
				break
			if not is_finite(float(rotation)) or float(rotation) != int(rotation) or rotation < 0 or rotation > 3:
				valid = false
				break
			var cell: Array = entity.cell
			if cell[0] != int(cell[0]) or cell[1] != int(cell[1]):
				valid = false
				break
			var result := add_asset(str(entity.get("kind", "")), int(entity.building_id), Vector2i(cell[0], cell[1]), int(rotation))
			if not result.ok:
				valid = false
				break
			assets[-1].id = int(entity.id)
			assets[-1].paid_cost = int(entity.get("paid_cost", 0))
			ids[int(entity.id)] = true
			_next_id = maxi(_next_id, int(entity.id) + 1)
	if valid:
		if legacy:
			_install_default_props(restored_props)
		else:
			for prop in restored_props:
				if ids.has(int(prop.id)) or not validate_prop(prop.kind, Vector2i(prop.cell[0], prop.cell[1]), int(prop.rotation), int(prop.variant)).ok:
					valid = false
					break
				ids[int(prop.id)] = true
				landscape.props.append(prop)
			if valid:
				# Explicit paths cannot bridge water; restore is transactional.
				for cell in landscape.path_overrides:
					if not landscape.path_at(cell).is_empty() and not landscape.cell_is_dry(cell):
						valid = false
						break
				for cell in landscape.terrain_overrides:
					if not landscape.path_at(cell).is_empty() and not landscape.cell_is_dry(cell):
						valid = false
						break
			if not landscape.rect_is_dry(Rect2(56, 272, GRID, GRID)):
				valid = false
	if not valid:
		buildings.assign(old_buildings)
		assets.assign(old_assets)
		landscape = old_landscape
	_invalidate()
	return valid


func _valid_id(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and value > 0 and value < 1000000000


func _valid_paid(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and value >= 0 and value <= 100000


func _numeric_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)) or abs(float(number)) > 10000:
			return false
	return true


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "id": -1}


func _invalidate() -> void:
	_dirty = true
	_routes.clear()
	_readiness_cache.clear()
	_rooms_cache.clear()
	_rooms_cached = false
	_stations_cache.clear()
	_dining_cache.clear()
	_dining_cached = false


func building_rect(building: Dictionary) -> Rect2:
	var r: Array = building.rect
	return Rect2(r[0], r[1], r[2], r[3])


func building_by_id(id: int) -> Dictionary:
	for building in buildings:
		if building.id == id:
			return building
	return {}


static func normalize_building_name(value: String) -> String:
	return value.strip_edges()


static func building_name(building: Dictionary) -> String:
	return str(building.get("display_name", BUILDING_CATALOG.get(building.get("kind", ""), {}).get("label", "Building")))


func _default_building_name(kind: String) -> String:
	if kind != "bedroom":
		return {"reception": "Lobby", "buffet": "Restaurant", "pool": "Pool"}.get(kind, "Building")
	var used: Array[String] = []
	for building in buildings:
		used.append(building_name(building))
	for i in range(8):
		var candidate := "Room " + char(65 + i)
		if candidate not in used:
			return candidate
	return "Guest Room"


func set_building_name(id: int, value: String) -> Dictionary:
	var building := building_by_id(id)
	if building.is_empty():
		return _fail("Select a building to name it.")
	var normalized := normalize_building_name(value)
	if normalized.is_empty() or normalized.length() > MAX_BUILDING_NAME_LENGTH:
		return _fail("Use a building name between 1 and %d characters." % MAX_BUILDING_NAME_LENGTH)
	for index in range(normalized.length()):
		var code := normalized.unicode_at(index)
		if code < 32 or (code >= 127 and code <= 159) or code in [0x2028, 0x2029]:
			return _fail("Use a single-line building name without control characters.")
	building.display_name = normalized
	return {"ok": true, "reason": "", "id": id}


func set_building_finish(id: int, surface: String, choice: String) -> Dictionary:
	var building := building_by_id(id)
	if building.is_empty():
		return _fail("Select a building to customize it.")
	if not FINISH_CATALOG.has(surface) or not FINISH_CATALOG[surface].has(choice):
		return _fail("Choose a valid floor, wall or ceiling finish.")
	if building.kind == "pool" and choice != "default":
		return _fail("The pool is outdoors; enclosed-building finishes do not apply.")
	if not building.has("finishes"):
		building.finishes = DEFAULT_FINISHES.duplicate()
	building.finishes[surface] = choice
	return {"ok": true, "reason": "", "id": id}


func door_point(building: Dictionary) -> Vector2:
	var r := building_rect(building)
	return r.position + Vector2((floor(r.size.x / GRID / 2.0) + 0.5) * GRID, r.size.y - GRID / 2.0)


func water_rect(building: Dictionary) -> Rect2:
	var r := building_rect(building)
	return Rect2(r.position + Vector2(24, 16), r.size - Vector2(48, 40))


func _dry(rect: Rect2) -> bool:
	return landscape.rect_is_dry(rect)


func validate_building(kind: String, rect: Rect2) -> Dictionary:
	if not BUILDING_CATALOG.has(kind):
		return _fail("Choose a building type.")
	var minimum: Array = BUILDING_CATALOG[kind].min_size
	if rect.size.x < minimum[0] * GRID or rect.size.y < minimum[1] * GRID:
		return _fail("Too small: minimum %d × %d tiles." % [minimum[0], minimum[1]])
	for value in [rect.position.x, rect.position.y, rect.size.x, rect.size.y]:
		if not is_finite(value) or not is_equal_approx(fposmod(value, GRID), 0):
			return _fail("Build on the 8-pixel grid.")
	if not _dry(rect):
		return _fail("Keep the whole building on land, away from the surf.")
	if rect.intersects(Rect2(48, 264, 24, 24)):
		return _fail("Keep the resort entrance clear.")
	for prop in landscape.props:
		if rect.intersects(prop_rect(prop)):
			return _fail("Move or bulldoze the outdoor scenery before building here.")
	var count := 0
	for building in buildings:
		if building.kind == kind:
			count += 1
		if rect.intersects(building_rect(building)):
			return _fail("Buildings cannot overlap.")
	if count >= (8 if kind == "bedroom" else 1):
		return _fail("This prototype supports eight bedrooms and one of each facility.")
	return {"ok": true, "reason": "", "id": -1}


func add_building(kind: String, rect: Rect2) -> Dictionary:
	var result := validate_building(kind, rect)
	if not result.ok:
		return result
	var id := _next_id
	_next_id += 1
	buildings.append({"id": id, "kind": kind, "rect": [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)], "paid_cost": 0, "display_name": _default_building_name(kind), "finishes": DEFAULT_FINISHES.duplicate()})
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func remove_building(id: int) -> Dictionary:
	var building := building_by_id(id)
	if building.is_empty():
		return _fail("No building here.")
	for i in range(assets.size() - 1, -1, -1):
		if assets[i].building_id == id:
			assets.remove_at(i)
	buildings.erase(building)
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func asset_size(kind: String, rotation: int = 0) -> Vector2i:
	if not ASSET_CATALOG.has(kind):
		return Vector2i.ZERO
	var size: Array = ASSET_CATALOG[kind].size
	return Vector2i(size[1], size[0]) if rotation % 2 else Vector2i(size[0], size[1])


func asset_rect(asset: Dictionary) -> Rect2:
	var building := building_by_id(asset.building_id)
	if building.is_empty():
		return Rect2()
	return Rect2(building_rect(building).position + Vector2(asset.cell[0], asset.cell[1]) * GRID, Vector2(asset_size(asset.kind, asset.get("rotation", 0))) * GRID)


func validate_asset(kind: String, building_id: int, cell: Vector2i, rotation: int = 0) -> Dictionary:
	var building := building_by_id(building_id)
	if not ASSET_CATALOG.has(kind) or building.is_empty():
		return _fail("Place furnishings inside a building or on a pool deck.")
	if assets.size() >= 512:
		return _fail("Furniture limit reached.")
	var allowed: Array = ASSET_CATALOG[kind].allowed
	if not allowed.is_empty() and not building.kind in allowed:
		return _fail("%s belongs in: %s." % [ASSET_CATALOG[kind].label, ", ".join(allowed)])
	var rect := asset_rect({"kind": kind, "building_id": building_id, "cell": [cell.x, cell.y], "rotation": rotation})
	if not building_rect(building).grow(-GRID).encloses(rect):
		return _fail("Keep furnishings inside the walls or deck edge.")
	var door := door_point(building)
	if rect.intersects(Rect2(door - Vector2(4, 12), Vector2(8, 16))):
		return _fail("Leave the doorway and its inside approach clear.")
	if building.kind == "pool" and rect.intersects(water_rect(building)):
		return _fail("Place furnishings on the deck, outside the pool water.")
	for asset in assets:
		if rect.intersects(asset_rect(asset)):
			return _fail("Furniture cannot overlap.")
	return {"ok": true, "reason": "", "id": -1}


func add_asset(kind: String, building_id: int, cell: Vector2i, rotation: int = 0) -> Dictionary:
	var result := validate_asset(kind, building_id, cell, rotation)
	if not result.ok:
		return result
	var id := _next_id
	_next_id += 1
	assets.append({"id": id, "kind": kind, "building_id": building_id, "cell": [cell.x, cell.y], "rotation": posmod(rotation, 4), "paid_cost": 0})
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func remove_asset(id: int) -> Dictionary:
	for asset in assets:
		if asset.id == id:
			assets.erase(asset)
			_invalidate()
			return {"ok": true, "reason": "", "id": id}
	return _fail("No furnishing here.")


func building_at(world: Vector2) -> Dictionary:
	for building in buildings:
		if building_rect(building).has_point(world):
			return building
	return {}


func asset_at(world: Vector2) -> Dictionary:
	for asset in assets:
		if asset_rect(asset).has_point(world):
			return asset
	return {}


func render_assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for asset in assets:
		var copy := asset.duplicate(true)
		var r := asset_rect(asset)
		copy.rect = [r.position.x, r.position.y, r.size.x, r.size.y]
		result.append(copy)
	return result


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floor(point.x / GRID), floor(point.y / GRID))


func _rebuild_graph() -> void:
	if not _dirty:
		return
	_graph = AStarGrid2D.new()
	_graph.region = Rect2i(-20, -15, 120, 75)
	_graph.cell_size = Vector2(GRID, GRID)
	_graph.offset = Vector2(4, 4)
	_graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_graph.update()
	# Paint collision regions once per edit, rather than testing every furnishing
	# against every world cell. Dense furnished layouts keep the same edit cost.
	for y in range(-15, 60):
		for x in range(-20, 100):
			var cell := Vector2i(x, y)
			_graph.set_point_solid(cell, not landscape.cell_is_dry(cell))
			var weight := 1.0 if not landscape.path_at(cell).is_empty() else (3.0 if landscape.terrain_at(cell) == "sand" else 2.5)
			_graph.set_point_weight_scale(cell, weight)
	for building in buildings:
		var r := building_rect(building)
		if building.kind == "pool":
			var water := water_rect(building)
			_graph.fill_solid_region(Rect2i(_cell(water.position), Vector2i(water.size / GRID)))
		else:
			var region := Rect2i(_cell(r.position), Vector2i(r.size / GRID))
			_graph.fill_solid_region(region)
			_graph.fill_solid_region(region.grow(-1), false)
			_graph.set_point_solid(_cell(door_point(building)), false)
			for y in range(region.position.y, region.end.y):
				for x in range(region.position.x, region.end.x):
					_graph.set_point_weight_scale(Vector2i(x, y), 1.0)
	for asset in assets:
		var r := asset_rect(asset)
		_graph.fill_solid_region(Rect2i(_cell(r.position), Vector2i(r.size / GRID)))
	for prop in landscape.props:
		var r := prop_rect(prop)
		_graph.fill_solid_region(Rect2i(_cell(r.position), Vector2i(r.size / GRID)))
	_dirty = false


func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	_rebuild_graph()
	var start := _cell(from)
	var end := _cell(to)
	var key := Vector4i(start.x, start.y, end.x, end.y)
	if _routes.has(key):
		return _routes[key]
	if not _graph.is_in_boundsv(start) or not _graph.is_in_boundsv(end) or _graph.is_point_solid(start) or _graph.is_point_solid(end):
		return PackedVector2Array()
	var result := _graph.get_point_path(start, end)
	_routes[key] = result
	return result


func _fixture_point(building: Dictionary, kind: String) -> Vector2:
	for asset in assets:
		if asset.building_id != building.id or asset.kind != kind:
			continue
		var point := _asset_access_point(asset)
		if point != Vector2.INF:
			return point
	return Vector2.INF


func _asset_access_point(asset: Dictionary) -> Vector2:
	var building := building_by_id(asset.building_id)
	var r := asset_rect(asset)
	var candidates: Array[Vector2] = []
	for x in range(int(r.position.x) + 4, int(r.end.x), GRID):
		candidates.append(Vector2(x, r.end.y + 4))
		candidates.append(Vector2(x, r.position.y - 4))
	for y in range(int(r.position.y) + 4, int(r.end.y), GRID):
		candidates.append(Vector2(r.position.x - 4, y))
		candidates.append(Vector2(r.end.x + 4, y))
	for point in candidates:
		if building_rect(building).grow(-GRID).has_point(point) and not route(ENTRY, point).is_empty():
			return point
	return Vector2.INF


func room_points() -> Array[Vector2]:
	if _rooms_cached:
		return _rooms_cache.duplicate()
	var points: Array[Vector2] = []
	for building in buildings:
		if building.kind == "bedroom":
			var point := _fixture_point(building, "bed")
			if point != Vector2.INF:
				points.append(point)
	_rooms_cache = points
	_rooms_cached = true
	return points.duplicate()


func station_point(index: int) -> Vector2:
	if _stations_cache.has(index):
		return _stations_cache[index]
	if index < 0 or index > 2:
		return Vector2.INF
	var kind: String = ["reception", "buffet", "pool"][index]
	for building in buildings:
		if building.kind == kind:
			var point := door_point(building) if index == 2 else _fixture_point(building, "desk" if index == 0 else "counter")
			_stations_cache[index] = point
			return point
	return Vector2.INF


func dining_tables() -> Array[Dictionary]:
	if _dining_cached:
		return _dining_cache.duplicate(true)
	_dining_cached = true
	var counter := station_point(1)
	var pool := station_point(2)
	if counter == Vector2.INF or pool == Vector2.INF or route(counter, pool).is_empty():
		return []
	var tables := assets.filter(func(asset: Dictionary) -> bool: return asset.kind == "table")
	tables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var used_seats := {}
	for table in tables:
		var seats := _table_seats(table, counter, used_seats)
		if seats.size() == 2:
			_dining_cache.append({"id": table.id, "building_id": table.building_id,
				"seat": seats[0], "child": seats[1], "table_center": asset_rect(table).get_center()})
			used_seats[seats[0]] = true
			used_seats[seats[1]] = true
	return _dining_cache.duplicate(true)


func _table_seats(table: Dictionary, counter: Vector2, used_seats: Dictionary) -> Array[Vector2]:
	var building := building_by_id(table.building_id)
	var inside := building_rect(building).grow(-GRID)
	var r := asset_rect(table)
	var sides := [
		[Vector2(r.position.x + 4, r.end.y + 4), Vector2(r.end.x - 4, r.end.y + 4)],
		[Vector2(r.position.x - 4, r.position.y + 4), Vector2(r.position.x - 4, r.end.y - 4)],
		[Vector2(r.position.x + 4, r.position.y - 4), Vector2(r.end.x - 4, r.position.y - 4)],
		[Vector2(r.end.x + 4, r.position.y + 4), Vector2(r.end.x + 4, r.end.y - 4)],
	]
	var open_seats: Array[Vector2] = []
	for side_offset in range(sides.size()):
		var free_side: Array[Vector2] = []
		for point in sides[(table.rotation + side_offset) % sides.size()]:
			if used_seats.has(point) or not inside.has_point(point) or route(counter, point).is_empty():
				continue
			free_side.append(point)
			open_seats.append(point)
		if free_side.size() == 2:
			return free_side
	if open_seats.size() >= 2:
		return [open_seats[0], open_seats[1]]
	if open_seats.is_empty():
		return []
	# Older layouts can leave only one open table edge cell. Use the closest
	# connected aisle cell for the child instead of invalidating the restaurant.
	var seat := open_seats[0]
	for direction in [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]:
		var aisle: Vector2 = seat + direction * GRID
		if (inside.has_point(aisle) or aisle == door_point(building)) and not used_seats.has(aisle) and not route(seat, aisle).is_empty():
			return [seat, aisle]
	return []


func readiness() -> Dictionary:
	if not _readiness_cache.is_empty():
		return _readiness_cache.duplicate(true)
	var reasons: Array[String] = []
	var rooms := room_points().size()
	if rooms == 0:
		reasons.append("Add at least one bedroom with an accessible bed.")
	for index in range(3):
		var point := station_point(index)
		if point == Vector2.INF or route(ENTRY, point).is_empty():
			reasons.append(["Reception needs a reachable desk.", "Buffet needs a reachable counter.", "Pool needs a reachable entrance."][index])
	if dining_tables().is_empty():
		reasons.append("Add an accessible dining table to the buffet.")
	var loungers := 0
	var umbrellas := 0
	for building in buildings:
		if building.kind == "pool":
			for asset in assets:
				if asset.building_id == building.id and asset.kind in ["lounger", "umbrella"] and _asset_access_point(asset) != Vector2.INF:
					loungers += int(asset.kind == "lounger")
					umbrellas += int(asset.kind == "umbrella")
	_readiness_cache = {"ok": reasons.is_empty(), "reasons": reasons, "room_count": rooms, "terrace": loungers >= 2 and umbrellas >= 1}
	return _readiness_cache.duplicate(true)


func quote_diff(active: RefCounted, free_build: bool = false) -> Dictionary:
	var previous := {}
	var current := {}
	for entity in active.buildings + active.assets + active.landscape.props:
		previous[int(entity.id)] = entity
	for entity in buildings + assets + landscape.props:
		current[int(entity.id)] = entity
	var cost := 0
	var refund := 0
	for id in current:
		if not previous.has(id) and not free_build:
			var entity: Dictionary = current[id]
			cost += _entity_cost(entity)
	for id in previous:
		if not current.has(id) and not free_build:
			refund += int(floor(float(previous[id].get("paid_cost", 0)) * 0.5))
	if not free_build:
		cost += landscape.surface_quote(active.landscape)
		for building in buildings:
			if building.kind == "pool":
				continue
			var prior: Dictionary = previous.get(int(building.id), {})
			var prior_finishes: Dictionary = prior.get("finishes", DEFAULT_FINISHES)
			for surface in DEFAULT_FINISHES:
				var finish: String = building.get("finishes", DEFAULT_FINISHES)[surface]
				if finish != prior_finishes.get(surface, "default"):
					cost += int(FINISH_CATALOG[surface][finish].cost)
	return {"cost": cost, "refund": refund, "net": cost - refund}


func stamp_paid(active: RefCounted, free_build: bool = false) -> void:
	var previous := {}
	for entity in active.buildings + active.assets + active.landscape.props:
		previous[int(entity.id)] = entity
	for entity in buildings + assets + landscape.props:
		if previous.has(int(entity.id)):
			entity.paid_cost = int(previous[int(entity.id)].get("paid_cost", 0))
		else:
			entity.paid_cost = 0 if free_build else _entity_cost(entity)


func _entity_cost(entity: Dictionary) -> int:
	if entity.has("offset"):
		return int(Landscape.PROP_CATALOG[entity.kind].cost)
	return int(BUILDING_CATALOG[entity.kind].cost if BUILDING_CATALOG.has(entity.kind) else ASSET_CATALOG[entity.kind].cost)


func _install_default_props(defaults: Array, preserve_legacy_access: bool = true) -> void:
	for prop in defaults:
		if validate_prop(prop.kind, Vector2i(prop.cell[0], prop.cell[1]), int(prop.rotation), int(prop.variant)).ok:
			landscape.props.append(prop.duplicate(true))
	_invalidate()
	if not preserve_legacy_access:
		landscape.touch()
		return
	# Legacy custom layouts never had physical scenery obstacles. Preserve all
	# their reachable rooms/services if default props would obstruct a corridor.
	var with_props := room_points().size()
	var services: Array[Vector2] = [station_point(0), station_point(1), station_point(2)]
	var reachable: Array[bool] = []
	for point in services:
		reachable.append(point != Vector2.INF and not route(ENTRY, point).is_empty())
	var retained := landscape.props.duplicate(true)
	landscape.props.clear()
	_invalidate()
	var without_props := room_points().size()
	var preserve := without_props == with_props
	for index in range(3):
		var free_point := station_point(index)
		if free_point != Vector2.INF and not route(ENTRY, free_point).is_empty() and not reachable[index]:
			preserve = false
	if preserve:
		landscape.props.assign(retained)
	else:
		# Keep scenery away from the legacy hotel's required routes rather than
		# clearing the whole landscape when a single old corridor is obstructed.
		var required_points := room_points()
		for index in range(3):
			var point := station_point(index)
			if point != Vector2.INF:
				required_points.append(point)
		for building in buildings:
			if building.kind == "buffet":
				var table := _fixture_point(building, "table")
				if table != Vector2.INF:
					required_points.append(table)
		var route_cells := {}
		for point in required_points:
			for step in route(ENTRY, point):
				route_cells[_cell(step)] = true
		for prop in retained:
			var rect := prop_rect(prop)
			var blocks := false
			for cell in route_cells:
				if rect.has_point(landscape.cell_rect(cell).get_center()):
					blocks = true
					break
			if not blocks:
				landscape.props.append(prop)
	landscape.touch()
	_invalidate()


func prop_rect(prop: Dictionary) -> Rect2:
	return landscape.prop_rect(prop)


func prop_visual_rect(prop: Dictionary) -> Rect2:
	return landscape.prop_visual_rect(prop)


func prop_at(world: Vector2) -> Dictionary:
	for prop in landscape.props:
		if prop_rect(prop).has_point(world):
			return prop
	var found := {}
	var front_y := -INF
	for prop in landscape.props:
		if prop_visual_rect(prop).has_point(world) and prop_rect(prop).end.y > front_y:
			found = prop
			front_y = prop_rect(prop).end.y
	return found


func validate_prop(kind: String, cell: Vector2i, rotation: int = 0, variant: int = 0, ignore_id: int = -1) -> Dictionary:
	if not Landscape.PROP_CATALOG.has(kind) or rotation < 0 or rotation > 3 or variant < 0 or variant > 63:
		return _fail("Choose valid outdoor scenery.")
	if landscape.props.size() >= 512 and ignore_id < 0:
		return _fail("Outdoor scenery limit reached.")
	var rect := prop_rect({"kind": kind, "cell": [cell.x, cell.y], "rotation": rotation})
	if not _dry(rect):
		return _fail("Place scenery fully on dry land.")
	if rect.intersects(Rect2(48, 264, 24, 24)):
		return _fail("Keep the resort entrance clear.")
	for building in buildings:
		if rect.intersects(building_rect(building)):
			return _fail("Outdoor scenery cannot overlap a building.")
	for other in landscape.props:
		if int(other.id) == ignore_id:
			continue
		if rect.intersects(prop_rect(other)):
			return _fail("Outdoor scenery footprints cannot overlap.")
		if kind == "beach_flag" and other.kind == kind:
			return _fail("Move the existing beach flag, or remove it before placing another.")
	for y in range(int(rect.position.y / GRID), int(rect.end.y / GRID)):
		for x in range(int(rect.position.x / GRID), int(rect.end.x / GRID)):
			if not landscape.path_at(Vector2i(x, y)).is_empty():
				return _fail("Keep paths clear. Erase the path before placing scenery here.")
	return {"ok": true, "reason": "", "id": -1}


func add_prop(kind: String, cell: Vector2i, rotation: int = 0, variant: int = 0) -> Dictionary:
	var result := validate_prop(kind, cell, rotation, variant)
	if not result.ok:
		return result
	var id := landscape.allocate_prop_id()
	landscape.props.append({"id": id, "kind": kind, "cell": [cell.x, cell.y], "offset": [4, 4], "rotation": rotation, "variant": variant, "paid_cost": 0})
	landscape.touch()
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func move_prop(id: int, cell: Vector2i, rotation: int = -1) -> Dictionary:
	var prop := landscape.prop_by_id(id)
	if prop.is_empty():
		return _fail("No scenery selected.")
	var turn: int = prop.rotation if rotation == -1 else rotation
	var result := validate_prop(prop.kind, cell, turn, int(prop.variant), id)
	if not result.ok:
		return result
	prop.cell = [cell.x, cell.y]
	prop.rotation = turn
	landscape.touch()
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func remove_prop(id: int) -> Dictionary:
	var prop := landscape.prop_by_id(id)
	if prop.is_empty():
		return _fail("No scenery here.")
	landscape.props.erase(prop)
	landscape.touch()
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func validate_landscape_stroke(layer: String, value: String, cells: Array) -> Dictionary:
	if layer not in ["terrain", "path", "restore"] or cells.is_empty():
		return _fail("Draw a terrain or path stroke on the map.")
	if layer == "terrain" and value == "water":
		return _fail("The ocean and coastline are protected. Paint grass, sand or dirt on dry land.")
	if layer == "terrain" and not Landscape.TERRAIN_CATALOG.has(value):
		return _fail("Choose a terrain material.")
	if layer == "path" and value != "" and not Landscape.PATH_CATALOG.has(value):
		return _fail("Choose a path material or Erase path.")
	for cell in cells:
		if not cell is Vector2i or not Landscape.REGION.has_point(cell):
			return _fail("Keep the brush inside the resort map.")
		if not landscape.cell_is_dry(cell):
			return _fail("The ocean and coastline are protected. Keep the whole brush on dry land.")
		var rect := landscape.cell_rect(cell)
		for building in buildings:
			if rect.intersects(building_rect(building)):
				return _fail("Remove the building before editing the ground beneath it.")
		if layer == "path" and not value.is_empty():
			if not landscape.cell_is_dry(cell):
				return _fail("Paths need dry land; bridges are not available yet.")
			for prop in landscape.props:
				if rect.intersects(prop_rect(prop)):
					return _fail("Move or remove scenery before drawing a path here.")
		if layer == "restore" and not landscape.base_path_at(cell).is_empty():
			for prop in landscape.props:
				if rect.intersects(prop_rect(prop)):
					return _fail("Move scenery before restoring the original path here.")
	return {"ok": true, "reason": "", "id": -1}


func paint_landscape_stroke(layer: String, value: String, cells: Array) -> Dictionary:
	var result := validate_landscape_stroke(layer, value, cells)
	if not result.ok:
		return result
	var seen := {}
	var changed := 0
	for cell in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		var before := landscape.ground_signature(cell) + ":" + landscape.path_at(cell)
		match layer:
			"terrain": landscape.set_terrain(cell, value)
			"path": landscape.set_path(cell, value)
			"restore": landscape.restore_cell(cell)
		changed += int(before != landscape.ground_signature(cell) + ":" + landscape.path_at(cell))
	landscape.touch()
	_invalidate()
	return {"ok": true, "reason": "", "id": -1, "changed": changed}
