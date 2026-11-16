extends SceneTree
const Preview := preload("res://scripts/animation_preview.gd")
const Probe := preload("res://tools/coast_rescue_preview.gd")
const Sim := preload("res://scripts/simulation.gd")
const Art := preload("res://scripts/lifeguard_art.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for fixture in Preview.build_panels("main_pool"):
		var sim: Sim = fixture.sim
		sim.mode = "developer"
		check(sim.hire_lifeguard("pool"), "Hire at rotated pool")
		var map := Probe.MapProbe.new()
		root.add_child(map)
		map.atlas = map.people.get_image()
		map.present(sim, 0)
		var idle := map._depth_plan()
		check(idle.filter(func(item: Dictionary) -> bool: return item.kind == "lifeguard" and item.seated).size() == 1,
			"Exactly one seated guard at rotated post")
		check(sim.start_rescue_drill(), "Start rotated pool rescue")
		for age in [0.0, 0.8, 1.5, 2.0, 3.5, 4.7, 5.5]:
			var before := sim.snapshot()
			map.present(sim, age)
			map._draw_actors()
			var positions := sim.rescue_positions(age)
			var plan := map._depth_plan()
			var guards := plan.filter(func(item: Dictionary) -> bool: return item.kind == "lifeguard")
			var victims := plan.filter(func(item: Dictionary) -> bool: return item.tag == "rescue_volunteer")
			check(guards.size() == 1 and victims.size() == 1 and guards[0].point == positions.guard
				and victims[0].actor.point == positions.victim, "Production draw uses physical rescue contacts")
			check(guards[0].swim == positions.guard_swim and victims[0].actor.swim == positions.victim_swim,
				"Water clips match rotated geometry")
			check(plan.any(func(item: Dictionary) -> bool: return item.tag == "rescue_float"), "Visible rescue float")
			check(sim.snapshot() == before, "Drawing/interpolation does not mutate save state")
		map.queue_free()
		await process_frame
	var sim := Sim.new()
	var ocean := Probe.Water.Probe.new()
	root.add_child(ocean)
	ocean.set_landscape(sim.layout.landscape)
	ocean.present_field([], [{"row": 156, "amount": 38}])
	var pixels := ocean.deposited_pixels()
	check(not pixels.is_empty(), "An arriving patch produces visible localized buildup")
	check(pixels.all(func(p: Vector2i) -> bool: return absi(p.y - 156) <= 20), "Piles stay near their actual landing row")
	ocean.present_field([], [])
	check(ocean.deposited_pixels().is_empty(), "Cleaned ledger removes the pile")
	var small := ocean.sargassum_patch_image(0, Vector2i(8, 5))
	var large := ocean.sargassum_patch_image(0, Vector2i(49, 25))
	check(large.get_used_rect().size.x > small.get_used_rect().size.x * 3, "Raft size changes native pixel silhouettes")
	ocean.queue_free()
	await process_frame
	print("Coast rescue visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
