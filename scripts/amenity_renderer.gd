extends RefCounted
## Original pixel art for outdoor amenities. Ground features turn with the prop,
## while poles, backs, canopies and lighting remain upright in the map view.

const Landscape := preload("res://scripts/landscape_model.gd")
const PLUM := Color("#483747")
const SHADE := Color("#7b555040")
const BROWN := Color("#865545")
const WOOD := Color("#be8058")
const WOOD_LIGHT := Color("#edb883")
const IVORY := Color("#fff0c8")
const STRAW := Color("#e1ad59")
const STRAW_LIT := Color("#f5d58b")
const STRAW_DARK := Color("#bb8047")
const TEAL := Color("#3caaac")
const TEAL_DARK := Color("#397879")
const TEAL_LIT := Color("#9ddbd1")
const CORAL := Color("#dc7954")
const CORAL_DARK := Color("#9e514b")
const SAND := Color("#efd095")
const SAND_LIT := Color("#f7dfaa")
const SAND_DARK := Color("#d5a673")
const NET := Color("#698681")
const NIGHT := Color("#37374a")

static var _frames := {}
static var _textures := {}


static func handles(kind: String) -> bool:
	return Landscape.PROP_CATALOG.has(kind) and Landscape.PROP_CATALOG[kind].has("overhang")


static func ground_size(kind: String) -> Vector2:
	var size: Array = Landscape.PROP_CATALOG[kind].size
	return Vector2(size[0], size[1]) * Landscape.GRID


static func ground_point(position: Vector2, size: Vector2, rotation: int, local: Vector2) -> Vector2:
	match rotation:
		1: return position + Vector2(size.y - local.y, local.x)
		2: return position + size - local
		3: return position + Vector2(local.y, size.x - local.x)
	return position + local


static func at(amenity: Dictionary, local: Vector2) -> Vector2:
	var bounds: Rect2 = amenity.rect
	return ground_point(bounds.position, ground_size(amenity.kind), int(amenity.rotation), local)


static func draw_prop(canvas: CanvasItem, prop: Dictionary, tint: Color) -> void:
	var kind: String = prop.kind
	var rotation := posmod(int(prop.get("rotation", 0)), 4)
	var key := kind + str(rotation)
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(frame(kind, rotation))
	var cell: Array = prop.cell
	var origin := Vector2(cell[0], cell[1]) * Landscape.GRID + art_offset(kind)
	canvas.draw_texture(_textures[key], origin, tint)


static func art_offset(kind: String) -> Vector2:
	return Vector2(0, -Landscape.PROP_CATALOG[kind].overhang)


static func frame(kind: String, rotation: int) -> Image:
	rotation = posmod(rotation, 4)
	var key := kind + str(rotation)
	if _frames.has(key):
		return _frames[key]
	var size := ground_size(kind)
	var area := Vector2i(size if rotation % 2 == 0 else Vector2(size.y, size.x))
	var origin := -art_offset(kind)
	var result := Image.create(area.x, area.y + int(origin.y), false, Image.FORMAT_RGBA8)
	match kind:
		"beach_lounge": _lounge(result, origin, size, rotation)
		"volleyball": _court(result, origin, size, rotation)
		"beach_bar": _bar(result, origin, size, rotation)
		"stage": _stage(result, origin, size, rotation)
	_frames[key] = result
	return result


static func _block(image: Image, x: float, y: float, w: float, h: float, color: Color) -> void:
	var bounds := Rect2i(roundi(x), roundi(y), roundi(w), roundi(h))
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounds.has_area():
		image.fill_rect(bounds, color)


static func _rect(image: Image, a: Vector2, b: Vector2, color: Color) -> void:
	var top := a.min(b)
	var extent := (b - a).abs()
	_block(image, top.x, top.y, extent.x, extent.y, color)


