extends SceneTree

const Layout = preload("res://scripts/layout_model.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var active := Layout.new()
	check(active.buildings[0].display_name == "Room A" and active.buildings[3].display_name == "Room D", "Starter bedrooms have stable readable names")
	check(active.buildings[4].display_name == "Lobby" and active.buildings[5].display_name == "Restaurant", "Public buildings receive lobby and restaurant names")
	var draft: Layout = active.duplicate_layout()
	var id: int = draft.buildings[5].id
	check(draft.set_building_name(id, "  Sunset Bistro  ").ok and draft.building_by_id(id).display_name == "Sunset Bistro", "Name editing trims edges")
	check(draft.quote_diff(active).net == 0, "Naming a building is free")
	check(active.building_by_id(id).display_name == "Restaurant", "Draft name does not change active hotel")
	for invalid in ["", "   ", "A".repeat(25), "First\nSecond", "Tabbed\tName", "Line" + char(0x2028) + "Break", "Bad" + char(127)]:
		check(not draft.set_building_name(id, invalid).ok and draft.building_by_id(id).display_name == "Sunset Bistro", "Invalid name rejected without losing existing name")
	check(draft.set_building_name(id, "Café Côte d’Azur").ok, "Printable Unicode building names accepted")
	check(draft.set_building_name(id, "A".repeat(24)).ok, "Exact name length limit accepted")
	check(not draft.set_building_name(-1, "Lobby").ok, "Unknown building name target rejected")
	check(draft.set_building_finish(id, "floor", "tile").ok and draft.quote_diff(active).cost == 12, "Regular floor change costs $12")
	draft.set_building_finish(id, "floor", "wood")
	check(draft.quote_diff(active).cost == 12, "Cycling finishes charges final choice once")
	draft.set_building_finish(id, "floor", "default")
	check(draft.quote_diff(active).cost == 0, "Returning draft to original finish cancels quote")
	for selection in [["floor", "stone"], ["wall", "brick"], ["ceiling", "beams"]]:
		check(draft.set_building_finish(id, selection[0], selection[1]).ok, "Each surface has an independent finish choice")
	check(draft.quote_diff(active).cost == 30 and draft.quote_diff(active, true).cost == 0, "Regular charges $30 for all surfaces, Developer charges zero")
	check(not draft.set_building_finish(id, "roof", "wood").ok, "Roof is not incorrectly treated as ceiling")
	check(not draft.set_building_finish(id, "wall", "water").ok, "Unknown finish choice rejected")
	var pool: Dictionary = draft.buildings[-1]
	check(draft.set_building_name(pool.id, "Lagoon Pool").ok and not draft.set_building_finish(pool.id, "ceiling", "panels").ok, "Outdoor pool has an editable name but no enclosed-building finishes")
	check(draft.readiness() == active.readiness() and draft.route(Layout.ENTRY, draft.station_point(1)) == active.route(Layout.ENTRY, active.station_point(1)), "Appearance changes preserve capacity and navigation")
	var restored := Layout.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(draft.snapshot()))), "Names and finishes JSON round trip")
	check(restored.building_by_id(id).display_name == "A".repeat(24) and restored.building_by_id(id).finishes == draft.building_by_id(id).finishes, "All independent finish selections and name survive save")
	var good := restored.buildings.duplicate(true)
	for corruption in ["missing", "unknown", "bad_name", "pool"]:
		var bad := draft.snapshot()
		match corruption:
			"missing": bad.buildings[0].erase("finishes")
			"unknown": bad.buildings[0].finishes.floor = "missing_texture"
			"bad_name": bad.buildings[0].display_name = "two\nlines"
			"pool": bad.buildings[-1].finishes.wall = "brick"
		check(not restored.restore(bad) and restored.buildings == good, "Malformed new metadata rejects save atomically")
	var old := active.snapshot()
	old.version = 2
	for building in old.buildings:
		building.erase("display_name")
		building.erase("finishes")
	check(restored.restore(old) and restored.buildings[4].display_name == "Lobby", "Old layouts acquire default names without deleting geometry")
	check(restored.quote_diff(active).net == 0, "Default finish migration adds no construction surcharge")
	var added: Layout = active.duplicate_layout()
	var new_room := added.add_building("bedroom", Rect2(304, 0, 48, 48))
	check(new_room.ok and added.building_by_id(new_room.id).display_name == "Room E", "New rooms receive first unused default name")
	added.set_building_finish(new_room.id, "wall", "timber")
	check(added.quote_diff(active).cost == 170, "New building includes only nondefault selected finish surcharge")
	var sim := Sim.new()
	var plan: Layout = sim.layout.duplicate_layout()
	var room_id: int = plan.buildings[0].id
	plan.set_building_finish(room_id, "floor", "wood")
	check(sim.apply_construction(plan).ok and sim.cash == 128, "Finish changes charge through real construction transactions")
	check(sim.layout.building_by_id(room_id).paid_cost == 0, "Redecoration does not inflate building demolition refund")
	for second in range(20):
		sim.tick()
	var tomorrow: Layout = sim.layout.duplicate_layout()
	tomorrow.set_building_name(room_id, "Family Suite")
	tomorrow.set_building_finish(room_id, "ceiling", "panels")
	check(sim.apply_construction(tomorrow).ok and sim.cash == 120 and sim.pending_reserve == 8, "Occupied hotel queues name and finish edits with exact reservation")
	check(sim.layout.building_by_id(room_id).display_name == "Room A", "Queued rename leaves live guests' building unchanged until applied")
	var reloaded := Sim.new()
	check(reloaded.restore(sim.snapshot(), false, true), "Queued named and styled building restores through Sim")
	while reloaded.day == 1:
		reloaded.tick()
	check(reloaded.cash == 480 and reloaded.layout.building_by_id(room_id).display_name == "Family Suite" and reloaded.layout.building_by_id(room_id).finishes.ceiling == "panels", "Next day applies name and ceiling without charging twice")
	var repaint: Layout = reloaded.layout.duplicate_layout()
	repaint.set_building_finish(room_id, "floor", "default")
	check(repaint.quote_diff(reloaded.layout).cost == 12 and repaint.quote_diff(reloaded.layout).refund == 0, "Repainting a purchased finish costs its surface price with no resale refund")
	print("Building identity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
