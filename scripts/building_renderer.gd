extends Node2D

## Interior and exterior architecture painted from the current world layout.
const GRID := 8
const ATLAS_CELL := 40
const FURNITURE_LIFT := Vector2(0, 6)
const FURNITURE := preload("res://assets/art/furniture.png")
const FurnitureDepth := preload("res://scripts/furniture_depth.gd")
const Finishes := preload("res://assets/art/building_finishes.gd")
const Landscape := preload("res://scripts/landscape_model.gd")
const WORLD_TOP := Landscape.WORLD_ORIGIN.y
const FURNITURE_ROWS := {
	"bed": 0, "desk": 1, "counter": 2, "table": 3,
	"lounger": 4, "umbrella": 5, "plant": 6, "bench": 7,
}

const FLOOR := {
	"bedroom": [Color("#aec3ae"), Color("#a4bba7"), Color("#97ae9e")],
	"reception": [Color("#dcc2a4"), Color("#d4b99f"), Color("#c7aa8e")],
	"buffet": [Color("#ebcda2"), Color("#e3c29a"), Color("#d1ad89")],
	"pool": [Color("#e9cda6"), Color("#e2c29d"), Color("#d1ae8a")],
}

const ROOF := {
	"bedroom": [Color("#a5574d"), Color("#d58360"), Color("#f2af7a")],
	"reception": [Color("#8f5060"), Color("#b77172"), Color("#db9b89")],
	"buffet": [Color("#8f654c"), Color("#c18a57"), Color("#efb975")],
}

const EXTERIOR_ROOF := {
	"bedroom": [Color("#744449"), Color("#aa5b4f"), Color("#c87358"), Color("#e29566")],
	"reception": [Color("#754343"), Color("#a65849"), Color("#bd6b4e"), Color("#e29265")],
	"buffet": [Color("#73433c"), Color("#a05c43"), Color("#c77d51"), Color("#e6a56a")],
}
const ROOF_FINISHES := {
	"terracotta": [Color("#8d493a"), Color("#ac6547"), Color("#ca8050"), Color("#f2b476")],
	"slate": [Color("#45526b"), Color("#56667e"), Color("#6f8291"), Color("#a6b4ba")],
	"metal": [Color("#3e6263"), Color("#5e857f"), Color("#79a49d"), Color("#a7d2c3")],
}
const DEFAULT_NAMES := {"bedroom": "Bedroom", "reception": "Lobby", "buffet": "Restaurant", "pool": "Pool"}
const FACADE_HEIGHT := 32
const SIGN_FONT_SIZE := 9
const SIGN_BORDER := Color("#cba374")
const SIGN_FACE := Color("#38454a")
const SIGN_SHADOW := Color("#704b43")

const IVORY := Color("#fff0c8")
const ASH := Color("#865f59")
const PLASTER := Color("#efc89e")
const STONE := Color("#b9886c")
const STONE_LIGHT := Color("#d6a683")
const STONE_SHADE := Color("#a87964")
const AMBIENT_SHADOW := Color(0.31, 0.22, 0.26, 0.16)

var _buildings: Array = []
var _assets: Array = []
var _pools: Array[Rect2i] = []
var _pool_animation := Node2D.new()
var _animation_frame := -1
var _exterior := false
var _ceiling_building_id := -1
var _hidden_buildings: Dictionary = {}
var _units: Dictionary = {}
var _night_light := 0.0
var _interleave := false
var _depth_cache: Array[Dictionary] = []
var _depth_dirty := true
var _capture := false
var _commands: Array[Dictionary] = []
var _capture_depth := 0.0
var _capture_tag := ""
var _capture_rows := false
var _draw_target: CanvasItem
var _plaque_layer := Node2D.new()


func _init() -> void:
	_pool_animation.name = "PoolSurface"
	_pool_animation.draw.connect(_draw_pool_animation)
	add_child(_pool_animation)
	_plaque_layer.name = "BuildingSigns"
	_plaque_layer.z_index = 2
	_plaque_layer.draw.connect(_draw_interleaved_signs)
	add_child(_plaque_layer)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


# `rect` is the world pixel footprint. Assets carry the resolved, rotated rect.
func present(buildings: Array, assets: Array, visual_time: float = 0.0) -> void:
	if _buildings != buildings or _assets != assets:
		_depth_dirty = true
		_buildings = buildings.duplicate(true)
		_assets = assets.duplicate(true)
		_pools.clear()
		_units.clear()
		for building in _buildings:
			if building.kind == "pool":
				_pools.append(_as_rect(building.get("water", _water_rect(_as_rect(building.rect)))))
			var unit := int(building.get("unit_id", building.id))
			if not _units.has(unit):
				_units[unit] = []
			_units[unit].append(building)
		_rebuild_hidden_buildings()
		queue_redraw()
		_pool_animation.queue_redraw()
		_plaque_layer.queue_redraw()
	advance_time(visual_time)


static func resolve_buildings(layout) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for building: Dictionary in layout.buildings:
		var entry := building.duplicate(true)
		entry.door = layout.door_point(building)
		entry.door_side = layout.door_side(building)
		entry.exterior_door = layout.external_door_open(building)
		entry.shared_doors = layout.shared_doors(building)
		entry.unit_id = layout.building_unit(building.id)[0].id
		if building.kind == "pool":
			entry.water = Rect2i(layout.water_rect(building))
		resolved.append(entry)
	return resolved


