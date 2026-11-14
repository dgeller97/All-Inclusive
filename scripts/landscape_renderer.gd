extends Node2D
## Draws construction landscape layers over the original shoreline texture.

const Landscape = preload("res://scripts/landscape_model.gd")
const DEFAULTS := preload("res://assets/art/landscape_defaults.png")
const MATERIALS := preload("res://assets/art/landscape_materials.png")
const PROPS := preload("res://assets/art/landscape_props.png")
const FURNITURE := preload("res://assets/art/furniture.png")
const GRID := Landscape.GRID
const MATERIAL_SPAN := 32
const PROP_SPAN := 96
const PROP_ANCHOR := Vector2(44, 67)
const MATERIAL_COLUMNS := {"grass": 0, "sand": 1, "dirt": 2, "water": 3, "stone": 4, "boardwalk": 5}
const PATH_EDGES := {
	"stone": [Color("#ffe7b7"), Color("#c69a73")],
	"boardwalk": [Color("#eac29a"), Color("#98694e")],
}
const PROP_BOUNDS := {
	"palm": Rect2(-44, -67, 88, 73),
	"bush": Rect2(-23, -10, 46, 20),
	"rock": Rect2(-8, -8, 19, 14),
}

static var _default_paths: Array[Vector2i] = []
var _landscape: Landscape
var _revision := -1
var _ground := {}
var _paths := {}
var _props: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


static func _initialize_default_paths() -> void:
	if _default_paths.is_empty():
		var source := DEFAULTS.get_image()
		for y in source.get_height():
			for x in source.get_width():
				if source.get_pixel(x, y).g8 > 0:
					_default_paths.append(Vector2i(x, y) + Landscape.REGION.position)


func present(landscape: Landscape, _visual_time := 0.0) -> void:
	if _landscape == landscape and _revision == landscape.revision:
		return
	_initialize_default_paths()
	_landscape = landscape
	_revision = landscape.revision
	_ground.clear()
	for cell: Vector2i in landscape.terrain_overrides:
		if landscape.ground_signature(cell).begins_with("paint:"):
			_ground[cell] = landscape.terrain_overrides[cell]
	_paths.clear()
	for cell in _default_paths:
		_cache_path(cell)
	for cell in landscape.path_overrides:
		_cache_path(cell)
	_props.assign(landscape.props.duplicate(true))
	_props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return prop_anchor(a).y < prop_anchor(b).y)
	queue_redraw()


func _cache_path(cell: Vector2i) -> void:
	var kind := _landscape.path_at(cell)
	if not kind.is_empty() and _landscape.cell_is_dry(cell):
		_paths[cell] = kind


func _draw() -> void:
	for cell: Vector2i in _ground:
		_draw_surface(cell, _ground[cell])
	for cell: Vector2i in _ground:
		if _ground[cell] == "water":
			_draw_pond_edges(cell)
	for cell: Vector2i in _paths:
		_draw_surface(cell, _paths[cell])
		_draw_path_edges(cell, _paths[cell])
	for prop in _props:
		if prop.kind != "beach_flag":
			draw_prop(self, prop)


func _draw_surface(cell: Vector2i, kind: String) -> void:
	var world := Vector2(cell * GRID)
	var source := Vector2(posmod(cell.x, 4) * GRID, posmod(cell.y, 4) * GRID)
	source.x += MATERIAL_COLUMNS[kind] * MATERIAL_SPAN
	var size := Vector2(GRID, GRID)
	draw_texture_rect_region(MATERIALS, Rect2(world, size), Rect2(source, size))


func _draw_pond_edges(cell: Vector2i) -> void:
	var world := cell * GRID
	var damp := Color("#8dc3b2")
	for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: Vector2i = cell + side
		if _ground.get(neighbor, "") == "water":
			continue
		var horizontal: bool = side.y != 0
		var tangent := Vector2i.RIGHT if horizontal else Vector2i.DOWN
		var edge := world + Vector2i(maxi(side.x, 0), maxi(side.y, 0)) * (GRID - 1)
		for i in GRID:
			var pixel := edge + tangent * i
			if not _landscape.is_water_pixel(Vector2(pixel + side)):
				draw_rect(Rect2(Vector2(pixel), Vector2.ONE), damp)


