extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")

var checks := 0
var failures := 0
var game: Game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/r7-beach-scene-"):
		push_error("Use isolated APPDATA under .tools/r7-beach-scene-<id>.")
		quit(2)
		return
	game = Scene.instantiate() as Game
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	_test_build_and_use()
	_test_v6_slot()
	game.queue_free()
	await process_frame
	print("Beach scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_build_and_use() -> void:
	game._new_run()
	var sim := game.simulation
	var visible_map := Rect2(0, 68, game.camera.size.x, game.ui._toast.position.y - 68)
	for record in sim.layout.amenities():
		var prop := sim.layout.landscape.prop_by_id(record.id)
		var bounds := sim.layout.prop_visual_rect(prop)
		var screen_bounds := Rect2(game.camera.world_to_screen(bounds.position), bounds.size * game.camera.zoom_level)
		_check(visible_map.encloses(screen_bounds), "%s is visible above the HUD at Home" % record.kind)
	game.ui.open_panel("pool")
	_check(game.ui._body.amenities.stage.text == "0 / 4 families", "Leisure panel shows real stage capacity")
	game.ui.close_panel()
	_click(game.ui._dock_buttons.design.get_global_rect().get_center())
	_click(game.design_ui._category_buttons.facilities.get_global_rect().get_center())
	for group in Layout.Landscape.FACILITY_GROUPS:
		_click(game.design_ui._facility_group_buttons[group].get_global_rect().get_center())
		for kind in Layout.Landscape.FACILITY_GROUPS[group]:
			var button: Button = game.design_ui._tool_buttons[kind]
			var price: Label = button.get_node("Price")
			_check(button.visible and price.visible and "$" in price.text and "famil" in button.tooltip_text,
				"%s has a visible build tool, cost and capacity" % kind)
	var bar: Dictionary = sim.layout.amenities("beach_bar")[0]
	_click(game.camera.world_to_screen(bar.rect.get_center()))
	_check(game.design.selection.get("id") == bar.id and not game.design_ui._move.disabled, "Amenities can be selected and moved in Build")
	_click(game.design_ui._move.get_global_rect().get_center())
	_click(game.design_ui._rotate.get_global_rect().get_center())
	var move_cell := Vector2i(48, 32)
	_click(game.camera.world_to_screen(Vector2(move_cell * Layout.GRID + Vector2i(4, 4))))
	var moved := game.design.draft.amenity_by_id(bar.id)
	_check(moved.get("rect") == Rect2(384, 256, 32, 48) and moved.get("rotation") == 1,
		"The moved beach bar keeps its identity and takes the rotated footprint")
	_check(game.design_ui._quote.text.begins_with("Cost $0"), "Relocation of the original beach bar is free")
	_click(game.design_ui._apply.get_global_rect().get_center())
	_check(sim.layout.amenity_by_id(bar.id) == moved and sim.cash == 140, "Apply activates the relocated bar")
	game.ui.open_panel("pool")
	for i in range(Sim.SHOW_START):
		sim.tick()
		for family in sim.families:
			if family.phase == "leisure" and family.leisure_kind == "beach_bar":
				game._refresh()
				var pose := game.map._pose(family)
				_check(family.amenity_id == bar.id and moved.rect.has_point(pose.point) and moved.rect.has_point(pose.child),
					"Drink animation uses the moved bar footprint")
				_check(game.ui._body.amenities.beach_bar.text.begins_with("1 / 2 families"), "Leisure panel displays the live bar reservation")
				break
		if sim.second >= 170:
			break
	while sim.second < Sim.SHOW_START + Sim.LEISURE_WALK_DURATION:
		sim.tick()
	game._refresh()
	_check(game.map.ocean.condition_name() == "Closed" and sim.families.all(
		func(family: Dictionary) -> bool: return family.phase == "leisure" and family.leisure_kind == "stage"
	), "Red shoreline flag leaves the live evening show open")
	game.ui.close_panel()
	game.elapsed = 0.5
	game._save_run()
	var saved := SaveSlot.read()
	_check(saved.get("version") == Game.SAVE_VERSION and saved.simulation.leisure_version == Sim.LEISURE_VERSION,
		"Save slot writes the beach revision and itinerary schema")
	game._load_run()
	_check(game.paused and game.elapsed == 0.5 and game.simulation.families == sim.families
		and game.simulation.layout.amenity_by_id(bar.id) == moved, "Load preserves an in-progress show and rotated bar")
	saved.simulation.erase("leisure_version")
	_check(SaveSlot.write(saved), "Stage a current slot with missing itinerary metadata")
	var active := game.simulation
	game._load_run()
	_check(game.simulation == active and "unreadable" in game.last_notice, "Missing itinerary metadata leaves current state intact")


func _test_v6_slot() -> void:
	var old := Sim.new()
	old.layout = Layout.new(false)
	for i in range(59):
		old.tick()
	var buffet := old.layout.building_at(old.layout.station_point(1))
	old.layout.set_building_name(buffet.id, "Palm Kitchen")
	old.layout.set_building_finish(buffet.id, "floor", "tile")
	var previous := old.snapshot()
	previous.erase("leisure_version")
	for family in previous.families:
		for key in Sim.LEISURE_DEFAULTS:
			family.erase(key)
	var view := {"zoom": 2.2, "center": Vector2(265, 150)}
	var saved := {"version": Game.DINING_SAVE_VERSION, "simulation": previous, "draft": {},
		"speed": 2, "elapsed": 0.25, "exterior_view": true, "camera": view}
	_check(SaveSlot.write(saved), "Stage a version 6 save with a meal in progress")
	game._load_run()
	var restored := game.simulation
	var kitchen := restored.layout.building_by_id(buffet.id)
	_check(game.paused and game.exterior_view and game.speed == 2 and game.elapsed == 0.25
		and game.camera.snapshot() == view and kitchen.get("display_name") == "Palm Kitchen"
		and kitchen.finishes.floor == "tile", "Version 6 preserves the saved camera, exterior view, name and material")
	_check(restored.layout.amenities().is_empty() and restored.families[0].phase == "eating"
		and restored.families[0].table_id == old.families[0].table_id, "Version 6 meal and original park layout survive without new free venues")
	for i in range(181):
		restored.tick()
	_check(restored.reviews.size() == 4 and restored.reviews.all(
		func(review: Dictionary) -> bool: return review.leisure_bonus == 0
	), "A migrated stay completes without inventing an activity bonus")


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
