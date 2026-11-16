extends RefCounted
## Original pixel art for outdoor amenities. Ground features turn with the prop,
## while poles, backs, canopies and lighting remain upright in the map view.

const Landscape := preload("res://scripts/landscape_model.gd")
const Facilities := preload("res://scripts/facility_renderer.gd")
const Depth := preload("res://scripts/render_depth.gd")
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
static var _bases := {}
static var _base_textures := {}
static var _layers := {}


static func handles(kind: String) -> bool:
	return Landscape.PROP_CATALOG.has(kind) and Landscape.PROP_CATALOG[kind].has("overhang")


static func ground_size(kind: String) -> Vector2:
	var size: Array = Landscape.PROP_CATALOG[kind].size
	return Vector2(size[0], size[1]) * Landscape.GRID


static func ground_point(position: Vector2, size: Vector2, rotation: int, local: Vector2) -> Vector2:
	return Facilities.ground_point(position, size, rotation, local)


static func at(amenity: Dictionary, local: Vector2) -> Vector2:
	var bounds: Rect2 = amenity.rect
	return ground_point(bounds.position, ground_size(amenity.kind), int(amenity.rotation), local)


static func stage_lamps(amenity: Dictionary) -> Array[Vector2]:
	return [at(amenity, Vector2(10, 5)) - Vector2(0, 14), at(amenity, Vector2(52, 5)) - Vector2(0, 14)]


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


static func draw_base(canvas: CanvasItem, prop: Dictionary) -> void:
	var kind: String = prop.kind
	var turn := posmod(int(prop.rotation), 4)
	var key := kind + str(turn)
	if not _base_textures.has(key):
		_base_textures[key] = ImageTexture.create_from_image(base_image(kind, turn))
	var site := Vector2(prop.cell[0], prop.cell[1]) * Landscape.GRID
	canvas.draw_texture(_base_textures[key], site + art_offset(kind))


static func base_image(kind: String, rotation: int) -> Image:
	var turn := posmod(rotation, 4)
	_build_art(kind, turn)
	return _bases[kind + str(turn)]


static func layers(kind: String, rotation: int) -> Array[Dictionary]:
	var turn := posmod(rotation, 4)
	_build_art(kind, turn)
	return _layers[kind + str(turn)]


static func frame(kind: String, rotation: int) -> Image:
	rotation = posmod(rotation, 4)
	var key := kind + str(rotation)
	if _frames.has(key):
		return _frames[key]
	var result: Image = base_image(kind, rotation).duplicate()
	for layer in layers(kind, rotation):
		result.blend_rect(layer.image, Rect2i(Vector2i.ZERO, Vector2i(layer.size)), Vector2i(layer.offset))
	_frames[key] = result
	return result


static func _build_art(kind: String, rotation: int) -> void:
	var key := kind + str(rotation)
	if _bases.has(key):
		return
	var size := ground_size(kind)
	var area := Vector2i(size if rotation % 2 == 0 else Vector2(size.y, size.x))
	var origin := -art_offset(kind)
	var result := Image.create(area.x, area.y + int(origin.y), false, Image.FORMAT_RGBA8)
	var parts: Array[Dictionary] = []
	match kind:
		"beach_lounge": _lounge(result, origin, size, rotation, parts)
		"volleyball": _court(result, origin, size, rotation, parts)
		"beach_bar": _bar(result, origin, size, rotation, parts)
		"stage": _stage(result, origin, size, rotation, parts)
		_: Facilities.paint(result, origin, size, rotation, kind, parts)
	Depth.order(parts)
	_bases[key] = result
	_layers[key] = parts


static func _cutout(image: Image) -> Image:
	return Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)


static func _append(parts: Array[Dictionary], image: Image, origin: Vector2, at: Vector2, tag: String, bias: float = 0.0) -> void:
	var item := Depth.piece(image, at.y - origin.y + bias, tag)
	if not item.is_empty():
		parts.append(item)


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


static func _ground(image: Image, origin: Vector2, size: Vector2, rotation: int, rect: Rect2, color: Color, lift: float = 0.0) -> void:
	var elevation := Vector2(0, lift)
	_rect(image, ground_point(origin, size, rotation, rect.position) - elevation,
		ground_point(origin, size, rotation, rect.end) - elevation, color)


static func _lounge(image: Image, origin: Vector2, size: Vector2, rotation: int, parts: Array[Dictionary]) -> void:
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
		var rest := _cutout(image)
		_block(rest, back.x - 3, back.y - 5, 7, 5, PLUM)
		_block(rest, back.x - 2, back.y - 4, 5, 3, shade)
		_block(rest, back.x - 2, back.y - 4, 5, 1, IVORY)
		_append(parts, rest, origin, back, "lounge_back")
	var pole := ground_point(origin, size, rotation, Vector2(17, 11))
	var x := pole.x - 10
	var y := maxf(1.0, pole.y - 22.0)
	var pole_height := pole.y - y - 3.0
	_block(image, pole.x - 8, pole.y + 1, 17, 3, SHADE)
	_block(image, pole.x - 2, pole.y, 5, 2, STRAW_DARK)
	image = _cutout(image)
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
	_append(parts, image, origin, pole, "lounge_parasol")


