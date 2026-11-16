extends SceneTree
## Seasonal field and swim-boundary contracts through production time, poses, and draw dispatch.

const Ocean := preload("res://scripts/ocean.gd")
const Calendar := preload("res://scripts/resort_calendar.gd")
const Landscape := preload("res://scripts/landscape_model.gd")
const Layout := preload("res://scripts/layout_model.gd")
const ResortMap := preload("res://scripts/resort_map.gd")
const Sim := preload("res://scripts/simulation.gd")
const MONTH_LENGTH := Calendar.DAYS_PER_MONTH * Calendar.DAY_LENGTH
const NOVEMBER := 8 * MONTH_LENGTH
const NEXT_MARCH := 12 * MONTH_LENGTH
const WORLD := Landscape.WORLD_BOUNDS


class OceanDrawProbe extends Ocean:
	var patch_rows: Array[Dictionary] = []
	var buoy_runs := 0
	var in_buoys := false

	func _draw_patch_row(texture: Texture2D, image: Image, source: Rect2, at: Vector2, opacity: float) -> void:
		patch_rows.append({"image": image, "source": Rect2i(source), "at": Vector2i(at), "opacity": opacity,
			"texture_size": Vector2i(texture.get_size())})
		super._draw_patch_row(texture, image, source, at, opacity)

	func _draw_swim_buoys() -> void:
		in_buoys = true
		super._draw_swim_buoys()
		in_buoys = false

	func _draw_water_run(x: int, y: int, width: int, color: Color) -> void:
		if in_buoys:
			buoy_runs += 1
		super._draw_water_run(x, y, width, color)


var checks := 0
var failures := 0
var season_samples := 0
var wade_points := 0
var submitted_pixels := 0
var shore: PackedInt32Array


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sim := Sim.new()
	var map := ResortMap.new()
	root.add_child(map)
	map.present(sim, 0.0)
	shore = Landscape.coastline()
	_check_season(map.ocean)
	_check_pause_load_cleanup(map, sim)
	_check_swim_zone(map, sim)
	await _check_draw_dispatch(sim.layout)
	map.queue_free()
	await process_frame
	print("Ocean season: %d checks, %d failures, %d seasonal samples, %d wet pose points, %d opaque/translucent patch pixels submitted" %
		[checks, failures, season_samples, wade_points, submitted_pixels])
	quit(1 if failures else 0)


