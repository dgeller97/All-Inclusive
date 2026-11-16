extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Sim = preload("res://scripts/simulation.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Layout = Sim.Layout

var game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/tester-appdata-r3-design"):
		push_error("Use an isolated APPDATA path under .tools/tester-appdata-r3-design.")
		quit(2)
		return
	game = _open_scene()
	await process_frame
	if "--resume" in OS.get_cmdline_user_args():
		_test_queued_load()
	else:
		_test_developer()
		if failures == 0:
			await _test_regular()
	game.queue_free()
	await process_frame
	print("Construction scene: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _test_developer() -> void:
	_button(game.dialog, "Developer showcase").pressed.emit()
	_check(game.simulation.mode == "developer", "Welcome selects Developer mode")
	# Isolate the original construction workflow from preplaced showcase furniture.
	# The full showcase entry/edit/save behavior is covered by developer_scene_test.
	var fixture := Sim.new()
	fixture.mode = "developer"
	game._set_simulation(fixture)
	game.camera.configure(Layout.WORLD_BOUNDS, Vector2(280, 170), 1.7)
	var initial: Sim = game.simulation
	_tick(0)
	_open_build()
	var draft: Layout = game.design.draft
	if draft == null:
		return
	var home: Dictionary = game.camera.snapshot()
	var count := draft.buildings.size()
	_check(game.design_ui.visible and not game.ui.visible and not game.map.actors.visible, "Design overlays replace management HUD and hide live actors")
	game._process(4.0)
	_check(initial.second == 0, "Opening Build pauses the simulation")
	var construction_site := Rect2(304, 56, 48, 48)
	for prop in draft.landscape.props.duplicate():
		if construction_site.intersects(draft.prop_rect(prop)):
			_category("landscape")
			_tool("bulldoze")
			_click_world(draft.prop_rect(prop).get_center())
	_tool("bedroom")
	_drag_world(Vector2(308, 60), Vector2(348, 100))
	var extra := draft.building_at(Vector2(310, 60))
	_check(extra.get("rect") == [304, 56, 48, 48] and draft.buildings.size() == count + 1, "Left-drag places an exact grid footprint")
	_check(game.camera.snapshot() == home and initial.layout.buildings.size() == count, "Drag changes only the draft")
	_drag_world(Vector2(308, 60), Vector2(348, 100))
	_check(draft.buildings.size() == count + 1 and not game.design.feedback_valid, "Overlapping drag is rejected")
	_drag_world(Vector2(536, 60), Vector2(576, 100))
	_check(draft.buildings.size() == count + 1 and "land" in game.design.feedback, "Offshore drag is rejected")
	var palette := game.design_ui.get_node("DesignPalette") as Control
	var blank := palette.get_global_rect().position + Vector2(140, 13)
	_mouse(blank, MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(blank, MOUSE_BUTTON_WHEEL_UP, false)
	_drag(blank, blank + Vector2(125, -90), MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_MASK_MIDDLE)
	_check(game.camera.snapshot() == home, "Blank palette area blocks wheel and middle drag")
	var anchor := Vector2(720, 330)
	_drag(anchor, anchor + Vector2(40, 45), MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_MASK_MIDDLE)
	_check(game.camera.snapshot() != home and not game.camera.is_dragging(), "Middle drag pans in design mode")
	var zoom: float = game.camera.zoom_level
	_mouse(anchor, MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(anchor, MOUSE_BUTTON_WHEEL_UP, false)
	_check(game.camera.zoom_level > zoom, "Wheel scroll zooms in design mode")
	_key(KEY_HOME)
	_check(game.camera.snapshot() == home, "Home resets design camera")
	_tool("bed")
	_key(KEY_R)
	_click_world(Vector2(314, 66))
	var bed := draft.asset_at(Vector2(314, 66))
	_check(bed.get("rotation") == 1 and draft.asset_rect(bed).size == Vector2(24, 16), "R rotates before click placement")
	if bed.is_empty():
		print("Failed bed: ", game.design.tool, " ", game.design.asset_rotation, " ", game.design.pointer, " ", game.design.feedback, " ", game.design.ghost_check)
		return
	_click_world(Vector2(314, 66))
	_check(draft.assets.size() == initial.layout.assets.size() + 1, "Furniture collision preserves draft")
	_tool("select")
	_click_world(Vector2(314, 66))
	_check(game.design.selection.get("id") == bed.id, "Select targets the clicked furnishing")
	_key(KEY_ESCAPE)
	_check(game.design.selection.is_empty() and not draft.asset_at(Vector2(314, 66)).is_empty(), "Escape clears selection without mutating the object")
	_tool("bulldoze")
	_click_world(Vector2(314, 66))
	_check(draft.asset_at(Vector2(314, 66)).is_empty() and not draft.building_by_id(extra.id).is_empty(), "Bulldoze removes furnishing without removing its room")
	_tool("bed")
	_click_world(Vector2(314, 66))
	_tool("bulldoze")
	for x in [30.0, 102.0, 174.0, 246.0]:
		_click_world(Vector2(x, 120))
	_check(draft.room_points().size() == 1 and draft.buildings.size() == 4, "Bulldozing buildings removes their furnishings and usable rooms")
	var old_pool := draft.building_at(Vector2(328, 225))
	var old_water := draft.water_rect(old_pool)
	var old_deck := draft.station_point(2)
	_click_world(Vector2(328, 225))
	_tool("pool")
	_drag_world(Vector2(100, 44), Vector2(236, 116))
	var new_pool := draft.building_at(Vector2(100, 44))
	_check(new_pool.get("rect") == [96, 40, 144, 80]
		and draft.building_by_id(old_pool.id).is_empty(), "Bulldoze and drag rebuild the pool in a new location")
	if new_pool.is_empty():
		return
	_context("Apply now")
	_check(game.design.draft == null and initial.cash == 140 and initial.rooms.size() == 1, "Developer applies real edits immediately for $0")
	_check(initial.layout.asset_at(Vector2(314, 66)).paid_cost == 0 and initial.layout.building_at(Vector2(310, 60)).paid_cost == 0, "Free build stamps zero actual paid cost")
	_check(game.map.actors.visible and game.map.room_points[0].x >= 304.0, "Management renderer follows the moved usable room")
	_tick(30)
	var family: Dictionary = initial.families[0]
	var expected := initial.layout.route(initial.layout.station_point(0), initial.layout.room_points()[0])
	var pose: Dictionary = game.map._pose(family)
	_check(initial.booked_count == 1 and family.phase == "to_room" and not expected.is_empty()
		and _on_route(pose.point, expected) and _on_route(pose.child, expected), "Demand caps at one usable room and family sprites follow its walkable route")
	_tick(40)
	var pool_deck := initial.layout.station_point(2)
	var table: Dictionary = initial.layout.dining_tables()[0]
	var to_pool := initial.layout.route(table.seat, pool_deck)
	pose = game.map._pose(family)
	_check(family.phase == "to_pool" and pool_deck != old_deck and to_pool[-1] == pool_deck
		and family.table_id == table.id and _on_route(pose.point, to_pool), "Guests approach the relocated pool on the walkable route from their table")
	_tick(6)
	pose = game.map._pose(family)
	var water := initial.layout.water_rect(new_pool)
	_check(pose.swim and water.has_point(pose.point) and water.has_point(pose.child)
		and not old_water.has_point(pose.point), "Swimming sprites use the relocated pool's water bounds")
	_tick(18)
	var venue := initial.layout.amenity_by_id(family.amenity_id)
	var from_pool := initial.layout.route(pool_deck, venue.get("point", Vector2.INF))
	pose = game.map._pose(family)
	_check(family.phase == "to_leisure" and not from_pool.is_empty() and from_pool[0] == pool_deck
		and _on_route(pose.point, from_pool), "Guests go from the relocated pool deck to a real beach activity")


func _test_regular() -> void:
	game.queue_free()
	await process_frame
	game = _open_scene()
	await process_frame
	_button(game.dialog, "Regular resort").pressed.emit()
	_check(game.simulation.mode == "regular", "Welcome selects Regular mode")
	_open_build()
	_tool("bulldoze")
	var desk := Vector2(59, 179)
	_click_world(desk)
	_check(game.design_ui._apply.disabled and "desk" in game.design_ui._apply_reason.text, "Incomplete operational draft disables Apply with a reason")
	_context("Save draft")
	_check(SaveSlot.read().get("version") == game.SAVE_VERSION and game.saved_draft != null, "Save draft writes an incomplete design with the live run")
	_context("Discard")
	_check(game.design.draft == null and not game.simulation.layout.asset_at(desk).is_empty(), "Discard exits and preserves live layout")
	game.queue_free()
	await process_frame
	game = _open_scene()
	await process_frame
	game.dialog_load_button.pressed.emit()
	_open_build()
	_check(game.paused and game.design.draft.asset_at(desk).is_empty() and game.design_ui._apply.disabled, "Relaunch reopens the saved incomplete draft")
	_tool("desk")
	_click_world(desk)
	_check(not game.design_ui._apply.disabled and "Cost $30" in game.design_ui._quote.text, "Regular quotes a paid replacement desk")
	_context("Apply now")
	_check(game.simulation.cash == 110 and game.simulation.layout.asset_at(desk).paid_cost == 30, "Apply Now charges and stamps the replacement desk")
	_tick(25)
	var live_layout: Layout = game.simulation.layout
	var active_families: Array = game.simulation.families.duplicate(true)
	_open_build()
	_tool("plant")
	_click_world(Vector2(84, 179))
	_check(game.design_ui._apply.text == "Apply tomorrow" and "Cost $8" in game.design_ui._quote.text, "Active guest changes Apply to Tomorrow and keeps the quote")
	_context("Apply tomorrow")
	_check(game.simulation.layout == live_layout and game.simulation.families == active_families
		and game.simulation.pending_reserve == 8 and game.simulation.cash == 102, "Queue reserves once and keeps live guests and layout")
	_open_build()
	_check(not game.design.draft.asset_at(Vector2(84, 179)).is_empty(), "Build opens the queued design")
	_context("Cancel queued plan")
	_check(game.simulation.pending_layout == null and game.simulation.cash == 110, "Cancel returns reserved cash")
	_context("Apply tomorrow")
	_open_build()
	_tool("bench")
	_click_world(Vector2(70, 197))
	_check("Cost $23" in game.design_ui._quote.text and "Available $110" in game.design_ui._quote.text, "Replacement quote uses active layout and virtually releases the old hold")
	_context("Apply tomorrow")
	_check(game.simulation.pending_reserve == 23 and game.simulation.cash == 87, "Replacement reserves the full new quote exactly once")
	_open_build()
	_tool("bulldoze")
	_click_world(desk)
	game.camera.zoom_in()
	_context("Save draft")
	_check(game.saved_draft != null and game.simulation.pending_reserve == 23, "Checkpoint saves an incomplete draft alongside queued construction")
	_context("Discard")


func _test_queued_load() -> void:
	var saved := SaveSlot.read()
	game.dialog_load_button.pressed.emit()
	var sim: Sim = game.simulation
	_check(game.started and game.paused and sim.mode == "regular" and sim.second == 25
		and sim.pending_reserve == 23 and sim.cash == 87, "Relaunch loads run mode, active families and reserved cash")
	_check(is_equal_approx(game.camera.zoom_level, saved.camera.zoom), "Relaunch restores design camera zoom")
	_open_build()
	_check(game.design_ui._apply.disabled and game.design_ui._cancel_pending.visible and game.design_ui._pending_notice.text == "Day 2 plan queued · $23 reserved", "Saved draft validation and queued status survive together")
	_context("Discard")
	_tick(215)
	_check(sim.day == 2 and sim.second == 0 and sim.pending_layout == null and sim.pending_reserve == 0, "Queued plan applies at safe day boundary")
	_check(sim.cash == 447 and sim.layout.asset_at(Vector2(84, 179)).paid_cost == 8
		and sim.layout.asset_at(Vector2(70, 197)).paid_cost == 15, "Next day activates the furnishings without charging the reserve twice")


func _on_route(point: Vector2, path: PackedVector2Array) -> bool:
	for i in range(1, path.size()):
		if Geometry2D.get_closest_point_to_segment(point, path[i - 1], path[i]).is_equal_approx(point):
			return true
	return path.has(point)


func _open_scene() -> Control:
	var scene := Scene.instantiate() as Control
	root.add_child(scene)
	scene.smoke_test_requested = true
	scene.set_process(false)
	return scene


func _open_build() -> void:
	_click(game.ui._dock_buttons.design.get_global_rect().get_center())
	_check(game.design.draft != null, "Routed Build dock click opens a draft")


func _tool(id: String) -> void:
	if Layout.BUILDING_CATALOG.has(id):
		_category("buildings")
	elif Layout.ASSET_CATALOG.has(id):
		_category("furniture")
	_click(game.design_ui._tool_buttons[id].get_global_rect().get_center())


func _category(id: String) -> void:
	if game.design.category != id:
		_click(game.design_ui._category_buttons[id].get_global_rect().get_center())


func _context(text: String) -> void:
	var button := _button(game.design_ui.get_node("DesignContext"), text)
	if button == null:
		_check(false, "Design action exists: " + text)
	else:
		_click(button.get_global_rect().get_center())


func _button(parent: Node, title: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == title:
			return child
	return null


func _tick(count: int) -> void:
	for i in range(count):
		game.simulation.tick()
	game._refresh()


func _click_world(point: Vector2) -> void:
	_click(game.camera.world_to_screen(point))


func _drag_world(from: Vector2, to: Vector2) -> void:
	_drag(game.camera.world_to_screen(from), game.camera.world_to_screen(to), MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT)


func _click(point: Vector2) -> void:
	_move(point)
	_mouse(point, MOUSE_BUTTON_LEFT, true)
	_mouse(point, MOUSE_BUTTON_LEFT, false)


func _drag(from: Vector2, to: Vector2, button: MouseButton, mask: MouseButtonMask) -> void:
	_move(from)
	_mouse(from, button, true)
	_move(to, mask, to - from)
	_mouse(to, button, false)


func _move(point: Vector2, mask: MouseButtonMask = 0, relative := Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)


func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	if pressed and button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(event, true)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
