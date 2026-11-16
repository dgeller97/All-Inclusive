extends SceneTree
## CPU reconstruction of production water/patch draw commands, no desktop capture.
const Ocean := preload("res://scripts/ocean.gd")
const Layout := preload("res://scripts/layout_model.gd")
const Terrain := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Layout.WORLD_BOUNDS)

class Probe extends Ocean:
	var picture: Image
	func _water_block(rect: Rect2, color: Color) -> void:
		if not picture:
			return
		var ink := Image.create(int(rect.size.x), int(rect.size.y), false, Image.FORMAT_RGBA8)
		ink.fill(color)
		picture.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i(rect.position) - WORLD.position)
	func _draw_patch_row(_texture: Texture2D, image: Image, source: Rect2, at: Vector2, opacity: float) -> void:
		if not picture:
			return
		var ink := image.get_region(Rect2i(source))
		for x in ink.get_width():
			var color := ink.get_pixel(x, 0)
			color.a *= opacity
			ink.set_pixel(x, 0, color)
		picture.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i(at) - WORLD.position)
	func _draw_flags() -> void:
		pass
	func _draw_sargassum() -> void:
		if picture:
			var pixels := deposited_pixels() if _field_active else sargassum_pixels(_sargassum)
			for point in pixels:
				picture.set_pixelv(point - WORLD.position, SEAWEED[(point.x + point.y * point.y) & 3])

func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ocean := Probe.new()
	root.add_child(ocean)
	var layout := Layout.new()
	ocean.set_landscape(layout.landscape)
	ocean.set_swim_access(layout.ocean_access())
	var terrain := Terrain.get_image()
	terrain.convert(Image.FORMAT_RGBA8)
	var times := [0.0, 48.0, 3060.0, 5880.0]
	var sheet := Image.create(1760, 960, false, Image.FORMAT_RGBA8)
	for index in times.size():
		ocean.present(times[index], [0, 1, 80, 5][index])
		ocean.picture = terrain.duplicate()
		ocean._draw()
		var crop := ocean.picture.get_region(Rect2i(Vector2i(360, 30) - WORLD.position, Vector2i(440, 240)))
		crop.resize(880, 480, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(index % 2 * 880, index / 2 * 480))
	sheet.save_png("res://.tools/r17-season-preview.png")
	ocean.queue_free()
	await process_frame
	print("Ocean preview: March 0s / March 48s / July peak / November; production command reconstruction")
	quit()
