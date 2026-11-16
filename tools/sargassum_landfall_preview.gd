extends SceneTree
const Sim := preload("res://scripts/simulation.gd")
const Water := preload("res://tools/ocean_season_preview.gd")
const Terrain := preload("res://assets/art/resort.png")
const WORLD := Rect2i(Sim.Layout.WORLD_BOUNDS)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var sim := Sim.new()
	sim.mode = "developer"
	sim.set_developer_sargassum_intensity(0)
	assert(sim.seed_sargassum_arrival())
	var raft: Dictionary = sim._offshore.filter(func(p: Dictionary) -> bool: return p.id % 16 == Sim.Sargassum.FORCED_LANE)[0]
	var water := Water.Probe.new()
	root.add_child(water)
	water.set_landscape(sim.layout.landscape)
	water.set_swim_access(sim.layout.ocean_access())
	var sheet := Image.create(1760, 640, false, Image.FORMAT_RGBA8)
	var samples := [0, raft.lands_at / 2, raft.lands_at - 1, raft.lands_at + 1]
	for index in samples.size():
		while sim.second < samples[index]:
			sim.tick()
		water.picture = Terrain.get_image().duplicate()
		water.picture.convert(Image.FORMAT_RGBA8)
		water.present_field(sim.floating_sargassum(), sim.beach_deposits)
		water.present(sim.second, sim.sargassum, sim.surf_condition())
		water._draw()
		var crop := water.picture.get_region(Rect2i(Vector2i(360, raft.row - 80) - WORLD.position, Vector2i(440, 160)))
		crop.resize(880, 320, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(index % 2 * 880, index / 2 * 320))
	sheet.save_png("res://.tools/r18-landfall.png")
	sim.set_developer_month(7)
	sim.set_developer_sargassum_intensity(100)
	while sim.second < 210:
		sim.tick()
	water.picture = Terrain.get_image().duplicate()
	water.picture.convert(Image.FORMAT_RGBA8)
	water.present_field(sim.floating_sargassum(), sim.beach_deposits)
	water.present(sim.second, sim.sargassum, sim.surf_condition())
	water._draw()
	var overview := water.picture.get_region(Rect2i(Vector2i(360, -40) - WORLD.position, Vector2i(440, 320)))
	overview.resize(880, 640, Image.INTERPOLATE_NEAREST)
	overview.save_png("res://.tools/r18-variable-patches.png")
	water.queue_free()
	await process_frame
	print("Actual ledger landfall preview; tracked raft mass %d at world row %d; July variable sizes and localized piles" % [raft.mass, raft.row])
	quit()