static func _line(image: Image, start: Vector2, finish: Vector2, color: Color) -> void:
	var steps := maxi(roundi(absf(finish.x - start.x)), roundi(absf(finish.y - start.y)))
	for i in range(steps + 1):
		var point := start.lerp(finish, float(i) / maxi(steps, 1))
		_block(image, point.x, point.y, 1, 1, color)


static func _ground(image: Image, origin: Vector2, size: Vector2, rotation: int, rect: Rect2, color: Color) -> void:
	_rect(image, ground_point(origin, size, rotation, rect.position),
		ground_point(origin, size, rotation, rect.end), color)


static func _lounge(image: Image, origin: Vector2, size: Vector2, rotation: int) -> void:
	for index: int in 2:
		var y := 2 + index * 12
		var chair := Rect2(4, y, 19, 8)
		var color := TEAL if index == 0 else CORAL
		var shade := TEAL_DARK if index == 0 else CORAL_DARK
		_ground(image, origin, size, rotation, Rect2(chair.position + Vector2(0, 1), chair.size + Vector2(1, 1)), SHADE)
		_ground(image, origin, size, rotation, chair, PLUM)
		_ground(image, origin, size, rotation, chair.grow(-1), WOOD_LIGHT)
		_ground(image, origin, size, rotation, Rect2(5, y + 2, 17, 4), color)
		for stripe in [7, 13, 19]:
			_ground(image, origin, size, rotation, Rect2(stripe, y + 2, 2, 4), IVORY)
		var back := ground_point(origin, size, rotation, Vector2(7, y + 4))
		_block(image, back.x - 3, back.y - 5, 7, 5, PLUM)
		_block(image, back.x - 2, back.y - 4, 5, 3, shade)
		_block(image, back.x - 2, back.y - 4, 5, 1, IVORY)
	var pole := ground_point(origin, size, rotation, Vector2(17, 11))
	var x := pole.x - 10
	var y := maxf(1.0, pole.y - 22.0)
	var pole_height := pole.y - y - 3.0
	_block(image, pole.x - 8, pole.y + 1, 17, 3, SHADE)
	_block(image, pole.x - 2, pole.y, 5, 2, STRAW_DARK)
	_block(image, pole.x, y + 3, 2, pole_height, BROWN)
	_block(image, pole.x, y + 3, 1, pole_height, IVORY)
	_block(image, x + 7, y, 7, 2, PLUM)
	_block(image, x + 3, y + 2, 15, 2, PLUM)
	_block(image, x + 1, y + 4, 19, 3, PLUM)
	_block(image, x, y + 7, 21, 3, PLUM)
	_block(image, x + 7, y + 1, 7, 1, CORAL.lightened(0.13))
	_block(image, x + 3, y + 3, 15, 1, CORAL.lightened(0.13))
	_block(image, x + 2, y + 4, 17, 3, CORAL.lightened(0.13))
	_block(image, x + 1, y + 7, 19, 2, CORAL_DARK)
	_block(image, x + 9, y + 2, 3, 2, IVORY)
	_block(image, x + 7, y + 4, 7, 3, IVORY)
	_block(image, x + 6, y + 7, 9, 2, STRAW_LIT)
	for fringe in [1, 5, 10, 15, 19]:
		_block(image, x + fringe, y + 9, 1, 1, STRAW_LIT)
	_block(image, x + 10, y - 1, 1, 2, IVORY)


