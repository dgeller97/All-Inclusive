extends SceneTree
## Backend save validation and boundary cases for localized arrivals and rescues.

const Sim := preload("res://scripts/simulation.gd")
const Drift := preload("res://scripts/sargassum_model.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_check_offshore_validation()
	_check_rescue_validation()
	_check_rescue_geometry()
	_check_rotated_pools()
	print("Coast state validation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_offshore_validation() -> void:
	var sim := Sim.new()
	sim.mode = "developer"
	sim.set_developer_sargassum_intensity(0)
	_check(sim.seed_sargassum_arrival(), "Forced birth schedules a live ledger record")
	sim.sargassum = 37
	var saved := sim.snapshot()
	var patch: Dictionary = saved.coast_runtime.offshore.back()
	_check(Drift.valid_rafts(saved.coast_runtime.offshore, 0, saved.coast_runtime.seed),
		"Canonical offshore records validate at birth")
	var broken := saved.duplicate(true)
	broken.coast_runtime.offshore.append(patch.duplicate())
	_check_rejected(sim, saved, broken, "Duplicate live patch ID")
	broken = saved.duplicate(true)
	broken.coast_runtime.offshore.back().row += 1
	_check_rejected(sim, saved, broken, "A forged landfall cannot disagree with the incoming trajectory")
	broken = saved.duplicate(true)
	broken.coast_runtime.offshore.back().size = Vector2(800.0, 500.0)
	_check_rejected(sim, saved, broken, "Forged patch size")
	broken = saved.duplicate(true)
	broken.coast_runtime.deposits[0].row = 720
	_check_rejected(sim, saved, broken, "Deposit outside the coastline")
	broken = saved.duplicate(true)
	broken.coast_runtime.deposits[1].row = broken.coast_runtime.deposits[0].row
	_check_rejected(sim, saved, broken, "Duplicate deposit row")
	broken = saved.duplicate(true)
	broken.coast_runtime.deposits[0].amount = 0
	_check_rejected(sim, saved, broken, "Empty deposit row")
	broken = saved.duplicate(true)
	broken.sargassum = 50
	_check_rejected(sim, saved, broken, "Legacy display amount contradicts saved shoreline mass")
	broken = saved.duplicate(true)
	broken.mode = "regular"
	_check_rejected(sim, saved, broken, "Developer-only intensity on a Regular save")
	broken = saved.duplicate(true)
	broken.coast_runtime.seed += 1
	_check_rejected(sim, saved, broken, "Changed save seed cannot rewrite in-flight patch outcomes")
	_check(not Drift.valid_rafts([patch], patch.lands_at, sim.sargassum_seed), "A patch is no longer active on its landfall tick")


func _check_rescue_validation() -> void:
	var sim := Sim.new()
	sim.mode = "developer"
	sim.float_station = 2
	_check(sim.hire_lifeguard("pool"), "Pool guard available for collision fixture")
	for step in range(170):
		sim.tick()
		if sim.count_at(2, "service") < 2 or not sim.start_rescue_drill():
			continue
		if sim.rescue.family >= 0:
			break
		for elapsed in range(Sim.RESCUE_DURATION):
			sim.tick()
	_check(not sim.rescue.is_empty() and sim.rescue.family >= 0 and sim.count_at(2, "service") >= 1,
		"Actual pool rescue overlaps another pool swimmer")
	if sim.rescue.is_empty() or sim.rescue.family < 0:
		return
	var saved := sim.snapshot()
	var broken := saved.duplicate(true)
	broken.coast_runtime.rescue.target += Vector2(80, 0)
	_check_rejected(sim, saved, broken, "Invalid victim world position")
	broken = saved.duplicate(true)
	broken.coast_runtime.rescue.phase = "tow"
	_check_rejected(sim, saved, broken, "Premature tow phase")
	broken = saved.duplicate(true)
	broken.coast_runtime.rescue = {}
	_check_rejected(sim, saved, broken, "Guest cannot be left in a rescue without a matching guard")
	broken = saved.duplicate(true)
	for swimmer: Dictionary in broken.families:
		if swimmer.phase == "service" and swimmer.station == 2:
			swimmer.slot = sim.rescue.slot
			break
	_check_rejected(sim, saved, broken, "Rescue and another swimmer cannot hold the same pool slot")
	var restored := Sim.new()
	_check(restored.restore(bytes_to_var(var_to_bytes(saved))) and restored.rescue == sim.rescue,
		"Combined rescue and independent pool reservation round-trip")


func _check_rescue_geometry() -> void:
	for site in ["beach", "pool"]:
		var sim := Sim.new()
		sim.mode = "developer"
		sim.cash = -5
		_check(sim.hire_lifeguard(site) and sim.start_rescue_drill(), "A real post starts an opening volunteer drill at " + site)
		_check(sim.cash == -5 and sim.lifeguard_payroll() == 0, "Free Developer hire and payroll work in debt")
		_check(sim.must_defer_construction(), "An opening volunteer still keeps the layout fixed during rescue")
		var saved := sim.snapshot()
		var dry := sim.rescue_positions(0.0)
		var distinct := true
		var swam := false
		for sample in range(20, 60):
			var at := sample / 10.0
			var pose := sim.rescue_positions(at)
			distinct = distinct and pose.guard.distance_to(pose.victim) >= 6.0
			swam = swam or pose.guard_swim
		var seated := sim.rescue_positions(float(Sim.RESCUE_DURATION))
		_check(dry.guard == sim.rescue.origin and not dry.guard_swim and dry.victim_swim and swam,
			"Guard at %s leaves a dry reachable seat and swims to a wet victim" % site)
		_check(distinct and seated.guard == sim.rescue.origin and seated.victim == sim.rescue.entry,
			"Tow keeps guest and guard distinct before an actual dry handoff and reseat at " + site)
		_check(sim.snapshot() == saved, "Sampling intermediate rescue poses does not mutate the underlying save")
		for step in range(Sim.RESCUE_DURATION):
			sim.tick()
		_check(sim.rescue_positions().is_empty() and not sim.must_defer_construction() \
			and sim.last_rescue.outcome == "drill_complete", "Only scheduled ticks finish the drill and release construction")


func _check_rotated_pools() -> void:
	for turn in range(4):
		var sim := Sim.new()
		sim.mode = "developer"
		for building: Dictionary in sim.layout.buildings.duplicate():
			if building.kind == "pool":
				sim.layout.remove_building(building.id)
		var size := Vector2(144, 80) if turn % 2 == 0 else Vector2(80, 144)
		var placed: Dictionary = sim.layout.add_building("pool", Rect2(Vector2(-352, 240), size), turn)
		var started: bool = placed.ok and sim.hire_lifeguard("pool") and sim.start_rescue_drill()
		_check(started, "The %d° rebuilt pool still provides a valid rescue post" % (turn * 90))
		if not started:
			continue
		var building: Dictionary = sim.layout.building_by_id(placed.id)
		var water: Rect2 = sim.layout.water_rect(building)
		var route: PackedVector2Array = sim.layout.route(sim.rescue.origin, sim.rescue.entry)
		var swimming := sim.rescue_positions(2.0)
		var dry_exit := sim.rescue_positions(5.0)
		_check(route.size() >= 2 and not water.has_point(sim.rescue.origin) and water.has_point(swimming.victim) \
			and dry_exit.victim == sim.layout.door_point(building) and not dry_exit.victim_swim,
			"The %d° rotated basin targets its own water and dry pool exit" % (turn * 90))


func _check_rejected(sim: Sim, good: Dictionary, bad: Dictionary, label: String) -> void:
	_check(not sim.restore(bad) and sim.snapshot() == good, label + " rejects without observable state mutation")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
