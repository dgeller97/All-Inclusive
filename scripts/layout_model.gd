extends RefCounted
## Serializable construction geometry. Money is committed by the main controller.

const Landscape := preload("res://scripts/landscape_model.gd")
const GRID := Landscape.GRID
const WORLD_BOUNDS := Landscape.WORLD_BOUNDS
const ENTRY := Vector2(60, 276)
const SHORE := preload("res://assets/art/resort_shore.png")
const MAX_BUILDING_NAME_LENGTH := 24
const DEFAULT_FINISHES := {"floor": "default", "wall": "default", "ceiling": "default", "facade": "default", "roof": "default"}
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
	"facade": {
		"default": {"label": "Original", "cost": 16}, "plaster": {"label": "Plaster", "cost": 16},
		"brick": {"label": "Brick", "cost": 16}, "timber": {"label": "Timber", "cost": 16},
	},
	"roof": {
		"default": {"label": "Original", "cost": 20}, "terracotta": {"label": "Terracotta", "cost": 20},
		"slate": {"label": "Slate", "cost": 20}, "metal": {"label": "Metal", "cost": 20},
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
const STARTER_AMENITIES := [
	{"kind": "beach_lounge", "cell": [60, 14]},
	{"kind": "volleyball", "cell": [45, 9], "rotation": 1},
	{"kind": "beach_bar", "cell": [52, 32]},
	{"kind": "stage", "cell": [40, 32]},
]
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
var _amenities_cache: Array[Dictionary] = []
var _amenities_cached := false
var _ocean_access := {}
var _ocean_access_cached := false


func _init(with_starter_amenities: bool = true) -> void:
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
	if with_starter_amenities:
		for i in range(STARTER_AMENITIES.size()):
			var prop: Dictionary = STARTER_AMENITIES[i].duplicate(true)
			prop.merge({"id": 1100000 + i, "offset": [4, 4], "rotation": 0, "variant": 0, "paid_cost": 0})
			default_props.append(prop)
	_install_default_props(default_props, false)
	# Starter hotel is owned, but carries no refundable construction expenditure.


func snapshot() -> Dictionary:
	return {"version": 4, "buildings": buildings.duplicate(true), "assets": assets.duplicate(true), "next_id": _next_id, "landscape": landscape.snapshot()}


func duplicate_layout() -> RefCounted:
	var copy = get_script().new(false)
	copy.restore(snapshot())
	return copy


func restore(data: Dictionary) -> bool:
	var version: Variant = data.get("version", 1)
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != int(version) or int(version) not in [1, 2, 3, 4]:
		return false
	if not data.get("buildings") is Array or not data.get("assets") is Array:
		return false
	if data.buildings.size() > 11 or data.assets.size() > 512:
		return false
	var old_buildings := buildings.duplicate(true)
	var old_assets := assets.duplicate(true)
	var old_landscape := landscape
	var old_next_id := _next_id
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
		var rotation: Variant = entity.get("rotation", 0 if int(version) < 4 else null)
		if not _valid_rotation(rotation):
			valid = false
			break
		var result := add_building(str(entity.get("kind", "")), Rect2(r[0], r[1], r[2], r[3]), int(rotation), false)
		if not result.ok or not _valid_paid(entity.get("paid_cost", 0)):
			valid = false
			break
		buildings[-1].id = int(entity.id)
		buildings[-1].paid_cost = int(entity.get("paid_cost", 0))
		if int(version) >= 3 and (not entity.has("display_name") or not entity.has("finishes")):
			valid = false
			break
		if entity.has("display_name"):
			if not entity.display_name is String or not set_building_name(int(entity.id), entity.display_name).ok:
				valid = false
				break
		if entity.has("finishes"):
			if not entity.finishes is Dictionary:
				valid = false
				break
			var surfaces := DEFAULT_FINISHES.keys() if int(version) >= 4 or entity.finishes.size() == DEFAULT_FINISHES.size() else ["floor", "wall", "ceiling"]
			if entity.finishes.size() != surfaces.size():
				valid = false
				break
			for surface in surfaces:
				if not entity.finishes.get(surface) is String or not _set_finish(buildings[-1], surface, entity.finishes[surface]):
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
			var result := add_asset(str(entity.get("kind", "")), int(entity.building_id), Vector2i(cell[0], cell[1]), int(rotation), false)
			if not result.ok:
				valid = false
				break
			assets[-1].id = int(entity.id)
			assets[-1].paid_cost = int(entity.get("paid_cost", 0))
			ids[int(entity.id)] = true
			_next_id = maxi(_next_id, int(entity.id) + 1)
	if valid and int(version) >= 4:
		for building in buildings:
			for member in building_unit(building.id):
				if member.finishes.facade != building.finishes.facade or member.finishes.roof != building.finishes.roof:
					valid = false
					break
			if not valid:
				break
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
		_next_id = old_next_id
	_invalidate()
	return valid


func _valid_id(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and value > 0 and value < 1000000000

func _valid_rotation(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == int(value) and value >= 0 and value <= 3


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
	_amenities_cache.clear()
	_amenities_cached = false
	_ocean_access.clear()
	_ocean_access_cached = false


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
	if building.kind == "pool" and choice != "default":
		return _fail("The pool is outdoors; enclosed-building finishes do not apply.")
	if not _set_finish(building, surface, choice):
		return _fail("Choose a valid finish.")
	if surface in ["facade", "roof"]:
		for member in building_unit(id):
			_set_finish(member, surface, choice)
	return {"ok": true, "reason": "", "id": id}


func _set_finish(building: Dictionary, surface: String, choice: String) -> bool:
	if not FINISH_CATALOG.has(surface) or not FINISH_CATALOG[surface].has(choice):
		return false
	if building.kind == "pool" and choice != "default":
		return false
	building.finishes[surface] = choice
	return true


func _rotate_rect(rect: Rect2, size: Vector2) -> Rect2:
	return Rect2(size.y - rect.end.y, rect.position.x, rect.size.y, rect.size.x)


func _building_feature(building: Dictionary, local: Rect2) -> Rect2:
	var bounds := building_rect(building)
	var rotation: int = building.get("rotation", 0)
	var size := _unrotated_size(building)
	for turn in range(rotation):
		local = _rotate_rect(local, size)
		size = Vector2(size.y, size.x)
	local.position += bounds.position
	return local


func _unrotated_size(building: Dictionary) -> Vector2:
	var size := building_rect(building).size
	return Vector2(size.y, size.x) if int(building.get("rotation", 0)) % 2 else size


func door_side(building: Dictionary) -> Vector2:
	return [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT][building.get("rotation", 0)]


func door_point(building: Dictionary) -> Vector2:
	var size := _unrotated_size(building)
	var cell := Rect2(floor(size.x / GRID / 2.0) * GRID, size.y - GRID, GRID, GRID)
	return _building_feature(building, cell).get_center()


func water_rect(building: Dictionary) -> Rect2:
	return _building_feature(building, Rect2(Vector2(24, 16), _unrotated_size(building) - Vector2(48, 40)))


func _dry(rect: Rect2) -> bool:
	return landscape.rect_is_dry(rect)


func validate_building(kind: String, rect: Rect2, rotation: int = 0, join_rooms: bool = true) -> Dictionary:
	if not BUILDING_CATALOG.has(kind):
		return _fail("Choose a building type.")
	var minimum: Array = BUILDING_CATALOG[kind].min_size
	if rotation % 2:
		minimum = [minimum[1], minimum[0]]
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
	if join_rooms:
		var candidate := {"id": -1, "kind": kind, "rect": _rect_data(rect)}
		for neighbor in buildings:
			if not _shared_wall(candidate, neighbor).is_empty() and _shared_passage(candidate, neighbor).is_empty():
				return _fail("Leave room for a doorway along the shared wall.")
	return {"ok": true, "reason": "", "id": -1}


func add_building(kind: String, rect: Rect2, rotation: int = 0, join_rooms: bool = true) -> Dictionary:
	rotation = posmod(rotation, 4)
	var result := validate_building(kind, rect, rotation, join_rooms)
	if not result.ok:
		return result
	var id := _next_id
	var building := {"id": id, "kind": kind, "rect": _rect_data(rect), "rotation": rotation,
		"paid_cost": 0, "display_name": _default_building_name(kind), "finishes": DEFAULT_FINISHES.duplicate()}
	_next_id += 1
	buildings.append(building)
	if join_rooms:
		_normalize_exterior(id)
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func _rect_data(rect: Rect2) -> Array:
	return [int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y)]


func building_unit(id: int) -> Array[Dictionary]:
	var building := building_by_id(id)
	var unit: Array[Dictionary] = []
	if building.is_empty():
		return unit
	unit.append(building)
	var included := {id: true}
	var index := 0
	while index < unit.size():
		for neighbor in buildings:
			if not included.has(neighbor.id) and not _shared_passage(unit[index], neighbor).is_empty():
				included[neighbor.id] = true
				unit.append(neighbor)
		index += 1
	unit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	return unit


func _normalize_exterior(id: int) -> void:
	var unit := building_unit(id)
	for surface in ["facade", "roof"]:
		var finish: String = unit[0].finishes[surface]
		for member in unit:
			member.finishes[surface] = finish


func _shared_wall(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.kind == "pool" or b.kind == "pool":
		return {}
	var first := building_rect(a)
	var second := building_rect(b)
	if first.end.x == second.position.x or first.position.x == second.end.x:
		var start := maxf(first.position.y, second.position.y)
		var end := minf(first.end.y, second.end.y)
		if end - start >= 2 * GRID:
			var side := Vector2.RIGHT if first.end.x == second.position.x else Vector2.LEFT
			return {"side": side, "start": start, "end": end, "edge": first.end.x if side.x > 0 else first.position.x}
	if first.end.y == second.position.y or first.position.y == second.end.y:
		var start := maxf(first.position.x, second.position.x)
		var end := minf(first.end.x, second.end.x)
		if end - start >= 2 * GRID:
			var side := Vector2.DOWN if first.end.y == second.position.y else Vector2.UP
			return {"side": side, "start": start, "end": end, "edge": first.end.y if side.y > 0 else first.position.y}
	return {}


func _shared_passage(a: Dictionary, b: Dictionary, extra := Rect2(), ignore_id: int = -1) -> Array[Vector2]:
	var doors: Array[Vector2] = []
	var wall := _shared_wall(a, b)
	if wall.is_empty():
		return doors
	var side: Vector2 = wall.side
	var left := building_rect(a).grow(-GRID)
	var right := building_rect(b).grow(-GRID)
	var center := (float(wall.start) + float(wall.end)) * 0.5
	var first_steps: Array[int] = []
	var second_steps: Array[int] = []
	var best_distance := INF
	var from_axis := 0
	var to_axis := 0
	for axis in range(int(wall.start) + GRID / 2, int(wall.end), GRID):
		var edge := Vector2(wall.edge, axis) if side.x else Vector2(axis, wall.edge)
		var first := edge - side * (GRID * 1.5)
		var second := edge + side * (GRID * 1.5)
		if left.has_point(first) and _clear_passage_step(first, a.id, extra, ignore_id):
			first_steps.append(axis)
		if right.has_point(second) and _clear_passage_step(second, b.id, extra, ignore_id):
			second_steps.append(axis)
	for first in first_steps:
		for second in second_steps:
			if absi(first - second) > GRID:
				continue
			var distance := absi(first - second) * 100.0 + absf((first + second) * 0.5 - center)
			if distance < best_distance:
				best_distance = distance
				from_axis = mini(first, second)
				to_axis = maxi(first, second)
	if not is_finite(best_distance):
		return doors
	for axis in range(from_axis, to_axis + 1, GRID):
		var edge := Vector2(wall.edge, axis) if side.x else Vector2(axis, wall.edge)
		doors.append(edge - side * GRID * 0.5)
	return doors


func _clear_passage_step(point: Vector2, building_id: int, extra: Rect2, ignore_id: int) -> bool:
	if extra.has_point(point):
		return false
	for asset in assets:
		if asset.id != ignore_id and asset.building_id == building_id and asset_rect(asset).has_point(point):
			return false
	return true


func shared_doors(building: Dictionary) -> Array[Vector2]:
	var doors: Array[Vector2] = []
	for neighbor in buildings:
		if neighbor.id == building.id:
			continue
		doors.append_array(_shared_passage(building, neighbor))
	return doors


func external_door_open(building: Dictionary) -> bool:
	var outside := building_at(door_point(building) + door_side(building) * GRID)
	return outside.is_empty() or outside.kind == "pool"


func rotate_building(id: int) -> Dictionary:
	var unit := building_unit(id)
	if unit.is_empty():
		return _fail("Select a building to rotate it.")
	var bounds := building_rect(unit[0])
	var members := {}
	for member in unit:
		members[member.id] = member
		bounds = bounds.merge(building_rect(member))
	var data := snapshot()
	for building in data.buildings:
		if not members.has(building.id):
			continue
		var local := building_rect(building)
		local.position -= bounds.position
		var turned := _rotate_rect(local, bounds.size)
		turned.position += bounds.position
		building.rect = _rect_data(turned)
		building.rotation = posmod(int(building.rotation) + 1, 4)
	for asset in data.assets:
		if not members.has(asset.building_id):
			continue
		var parent := building_rect(members[asset.building_id])
		var local := Rect2(Vector2(asset.cell[0], asset.cell[1]) * GRID, asset_rect(asset).size)
		var position := Vector2i(_rotate_rect(local, parent.size).position / GRID)
		asset.cell = [position.x, position.y]
		asset.rotation = posmod(int(asset.rotation) + 1, 4)
	var next_id := _next_id
	var candidate: RefCounted = get_script().new(false)
	var valid: bool = candidate.restore(data)
	_next_id = next_id
	if not valid:
		return _fail("Rotation needs clear land for the building, furnishings and surroundings.")
	if not _preserves_access(candidate):
		return _fail("Rotation would block a route to a room or facility.")
	if candidate.building_unit(id).size() != unit.size():
		return _fail("Leave space between the rotated unit and other buildings.")
	for member in unit:
		for neighbor in unit:
			if member.id < neighbor.id and not _shared_passage(member, neighbor).is_empty():
				if candidate._shared_passage(candidate.building_by_id(member.id), candidate.building_by_id(neighbor.id)).is_empty():
					return _fail("Rotation would block an interior doorway.")
	buildings.assign(candidate.buildings)
	assets.assign(candidate.assets)
	_normalize_exterior(id)
	_invalidate()
	return {"ok": true, "reason": "", "id": id}


func _preserves_access(candidate: RefCounted) -> bool:
	for building in buildings:
		if building.kind == "bedroom" and _fixture_point(building, "bed").is_finite():
			if not candidate._fixture_point(candidate.building_by_id(building.id), "bed").is_finite():
				return false
	for station in range(3):
		if not route(ENTRY, station_point(station)).is_empty() and candidate.route(ENTRY, candidate.station_point(station)).is_empty():
			return false
	var remaining_tables: Array[Dictionary] = candidate.dining_tables()
	for table in dining_tables():
		if not remaining_tables.any(func(other: Dictionary) -> bool: return other.id == table.id):
			return false
	for amenity in amenities():
		if candidate.amenity_by_id(amenity.id).is_empty():
			return false
	return ocean_access().is_empty() or not candidate.ocean_access().is_empty()


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


func validate_asset(kind: String, building_id: int, cell: Vector2i, rotation: int = 0, ignore_id: int = -1, check_passages: bool = true) -> Dictionary:
	var building := building_by_id(building_id)
	if not ASSET_CATALOG.has(kind) or building.is_empty():
		return _fail("Place furnishings inside a building or on a pool deck.")
	if assets.size() >= 512 and ignore_id < 0:
		return _fail("Furniture limit reached.")
	var allowed: Array = ASSET_CATALOG[kind].allowed
	if not allowed.is_empty() and not building.kind in allowed:
		return _fail("%s belongs in: %s." % [ASSET_CATALOG[kind].label, ", ".join(allowed)])
	var rect := asset_rect({"kind": kind, "building_id": building_id, "cell": [cell.x, cell.y], "rotation": rotation})
	if not building_rect(building).grow(-GRID).encloses(rect):
		return _fail("Keep furnishings inside the walls or deck edge.")
	var door := door_point(building)
	if rect.has_point(door - door_side(building) * GRID):
		return _fail("Leave the doorway and its inside approach clear.")
	if building.kind == "pool" and rect.intersects(water_rect(building)):
		return _fail("Place furnishings on the deck, outside the pool water.")
	for asset in assets:
		if asset.id != ignore_id and rect.intersects(asset_rect(asset)):
			return _fail("Furniture cannot overlap.")
	if check_passages:
		for neighbor in buildings:
			if neighbor.id != building.id and not _shared_passage(building, neighbor).is_empty() and _shared_passage(building, neighbor, rect, ignore_id).is_empty():
				return _fail("Leave the shared doorway and its approach clear.")
	return {"ok": true, "reason": "", "id": -1}


func add_asset(kind: String, building_id: int, cell: Vector2i, rotation: int = 0, check_passages: bool = true) -> Dictionary:
	var result := validate_asset(kind, building_id, cell, rotation, -1, check_passages)
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


func rotate_asset(id: int) -> Dictionary:
	for asset in assets:
		if asset.id != id:
			continue
		var rotation := posmod(int(asset.rotation) + 1, 4)
		var result := validate_asset(asset.kind, asset.building_id, Vector2i(asset.cell[0], asset.cell[1]), rotation, id)
		if not result.ok:
			return result
		var original := int(asset.rotation)
		var had_room := _fixture_point(building_by_id(asset.building_id), "bed").is_finite()
		var readiness_before := readiness()
		asset.rotation = rotation
		_invalidate()
		if (readiness_before.ok and not readiness().ok) or (had_room and not _fixture_point(building_by_id(asset.building_id), "bed").is_finite()):
			asset.rotation = original
			_invalidate()
			return _fail("Rotation would block an important route.")
		return {"ok": true, "reason": "", "id": id}
	return _fail("Select a furnishing to rotate it.")


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
	_graph.region = Landscape.REGION
	_graph.cell_size = Vector2(GRID, GRID)
	_graph.offset = Vector2(4, 4)
	_graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_graph.update()
	# Paint collision regions once per edit, rather than testing every furnishing
	# against every world cell. Dense furnished layouts keep the same edit cost.
	for y in range(Landscape.REGION.position.y, Landscape.REGION.end.y):
		for x in range(Landscape.REGION.position.x, Landscape.REGION.end.x):
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
			if external_door_open(building):
				_graph.set_point_solid(_cell(door_point(building)), false)
			for door in shared_doors(building):
				_graph.set_point_solid(_cell(door), false)
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
	if not from.is_finite() or not to.is_finite():
		return PackedVector2Array()
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


func ocean_access() -> Dictionary:
	if _ocean_access_cached:
		return _ocean_access.duplicate()
	_ocean_access_cached = true
	# Search the fixed beach near the central resort before fallback rows.
	for offset in range(30):
		var y := 19 + (offset + 1) / 2 * (1 if offset % 2 else -1)
		var world_y := float(y * GRID + GRID / 2)
		for x in range(89, 48, -1):
			var cell := Vector2i(x, y)
			if not landscape.cell_is_dry(cell):
				continue
			var shore := landscape.cell_rect(cell).get_center()
			if not landscape.is_water_pixel(shore + Vector2(16, 0)) or route(ENTRY, shore).is_empty() or not building_at(shore).is_empty():
				break
			var water := Vector2(shore.x + 32, world_y)
			if landscape.is_water_pixel(water):
				_ocean_access = {"shore": shore, "water": water}
				return _ocean_access.duplicate()
			break
	return {}


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
	# Prefer diners across the tabletop. These two sides keep both seats
	# reachable without requiring space in front of or behind the table.
	var west: Array = sides[1]
	var east: Array = sides[3]
	for pair: Array in [[west[1], east[1]], [west[0], east[0]], [west[1], east[0]], [west[0], east[1]]]:
		if _table_seat_open(pair[0], inside, counter, used_seats) and _table_seat_open(pair[1], inside, counter, used_seats):
			return [pair[0], pair[1]]
	var open_seats: Array[Vector2] = []
	for side_offset in range(sides.size()):
		var free_side: Array[Vector2] = []
		for point in sides[(table.rotation + side_offset) % sides.size()]:
			if not _table_seat_open(point, inside, counter, used_seats):
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


func _table_seat_open(point: Vector2, interior: Rect2, counter: Vector2, used_seats: Dictionary) -> bool:
	return interior.has_point(point) and not used_seats.has(point) and not route(counter, point).is_empty()


func amenities(kind: String = "") -> Array[Dictionary]:
	if not _amenities_cached:
		_amenities_cached = true
		for prop in landscape.props:
			var info: Dictionary = Landscape.PROP_CATALOG[prop.kind]
			if not info.has("capacity"):
				continue
			var bounds := prop_rect(prop)
			var access := _facility_access(prop) if info.get("gate", false) else _amenity_access(bounds)
			if access != Vector2.INF:
				_amenities_cache.append({
					"id": prop.id, "kind": prop.kind, "point": access, "rect": bounds,
					"capacity": info.capacity, "rotation": prop.rotation,
				})
		_amenities_cache.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var found: Array[Dictionary] = []
	for amenity in _amenities_cache:
		if kind.is_empty() or amenity.kind == kind:
			found.append(amenity.duplicate())
	return found


func amenity_by_id(id: int) -> Dictionary:
	for amenity in amenities():
		if amenity.id == id:
			return amenity
	return {}


func facility_gate(prop: Dictionary) -> Vector2:
	var bounds := prop_rect(prop)
	var dimensions: Array = Landscape.PROP_CATALOG[prop.kind].size
	var size := Vector2(dimensions[0], dimensions[1]) * GRID
	var gate := Rect2(floorf(size.x / GRID / 2.0) * GRID, size.y, GRID, GRID)
	for turn in range(prop.rotation):
		gate = _rotate_rect(gate, size)
		size = Vector2(size.y, size.x)
	return bounds.position + gate.get_center()


func _facility_access(prop: Dictionary) -> Vector2:
	var point := facility_gate(prop)
	if not building_at(point).is_empty() or route(ENTRY, point).is_empty():
		return Vector2.INF
	return point


func _amenity_access(bounds: Rect2) -> Vector2:
	var footprint := Rect2i(_cell(bounds.position), Vector2i(bounds.size / GRID))
	var preferred := Vector2(bounds.get_center().x, bounds.end.y + GRID * 0.5)
	var candidates: Array[Vector2] = []
	for x in range(footprint.position.x, footprint.end.x):
		candidates.append(landscape.cell_rect(Vector2i(x, footprint.end.y)).get_center())
		candidates.append(landscape.cell_rect(Vector2i(x, footprint.position.y - 1)).get_center())
	for y in range(footprint.position.y, footprint.end.y):
		candidates.append(landscape.cell_rect(Vector2i(footprint.position.x - 1, y)).get_center())
		candidates.append(landscape.cell_rect(Vector2i(footprint.end.x, y)).get_center())
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(preferred) < b.distance_squared_to(preferred)
	)
	for point in candidates:
		# A service door can be traversable, but an outdoor venue may not use it
		# or otherwise put its entrance inside a building.
		if building_at(point).is_empty() and not route(ENTRY, point).is_empty():
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