static func _court(image: Image, origin: Vector2, size: Vector2, rotation: int) -> void:
	_ground(image, origin, size, rotation, Rect2(2, 2, 76, 52), SAND_DARK)
	_ground(image, origin, size, rotation, Rect2(3, 3, 74, 50), SAND)
	_ground(image, origin, size, rotation, Rect2(5, 5, 70, 1), SAND_LIT)
	for row in range(7, 53, 4):
		for col in range(7 + (row % 5), 74, 8):
			var variation := SAND_DARK if (col + row) % 5 == 0 else SAND_LIT
			_ground(image, origin, size, rotation, Rect2(col, row, 1 + row % 2, 1), variation)
	for stripe in [Rect2(8, 8, 64, 2), Rect2(8, 46, 64, 2), Rect2(8, 10, 2, 36),
			Rect2(70, 10, 2, 36), Rect2(39, 10, 2, 36)]:
		_ground(image, origin, size, rotation, stripe, IVORY)
	var top := ground_point(origin, size, rotation, Vector2(40, 5))
	var bottom := ground_point(origin, size, rotation, Vector2(40, 51))
	# Give an edge-on net the same shallow camera angle as the furniture.
	if rotation % 2 == 0:
		top.x += -7 if top.y < bottom.y else 7
		bottom.x += 7 if top.y < bottom.y else -7
	_line(image, top + Vector2(2, 2), bottom + Vector2(2, 2), SHADE)
	for row in [3, 6, 9]:
		_line(image, top - Vector2(0, row), bottom - Vector2(0, row), NET)
	for segment in range(1, 12):
		var point := top.lerp(bottom, float(segment) / 12)
		_line(image, point - Vector2(0, 3), point - Vector2(0, 9), NET.lightened(0.14))
	_line(image, top - Vector2(0, 10), bottom - Vector2(0, 10), IVORY)
	for post: Vector2 in [top, bottom]:
		_block(image, post.x - 3, post.y - 2, 7, 4, SAND_DARK)
		_block(image, post.x - 2, post.y - 11, 4, 12, PLUM)
		_block(image, post.x - 1, post.y - 10, 2, 8, TEAL)
		_block(image, post.x - 1, post.y - 11, 2, 1, TEAL_LIT)
		_block(image, post.x - 2, post.y - 3, 4, 1, IVORY)


static func _bar(image: Image, origin: Vector2, size: Vector2, rotation: int) -> void:
	_ground(image, origin, size, rotation, Rect2(3, 4, 42, 23), SHADE)
	_ground(image, origin, size, rotation, Rect2(4, 5, 40, 20), BROWN)
	_ground(image, origin, size, rotation, Rect2(5, 6, 38, 18), WOOD)
	for row in range(7, 24, 4):
		_ground(image, origin, size, rotation, Rect2(5, row, 38, 1), WOOD_LIGHT)
	var bar_a := ground_point(origin, size, rotation, Vector2(4, 9))
	var bar_b := ground_point(origin, size, rotation, Vector2(44, 20))
	var top := bar_a.min(bar_b)
	var extent := (bar_b - bar_a).abs()
	_block(image, top.x, top.y - 4, extent.x, extent.y + 4, PLUM)
	_block(image, top.x + 1, top.y - 3, extent.x - 2, extent.y + 1, TEAL_DARK)
	for panel in range(3, int(extent.x) - 2, 4):
		_block(image, top.x + panel, top.y + extent.y - 5, 2, 4, TEAL)
	_block(image, top.x, top.y - 4, extent.x, 3, WOOD_LIGHT)
	_block(image, top.x + 1, top.y - 5, extent.x - 2, 1, IVORY)
	var right := top.x + extent.x - 1
	var y := top.y - 2
	for pole in [top.x + 1, right - 2]:
		_block(image, pole, y - 14, 2, 15, PLUM)
		_block(image, pole, y - 13, 1, 13, WOOD_LIGHT)
	for index in range(1, 5):
		var x := top.x + roundf(extent.x * index / 5)
		var bottle_y := y - (7 if index % 2 else 6)
		_block(image, x, bottle_y, 2, 6, PLUM)
		_block(image, x, bottle_y + 2, 2, 3, TEAL_LIT if index % 2 else CORAL)
		_block(image, x, bottle_y, 2, 1, STRAW_LIT)
	var width := extent.x + 6
	var x := top.x - 3
	var canopy_y := y - 14
	_block(image, x + 4, canopy_y - 2, width - 8, 2, PLUM)
	_block(image, x + 2, canopy_y, width - 4, 3, STRAW_LIT)
	_block(image, x, canopy_y + 3, width, 4, STRAW)
	_block(image, x, canopy_y + 7, width, 1, BROWN)
	for straw in range(1, int(width) - 1, 3):
		_block(image, x + straw, canopy_y + 2 + straw % 3, 1, 3, STRAW_DARK)
		_block(image, x + straw, canopy_y + 6, 2, 2 + straw % 2, STRAW_LIT)
	var sign := top.x + floorf((extent.x - 8) / 2)
	_block(image, sign, canopy_y + 5, 8, 6, PLUM)
	_block(image, sign + 1, canopy_y + 6, 6, 4, TEAL_DARK)
	_block(image, sign + 3, canopy_y + 7, 3, 2, IVORY)
	_block(image, sign + 4, canopy_y + 6, 1, 4, CORAL)