static func _court(image: Image, origin: Vector2, size: Vector2, rotation: int, parts: Array[Dictionary]) -> void:
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
	_line(image, top + Vector2(2, 2), bottom + Vector2(2, 2), SHADE)
	# At an edge-on view, a one-pixel side profile keeps the net legible.
	var mesh_x := 1 if rotation % 2 == 0 else 0
	for segment in range(12):
		var start := top.lerp(bottom, float(segment) / 12)
		var end := top.lerp(bottom, float(segment + 1) / 12)
		var mesh := _cutout(image)
		for row in [3, 6, 9]:
			_line(mesh, start - Vector2(mesh_x, row), end - Vector2(mesh_x, row), NET)
		_line(mesh, end - Vector2(0, 3), end - Vector2(0, 9), NET.lightened(0.14))
		_line(mesh, start - Vector2(0, 10), end - Vector2(0, 10), IVORY)
		_append(parts, mesh, origin, start.lerp(end, 0.5), "volleyball_net")
	for post: Vector2 in [top, bottom]:
		_block(image, post.x - 3, post.y - 2, 7, 4, SAND_DARK)
		var upright := _cutout(image)
		_block(upright, post.x - 2, post.y - 11, 4, 12, PLUM)
		_block(upright, post.x - 1, post.y - 10, 2, 8, TEAL)
		_block(upright, post.x - 1, post.y - 11, 2, 1, TEAL_LIT)
		_block(upright, post.x - 2, post.y - 3, 4, 1, IVORY)
		_append(parts, upright, origin, post, "volleyball_post", 0.1)


static func _bar(image: Image, origin: Vector2, size: Vector2, rotation: int, parts: Array[Dictionary]) -> void:
	_ground(image, origin, size, rotation, Rect2(3, 4, 42, 23), SHADE)
	_ground(image, origin, size, rotation, Rect2(4, 5, 40, 21), BROWN)
	_ground(image, origin, size, rotation, Rect2(5, 6, 38, 19), WOOD)
	for row in range(7, 25, 4):
		_ground(image, origin, size, rotation, Rect2(5, row, 38, 1), WOOD_LIGHT)

	for band in (13 if rotation % 2 == 0 else 20):
		var panel := Rect2(4, 8 + band, 40, 1) if rotation % 2 == 0 else Rect2(4 + 2 * band, 8, 2, 13)
		var piece := _cutout(image)
		_ground(piece, origin, size, rotation, panel, PLUM)
		_ground(piece, origin, size, rotation, panel.intersection(Rect2(5, 9, 38, 11)), TEAL_DARK, 2)
		_ground(piece, origin, size, rotation, panel, WOOD_LIGHT, 4)
		_ground(piece, origin, size, rotation, panel.intersection(Rect2(5, 19, 38, 1)), IVORY, 4)
		_append(parts, piece, origin, ground_point(origin, size, rotation, panel.get_center()), "bar_counter")
	for index in range(4):
		var contact := ground_point(origin, size, rotation, Vector2(8 + index * 10, 13))
		var foot := contact - Vector2(0, 4)
		var bottle := _cutout(image)
		_block(bottle, foot.x - 1, foot.y - 5, 3, 6, PLUM)
		_block(bottle, foot.x, foot.y - 4, 2, 4, TEAL_LIT if index % 2 else CORAL)
		_block(bottle, foot.x, foot.y - 5, 1, 1, STRAW_LIT)
		_append(parts, bottle, origin, contact, "bar_bottle", 0.1)
	for local: Vector2 in [Vector2(5, 9), Vector2(42, 9), Vector2(5, 19), Vector2(42, 19)]:
		var pole := ground_point(origin, size, rotation, local)
		var post := _cutout(image)
		_block(post, pole.x - 1, pole.y - 15, 3, 12, PLUM)
		_block(post, pole.x, pole.y - 15, 1, 11, WOOD_LIGHT)
		_append(parts, post, origin, pole, "bar_post", 0.1)

	for band in (6 if rotation % 2 == 0 else 22):
		var local := Vector2(2, 7) + (Vector2(0, 2 * band) if rotation % 2 == 0 else Vector2(2 * band, 0))
		var span := Vector2(44, 2) if rotation % 2 == 0 else Vector2(2, 12)
		var panel := Rect2(local, span)
		var piece := _cutout(image)
		_ground(piece, origin, size, rotation, panel, BROWN, 13)
		_ground(piece, origin, size, rotation, panel, STRAW, 14)
		_ground(piece, origin, size, rotation, panel.intersection(Rect2(3, 8, 42, 10)), STRAW_LIT, 16)
		for x in range(5, 44, 3):
			_ground(piece, origin, size, rotation, panel.intersection(Rect2(x, 9, 1, 8)), STRAW_DARK, 16)
			_ground(piece, origin, size, rotation, panel.intersection(Rect2(x, 18, 2, 1)), IVORY, 14)
		_append(parts, piece, origin, ground_point(origin, size, rotation, panel.get_center()), "bar_canopy", 0.2)
	var sign_contact := ground_point(origin, size, rotation, Vector2(24, 19))
	var sign := sign_contact - Vector2(0, 11)
	var plaque := _cutout(image)
	_block(plaque, sign.x - 4, sign.y, 8, 6, PLUM)
	_block(plaque, sign.x - 3, sign.y + 1, 6, 4, TEAL_DARK)
	_block(plaque, sign.x - 1, sign.y + 2, 3, 2, IVORY)
	_block(plaque, sign.x, sign.y + 1, 1, 4, CORAL)
	_append(parts, plaque, origin, sign_contact, "bar_sign", 0.25)