func set_daylight(daylight: float) -> void:
	var light := roundf((1.0 - daylight) * 12.0) / 12.0
	if _night_light != light:
		_night_light = light
		_depth_dirty = true
		queue_redraw()
		_plaque_layer.queue_redraw()


func set_view(exterior: bool, ceiling_building_id: int = -1) -> void:
	var ceiling := -1 if exterior else ceiling_building_id
	if _exterior == exterior and _ceiling_building_id == ceiling:
		return
	_exterior = exterior
	_depth_dirty = true
	_ceiling_building_id = ceiling
	_rebuild_hidden_buildings()
	queue_redraw()
	_plaque_layer.queue_redraw()


func set_interleave(enabled: bool) -> void:
	if _interleave != enabled:
		_interleave = enabled
		queue_redraw()
		_plaque_layer.queue_redraw()


func _draw_interleaved_signs() -> void:
	if not _interleave:
		return
	_draw_target = _plaque_layer
	for building in _buildings:
		if not _exterior or building.id == building.get("unit_id", building.id):
			_draw_building_plaque(building)
	_draw_target = null


func depth_items() -> Array[Dictionary]:
	if not _depth_dirty:
		return _depth_cache
	_depth_cache.clear()
	for asset in _assets:
		if _hidden_buildings.has(asset.get("building_id", -1)):
			continue
		var bounds := Rect2(_as_rect(asset.rect))
		for layer in FurnitureDepth.data(asset.kind, int(asset.get("rotation", 0))).layers:
			var position: Vector2 = bounds.position + layer.offset
			_depth_cache.append({"kind": "asset", "tag": "dining_table" if asset.kind == "table" else "furniture_" + asset.kind,
				"depth": bounds.position.y + layer.depth, "position": position, "texture": layer.texture,
				"bounds": Rect2(position, layer.texture.get_size()), "image": layer.image, "asset_id": asset.get("id", -1)})
	_capture = true
	for building in _buildings:
		var bounds := _as_rect(building.rect)
		_commands.clear()
		_capture_rows = false
		_capture_depth = bounds.end.y
		if building.kind == "pool":
			_capture_tag = "pool_edge"
			_capture_pool_edges(bounds, building)
		elif _exterior:
			_capture_tag = "exterior"
			var members: Array = _units[building.get("unit_id", building.id)]
			if members[0].id != building.id:
				continue
			if members.size() == 1:
				_draw_exterior(bounds, building, _roof_overhang(bounds))
			else:
				for member in members:
					_capture_depth = maxf(_capture_depth, _as_rect(member.rect).end.y)
				_draw_unit_exterior(members)
		else:
			_capture_tag = "room_wall"
			_draw_room_walls(bounds, building)
		_flush_capture(int(building.id))
	_capture = false
	_capture_rows = false
	_commands.clear()
	_depth_dirty = false
	return _depth_cache