static func _stage(image: Image, origin: Vector2, size: Vector2, rotation: int) -> void:
	_ground(image, origin, size, rotation, Rect2(3, 1, 58, 24), SHADE)
	var a := ground_point(origin, size, rotation, Vector2(4, 2))
	var b := ground_point(origin, size, rotation, Vector2(60, 23))
	var corner := a.min(b)
	var extent := (b - a).abs()
	var x := corner.x
	var y := corner.y
	var width := extent.x
	var depth := extent.y
	_block(image, x, y - 4, width, depth + 4, PLUM)
	_block(image, x + 1, y - 3, width - 2, depth - 3, WOOD)
	for row in range(-3, int(depth) - 4, 3):
		_block(image, x + 2, y + row, width - 4, 1, WOOD_LIGHT)
		var seam := 5 + posmod(row * 7, int(width) - 10)
		_block(image, x + seam, y + row + 1, 1, 2, BROWN)
	_block(image, x + 1, y + depth - 5, width - 2, 1, IVORY)
	_block(image, x + 1, y + depth - 4, width - 2, 3, BROWN)
	var left := x + 2
	var right := x + width - 3
	_block(image, left, y - 15, width - 4, 2, PLUM)
	_block(image, left + 1, y - 15, width - 6, 1, IVORY)
	for column in [left, right]:
		_block(image, column - 1, y - 15, 3, 19, PLUM)
		_block(image, column, y - 14, 1, 17, WOOD_LIGHT)
	for speaker in [left + 1, right - 5]:
		_block(image, speaker, y, 5, 9, PLUM)
		_block(image, speaker + 1, y + 1, 3, 1, TEAL_DARK)
		_block(image, speaker + 1, y + 4, 3, 3, NIGHT.lightened(0.22))
		_block(image, speaker + 2, y + 5, 1, 1, NIGHT)
	var middle := x + floorf(width / 2)
	var banner := minf(23, width - 10)
	_block(image, middle - floorf(banner / 2), y - 13, banner, 8, CORAL_DARK)
	_block(image, middle - floorf(banner / 2) + 1, y - 12, banner - 2, 5, CORAL)
	_block(image, middle, y - 12, 1, 4, IVORY)
	_block(image, middle, y - 12, 3, 1, IVORY)
	_block(image, middle - 2, y - 9, 3, 2, IVORY)
	for lamp in [left + 3, right - 5]:
		_block(image, lamp, y - 14, 3, 4, NIGHT)
		_block(image, lamp, y - 11, 3, 1, TEAL_LIT)
	for seat in range(4):
		_ground(image, origin, size, rotation, Rect2(4 + seat * 15, 29, 12, 9), SHADE)
		_ground(image, origin, size, rotation, Rect2(4 + seat * 15, 27, 12, 9), TEAL_DARK)
		_ground(image, origin, size, rotation, Rect2(5 + seat * 15, 28, 10, 7), TEAL if seat % 2 == 0 else CORAL)
		_ground(image, origin, size, rotation, Rect2(6 + seat * 15, 28, 1, 7), IVORY)
