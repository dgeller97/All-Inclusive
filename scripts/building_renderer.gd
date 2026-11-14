extends Node2D

## Interior and exterior architecture painted from the current world layout.
const GRID := 8
const ATLAS_CELL := 32
const FURNITURE := preload("res://assets/art/furniture.png")
const Finishes := preload("res://assets/art/building_finishes.gd")
const WORLD_TOP := -120
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


func _init() -> void:
	_pool_animation.name = "PoolSurface"
	_pool_animation.draw.connect(_draw_pool_animation)
	add_child(_pool_animation)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


# `rect` is the world pixel footprint. Assets carry the resolved, rotated rect.
func present(buildings: Array, assets: Array, visual_time: float = 0.0) -> void:
	if _buildings != buildings or _assets != assets:
		_buildings = buildings.duplicate(true)
		_assets = assets.duplicate(true)
		_pools.clear()
		for building in _buildings:
			if building.kind == "pool":
				_pools.append(_water_rect(_as_rect(building.rect)))
		_rebuild_hidden_buildings()
		queue_redraw()
		_pool_animation.queue_redraw()
	advance_time(visual_time)


func set_view(exterior: bool, ceiling_building_id: int = -1) -> void:
	var ceiling := -1 if exterior else ceiling_building_id
	if _exterior == exterior and _ceiling_building_id == ceiling:
		return
	_exterior = exterior
	_ceiling_building_id = ceiling
	_rebuild_hidden_buildings()
	queue_redraw()


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
			_draw_platform(bounds, FLOOR[kind])
			_draw_pool(bounds, building.get("upgraded", false))
		elif _exterior:
			_draw_exterior(bounds, building, _roof_overhang(bounds))
		else:
			_draw_platform(bounds, FLOOR[kind], _finish(building, "floor"))
			if _hidden_buildings.has(building.get("id", -1)):
				_draw_ceiling(bounds, _finish(building, "ceiling"))
			_draw_walls(bounds, ROOF[kind], kind, _roof_overhang(bounds), _finish(building, "wall"))
	for asset in _assets:
		if not _hidden_buildings.has(asset.get("building_id", -1)):
			_draw_asset(asset)
	for building in _buildings:
		_draw_building_plaque(building)


static func _finish(building: Dictionary, surface: String) -> String:
	return building.get("finishes", {}).get(surface, "default")


static func _as_rect(value: Variant) -> Rect2i:
	if value is Rect2i:
		return value
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


static func _entrance_x(bounds: Rect2i) -> int:
	return bounds.position.x + floori(float(bounds.size.x) / (2 * GRID)) * GRID


static func _water_rect(bounds: Rect2i) -> Rect2i:
	return Rect2i(bounds.position + Vector2i(24, 16), bounds.size - Vector2i(48, 40))


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