func _flush_capture(building_id: int) -> void:
	var groups := {}
	for command in _commands:
		var key: String = str(command.depth) + ":" + command.tag
		if not groups.has(key):
			groups[key] = []
		groups[key].append(command)
	for group: Array in groups.values():
		var area: Rect2i = group[0].rect
		for command in group:
			area = area.merge(command.rect)
		if not area.has_area():
			continue
		var image := Image.create(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
		for command in group:
			var rect: Rect2i = command.rect
			if command.has("texture"):
				var tile: Image = command.texture.get_image()
				var origin: Vector2i = command.get("tile_origin", rect.position)
				for y in rect.size.y:
					for x in rect.size.x:
						var sample := rect.position - origin + Vector2i(x, y)
						image.set_pixelv(rect.position - area.position + Vector2i(x, y), tile.get_pixel(posmod(sample.x, tile.get_width()), posmod(sample.y, tile.get_height())) * command.color)
			elif command.color.a >= 0.99:
				image.fill_rect(Rect2i(rect.position - area.position, rect.size), command.color)
			else:
				var patch := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
				patch.fill(command.color)
				image.blend_rect(patch, Rect2i(Vector2i.ZERO, rect.size), rect.position - area.position)
		var texture := ImageTexture.create_from_image(image)
		_depth_cache.append({"kind": "asset", "tag": group[0].tag, "depth": group[0].depth,
			"position": Vector2(area.position), "texture": texture, "image": image, "bounds": Rect2(area), "asset_id": -building_id})


func _capture_pool_edges(bounds: Rect2i, building: Dictionary) -> void:
	var water := _as_rect(building.get("water", _water_rect(bounds)))
	_capture_depth = water.end.y + 1
	_block(water.position.x - 2, water.end.y, water.size.x + 4, 2, IVORY)
	_block(water.position.x - 2, water.end.y + 2, water.size.x + 4, 1, Color("#aca183"))
	_block(water.position.x - 1, water.end.y, water.size.x + 2, 1, Color("#c7c899"))
	for x in range(water.position.x + 4, water.end.x - 2, 5):
		_block(x, water.end.y, 1, 1, Color("#b6b383"))
	var turn := int(building.get("rotation", 0))
	var original := Vector2(bounds.size) if turn % 2 == 0 else Vector2(bounds.size.y, bounds.size.x)
	var ladder := _turn_point(Vector2(bounds.position), original, turn, Vector2(34, 16))
	var side: Vector2 = building.get("door_side", Vector2.DOWN)
	var tangent := Vector2(side.y, -side.x)
	_capture_tag = "pool_ladder"
	for offset in [-3, 3]:
		var post := Vector2i(ladder - side * 2 + tangent * offset)
		_capture_depth = post.y
		_block(post.x, post.y - 3, 1, 4, IVORY)


func is_interior_hidden(point: Vector2) -> bool:
	for id in _hidden_buildings:
		var bounds: Rect2 = _hidden_buildings[id]
		if bounds.has_point(point):
			return true
	return false


static func finish_preview(surface: String, choice: String) -> Texture2D:
	return Finishes.texture(surface, choice)


func _rebuild_hidden_buildings() -> void:
	_hidden_buildings.clear()
	for building in _buildings:
		var id := int(building.get("id", -1))
		if building.kind != "pool" and (_exterior or id > 0 and id == _ceiling_building_id):
			_hidden_buildings[id] = Rect2(_as_rect(building.rect))


func advance_time(visual_time: float) -> void:
	var frame := floori(visual_time * 10.0)
	if frame != _animation_frame:
		_animation_frame = frame
		if not _pools.is_empty():
			_pool_animation.queue_redraw()


func _draw() -> void:
	for building in _buildings:
		var bounds := _as_rect(building.rect)
		var kind: String = building.kind
		if kind == "pool":
			_draw_platform(bounds, FLOOR[kind], _finish(building, "floor"))
			_draw_pool(bounds, building)
		elif _exterior:
			if _interleave:
				continue
			var members: Array = _units[building.get("unit_id", building.id)]
			if members.size() == 1:
				_draw_exterior(bounds, building, _roof_overhang(bounds))
			elif members[0].id == building.id:
				_draw_unit_exterior(members)
		else:
			_draw_platform(bounds, FLOOR[kind], _finish(building, "floor"))
	if not _exterior:
		for building in _buildings:
			if building.kind == "pool":
				continue
			var bounds := _as_rect(building.rect)
			if _hidden_buildings.has(building.get("id", -1)):
				_draw_ceiling(bounds, _finish(building, "ceiling"))
			if not _interleave:
				_draw_room_walls(bounds, building)
	for asset in _assets:
		if not _hidden_buildings.has(asset.get("building_id", -1)):
			_draw_asset(asset)
	for building in _buildings:
		# A joined exterior has a single sign. Each room keeps its own sign in cutaway.
		if not _interleave and (not _exterior or building.id == building.get("unit_id", building.id)):
			_draw_building_plaque(building)


static func _finish(building: Dictionary, surface: String) -> String:
	return building.get("finishes", {}).get(surface, "default")


static func _as_rect(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value
	if value is Rect2:
		return Rect2i(value)
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


static func _entrance_x(bounds: Rect2i) -> int:
	return bounds.position.x + floori(float(bounds.size.x) / (2 * GRID)) * GRID


static func _water_rect(bounds: Rect2i) -> Rect2i:
	return Rect2i(bounds.position + Vector2i(24, 16), bounds.size - Vector2i(48, 40))


static func _turn_point(origin: Vector2, size: Vector2, rotation: int, local: Vector2) -> Vector2:
	match rotation:
		1: return origin + Vector2(size.y - local.y, local.x)
		2: return origin + size - local
		3: return origin + Vector2(local.y, size.x - local.x)
	return origin + local


static func _door(building: Dictionary, bounds: Rect2i) -> Vector2:
	return building.get("door", Vector2(_entrance_x(bounds) + 4, bounds.end.y - 4))


func _roof_overhang(bounds: Rect2i) -> int:
	var north := Rect2i(bounds.position - Vector2i(0, GRID), Vector2i(bounds.size.x, GRID))
	if north.position.y < WORLD_TOP:
		return 0
	for building in _buildings:
		if north.intersects(_as_rect(building.rect)):
			return 0
	return GRID


func _draw_platform(bounds: Rect2i, palette: Array, finish: String = "default") -> void:
	var left := bounds.position.x
	var top := bounds.position.y
	var right := bounds.end.x
	var bottom := bounds.end.y
	_block(left, top, bounds.size.x, bounds.size.y, AMBIENT_SHADOW)
	_block(left, top, bounds.size.x - 1, bounds.size.y - 1, STONE_SHADE)
	if finish == "default":
		_block(left, top, bounds.size.x - 2, bounds.size.y - 3, palette[0])
		for row in range(top, bottom - 3, 8):
			var height := mini(8, bottom - 3 - row)
			var offset := 6 if (row - top) % 16 == 0 else 12
			for col in range(left + offset, right - 2, 12):
				var width := mini(12, right - 2 - col)
				if (row + col - top - left) % 24 < 12:
					_block(col, row, width, height, palette[1])
				_block(col, row, 1, height, palette[2])
			_block(left, row, bounds.size.x - 2, 1, palette[2])
	else:
		_surface(Rect2i(left, top, bounds.size.x - 2, bounds.size.y - 3), "floor", finish)
	_block(left, bottom - 3, bounds.size.x - 2, 1, Color("#f4d9ae"))
	for x in range(left + 4, right - 2, 9):
		_block(x, bottom - 2, 1, 1, STONE_LIGHT)


func _draw_room_walls(bounds: Rect2i, building: Dictionary) -> void:
	var finish := _finish(building, "wall")
	var roof: Array = ROOF[building.kind]
	var doors: Array = building.get("shared_doors", []).duplicate()
	if building.get("exterior_door", true):
		doors.append(_door(building, bounds))
	var members: Array = _units[building.get("unit_id", building.id)]
	for side: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var tangent := Vector2i.RIGHT if side.y != 0 else Vector2i.DOWN
		var extent := bounds.size.x if side.y != 0 else bounds.size.y
		var start := bounds.position + Vector2i(4, 4)
		if side.x > 0:
			start.x = bounds.end.x - 4
		if side.y > 0:
			start.y = bounds.end.y - 4
		for offset in range(0, extent, GRID):
			var center := start + tangent * offset
			var cell := Rect2i(center - Vector2i(4, 4), Vector2i(GRID, GRID))
			if _capture:
				_capture_depth = cell.end.y - 1
				_capture_rows = side.x != 0
			# One drawing pass per edge cell keeps a real opening in both rooms' walls.
			if doors.has(Vector2(center)):
				if _capture:
					_capture_depth = -1000000.0
					_capture_rows = false
				_draw_threshold(cell, Vector2(side))
				continue
			var shared := false
			for neighbor: Dictionary in members:
				if neighbor.id != building.id and _as_rect(neighbor.rect).has_point(center + side * GRID):
					shared = true
					break
			if shared:
				var edge := cell.position + Vector2i(maxi(side.x, 0), maxi(side.y, 0)) * 5
				var size := Vector2i(3, GRID) if side.x != 0 else Vector2i(GRID, 3)
				_block(edge.x, edge.y, size.x, size.y, STONE_SHADE)
				_block(edge.x, edge.y, size.x - int(side.x != 0), size.y - int(side.y != 0), PLASTER)
				continue
			if side == Vector2i.UP:
				var roof_clearance := _roof_overhang(cell)
				var upper := cell.position.y - roof_clearance
				_block(cell.position.x, upper, GRID, 3, roof[1])
				_block(cell.position.x, upper, GRID, 1, roof[2])
				_block(cell.position.x, upper + 3, GRID, 1, roof[0])
				_block(cell.position.x, upper + 4, GRID, cell.end.y - upper - 4, PLASTER)
				if finish != "default":
					_surface(Rect2i(cell.position.x, upper + 4, GRID, cell.end.y - upper - 4), "wall", finish)
				_block(cell.position.x, cell.end.y - 1, GRID, 1, STONE_SHADE)
				if roof_clearance > 0 and offset > 0 and offset + GRID < extent and offset % 24 == 8:
					_draw_short_window(cell.position.x + 1, cell.end.y - 7)
			elif side == Vector2i.DOWN:
				_draw_front_wall(cell.position.x, cell.position.y + 1, GRID)
				if finish != "default":
					_surface(Rect2i(cell.position.x, cell.position.y + 3, GRID, 2), "wall", finish)
			else:
				var edge_x := cell.position.x if side.x < 0 else cell.end.x - 6
				_block(edge_x, cell.position.y, 6, GRID, STONE_LIGHT if side.x < 0 else STONE)
				_block(edge_x, cell.position.y, 1, GRID, IVORY if side.x < 0 else STONE_SHADE)
				_block(edge_x + 5, cell.position.y, 1, GRID, STONE_SHADE if side.x < 0 else PLASTER)
				if finish != "default":
					_surface(Rect2i(edge_x + 1, cell.position.y, 4, GRID), "wall", finish)
				else:
					_block(edge_x + 2, cell.position.y + 3, 3, 1, STONE_SHADE)


func _draw_short_window(x: int, y: int) -> void:
	_block(x, y, 6, 5, STONE_SHADE)
	_block(x + 1, y + 1, 4, 3, _window_glass(Color("#79a9a5")))
	_block(x + 3, y + 1, 1, 3, IVORY)
	_block(x, y + 4, 6, 1, IVORY)


func _draw_threshold(cell: Rect2i, side: Vector2) -> void:
	var x := cell.position.x
	var y := cell.position.y
	_block(x, y, GRID, GRID, Color("#d6b995"))
	if side.x != 0.0:
		_block(x + 2, y, 3, GRID, STONE_LIGHT)
		_block(x + 2, y, 1, GRID, IVORY)
		_block(x, y, GRID, 1, STONE_SHADE)
		_block(x, y + GRID - 1, GRID, 1, STONE_SHADE)
	else:
		_block(x, y + 2, GRID, 3, STONE_LIGHT)
		_block(x, y + 2, GRID, 1, IVORY)
		_block(x, y, 1, GRID, STONE_SHADE)
		_block(x + GRID - 1, y, 1, GRID, STONE_SHADE)


func _window_glass(day: Color) -> Color:
	return day.lerp(Color("#fff1ac"), _night_light)

func _draw_front_wall(x: int, y: int, width: int) -> void:
	_block(x, y, width, 6, STONE)
	_block(x, y, width, 2, IVORY)
	_block(x, y + 2, width, 1, STONE_LIGHT)
	_block(x, y + 5, width, 1, STONE_SHADE)
	for offset in range(4, width - 1, 9):
		_block(x + offset, y + 3, 1, 2, STONE_SHADE)


func _draw_exterior(bounds: Rect2i, building: Dictionary, overhang: int) -> void:
	var cornice := bounds.end.y - FACADE_HEIGHT
	var kind: String = building.kind
	var finish := _finish(building, "roof")
	var roof: Array = ROOF_FINISHES.get(finish, EXTERIOR_ROOF[kind])
	_draw_facade_body(bounds, building)
	_draw_hip_roof(bounds, cornice, overhang, roof, finish)
	_draw_facade_fittings(bounds, building)


static func _unit_sections(members: Array) -> Array[Rect2i]:
	var sections: Array[Rect2i] = []
	var extent := _as_rect(members[0].rect)
	for member in members:
		extent = extent.merge(_as_rect(member.rect))
	var previous := {}
	for x in range(extent.position.x, extent.end.x, GRID):
		var vertical: Array[Vector2i] = []
		for member in members:
			var bounds := _as_rect(member.rect)
			if x >= bounds.position.x and x < bounds.end.x:
				vertical.append(Vector2i(bounds.position.y, bounds.end.y))
		vertical.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
		var spans: Array[Vector2i] = []
		for interval in vertical:
			if not spans.is_empty() and spans[-1].y == interval.x:
				spans[-1].y = interval.y
			else:
				spans.append(interval)
		var current := {}
		for span in spans:
			if previous.has(span):
				var index: int = previous[span]
				sections[index].size.x += GRID
				current[span] = index
			else:
				current[span] = sections.size()
				sections.append(Rect2i(x, span.x, GRID, span.y - span.x))
		previous = current
	return sections


func _draw_unit_exterior(members: Array) -> void:
	var principal: Dictionary = members[0]
	var sections := _unit_sections(members)
	var finish := _finish(principal, "roof")
	var roof: Array = ROOF_FINISHES.get(finish, EXTERIOR_ROOF[principal.kind])
	var top := _as_rect(principal.rect).position.y
	for section in sections:
		top = mini(top, section.position.y)
	# Draw the north-to-south spans of the union. The brickwork and roof courses
	# are continuous across shared side walls and leave the open corners exposed.
	for section in sections:
		var cornice := section.end.y - FACADE_HEIGHT
		if _capture:
			_capture_depth = section.end.y
		_draw_facade_body(section, principal)
		var upper := section.position.y
		for y in range(upper, cornice):
			var course := posmod(y - top, 5)
			var shade: Color = roof[1]
			var field: Color = roof[2]
			if y < top + 12:
				shade = roof[0]
				field = roof[1]
			var left := section.position.x
			var width := section.size.x
			_block(left, y, width, 1, shade if course == 4 and finish != "metal" else field)
			if finish == "metal":
				for x in range(left + posmod(-left, 8), section.end.x, 8):
					_block(x, y, 1, 1, shade)
					if x + 1 < section.end.x:
						_block(x + 1, y, 1, 1, roof[3])
			elif course < 4:
				var stagger := 3 * posmod(floori(float(y - top) / 5.0), 2)
				for x in range(left + posmod(stagger - left, 6), section.end.x, 6):
					_block(x, y, 1, 1, shade)
			if y == upper:
				_block(left, y, width, 1, roof[3])
		_block(section.position.x, cornice - 2, section.size.x, 1, roof[3])
		_block(section.position.x, cornice - 1, section.size.x, 2, SIGN_SHADOW)
		_block(section.position.x, cornice + 1, section.size.x, 1, IVORY)
	for member in members:
		var bounds := _as_rect(member.rect)
		if _capture:
			_capture_depth = bounds.end.y
		_draw_facade_fittings(bounds, member, members)


func _draw_facade_body(bounds: Rect2i, building: Dictionary) -> void:
	var left := bounds.position.x
	var right := bounds.end.x
	var bottom := bounds.end.y
	var width := bounds.size.x
	var cornice := bottom - FACADE_HEIGHT
	var kind: String = building.kind
	var wall := Color("#eee0b7") if kind == "reception" else PLASTER
	if kind == "buffet":
		wall = Color("#edca9b")
	_block(left, cornice, width, FACADE_HEIGHT - 1, STONE_SHADE)
	_block(left, cornice + 1, width, FACADE_HEIGHT - 6, wall)
	var finish := _finish(building, "facade")
	if finish != "default":
		_surface(Rect2i(left, cornice + 3, width, FACADE_HEIGHT - 8), "facade", finish)
	_block(left, bottom - 6, width, 1, STONE_LIGHT)
	_block(left, bottom - 3, width, 1, STONE_LIGHT)
	for x in range(left + posmod(-left, 10), right, 10):
		_block(x, bottom - 5, 1, 2, STONE)
		_block(x, cornice + 7 + posmod(x, 3), 1, 1, Color(0.56, 0.35, 0.28, 0.16))


func _draw_facade_fittings(bounds: Rect2i, building: Dictionary, members: Array = []) -> void:
	var left := bounds.position.x
	var right := bounds.end.x
	var bottom := bounds.end.y
	var door := _door(building, bounds)
	var side: Vector2 = building.get("door_side", Vector2.DOWN)
	var has_door: bool = building.get("exterior_door", true)
	var kind: String = building.kind
	var south_door := has_door and side == Vector2.DOWN
	_draw_side_facades(bounds, building, members)
	for x in range(left + 7, right - 15, 23):
		var room_below := false
		for neighbor in members:
			if neighbor.id != building.id and _as_rect(neighbor.rect).has_point(Vector2i(x + 6, bottom)):
				room_below = true
				break
		if not room_below and (not south_door or absf(float(x + 6) - door.x) >= 13.0):
			_draw_facade_window(x, bottom - 15, kind == "reception")
	if south_door:
		var entry := roundi(door.x) - 4
		_draw_facade_door(entry, bottom, kind)
		if kind == "buffet":
			_draw_canopy(entry - 6, bottom - 18, 20)


func _draw_side_facades(bounds: Rect2i, building: Dictionary, members: Array) -> void:
	var finish := _finish(building, "facade")
	var door := _door(building, bounds)
	var door_side: Vector2 = building.get("door_side", Vector2.DOWN)
	for side in [-1, 1]:
		var x := bounds.position.x if side < 0 else bounds.end.x - 5
		var outside := bounds.position.x - 1 if side < 0 else bounds.end.x
		var front := bounds.end.y - 1
		for row in range(bounds.position.y, bounds.end.y, GRID):
			var shared := false
			for neighbor in members:
				if neighbor.id != building.id and _as_rect(neighbor.rect).has_point(Vector2i(outside, row + 4)):
					shared = true
					break
			if shared:
				continue
			var y := maxi(row, bounds.position.y + 5)
			var height := mini(row + GRID, front) - y
			_block(x, y, 5, height, STONE)
			if finish != "default":
				_surface(Rect2i(x + 1, y, 3, height), "facade", finish, Color("#dbc3ae"))
			_block(x + (4 if side < 0 else 0), y, 1, height, SIGN_SHADOW)
			_block(x + (0 if side < 0 else 4), y, 1, height, STONE_LIGHT)
			if building.get("exterior_door", true) and door_side.x == side and int(door.y) == row + 4:
				_block(x, y, 5, height, IVORY)
				_block(x + 1, y + 1, 3, height - 2, SIGN_SHADOW)
				_block(x + 2, y + 2, 1, height - 4, _window_glass(Color("#659c91")))

func _draw_hip_roof(bounds: Rect2i, cornice: int, overhang: int, colors: Array, finish: String) -> void:
	var left := bounds.position.x
	var right := bounds.end.x
	var upper := bounds.position.y - overhang
	var ridge := upper + maxi(5, floori((cornice - upper) * 0.35))
	# The far edge tapers inward. Staggered courses cover the far and near roof slopes.
	for y in range(upper, cornice):
		var rise := y - upper
		var inset := maxi(0, 5 - rise)
		var left_edge := left + inset
		var right_edge := right - inset
		var far_slope := y < ridge
		var course := posmod(y - ridge, 5)
		var field: Color = colors[1] if far_slope else colors[2]
		var shade: Color = colors[0] if far_slope else colors[1]
		_block(left_edge, y, right_edge - left_edge, 1, shade if course == 4 and finish != "metal" else field)
		var hip := clampi(floori(absf(y - ridge) * 0.28), 1, 9)
		if finish == "metal":
			for x in range(left + 8, right_edge - hip - 1, 8):
				_block(x, y, 1, 1, shade)
				_block(x + 1, y, 1, 1, colors[3])
		elif course != 4:
			var offset := 3 if floori((y - ridge) / 5.0) % 2 == 0 else 0
			for x in range(left + 9 + offset, right_edge - hip - 1, 6):
				if x <= left_edge + hip:
					continue
				_block(x, y, 1, 1, shade)
				if course == 0:
					_block(x + 1, y, 2, 1, colors[3] if not far_slope else colors[2])
		_block(left_edge, y, 1, 1, colors[3] if course != 4 else shade)
		_block(right_edge - hip, y, hip, 1, colors[1] if course != 4 else colors[0])
		_block(right_edge - 1, y, 1, 1, colors[0])
	_block(left + 2, ridge, bounds.size.x - 4, 2, colors[0])
	_block(left + 3, ridge, bounds.size.x - 7, 1, colors[3])
	for x in range(left + 8, right - 4, 7):
		_block(x, ridge, 1, 1, colors[2])
	_block(left + 1, cornice - 2, bounds.size.x - 2, 1, colors[3])
	_block(left, cornice - 1, bounds.size.x, 1, colors[0])


func _draw_facade_window(x: int, y: int, brass: bool) -> void:
	var frame := Color("#dfad77") if brass else IVORY
	_block(x - 1, y, 14, 9, STONE_SHADE)
	_block(x, y - 1, 12, 9, frame)
	_block(x + 1, y, 10, 7, Color("#547d79").lerp(Color("#c99059"), _night_light))
	_block(x + 2, y + 1, 3, 5, _window_glass(Color("#75a39b")))
	_block(x + 7, y + 1, 3, 5, _window_glass(Color("#75a39b")))
	_block(x + 2, y + 2, 1, 2, _window_glass(Color("#b7ccac")))
	_block(x + 7, y + 2, 1, 2, _window_glass(Color("#b7ccac")))
	_block(x + 5, y, 1, 7, frame)
	_block(x - 1, y + 7, 14, 1, IVORY)
	if _night_light > 0.0:
		_block(x, y + 8, 12, 2, Color(1.0, 0.82, 0.47, _night_light * 0.35))


func _draw_facade_door(entry: int, bottom: int, kind: String) -> void:
	var frame := Color("#f5d69f")
	var leaf := Color("#477a71") if kind == "reception" else Color("#9a6553")
	var x := entry - 2
	var y := bottom - 16
	_block(x, y + 2, 12, 13, STONE_SHADE)
	_block(x + 1, y, 10, 14, frame)
	_block(x + 2, y - 1, 8, 1, frame)
	_block(x + 2, y + 2, 8, 12, SIGN_SHADOW)
	_block(x + 3, y + 3, 6, 11, leaf)
	_block(x + 4, y + 4, 4, 3, _window_glass(Color("#7ba49c")))
	if kind != "bedroom":
		_block(x + 6, y + 3, 1, 11, SIGN_SHADOW)
	_block(x + 5, y + 9, 1, 1, frame)
	_block(entry - 1, bottom - 3, GRID + 2, 2, STONE_LIGHT)
	_block(entry - 1, bottom - 3, GRID + 2, 1, IVORY)


func _draw_canopy(x: int, y: int, width: int) -> void:
	_block(x, y + 1, width, 4, SIGN_SHADOW)
	_block(x + 1, y, width - 2, 3, Color("#b07558"))
	for offset in range(1, width - 3, 4):
		_block(x + offset, y, 2, 3, Color("#f8dfab"))
	_block(x, y + 3, width, 1, Color("#805447"))


func _draw_ceiling(bounds: Rect2i, finish: String) -> void:
	var plane := Rect2i(bounds.position + Vector2i(8, 9), bounds.size - Vector2i(16, 17))
	var edge := plane.grow(1)
	_block(edge.position.x, edge.position.y, edge.size.x, edge.size.y, SIGN_SHADOW)
	_surface(plane, "ceiling", finish)
	_block(plane.position.x, plane.position.y, plane.size.x, 1, STONE_LIGHT)
	_block(plane.position.x, plane.end.y - 1, plane.size.x, 1, IVORY)
	var count := maxi(1, floori(plane.size.x / 32.0))
	for i in range(count):
		var x := plane.position.x + roundi(plane.size.x * (i + 1.0) / (count + 1.0))
		var y := plane.get_center().y + 1
		_block(x - 3, y - 2, 7, 5, STONE_SHADE)
		_block(x - 2, y - 3, 5, 5, STONE_LIGHT)
		_block(x - 2, y - 2, 5, 3, IVORY)
		_block(x - 1, y - 1, 3, 1, Color("#fff6db"))


func _draw_building_plaque(building: Dictionary) -> void:
	var bounds := _as_rect(building.rect)
	var kind: String = building.kind
	var name: String = building.get("display_name", DEFAULT_NAMES[kind])
	var center_x := bounds.get_center().x
	var y := bounds.position.y - _roof_overhang(bounds) + 2
	if kind == "pool":
		y = bounds.position.y + 3
	elif _exterior:
		y = bounds.end.y - FACADE_HEIGHT + 4
	var font := ThemeDB.fallback_font
	var label := _fit_plaque(font, name, bounds.size.x - 18)
	var text_width := _plaque_text_width(font, label)
	var width := text_width + 10
	var left := center_x - floori(width / 2.0)
	if not _exterior and kind != "pool":
		var doors: Array = building.get("shared_doors", []).duplicate()
		if building.get("exterior_door", true):
			doors.append(_door(building, bounds))
		for door: Vector2 in doors:
			var opening := Rect2i(Vector2i(door) - Vector2i(4, 4), Vector2i(GRID, GRID))
			if opening.intersects(Rect2i(left, y, width + 1, 11)):
				y = opening.end.y
	_block(left + 1, y + 1, width, 10, SIGN_SHADOW)
	_block(left, y, width, 10, SIGN_BORDER)
	_block(left + 1, y + 1, width - 2, 8, SIGN_FACE)
	_block(left + 2, y + 4, 1, 1, IVORY)
	_block(left + width - 3, y + 4, 1, 1, IVORY)
	_draw_plaque_text(font, Vector2(left + 5, y + 8), label)


static func _plaque_text_width(font: Font, label: String) -> int:
	return ceili(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE).x)


static func _fit_plaque(font: Font, label: String, available: int) -> String:
	if _plaque_text_width(font, label) <= available:
		return label
	var shortened := label
	while not shortened.is_empty():
		shortened = shortened.left(-1).strip_edges()
		var ellipsized := shortened + "…"
		if _plaque_text_width(font, ellipsized) <= available:
			return ellipsized
	return "…"


func _draw_plaque_text(font: Font, position_on_map: Vector2, label: String) -> void:
	var target: CanvasItem = _draw_target if _draw_target else self
	target.draw_string(font, position_on_map, label, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE, IVORY)


func _surface(bounds: Rect2i, surface: String, finish: String, tint: Color = Color.WHITE) -> void:
	var texture := finish_preview(surface, finish)
	if texture:
		if _capture:
			if _capture_rows:
				for y in range(bounds.position.y, bounds.end.y):
					_commands.append({"rect": Rect2i(bounds.position.x, y, bounds.size.x, 1), "color": tint,
						"texture": texture, "depth": float(y), "tag": _capture_tag, "tile_origin": bounds.position})
			else:
				_commands.append({"rect": bounds, "color": tint, "texture": texture, "depth": _capture_depth, "tag": _capture_tag})
		else:
			var target: CanvasItem = _draw_target if _draw_target else self
			target.draw_texture_rect(texture, Rect2(bounds), true, tint)


func _draw_pool(bounds: Rect2i, building: Dictionary) -> void:
	var water := _as_rect(building.get("water", _water_rect(bounds)))
	var upgraded: bool = building.get("upgraded", false)
	var left := water.position.x
	var top := water.position.y
	var right := water.end.x
	var bottom := water.end.y
	var width := water.size.x
	var height := water.size.y
	var lining := Color("#53b5b1") if upgraded else Color("#64aead")
	var deep := Color("#4c969d") if upgraded else Color("#4b8a8e")
	var ripple := Color("#88c8b7")

	# Coping steps out onto the deck, and all water remains within the water cell bounds.
	_block(left - 2, top - 2, width + 4, height + 5, Color("#aca183"))
	_block(left - 2, top - 2, width + 4, height + 4, IVORY)
	_block(left - 1, top - 1, width + 2, height + 2, Color("#c7c899"))
	_block(left, top, width, height, lining)
	_block(left, top, width, 4, deep)
	_block(left, top + 2, 2, height - 2, deep)
	_block(left + 2, bottom - 2, width - 2, 1, ripple)
	_block(right - 1, top + 4, 1, height - 6, ripple)
	for x in range(left + 4, right - 2, 5):
		_block(x, top + 2, 1, 1, lining)
		_block(x, top - 2, 1, 1, Color("#d8b896"))
		_block(x, bottom, 1, 1, Color("#b6b383"))
	for y in range(top + 7, bottom - 4, 5):
		for x in range(left + 6 + (y - top) % 8, right - 8, 17):
			_block(x, y, 3 + posmod(x + y, 4), 1, ripple)
			if (x + y) % 3 == 0:
				_block(x + 3, y + 2, 3, 1, ripple)

	if upgraded:
		var center := water.get_center()
		for offset in range(-5, 6):
			var half_width := floori((5 - absi(offset)) * 1.4)
			_block(center.x - half_width, center.y + offset, half_width * 2 + 1, 1, deep)
		_block(center.x - 2, center.y, 5, 1, Color("#aae0c3"))
		_block(center.x, center.y - 2, 1, 5, Color("#aae0c3"))
	var turn := int(building.get("rotation", 0))
	var original_size := Vector2(bounds.size) if turn % 2 == 0 else Vector2(bounds.size.y, bounds.size.x)
	var side: Vector2 = building.get("door_side", Vector2.DOWN)
	var ladder := _turn_point(Vector2(bounds.position), original_size, turn, Vector2(34, 16))
	_draw_ladder(ladder, side)
	var door := _door(building, bounds)
	_draw_threshold(Rect2i(Vector2i(door) - Vector2i(4, 4), Vector2i(GRID, GRID)), side)


func _draw_ladder(at: Vector2, toward_water: Vector2) -> void:
	var tangent := Vector2(toward_water.y, -toward_water.x)
	for depth in range(2, 7, 2):
		for offset in range(-3, 4):
			var rung := Vector2i(at + toward_water * depth + tangent * offset)
			_block(rung.x, rung.y, 1, 1, Color("#cae3c6"))
	for offset in [-3, 3]:
		for depth in range(-2, 8):
			var rail := Vector2i(at + toward_water * depth + tangent * offset)
			_block(rail.x, rail.y, 1, 1, Color("#5d8d8a"))
		var post := Vector2i(at - toward_water * 2 + tangent * offset)
		_block(post.x, post.y - 3, 1, 4, IVORY)


func _draw_pool_animation() -> void:
	var time := float(_animation_frame) * 0.1
	for water in _pools:
		var count := maxi(3, floori(float(water.size.x) / 12.0))
		for i in range(count):
			var phase := time * 2.0 + i * 2.1
			var x := water.position.x + 10 + i * (water.size.x - 22) / float(count) + roundf(cos(phase) * 3.0)
			var y := water.position.y + 5 + (i * 7) % (water.size.y - 10)
			var glint := Color(0.9, 1.0, 0.93, 0.14 + (sin(phase) + 1.0) * 0.2)
			_pool_animation.draw_rect(Rect2(roundf(x), y, 3 + i % 4, 1), glint)


func _draw_asset(asset: Dictionary) -> void:
	var bounds := Rect2(_as_rect(asset.rect))
	if _interleave:
		var data := FurnitureDepth.data(asset.kind, int(asset.get("rotation", 0)))
		draw_texture(data.base, bounds.position - FURNITURE_LIFT)
	else:
		draw_furniture(self, asset.kind, int(asset.get("rotation", 0)), bounds)


static func draw_furniture(canvas: CanvasItem, kind: String, rotation: int, bounds: Rect2, tint := Color.WHITE) -> void:
	var source := furniture_source(kind, rotation, bounds.size)
	canvas.draw_texture_rect_region(FURNITURE, Rect2(bounds.position - FURNITURE_LIFT, source.size), source, tint)


static func furniture_source(kind: String, rotation: int, size: Vector2) -> Rect2:
	return Rect2(Vector2(posmod(rotation, 4), FURNITURE_ROWS[kind]) * ATLAS_CELL, size + FURNITURE_LIFT)


func _block(x: int, y: int, width: int, height: int, color: Color) -> void:
	if width <= 0 or height <= 0:
		return
	if _capture:
		if _capture_rows:
			for row in range(y, y + height):
				_commands.append({"rect": Rect2i(x, row, width, 1), "color": color, "depth": float(row), "tag": _capture_tag})
		else:
			_commands.append({"rect": Rect2i(x, y, width, height), "color": color, "depth": _capture_depth, "tag": _capture_tag})
	else:
		var target: CanvasItem = _draw_target if _draw_target else self
		target.draw_rect(Rect2(x, y, width, height), color)
