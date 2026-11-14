extends RefCounted
## Serializable construction geometry. Money is committed by the main controller.

const GRID := 8
const WORLD_BOUNDS := Rect2(-160, -120, 960, 600)
const ENTRY := Vector2(60, 276)
const SHORE := preload("res://assets/art/resort_shore.png")
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
var _graph: AStarGrid2D
var _dirty := true
var _shore: Image
var _routes := {}
var _readiness_cache := {}
var _rooms_cache: Array[Vector2] = []
var _rooms_cached := false
var _stations_cache := {}


func _init() -> void:
	_shore = SHORE.get_image()
	for i in range(4):
		var result := add_building("bedroom", Rect2(24 + 72 * i, 48, 64, 80))
		add_asset("bed", result.id, Vector2i(1, 1))
	var reception := add_building("reception", Rect2(32, 160, 112, 72))
	add_asset("desk", reception.id, Vector2i(3, 2))
	var buffet := add_building("buffet", Rect2(160, 160, 120, 72))
	add_asset("counter", buffet.id, Vector2i(2, 2))
	add_asset("table", buffet.id, Vector2i(9, 3))
	add_building("pool", Rect2(312, 160, 144, 80))
	# Starter hotel is owned, but carries no refundable construction expenditure.


func snapshot() -> Dictionary:
	return {"version": 1, "buildings": buildings.duplicate(true), "assets": assets.duplicate(true), "next_id": _next_id}


func duplicate_layout() -> RefCounted:
	var copy = get_script().new()
	copy.restore(snapshot())
	return copy


func restore(data: Dictionary) -> bool:
	if not data.get("buildings") is Array or not data.get("assets") is Array:
		return false
	if data.buildings.size() > 11 or data.assets.size() > 512:
		return false
	var old_buildings := buildings.duplicate(true)
	var old_assets := assets.duplicate(true)
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
	if not valid:
		buildings.assign(old_buildings)
		assets.assign(old_assets)
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


func building_rect(building: Dictionary) -> Rect2:
	var r: Array = building.rect
	return Rect2(r[0], r[1], r[2], r[3])


func building_by_id(id: int) -> Dictionary:
	for building in buildings:
		if building.id == id:
			return building
	return {}


func door_point(building: Dictionary) -> Vector2:
	var r := building_rect(building)
	return r.position + Vector2((floor(r.size.x / GRID / 2.0) + 0.5) * GRID, r.size.y - GRID / 2.0)


func water_rect(building: Dictionary) -> Rect2:
	var r := building_rect(building)
	return Rect2(r.position + Vector2(24, 16), r.size - Vector2(48, 40))


func _dry(rect: Rect2) -> bool:
	if not WORLD_BOUNDS.encloses(rect):
		return false
	for y in range(int(rect.position.y), int(rect.end.y)):
		var encoded := _shore.get_pixel(0, clampi(y + 120, 0, 599))
		var shore_x := -160 + encoded.r8 + (encoded.g8 << 8)
		if rect.end.x > shore_x - 8:
			return false
	return true


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
	if rect.intersects(Rect2(48, 264, 24, 24)) or rect.intersects(Rect2(464, 144, 24, 32)):
		return _fail("Keep the resort entrance and beach flag clear.")
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
	buildings.append({"id": id, "kind": kind, "rect": [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)], "paid_cost": 0})
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
		var land_end := 800
		for pixel_y in range(y * GRID, (y + 1) * GRID):
			var encoded := _shore.get_pixel(0, pixel_y + 120)
			land_end = mini(land_end, -160 + encoded.r8 + (encoded.g8 << 8) - 8)
		for x in range(-20, 100):
			if (x + 1) * GRID > land_end:
				_graph.set_point_solid(Vector2i(x, y))
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
	for asset in assets:
		var r := asset_rect(asset)
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
	var table_ok := false
	for building in buildings:
		if building.kind == "buffet":
			table_ok = _fixture_point(building, "table") != Vector2.INF
	if not table_ok:
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
	for entity in active.buildings + active.assets:
		previous[int(entity.id)] = entity
	for entity in buildings + assets:
		current[int(entity.id)] = entity
	var cost := 0
	var refund := 0
	for id in current:
		if not previous.has(id) and not free_build:
			var entity: Dictionary = current[id]
			cost += int(BUILDING_CATALOG[entity.kind].cost if BUILDING_CATALOG.has(entity.kind) else ASSET_CATALOG[entity.kind].cost)
	for id in previous:
		if not current.has(id) and not free_build:
			refund += int(floor(float(previous[id].get("paid_cost", 0)) * 0.5))
	return {"cost": cost, "refund": refund, "net": cost - refund}


func stamp_paid(active: RefCounted, free_build: bool = false) -> void:
	var previous := {}
	for entity in active.buildings + active.assets:
		previous[int(entity.id)] = entity
	for entity in buildings + assets:
		if previous.has(int(entity.id)):
			entity.paid_cost = int(previous[int(entity.id)].get("paid_cost", 0))
		else:
			entity.paid_cost = 0 if free_build else int(BUILDING_CATALOG[entity.kind].cost if BUILDING_CATALOG.has(entity.kind) else ASSET_CATALOG[entity.kind].cost)
