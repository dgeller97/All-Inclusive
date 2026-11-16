extends SceneTree
## Independent regression for the user's squashed/overlapping diner screenshot.
const Sim := preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0


class Probe extends "res://scripts/resort_map.gd":
	var regions: Array[Dictionary] = []
	func _actor_block(_at: Rect2, _color: Color) -> void:
		pass
	func _actor_region(destination: Rect2, source: Rect2) -> void:
		regions.append({"destination": destination, "source": source})
	func draw_guest(actor: Dictionary) -> Array[Dictionary]:
		regions.clear()
		_draw_actor(actor)
		return regions.duplicate(true)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := Probe.new()
	root.add_child(map)
	var atlas := map.people.get_image()
	for rotation in range(4):
		var sim := Sim.new()
		var table: Dictionary = sim.layout.dining_tables()[0]
		for turn in range(rotation):
			check(sim.layout.rotate_asset(table.id).ok, "Rotated table fixture remains usable")
		var family := {}
		for tick in range(180):
			sim.tick()
			for candidate: Dictionary in sim.families:
				if candidate.phase == "eating":
					family = candidate
					break
			if not family.is_empty():
				break
		check(not family.is_empty(), "A real family eats at table orientation " + str(rotation))
		if family.is_empty():
			continue
		for age in [0.0, 0.4, 0.9, 1.5, 5.0, 11.8]:
			map.present(sim, family.since + age, null, true)
			var pose: Dictionary = map._pose(family)
			var adult := map.draw_guest(map._guest_sprite(family, pose, false))
			var child := map.draw_guest(map._guest_sprite(family, pose, true))
			_check_native(adult, "adult diner")
			_check_native(child, "child diner")
			if not adult.is_empty() and not child.is_empty():
				var adult_head := _head_pixels(atlas, adult[0], 9)
				var child_head := _head_pixels(atlas, child[0], 8)
				check(not adult_head.is_empty() and not child_head.is_empty(), "Both native faces remain visible")
				check(not adult_head.keys().any(func(pixel: Vector2i) -> bool: return child_head.has(pixel)), "Diner head pixels do not merge at rotation %d and age %.1f" % [rotation, age])
		var saved := Sim.new()
		check(saved.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Eating phase remains save-compatible")
		map.present(sim, float(family.since), null, true)
		var eating: Dictionary = map._pose(family)
		var arriving: Dictionary = family.duplicate(true)
		arriving.phase = "to_table"
		arriving.since = family.since - Sim.TABLE_WALK_DURATION
		arriving.until = family.since
		var arrival: Dictionary = map._pose(arriving)
		var adult_seat: Vector2 = map._guest_sprite(family, eating, false).point
		var child_seat: Vector2 = map._guest_sprite(family, eating, true).point
		var table_bounds: Rect2 = sim.layout.asset_rect(sim.layout.asset_at(table.table_center))
		check(minf(adult_seat.x, child_seat.x) < table_bounds.position.x and maxf(adult_seat.x, child_seat.x) > table_bounds.end.x, "Open table aisles put diners on opposite sides with the table between them")
		check(table_bounds.has_point(eating.adult_plate) and table_bounds.has_point(eating.child_plate), "Opposite diners keep both plates on the actual tabletop")
		check(map._guest_sprite(arriving, arrival, false).point.distance_to(adult_seat) < 0.01 and map._guest_sprite(arriving, arrival, true).point.distance_to(child_seat) < 0.01, "Arrival ends at the displayed seats without a position snap")
		var leaving: Dictionary = family.duplicate(true)
		leaving.phase = "to_pool"
		leaving.since = family.until
		leaving.until = family.until + 8
		map.time = family.until
		var departure: Dictionary = map._pose(leaving)
		check(map._guest_sprite(leaving, departure, false).point.distance_to(adult_seat) < 0.01 and map._guest_sprite(leaving, departure, true).point.distance_to(child_seat) < 0.01, "Departure starts at the displayed seats without a position snap")
	_test_tight_layout()
	for kind: String in ["stage", "beach_lounge", "relax", "supervise", "cafe_sit", "slide"]:
		for row in [0, 1, 2, 4]:
			for facing in [true, false]:
				var actor := {"point": Vector2(200, 200), "row": row, "frame": 0, "facing": facing,
					"swim": false, "leisure_age": 3.0, "leisure_slot": 0, "facility_target": Vector2(205, 195),
					"leisure": kind if kind in ["stage", "beach_lounge"] else "",
					"facility_action": "" if kind in ["stage", "beach_lounge"] else kind}
				_check_native(map.draw_guest(actor), "shared seated pose " + kind)
	map.queue_free()
	await process_frame
	print("Seated proportions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_tight_layout() -> void:
	var sim := Sim.new()
	var table: Dictionary = sim.layout.dining_tables()[0]
	for cell in [Vector2i(8, 3), Vector2i(8, 4), Vector2i(11, 3), Vector2i(11, 4), Vector2i(9, 2), Vector2i(10, 2)]:
		check(sim.layout.add_asset("plant", table.building_id, cell).ok, "Prepare cramped existing restaurant layout")
	check(sim.layout.dining_tables().size() == 1 and sim.layout.readiness().ok, "A table with only one open edge retains usable fallback seating")
	var observed := false
	for tick in range(239):
		sim.tick()
		if not observed and sim.families.any(func(f: Dictionary) -> bool: return f.phase == "eating"):
			observed = true
			var loaded := Sim.new()
			check(loaded.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Tight-layout active meal remains save-compatible")
	check(observed and sim.reviews.size() == 4, "Guests still complete meals and stays in a tight fallback layout")


func _check_native(regions: Array[Dictionary], label: String) -> void:
	check(not regions.is_empty(), label + " draws its character")
	for region: Dictionary in regions:
		var source: Rect2 = region.source
		var destination: Rect2 = region.destination
		check(source.size.is_equal_approx(destination.size.abs()), label + " preserves native pixel proportions")
		check(source.size.x >= 8 and source.size.y >= 8, label + " retains a readable head and torso")


func _head_pixels(atlas: Image, region: Dictionary, rows: int) -> Dictionary:
	var result := {}
	var source: Rect2 = region.source
	var destination: Rect2 = region.destination
	if source.size != destination.size.abs():
		return result
	var start := Vector2i(destination.position)
	for y in range(mini(rows, int(source.size.y))):
		for x in range(int(source.size.x)):
			if atlas.get_pixelv(Vector2i(source.position) + Vector2i(x, y)).a > 0.0:
				var pixel_x := int(source.size.x) - 1 - x if destination.size.x < 0 else x
				result[start + Vector2i(pixel_x, y)] = true
	return result


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
