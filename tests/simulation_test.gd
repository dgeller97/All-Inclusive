extends SceneTree

const Sim = preload("res://scripts/simulation.gd")

var failures := 0


func _initialize() -> void:
	_check_standard_run()
	_check_price_changes()
	_check_staff_transfer()
	_check_restore()
	if failures == 0:
		print("Simulation checks passed")
	quit(0 if failures == 0 else 1)


func _check_standard_run() -> void:
	var sim := Sim.new()
	_expect(sim.cash == 140 and sim.selected_package == 1 and sim.float_station == 1, "Opening balances and selections")
	_expect(sim.rooms == [-1, -1, -1, -1], "Four initially free rooms")
	_expect(not sim.terrace and sim.capacity(2) == 1, "Pool starts without terrace furnishings")
	_tick(sim, 140)
	_expect(sim.cash == 620 and sim.rooms == [0, 1, 2, 3], "Four check-ins at the locked price")
	_expect(sim.families[3].waits[2] == 12 and sim.families[3].dining_wait == 24, "Separate peak pool and dining-table waits")
	_tick(sim, 97)
	_expect(sim.rooms == [-1, -1, -1, -1] and sim.families[3].phase == "gone", "All families clear before payroll")
	_expect(_scores(sim) == [95, 94, 89, 83], "Day 1 ratings include dining waits and completed beach activities")
	_tick(sim, 3)
	_expect(sim.day == 2 and sim.second == 0 and sim.cash == 500, "Day 1 closing balance")
	var plan := _terrace_plan(sim)
	_expect(sim.apply_construction(plan).ok and sim.cash == 400 and sim.capacity(2) == 2, "Day 2 furnishings add pool capacity for $100")
	_expect(sim.apply_construction(plan).ok and sim.cash == 400, "Existing terrace furnishings are charged only once")
	_tick(sim, Sim.DAY_LENGTH)
	_expect(_scores(sim).slice(4) == [100, 100, 98, 94], "Upgraded pool ratings include dining waits and completed beach activities")
	_tick(sim, Sim.DAY_LENGTH)
	_expect(sim.stopped and sim.cash == 1120 and sim.reviews.size() == 12, "Three-day recap balance and stay count")
	_expect(is_equal_approx(sim.average(), 1145.0 / 12.0) and sim.milestone.terrace, "Three-day recap rating and terrace")
	_tick(sim, 5)
	_expect(sim.cash == 1120 and sim.day == 3, "Time stays stopped at recap")
	sim.continue_after_recap()
	_expect(sim.day == 4 and sim.second == 0 and sim.milestone.stays == 12, "Day 4 preserves the milestone")


func _check_price_changes() -> void:
	var sim := Sim.new()
	sim.selected_package = 0
	_tick(sim, 20)
	sim.selected_package = 2
	_tick(sim, 100)
	_expect(sim.cash == 500 and sim.booked_package == 0, "Today's Budget bookings keep their price")
	_tick(sim, 120)
	_expect(sim.cash == 380 and not sim.terrace, "Budget closes with $380 and the original pool")
	_tick(sim, 28)
	_expect(sim.cash == 550 and sim.apply_construction(_terrace_plan(sim)).defer and sim.cash == 450, "Pending terrace reserves $100 after the first Premium check-in")
	_tick(sim, 172)
	_expect(sim.families.size() == 3 and sim.cash == 790, "Premium has three arrivals and $510 in revenue")


func _check_staff_transfer() -> void:
	var sim := Sim.new()
	sim.float_station = 2
	_tick(sim, 170)
	_expect(sim.families[3].waits[1] == 0 and sim.families[3].dining_wait == 24, "Counter and table wait remain distinct")
	_expect(sim.families.all(func(family: Dictionary) -> bool: return family.waits[2] == 0), "Pool float prevents pool waits")

	sim = Sim.new()
	_tick(sim, 55)
	_expect(sim.capacity(1) == 2 and sim.count_at(1, "service") == 1, "Buffet float expands counter capacity")
	var deadline: int = sim.families[1].until
	sim.float_station = 0
	_tick(sim, 1)
	_expect(sim.capacity(1) == 1 and sim.families[1].phase == "service" and sim.families[1].until == deadline, "Reassignment keeps current buffet service")
	_tick(sim, 4)
	_expect(sim.count_at(1, "service") == 0 and sim.count_at(1, "wait_table") == 1, "Table waiting releases the counter slot")
	_tick(sim, 2)
	_expect(sim.count_at(1, "service") == 1 and sim.count_at(1, "wait_table") == 1, "New collection uses the free slot while a family waits for a table")
	_tick(sim, 175)
	_expect(sim.rooms == [-1, -1, -1, -1] and sim.families[3].phase == "gone", "Transfer run clears before closing")


func _check_restore() -> void:
	var original := Sim.new()
	_tick(original, 106)
	_expect(original.count_at(2, "queue") == 1 and original.count_at(2, "service") == 1, "Checkpoint contains both active service and queue")
	original.selected_package = 2
	var restored := Sim.new()
	var state: Dictionary = bytes_to_var(var_to_bytes(original.snapshot()))
	_expect(restored.restore(state) and _same_state(restored.snapshot(), original.snapshot()), "Active simulation survives serialization")
	_tick(original, 134)
	_tick(restored, 134)
	_expect(_same_state(restored.snapshot(), original.snapshot()), "Loaded run posts each review and payroll once")
	var before := restored.snapshot()
	state.families[0].waits = [false, 0, 0]
	_expect(not restored.restore(state) and _same_state(restored.snapshot(), before), "Invalid wait records leave current state intact")
	state = original.snapshot()
	state.rooms = [-1, "bad", -1, -1]
	_expect(not restored.restore(state) and _same_state(restored.snapshot(), before), "Invalid room record leaves current state intact")
	state = original.snapshot()
	state.reviews[0].score = -5
	_expect(not restored.restore(state) and _same_state(restored.snapshot(), before), "Invalid review leaves current state intact")
	var occupied := Sim.new()
	_tick(occupied, 55)
	state = occupied.snapshot()
	state.families[0].station = 0
	_expect(not restored.restore(state) and _same_state(restored.snapshot(), before), "An occupied room cannot reenter check-in service")


func _tick(sim: Sim, seconds: int) -> void:
	for i in range(seconds):
		sim.tick()


func _scores(sim: Sim) -> Array:
	return sim.reviews.map(func(review: Dictionary) -> int: return review.score)


func _expect(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _terrace_plan(sim: Sim) -> Sim.Layout:
	var draft: Sim.Layout = sim.layout.duplicate_layout()
	var pool: Dictionary = draft.buildings.back()
	draft.add_asset("lounger", pool.id, Vector2i(1, 2))
	draft.add_asset("lounger", pool.id, Vector2i(16, 2))
	draft.add_asset("umbrella", pool.id, Vector2i(2, 7))
	return draft


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	# Object IDs are allocated globally and the allocator can advance during restore.
	left.layout.erase("next_id")
	right.layout.erase("next_id")
	return left == right
