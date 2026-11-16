extends SceneTree
## Independent R10 acceptance of catalog purchases and real guest visits.
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const EXPECTED := {
	"lap_pool": {"size": Vector2i(12, 8), "cost": 160, "capacity": 2},
	"lagoon_pool": {"size": Vector2i(12, 10), "cost": 180, "capacity": 3},
	"hot_tub": {"size": Vector2i(5, 5), "cost": 100, "capacity": 1},
	"kids_pool": {"size": Vector2i(8, 7), "cost": 120, "capacity": 2},
	"waterpark": {"size": Vector2i(14, 11), "cost": 220, "capacity": 3},
	"basketball": {"size": Vector2i(10, 8), "cost": 100, "capacity": 2},
	"climbing_wall": {"size": Vector2i(7, 6), "cost": 100, "capacity": 1},
	"arcade": {"size": Vector2i(7, 5), "cost": 90, "capacity": 2},
	"cafe": {"size": Vector2i(8, 6), "cost": 60, "capacity": 2},
	"nightclub": {"size": Vector2i(10, 8), "cost": 140, "capacity": 4},
}
const ACTIVE := ["to_leisure", "leisure", "from_leisure"]
var checks := 0
var failures := 0


func _initialize() -> void:
	for kind: String in EXPECTED:
		check(Layout.Landscape.PROP_CATALOG.has(kind), "Catalog exposes " + kind)
		if not Layout.Landscape.PROP_CATALOG.has(kind):
			continue
		var data: Dictionary = Layout.Landscape.PROP_CATALOG[kind]
		var wanted: Dictionary = EXPECTED[kind]
		check(data.cost == wanted.cost and data.capacity == wanted.capacity, "Price and guest capacity match " + kind)
		for rotation in range(4):
			_check_venue(kind, rotation, false)
		_check_venue(kind, 0, true)
	var untouched := Sim.new()
	check(untouched.layout.amenities().size() == 4, "Expansion preserves the original starter layout")
	for venue: Dictionary in untouched.layout.amenities():
		check(not EXPECTED.has(venue.kind), "New venues are player choices, not injected into existing space")
	print("Activity expansion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _check_venue(kind: String, rotation: int, free: bool) -> void:
	var label := "%s at %d degrees%s" % [kind, rotation * 90, " (Developer)" if free else ""]
	var sim := Sim.new()
	sim.cash = 5000
	sim.set_swim_policy("closed")
	if free:
		sim.mode = "developer"
	var plan = sim.layout.duplicate_layout()
	# Isolate the attraction, keeping the real hotel/service geometry intact.
	for prop: Dictionary in plan.landscape.props.duplicate(true):
		plan.remove_prop(prop.id)
	var placed: Dictionary = plan.add_prop(kind, Vector2i(-12, -8), rotation)
	check(placed.ok, "Place " + label)
	if not placed.ok:
		return
	var price: int = 0 if free else EXPECTED[kind].cost
	check(plan.quote_diff(sim.layout, free).net == price, "Quote shows actual purchase cost: " + label)
	check(sim.apply_construction(plan).ok and sim.cash == 5000 - price, "Apply buys " + label)
	var prop: Dictionary = sim.layout.landscape.prop_by_id(placed.id)
	check(prop.paid_cost == price and prop.rotation == rotation, "Paid value and orientation persisted: " + label)
	var venues: Array = sim.layout.amenities(kind)
	check(venues.size() == 1, "Exactly one usable actual venue: " + label)
	if venues.is_empty():
		return
	var venue: Dictionary = venues[0]
	var cells: Vector2i = EXPECTED[kind].size
	var expected_size := Vector2(cells.y, cells.x) * Layout.GRID if rotation % 2 else Vector2(cells) * Layout.GRID
	check(venue.rect.size == expected_size, "Rotated footprint matches art contract: " + label)
	check(venue.capacity == EXPECTED[kind].capacity and sim.layout.landscape.rect_is_dry(venue.rect), "Capacity and dry foundation: " + label)
	check(not sim.layout.route(Layout.ENTRY, venue.point).is_empty() and not venue.rect.has_point(venue.point), "Real reachable entrance outside solid venue: " + label)
	var loaded_layout := Layout.new(false)
	check(loaded_layout.restore(bytes_to_var(var_to_bytes(sim.layout.snapshot()))) and loaded_layout.amenities(kind) == venues, "Placed attraction roundtrip: " + label)
	var relocation = sim.layout.duplicate_layout()
	var original_point: Vector2 = venue.point
	check(relocation.move_prop(placed.id, Vector2i(-12, 6), rotation).ok, "Relocate " + label)
	check(relocation.quote_diff(sim.layout, free).net == 0, "Relocation is free: " + label)
	var before_move: int = sim.cash
	check(sim.apply_construction(relocation).ok and sim.cash == before_move, "Commit relocation without a new purchase charge: " + label)
	venue = sim.layout.amenity_by_id(placed.id)
	check(not venue.is_empty() and venue.point != original_point and sim.layout.landscape.prop_by_id(placed.id).paid_cost == price, "Moved entrance and original paid basis remain valid: " + label)
	if venue.is_empty():
		return
	if not free:
		_observe(sim, venue, label)
	var before: int = sim.cash
	var removal = sim.layout.duplicate_layout()
	check(removal.remove_prop(placed.id).ok, "Bulldoze " + label)
	check(sim.apply_construction(removal).ok, "Apply demolition: " + label)
	check(sim.cash == before + floori(float(price) / 2.0), "Only paid cost is refunded: " + label)
	check(sim.layout.amenities(kind).is_empty(), "Demolition actually removes attraction: " + label)


func _observe(sim: RefCounted, venue: Dictionary, label: String) -> void:
	var seen := {}
	var restored_outcomes: Array[Dictionary] = []
	var capacity_ok := true
	var slots_ok := true
	var reservations_ok := true
	var night_ok := true
	for tick in range(239):
		sim.tick()
		var reserved := 0
		var used_slots := {}
		for family: Dictionary in sim.families:
			if family.phase not in ACTIVE:
				continue
			reservations_ok = reservations_ok and family.amenity_id == venue.id and family.leisure_kind == venue.kind
			if family.amenity_id != venue.id:
				continue
			reserved += 1
			slots_ok = slots_ok and not used_slots.has(family.leisure_slot) and family.leisure_slot >= 0 and family.leisure_slot < venue.capacity
			used_slots[family.leisure_slot] = true
			if venue.kind == "nightclub":
				night_ok = night_ok and sim.second >= Sim.SHOW_START
			if not seen.has(family.phase):
				seen[family.phase] = true
				var resumed := Sim.new()
				var accepted := resumed.restore(bytes_to_var(var_to_bytes(sim.snapshot())))
				check(accepted, "Save active " + family.phase + ": " + label)
				if accepted:
					for remaining in range(sim.second, 239):
						resumed.tick()
					restored_outcomes.append(_outcome(resumed))
		capacity_ok = capacity_ok and reserved <= venue.capacity
	check(reservations_ok and capacity_ok and slots_ok, "Reservations remain unique and within real venue capacity: " + label)
	for phase: String in ACTIVE:
		check(seen.has(phase), "Guests actually reach " + phase + ": " + label)
	check(night_ok, "Nightclub observes the night schedule: " + label)
	check(sim.families.all(func(f: Dictionary) -> bool: return f.phase == "gone") and sim.reviews.size() == 4, "All guest stays complete with " + label)
	check(sim.families.any(func(f: Dictionary) -> bool: return venue.kind in f.leisure_completed), "Activity completion recorded: " + label)
	for outcome: Dictionary in restored_outcomes:
		check(outcome == _outcome(sim), "Saved activity resumes to exact uninterrupted day end: " + label)


func _outcome(sim: RefCounted) -> Dictionary:
	return {"day": sim.day, "second": sim.second, "cash": sim.cash,
		"families": sim.families.duplicate(true), "reviews": sim.reviews.duplicate(true),
		"incidents": sim.ocean_incidents.duplicate(true)}
