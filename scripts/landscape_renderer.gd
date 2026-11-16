extends Node2D
## Draws construction landscape layers over the original shoreline texture.

const Landscape = preload("res://scripts/landscape_model.gd")
const AmenityArt := preload("res://scripts/amenity_renderer.gd")
const FurnitureArt := preload("res://scripts/building_renderer.gd")
const FurnitureDepth := preload("res://scripts/furniture_depth.gd")
const DEFAULTS := preload("res://assets/art/landscape_defaults.png")
const MATERIALS := preload("res://assets/art/landscape_materials.png")
const PROPS := preload("res://assets/art/landscape_props.png")
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
static var _prop_textures := {}
var _landscape: Landscape
var _revision := -1
var _ground := {}
var _paths := {}
var _props: Array[Dictionary] = []
var _depth_items: Array[Dictionary] = []
var _interleave := false
var _scenery := Node2D.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_scenery.name = "Scenery"
	_scenery.draw.connect(_draw_scenery)
	add_child(_scenery)


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
		return _prop_depth(a) < _prop_depth(b))
	_cache_depth_items()
	queue_redraw()
	_scenery.queue_redraw()


func set_interleave(enabled: bool) -> void:
	if enabled == _interleave:
		return
	_interleave = enabled
	_cache_depth_items()
	_scenery.queue_redraw()


func depth_items() -> Array[Dictionary]:
	return _depth_items


func _cache_depth_items() -> void:
	_depth_items.clear()
	if not _interleave:
		return
	for prop in _props:
		var kind: String = prop.kind
		if AmenityArt.handles(kind):
			var site := Vector2(prop.cell[0], prop.cell[1]) * GRID
			var origin := site + AmenityArt.art_offset(kind)
			for layer in AmenityArt.layers(kind, prop.rotation):
				var position: Vector2 = origin + layer.offset
				_depth_items.append({
					"kind": "asset", "tag": layer.tag, "depth": site.y + float(layer.depth),
					"position": position, "bounds": Rect2(position, layer.size),
					"texture": layer.texture, "image": layer.image, "asset_id": prop.id,
				})
		else:
			var site := _landscape.prop_rect(prop)
			var anchor := prop_anchor(prop)
			if kind == "bench":
				for layer in FurnitureDepth.data(kind, int(prop.rotation)).layers:
					var position: Vector2 = site.position + layer.offset
					_depth_items.append({
						"kind": "asset", "tag": kind, "depth": site.position.y + float(layer.depth),
						"bounds": Rect2(position, layer.texture.get_size()), "position": position,
						"texture": layer.texture, "image": layer.image, "asset_id": prop.id,
					})
			elif kind == "beach_flag":
				_depth_items.append({
					"kind": "prop", "tag": kind, "depth": anchor.y, "prop": prop, "asset_id": prop.id,
					"bounds": Rect2(anchor - Vector2(24, 46), Vector2(52, 50)),
				})
			elif PROP_BOUNDS.has(kind):
				var local: Rect2 = PROP_BOUNDS[kind]
				var position := anchor + local.position
				_depth_items.append({
					"kind": "asset", "tag": kind, "depth": anchor.y, "asset_id": prop.id,
					"bounds": Rect2(position, local.size), "position": position,
					"texture": _prop_texture(_prop_source(prop)),
				})


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


func _draw_scenery() -> void:
	for prop in _props:
		if prop.kind == "beach_flag":
			continue
		if not _interleave:
			draw_prop(_scenery, prop)
		elif AmenityArt.handles(prop.kind):
			AmenityArt.draw_base(_scenery, prop)
		elif prop.kind == "bench":
			var cell: Array = prop.cell
			_scenery.draw_texture(FurnitureDepth.data(prop.kind, int(prop.rotation)).base,
				Vector2(cell[0], cell[1]) * GRID - Vector2(0, 6))


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


func _prop_depth(prop: Dictionary) -> float:
	if AmenityArt.handles(prop.kind) or prop.kind == "bench":
		return _landscape.prop_rect(prop).end.y
	return prop_anchor(prop).y


