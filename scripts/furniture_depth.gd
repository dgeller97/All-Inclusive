extends RefCounted
## Contact-depth metadata for the existing atlas. Colors remain atlas pixels.
## Geometry mirrors furnitureAtlas in generate_art.mjs: flat tops have a height,
## upright posts have a ground anchor, and rails retain depth along their length.
const ATLAS := preload("res://assets/art/furniture.png")
const KINDS := ["bed", "desk", "counter", "table", "lounger", "umbrella", "plant", "bench"]
const SIZES := [Vector2i(16, 24), Vector2i(24, 16), Vector2i(32, 16), Vector2i(16, 16), Vector2i(8, 24), Vector2i(16, 16), Vector2i(8, 8), Vector2i(24, 8)]
static var _cache := {}
var _depth := PackedFloat32Array()
var _size: Vector2i
var _extent: Vector2i
var _turn := 0

static func data(kind: String, turn: int) -> Dictionary:
	var key := kind + str(posmod(turn, 4))
	if _cache.has(key):
		return _cache[key]
	var row := KINDS.find(kind)
	if row < 0:
		return {}
	var painter := new()
	painter._size = SIZES[row]
	painter._turn = posmod(turn, 4)
	painter._extent = (painter._size if turn % 2 == 0 else Vector2i(painter._size.y, painter._size.x)) + Vector2i(0, 6)
	painter._depth.resize(painter._extent.x * painter._extent.y)
	painter._depth.fill(NAN)
	painter._paint(row)
	var image := ATLAS.get_image().get_region(Rect2i(Vector2i(posmod(turn, 4), row) * 40, painter._extent))
	image.convert(Image.FORMAT_RGBA8)
	var base := image.duplicate()
	var layers := {}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a < 0.99:
				continue
			var depth: float = painter._depth[y * painter._extent.x + x]
			assert(is_finite(depth), "Every opaque furniture pixel must have contact geometry: %s (%d,%d)" % [key, x, y])
			if not is_finite(depth):
				depth = float(clampi(y - 3, 0, painter._extent.y - 7))
			if not layers.has(depth):
				layers[depth] = Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
			layers[depth].set_pixel(x, y, color)
			base.set_pixel(x, y, Color.TRANSPARENT)
	var pieces: Array[Dictionary] = []
	var depths := layers.keys()
	depths.sort()
	for depth in depths:
		var ink: Image = layers[depth]
		var used := ink.get_used_rect()
		var pixels := ink.get_region(used)
		pieces.append({"texture": ImageTexture.create_from_image(pixels), "image": pixels,
			"offset": Vector2(used.position) - Vector2(0, 6), "depth": float(depth)})
	_cache[key] = {"base": ImageTexture.create_from_image(base), "base_image": base, "layers": pieces}
	return _cache[key]

func _at(x: int, y: int, z: int = 0) -> Vector2i:
	var ground := Vector2i(x, y)
	match _turn:
		1: ground = Vector2i(_size.y - 1 - y, x)
		2: ground = _size - Vector2i.ONE - ground
		3: ground = Vector2i(y, _size.x - 1 - x)
	return ground + Vector2i(0, 6 - z)

func _mark(at: Vector2i, depth: float) -> void:
	if Rect2i(Vector2i.ZERO, _extent).has_point(at):
		_depth[at.y * _extent.x + at.x] = depth

func _rect(rect: Rect2i, depth: float = NAN, height: int = 0) -> void:
	var clipped := rect.intersection(Rect2i(Vector2i.ZERO, _extent))
	for y in range(clipped.position.y, clipped.end.y):
		for x in range(clipped.position.x, clipped.end.x):
			_mark(Vector2i(x, y), depth if is_finite(depth) else float(y - 6 + height))

func _flat(x: int, y: int, width: int, height: int, lift: int = 0) -> void:
	var a := _at(x, y, lift)
	var b := _at(x + width - 1, y + height - 1, lift)
	_rect(Rect2i(a.min(b), (a - b).abs() + Vector2i.ONE), NAN, lift)

func _upright(x: int, y: int, width: int, height: int, lift: int = 0) -> void:
	var at := _at(x, y, lift)
	_rect(Rect2i(at - Vector2i(width / 2, height - 1), Vector2i(width, height)), float(_at(x, y).y - 6))

func _line(a: Vector2i, b: Vector2i, lift: int) -> void:
	var delta := (b - a).abs()
	var direction := (b - a).sign()
	var error := delta.x - delta.y
	while true:
		_mark(a, float(a.y - 6 + lift))
		if a == b:
			return
		var doubled := error * 2
		if doubled >= -delta.y:
			error -= delta.y
			a.x += direction.x
		if doubled <= delta.x:
			error += delta.x
			a.y += direction.y

func _rail(x1: int, y1: int, x2: int, y2: int, lift: int, height: int) -> void:
	for dy in height:
		_line(_at(x1, y1, lift + dy), _at(x2, y2, lift + dy), lift + dy)

func _raised(x: int, y: int, width: int, height: int, tall: int) -> void:
	_flat(x + 1, y + 1, width, height)
	for sx in [x + 1, x + width - 2]:
		for sy in [y + 1, y + height - 2]:
			_upright(sx, sy, 2, tall)
	_flat(x, y, width, height, tall - 1)
	_flat(x, y, width, height, tall)
	_flat(x, y, width, height, tall + 1)
	_flat(x + 1, y + 1, width - 2, height - 2, tall + 1)

func _paint(row: int) -> void:
	var w := _size.x
	var h := _size.y
	match row:
		0:
			_raised(1, 1, 14, 22, 2)
			_flat(2, 9, 12, 12, 3)
			for x in [3, 9]:
				_flat(x, 3, 4, 4, 3)
			_rail(1, 1, 14, 1, 4, 4)
		1, 2:
			_raised(1, 2, w - 2, h - 4, 4)
			_rail(2, h - 4, w - 3, h - 4, 1, 3)
			for x in range(4, w - 4, 7):
				_flat(x, h - 4, 3, 1, 2)
			if row == 1:
				_flat(3, 8, 6, 3, 5)
				var point := _at(15, 6, 5)
				var ground := float(_at(15, 6).y - 6)
				_rect(Rect2i(point - Vector2i(1, 2), Vector2i(3, 3)), ground)
				_rect(Rect2i(point - Vector2i(3, 6), Vector2i(7, 5)), ground)
			else:
				for index in range(3):
					_flat(3 + index * 9, 6, 8, 5, 5)
		3:
			_raised(1, 2, 14, 12, 2)
			_flat(1, 6, 14, 4, 3)
			_flat(7, 7, 2, 2, 4)
			_flat(7, 7, 1, 1, 5)
		4:
			_raised(1, 1, 6, 22, 1)
			for y in [9, 13, 17]:
				_flat(2, y, 4, 1, 2)
			_rail(1, 2, 6, 2, 3, 3)
		5:
			_flat(5, 6, 7, 6)
			_flat(6, 6, 4, 4)
			_upright(7, 7, 2, 12)
			var top := _at(7, 7, 11)
			_rect(Rect2i(0, top.y - 2, 16, 9), NAN, 11)
		6:
			_flat(1, 2, 6, 6)
			var center := _at(3, 3)
			_rect(Rect2i(center - Vector2i(3, 8), Vector2i(7, 10)), float(center.y - 6))
		7:
			_raised(1, 2, 22, 5, 2)
			_rail(1, 2, 22, 2, 3, 4)
			_rail(2, 3, 21, 3, 3, 1)