func _check_season(ocean: Ocean) -> void:
	var first := ocean.floating_sargassum(0.0)
	_check(not first.is_empty() and first.any(func(raft: Dictionary) -> bool: return raft.opacity >= 0.2),
		"March opens with a visible offshore arrival")
	_check(first.all(func(raft: Dictionary) -> bool:
		return raft.progress == 0.0 and _relative_depth(raft.point) >= 0.65), "Opening rafts originate in deep water")
	var early := ocean.floating_sargassum(8.0)
	var later := _by_id(ocean.floating_sargassum(48.0))
	var nearing := _by_id(ocean.floating_sargassum(68.0))
	var tracked := 0
	var travel_is_inward := true
	for raft in early:
		if not later.has(raft.id) or not nearing.has(raft.id):
			continue
		tracked += 1
		var middle: Dictionary = later[raft.id]
		var last: Dictionary = nearing[raft.id]
		travel_is_inward = travel_is_inward and raft.progress < middle.progress and middle.progress < last.progress \
			and _relative_depth(raft.point) - _relative_depth(middle.point) > 0.2 \
			and _relative_depth(middle.point) - _relative_depth(last.point) > 0.05
	_check(tracked >= 2 and travel_is_inward, "Identified March rafts progress steadily toward the beach")

	var month_totals: Array[int] = []
	month_totals.resize(8)
	var covered_rows := {}
	var valid_time_series := true
	for elapsed in range(0, NOVEMBER, 17):
		season_samples += 1
		var rafts := ocean.floating_sargassum(float(elapsed))
		var ids := _by_id(rafts)
		month_totals[elapsed / MONTH_LENGTH] += rafts.size()
		valid_time_series = valid_time_series and not rafts.is_empty() and ids.size() == rafts.size()
		for raft in rafts:
			var point: Vector2 = raft.point
			valid_time_series = valid_time_series and WORLD.has_point(point) and point.x >= _coast_at(point.y) \
				and raft.progress >= 0.0 and raft.progress < 1.0 and raft.opacity > 0.0 and raft.opacity <= 1.0
			if raft.progress < 0.15 and _relative_depth(point) >= 0.65:
				covered_rows[floori((point.y - WORLD.position.y) * 8.0 / WORLD.size.y)] = true
	_check(valid_time_series, "Every sampled March–October clock contains distinct, visible, wet floating rafts")
	_check(covered_rows.size() == 8, "Deep arrivals span the full expanded ocean, including northern and southern rows")
	_check(month_totals[4] > month_totals[0] * 1.2 and month_totals[4] > month_totals[7] * 1.2,
		"Summer pressure yields more rafts than March or October")

	var before_november := _by_id(ocean.floating_sargassum(NOVEMBER - 0.01))
	var winter_remnants := 0
	var only_remnants := true
	for delay: float in [0.0, 20.0, 50.0, 80.0]:
		for raft in ocean.floating_sargassum(NOVEMBER + delay):
			winter_remnants += 1
			only_remnants = only_remnants and before_november.has(raft.id)
			if before_november.has(raft.id):
				only_remnants = only_remnants and raft.progress > before_november[raft.id].progress
	_check(winter_remnants > 0 and only_remnants, "November completes October's drift without spawning winter arrivals")
	for elapsed: float in [NOVEMBER + 110.0, NOVEMBER + MONTH_LENGTH * 0.5, NOVEMBER + 2.0 * MONTH_LENGTH, NEXT_MARCH - 0.01]:
		_check(ocean.floating_sargassum(elapsed).is_empty(), "Offshore field drains during November–February at %.2f s" % elapsed)
	var next_year := ocean.floating_sargassum(NEXT_MARCH)
	_check(not next_year.is_empty() and not first.is_empty() and next_year.front().id != first.front().id \
		and next_year.front().progress == 0.0 and _relative_depth(next_year.front().point) >= 0.65,
		"Next March starts a new set of deep-water arrivals")


