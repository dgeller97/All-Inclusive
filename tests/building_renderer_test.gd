extends SceneTree

const Layout := preload("res://scripts/layout_model.gd")
const Renderer := preload("res://scripts/building_renderer.gd")
const TERRAIN := preload("res://assets/art/resort.png")
const WORLD := Rect2i(-160, -120, 960, 600)
const PREVIEW_CROP := Rect2i(8, 26, 465, 228)

var checks := 0
var failures := 0


class Probe extends "res://scripts/building_renderer.gd":
	var boxes: Array[Rect2i] = []
	var assets_drawn: Array[int] = []
	var finishes_drawn: Array[String] = []
	var labels_drawn: Array[String] = []
	var picture: Image
	var furniture := FURNITURE.get_image()
	var terrace_water := Rect2i()

	func _block(x: int, y: int, width: int, height: int, color: Color) -> void:
		var bounds := Rect2i(x, y, width, height)
		boxes.append(bounds)
		if not picture or not bounds.has_area():
			return
		var target := Rect2i(bounds.position - WORLD.position, bounds.size)
		if color.a == 1.0:
			picture.fill_rect(target, color)
		else:
			var patch := Image.create(width, height, false, Image.FORMAT_RGBA8)
			patch.fill(color)
			picture.blend_rect(patch, Rect2i(Vector2i.ZERO, bounds.size), target.position)

	func _draw_asset(asset: Dictionary) -> void:
		assets_drawn.append(asset.id)
		if picture:
			var bounds := _as_rect(asset.rect)
			picture.blend_rect(furniture, Rect2i(_asset_source(asset, bounds.size)), bounds.position - WORLD.position)

	func _draw_pool(bounds: Rect2i, upgraded: bool) -> void:
		terrace_water = _water_rect(bounds)
		super(bounds, upgraded)

	func _draw_plaque_text(font: Font, at: Vector2, label: String) -> void:
		labels_drawn.append(label)
		if not picture or not font is FontFile:
			return
		var file := font as FontFile
		var x := at.x
		for letter in label:
			var id := file.get_glyph_index(SIGN_FONT_SIZE, letter.unicode_at(0), 0)
			var metrics := Vector2i(SIGN_FONT_SIZE, 0)
			var texture_index := file.get_glyph_texture_idx(0, metrics, id)
			var glyph := Rect2i(file.get_glyph_uv_rect(0, metrics, id))
			var image := file.get_texture_image(0, metrics, texture_index) if texture_index >= 0 else null
			var offset := file.get_glyph_offset(0, metrics, id)
			if image and glyph.has_area():
				for row in glyph.size.y:
					for col in glyph.size.x:
						var weight := image.get_pixelv(glyph.position + Vector2i(col, row)).a
						if weight > 0.0:
							var pixel := Vector2i(Vector2(x, at.y) + offset) + Vector2i(col, row) - WORLD.position
							picture.set_pixelv(pixel, picture.get_pixelv(pixel).lerp(IVORY, weight))
			x += file.get_glyph_advance(0, SIGN_FONT_SIZE, id).x

	func _surface(bounds: Rect2i, surface: String, finish: String, tint: Color = Color.WHITE) -> void:
		boxes.append(bounds)
		finishes_drawn.append(surface + "/" + finish)
		if not picture:
			return
		var tile := finish_preview(surface, finish).get_image()
		if not tile:
			return
		for y in bounds.size.y:
			for x in bounds.size.x:
				var pixel := tile.get_pixel(x % tile.get_width(), y % tile.get_height()) * tint
				picture.set_pixelv(bounds.position + Vector2i(x, y) - WORLD.position, pixel)

	func clear_marks() -> void:
		boxes.clear()
		labels_drawn.clear()
		finishes_drawn.clear()
		assets_drawn.clear()

	func bounded(limit: Rect2i) -> bool:
		return not boxes.is_empty() and boxes.all(func(box: Rect2i) -> bool: return box.has_area() and limit.encloses(box))


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr(description)