func _draw_path_edges(cell: Vector2i, kind: String) -> void:
	var world := Vector2(cell * GRID)
	var colors: Array = PATH_EDGES[kind]
	if not _paths.has(cell + Vector2i.UP):
		draw_rect(Rect2(world, Vector2(GRID, 1)), colors[0])
	if not _paths.has(cell + Vector2i.LEFT):
		draw_rect(Rect2(world, Vector2(1, GRID)), colors[0])
	if not _paths.has(cell + Vector2i.DOWN):
		draw_rect(Rect2(world + Vector2(0, GRID - 1), Vector2(GRID, 1)), colors[1])
	if not _paths.has(cell + Vector2i.RIGHT):
		draw_rect(Rect2(world + Vector2(GRID - 1, 0), Vector2(1, GRID)), colors[1])


static func prop_anchor(prop: Dictionary) -> Vector2:
	var cell: Array = prop.cell
	var offset: Array = prop.get("offset", [4, 4])
	return Vector2(cell[0], cell[1]) * GRID + Vector2(offset[0], offset[1])


static func draw_prop(canvas: CanvasItem, prop: Dictionary, tint := Color.WHITE) -> void:
	var kind: String = prop.kind
	var rotation := posmod(int(prop.get("rotation", 0)), 4)
	if kind == "bench":
		var cell: Array = prop.cell
		var size := Vector2(24, 8) if rotation % 2 == 0 else Vector2(8, 24)
		var source := Rect2(Vector2(rotation * 32, 7 * 32), size)
		canvas.draw_texture_rect_region(FURNITURE, Rect2(Vector2(cell[0], cell[1]) * GRID, size), source, tint)
		return
	var anchor := prop_anchor(prop)
	if kind == "beach_flag":
		draw_beach_flag(canvas, anchor, rotation, Color("#78c897"), 0, 0, tint)
		return
	if not PROP_BOUNDS.has(kind):
		return
	var row := int(prop.get("variant", 0))
	var palm_rows := PROPS.get_height() / PROP_SPAN - 2
	if kind == "bush":
		row = palm_rows
	elif kind == "rock":
		row = palm_rows + 1
	elif row < 0 or row >= palm_rows:
		row = 0
	var bounds: Rect2 = PROP_BOUNDS[kind]
	var source := Rect2(Vector2(rotation, row) * PROP_SPAN + PROP_ANCHOR + bounds.position, bounds.size)
	var target := Rect2(anchor + bounds.position, bounds.size)
	canvas.draw_texture_rect_region(PROPS, target, source, tint)


static func draw_beach_flag(canvas: CanvasItem, anchor: Vector2, rotation: int, color: Color, fold: float, tip: float, tint := Color.WHITE) -> void:
	var side := 1.0 if rotation < 2 else -1.0
	var panel := anchor + Vector2(-23, -23)
	canvas.draw_rect(Rect2(anchor + Vector2(-3, -2), Vector2(19, 3)), Color("#d6ad83") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-1, -43), Vector2(3, 43)), Color("#966952") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-1, -43), Vector2(1, 43)), Color("#f8d5a1") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-2, -45), Vector2(5, 3)), Color("#fbe8b7") * tint)
	var reach := 23.0 if rotation % 2 == 0 else 18.0
	var flag := PackedVector2Array([
		anchor + Vector2(2 * side, -40),
		anchor + Vector2(reach * 0.52 * side, -40 + fold),
		anchor + Vector2(reach * side, -38 + tip),
		anchor + Vector2((reach - 6) * side, -32 + tip),
		anchor + Vector2(reach * side, -26 + tip),
		anchor + Vector2(reach * 0.52 * side, -28 + fold),
		anchor + Vector2(2 * side, -28),
	])
	canvas.draw_colored_polygon(flag, color * tint)
	canvas.draw_polyline(flag, Color("#715651") * tint, 1.0)
	canvas.draw_rect(Rect2(panel + Vector2(1, 1), Vector2(49, 21)), Color("#b58b68") * tint)
	canvas.draw_rect(Rect2(panel, Vector2(49, 21)), Color("#443b40") * tint)
	canvas.draw_rect(Rect2(panel, Vector2(49, 1)), Color("#fff0c5") * tint)
	canvas.draw_string(ThemeDB.fallback_font, panel + Vector2(1, 18), "OCEAN", HORIZONTAL_ALIGNMENT_CENTER, 47, 7, Color("#fff0d0") * tint)
