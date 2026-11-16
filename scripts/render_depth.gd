extends RefCounted
## Cached transparent pieces authored in ground space. Their image offsets
## describe pixels; their depth describes the projection of the contact point.

static func piece(image: Image, depth: float, tag: String) -> Dictionary:
	var used := image.get_used_rect()
	if not used.has_area():
		return {}
	var cropped := image.get_region(used)
	return {
		"image": cropped, "offset": Vector2(used.position), "size": Vector2(used.size),
		"texture": ImageTexture.create_from_image(cropped), "depth": depth, "tag": tag,
	}


static func order(items: Array[Dictionary]) -> void:
	for index in items.size():
		items[index].order = index
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.depth) == float(b.depth):
			return int(a.order) < int(b.order)
		return float(a.depth) < float(b.depth))
