extends RefCounted
## Original repeatable pixel textures for building surfaces.

const SIZE := Vector2i(16, 16)

static var _textures: Dictionary = {}


static func texture(surface: String, finish: String) -> Texture2D:
	var key := surface + "/" + finish
	if _textures.has(key):
		return _textures[key]
	var tile := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	match key:
		"floor/default": _pavers(tile, "#d9bea0", "#e8cdb0", "#bda084")
		"floor/tile": _glazed_tile(tile)
		"floor/wood": _boards(tile, "#dca979", "#c89261", "#ab744e")
		"floor/stone": _pavers(tile, "#c1b8a3", "#d1c8af", "#9e998a")
		"wall/default": _plaster(tile, "#efc89e", "#e8bf96", "#f5d1a9")
		"wall/plaster": _plaster(tile, "#cbd4bb", "#bac5a9", "#dbe0c7")
		"wall/brick": _brick(tile)
		"wall/timber": _boards(tile, "#ad7758", "#99644f", "#774c43")
		"facade/default": _plaster(tile, "#efc89e", "#e8bf96", "#f5d1a9")
		"facade/plaster": _plaster(tile, "#9dc2b3", "#89afa1", "#c3d7ba")
		"facade/brick": _brick(tile)
		"facade/timber": _boards(tile, "#bc9569", "#a77d5d", "#815c4f")
		"roof/default": _roof(tile, "#bd7258", "#e0a678", "#8f5148", false)
		"roof/terracotta": _roof(tile, "#ca8050", "#f2b476", "#9d533f", false)
		"roof/slate": _roof(tile, "#6f8291", "#a6b4ba", "#4b5b72", false)
		"roof/metal": _roof(tile, "#79a49d", "#a7d2c3", "#4e7875", true)
		"ceiling/default": _plaster(tile, "#f4dfba", "#eddbb5", "#f9e9ca")
		"ceiling/plaster": _plaster(tile, "#c5d5cc", "#b6c9bd", "#d4e0d6")
		"ceiling/beams": _beams(tile)
		"ceiling/panels": _panels(tile)
		_: return null
	var result := ImageTexture.create_from_image(tile)
	_textures[key] = result
	return result


static func _roof(tile: Image, body: String, light: String, seam: String, metal: bool) -> void:
	tile.fill(Color(body))
	if metal:
		for x in [2, 10]:
			_ink(tile, x, 0, 1, 16, seam)
			_ink(tile, x + 1, 0, 1, 16, light)
	else:
		for y in [0, 4, 8, 12]:
			_ink(tile, 0, y, 16, 1, seam)
			var offset: int = 2 + (int(y) >> 2) % 2 * 4
			for x in [offset, offset + 8]:
				_ink(tile, x, y + 1, 1, 3, seam)
				_ink(tile, x + 1, y + 1, 2, 1, light)


static func _ink(tile: Image, x: int, y: int, width: int, height: int, color: String) -> void:
	tile.fill_rect(Rect2i(x, y, width, height), Color(color))


static func _glazed_tile(tile: Image) -> void:
	tile.fill(Color("#d9d3ae"))
	for y in [0, 8]:
		for x in [0, 8]:
			var teal: bool = x == y
			_ink(tile, x + 1, y + 1, 7, 7, "#74aba2" if teal else "#f2e4c0")
			_ink(tile, x + 1, y + 1, 6, 1, "#a1c9b4" if teal else "#fff2d5")
			_ink(tile, x + 7, y + 2, 1, 6, "#64948e" if teal else "#dfc69f")
			_ink(tile, x + 4, y + 3, 1, 3, "#b9d3b7" if teal else "#d1af87")
			_ink(tile, x + 3, y + 4, 3, 1, "#b9d3b7" if teal else "#d1af87")


static func _boards(tile: Image, light: String, dark: String, seam: String) -> void:
	tile.fill(Color(light))
	_ink(tile, 0, 5, 16, 5, dark)
	for y in [0, 5, 10]:
		_ink(tile, 0, y, 16, 1, seam)
	_ink(tile, 11, 1, 1, 4, seam)
	_ink(tile, 4, 6, 1, 4, seam)
	_ink(tile, 8, 11, 1, 5, seam)
	_ink(tile, 2, 2, 4, 1, dark)
	_ink(tile, 11, 7, 4, 1, light)
	_ink(tile, 9, 13, 5, 1, dark)
	_ink(tile, 2, 14, 3, 1, dark)


static func _pavers(tile: Image, body: String, light: String, seam: String) -> void:
	tile.fill(Color(body))
	_ink(tile, 0, 0, 16, 1, seam)
	_ink(tile, 0, 8, 16, 1, seam)
	_ink(tile, 9, 1, 1, 7, seam)
	_ink(tile, 3, 9, 1, 7, seam)
	_ink(tile, 0, 1, 8, 1, light)
	_ink(tile, 10, 1, 6, 7, light)
	_ink(tile, 4, 9, 12, 1, light)
	_ink(tile, 2, 5, 2, 1, seam)
	_ink(tile, 7, 12, 3, 1, light)
	_ink(tile, 13, 14, 2, 1, seam)


static func _plaster(tile: Image, body: String, shade: String, light: String) -> void:
	tile.fill(Color(body))
	_ink(tile, 0, 0, 5, 1, light)
	_ink(tile, 5, 1, 2, 1, light)
	_ink(tile, 12, 3, 3, 1, shade)
	_ink(tile, 14, 4, 2, 1, shade)
	_ink(tile, 3, 7, 4, 1, shade)
	_ink(tile, 1, 10, 2, 1, light)
	_ink(tile, 9, 12, 4, 1, light)
	_ink(tile, 7, 15, 3, 1, shade)


static func _brick(tile: Image) -> void:
	tile.fill(Color("#d7b39a"))
	for y in [0, 4, 8, 12]:
		var offset: int = 4 if y % 8 == 4 else 0
		for x in [-8 + offset, offset, 8 + offset]:
			var left := maxi(0, x + 1)
			var right := mini(SIZE.x, x + 8)
			if left >= right:
				continue
			_ink(tile, left, y + 1, right - left, 3, "#bd7b68" if (x + y) % 16 == 0 else "#ca8c73")
			_ink(tile, left, y + 3, right - left, 1, "#ad715f")


static func _beams(tile: Image) -> void:
	_plaster(tile, "#edddaf", "#e3d2ab", "#f5e7c5")
	_ink(tile, 0, 0, 16, 1, "#b09a77")
	_ink(tile, 0, 1, 16, 3, "#9b6b53")
	_ink(tile, 0, 1, 16, 1, "#c69269")
	_ink(tile, 6, 2, 4, 1, "#b3825d")
	_ink(tile, 0, 4, 16, 1, "#d4bf97")


static func _panels(tile: Image) -> void:
	tile.fill(Color("#9da8a0"))
	for y in [0, 8]:
		for x in [0, 8]:
			_ink(tile, x + 1, y + 1, 7, 7, "#cbcfbb")
			_ink(tile, x + 2, y + 2, 5, 5, "#e9e4cc")
			_ink(tile, x + 2, y + 2, 5, 1, "#f5efdb")
			_ink(tile, x + 2, y + 6, 5, 1, "#d0c8ad")