static func _stage(image: Image, origin: Vector2, size: Vector2, rotation: int, parts: Array[Dictionary]) -> void:
	var platform := Rect2(4, 2, 56, 21)
	_ground(image, origin, size, rotation, platform.grow(1), SHADE)
	_ground(image, origin, size, rotation, platform, PLUM)
	_ground(image, origin, size, rotation, platform, BROWN, 2)
	_ground(image, origin, size, rotation, platform.grow(-1), WOOD, 4)
	for row in range(3, 21, 3):
		_ground(image, origin, size, rotation, Rect2(5, row, 54, 1), WOOD_LIGHT, 4)
		_ground(image, origin, size, rotation, Rect2(9 + posmod(row * 7, 46), row + 1, 1, 2), BROWN, 4)
	_ground(image, origin, size, rotation, Rect2(5, 21, 54, 1), IVORY, 4)

	var left := ground_point(origin, size, rotation, Vector2(6, 5))
	var right := ground_point(origin, size, rotation, Vector2(57, 5))
	for column: Vector2 in [left, right]:
		var post := _cutout(image)
		_block(post, column.x - 1, column.y - 18, 3, 16, PLUM)
		_block(post, column.x, column.y - 17, 1, 14, WOOD_LIGHT)
		_append(parts, post, origin, column, "stage_post")
	for index in 26:
		var start := left.lerp(right, float(index) / 26.0)
		var finish := left.lerp(right, float(index + 1) / 26.0)
		var span := _cutout(image)
		_line(span, start - Vector2(0, 18), finish - Vector2(0, 18), IVORY)
		_line(span, start - Vector2(0, 17), finish - Vector2(0, 17), PLUM)
		_append(parts, span, origin, start.lerp(finish, 0.5), "stage_truss", 0.1)
	for speaker in [Vector2(9, 15), Vector2(53, 15)]:
		var contact := ground_point(origin, size, rotation, speaker)
		var foot := contact - Vector2(0, 4)
		var cabinet := _cutout(image)
		_block(cabinet, foot.x - 2, foot.y - 7, 5, 8, PLUM)
		_block(cabinet, foot.x - 1, foot.y - 6, 3, 1, TEAL_DARK)
		_block(cabinet, foot.x - 1, foot.y - 3, 3, 3, NIGHT.lightened(0.22))
		_block(cabinet, foot.x, foot.y - 2, 1, 1, NIGHT)
		_append(parts, cabinet, origin, contact, "stage_speaker")
	var banner_contact := ground_point(origin, size, rotation, Vector2(32, 5))
	var banner := banner_contact - Vector2(0, 16)
	var sign := _cutout(image)
	var width := 19 if rotation % 2 == 0 else 9
	var banner_left := banner.x - floorf(width * 0.5)
	_block(sign, banner_left, banner.y, width, 7, CORAL_DARK)
	_block(sign, banner_left + 1, banner.y + 1, width - 2, 5, CORAL)
	_block(sign, banner.x, banner.y + 1, 1, 4, IVORY)
	_block(sign, banner.x, banner.y + 1, 3, 1, IVORY)
	_block(sign, banner.x - 2, banner.y + 4, 3, 2, IVORY)
	_append(parts, sign, origin, banner_contact, "stage_banner", 0.2)
	for local in [Vector2(10, 5), Vector2(52, 5)]:
		var contact := ground_point(origin, size, rotation, local)
		var lamp := contact - Vector2(0, 14)
		var fixture := _cutout(image)
		_block(fixture, lamp.x, lamp.y - 2, 3, 4, NIGHT)
		_block(fixture, lamp.x, lamp.y, 3, 2, TEAL_LIT)
		_append(parts, fixture, origin, contact, "stage_lamp", 0.3)
	for seat in range(4):
		for row in [24, 36]:
			var bench := Rect2(2 + seat * 16, row, 12, 4)
			_ground(image, origin, size, rotation, bench.grow(1), SHADE)
			_ground(image, origin, size, rotation, bench, TEAL_DARK)
			_ground(image, origin, size, rotation, bench.grow(-1), TEAL if seat % 2 == 0 else CORAL)
			_ground(image, origin, size, rotation, Rect2(bench.position + Vector2(1, 1), Vector2(1, 3)), IVORY)