func _check_pause_load_cleanup(map: ResortMap, sim: Sim) -> void:
	var summer_day := 4 * Calendar.DAYS_PER_MONTH + 1
	while sim.day < summer_day or sim.second < 95:
		if sim.stopped:
			sim.continue_after_recap()
		else:
			sim.tick()
	map.present(sim, float(sim.second))
	var visible := map.ocean.floating_sargassum()
	_check(sim.calendar_state().month == 7 and not visible.is_empty() and sim.sargassum >= 60,
		"A real summer run has offshore arrivals and independently accumulated beach litter")
	map.present(sim, float(sim.second))
	var seek := map.ocean.floating_sargassum(float((sim.day - 1) * Sim.DAY_LENGTH + sim.second - 42))
	_check(seek != visible and map.ocean.floating_sargassum() == visible, "A paused clock is stable and seeking records leaves it unchanged")
	var restored := Sim.new()
	_check(restored.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Game save restores the sampled July clock")
	var restored_map := ResortMap.new()
	root.add_child(restored_map)
	restored_map.present(restored, float(restored.second))
	_check(restored_map.ocean.floating_sargassum() == visible, "Fresh loaded world reconstructs exact raft IDs, positions and opacity")
	restored_map.queue_free()
	var shore_before := map.ocean.sargassum_pixels(sim.sargassum)
	var buoys_before := map.ocean.swim_buoy_points()
	var cleaned := sim.clean_beach()
	map.present(sim, float(sim.second))
	_check(cleaned.ok and cleaned.removed > 0 and map.ocean.sargassum_pixels(sim.sargassum).size() < shore_before.size(),
		"Actual paid beach cleaning removes deposited pixels")
	_check(map.ocean.floating_sargassum() == visible, "Beach cleaning leaves all offshore patches unchanged at the same time")
	_check(not buoys_before.is_empty() and map.ocean.swim_buoy_points() == buoys_before, "Beach cleaning also leaves the swim markers in place")


func _check_swim_zone(map: ResortMap, sim: Sim) -> void:
	var initial := sim.layout.ocean_access()
	var boundary := map.ocean.swim_buoy_points()
	_check(not initial.is_empty() and map.ocean_access == initial, "Live map uses the resort's reachable swim access")
	_check_zone_geometry(map, initial, "starter")
	var colors := {}
	for weather: int in [Ocean.Condition.CALM, Ocean.Condition.CAUTION, Ocean.Condition.CLOSED]:
		map.ocean.present(56.0, sim.sargassum, weather)
		colors[map.ocean.condition_color()] = true
		_check(map.ocean.swim_buoy_points() == boundary, "Surf flag %s leaves the marker outline stable" % map.ocean.condition_name())
	_check(colors.size() == 3 and sim.set_swim_policy("closed"), "Safety flag's three colors and swimming closure remain separate")
	map.present(sim, float(sim.second))
	_check(map.ocean.swim_buoy_points() == boundary and sim.swim_policy == "closed", "Markers remain present with the actual closed swimming policy")

	if initial.is_empty():
		return
	var shifted: Layout = sim.layout.duplicate_layout()
	var cell := Vector2i((initial.shore as Vector2) / Landscape.GRID)
	shifted.paint_landscape_stroke("path", "", [cell])
	var obstacle := shifted.add_prop("rock", cell)
	var new_access := shifted.ocean_access()
	_check(obstacle.ok and not new_access.is_empty() and new_access != initial, "Blocking the original access chooses a different reachable shore")
	if obstacle.ok and not new_access.is_empty() and new_access != initial:
		sim.layout = shifted
		map.present(sim, float(sim.second))
		_check(map.ocean_access == new_access and map.ocean.swim_buoy_points() != boundary, "Runtime map moves the outline to the new access")
		_check_zone_geometry(map, new_access, "shifted")
	var old_field := map.ocean.floating_sargassum()
	map.ocean.set_swim_access({})
	_check(map.ocean.swim_buoy_points().is_empty() and map.ocean.floating_sargassum() == old_field,
		"No swim access removes the boundary while leaving offshore drift in place")


func _check_zone_geometry(map: ResortMap, access: Dictionary, label: String) -> void:
	var buoys := map.ocean.swim_buoy_points()
	_check(buoys.size() >= 6, "The %s access has visible markers along three sides" % label)
	if buoys.size() < 6 or access.is_empty():
		return
	var first := buoys[0]
	var last := buoys[-1]
	var edge := first.x
	var all_wet := true
	var chain := true
	for i in buoys.size():
		var point := buoys[i]
		edge = maxf(edge, point.x)
		all_wet = all_wet and WORLD.has_point(point) and map.visible_layout.landscape.is_water_pixel(point)
		if i > 0:
			chain = chain and point.distance_to(buoys[i - 1]) <= 25.0 and point.y >= buoys[i - 1].y and point != buoys[i - 1]
	var is_u := chain and absf(first.x - _coast_at(first.y)) <= 20.0 and absf(last.x - _coast_at(last.y)) <= 20.0
	for point in buoys:
		is_u = is_u and (point.y == first.y or point.y == last.y or point.x == edge)
	_check(all_wet and is_u and first.y < access.shore.y and access.shore.y < last.y,
		"The %s markers make an open-to-shore U entirely on water" % label)
	# Complete the U with the physical shoreline. A straight connector between
	# the tips would exclude the shallows where guests enter the water.
	var swim_area := buoys.duplicate()
	for row in range(int(last.y), int(first.y) - 1, -1):
		swim_area.append(Vector2(_coast_at(row) - 0.5, row))
	for lane in 4:
		var travel := {"id": lane, "room": lane, "since": 0, "phase": "ocean_swim",
			"ocean_red_seconds": 0, "ocean_return_wet": true, "ocean_fatality": false}
		var wet_points_in_zone := true
		var has_sprite_room := true
		var adult_wet := 0
		var child_wet := 0
		var inverse_path := true
		for step in range(11):
			var progress := step / 10.0
			map.time = progress * Sim.OCEAN_WADE_DURATION
			travel.phase = "ocean_swim"
			var pose := map._pose(travel)
			for part in ["point", "child"]:
				var wet: bool = pose.swim if part == "point" else pose.child_swim
				if wet:
					var point: Vector2 = pose[part]
					wade_points += 1
					adult_wet += int(part == "point")
					child_wet += int(part == "child")
					wet_points_in_zone = wet_points_in_zone and Geometry2D.is_point_in_polygon(point, swim_area)
					# The swimmer is 20×12 with up to two pixels of vertical bob.
					# The open shore side stays free for entry and exit.
					has_sprite_room = has_sprite_room and point.x + 10.0 < edge - 3.0 \
						and first.y + 2.0 < point.y - 13.0 and point.y + 3.0 < last.y - 2.0
			if step > 0:
				map.time = (1.0 - progress) * Sim.OCEAN_WADE_DURATION
				travel.phase = "from_ocean"
				var returning := map._pose(travel)
				inverse_path = inverse_path and returning.point.is_equal_approx(pose.point) \
					and returning.child.is_equal_approx(pose.child)
		_check(adult_wet > 0 and child_wet > 0 and wet_points_in_zone and inverse_path,
			"%s lane %d contains actual adult and child wet approach, swim and return points" % [label, lane])
		_check(has_sprite_room, "%s lane %d keeps the swimmer sprite and bob inside the marked sides" % [label, lane])
		map.time = Sim.OCEAN_WADE_DURATION
		travel.phase = "ocean_swim"
		var final_pose := map._pose(travel)
		var adult_target: Vector2 = access.water + Vector2([0, 3, 6, 9][lane], [0, -12, 12, 20][lane])
		_check(final_pose.point.is_equal_approx(_swim_target(adult_target)) \
			and final_pose.child.is_equal_approx(_swim_target(adult_target + Vector2(-7, 8))) \
			and final_pose.swim and final_pose.child_swim,
			"%s lane %d ends at the original coast-clamped adult and child targets" % [label, lane])
	map.time = float(map.simulation.second)


func _check_draw_dispatch(layout: Layout) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(WORLD.size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var ocean := OceanDrawProbe.new()
	ocean.position = -WORLD.position
	viewport.add_child(ocean)
	ocean.set_landscape(layout.landscape)
	ocean.set_swim_access(layout.ocean_access())
	ocean.present(4 * MONTH_LENGTH + 95.0)
	await process_frame
	await process_frame
	var valid_patch_dispatch := true
	var clipped := 0
	for command in ocean.patch_rows:
		var image: Image = command.image
		var source: Rect2i = command.source
		valid_patch_dispatch = valid_patch_dispatch and command.texture_size == image.get_size() \
			and Rect2i(Vector2i.ZERO, image.get_size()).encloses(source) \
			and source.size.y == 1 and command.opacity > 0.0 and command.opacity <= 1.0
		clipped += int(source.size.x < image.get_width())
		for dx in source.size.x:
			if image.get_pixelv(source.position + Vector2i(dx, 0)).a == 0.0:
				continue
			var pixel := Vector2(command.at + Vector2i(dx, 0))
			submitted_pixels += 1
			valid_patch_dispatch = valid_patch_dispatch and WORLD.has_point(pixel) \
				and layout.landscape.is_water_pixel(pixel)
	_check(valid_patch_dispatch and submitted_pixels > 0 and clipped > 0,
		"Production canvas dispatch includes clipped, wet-only summer patch rows with nontransparent texture pixels")
	_check(ocean.buoy_runs > ocean.swim_buoy_points().size() * 6, "Production draw submits buoy bodies plus connecting rope runs")
	ocean.patch_rows.clear()
	ocean.buoy_runs = 0
	ocean.present(NOVEMBER + 110.0)
	await process_frame
	await process_frame
	_check(ocean.patch_rows.is_empty() and ocean.buoy_runs > 0, "Winter still draws the marked swim area after offshore drift ends")
	ocean.buoy_runs = 0
	ocean.set_swim_access({})
	await process_frame
	await process_frame
	_check(ocean.patch_rows.is_empty() and ocean.buoy_runs == 0, "Offseason without swim access submits neither patches nor buoy runs")
	viewport.queue_free()


func _coast_at(y: float) -> float:
	return shore[clampi(floori(y - WORLD.position.y), 0, shore.size() - 1)]


func _swim_target(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x, _coast_at(point.y) + 7.0, WORLD.end.x - 9.0), point.y)


func _relative_depth(point: Vector2) -> float:
	var coast := _coast_at(point.y)
	return (point.x - coast) / (WORLD.end.x - coast)


func _by_id(rafts: Array[Dictionary]) -> Dictionary:
	var result := {}
	for raft in rafts:
		result[raft.id] = raft
	return result


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