func _draw_walls(bounds: Rect2i, roof: Array, kind: String, overhang: int, finish: String = "default") -> void:
	var left := bounds.position.x
	var top := bounds.position.y
	var right := bounds.end.x
	var bottom := bounds.end.y
	var width := bounds.size.x
	var height := bounds.size.y
	var entry := _entrance_x(bounds)
	var crest := top - overhang
	var wall_top := crest + 4

	# The wall face fills the rear grid row. The roof rises eight pixels over it.
	_block(left, wall_top, width, top + 7 - wall_top, PLASTER)
	if finish != "default":
		_surface(Rect2i(left, wall_top, width, top + 7 - wall_top), "wall", finish)
	_block(left + 1, top + 6, width - 2, 2, STONE)
	_block(left + 1, top + 7, width - 2, 1, STONE_SHADE)
	_block(left + 1, top + 8, width - 2, 1, AMBIENT_SHADOW)
	_block(left, crest + 1, width, 3, roof[1])
	_block(left + 1, crest, width - 2, 1, roof[2])
	_block(left, wall_top, width, 1, roof[0])
	for x in range(left + 2, right - 2, 4):
		_block(x, crest + 2, 1, 2, roof[0])
		_block(x + 1, crest + 1, 1, 1, roof[2])
	if overhang > 0:
		var window_count := maxi(1, floori(float(width - 12) / 26.0))
		for i in range(window_count):
			var center := left + roundi(float(width) * (i + 1) / (window_count + 1))
			_draw_window(center - 6, top - 2, kind == "reception")

	# Side and front cutaway walls align with the blocked cells in the layout.
	_block(left, top, 6, height - 1, STONE_LIGHT)
	_block(left, top, 2, height - 1, IVORY)
	_block(left + 5, top + 5, 1, height - 6, STONE_SHADE)
	_block(left + 6, top + 8, 2, height - 16, AMBIENT_SHADOW)
	_block(right - 6, top, 5, height - 1, STONE)
	_block(right - 6, top + 3, 1, height - 4, STONE_SHADE)
	_block(right - 2, top, 1, height - 1, PLASTER)
	if finish == "default":
		for y in range(top + 10, bottom - 7, 10):
			_block(left + 1, y, 4, 1, STONE)
			_block(right - 5, y, 3, 1, STONE_SHADE)
	else:
		_surface(Rect2i(left + 2, top + 8, 3, height - 15), "wall", finish)
		_surface(Rect2i(right - 5, top + 8, 3, height - 15), "wall", finish, Color(0.87, 0.84, 0.82))
	_draw_front_wall(left, bottom - 7, entry - left)
	_draw_front_wall(entry + GRID, bottom - 7, right - entry - GRID)
	_block(entry, bottom - 3, GRID, 3, STONE_LIGHT)
	_block(entry, bottom - 3, GRID, 1, IVORY)
	_block(entry - 2, bottom - 8, 2, 3, IVORY)
	_block(entry + GRID, bottom - 8, 2, 3, IVORY)
	for x in [left, right - 5]:
		_block(x, bottom - 8, 5, 2, IVORY)
		_block(x + 1, bottom - 6, 2, 5, PLASTER)


func _draw_window(x: int, y: int, brass: bool) -> void:
	_block(x - 1, y, 14, 7, STONE_LIGHT)
	_block(x, y, 12, 6, Color("#79a9a5"))
	_block(x, y, 12, 1, Color("#587d79"))
	for i in range(4):
		_block(x + 1 + i, y + 4 - i, 1, 1, Color("#b3cfb9"))
	var frame := Color("#e8af73") if brass else IVORY
	_block(x + 6, y + 1, 1, 5, frame)
	_block(x - 1, y + 6, 14, 1, frame)


func _draw_front_wall(x: int, y: int, width: int) -> void:
	_block(x, y, width, 6, STONE)
	_block(x, y, width, 2, IVORY)
	_block(x, y + 2, width, 1, STONE_LIGHT)
	_block(x, y + 5, width, 1, STONE_SHADE)
	for offset in range(4, width - 1, 9):
		_block(x + offset, y + 3, 1, 2, STONE_SHADE)


