extends SceneTree

const Depth := preload("res://scripts/furniture_depth.gd")
var checks := 0

func _initialize() -> void:
	for row in Depth.KINDS.size():
		for turn in 4:
			var data := Depth.data(Depth.KINDS[row], turn)
			var restored: Image = data.base_image.duplicate()
			for layer in data.layers:
				assert(is_finite(layer.depth))
				var pixels: Image = layer.image
				restored.blend_rect(pixels, Rect2i(Vector2i.ZERO, pixels.get_size()), Vector2i(layer.offset) + Vector2i(0, 6))
			var original := Depth.ATLAS.get_image().get_region(Rect2i(Vector2i(turn, row) * 40, restored.get_size()))
			original.convert(Image.FORMAT_RGBA8)
			assert(original.get_data() == restored.get_data(), "Depth pieces preserve original atlas pixels: %s/%d" % [Depth.KINDS[row], turn])
			assert(data.layers.size() > 0)
			checks += 1
	print("Furniture depth: %d/32 rotations reproduce original atlas pixels" % checks)
	quit()
