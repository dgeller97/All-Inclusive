extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Sim = preload("res://scripts/simulation.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Layout = Sim.Layout

var game
var checks := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/tester-appdata-r4-landscape-"):
		push_error("Use isolated APPDATA under .tools/tester-appdata-r4-landscape-<id>.")
		quit(2)
		return
	await _open_scene()
	if "--resume" in OS.get_cmdline_user_args():
		_test_relaunch()
		await _test_revision_three()
		_test_protected_save()
	else:
		_test_developer()
		await _open_scene()
		_test_regular()
	await _close_scene()
	print("Landscape scene: %d/%d checks passed" % [checks - failed, checks])
	quit(1 if failed else 0)


func _test_developer() -> void:
	_start("Developer · Free build")
	_use_pre_amenity_fixture()
	var active: Layout = game.simulation.layout
	_open_landscape()
	var draft: Layout = game.design.draft
	_check(_controls_fit(game.design_ui), "Landscape terrain buttons and labels fit the palette")
	_check(game.design_ui._tool_buttons.grass.visible and not game.design_ui._tool_buttons.bedroom.visible
		and not game.design_ui._tool_buttons.bed.visible, "Landscape displays its own tools")
	_check(game.design_ui._brush_buttons[1].button_pressed and game.design_ui._brush_buttons[5].visible,
		"Landscape opens on a one-tile terrain brush with sizes available")
	_check(not game.design_ui._tool_buttons.has("water"), "Terrain palette omits the Water brush")
	_tool("sand")
	_choose(game.design_ui._brush_buttons[3])
	_click_cell(Vector2i(45, 14))
	var terrain_tiles := 0
	for y in range(13, 16):
		for x in range(44, 47):
			terrain_tiles += int(draft.landscape.terrain_at(Vector2i(x, y)) == "sand")
	_check(terrain_tiles == 9 and active.landscape.terrain_at(Vector2i(45, 14)) != "sand",
		"3×3 brush covers nine tiles and edits only the paused draft")
	_tool("restore")
	_choose(game.design_ui._brush_buttons[5])
	_click_cell(Vector2i(45, 14))
	_check(draft.landscape.terrain_overrides.is_empty(), "5×5 Restore clears painted ground")

	_choose(game.design_ui._brush_buttons[1])
	_tool("sand")
	_drag_cells(Vector2i(40, 11), Vector2i(37, 11))
	_check(draft.landscape.terrain_overrides.is_empty() and "building" in game.design.feedback,
		"An invalid building tile aborts the entire terrain stroke with a reason")
	_drag_cells(Vector2i(62, 14), Vector2i(64, 14))
	_check(draft.landscape.terrain_overrides.is_empty() and "protected" in game.design.feedback.to_lower()
		and draft.landscape.is_water_pixel(Vector2(519, 116)),
		"Mixed shoreline tile blocks the whole stroke and preserves the original coast")
	_group("path")
	_click_cell(Vector2i(65, 14))
	_check(draft.landscape.path_overrides.is_empty() and "protected" in game.design.feedback.to_lower(),
		"The path brush preserves fully wet ocean tiles with clear feedback")
	_group("terrain")
	_tool("restore")
	_click_cell(Vector2i(64, 14))
	_check(draft.landscape.terrain_overrides.is_empty() and "protected" in game.design.feedback.to_lower(),
		"Restore preserves the mixed shoreline")

	_group("path")
	_check(_controls_fit(game.design_ui), "Path palette fits its buttons and labels")
	_tool("stone")
	var from := Vector2i(42, 14)
	var to := Vector2i(49, 14)
	var original := draft.route(_world(from), _world(to))
	_drag_cells(from, Vector2i(42, 16))
	_drag_cells(Vector2i(42, 16), Vector2i(49, 16))
	_drag_cells(Vector2i(49, 16), to)
	var detour := draft.route(_world(from), _world(to))
	_check(detour.size() > original.size() and _world(Vector2i(45, 16)) in detour,
		"A path drawn with routed input changes a guest route to prefer the longer paved route")
	_tool("boardwalk")
	_drag_cells(Vector2i(41, 10), Vector2i(46, 15))
	var continuous := true
	for i in range(5):
		var diagonal := Vector2i(41 + i, 10 + i)
		continuous = continuous and draft.landscape.path_at(diagonal) == "boardwalk"
		continuous = continuous and (draft.landscape.path_at(diagonal + Vector2i.RIGHT) == "boardwalk"
			or draft.landscape.path_at(diagonal + Vector2i.DOWN) == "boardwalk")
	_check(continuous and draft.landscape.path_at(Vector2i(46, 15)) == "boardwalk",
		"One fast mouse event paints each tile of an orthogonally connected diagonal")
	var baseline_path := Vector2i(41, 30)
	_check(active.landscape.path_at(baseline_path) == "stone", "Starting promenade is an editable stone path")
	_tool("erase")
	_click_cell(baseline_path)
	_check(draft.landscape.path_at(baseline_path).is_empty() and draft.landscape.terrain_at(baseline_path)
		== active.landscape.terrain_at(baseline_path), "Erase path exposes the original ground")
	_group("terrain")
	_tool("restore")
	_click_cell(baseline_path)
	_check(draft.landscape.path_at(baseline_path) == "stone", "Restore reinstates the original promenade")

	_tool("dirt")
	var canceled := Vector2i(52, 14)
	var start := _screen(canceled)
	var end := _screen(canceled + Vector2i.DOWN)
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	_motion(end, MOUSE_BUTTON_MASK_LEFT)
	_key(KEY_ESCAPE)
	_mouse(end, MOUSE_BUTTON_LEFT, false)
	_check(draft.landscape.terrain_at(canceled) == active.landscape.terrain_at(canceled), "Escape cancels the previewed stroke")
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	_motion(end, MOUSE_BUTTON_MASK_LEFT)
	_mouse(end, MOUSE_BUTTON_RIGHT, true)
	_mouse(end, MOUSE_BUTTON_RIGHT, false)
	_mouse(end, MOUSE_BUTTON_LEFT, false)
	_check(draft.landscape.terrain_at(canceled) == active.landscape.terrain_at(canceled), "Right-click cancels the previewed stroke")
	var palette_center: Vector2 = game.design_ui._palette.get_global_rect().get_center()
	_mouse(start, MOUSE_BUTTON_LEFT, true)
	_motion(palette_center, MOUSE_BUTTON_MASK_LEFT)
	_mouse(palette_center, MOUSE_BUTTON_LEFT, false)
	_check(not game.design.is_drawing() and draft.landscape.terrain_at(canceled) == active.landscape.terrain_at(canceled)
		and game.design.draft == draft, "Dragging over a palette cancels the stroke and does not activate a UI action")

	_group("scenery")
	_check(_controls_fit(game.design_ui), "Scenery palette fits its buttons and labels")
	var palm_start := Vector2i(-7, 16)
	var palm_stop := Vector2i(0, 16)
	var palm := draft.prop_at(_world(palm_start)).duplicate()
	_check(palm.get("kind") == "palm", "Starting palm exists as a scenery object")
	if palm.is_empty():
		return
	_click_cell(palm_start)
	_check(game.design.selection.get("id") == palm.id and not game.design_ui._move.disabled,
		"Selecting a starting palm enables Move")
	_tool("move")
	_key(KEY_R)
	_click_cell(palm_stop)
	var moved := draft.landscape.prop_by_id(palm.id)
	_check(moved.cell == [palm_stop.x, palm_stop.y] and moved.paid_cost == palm.paid_cost
		and moved.rotation == (int(palm.rotation) + 1) % 4, "Move preserves the original palm identity and accepts rotation")
	_tool("bulldoze")
	var flag := draft.prop_at(_world(Vector2i(59, 19))).duplicate()
	_check(flag.get("kind") == "beach_flag", "Starting beach flag is included in scenery")
	_click_cell(Vector2i(59, 19))
	_check(not flag.is_empty() and draft.landscape.prop_by_id(flag.id).is_empty(), "Bulldoze removes the existing beach flag")
	_tool("scenery_bench")
	_key(KEY_R)
	_click_cell(Vector2i(50, 11))
	var bench := draft.prop_at(_world(Vector2i(50, 11)))
	_check(bench.get("kind") == "bench" and draft.prop_rect(bench).size == Vector2(8, 24),
		"Outdoor bench uses its rotated three-tile footprint")
	_context("Apply now")
	var sim: Sim = game.simulation
	_check(game.design.draft == null and sim.cash == 140 and sim.layout.landscape.prop_by_id(bench.get("id", -1)).get("paid_cost") == 0,
		"Developer applies landscape edits without paying for scenery or brushes")
	_check(sim.layout.route(_world(from), _world(to)).has(_world(Vector2i(45, 16))) and game.map.visible_layout == sim.layout,
		"Applied paths remain part of management navigation and map rendering")


func _test_regular() -> void:
	_start("Regular resort")
	_use_pre_amenity_fixture()
	_open_landscape()
	var cell := Vector2i(44, 14)
	_tool("sand")
	_click_cell(cell)
	_click_cell(cell)
	_group("path")
	_tool("stone")
	_click_cell(cell)
	_group("scenery")
	_tool("palm")
	var placed := Vector2i(46, 14)
	_click_cell(placed)
	var draft: Layout = game.design.draft
	var palm_id: int = draft.prop_at(_world(placed)).get("id", -1)
	_check(palm_id >= 0 and "Cost $18" in game.design_ui._quote.text,
		"Regular quotes the terrain, path and palm once after repeated painting")
	_tool("bulldoze")
	_click_cell(Vector2i(59, 19))
	_context("Apply now")
	var sim: Sim = game.simulation
	_check(sim.cash == 122 and sim.layout.landscape.prop_by_id(palm_id).get("paid_cost") == 15,
		"Regular Apply Now charges the landscape total and stamps the palm price")
	_tick(25)
	var active_families := sim.families.duplicate(true)
	_open_landscape()
	_group("scenery")
	_click_cell(placed)
	_tool("move")
	var moved := Vector2i(47, 14)
	_click_cell(moved)
	_check("Cost $0" in game.design_ui._quote.text and "Refund $0" in game.design_ui._quote.text,
		"Moving paid scenery keeps its original cost basis and adds zero to the quote")
	_group("path")
	_tool("boardwalk")
	_click_cell(cell)
	_context("Apply tomorrow")
	_check(sim.pending_reserve == 3 and sim.cash == 119 and sim.families == active_families and sim.layout.landscape.path_at(cell) == "stone",
		"Landscape queues with one cash reservation and leaves guests and active terrain unchanged")
	_open_landscape()
	_context("Cancel queued plan")
	_check(sim.pending_layout == null and sim.pending_reserve == 0 and sim.cash == 122,
		"Cancel releases the full landscape reserve and retains the editable draft")
	_context("Apply tomorrow")
	_open_landscape()
	_group("scenery")
	_tool("bulldoze")
	_click_cell(moved)
	_check("Refund $7" in game.design_ui._quote.text, "Bulldozing the moved paid palm refunds half its original price")
	_group("terrain")
	_tool("sand")
	_click_cell(Vector2i(50, 16))
	_context("Save draft")
	_check(SaveSlot.read().version == game.SAVE_VERSION, "Landscape draft writes the current save revision")


func _test_relaunch() -> void:
	var cell := Vector2i(44, 14)
	var placed := Vector2i(46, 14)
	var moved := Vector2i(47, 14)
	game.dialog_load_button.pressed.emit()
	var sim: Sim = game.simulation
	var palm_id: int = sim.layout.prop_at(_world(placed)).get("id", -1)
	_check(game.started and game.paused and sim.pending_reserve == 3 and sim.cash == 119
		and sim.layout.landscape.terrain_at(cell) == "sand" and sim.layout.landscape.path_at(cell) == "stone"
		and sim.pending_layout.landscape.path_at(cell) == "boardwalk" and palm_id >= 0,
		"Fresh process keeps the active terrain, active path and queued path distinct")
	_check(sim.pending_layout.landscape.prop_by_id(palm_id).get("cell") == [moved.x, moved.y]
		and sim.layout.landscape.props.all(func(prop: Dictionary) -> bool: return prop.kind != "beach_flag"),
		"Fresh process retains a queued palm move and the removed starter flag")
	_open_landscape()
	_check(game.design.draft.landscape.prop_by_id(palm_id).is_empty() and sim.second == 25 and sim.families.size() == 1
		and game.design.draft.landscape.terrain_at(Vector2i(50, 16)) == "sand"
		and sim.layout.landscape.terrain_at(Vector2i(50, 16)) != "sand",
		"Fresh process preserves a separate draft with painted terrain and a removed palm during active service")
	_context("Discard")
	_tick(Sim.DAY_LENGTH - sim.second)
	_check(sim.pending_layout == null and sim.pending_reserve == 0 and sim.layout.landscape.path_at(cell) == "boardwalk"
		and sim.layout.landscape.prop_by_id(palm_id).get("cell") == [moved.x, moved.y] and sim.cash == 479,
		"Next day applies the queued landscape without a duplicate charge")


func _test_revision_three() -> void:
	var old := Sim.new()
	old.layout = Layout.new(false)
	var room := old.layout.add_building("bedroom", Rect2(320, 80, 48, 48))
	if not room.ok:
		_check(false, "Revision 3 fixture site available: " + room.reason)
		return
	old.layout.add_asset("bed", room.id, Vector2i(1, 1))
	old.apply_construction(old.layout)
	for i in range(25):
		old.tick()
	var plan: Layout = old.layout.duplicate_layout()
	var reception := plan.building_at(Vector2(60, 180))
	plan.add_asset("plant", reception.id, Vector2i(6, 2))
	old.apply_construction(plan)
	var unsaved := plan.duplicate_layout() as Layout
	var desk := unsaved.asset_at(Vector2(60, 180))
	unsaved.remove_asset(desk.id)
	var snapshot := old.snapshot()
	var draft := unsaved.snapshot()
	for legacy_layout in [snapshot.layout, snapshot.pending_layout, draft]:
		legacy_layout.erase("landscape")
		legacy_layout.version = 1
	_check(SaveSlot.write({"version": 3, "simulation": snapshot, "draft": draft, "elapsed": 0.0, "speed": 1}), "Synthetic revision 3 fixture writes")
	await _open_scene()
	game.dialog_load_button.pressed.emit()
	var sim: Sim = game.simulation
	_check(game.started and game.paused and sim.layout.building_by_id(room.id).get("rect") == [320, 80, 48, 48]
		and sim.layout.room_points().size() == 5 and not sim.layout.landscape.props.is_empty(),
		"Revision 3 migration preserves custom buildings and installs default scenery")
	_check(sim.pending_layout != null and sim.pending_reserve == 8 and game.saved_draft != null
		and game.saved_draft.asset_at(Vector2(60, 180)).is_empty(),
		"Revision 3 migration preserves the queued reserve and incomplete draft")
	var damaged := sim.snapshot()
	damaged.layout.erase("landscape")
	_check(not Sim.new().restore(damaged, false, true), "Revision 4 rejects a missing landscape instead of silently migrating it")


func _test_protected_save() -> void:
	var current: Sim = game.simulation
	var attempt := Sim.new()
	attempt.mode = "developer"
	var fresh := attempt.layout.snapshot()
	var save := {"version": 4, "simulation": attempt.snapshot(), "draft": {}, "elapsed": 0.0, "speed": 1}
	var original := current.snapshot()
	for section in ["layout", "pending_layout", "draft"]:
		var invalid := save.duplicate(true)
		var forbidden := fresh.duplicate(true)
		match section:
			"layout":
				forbidden.landscape.terrain.append([50, 16, "water"])
				invalid.simulation.layout = forbidden
			"pending_layout":
				forbidden.landscape.terrain.append([64, 10, "grass"])
				invalid.simulation.pending_layout = forbidden
			"draft":
				forbidden.landscape.paths.append([64, 14, "stone"])
				invalid.draft = forbidden
		var written := SaveSlot.write(invalid)
		var before := FileAccess.get_file_as_bytes(SaveSlot.PATH)
		game._load_run()
		_check(written and "protected coast" in game.last_notice and game.simulation == current and current.snapshot() == original
			and FileAccess.get_file_as_bytes(SaveSlot.PATH) == before,
			"Forbidden coastline edit in %s keeps the run and saved file intact" % section)
	save.simulation.layout.landscape.terrain.append([95, 14, "water"])
	var written := SaveSlot.write(save)
	var before := FileAccess.get_file_as_bytes(SaveSlot.PATH)
	game._load_run()
	_check(written and game.simulation != current and not game.simulation.layout.landscape.terrain_overrides.has(Vector2i(95, 14))
		and FileAccess.get_file_as_bytes(SaveSlot.PATH) == before,
		"Legacy no-op ocean override loads and normalizes without rewriting the save")


func _use_pre_amenity_fixture() -> void:
	# The original brush and scenery sites are occupied by a new-run court.
	# Run these specific editing regressions against that older hotel geometry.
	var sim: Sim = game.simulation
	var plan: Layout = sim.layout.duplicate_layout()
	for venue in plan.amenities():
		plan.remove_prop(venue.id)
	sim.apply_construction(plan)
	game._refresh()


func _open_scene() -> void:
	await _close_scene()
	game = Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame


func _close_scene() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame


func _start(title: String) -> void:
	for child in game.dialog.get_children():
		if child is Button and child.text == title:
			child.pressed.emit()
			return
	_check(false, "Welcome mode button exists")


func _open_landscape() -> void:
	_choose(game.ui._dock_buttons.design)
	_choose(game.design_ui._category_buttons.landscape)


func _group(id: String) -> void:
	_choose(game.design_ui._landscape_buttons[id])


func _tool(id: String) -> void:
	_choose(game.design_ui._tool_buttons[id])


func _context(title: String) -> void:
	for child in game.design_ui._context.get_children():
		if child is Button and child.text == title:
			_choose(child)
			return
	_check(false, "Design action exists: " + title)


func _tick(count: int) -> void:
	for i in range(count):
		game.simulation.tick()
	game._refresh()


func _world(cell: Vector2i) -> Vector2:
	return Vector2(cell * Layout.GRID) + Vector2(4, 4)


func _screen(cell: Vector2i) -> Vector2:
	return game.camera.world_to_screen(_world(cell))


func _click_cell(cell: Vector2i) -> void:
	_click(_screen(cell))


func _drag_cells(from: Vector2i, to: Vector2i) -> void:
	_mouse(_screen(from), MOUSE_BUTTON_LEFT, true)
	_motion(_screen(to), MOUSE_BUTTON_MASK_LEFT)
	_mouse(_screen(to), MOUSE_BUTTON_LEFT, false)


func _choose(button: Button) -> void:
	_click(button.get_global_rect().get_center())


func _click(point: Vector2) -> void:
	_motion(point)
	_mouse(point, MOUSE_BUTTON_LEFT, true)
	_mouse(point, MOUSE_BUTTON_LEFT, false)


func _motion(point: Vector2, mask: MouseButtonMask = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = mask
	root.push_input(event, true)


func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	if pressed and button == MOUSE_BUTTON_LEFT:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
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
		failed += 1
		push_error(label)


func _controls_fit(parent: Control) -> bool:
	for child in parent.get_children():
		if not child is Control or not child.is_visible_in_tree():
			continue
		if not parent.get_global_rect().grow(1.0).encloses(child.get_global_rect()):
			return false
		if child is Label and child.get_theme_font("font").get_string_size(child.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x > child.size.x:
			return false
		if not _controls_fit(child):
			return false
	return true