func _run() -> void:
	var model := Layout.new()
	var probe := Probe.new()
	var rooms := model.buildings.filter(func(building: Dictionary) -> bool: return building.kind == "bedroom")
	var lobby: Dictionary = model.buildings[4]
	var restaurant: Dictionary = model.buildings[5]
	var pool: Dictionary = model.buildings[6]
	var outdoor := model.add_asset("lounger", pool.id, Vector2i(1, 2))
	_check(outdoor.ok, "Pool test fixture")

	for surface: String in Layout.FINISH_CATALOG:
		var distinct_pixels := {}
		for choice: String in Layout.FINISH_CATALOG[surface]:
			var swatch := Renderer.finish_preview(surface, choice)
			_check(swatch != null and swatch.get_size() == Vector2(16, 16), "%s/%s preview exists" % [surface, choice])
			_check(swatch == Renderer.finish_preview(surface, choice), "%s/%s preview is cached" % [surface, choice])
			if swatch and swatch.get_image():
				distinct_pixels[swatch.get_image().get_data().hex_encode()] = true
		_check(distinct_pixels.size() == Layout.FINISH_CATALOG[surface].size(), "%s has distinct swatches" % surface)
	_check(Renderer.finish_preview("ceiling", "missing") == null, "Unknown finish has no swatch")

	for kind: String in Layout.BUILDING_CATALOG:
		var size: Array = Layout.BUILDING_CATALOG[kind].min_size
		var long_name := "WWWWWWWWWWWWWWWWWWWWWWWW"
		var footprint := Rect2i(-112, 0, size[0] * Renderer.GRID, size[1] * Renderer.GRID)
		var building := {"id": 120, "kind": kind, "rect": footprint, "display_name": long_name, "finishes": {"floor": "tile", "wall": "brick", "ceiling": "beams"}}
		for overhang in [false, true]:
			if not overhang:
				footprint.position.y = int(Layout.WORLD_BOUNDS.position.y)
			else:
				footprint.position.y = 0
			building.rect = footprint
			probe.present([building], [])
			var covered := footprint
			if kind != "pool" and overhang:
				covered.position.y -= Renderer.GRID
				covered.size.y += Renderer.GRID
			for exterior in [false, true]:
				probe.set_view(exterior)
				probe.clear_marks()
				probe._draw()
				_check(probe.bounded(covered), "%s geometry fits the footprint in exterior=%s with overhang=%s" % [kind, exterior, overhang])
				var label := probe.labels_drawn[0]
				_check(label.ends_with("…") and Renderer._plaque_text_width(ThemeDB.fallback_font, label) <= footprint.size.x - 18, "Long %s name fits its plaque" % kind)
			var max_overlap := footprint
			max_overlap.position.y -= max_overlap.size.y
			if overhang:
				probe.present([building, {"id": 119, "kind": "bedroom", "rect": max_overlap}], [])
				_check(probe._roof_overhang(footprint) == 0, "Roof tucks beside an abutting building")

	var terrain := TERRAIN.get_image()
	terrain.convert(Image.FORMAT_RGBA8)
	var export_preview := "--preview" in OS.get_cmdline_user_args()
	var contact_sheet := Image.create(PREVIEW_CROP.size.x, PREVIEW_CROP.size.y * 3, false, Image.FORMAT_RGBA8)
	model.set_building_name(rooms[0].id, "WWWWWWWWWWWWWWWWWWWWWWWW")
	model.set_building_finish(rooms[1].id, "floor", "tile")
	model.set_building_finish(rooms[1].id, "wall", "timber")
	model.set_building_finish(rooms[2].id, "floor", "wood")
	model.set_building_finish(rooms[3].id, "floor", "stone")
	model.set_building_finish(lobby.id, "wall", "plaster")
	model.set_building_finish(restaurant.id, "wall", "brick")
	model.set_building_finish(restaurant.id, "ceiling", "panels")
	probe.present(model.buildings, model.render_assets(), 1.0)
	var pool_images: Array[PackedByteArray] = []
	for row in [0, 1, 2]:
		probe.set_view(row == 1, restaurant.id if row == 2 else -1)
		probe.clear_marks()
		probe.picture = terrain.duplicate()
		probe._draw()
		var pool_bounds := Renderer._as_rect(pool.rect)
		var section := Rect2i(pool_bounds.position - WORLD.position, pool_bounds.size)
		pool_images.append(probe.picture.get_region(section).get_data())
		_check(not probe.is_interior_hidden(Vector2(pool_bounds.get_center())), "Pool occupants remain visible in view %s" % row)
		_check(probe.is_interior_hidden(Vector2(Renderer._as_rect(lobby.rect).get_center())) == (row == 1), "Lobby occupants follow the global view")
		_check(probe.is_interior_hidden(Vector2(Renderer._as_rect(restaurant.rect).get_center())) == (row > 0), "Restaurant occupants follow the global and ceiling views")
		_check(probe.is_interior_hidden(model.door_point(restaurant) + Vector2(0, 8)) == false, "Outdoor guests remain visible")
		_check(probe.assets_drawn.size() == [8, 1, 6][row], "Indoor furniture filter in view %s" % row)
		_check(probe.finishes_drawn.has("floor/tile") == (row != 1), "Interior floor shows only in cutaway")
		_check(probe.finishes_drawn.has("ceiling/panels") == (row == 2), "Ceiling preview shows only while inspecting")
		_check(probe.finishes_drawn.has("wall/brick"), "Brick shows on the interior wall and exterior facade")
		_check(probe.labels_drawn.has("Lobby") and probe.labels_drawn.has("Restaurant"), "Full starter station names fit")
		if export_preview:
			var preview_section := Rect2i(PREVIEW_CROP.position - WORLD.position, PREVIEW_CROP.size)
			contact_sheet.blit_rect(probe.picture, preview_section, Vector2i(0, row * PREVIEW_CROP.size.y))
	_check(pool_images[0] == pool_images[1] and pool_images[1] == pool_images[2], "Pool pixels remain identical in all views")
	_check(probe.terrace_water == Rect2i(model.water_rect(pool)), "Pool water bounds remain unchanged")
	probe.free()

	var renderer := Renderer.new()
	root.add_child(renderer)
	renderer.present(model.buildings, model.render_assets(), 2.0)
	await process_frame
	renderer.set_view(true)
	await process_frame
	renderer.set_view(false, restaurant.id)
	await process_frame
	if export_preview:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools"))
		_check(contact_sheet.save_png("res://.tools/r5-building-art-preview.png") == OK, "CPU preview saved")
	print("Building appearance probe: %s/%s checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
