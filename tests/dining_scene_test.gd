extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Layout = preload("res://scripts/layout_model.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Sim = preload("res://scripts/simulation.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/r6-dining-scene"):
		push_error("Use isolated APPDATA under .tools/r6-dining-scene.")
		quit(2)
		return
	var game := Scene.instantiate() as Game
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	_test_current_slot(game)
	_test_v5_migration(game)
	_test_cramped_and_adjacent_tables()
	game.queue_free()
	await process_frame
	print("Dining scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_current_slot(game: Game) -> void:
	game._new_run()
	for checkpoint in [[48, 0, "service"], [54, 0, "to_table"], [59, 0, "eating"], [63, 1, "wait_table"], [69, 0, "to_pool"]]:
		game.paused = false
		game._process(checkpoint[0] - game.simulation.second - game.elapsed + 0.25)
		var before := game.simulation.snapshot()
		var phase: String = checkpoint[2]
		_check(before.families[checkpoint[1]].phase == phase, "Reach %s through controller" % phase)
		if phase == "wait_table":
			game.ui.open_panel("staff")
			_check(game.ui._body.tables.text == "Tables 1/1 in use · 1 waiting to eat"
				and "1/2 collecting · 0 in buffet line" in game.ui._body.options[1].text,
				"Staff shows table capacity, dining wait and separate counter activity")
			game.ui.close_panel()
			var plan := game.simulation.layout.duplicate_layout() as Layout
			var table: Dictionary = plan.dining_tables()[0]
			plan.remove_asset(table.id)
			plan.add_asset("table", table.building_id, Vector2i(11, 4), 1)
			_check(game.simulation.apply_construction(plan).defer and game.simulation.pending_reserve == 20,
				"A moved and rotated table queues tomorrow while the current tabletop is occupied")
			before = game.simulation.snapshot()
		game._save_run()
		var saved := SaveSlot.read()
		_check(saved.get("version") == Game.SAVE_VERSION and saved.get("simulation", {}).get("meal_version") == Sim.MEAL_VERSION,
			"Current slot versions both wrapper and meal state")
		game._load_run()
		_check(game.paused and is_equal_approx(game.elapsed, 0.25) and _same_state(game.simulation.snapshot(), before),
			"Save and reload %s at the same fractional clock and table state" % phase)
	var before := game.simulation.snapshot()
	var invalid := SaveSlot.read()
	invalid.simulation.erase("meal_version")
	_check(SaveSlot.write(invalid), "Stage a current wrapper missing meal metadata")
	game._load_run()
	_check(_same_state(game.simulation.snapshot(), before) and "unreadable" in game.last_notice,
		"Reject missing current meal metadata without changing the active game")
	var old_table: Dictionary = game.simulation.layout.dining_tables()[0]
	game.paused = false
	game._process(float(Sim.DAY_LENGTH - game.simulation.second) - game.elapsed)
	var moved: Dictionary = game.simulation.layout.dining_tables()[0]
	_check(game.simulation.day == 2 and moved.id != old_table.id and moved.seat != old_table.seat
		and game.simulation.pending_layout == null and game.simulation.pending_reserve == 0,
		"Morning activates the new table geometry and settles the reserved construction")


func _test_v5_migration(game: Game) -> void:
	var old := Sim.new()
	for second in range(64):
		old.tick()
	var buffet := old.layout.building_at(old.layout.station_point(1))
	old.layout.set_building_name(buffet.id, "Palm Kitchen")
	old.layout.set_building_finish(buffet.id, "floor", "tile")
	var state := old.snapshot()
	state.erase("meal_version")
	state.families[0].merge({"phase": "to_pool", "since": 64, "until": 68, "slot": 0}, true)
	state.families[1].merge({"phase": "service", "since": 54, "until": 72, "slot": 1}, true)
	state.families[2].merge({"phase": "service", "since": 64, "until": 82, "slot": 0, "waits": [4, 2, 0]}, true)
	for family in state.families:
		family.erase("table_id")
		family.erase("dining_wait")
	var saved := {"version": Game.EXTERIOR_SAVE_VERSION, "simulation": state, "draft": {},
		"elapsed": 0.5, "speed": 2, "exterior_view": true, "camera": game.camera.snapshot()}
	_check(SaveSlot.write(saved), "Stage a pre-meal version 5 with active buffet and post-buffet travel")
	game._load_run()
	var loaded := game.simulation
	var restaurant := loaded.layout.building_at(loaded.layout.station_point(1))
	_check(game.paused and game.exterior_view and restaurant.display_name == "Palm Kitchen"
		and restaurant.finishes.floor == "tile" and loaded.second == 64 and game.elapsed == 0.5,
		"Version 5 restores view, name, finish and exact clock")
	_check(loaded.families[0].table_id == -1 and loaded.families[0].until == 68
		and loaded.families[1].since == 54 and loaded.families[1].until == 72,
		"Migration preserves in-progress collection and pool departure deadlines")
	game._save_run()
	game._load_run()
	_check(game.simulation.families[1].until == 72 and game.simulation.families[0].phase == "to_pool",
		"Converted version 6 can immediately reload the migrated in-flight guests")
	game.speed = 1
	game.paused = false
	game._process(7.5)
	_check(game.simulation.families[0].station == 2 and game.simulation.families[0].table_id == -1
		and game.simulation.families[1].phase == "to_table" and game.simulation.families[1].table_id > 0,
		"Already-fed guests continue swimming and active counter guests advance to real tables")
	game._save_run()
	game._load_run()
	_check(game.simulation.families[1].phase == "to_table" and game.simulation.families[1].until == 76,
		"Migrated collection can save and reload after real table assignment")
	var invalid := saved.duplicate(true)
	invalid.simulation.layout.erase("landscape")
	_check(SaveSlot.write(invalid), "Stage an incomplete version 5 slot")
	game._load_run()
	_check(game.simulation.second == 72 and "unreadable" in game.last_notice,
		"Version 5 retains its landscape requirement")


func _test_cramped_and_adjacent_tables() -> void:
	var layout := Layout.new()
	var restaurant := layout.building_at(layout.station_point(1))
	var second := layout.add_asset("table", restaurant.id, Vector2i(9, 6), 2)
	var tables := layout.dining_tables()
	var cells := {}
	for table in tables:
		cells[table.seat] = true
		cells[table.child] = true
	_check(second.ok and tables.size() == 2 and cells.size() == 4,
		"Adjacent tables expose distinct adult and child seats")
	layout.remove_asset(second.id)
	for cell in [Vector2i(9, 2), Vector2i(10, 2), Vector2i(10, 5), Vector2i(8, 3), Vector2i(8, 4), Vector2i(11, 3), Vector2i(11, 4)]:
		_check(layout.add_asset("plant", restaurant.id, cell).ok, "Place plant around a one-edge table")
	var cramped := layout.dining_tables()
	_check(layout.readiness().ok and cramped.size() == 1 and cramped[0].seat != cramped[0].child
		and not layout.route(cramped[0].seat, cramped[0].child).is_empty(),
		"A formerly ready one-edge restaurant keeps its table and nearby accessible child seat")


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	for state in [left, right]:
		state.layout.erase("next_id")
		state.pending_layout.erase("next_id")
	return left == right


func _check(passed: bool, explanation: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		push_error(explanation)
