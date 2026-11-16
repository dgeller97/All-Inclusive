extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Layout = preload("res://scripts/layout_model.gd")
const Save = preload("res://scripts/save_slot.gd")

var game: Game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path(Save.PATH).replace("\\", "/").contains("/.tools/r10-scene-"):
		push_error("Use isolated APPDATA under .tools/r10-scene-<id>.")
		quit(2)
		return
	game = Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	game._new_run("developer")
	await process_frame
	_clear_scenery(game.simulation.layout)
	game._refresh()
	_click(game.ui._dock_buttons.design)
	game.camera.pan_by(Vector2(150, 0))
	_click(game.design_ui._category_buttons.facilities)
	_check(game.design.facility_group == "water", "Facilities opens to Water")
	for group in Layout.Landscape.FACILITY_GROUPS:
		_click(game.design_ui._facility_group_buttons[group])
		_check(game.design.facility_group == group, "Facility tab selects " + group)
		for kind in Layout.Landscape.FACILITY_GROUPS[group]:
			var button: Button = game.design_ui._tool_buttons[kind]
			_check(button.visible and button.get_node("Price").text == "Free"
				and not button.get_global_rect().intersects(game.design_ui._rotate.get_global_rect()),
				"Readable separate tile and Free price for " + kind)
			if Layout.Landscape.PROP_CATALOG[kind].get("gate", false):
				_edit(kind, button)
	_click(game.design_ui._apply)
	_check(game.design.draft == null and game.simulation.cash == 140, "Free edits publish without charging")
	_queue_and_reload()
	await _scroll_all_facilities()
	game.queue_free()
	await process_frame
	print("Activity expansion scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _edit(kind: String, button: Button) -> void:
	var draft := game.design.draft
	_click(button)
	_click(game.design_ui._rotate)
	var base := Vector2(-92, 52)
	_world_click(base)
	var prop := draft.prop_at(base)
	_check(prop.get("kind") == kind and prop.get("rotation") == 1, "Place rotated " + kind)
	if prop.is_empty():
		return
	var id: int = prop.id
	_click(game.design_ui._tool_buttons.select)
	_world_click(draft.prop_rect(prop).get_center())
	_click(game.design_ui._rotate)
	_check(prop.rotation == 2 and game.design.selection.get("id") == id, "Rotate an existing " + kind)
	_click(game.design_ui._move)
	_world_click(Vector2(-92, 180))
	_check(prop.cell == [-12, 22] and prop.rotation == 2 and not draft.amenity_by_id(id).is_empty(), "Move an accessible " + kind)
	_click(game.design_ui._tool_buttons.bulldoze)
	_world_click(draft.prop_rect(prop).get_center())
	_check(draft.landscape.prop_by_id(id).is_empty(), "Bulldoze " + kind)


func _queue_and_reload() -> void:
	game._new_run("regular")
	game.simulation.cash = 500
	_clear_scenery(game.simulation.layout)
	for second in range(34):
		game.simulation.tick()
	game._refresh()
	_click(game.ui._dock_buttons.design)
	game.camera.pan_by(Vector2(150, 0))
	_click(game.design_ui._category_buttons.facilities)
	var waterpark: Button = game.design_ui._tool_buttons.waterpark
	_check(waterpark.get_node("Price").text == "$220", "Regular shows the Waterpark's actual price")
	_click(waterpark)
	_world_click(Vector2(-92, 52))
	var plan := game.design.draft
	var prop: Dictionary = plan.prop_at(Vector2(-92, 52))
	_check(prop.get("kind") == "waterpark", "Place Waterpark through the live game draft")
	if prop.is_empty():
		return
	var id: int = prop.id
	var before := game.simulation.cash
	_click(game.design_ui._apply)
	_check(game.simulation.pending_layout != null and game.simulation.pending_reserve == 220
		and game.simulation.cash == before - 220 and game.simulation.layout.amenity_by_id(id).is_empty(),
		"Apply Tomorrow reserves the price without opening the facility during occupied stays")
	_check(game._write_run(null), "Queued facility saves in the actual slot")
	game._load_run()
	var loaded := game.simulation
	_check(game.paused and loaded.pending_layout != null and loaded.pending_layout.amenity_by_id(id).kind == "waterpark",
		"Load restores the queued Waterpark and exact site")
	while loaded.day == 1:
		loaded.tick()
	var paid: Dictionary = loaded.layout.landscape.prop_by_id(id)
	_check(loaded.pending_layout == null and loaded.pending_reserve == 0 and paid.get("paid_cost") == 220
		and not loaded.layout.amenity_by_id(id).is_empty(), "Next day activates the paid facility exactly once")
	game._refresh()
	_click(game.ui._dock_buttons.pool)
	_check(game.ui._body.amenity_rows.waterpark.visible and game.ui._body.amenities.waterpark.text == "0 / 3 families",
		"Leisure exposes the installed facility's capacity")


func _clear_scenery(layout: Layout) -> void:
	for prop in layout.landscape.props.duplicate():
		layout.remove_prop(prop.id)


func _scroll_all_facilities() -> void:
	game._new_run("developer")
	var plan: Layout = game.simulation.layout
	for kind in Layout.Landscape.PROP_CATALOG:
		if not Layout.Landscape.PROP_CATALOG[kind].get("gate", false):
			continue
		_check(_place_on_open_land(plan, kind), "Install " + kind + " in the all-facility list fixture")
	game._refresh()
	_click(game.ui._dock_buttons.pool)
	await process_frame
	var scroll: ScrollContainer = game.ui._popover.get_node("FacilityCapacity")
	var nightclub: Control = game.ui._body.amenity_rows.nightclub
	_check(game.ui._body.amenity_rows.values().all(func(row: Control) -> bool: return row.visible)
		and not scroll.get_global_rect().encloses(nightclub.get_global_rect()), "All 14 facility rows overflow the initial capacity viewport")
	var camera := game.camera.snapshot()
	for step in range(20):
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel, true)
	await process_frame
	_check(scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(nightclub.get_global_rect()),
		"Wheel scroll reaches the final Nightclub capacity row")
	_check(game.camera.snapshot() == camera, "Wheel over facility capacity does not zoom or pan the map")


func _place_on_open_land(plan: Layout, kind: String) -> bool:
	for y in range(-12, 46):
		for x in range(-18, 54):
			var cell := Vector2i(x, y)
			if plan.validate_prop(kind, cell).ok:
				return plan.add_prop(kind, cell).ok
	return false


func _click(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _world_click(point: Vector2) -> void:
	_click_at(game.camera.world_to_screen(point))


func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event, true)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
