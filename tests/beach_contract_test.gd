extends SceneTree
## Independent acceptance of real, editable leisure venues and safe guest completion.
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const KINDS := ["beach_lounge", "volleyball", "beach_bar", "stage"]
const ACTIVE := ["to_leisure", "leisure", "from_leisure"]
var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var sim := Sim.new()
	var amenities: Array = sim.layout.amenities()
	for kind: String in KINDS:
		var venues: Array = sim.layout.amenities(kind)
		check(not venues.is_empty(), "New resort includes usable " + kind)
		for venue: Dictionary in venues:
			check(sim.layout.landscape.rect_is_dry(venue.rect), "Venue footprint stays on dry land: " + kind)
			check(not sim.layout.route(Layout.ENTRY, venue.point).is_empty(), "Guests can reach actual venue access: " + kind)
			check(not venue.rect.has_point(venue.point), "Access point is outside the solid venue footprint: " + kind)
			check(sim.layout.amenity_by_id(venue.id) == venue, "Venue ID resolves to actual geometry: " + kind)
	var old_layout := Layout.new(false)
	check(old_layout.amenities().is_empty(), "Legacy layout construction does not inject free amenities into an existing design")
	var no_venues := Sim.new()
	var without_amenities: Layout = no_venues.layout.duplicate_layout()
	for venue: Dictionary in without_amenities.amenities():
		without_amenities.remove_prop(venue.id)
	check(no_venues.apply_construction(without_amenities).ok, "Removing all optional amenities still permits an operational hotel")
	var baseline := _observe(sim, true)
	var absent := _observe(no_venues, false)
	check(baseline.completed == 4 and absent.completed == 4, "Both equipped and amenity-free resorts complete every family stay")
	check(baseline.cash == 620 and absent.cash == 620, "Included activities do not create extra guest charges")
	for index in range(4):
		check(baseline.bonuses[index] > 0 and baseline.bonuses[index] <= 3, "Completed activities give a small capped satisfaction benefit")
		check(absent.bonuses[index] == 0 and baseline.scores[index] == mini(100, absent.scores[index] + baseline.bonuses[index]), "Activity benefit changes the review score by the displayed amount")
	for kind: String in KINDS:
		check(baseline.visits.has(kind), "A real guest participates in " + kind)
	check(absent.visits.is_empty(), "Removed venues are not visited as invisible attractions")
	var legacy := no_venues.snapshot()
	legacy.erase("leisure_version")
	for family: Dictionary in legacy.families:
		for key in family.keys():
			if key == "amenity_id" or str(key).begins_with("leisure_"):
				family.erase(key)
	for review: Dictionary in legacy.reviews:
		review.erase("leisure_bonus")
	var migrated := Sim.new()
	check(migrated.restore(legacy) and migrated.layout.amenities().is_empty(), "Pre-expansion save loads without silently adding venues")
	check(migrated.cash == no_venues.cash and migrated.reviews.all(func(r: Dictionary) -> bool: return r.leisure_bonus == 0), "Old balances and reviews migrate without unearned activity rewards")
	var original: Dictionary = amenities.filter(func(a: Dictionary) -> bool: return a.kind == "beach_bar")[0]
	var purchase: Layout = no_venues.layout.duplicate_layout()
	var bar_cell := Vector2i(original.rect.position / Layout.GRID)
	var bought := purchase.add_prop("beach_bar", bar_cell)
	check(bought.ok and no_venues.apply_construction(purchase).ok and no_venues.cash == 520, "Regular mode charges $100 for an actual newly placed bar")
	var removal: Layout = no_venues.layout.duplicate_layout()
	removal.remove_prop(bought.id)
	check(no_venues.apply_construction(removal).ok and no_venues.cash == 570, "Bulldozing a purchased bar refunds only half its paid cost")
	var free := Sim.new()
	free.mode = "developer"
	var free_plan: Layout = free.layout.duplicate_layout()
	free_plan.remove_prop(original.id)
	var free_bar := free_plan.add_prop("beach_bar", bar_cell)
	check(free_bar.ok and free.apply_construction(free_plan).ok and free.cash == 140, "Developer mode allows free bar construction")
	check(free.layout.landscape.prop_by_id(free_bar.id).paid_cost == 0, "Free bar construction cannot create a resale windfall")
	var edited: Layout = sim.layout.duplicate_layout()
	var moved := false
	for delta in [Vector2i(0, 6), Vector2i(-8, 0), Vector2i(0, -6), Vector2i(-8, 6), Vector2i(-16, 0)]:
		var prop: Dictionary = edited.landscape.prop_by_id(original.id)
		var target: Vector2i = Vector2i(prop.cell[0], prop.cell[1]) + delta
		if edited.move_prop(original.id, target).ok:
			moved = true
			break
	check(moved, "A placed bar can be moved through the existing editor model")
	if moved:
		var changed: Dictionary = edited.amenity_by_id(original.id)
		check(not changed.is_empty() and changed.point != original.point and changed.rect != original.rect, "Bar visitors follow its changed location")
		check(edited.quote_diff(sim.layout).net == 0, "Moving a starter bar does not invent a construction charge")
	var saved := edited.snapshot()
	var round_trip := Layout.new(false)
	check(round_trip.restore(bytes_to_var(var_to_bytes(saved))) and round_trip.amenities() == edited.amenities(), "Edited amenity positions and IDs survive layout serialization")
	var prohibited := edited.add_prop("beach_bar", Vector2i(90, 30))
	check(not prohibited.ok, "Beach amenities cannot be placed in the ocean")
	print("Beach contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _observe(sim: Sim, test_saves: bool) -> Dictionary:
	var visits := {}
	var checkpoints := {}
	var resumed: Array[Dictionary] = []
	var valid_capacity := true
	var valid_geometry := true
	var unique_slots := true
	for second in range(1, Sim.DAY_LENGTH):
		sim.tick()
		var reservations := {}
		var slots := {}
		for family: Dictionary in sim.families:
			if family.phase not in ACTIVE:
				continue
			var venue: Dictionary = sim.layout.amenity_by_id(family.amenity_id)
			valid_geometry = valid_geometry and not venue.is_empty()
			if venue.is_empty():
				continue
			valid_geometry = valid_geometry and venue.kind == family.leisure_kind
			reservations[venue.id] = reservations.get(venue.id, 0) + 1
			valid_capacity = valid_capacity and reservations[venue.id] <= venue.capacity
			var slot := Vector2i(venue.id, family.leisure_slot)
			unique_slots = unique_slots and not slots.has(slot) and family.leisure_slot >= 0 and family.leisure_slot < venue.capacity
			slots[slot] = true
			if family.phase == "leisure":
				visits[family.leisure_kind] = true
			var checkpoint: String = family.leisure_kind + ":" + family.phase
			if test_saves and not checkpoints.has(checkpoint):
				checkpoints[checkpoint] = true
				resumed.append(_resume(sim, family))
	check(valid_geometry, "Every active leisure visit references a real venue of the matching kind")
	check(valid_capacity and unique_slots, "Travel, activity and departure retain unique reservations within venue capacity")
	check(sim.families.all(func(f: Dictionary) -> bool: return f.phase == "gone"), "Leisure visitors still leave before the day ends")
	for family: Dictionary in sim.families:
		var unique := {}
		for kind: String in family.leisure_completed:
			unique[kind] = true
		check(unique.size() == family.leisure_completed.size(), "A family does not accumulate duplicate activity completions")
		var review: Dictionary = sim.reviews.filter(func(r: Dictionary) -> bool: return r.room == family.room)[0]
		check(review.leisure_bonus == mini(3, unique.size()), "Review bonus counts completed distinct activities, not visits that were only reserved")
	if test_saves:
		check(checkpoints.size() >= 8, "Save checkpoints cover different venue kinds as well as activity phases")
		for kind: String in ["beach_bar", "stage"]:
			for phase: String in ACTIVE:
				check(checkpoints.has(kind + ":" + phase), "Save exercised " + kind + " during " + phase)
		for outcome in resumed:
			check(outcome == _comparable(sim.snapshot()), "Saved leisure resumes to the exact uninterrupted end state")
	return {"visits": visits, "completed": sim.reviews.size(), "cash": sim.cash,
		"scores": sim.reviews.map(func(r: Dictionary) -> int: return r.score),
		"bonuses": sim.reviews.map(func(r: Dictionary) -> int: return r.leisure_bonus)}


func _resume(sim: Sim, family: Dictionary) -> Dictionary:
	var state := bytes_to_var(var_to_bytes(sim.snapshot())) as Dictionary
	var restored := Sim.new()
	check(restored.restore(state), "Save/load accepts leisure phase " + family.phase)
	check(_comparable(restored.snapshot()) == _comparable(sim.snapshot()), "Save retains exact venue, step, slot and timing")
	var corrupt := state.duplicate(true)
	corrupt.families[family.id].amenity_id = 99999999
	check(not restored.restore(corrupt) and _comparable(restored.snapshot()) == _comparable(state), "Nonexistent leisure venue is rejected transactionally")
	corrupt = state.duplicate(true)
	corrupt.families[family.id].leisure_slot = 100
	check(not restored.restore(corrupt) and _comparable(restored.snapshot()) == _comparable(state), "Out-of-range leisure slot is rejected transactionally")
	for second in range(sim.second + 1, Sim.DAY_LENGTH):
		restored.tick()
	return _comparable(restored.snapshot())


func _comparable(state: Dictionary) -> Dictionary:
	state.layout.erase("next_id")
	if not state.pending_layout.is_empty():
		state.pending_layout.erase("next_id")
	return state
