extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Sim = preload("res://scripts/simulation.gd")
const Save = preload("res://scripts/save_slot.gd")

var game: Game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path(Save.PATH).replace("\\", "/").contains("/.tools/r9-scene-"):
		push_error("Use an isolated APPDATA path under .tools/r9-scene-<id>.")
		quit(2)
		return
	game = Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	game._new_run()
	await process_frame
	_booking()
	_beach()
	_design()
	_save_validation()
	game.queue_free()
	await process_frame
	print("Revision 9 scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _booking() -> void:
	_check(game.ui._clock.text == "06:00" and "MARCH 1" in game.ui._date_heading.text and "°C" in game.ui._temperature.text,
		"HUD exposes calendar date, local hour and temperature")
	_click(game.ui._dock_buttons.package)
	var slider: HSlider = game.ui._body.slider
	var bounds := slider.get_global_rect()
	_click_at(bounds.position + bounds.size * Vector2(0.33, 0.5))
	var chosen := game.simulation.selected_price
	_check(chosen == int(slider.value) and chosen > 120 and chosen < 150 and "$%d" % chosen in game.ui._body.effective.text,
		"A pointer click on the slider selects an intermediate room price and updates its label")
	for second in range(Sim.OPEN_BOOKINGS):
		game.simulation.tick()
	_click_at(bounds.position + bounds.size * Vector2(0.78, 0.5))
	_check(game.simulation.booked_price == chosen and game.simulation.selected_price > 150 and "$%d" % chosen in game.ui._body.booking.text,
		"A later slider edit changes the next price without replacing locked bookings")
	game.ui.close_panel()


func _beach() -> void:
	_click(game.ui._dock_buttons.beach)
	_check(game.simulation.swim_policy == "safe" and game.ui._body.policies.safe.button_pressed,
		"Beach opens with Safe flags selected")
	_click(game.ui._body.policies.allow_red)
	_check(game.simulation.swim_policy == "allow_red" and "drown" in game.ui._body.swim_warning.text,
		"Allow red risk is routed and exposes a drowning warning")
	_click(game.ui._body.policies.closed)
	_check(game.simulation.swim_policy == "closed" and "closed" in game.ui._body.swim_warning.text,
		"Closed turns off swim participation")
	game.simulation.sargassum = 76
	game._refresh()
	var cash := game.simulation.cash
	_click(game.ui._body.clean)
	_check(game.simulation.sargassum == 16 and game.simulation.cash == cash - 30 and "16%" in game.ui._body.seaweed.text,
		"Clean beach spends $30 and refreshes actual buildup")
	game.ui.close_panel()


func _design() -> void:
	game._new_run("developer")
	_click(game.ui._dock_buttons.design)
	var draft := game.design.draft
	var building := draft.buildings[3]
	var id: int = building.id
	var screen := game.camera.world_to_screen(draft.building_rect(building).position + Vector2(42, 24))
	_click_at(screen)
	_check(game.design.selected_building().get("id") == id and not game.design_ui._rotate.disabled,
		"Selecting an existing room enables Rotate")
	_click(game.design_ui._rotate)
	_check(draft.building_by_id(id).rotation == 1 and game.simulation.layout.building_by_id(id).rotation == 0,
		"Rotate changes only the selected draft room and its furnishing (%s)" % game.design.feedback)
	_click(game.design_ui._open_building_settings)
	var facade: OptionButton = game.design_ui._finish_fields.facade
	facade.item_selected.emit(2)
	var roof: OptionButton = game.design_ui._finish_fields.roof
	roof.item_selected.emit(2)
	_check(draft.building_by_id(id).finishes.facade == "brick" and draft.building_by_id(id).finishes.roof == "slate"
		and game.design.inspect_exterior and game.map.exterior_view and game.map.daylight == 1.0,
		"Exterior choices are routed to the draft and visible before Apply in edit lighting")
	_click(game.design_ui._inspect_exterior)
	_check(not game.map.exterior_view and not game.design.inspect_exterior, "Exterior inspection returns to the floor plan")
	_click(game.design_ui._apply)
	_check(game.design.draft == null and game.simulation.layout.building_by_id(id).rotation == 1
		and game.simulation.layout.building_by_id(id).finishes.roof == "slate", "Apply publishes the rotated and finished room")
	_check(game._write_run(null) and Save.read().version == Game.SAVE_VERSION, "Current save writes the new envelope")
	game._load_run()
	_check(game.paused and game.simulation.layout.building_by_id(id).finishes.facade == "brick",
		"Current save restores the rotated and finished room")


func _save_validation() -> void:
	var sim := Sim.new()
	sim.set_swim_policy("allow_red")
	for tick in range(Sim.DAY_LENGTH * 6):
		if sim.stopped:
			sim.continue_after_recap()
		sim.tick()
		if not sim.ocean_incidents.is_empty():
			break
	_check(not sim.ocean_incidents.is_empty(), "Deterministic risky run yields a recorded incident")
	if sim.ocean_incidents.is_empty():
		return
	var active := game.simulation
	var before := active.snapshot()
	for tamper in ["selected_price", "booked_value", "sargassum", "swim_policy", "ocean_incidents", "family", "review", "rotation"]:
		var bad := sim.snapshot()
		match tamper:
			"selected_price": bad.selected_price = 112
			"booked_value": bad.booked_value = 40.0
			"sargassum": bad.sargassum = 101
			"swim_policy": bad.swim_policy = "force_open"
			"ocean_incidents": bad.ocean_incidents.append(bad.ocean_incidents[0].duplicate())
			"family": bad.families[bad.ocean_incidents[0].family].ocean_fatality = false
			"review": bad.reviews.pop_back()
			"rotation": bad.layout.buildings[0].rotation = 4
		_check(not active.restore(bad) and active.snapshot() == before, "Reject invalid %s without changing live state" % tamper)
	var legacy := Sim.new()
	legacy.selected_package = 2
	var old := legacy.snapshot()
	for field in ["beach_version", "selected_price", "booked_price", "booked_value", "swim_policy", "sargassum", "ocean_incidents"]:
		old.erase(field)
	old.layout.version = 3
	for building in old.layout.buildings:
		building.erase("rotation")
		building.finishes.erase("facade")
		building.finishes.erase("roof")
	var stored := Save.write({"version": Game.LEISURE_SAVE_VERSION, "simulation": old, "draft": {}, "elapsed": 0.0, "speed": 1})
	game._load_run()
	_check(stored and game.simulation != active and game.simulation.selected_price == 170 and game.simulation.swim_policy == "safe"
		and game.simulation.sargassum == 0 and game.simulation.layout.buildings[0].rotation == 0,
		"R8 migration defaults beach and rotation while preserving the selected package price")


func _click(control: Control) -> void:
	_click_at(control.get_global_rect().get_center())


func _click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		root.push_input(click, true)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
