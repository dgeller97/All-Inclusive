extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Layout = preload("res://scripts/layout_model.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Sim = preload("res://scripts/simulation.gd")

var game: Game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/test-appdata-r5-appearance"):
		push_error("Use isolated APPDATA under .tools/test-appdata-r5-appearance.")
		quit(2)
		return
	await _open_scene()
	_click_button(_dialog_button("Regular resort"))
	_test_view()
	await _test_settings()
	if failures == 0:
		await _test_save_and_apply()
		_test_developer()
		_test_legacy_and_coast()
	game.queue_free()
	await process_frame
	print("Building appearance scene: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _open_scene() -> void:
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame


func _test_view() -> void:
	var sim_state := game.simulation.snapshot()
	var camera_at_start := game.camera.snapshot()
	var buildings := game.simulation.layout.buildings
	var pool := _building(game.simulation.layout, "pool")
	var swimmer := game.simulation.layout.water_rect(pool).get_center()
	_check(not game.map.exterior_view and game.map.renderer._hidden_buildings.is_empty(), "New run starts in Interior")
	_click_button(game.ui._building_view)
	var enclosed_hidden := true
	for building in buildings:
		var center := game.simulation.layout.building_rect(building).get_center()
		enclosed_hidden = enclosed_hidden and game.map.actor_visible(center) == (building.kind == "pool")
	_check(game.exterior_view and game.map.exterior_view and game.ui._building_view.text == "Show interiors"
		and enclosed_hidden and game.map.renderer._hidden_buildings.size() == buildings.size() - 1,
		"One global click covers every enclosed building and hides actors inside each one")
	_check(game.map.actor_visible(Layout.ENTRY) and game.map.actor_visible(swimmer)
		and game.map.renderer._pools.size() == 1, "Exterior preserves actors outdoors, swimmers, and animated pool water")
	_check(game.simulation.snapshot() == sim_state and game.camera.snapshot() == camera_at_start,
		"View switching leaves the camera and simulation untouched")
	_click_button(game.ui._building_view)
	_check(not game.map.exterior_view and game.map.renderer._hidden_buildings.is_empty(), "The same button restores all interiors")
	_click_button(game.ui._building_view)
	_click_button(game.ui._dock_buttons.design)
	_check(game.exterior_view and not game.map.exterior_view and not game.map.actors.visible
		and not game.ui._building_view.is_visible_in_tree(), "Build uses Interior while the exterior preference is preserved")


func _test_settings() -> void:
	var draft := game.design.draft
	var lobby := _building(draft, "reception")
	var restaurant := _building(draft, "buffet")
	var pool := _building(draft, "pool")
	_check([lobby.display_name, restaurant.display_name, pool.display_name] == ["Lobby", "Restaurant", "Pool"],
		"Starter facility names identify lobby, restaurant, and pool")
	_open_settings(lobby)
	var ui := game.design_ui
	_check(ui._building_settings.visible and ui._name_field.text == "Lobby" and ui._surface_settings.visible,
		"Select and Building settings expose the selected building's name and surfaces")
	var blank := ui._building_settings.get_global_rect().position + Vector2(25, 105)
	var camera_before := game.camera.snapshot()
	_mouse(blank, MOUSE_BUTTON_WHEEL_UP, true)
	_mouse(blank, MOUSE_BUTTON_WHEEL_UP, false)
	_mouse(blank, MOUSE_BUTTON_MIDDLE, true)
	_motion(blank + Vector2(20, 14), MOUSE_BUTTON_MASK_MIDDLE)
	_mouse(blank + Vector2(20, 14), MOUSE_BUTTON_MIDDLE, false)
	_click(blank)
	_check(game.design.selection == lobby and game.camera.snapshot() == camera_before,
		"Blank settings space blocks map selection, wheel zoom, and middle pan")

	game.camera.zoom_in()
	camera_before = game.camera.snapshot()
	_click(ui._name_field.get_global_rect().get_center())
	_key(KEY_A, 0, true)
	for character in "Palm 123r":
		_type_character(character)
	_key(KEY_HOME)
	_type_character("2")
	_check(ui._name_field.has_focus() and ui._name_field.text == "2Palm 123r"
		and game.camera.snapshot() == camera_before and game.speed == 1 and not game.paused
		and game.design.asset_rotation == 0 and lobby.display_name == "Lobby",
		"Space, digits, R and Home belong to the focused name field; typing stages no rename")
	await process_frame
	_check(ui._apply.disabled and ui._save.disabled, "An uncommitted name must be set or canceled before saving or applying")
	_key(KEY_ENTER)
	_check(lobby.display_name == "2Palm 123r" and not ui._name_field.has_focus()
		and not ui._apply.disabled and not ui._save.disabled, "Enter commits the name into the draft exactly once")
	_check(_building(game.simulation.layout, "reception").display_name == "Lobby",
		"The live building name stays unchanged while editing")

	_click(ui._name_field.get_global_rect().get_center())
	_key(KEY_END)
	_type_character(" ")
	_key(KEY_ENTER)
	_check(ui._name_field.text == "2Palm 123r" and not ui._save.disabled and not ui._apply.disabled,
		"A normalized name matching the prior draft value clears the edit and keeps Apply enabled")

	_click(ui._name_field.get_global_rect().get_center())
	_key(KEY_A, 0, true)
	_key(KEY_BACKSPACE)
	_key(KEY_ENTER)
	_check(ui._name_field.has_focus() and ui._name_field.text.is_empty()
		and "between 1 and 24" in ui._name_status.text and lobby.display_name == "2Palm 123r",
		"Invalid name retains input, focus, and a readable reason")
	_key(KEY_ESCAPE)
	_check(ui._building_settings.visible and not ui._name_field.has_focus() and ui._name_field.text == "2Palm 123r",
		"First Escape cancels the name field without closing settings or clearing selection")

	var swatches := true
	for surface in ui._finish_fields:
		var field: OptionButton = ui._finish_fields[surface]
		swatches = swatches and field.item_count == 4
		for index in range(field.item_count):
			swatches = swatches and field.get_item_icon(index) != null
	_check(swatches, "Each surface presents Original and three pattern swatches")
	await _choose_finish("floor", "tile")
	_check(lobby.finishes.floor == "tile" and _rendered_building(lobby.id).finishes.floor == "tile"
		and "Cost $12" in ui._quote.text, "A floor choice refreshes the preview and quote")
	await _choose_finish("floor", "wood")
	await _choose_finish("wall", "brick")
	await _choose_finish("ceiling", "beams")
	_check(lobby.finishes == {"floor": "wood", "wall": "brick", "ceiling": "beams"}
		and _rendered_building(lobby.id).finishes == lobby.finishes
		and "Cost $30" in ui._quote.text and game.map.ceiling_id == -1,
		"Final floor, wall, and ceiling choices quote $30 once without auto-opening the ceiling")
	_click_button(ui._inspect_ceiling)
	_check(game.map.ceiling_id == lobby.id and not game.map.exterior_view and game.map.renderer._ceiling_building_id == lobby.id
		and game.map.renderer._hidden_buildings.has(lobby.id) and not game.map.renderer._hidden_buildings.has(restaurant.id),
		"Inspect ceiling shows only the selected building's ceiling plane")
	_click_button(ui._inspect_ceiling)
	_check(game.map.ceiling_id == -1 and game.map.renderer._hidden_buildings.is_empty(),
		"Closing ceiling inspection restores the floor plan")
	_key(KEY_ESCAPE)
	_check(not ui._building_settings.visible and game.design.selection == lobby, "Escape closes settings and preserves the selection")
	_key(KEY_HOME)
	_open_settings(pool)
	_check(ui._building_settings.visible and not ui._surface_settings.visible and not ui._inspect_ceiling.is_visible_in_tree(),
		"Pool settings allow a name with no enclosed-surface controls")
	_key(KEY_ESCAPE)
	_open_settings(restaurant)
	_click(ui._name_field.get_global_rect().get_center())
	_key(KEY_A, 0, true)
	for character in "Tide 2":
		_type_character(character)
	_click_button(ui._set_name)
	_check(restaurant.display_name == "Tide 2" and _rendered_building(restaurant.id).display_name == "Tide 2",
		"Set name also updates the restaurant's rendered sign data")


func _test_save_and_apply() -> void:
	var ui := game.design_ui
	_click_button(ui._save)
	_check(SaveSlot.read().exterior_view == true and game.saved_draft != null,
		"Saving a draft retains the management exterior preference")
	_click_button(_context_button("Discard"))
	_check(game.map.exterior_view and game.design.draft == null and game.simulation.cash == 140,
		"Discard restores Exterior without charging for the draft")
	await _open_scene()
	_click_button(game.dialog_load_button)
	_check(game.paused and game.map.exterior_view and game.saved_draft != null and game.simulation.cash == 140,
		"Relaunch loads the exterior preference and staged draft separately from the live layout")
	_tick(25)
	_click_button(game.ui._dock_buttons.design)
	var draft := game.design.draft
	var lobby := _building(draft, "reception")
	ui = game.design_ui
	_check(lobby.display_name == "2Palm 123r" and lobby.finishes == {"floor": "wood", "wall": "brick", "ceiling": "beams"}
		and _building(draft, "buffet").display_name == "Tide 2" and ui._apply.text == "Apply tomorrow"
		and "Cost $30" in ui._quote.text, "Reopened draft restores both names, materials, and the safe queued quote")
	_click_button(ui._apply)
	var sim := game.simulation
	_check(game.map.exterior_view and sim.cash == 110 and sim.pending_reserve == 30 and sim.pending_layout != null
		and _building(sim.layout, "reception").display_name == "Lobby", "Queue reserves $30 without changing the live buildings")
	game._save_run()
	await _open_scene()
	_click_button(game.dialog_load_button)
	sim = game.simulation
	_check(sim.pending_reserve == 30 and sim.cash == 110 and _building(sim.pending_layout, "reception").finishes.ceiling == "beams",
		"Queued names, materials, and exact held cash survive a saved run")
	_click_button(game.ui._dock_buttons.design)
	_click_button(game.design_ui._cancel_pending)
	_check(sim.pending_layout == null and sim.pending_reserve == 0 and sim.cash == 140
		and _building(game.design.draft, "reception").display_name == "2Palm 123r",
		"Cancel releases the hold and keeps the staged building settings editable")
	_click_button(game.design_ui._apply)
	_tick(Sim.DAY_LENGTH - sim.second)
	_check(sim.day == 2 and sim.pending_layout == null and sim.pending_reserve == 0
		and sim.cash == 470 and _building(sim.layout, "reception").display_name == "2Palm 123r"
		and _rendered_building(_building(sim.layout, "reception").id).finishes.ceiling == "beams"
		and game.map.exterior_view and game.map.renderer._ceiling_building_id == -1,
		"Day rollover applies the queued finish without a second charge and preserves the roof mode")
	_click_button(game.ui._dock_buttons.staff)
	_check("2Palm 123r" in game.ui._body.options[0].text and "Tide 2" in game.ui._body.options[1].text,
		"Management staff controls show the committed facility names")


func _test_developer() -> void:
	game._new_run("developer")
	_click_button(game.ui._dock_buttons.design)
	var draft := game.design.draft
	var lobby := _building(draft, "reception")
	draft.set_building_finish(lobby.id, "wall", "timber")
	game._refresh_design_ui()
	_click_button(game.design_ui._apply)
	_check(game.simulation.cash == 140 and _building(game.simulation.layout, "reception").finishes.wall == "timber"
		and game.design.draft == null, "Developer applies finishes immediately for free")


func _test_legacy_and_coast() -> void:
	var active := game.simulation
	var saved := active.snapshot()
	saved.layout.version = 2
	for building in saved.layout.buildings:
		building.erase("display_name")
		building.erase("finishes")
	_click_button(game.ui._building_view)
	_check(SaveSlot.write({"version": 4, "simulation": saved, "draft": {}, "elapsed": 0.0, "speed": 1}),
		"Version 4 fixture writes to the isolated slot")
	game._load_run()
	active = game.simulation
	var defaults := _building(active.layout, "reception")
	_check(not game.map.exterior_view and defaults.display_name == "Lobby" and defaults.finishes == Layout.DEFAULT_FINISHES
		and active.cash == 140, "Old local saves load Interior with default names and materials")
	var before := active.snapshot()
	for location in ["layout", "pending_layout", "draft"]:
		var tampered := {"version": Game.SAVE_VERSION, "simulation": active.snapshot(),
			"draft": {}, "elapsed": 0.0, "speed": 1, "exterior_view": true}
		var damaged := active.layout.snapshot()
		damaged.landscape.terrain.append([95, 14, "grass"])
		if location == "draft":
			tampered.draft = damaged
		else:
			tampered.simulation[location] = damaged
		var written := SaveSlot.write(tampered)
		var bytes := FileAccess.get_file_as_bytes(SaveSlot.PATH)
		game._load_run()
		_check(written and "protected coast" in game.last_notice and game.simulation == active
			and active.snapshot() == before and not game.map.exterior_view
			and FileAccess.get_file_as_bytes(SaveSlot.PATH) == bytes,
			"Version 5 rejects a protected-coast change in %s without altering file or run" % location)


func _choose_finish(surface: String, choice: String) -> void:
	var field: OptionButton = game.design_ui._finish_fields[surface]
	_click_button(field)
	await process_frame
	var popup := field.get_popup()
	_check(popup.visible, "%s choices open through routed input" % surface.capitalize())
	if popup.visible:
		for index in range(field.item_count):
			if field.get_item_metadata(index) == choice:
				popup.set_focused_item(index)
				break
		_key(KEY_ENTER)
		await process_frame


func _open_settings(building: Dictionary) -> void:
	var rect := game.design.draft.building_rect(building)
	for world in [rect.position + Vector2(10, 10), rect.position + Vector2(12, rect.size.y - 12),
			rect.end - Vector2(12, 12), rect.get_center()]:
		var screen := game.camera.world_to_screen(world)
		if game.design.draft.asset_at(world).is_empty() and not game.design_ui.is_pointer_over_ui(screen):
			_click(screen)
			break
	_check(game.design.selection == building and game.design_ui._open_building_settings.visible,
		"Routed map selection offers settings for %s" % building.kind)
	_click_button(game.design_ui._open_building_settings)


func _rendered_building(id: int) -> Dictionary:
	for building in game.map.renderer._buildings:
		if building.id == id:
			return building
	return {}


func _building(layout: Layout, kind: String) -> Dictionary:
	for building in layout.buildings:
		if building.kind == kind:
			return building
	return {}


func _tick(count: int) -> void:
	for index in range(count):
		game.simulation.tick()
	game._refresh()


func _dialog_button(title: String) -> Button:
	for child in game.dialog.get_children():
		if child is Button and child.text == title:
			return child
	return null


func _context_button(title: String) -> Button:
	for child in game.design_ui._context.get_children():
		if child is Button and child.text == title:
			return child
	return null


func _type_character(character: String) -> void:
	_key(character.to_upper().unicode_at(0), character.unicode_at(0))


func _key(code: Key, glyph: int = 0, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.unicode = glyph
	event.ctrl_pressed = ctrl
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _click_button(button: BaseButton) -> void:
	if not is_instance_valid(button):
		_check(false, "Expected an available button")
		return
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


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
