extends SceneTree
const Layout = preload("res://scripts/layout_model.gd")
const Sim = preload("res://scripts/simulation.gd")
const Design = preload("res://scripts/resort_design.gd")
const CATEGORIES := ["buildings", "furniture", "facilities", "landscape"]
var checks := 0
var failures := 0
var design: Design


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	design = Design.new()
	root.add_child(design)
	await process_frame
	var original := Layout.new()
	for category: String in CATEGORIES:
		for venue: Dictionary in original.amenities():
			design.enter(original)
			design.choose("category", category)
			design.choose("tool", "select")
			design.press(venue.rect.get_center())
			check(design.selection.get("id") == venue.id and design.can_move(), "Select/move recognizes " + venue.kind + " from " + category)
			design.choose("bulldoze", null)
			check(design.press(venue.rect.get_center()) and design.draft.landscape.prop_by_id(venue.id).is_empty(), "Bulldoze removes " + venue.kind + " from " + category)
			check(not original.amenity_by_id(venue.id).is_empty(), "Draft demolition leaves the active venue unchanged until Apply")
		design.enter(original)
		design.choose("category", category)
		design.choose("tool", "select")
		var bed: Dictionary = design.draft.assets[0]
		var bed_point := design.draft.asset_rect(bed).get_center()
		design.press(bed_point)
		check(design.selection.get("id") == bed.id, "Furniture can be selected from " + category)
		design.choose("bulldoze", null)
		check(design.press(bed_point) and design.draft.asset_at(bed_point).is_empty() and not design.draft.building_at(bed_point).is_empty(), "Furniture demolition preserves its building from " + category)
		design.choose("tool", "select")
		var lobby: Dictionary = design.draft.buildings[4]
		var empty_floor := design.draft.building_rect(lobby).position + Vector2(12, 12)
		design.press(empty_floor)
		check(design.selected_building().get("id") == lobby.id, "Building settings remain available when selected from " + category)
		design.choose("bulldoze", null)
		check(design.press(empty_floor) and design.draft.building_by_id(lobby.id).is_empty(), "Empty floor selects the building for demolition from " + category)
		var scenery: Dictionary = design.draft.landscape.props[0]
		var scenery_point := design.draft.prop_rect(scenery).get_center()
		check(design.press(scenery_point) and design.draft.landscape.prop_by_id(scenery.id).is_empty(), "Ordinary scenery uses the same bulldozer from " + category)
	for kind: String in Sim.STARTER_LEISURE:
		for free in [false, true]:
			_test_purchase_and_remove(kind, free)
	_test_occupied_removal()
	design.queue_free()
	await process_frame
	print("Construction consistency: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_purchase_and_remove(kind: String, free: bool) -> void:
	var sim := Sim.new()
	sim.mode = "developer" if free else "regular"
	var starter: Dictionary = sim.layout.amenities(kind)[0]
	design.enter(sim.layout)
	design.choose("category", "buildings")
	design.choose("bulldoze", null)
	check(design.press(starter.rect.get_center()), "Starter " + kind + " is removable with the ordinary bulldozer")
	if not design.draft.amenity_by_id(starter.id).is_empty():
		return
	design.choose("category", "facilities")
	design.choose("prop", kind)
	for turn in range(starter.rotation):
		design.rotate_asset()
	check(design.press(starter.rect.position + Vector2(4, 4)), "A replacement " + kind + " is placeable through the construction controller")
	var price: int = 0 if free else Layout.Landscape.PROP_CATALOG[kind].cost
	check(sim.cash == 140 and sim.layout.amenity_by_id(starter.id) == starter, "Previewing a purchase does not charge cash or alter the active hotel")
	check(sim.construction_status(design.draft).cost == price and sim.apply_construction(design.draft).ok and sim.cash == 140 - price, "Apply charges the correct " + sim.mode + " price for " + kind)
	var purchased: Dictionary = sim.layout.amenities(kind)[0]
	check(purchased.id != starter.id and sim.layout.landscape.prop_by_id(purchased.id).paid_cost == price, "Purchased facility keeps its own identity and paid refund basis")
	design.enter(sim.layout)
	design.choose("category", "furniture")
	design.choose("bulldoze", null)
	check(design.press(purchased.rect.get_center()), "Purchased " + kind + " can be removed while the Furniture catalog is open")
	check(sim.construction_status(design.draft).refund == price / 2 and sim.apply_construction(design.draft).ok and sim.cash == 140 - price + price / 2, "Demolition refunds only half of the actual paid price")
	check(sim.layout.amenities(kind).is_empty(), "Applied demolition actually removes " + kind + " from guest destinations")


func _test_occupied_removal() -> void:
	var sim := Sim.new()
	var occupied := false
	while sim.second < 179:
		sim.tick()
		if sim.families.any(func(f: Dictionary) -> bool: return f.phase == "leisure" and f.leisure_kind == "beach_bar"):
			occupied = true
			break
	check(occupied, "Occupied-removal fixture reaches a real guest bar visit")
	var bar: Dictionary = sim.layout.amenities("beach_bar")[0]
	design.enter(sim.layout)
	design.choose("category", "furniture")
	design.choose("bulldoze", null)
	check(design.press(bar.rect.get_center()), "An occupied starter bar is removable in the design draft")
	var result := sim.apply_construction(design.draft)
	check(result.ok and result.defer and not sim.layout.amenity_by_id(bar.id).is_empty() and sim.pending_layout.amenity_by_id(bar.id).is_empty(), "Apply Tomorrow queues demolition while today's guests retain their venue")
	var resumed := Sim.new()
	check(resumed.restore(sim.snapshot()), "Queued facility demolition and its active guest visit survive save/load")
	while resumed.day == 1:
		resumed.tick()
	check(resumed.layout.amenity_by_id(bar.id).is_empty() and resumed.pending_layout == null and resumed.cash == 500, "Next day removes the bar without duplicate charges or an unearned starter refund")
