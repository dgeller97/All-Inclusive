extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	_check_entry_points()
	var show := Sim.new()
	var starter := show.layout.snapshot()
	var configured := show.configure_new_run("developer")
	_check(configured, "Developer showcase is constructible on the expanded map")
	if configured:
		_check_catalog(show, starter)
		var opening := show.snapshot()
		_check(not show.configure_new_run("developer") and show.snapshot() == opening, "Fresh-run setup is single-use")
		_check_play_and_resume(show)
		_check_edits(opening)
	print("Developer showcase: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_entry_points() -> void:
	var regular := Sim.new()
	var first := regular.snapshot()
	_check(not regular.configure_new_run("unknown") and regular.snapshot() == first, "Unknown mode cannot change a fresh run")
	_check(regular.configure_new_run("regular") and regular.snapshot() == first, "Explicit Regular retains baseline layout and decisions")
	var legacy := Sim.new()
	var prop_count := legacy.layout.landscape.props.size()
	legacy.mode = "developer"
	_check(not legacy.showcase_enabled and legacy.layout.landscape.props.size() == prop_count, "Assigning Developer mode does not inject a showcase")
	var loaded := Sim.new()
	_check(loaded.restore(legacy.snapshot()) and not loaded.showcase_enabled and loaded.mode == "developer",
		"Pre-showcase Developer saves retain their layout and mode")
	_check(not loaded.configure_new_run("developer") and loaded.layout.landscape.props.size() == prop_count,
		"A restored opening-day run is not a fresh showcase")


func _check_catalog(show: Sim, starter: Dictionary) -> void:
	var layout := show.layout
	_check(show.mode == "developer" and show.showcase_enabled and show.showcase_coverage.is_empty(), "Fresh Developer enables real coverage with no seeded visits")
	_check(layout.buildings == starter.buildings and show.rooms.size() == 4 and show.cash == 140,
		"Opening hotel geometry, rooms, and cash retain their original state")
	_check(layout.readiness().ok and show.terrace and layout.dining_tables().size() >= 2,
		"Showcase has working facilities, a furnished terrace and two tables")
	for kind in Layout.ASSET_CATALOG:
		_check(layout.assets.any(func(asset: Dictionary) -> bool: return asset.kind == kind), "Placed furnishing " + kind)
	for kind in Layout.Landscape.PROP_CATALOG:
		var props := layout.landscape.props.filter(func(prop: Dictionary) -> bool: return prop.kind == kind)
		_check(not props.is_empty(), "Placed outdoor catalog item " + kind)
		if Sim.LEISURE_DURATIONS.has(kind):
			var amenities := layout.amenities(kind)
			_check(not amenities.is_empty() and not layout.route(Layout.ENTRY, amenities[0].point).is_empty(), "Reachable guest entrance for " + kind)
			if Layout.Landscape.PROP_CATALOG[kind].get("gate", false) and not amenities.is_empty():
				var gate := Vector2i((amenities[0].point / Layout.GRID).floor())
				_check(layout.landscape.path_at(gate) == "boardwalk", "Showcase boardwalk reaches " + kind)
	var entities := layout.buildings + layout.assets + layout.landscape.props
	_check(entities.all(func(entity: Dictionary) -> bool: return entity.paid_cost == 0), "Showcase assets carry no paid resale value")
	var restored := _roundtrip(show.snapshot())
	_check(restored != null and restored.showcase_enabled and restored.showcase_coverage.is_empty(), "Opening showcase restores its optional marker")


func _check_play_and_resume(show: Sim) -> void:
	var observed := {}
	var sampled := {}
	var replays: Array[Sim] = []
	for tick in range(Sim.FINAL_DAY * Sim.DAY_LENGTH):
		show.tick()
		for replay in replays:
			replay.tick()
		for family in show.families:
			if family.phase == "leisure":
				observed[family.leisure_kind] = true
			if family.phase not in Sim.LEISURE_PHASES or sampled.has(family.phase):
				continue
			sampled[family.phase] = true
			var loaded := _roundtrip(show.snapshot())
			_check(loaded != null and loaded.families == show.families and loaded.showcase_coverage == show.showcase_coverage,
				"Showcase restores active " + str(family.phase))
			if loaded:
				replays.append(loaded)
	_check(show.day == 3 and show.second == Sim.DAY_LENGTH and show.reviews.size() == 12, "Four stays per day finish through the opening recap")
	_check(observed.size() == Sim.LEISURE_DURATIONS.size() and show.showcase_coverage.size() == observed.size()
		and show.showcase_coverage.all(func(kind: String) -> bool: return observed.has(kind)),
		"Guests really visit and complete all 14 activities during the first three days")
	_check(sampled.size() == Sim.LEISURE_PHASES.size(), "Each real reservation phase was sampled")
	for replay in replays:
		_check(_same_run(show, replay), "A live activity save resumes to the same coverage, reviews, and cash")
	var finished := _roundtrip(show.snapshot())
	_check(finished != null and _same_run(show, finished), "Completed three-day showcase restores exact results")
	if not finished:
		return
	var original := finished.snapshot()
	for bad_marker in [null, {"completed": ["waterpark", "waterpark"]}, {"completed": ["unknown"]}, {"completed": true}, {"completed": [], "extra": 1}]:
		var bad := original.duplicate(true)
		bad.developer_showcase = bad_marker
		_check(not finished.restore(bad) and finished.snapshot() == original, "Malformed coverage marker is rejected atomically")
	var wrong_mode := original.duplicate(true)
	wrong_mode.mode = "regular"
	_check(not finished.restore(wrong_mode) and finished.snapshot() == original, "Regular saves cannot opt into the showcase marker")


func _check_edits(opening: Dictionary) -> void:
	var show := _roundtrip(opening)
	if show == null:
		return
	for tick in range(34):
		show.tick()
	var draft: Layout = show.layout.duplicate_layout()
	var removed: Dictionary = draft.amenities("hot_tub")[0]
	var moved: Dictionary = draft.amenities("arcade")[0]
	_check(draft.remove_prop(removed.id).ok and draft.move_prop(moved.id, Vector2i(-46, 61), 1).ok,
		"Showcase venue removal and relocation use ordinary construction across expanded land")
	var applied := show.apply_construction(draft)
	_check(applied.ok and applied.defer and show.pending_reserve == 0, "Occupied Developer edits can queue for free")
	var loaded := _roundtrip(show.snapshot())
	_check(loaded != null and loaded.pending_layout != null and loaded.showcase_enabled, "Queued edits and showcase mode save together")
	if loaded == null or loaded.pending_layout == null:
		return
	_check(loaded.layout.amenity_by_id(removed.id) == removed and loaded.pending_layout.amenity_by_id(removed.id).is_empty(),
		"Queued removal leaves today's original reservation site intact")
	for tick in range(Sim.DAY_LENGTH - loaded.second):
		loaded.tick()
	var relocated := loaded.layout.amenity_by_id(moved.id)
	_check(loaded.pending_layout == null and loaded.layout.amenities("hot_tub").is_empty() and not relocated.is_empty()
		and relocated.rotation == 1 and relocated.rect.position == Vector2(-368, 488), "Next day activates only the saved edited layout")
	var persisted := _roundtrip(loaded.snapshot())
	_check(persisted != null and persisted.layout.amenities("hot_tub").is_empty() and persisted.layout.amenity_by_id(moved.id) == relocated,
		"Reload never resurrects Developer objects or overwrites their restored locations")


func _roundtrip(data: Dictionary) -> Sim:
	var loaded := Sim.new()
	return loaded if loaded.restore(bytes_to_var(var_to_bytes(data))) else null


func _same_run(expected: Sim, actual: Sim) -> bool:
	return (actual.day == expected.day and actual.second == expected.second and actual.cash == expected.cash
		and actual.showcase_coverage == expected.showcase_coverage and actual.families == expected.families
		and actual.reviews == expected.reviews and actual.ocean_incidents == expected.ocean_incidents)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
