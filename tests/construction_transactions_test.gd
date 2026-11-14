extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func planted(sim: RefCounted) -> RefCounted:
	var draft = sim.layout.duplicate_layout()
	draft.add_asset("plant", draft.buildings[0].id, Vector2i(5, 2))
	return draft


func _initialize() -> void:
	var sim := Sim.new()
	var active_ids: Array = sim.layout.assets.map(func(a): return a.id)
	var result := sim.apply_construction(planted(sim))
	check(result.ok and not result.defer and sim.cash == 132, "Immediate regular purchase costs $8")
	check(sim.layout.assets[-1].paid_cost == 8, "Applied furniture records actual paid price")
	var removal = sim.layout.duplicate_layout()
	removal.remove_asset(removal.assets[-1].id)
	check(sim.apply_construction(removal).ok and sim.cash == 136, "Immediate demolition refunds half paid cost")
	check(sim.layout.assets.map(func(a): return a.id) == active_ids, "Demolition leaves starter furniture intact")
	var developer := Sim.new()
	developer.mode = "developer"
	developer.cash = -120
	check(developer.apply_construction(planted(developer)).ok and developer.cash == -120, "Developer construction free despite operating debt")
	check(developer.layout.assets[-1].paid_cost == 0, "Free furniture has no refundable purchase price")
	var saved_dev := Sim.new()
	check(saved_dev.restore(developer.snapshot()) and saved_dev.mode == "developer", "Developer mode survives save/load")
	var queued := Sim.new()
	for second in range(20):
		queued.tick()
	var draft = planted(queued)
	result = queued.apply_construction(draft)
	check(result.ok and result.defer and queued.cash == 132 and queued.pending_reserve == 8, "Occupied resort reserves next-day construction")
	check(queued.layout.assets.size() == 7 and queued.families.size() == 1, "Queued draft leaves live guests/layout unchanged")
	var replacement = queued.layout.duplicate_layout()
	replacement.add_asset("bench", replacement.buildings[0].id, Vector2i(3, 3))
	check(queued.apply_construction(replacement).ok and queued.cash == 125 and queued.pending_reserve == 15, "Replacement releases old reservation before charging new")
	var held_snapshot := queued.snapshot()
	queued.cash = 0
	var expensive = planted(queued)
	expensive.add_asset("bench", expensive.buildings[0].id, Vector2i(3, 3))
	check(not queued.apply_construction(expensive).ok and queued.cash == 0 and queued.pending_reserve == 15, "Rejected replacement preserves held reservation")
	check(queued.pending_layout.assets[-1].kind == "bench", "Rejected replacement retains existing plan")
	queued.restore(held_snapshot)
	var restored := Sim.new()
	check(restored.restore(queued.snapshot()) and restored.pending_reserve == 15, "Pending construction round-trips save/load")
	check(restored.cancel_construction() and restored.cash == 140 and restored.pending_layout == null, "Cancel returns reservation exactly")
	check(not restored.cancel_construction() and restored.cash == 140, "Second cancel cannot create money")
	var tampered := queued.snapshot()
	tampered.pending_reserve += 1
	check(not restored.restore(tampered), "Saved hold must match actual pending quote")
	while queued.day == 1:
		queued.tick()
	check(queued.cash == 485 and queued.pending_reserve == 0 and queued.pending_layout == null, "Next-day purchase charged once: 140 + 480 - 120 - 15")
	check(queued.layout.assets[-1].kind == "bench" and queued.layout.assets[-1].paid_cost == 15, "Next day applies and stamps paid furniture")
	for second in range(20):
		queued.tick()
	var demolish = queued.layout.duplicate_layout()
	demolish.remove_asset(demolish.assets[-1].id)
	var cash_before := queued.cash
	check(queued.apply_construction(demolish).ok and queued.cash == cash_before and queued.pending_reserve == 0, "Demolition refund deferred while guests stay")
	queued.cancel_construction()
	check(queued.cash == cash_before, "Canceled queued demolition pays no refund")
	queued.apply_construction(demolish)
	while queued.day == 2:
		queued.tick()
	check(queued.cash == cash_before + 480 - 120 + 7, "Actual demolition pays floor(half purchase price) once")
	var late := Sim.new()
	for second in range(235):
		late.tick()
	var smaller = late.layout.duplicate_layout()
	for building in smaller.buildings.duplicate():
		if building.kind == "bedroom" and building.id != smaller.buildings[0].id:
			smaller.remove_building(building.id)
	check(late.apply_construction(smaller).ok and late.rooms.size() == 1, "Post-checkout layout can shrink immediately")
	var smaller_restore := Sim.new()
	check(smaller_restore.restore(late.snapshot()), "Gone families referring to removed rooms do not break saves")
	while smaller_restore.day == 1:
		smaller_restore.tick()
	for second in range(20):
		smaller_restore.tick()
	check(smaller_restore.booked_count == 1, "Next day demand capped by remaining usable rooms")
	print("Construction transactions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
