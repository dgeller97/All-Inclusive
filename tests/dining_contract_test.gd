extends SceneTree
## Independent behavior checks: real furniture capacity, complete meals and resumable visits.
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var baseline := Sim.new()
	var tables: Array = baseline.layout.dining_tables()
	check(tables.size() == 1, "Starter restaurant has one real dining table")
	if tables.is_empty():
		quit(1)
		return
	_check_geometry(baseline.layout, tables)
	var expanded := Sim.new()
	var draft: Layout = expanded.layout.duplicate_layout()
	var restaurant: Dictionary = draft.buildings.filter(func(b: Dictionary) -> bool: return b.kind == "buffet")[0]
	var extra := draft.add_asset("table", restaurant.id, Vector2i(3, 5))
	check(extra.ok and draft.readiness().ok, "A second accessible table can be placed in the restaurant")
	check(expanded.apply_construction(draft).ok and expanded.cash == 120, "Buying a functional dining table costs $20")
	check(expanded.layout.dining_tables().size() == 2, "Construction adds real seating capacity")
	_check_geometry(expanded.layout, expanded.layout.dining_tables())
	var one := _observe_day(baseline, true)
	var two := _observe_day(expanded, false)
	check(one.completed == 4 and two.completed == 4, "Both restaurant layouts finish all four stays before closing")
	check(one.max_dining == 1 and two.max_dining >= 2, "One table serves one family at a time; a second enables concurrent meals")
	check(one.wait > two.wait, "Adding a reachable table measurably reduces seating wait")
	check(one.buffet_wait == two.buffet_wait, "Table supply does not pretend to add buffet staffing")
	check(one.cash == 620 and two.cash == 600, "Meals do not charge guests twice or create revenue")
	var moved := Layout.new()
	var old_table: Dictionary = moved.dining_tables()[0]
	moved.remove_asset(old_table.id)
	var replacement := moved.add_asset("table", moved.buildings[5].id, Vector2i(3, 5))
	var new_tables: Array = moved.dining_tables()
	check(replacement.ok and new_tables.size() == 1 and new_tables[0].id == replacement.id, "Rebuilt table replaces the removed table's identity")
	check(new_tables[0].seat != old_table.seat, "Dining destination follows edited furniture instead of a fixed map point")
	check(not new_tables.any(func(t: Dictionary) -> bool: return t.id == old_table.id), "Removed starter table is not retained as invisible seating")
	_check_geometry(moved, new_tables)
	print("Dining contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_geometry(layout: Layout, tables: Array) -> void:
	for table: Dictionary in tables:
		check(table.seat != table.child, "Adult and child have distinct dining positions")
		check(not layout.route(layout.station_point(1), table.seat).is_empty(), "Reserved seat is reachable from the actual buffet counter")
		check(not layout.route(table.seat, table.child).is_empty(), "Child dining position is reachable without crossing furniture")
		var furniture: Dictionary = layout.assets.filter(func(a: Dictionary) -> bool: return a.id == table.id)[0]
		var bounds := layout.asset_rect(furniture)
		check(not bounds.has_point(table.seat) and not bounds.has_point(table.child), "Diners occupy accessible floor beside the table, not its solid footprint")


func _observe_day(sim: Sim, exercise_save: bool) -> Dictionary:
	var histories := {}
	var saved_phases := {}
	var resumed_outcomes: Array[Dictionary] = []
	var peak := 0
	var seating_order: Array[int] = []
	for second in range(1, Sim.DAY_LENGTH):
		sim.tick()
		var reserved := {}
		var dining := 0
		for family: Dictionary in sim.families:
			if not histories.has(family.id):
				histories[family.id] = []
			var history: Array = histories[family.id]
			if history.is_empty() or history[-1] != family.phase:
				history.append(family.phase)
				if family.phase == "to_table":
					seating_order.append(family.id)
			if family.phase in ["to_table", "eating"]:
				if reserved.has(family.table_id):
					check(false, "Two families cannot reserve one table at the same time")
				reserved[family.table_id] = family.id
				dining += 1
			if exercise_save and family.phase in ["wait_table", "to_table", "eating"] and not saved_phases.has(family.phase):
				saved_phases[family.phase] = true
				resumed_outcomes.append(_check_resume(sim, family))
		peak = maxi(peak, dining)
	for history: Array in histories.values():
		var collect: int = history.find("to_buffet")
		var seated: int = history.find("to_table")
		var eat: int = history.find("eating")
		var leave: int = history.find("to_pool")
		check(collect >= 0 and seated > collect and eat > seated and leave > eat, "Every family collects food, reaches a table, eats, then leaves for the pool")
		check(history.count("eating") == 1 and history[-1] == "gone", "Each family eats once and completes checkout")
	check(seating_order == [0, 1, 2, 3], "Dining reservations are granted in arrival order")
	if exercise_save:
		check(saved_phases.size() == 3, "Save checks exercised waiting, walking with food and seated eating")
		for outcome in resumed_outcomes:
			check(outcome == _comparable(sim.snapshot()), "Resumed meal produces the same final state as the uninterrupted original run")
	var waiting := 0
	var buffet_waiting := 0
	for family: Dictionary in sim.families:
		waiting += family.dining_wait
		buffet_waiting += family.waits[1]
	return {"completed": sim.reviews.size(), "max_dining": peak, "wait": waiting, "buffet_wait": buffet_waiting, "cash": sim.cash}


func _check_resume(sim: Sim, family: Dictionary) -> Dictionary:
	var saved := bytes_to_var(var_to_bytes(sim.snapshot())) as Dictionary
	var restored := Sim.new()
	check(restored.restore(saved), "Save/load accepts a meal in progress: " + family.phase)
	check(_comparable(restored.snapshot()) == _comparable(sim.snapshot()), "Save/load preserves exact meal state: " + family.phase)
	for second in range(sim.second + 1, Sim.DAY_LENGTH):
		restored.tick()
	check(restored.reviews.size() == 4 and restored.families.all(func(f: Dictionary) -> bool: return f.phase == "gone"), "Resumed meal completes without losing or duplicating a stay")
	if family.phase in ["to_table", "eating"]:
		var malformed := saved.duplicate(true)
		malformed.families[family.id].table_id = 999999
		var before := _comparable(restored.snapshot())
		check(not restored.restore(malformed) and _comparable(restored.snapshot()) == before, "Nonexistent reserved table rejects a save without changing the current run")
		var other_index := 1 if family.id == 0 else 0
		if saved.families.size() > other_index and saved.families[other_index].room >= 0:
			malformed = saved.duplicate(true)
			var other_room: int = malformed.families[other_index].room
			malformed.families[other_index] = malformed.families[family.id].duplicate(true)
			malformed.families[other_index].id = other_index
			malformed.families[other_index].room = other_room
			check(not restored.restore(malformed) and _comparable(restored.snapshot()) == before, "Duplicate reservation rejects a save instead of placing two families at one table")
	return _comparable(restored.snapshot())


func _comparable(state: Dictionary) -> Dictionary:
	state.layout.erase("next_id")
	if not state.pending_layout.is_empty():
		state.pending_layout.erase("next_id")
	return state
