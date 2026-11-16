extends SceneTree
## Independent public behavior, live save continuations and arrival accounting.
const Sim = preload("res://scripts/simulation.gd")
const Sargassum = preload("res://scripts/sargassum_model.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	_controls_and_arrivals()
	_repeated_controls()
	_economy()
	_rescues()
	print("Revision 18 independent acceptance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _developer() -> RefCounted:
	var sim := Sim.new()
	# Deliberately use the original hotel for isolated environment/staff checks.
	# Fresh showcase initialization is covered by the routed UI and existing tests.
	sim.mode = "developer"
	return sim


func _step(sim: RefCounted) -> void:
	if sim.stopped:
		sim.continue_after_recap()
	sim.tick()


func _mass(piles: Array) -> int:
	var total := 0
	for pile: Dictionary in piles:
		total += pile.amount
	return total


func _controls_and_arrivals() -> void:
	var regular := Sim.new()
	var initial: Dictionary = regular.snapshot()
	check(not regular.set_developer_month(7) and not regular.set_developer_sargassum_intensity(100)
		and not regular.seed_sargassum_arrival() and not regular.start_rescue_drill(), "Regular rejects all Developer actions")
	check(regular.snapshot() == initial, "Rejected Developer actions preserve the Regular run")
	var sim := _developer()
	check(sim.set_developer_sargassum_intensity(0), "Developer can stop new natural cohorts")
	for tick in range(25):
		_step(sim)
	var before: Dictionary = sim.snapshot()
	var existing: Array = sim.get("_offshore").duplicate(true)
	check(sim.set_developer_month(7) and sim.calendar_state().month == 7, "Developer selects actual July climate")
	check(sim.day == before.day and sim.second == before.second and sim.cash == before.cash
		and sim.families == before.families and sim.booked_count == before.booked_count, "Month selection preserves active guests, bookings, clock and cash")
	check(sim.get("_offshore") == existing, "Month changes preserve existing trajectories with births disabled")
	check(not sim.set_developer_month(13) and not sim.set_developer_sargassum_intensity(101)
		and not sim.set_developer_sargassum_intensity(-2), "Out-of-range controls reject")
	check(sim.seed_sargassum_arrival(), "Force action creates a real incoming patch")
	check(not sim.seed_sargassum_arrival(), "Same-second repeated force cannot duplicate a patch ID")
	var records: Array = sim.get("_offshore").duplicate(true)
	var forced: Dictionary = records.back()
	var old_mass := _mass(sim.beach_deposits)
	var expected_mass := old_mass
	for record: Dictionary in records:
		expected_mass += record.mass
	var restored := Sim.new()
	check(restored.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Restore live offshore cohorts and month controls")
	var same := true
	for tick in range(120):
		_step(sim)
		_step(restored)
		if sim.snapshot() != restored.snapshot() or sim.floating_sargassum() != restored.floating_sargassum():
			same = false
	check(same, "Every live tick after load matches uninterrupted arrival and hotel progression")
	check(sim.get("_offshore").is_empty() and _mass(sim.beach_deposits) == expected_mass,
		"Each recorded patch deposits its exact mass once; no unseen arrivals")
	check(sim.beach_deposits.any(func(pile: Dictionary) -> bool: return pile.row == forced.row and pile.amount >= forced.mass),
		"Forced patch deposits at its own landfall row")
	check(sim.seed_sargassum_arrival(), "Start a second incoming patch while beach has deposits")
	var offshore_before: Array = sim.floating_sargassum().duplicate(true)
	var clean: Dictionary = sim.clean_beach()
	check(clean.ok and _mass(sim.beach_deposits) == 0 and sim.floating_sargassum() == offshore_before,
		"Cleanup removes only deposited mass and preserves live incoming patch")
	check(sim.set_developer_month(0) and sim.calendar_state() == Sim.Calendar.state(sim.day, sim.second), "Auto restores natural calendar without advancing time")
	var widths := {}
	var fronts := {}
	for birth in range(0, 1400, 7):
		var patch: Dictionary = Sargassum.raft(birth, 0, sim.sargassum_seed)
		widths[int(patch.size.x)] = true
		fronts[int(patch.weather * 10)] = true
	check(widths.size() >= 20 and fronts.size() >= 5, "Seeded field produces broad patch sizes and improving/worsening fronts")


func _repeated_controls() -> void:
	var sim := _developer()
	for tick in range(100):
		sim.set_developer_sargassum_intensity(99 if tick % 2 else 100)
		sim.seed_sargassum_arrival()
		_step(sim)
	var loaded := Sim.new()
	check(loaded.restore(bytes_to_var(var_to_bytes(sim.snapshot()))), "Frequent legitimate control changes remain serializable")
	check(loaded.snapshot() == sim.snapshot(), "High-cohort save restores without silently dropping arrivals")


func _economy() -> void:
	var sim := Sim.new()
	sim.cash = 59
	check(not sim.hire_lifeguard("beach") and sim.cash == 59, "Insufficient hire cash rejects without charge")
	sim.cash = 140
	check(sim.hire_lifeguard("beach") and sim.cash == 80, "Regular hire charges exactly sixty")
	check(not sim.hire_lifeguard("pool") and sim.cash == 80, "Second hire cannot create a duplicate guard or extra charge")
	check(sim.assign_lifeguard("pool") and sim.cash == 80, "Idle reassignment changes coverage without charge")
	for tick in range(Sim.DAY_LENGTH):
		_step(sim)
	check(sim.day == 2 and sim.cash == 415, "First-day cash includes actual bookings and base120 plus guard25 payroll")
	var dev := _developer()
	dev.cash = -50
	check(dev.hire_lifeguard("pool") and dev.cash == -50 and dev.lifeguard_payroll() == 0, "Developer guard hire and added payroll stay free even in debt")


func _rescues() -> void:
	for site: String in ["beach", "pool"]:
		var volunteer := _developer()
		check(not volunteer.start_rescue_drill(), site + " drill requires a hired assigned guard")
		check(volunteer.hire_lifeguard(site) and volunteer.start_rescue_drill(), site + " volunteer drill starts")
		check(volunteer.rescue.family == -1 and volunteer.rescue.drill, site + " empty resort uses explicit volunteer identity")
		_verify_rescue(volunteer, site + " volunteer")
		check(volunteer.reviews.is_empty() and volunteer.last_rescue.outcome == "drill_complete", site + " volunteer does not invent completed stays")
		var actual := _developer()
		actual.set_swim_policy("allow_red")
		actual.hire_lifeguard(site)
		var found := false
		for tick in range(190):
			_step(actual)
			for family: Dictionary in actual.families:
				var at_site: bool = family.phase == "ocean_swim" if site == "beach" else family.phase == "service" and family.station == 2
				if at_site and actual.second - family.since >= 2 and family.until - actual.second >= 3 and actual.rescue.is_empty():
					found = actual.start_rescue_drill()
					break
			if found:
				break
		check(found and actual.rescue.get("family", -1) >= 0, site + " drill uses a real currently swimming family when eligible")
		if found:
			_verify_rescue(actual, site + " real guest")
		while actual.day == 1:
			_step(actual)
		check(actual.reviews.size() == 4 and actual.families.is_empty(), site + " rescued family reaches normal checkout with no lost stay")
		var natural := Sim.new()
		natural.hire_lifeguard(site)
		natural.set_swim_policy("allow_red" if site == "beach" else "closed")
		var natural_count := 0
		for tick in range(Sim.DAY_LENGTH * 7):
			_step(natural)
			if not natural.rescue.is_empty() and natural.rescue.started_at == natural.second:
				natural_count += 1
				check(not natural.rescue.drill and natural.rescue.family >= 0 and natural.rescue.site == site,
					site + " ordinary gameplay produces a real distress rescue")
				if natural_count == 1:
					_verify_rescue(natural, site + " natural incident")
		check(natural_count > 0, site + " natural rescue is not only a Developer animation")
	var late := _developer()
	late.hire_lifeguard("beach")
	for tick in range(237):
		_step(late)
	var late_before: Dictionary = late.snapshot()
	check(not late.start_rescue_drill() and late.snapshot() == late_before, "Late drill cannot strand a rescue across day cleanup")
	var legacy: Dictionary = late.snapshot()
	legacy.erase("coast_runtime")
	legacy.sargassum = 37
	var migrated := Sim.new()
	check(migrated.restore(bytes_to_var(var_to_bytes(legacy))) and migrated.sargassum == 37
		and _mass(migrated.beach_deposits) == 3700 and migrated.lifeguard_assignment.is_empty(),
		"Pre-ledger save migrates exact legacy buildup without injecting a hired guard")
	check(migrated.day == late.day and migrated.second == late.second and migrated.families == late.families,
		"Legacy environment migration preserves live guest progression")


func _verify_rescue(sim: RefCounted, label: String) -> void:
	var original: Dictionary = sim.snapshot()
	check(not sim.assign_lifeguard("pool" if sim.lifeguard_assignment == "beach" else "beach")
		and not sim.start_rescue_drill() and sim.snapshot() == original, label + " busy guard cannot teleport or start concurrent rescue")
	var broken := original.duplicate(true)
	broken.coast_runtime.rescue.family = 999
	check(not sim.restore(broken) and sim.snapshot() == original, label + " malformed rescue rejects transactionally")
	var observed := {}
	var shadows: Array[Dictionary] = []
	var finite_poses := true
	for tick in range(20):
		if not sim.rescue.is_empty():
			var record: Dictionary = sim.rescue
			var phase: String = "return" if sim.second >= record.drop_at else record.phase
			var pose: Dictionary = sim.rescue_positions(float(sim.second) + 0.5)
			finite_poses = finite_poses and pose.guard.is_finite() and pose.victim.is_finite() and pose.child.is_finite()
			if not observed.has(phase):
				var shadow := Sim.new()
				var accepted: bool = shadow.restore(bytes_to_var(var_to_bytes(sim.snapshot())))
				check(accepted, label + " saves active " + phase)
				if accepted:
					shadows.append({"sim": shadow, "remaining": 10, "phase": phase})
				observed[phase] = true
		_step(sim)
		for shadow: Dictionary in shadows.duplicate():
			_step(shadow.sim)
			shadow.remaining -= 1
			if shadow.remaining == 0:
				check(shadow.sim.snapshot() == sim.snapshot(), label + " " + shadow.phase + " reload matches live uninterrupted hotel")
				shadows.erase(shadow)
	check(observed.has("swim_out") and observed.has("tow") and observed.has("return") and finite_poses,
		label + " has finite outbound/contact/tow/return geometry")
	check(sim.rescue.is_empty() and not sim.last_rescue.is_empty(), label + " finishes and returns the guard to duty")
