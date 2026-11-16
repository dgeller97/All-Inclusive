extends SceneTree
## Headless scene, timing, and state audit. The renderer's pixel output is not sampled.

const Viewer = preload("res://scripts/animation_viewer.gd")
const ResortMap = preload("res://scripts/resort_map.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const Save = preload("res://scripts/save_slot.gd")
const ROTATION_CLIPS := ["dining", "buffet_collection", "main_pool", "walking"]
const FIXED_CLIPS := ["ocean_swim", "ocean_evacuation"]

var viewer: Viewer
var checks := 0
var failures := 0
var closed_count := 0
var draws := {}
var behind_presses := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path(Save.PATH).replace("\\", "/").contains("/.tools/r14-viewer-contract"):
		push_error("Use isolated APPDATA under .tools/r14-viewer-contract.")
		quit(2)
		return
	var live := Sim.new()
	for tick in range(90):
		live.tick()
	var live_before := live.snapshot()
	var next_prop_id := Layout.Landscape._next_prop_id
	if not Save.write({"version": 8, "simulation": live_before}):
		push_error("Could not create the isolated save fixture.")
		quit(2)
		return
	var save_before := FileAccess.get_file_as_bytes(Save.PATH)
	var behind := Button.new()
	behind.size = root.get_visible_rect().size
	behind.pressed.connect(func() -> void: behind_presses += 1)
	root.add_child(behind)
	viewer = Viewer.new()
	root.add_child(viewer)
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewer.viewer_closed.connect(func() -> void: closed_count += 1)
	viewer.show_viewer()
	viewer.set_playing(false)
	await process_frame
	_check(viewer.is_visible_in_tree() and viewer.get_global_rect().encloses(root.get_visible_rect()), "Viewer fills the game viewport as a modal")
	_check(viewer.clip_id == "dining" and viewer.phase_id == "activity", "First open displays the dining comparison")
	_check_modal_input()
	for kind: String in Sim.LEISURE_DURATIONS:
		await _check_venue(kind)
	for clip: String in ROTATION_CLIPS:
		await _check_rotated_clip(clip)
	for clip: String in FIXED_CLIPS:
		await _check_fixed_clip(clip)
	await _check_playback()
	await _check_zoom()
	await _check_lifecycle()
	_check(live.snapshot() == live_before and Layout.Landscape._next_prop_id == next_prop_id, "Preview preserves unrelated resort state and both allocators")
	_check(FileAccess.get_file_as_bytes(Save.PATH) == save_before, "Preview preserves the existing save bytes")
	viewer.queue_free()
	behind.queue_free()
	await process_frame
	print("Animation viewer contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_venue(kind: String) -> void:
	viewer.select_clip(kind)
	viewer.set_playing(false)
	viewer.set_full_occupancy(false)
	viewer.select_phase("activity")
	viewer.seek(viewer.duration * 0.57)
	if not _check_panels(kind, 4):
		return
	await _check_draw_dispatch(kind)
	_check(viewer.clip_id == kind and viewer.phase_id == "activity", "Select actual activity phase for " + kind)
	for turn in range(4):
		var fixture: Dictionary = viewer.fixtures[turn]
		var layout: Layout = fixture.sim.layout
		var venue := layout.amenity_by_id(fixture.focus_id)
		var label := "%s %d degrees" % [kind, turn * 90]
		_check(not venue.is_empty() and venue.kind == kind and venue.rotation == turn, "Fixture has a real rotated venue: " + label)
		if venue.is_empty():
			continue
		var row: Dictionary = Layout.Landscape.PROP_CATALOG[kind]
		var canonical := Vector2(row.size[0], row.size[1]) * Layout.GRID
		var footprint := Vector2(canonical.y, canonical.x) if turn % 2 else canonical
		_check(venue.rect.size == footprint and venue.capacity == row.capacity and layout.landscape.rect_is_dry(venue.rect), "Footprint and capacity match production: " + label)
		_check(not layout.route(Layout.ENTRY, venue.point).is_empty(), "Venue has a genuine guest route: " + label)
		var map: ResortMap = viewer.panel_maps[turn]
		var families := _venue_families(map, venue.id, "leisure")
		_check(families.size() == 1 and families[0].leisure_slot == 0, "Single occupancy reserves one family: " + label)
		if not families.is_empty():
			var pose := map._pose(families[0])
			_check(pose.get("leisure") == kind and _pose_on_screen(map, pose), "Production activity pose is visible in its viewport: " + label)
	_check_sync(kind)
	viewer.set_full_occupancy(true)
	viewer.seek(viewer.duration * 0.57)
	for turn in range(4):
		var map: ResortMap = viewer.panel_maps[turn]
		var focus_id: int = viewer.fixtures[turn].focus_id
		var venue := map.simulation.layout.amenity_by_id(focus_id)
		var families := _venue_families(map, focus_id, "leisure")
		var slots := {}
		for family in families:
			slots[family.leisure_slot] = true
		var capacity: int = Layout.Landscape.PROP_CATALOG[kind].capacity
		_check(not venue.is_empty() and families.size() == capacity and slots.size() == capacity
			and slots.keys().all(func(slot: int) -> bool: return slot >= 0 and slot < capacity),
			"Full occupancy uses unique legal %s slots at %d degrees" % [kind, turn * 90])
	_check_sync(kind + " full")
	for phase in [["approach", "to_leisure"], ["departure", "from_leisure"]]:
		viewer.select_phase(phase[0])
		viewer.seek(viewer.duration * 0.65)
		_check(viewer.phase_id == phase[0] and viewer.panel_maps.all(func(map: ResortMap) -> bool:
			return map.simulation.families.any(func(family: Dictionary) -> bool: return family.phase == phase[1])),
			"%s reaches real %s poses in all turns" % [kind, phase[0]])
		_check_sync("%s %s" % [kind, phase[0]])


func _check_rotated_clip(clip: String) -> void:
	viewer.select_clip(clip)
	viewer.set_full_occupancy(false)
	viewer.select_phase("activity")
	viewer.seek(viewer.duration * 0.55)
	if not _check_panels(clip, 4):
		return
	await _check_draw_dispatch(clip)
	_check(viewer.clip_id == clip, "Viewer selects " + clip)
	for turn in range(4):
		var map: ResortMap = viewer.panel_maps[turn]
		var family := _first_active_family(map)
		var label := "%s at %d degrees" % [clip, turn * 90]
		_check(not family.is_empty(), "Fixture contains a guest family: " + label)
		if family.is_empty():
			continue
		var pose := map._pose(family)
		_check(_pose_on_screen(map, pose), "Ordinary production pose fits its panel: " + label)
		match clip:
			"dining", "buffet_collection":
				var action := "seated" if clip == "dining" else "collecting"
				var asset_kind := "table" if clip == "dining" else "counter"
				var item_id: int = family.table_id if clip == "dining" else viewer.fixtures[turn].focus_id
				var item := _asset(map.simulation.layout, item_id)
				_check(not item.is_empty() and item.kind == asset_kind and item.rotation == turn and pose.get("meal") == action,
					"Actual rotated %s produces %s: %s" % [asset_kind, action, label])
			"main_pool":
				var pool := _building(map.simulation.layout, "pool")
				_check(not pool.is_empty() and pool.rotation == turn and pose.swim and map.pool_water.has_point(pose.point),
					"Production pool swim is grounded in turned water: " + label)
			"walking":
				_check(not pose.swim and pose.frame in [0, 1, 2, 3], "Walk uses production walking atlas frames: " + label)
	_check_sync(clip)
	if clip == "walking":
		viewer.seek(viewer.duration * 0.10)
		var starts: Array[Vector2] = []
		for map in viewer.panel_maps:
			starts.append(map._pose(_first_active_family(map)).point)
		viewer.seek(viewer.duration * 0.85)
		var walks := {}
		for turn in range(4):
			var map: ResortMap = viewer.panel_maps[turn]
			var displacement: Vector2 = map._pose(_first_active_family(map)).point - starts[turn]
			if displacement.length() > 1.0:
				walks[Vector2i(displacement.sign())] = true
		_check(walks.size() == 4, "The four walking clips travel along distinct turned routes")
	viewer.set_full_occupancy(true)
	viewer.seek(viewer.duration * 0.55)
	for turn in range(4):
		var map: ResortMap = viewer.panel_maps[turn]
		var families := map.simulation.families.filter(func(family: Dictionary) -> bool: return family.phase != "gone")
		var occupied := {}
		for family in families:
			match clip:
				"dining": occupied[family.table_id] = true
				"buffet_collection": occupied[map._pose(family).point] = true
				"main_pool": occupied[family.slot] = true
				"walking": occupied[family.room] = true
		var expected := {"dining": 2, "buffet_collection": 2, "main_pool": 3, "walking": 3}
		_check(families.size() == expected[clip] and occupied.size() == families.size(), "%s full occupancy has distinct production anchors at %d degrees" % [clip, turn * 90])


func _check_fixed_clip(clip: String) -> void:
	viewer.select_clip(clip)
	viewer.set_playing(false)
	viewer.set_full_occupancy(false)
	viewer.seek(viewer.duration * 0.55)
	if not _check_panels(clip, 1):
		return
	await _check_draw_dispatch(clip)
	var fixed := viewer.find_children("*", "Label", true, false).any(func(label: Label) -> bool:
		return label.is_visible_in_tree() and "fixed" in label.text.to_lower())
	_check(viewer.clip_id == clip and fixed, "Ocean clip identifies the single fixed-coast panel: " + clip)
	var map: ResortMap = viewer.panel_maps[0]
	var family := _first_active_family(map)
	if family.is_empty():
		_check(false, "Ocean fixture has an active party: " + clip)
		return
	var pose := map._pose(family)
	_check(family.phase == ("ocean_swim" if clip == "ocean_swim" else "evacuate") and _pose_on_screen(map, pose),
		"Ocean clip uses the production shoreline animation: " + clip)
	_check(pose.get("swim") if clip == "ocean_swim" else pose.get("child_only", false), "Ocean sample distinguishes swimmer and evacuation states")
	viewer.set_full_occupancy(true)
	viewer.seek(viewer.duration * 0.55)
	_check(viewer.panel_maps.size() == 1 and viewer.panel_maps[0].simulation.families.size() == (4 if clip == "ocean_swim" else 1),
		"Ocean occupancy preserves its one fixed orientation: " + clip)


func _check_playback() -> void:
	viewer.select_clip("arcade")
	viewer.select_phase("activity")
	viewer.set_full_occupancy(false)
	viewer.set_playing(false)
	await process_frame
	if not _check_panels("playback", 4):
		return
	viewer.seek(viewer.duration * 0.37)
	var middle := viewer.playhead
	viewer._process(0.2)
	_check(is_equal_approx(viewer.playhead, middle), "Paused playback stays fixed")
	viewer.step_frame(1)
	_check(is_equal_approx(viewer.playhead, middle + Viewer.FRAME_SECONDS), "Forward steps one frame while paused")
	viewer.step_frame(-1)
	_check(is_equal_approx(viewer.playhead, middle), "Backward steps one frame while paused")
	viewer.seek(0.05)
	viewer.step_frame(1)
	_check(is_equal_approx(viewer.playhead, Viewer.FRAME_SECONDS * 2), "Next step from an off-grid seek lands on the next frame boundary")
	viewer.seek(0.05)
	viewer.step_frame(-1)
	_check(is_equal_approx(viewer.playhead, Viewer.FRAME_SECONDS), "Reverse step from an off-grid seek lands on the preceding frame boundary")
	viewer.seek(0.04)
	viewer.step_frame(-1)
	_check(is_equal_approx(viewer.playhead, Viewer.FRAME_SECONDS), "Reverse step doesn't skip the displayed frame after a small scrub")
	viewer.seek(-3.0)
	viewer.step_frame(-1)
	_check(is_zero_approx(viewer.playhead), "Negative seek and reverse step clamp at the start")
	viewer.seek(viewer.duration + 5.0)
	viewer.step_frame(1)
	_check(is_equal_approx(viewer.playhead, viewer.duration), "Positive seek and forward step clamp at the end")
	viewer.seek(middle)
	viewer.set_speed(2.0)
	viewer.set_playing(true)
	viewer._process(0.15)
	viewer.set_playing(false)
	_check(is_equal_approx(viewer.speed, 2.0) and is_equal_approx(viewer.playhead, middle + 0.3), "Play advances at the chosen speed")
	_check_sync("manual playback tick")
	viewer.set_speed(-1.0)
	_check(is_finite(viewer.speed) and viewer.speed > 0.0, "Invalid speed cannot reverse or poison playback")
	var variant_rows := {}
	for variant in range(3):
		viewer.set_guest_variant(variant)
		viewer.seek(middle)
		var variant_map: ResortMap = viewer.panel_maps[0]
		var actor := _first_active_family(variant_map)
		if not actor.is_empty():
			variant_rows[variant_map._guest_sprite(actor, variant_map._pose(actor), false).row] = true
	_check(variant_rows.size() == 3, "Appearance variants select three real adult atlas rows")
	_check_sync("appearance variants")
	viewer.select_phase("sequence")
	for segment in [[0.10, "to_leisure"], [0.50, "leisure"], [0.90, "from_leisure"]]:
		viewer.seek(viewer.duration * float(segment[0]))
		_check(viewer.panel_maps.all(func(map: ResortMap) -> bool: return _first_active_family(map).get("phase") == segment[1]),
			"Full sequence seeks all turns to " + str(segment[1]))
		_check_sync("sequence " + str(segment[1]))
	var active := viewer.clip_id
	_check(not viewer.select_clip("missing") and viewer.clip_id == active, "Unknown clip leaves the active comparison intact")


func _check_modal_input() -> void:
	var start := root.gui_get_focus_owner()
	var focus_inside := is_instance_valid(start) and viewer.is_ancestor_of(start)
	for reverse in [false, true]:
		for step in range(14):
			for pressed in [true, false]:
				var event := InputEventKey.new()
				event.keycode = KEY_TAB
				event.pressed = pressed
				event.shift_pressed = reverse
				root.push_input(event, true)
			var focus := root.gui_get_focus_owner()
			focus_inside = focus_inside and is_instance_valid(focus) and viewer.is_ancestor_of(focus)
	_check(focus_inside and behind_presses == 0, "Keyboard focus stays in the modal across forward and reverse loops")
	var controls := viewer.find_children("*", "Button", true, false)
	for control in controls:
		if control.text != "Play":
			continue
		var point: Vector2 = control.get_global_rect().get_center()
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.position = point
			event.global_position = point
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			event.pressed = pressed
			root.push_input(event, true)
		_check(viewer.playing and behind_presses == 0, "Pointer activates the viewer Play button and no covered control")
		viewer.set_playing(false)
		control.grab_focus()
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_SPACE
			key.pressed = pressed
			root.push_input(key, true)
		_check(viewer.playing and behind_presses == 0, "Space activates the focused viewer button only")
		viewer.set_playing(false)
		return
	_check(false, "Viewer has a usable Play button")


func _check_zoom() -> void:
	viewer.select_clip("arcade")
	viewer.select_phase("activity")
	viewer.set_playing(false)
	viewer.set_full_occupancy(true)
	viewer.seek(viewer.duration * 0.43)
	await process_frame
	if viewer.panel_maps.size() != 4:
		_check(false, "Zoom fixture requires all four panels")
		return
	var time := viewer.playhead
	var sample := viewer.panel_maps[0]._pose(_first_active_family(viewer.panel_maps[0]))
	var picker := viewer.find_child("ZoomPicker", true, false) as OptionButton
	if not picker:
		_check(false, "Viewer exposes the magnification selector")
		return
	_check(picker.item_count == 3 and picker.get_item_metadata(0) == 0.0, "Fit is available with two fixed magnifications")
	var fit := viewer.panel_maps[0].scale
	for index in [1, 2, 0]:
		var zoom: float = picker.get_item_metadata(index)
		picker.item_selected.emit(index)
		_check(viewer.view_zoom == zoom and viewer.playhead == time and viewer.phase_id == "activity" and viewer.full_occupancy,
			"Changing magnification retains the exact phase, time, and occupancy")
		var expected := Vector2.ONE * zoom if zoom > 0.0 else fit
		_check(viewer.panel_maps.all(func(map: ResortMap) -> bool: return map.scale.is_equal_approx(expected)),
			"Chosen magnification consistently reframes all four maps")
		_check(viewer.panel_maps[0]._pose(_first_active_family(viewer.panel_maps[0])) == sample,
			"Magnification never changes the sampled production pose")


func _check_draw_dispatch(label: String) -> void:
	draws.clear()
	for index in range(viewer.panel_maps.size()):
		viewer.panel_maps[index].actors.draw.connect(_record_draw.bind(index))
	viewer.seek(viewer.playhead)
	await process_frame
	await process_frame
	_check(draws.size() == viewer.panel_maps.size(), "Seeking dispatches each real actor CanvasItem draw callback: " + label)
	for index in range(viewer.panel_maps.size()):
		viewer.panel_maps[index].actors.draw.disconnect(_record_draw.bind(index))


func _check_lifecycle() -> void:
	viewer.close()
	viewer.close()
	await process_frame
	_check(closed_count == 1 and not viewer.is_visible_in_tree(), "Close emits once and hides the modal")
	_check(viewer.panel_viewports.all(func(viewport: SubViewport) -> bool:
		return not is_instance_valid(viewport) or viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED),
		"A closed viewer drops or disables every render target")
	viewer.show_viewer()
	viewer.set_playing(false)
	await process_frame
	_check(viewer.is_visible_in_tree() and viewer.find_children("*", "SubViewport", true, false).size() <= 4,
		"Reopening creates at most the four intended render targets")
	viewer.close()
	await process_frame
	_check(closed_count == 2 and not viewer.is_visible_in_tree(), "Reopened viewer closes with one further signal")


func _check_panels(label: String, expected: int) -> bool:
	var present := viewer.panel_maps.size() == expected and viewer.panel_viewports.size() == expected and viewer.fixtures.size() == expected
	_check(present, "%s has %d active runtime panels" % [label, expected])
	if not present:
		return false
	var unique := {}
	for index in range(expected):
		var viewport: SubViewport = viewer.panel_viewports[index]
		var map: ResortMap = viewer.panel_maps[index]
		var fixture: Dictionary = viewer.fixtures[index]
		unique[viewport.get_instance_id()] = true
		var draw_callback := map.actors.draw.get_connections().any(func(connection: Dictionary) -> bool:
			return connection.callable.get_object() == map and connection.callable.get_method() == &"_draw_actors")
		_check(viewport.is_inside_tree() and viewport.size.x > 0 and viewport.size.y > 0 and map.get_viewport() == viewport
			and map.simulation == fixture.sim and map.visible_layout == fixture.sim.layout and fixture.rotation == index,
			"%s panel %d binds its own actual resort model and viewport" % [label, index])
		_check(map.get_script() == ResortMap and map.people != null and map.people.resource_path == ResortMap.PEOPLE_PATH and draw_callback
			and map.actors.is_visible_in_tree() and not map.viewing_draft,
			"%s panel %d uses the actual guest atlas and production draw callback" % [label, index])
		_check(_viewport_is_displayed(viewport), "%s panel %d displays a genuine ViewportTexture" % [label, index])
	_check(unique.size() == expected, label + " panels use distinct SubViewports")
	return true


func _viewport_is_displayed(viewport: SubViewport) -> bool:
	var texture := viewport.get_texture()
	if not texture is ViewportTexture:
		return false
	var container := viewport.get_parent() as SubViewportContainer
	if container:
		return container.is_visible_in_tree() and container.size.x > 0 and container.size.y > 0
	return viewer.find_children("*", "TextureRect", true, false).any(func(rect: TextureRect) -> bool:
		return rect.is_visible_in_tree() and rect.texture == texture and rect.size.x > 0 and rect.size.y > 0)


func _check_sync(label: String) -> void:
	var time := -INF
	var state := ""
	var synchronized := true
	for map in viewer.panel_maps:
		var family := _first_active_family(map)
		if family.is_empty():
			synchronized = false
			continue
		var age := map.time - float(family.since)
		if time == -INF:
			time = age
			state = family.phase
		else:
			synchronized = synchronized and family.phase == state and is_equal_approx(age, time)
	_check(synchronized and is_finite(time) and time >= 0.0, "All rotations share the same phase and age: " + label)


func _pose_on_screen(map: ResortMap, pose: Dictionary) -> bool:
	var bounds := map.get_viewport_rect().grow(2.0)
	var project := map.get_global_transform_with_canvas()
	var adult: Vector2 = pose.get("adult_draw", pose.get("point", Vector2.INF))
	var child: Vector2 = pose.get("child_draw", pose.get("child", Vector2.INF))
	return child.is_finite() and bounds.has_point(project * child) and map.actor_visible(child) \
		and (pose.get("child_only", false) or adult.is_finite() and bounds.has_point(project * adult) and map.actor_visible(adult))


func _first_active_family(map: ResortMap) -> Dictionary:
	for family in map.simulation.families:
		if family.phase != "gone":
			return family
	return {}


func _venue_families(map: ResortMap, id: int, phase: String) -> Array[Dictionary]:
	return map.simulation.families.filter(func(family: Dictionary) -> bool:
		return family.get("phase") == phase and family.get("amenity_id") == id)


func _building(layout: Layout, kind: String) -> Dictionary:
	for building in layout.buildings:
		if building.kind == kind:
			return building
	return {}


func _asset(layout: Layout, id: int) -> Dictionary:
	for item in layout.assets:
		if item.id == id:
			return item
	return {}


func _record_draw(index: int) -> void:
	draws[index] = true


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
