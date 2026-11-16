extends SceneTree
## Uses the actual world depth dispatch and ocean draw commands, composited on CPU.
const Sim := preload("res://scripts/simulation.gd")
const Dining := preload("res://tests/dining_visual_test.gd")
const Buildings := preload("res://tests/building_renderer_test.gd")
const Water := preload("res://tools/ocean_season_preview.gd")
const TERRAIN := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Sim.Layout.WORLD_BOUNDS)

class MapProbe extends Dining.ActorProbe:
	func _draw_depth_item(item: Dictionary) -> void:
		if item.kind == "asset":
			if picture and item.has("image"):
				var ink: Image = item.image
				picture.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i(item.position) - WORLD.position)
		else:
			super._draw_depth_item(item)

class Base extends Buildings.Probe:
	func _draw_asset(asset: Dictionary) -> void:
		var bounds := _as_rect(asset.rect)
		var ink: Image = FurnitureDepth.data(asset.kind, int(asset.get("rotation", 0))).base_image
		picture.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), bounds.position - Vector2i(FURNITURE_LIFT) - WORLD.position)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sheet := Image.create(1440, 560, false, Image.FORMAT_RGBA8)
	var phases := [-1.0, 1.2, 2.0, 3.5, 4.7, 5.5]
	for row in 2:
		var sim := Sim.new()
		sim.mode = "developer"
		var site := "beach" if row == 0 else "pool"
		assert(sim.hire_lifeguard(site))
		var post := sim.lifeguard_post(site)
		var map := MapProbe.new()
		root.add_child(map)
		map.atlas = map.people.get_image()
		var water := Water.Probe.new()
		root.add_child(water)
		water.set_landscape(sim.layout.landscape)
		water.set_swim_access(sim.layout.ocean_access())
		for column in phases.size():
			if column == 1:
				assert(sim.start_rescue_drill())
			var clock: float = maxf(0.0, phases[column])
			map.present(sim, clock)
			var picture: Image = TERRAIN.get_image().duplicate()
			picture.convert(Image.FORMAT_RGBA8)
			water.picture = picture
			water.present_field(sim.floating_sargassum(clock), sim.beach_deposits)
			water.present(clock)
			water._draw()
			var base := Base.new()
			base.picture = picture
			base.present(map.renderer._buildings, map.renderer._assets)
			base.set_interleave(true)
			base._draw()
			map.picture = picture
			map._draw_actors()
			var center: Vector2 = post.entry + Vector2(14, -10)
			var crop: Image = picture.get_region(Rect2i(Vector2i(center) - Vector2i(60, 70) - WORLD.position, Vector2i(120, 140)))
			crop.resize(240, 280, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(column * 240, row * 280))
			base.free()
		map.queue_free()
		water.queue_free()
		await process_frame
	sheet.save_png("res://.tools/r18-rescue-preview.png")
	print("Rescue preview: beach / pool; seated, outbound, contact, tow, shore, returning; production draw commands")
	quit()