static func draw_prop(canvas: CanvasItem, prop: Dictionary, tint := Color.WHITE) -> void:
	var kind: String = prop.kind
	if AmenityArt.handles(kind):
		AmenityArt.draw_prop(canvas, prop, tint)
		return
	var rotation := posmod(int(prop.get("rotation", 0)), 4)
	if kind == "bench":
		var cell: Array = prop.cell
		var size := Vector2(24, 8) if rotation % 2 == 0 else Vector2(8, 24)
		FurnitureArt.draw_furniture(canvas, kind, rotation, Rect2(Vector2(cell[0], cell[1]) * GRID, size), tint)
		return
	var anchor := prop_anchor(prop)
	if kind == "beach_flag":
		draw_beach_flag(canvas, anchor, rotation, Color("#78c897"), 0, 0, tint)
		return
	if not PROP_BOUNDS.has(kind):
		return
	var bounds: Rect2 = PROP_BOUNDS[kind]
	var target := Rect2(anchor + bounds.position, bounds.size)
	canvas.draw_texture_rect_region(PROPS, target, _prop_source(prop), tint)


static func _prop_source(prop: Dictionary) -> Rect2:
	var kind: String = prop.kind
	var rotation := posmod(int(prop.get("rotation", 0)), 4)
	var row := int(prop.get("variant", 0))
	var palm_rows := PROPS.get_height() / PROP_SPAN - 2
	if kind == "bush":
		row = palm_rows
	elif kind == "rock":
		row = palm_rows + 1
	elif row < 0 or row >= palm_rows:
		row = 0
	var bounds: Rect2 = PROP_BOUNDS[kind]
	return Rect2(Vector2(rotation, row) * PROP_SPAN + PROP_ANCHOR + bounds.position, bounds.size)


static func _prop_texture(source: Rect2) -> Texture2D:
	if not _prop_textures.has(source):
		_prop_textures[source] = ImageTexture.create_from_image(PROPS.get_image().get_region(Rect2i(source)))
	return _prop_textures[source]


static func draw_beach_flag(canvas: CanvasItem, anchor: Vector2, rotation: int, color: Color, fold: float, tip: float, tint := Color.WHITE) -> void:
	var panel := anchor + Vector2(-23, -23)
	canvas.draw_rect(Rect2(anchor + Vector2(-3, -2), Vector2(19, 3)), Color("#d6ad83") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-1, -43), Vector2(3, 43)), Color("#966952") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-1, -43), Vector2(1, 43)), Color("#f8d5a1") * tint)
	canvas.draw_rect(Rect2(anchor + Vector2(-2, -45), Vector2(5, 3)), Color("#fbe8b7") * tint)
	var flag := flag_outline(anchor, rotation, fold, tip)
	canvas.draw_colored_polygon(flag, color * tint)
	canvas.draw_polyline(flag, Color("#715651") * tint, 1.0)
	canvas.draw_rect(Rect2(panel + Vector2(1, 1), Vector2(49, 21)), Color("#b58b68") * tint)
	canvas.draw_rect(Rect2(panel, Vector2(49, 21)), Color("#443b40") * tint)
	canvas.draw_rect(Rect2(panel, Vector2(49, 1)), Color("#fff0c5") * tint)
	canvas.draw_string(ThemeDB.fallback_font, panel + Vector2(1, 18), "OCEAN", HORIZONTAL_ALIGNMENT_CENTER, 47, 7, Color("#fff0d0") * tint)


static func flag_outline(anchor: Vector2, rotation: int, fold: float, tip: float) -> PackedVector2Array:
	var side := 1.0 if rotation < 2 else -1.0
	var reach := 23.0 if rotation % 2 == 0 else 18.0
	return PackedVector2Array([
		anchor + Vector2(2 * side, -40),
		anchor + Vector2(reach * 0.52 * side, -40 + fold),
		anchor + Vector2(reach * side, -38 + tip),
		anchor + Vector2((reach - 6) * side, -32 + tip),
		anchor + Vector2(reach * side, -26 + tip),
		anchor + Vector2(reach * 0.52 * side, -28 + fold),
		anchor + Vector2(2 * side, -28),
	])