func _draw_exterior(bounds: Rect2i, building: Dictionary, overhang: int) -> void:
	var left := bounds.position.x
	var right := bounds.end.x
	var bottom := bounds.end.y
	var width := bounds.size.x
	var entry := _entrance_x(bounds)
	var cornice := bottom - FACADE_HEIGHT
	var kind: String = building.kind
	var wall := Color("#eee0b7") if kind == "reception" else PLASTER
	if kind == "buffet":
		wall = Color("#edca9b")
	_block(left, cornice, width, FACADE_HEIGHT, AMBIENT_SHADOW)
	_block(left, cornice, width - 1, FACADE_HEIGHT - 1, STONE_SHADE)
	_block(left + 1, cornice + 1, width - 3, FACADE_HEIGHT - 6, wall)
	var finish := _finish(building, "wall")
	if finish != "default":
		_surface(Rect2i(left + 4, cornice + 3, width - 8, FACADE_HEIGHT - 8), "wall", finish)
	_block(left + 2, cornice + 1, 2, FACADE_HEIGHT - 6, IVORY)
	_block(right - 5, cornice + 1, 3, FACADE_HEIGHT - 6, STONE_LIGHT)
	_block(left + 1, bottom - 6, width - 3, 1, STONE_LIGHT)
	_block(left + 1, bottom - 3, width - 3, 1, STONE_LIGHT)
	for x in range(left + 7, right - 7, 10):
		_block(x, bottom - 4, 1, 2, STONE)
		_block(x, cornice + 7 + posmod(x, 3), 2, 1, Color(0.56, 0.35, 0.28, 0.16))

	_draw_hip_roof(bounds, cornice, overhang, EXTERIOR_ROOF[kind])
	_block(left + 1, cornice, width - 2, 3, SIGN_SHADOW)
	_block(left + 2, cornice + 1, width - 4, 1, IVORY)
	for x in range(left + 5, right - 4, 8):
		_block(x, cornice + 2, 2, 2, STONE)

	var window_y := bottom - 15
	var reception := kind == "reception"
	var left_window := left + maxi(6, floori((entry - left - 12) / 2.0))
	var right_window := entry + GRID + maxi(2, floori((right - entry - GRID - 12) / 2.0))
	if width >= 88:
		_draw_facade_window(left + 8, window_y, reception)
		_draw_facade_window(entry - 18, window_y, reception)
		_draw_facade_window(entry + 13, window_y, reception)
		_draw_facade_window(right - 21, window_y, reception)
	else:
		_draw_facade_window(left_window, window_y, reception)
		_draw_facade_window(right_window, window_y, reception)
	_draw_facade_door(entry, bottom, kind)
	if kind == "buffet":
		_draw_canopy(entry - 6, bottom - 18, 20)


func _draw_hip_roof(bounds: Rect2i, cornice: int, overhang: int, colors: Array) -> void:
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
		_block(left_edge, y, right_edge - left_edge, 1, shade if course == 4 else field)
		var hip := clampi(floori(absf(y - ridge) * 0.28), 1, 9)
		if course != 4:
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
	_block(x + 1, y, 10, 7, Color("#547d79"))
	_block(x + 2, y + 1, 3, 5, Color("#75a39b"))
	_block(x + 7, y + 1, 3, 5, Color("#75a39b"))
	_block(x + 2, y + 2, 1, 2, Color("#b7ccac"))
	_block(x + 7, y + 2, 1, 2, Color("#b7ccac"))
	_block(x + 5, y, 1, 7, frame)
	_block(x - 1, y + 7, 14, 1, IVORY)


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
	_block(x + 4, y + 4, 4, 3, Color("#7ba49c"))
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
	draw_string(font, position_on_map, label, HORIZONTAL_ALIGNMENT_LEFT, -1, SIGN_FONT_SIZE, IVORY)


func _surface(bounds: Rect2i, surface: String, finish: String, tint: Color = Color.WHITE) -> void:
	var texture := finish_preview(surface, finish)
	if texture:
		draw_texture_rect(texture, Rect2(bounds), true, tint)


func _draw_pool(bounds: Rect2i, upgraded: bool) -> void:
	var water := _water_rect(bounds)
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
	_draw_ladder(left + 7, top - 3)
	var entry := _entrance_x(bounds)
	_block(entry, bounds.end.y - 3, GRID, 3, STONE_LIGHT)
	_block(entry, bounds.end.y - 3, GRID, 1, IVORY)


func _draw_ladder(x: int, y: int) -> void:
	for side in [x, x + 6]:
		_block(side, y, 2, 11, Color("#5d8d8a"))
		_block(side, y, 1, 10, IVORY)
	for rung in range(3):
		_block(x + 1, y + 3 + 3 * rung, 5, 1, Color("#cae3c6"))


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
	var bounds := _as_rect(asset.rect)
	draw_texture_rect_region(FURNITURE, Rect2(bounds), _asset_source(asset, bounds.size))


static func _asset_source(asset: Dictionary, size: Vector2i) -> Rect2:
	var rotation := int(asset.get("rotation", 0))
	var row: int = FURNITURE_ROWS[asset.kind]
	return Rect2(Vector2(rotation * ATLAS_CELL, row * ATLAS_CELL), size)


func _block(x: int, y: int, width: int, height: int, color: Color) -> void:
	draw_rect(Rect2(x, y, width, height), color)
