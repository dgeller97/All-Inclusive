extends SceneTree

const Layout = preload("res://scripts/layout_model.gd")
const Landscape = preload("res://scripts/landscape_model.gd")
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
	check(active.landscape.props.size() == 71 and active.amenities().size() == 4, "All 67 scenery objects and four starter amenities are present and editable")
	check(active.readiness().ok and active.room_points().size() == 4, "Default landscaping preserves working resort")
	check(active.landscape.path_at(Vector2i(10, 30)) == "stone", "Original promenade is model path data")
	var draft: Layout = active.duplicate_layout()
	var cell := Vector2i(0, 0)
	check(draft.paint_landscape_stroke("terrain", "sand", [cell, cell]).ok, "Terrain brush accepts repeated stroke cells")
	check(draft.landscape.terrain_at(cell) == "sand" and active.landscape.terrain_at(cell) != "sand", "Terrain edits affect draft only")
	check(draft.quote_diff(active).cost == 1, "Repeated terrain touches are quoted once")
	check(draft.paint_landscape_stroke("path", "stone", [cell]).ok, "Path can overlay painted ground")
	check(draft.quote_diff(active).cost == 3, "Terrain and path construction costs combine")
	check(draft.paint_landscape_stroke("path", "", [cell]).ok and draft.landscape.terrain_at(cell) == "sand", "Erase path reveals preserved ground")
	check(draft.quote_diff(active).cost == 1, "Erased draft path is not charged")
	check(draft.paint_landscape_stroke("restore", "", [cell]).ok and draft.quote_diff(active).net == 0, "Restore baseline cancels draft surface expense")
	var before := draft.snapshot()
	check(not draft.paint_landscape_stroke("terrain", "sand", [Vector2i(0, 0), Vector2i(4, 7)]).ok, "Stroke touching a building is rejected atomically")
	check(draft.snapshot() == before, "Failed stroke leaves all cells unchanged")
	check(not draft.paint_landscape_stroke("terrain", "water", [Vector2i(7, 34)]).ok, "Water cannot cover guest entrance")
	check(not draft.paint_landscape_stroke("terrain", "water", [cell]).ok and not draft.landscape.is_water_pixel(Vector2(4, 4)), "Water painting is unavailable even on inland ground")
	check(draft.landscape.cell_is_dry(cell), "Rejected water painting preserves navigation")
	var ocean_cell := Vector2i(75, 0)
	check(not draft.paint_landscape_stroke("path", "boardwalk", [ocean_cell]).ok, "Paths cannot bridge protected water")
	check(not draft.add_prop("palm", ocean_cell).ok, "Scenery cannot float on protected ocean")
	check(active.landscape.is_water_pixel(Vector2(604, 4)), "Chosen ocean site starts wet")
	check(not draft.paint_landscape_stroke("terrain", "grass", [ocean_cell]).ok, "Land painting cannot reclaim ocean")
	check(not draft.landscape.cell_is_dry(ocean_cell) and draft.landscape.is_water_pixel(Vector2(604, 4)), "Original ocean remains wet")
	check(not draft.paint_landscape_stroke("restore", "", [ocean_cell]).ok and draft.landscape.is_water_pixel(Vector2(604, 4)), "Restore brush respects protected ocean")
	check(draft.route(Vector2(4, 4), Vector2(604, 4)).is_empty(), "Guest navigation cannot enter ocean")
	draft.paint_landscape_stroke("terrain", "sand", [cell])
	var original_prop: Dictionary = draft.landscape.props[0]
	var id: int = original_prop.id
	check(draft.prop_at(draft.prop_rect(original_prop).get_center()).id == id, "Scenery footprint is selectable")
	check(draft.move_prop(id, Vector2i(-10, 12)).ok and draft.landscape.prop_by_id(id).paid_cost == 0, "Moving original tree preserves identity and zero paid basis")
	check(draft.remove_prop(id).ok and draft.landscape.prop_by_id(id).is_empty(), "Existing scenery can be bulldozed")
	var palm := draft.add_prop("palm", Vector2i(-10, 12))
	check(palm.ok, "New tree can be placed on clear land")
	check(not draft.add_prop("rock", Vector2i(-10, 12)).ok, "Scenery footprint collision rejected")
	check(not draft.paint_landscape_stroke("terrain", "water", [Vector2i(-10, 12)]).ok, "Water cannot cover existing tree")
	check(not draft.paint_landscape_stroke("path", "stone", [Vector2i(-10, 12)]).ok, "Paths cannot run through tree trunks")
	var tree_route := draft.route(Vector2(-84, 100), Vector2(-68, 100))
	check(not tree_route.is_empty() and not tree_route.has(Vector2(-76, 100)), "Guests navigate around scenery footprint")
	var copy = Layout.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(draft.snapshot()))), "Terrain/path/prop JSON save round trip")
	check(copy.landscape.terrain_at(cell) == "sand" and copy.landscape.prop_by_id(palm.id).kind == "palm", "Restored land painting and tree retain actual state")
	var invalid: Dictionary = draft.snapshot()
	invalid.landscape.terrain.append([999, 0, "sand"])
	check(not copy.restore(invalid), "Out-of-map saved terrain rejected")
	check(copy.landscape.terrain_at(cell) == "sand", "Failed landscape restore preserves previous state")
	invalid = draft.snapshot()
	invalid.landscape.props[0].cell = [4, 7]
	check(not copy.restore(invalid), "Saved scenery overlapping building rejected")
	invalid = active.snapshot()
	invalid.landscape.terrain = [[10, 30, "water"]]
	check(not copy.restore(invalid), "Saved water beneath default path rejected")
	var legacy := active.snapshot()
	legacy.erase("landscape")
	legacy.version = 1
	check(copy.restore(legacy) and copy.landscape.props.size() == 67, "R3 layout gains editable default scenery safely")
	var old_custom: Layout = active.duplicate_layout()
	var new_room_rect := Rect2(304, 56, 48, 48)
	for prop in old_custom.landscape.props.duplicate():
		if new_room_rect.intersects(old_custom.prop_rect(prop)):
			old_custom.remove_prop(prop.id)
	var old_room := old_custom.add_building("bedroom", new_room_rect)
	check(old_room.ok and old_custom.add_asset("bed", old_room.id, Vector2i(1, 1)).ok, "Construct legacy custom room over a formerly baked tree")
	var old_data := old_custom.snapshot()
	old_data.erase("landscape")
	old_data.version = 1
	check(copy.restore(old_data) and copy.room_points().size() == 5 and copy.landscape.props.size() >= 60, "Legacy occupied tree site pruned without deleting user building or distant scenery")
	check(copy.building_at(Vector2(340, 60)).id == old_room.id, "Migrated custom bedroom identity preserved")
	invalid = active.snapshot()
	invalid.landscape.props[0].id = invalid.buildings[0].id
	check(not copy.restore(invalid), "Saved scenery ID cannot collide with a building ID")
	invalid = active.snapshot()
	invalid.landscape.terrain = [[0, 0, "sand"], [0, 0, "grass"]]
	check(not copy.restore(invalid), "Duplicate saved terrain cells rejected")
	var shoreline := Landscape.SHORE.get_image()
	var mixed_cell := Vector2i.ZERO
	var dry_pixel := Vector2.ZERO
	var wet_pixel := Vector2.ZERO
	for row in range(shoreline.get_height()):
		var encoded := shoreline.get_pixel(0, row)
		var shore_x := Landscape.WORLD_ORIGIN.x + encoded.r8 + (encoded.g8 << 8)
		if posmod(shore_x, 8) in [2, 3, 4, 5, 6]:
			var y := Landscape.WORLD_ORIGIN.y + row
			mixed_cell = Vector2i(floor(float(shore_x) / 8), floor(float(y) / 8))
			dry_pixel = Vector2(shore_x - 1, y)
			wet_pixel = Vector2(shore_x, y)
			break
	var coast_edit: Layout = active.duplicate_layout()
	check(not coast_edit.landscape.is_water_pixel(dry_pixel) and coast_edit.landscape.is_water_pixel(wet_pixel), "Original curved coast retains exact pixel land/water boundary")
	check(not coast_edit.paint_landscape_stroke("terrain", "sand", [mixed_cell]).ok and coast_edit.landscape.is_water_pixel(wet_pixel), "Painting partly wet shore cells cannot alter the coast")
	check(coast_edit.quote_diff(active).cost == 0, "Rejected coastal edits are never charged")
	check(not coast_edit.paint_landscape_stroke("restore", "", [mixed_cell]).ok and coast_edit.landscape.is_water_pixel(wet_pixel) and not coast_edit.landscape.is_water_pixel(dry_pixel), "Restore leaves original curved coast intact")
	invalid = active.snapshot()
	invalid.landscape.terrain = [[0, 0, "water"]]
	check(Landscape.has_protected_water_edits(invalid.landscape) and not copy.restore(invalid), "Prior inland water edits rejected transactionally")
	invalid.landscape.terrain = [[75, 0, "grass"]]
	check(Landscape.has_protected_water_edits(invalid.landscape) and not copy.restore(invalid), "Prior reclaimed ocean edits rejected transactionally")
	invalid.landscape.terrain = [[75, 0, "water"]]
	check(not Landscape.has_protected_water_edits(invalid.landscape) and copy.restore(invalid) and copy.landscape.terrain_overrides.is_empty(), "Harmless unchanged open-ocean override normalizes safely")
	invalid.landscape.paths = [[mixed_cell.x, mixed_cell.y, "stone"]]
	check(Landscape.has_protected_water_edits(invalid.landscape) and not copy.restore(invalid), "Saved path cannot bypass protected partial coast")
	var shoreline_before := coast_edit.snapshot()
	check(not coast_edit.paint_landscape_stroke("terrain", "sand", [Vector2i(0, 0), mixed_cell]).ok and coast_edit.snapshot() == shoreline_before, "Mixed land/coast brush stroke rejects atomically")
	var paid_sim := Sim.new()
	var purchase = paid_sim.layout.duplicate_layout()
	purchase.add_prop("palm", Vector2i(0, 0))
	check(paid_sim.apply_construction(purchase).ok and paid_sim.cash == 125, "Regular mode charges for new scenery")
	var paid_id: int = paid_sim.layout.prop_at(Vector2(4, 4)).id
	var move = paid_sim.layout.duplicate_layout()
	check(move.move_prop(paid_id, Vector2i(1, 0)).ok and move.quote_diff(paid_sim.layout).net == 0, "Moving paid scenery is free")
	paid_sim.apply_construction(move)
	var remove = paid_sim.layout.duplicate_layout()
	remove.remove_prop(paid_id)
	check(paid_sim.apply_construction(remove).ok and paid_sim.cash == 132, "Demolition refunds half actual paid scenery cost")
	var free_sim := Sim.new()
	free_sim.mode = "developer"
	var free_plan = free_sim.layout.duplicate_layout()
	free_plan.paint_landscape_stroke("terrain", "sand", [Vector2i(0, 0)])
	free_plan.add_prop("bench", Vector2i(1, 0), 1)
	check(free_sim.apply_construction(free_plan).ok and free_sim.cash == 140, "Developer terrain and outdoor furniture are free")
	var bench: Dictionary = free_sim.layout.prop_at(Vector2(12, 4))
	check(bench.paid_cost == 0 and free_sim.layout.prop_rect(bench).size == Vector2(8, 24), "Outdoor bench rotation uses correct footprint and paid basis")
	var isolated: Layout = active.duplicate_layout()
	for prop in isolated.landscape.props.duplicate():
		isolated.remove_prop(prop.id)
	var barrier: Array = []
	for x in range(Landscape.REGION.position.x, Landscape.REGION.end.x):
		if isolated.landscape.cell_is_dry(Vector2i(x, 32)):
			barrier.append(Vector2i(x, 32))
	check(isolated.paint_landscape_stroke("path", "", barrier).ok, "Erase paths across a dry-land row")
	for position in barrier:
		isolated.add_prop("rock", position)
	check(not isolated.readiness().ok and isolated.room_points().is_empty(), "Scenery barrier disconnects guest entry from hotel and blocks operational readiness")
	var protect := Sim.new()
	protect.mode = "developer"
	check(not protect.apply_construction(isolated).ok and protect.layout.readiness().ok, "Even free mode cannot apply an unusable scenery-blocked resort")
	_test_preferred_route()
	print("Landscape model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_preferred_route() -> void:
	var model := Layout.new()
	for prop in model.landscape.props.duplicate():
		model.remove_prop(prop.id)
	var cells: Array = []
	for x in range(-10, 1):
		cells.append(Vector2i(x, 1))
	cells.append(Vector2i(-10, 0))
	cells.append(Vector2i(0, 0))
	check(model.paint_landscape_stroke("path", "stone", cells).ok, "Connected detour path can be drawn")
	var route := model.route(Vector2(-76, 4), Vector2(4, 4))
	check(route.has(Vector2(-36, 12)) and route.size() > 11, "Guests prefer a longer connected paved route over a shorter unpaved route")
	model.paint_landscape_stroke("path", "", cells)
	var direct := model.route(Vector2(-76, 4), Vector2(4, 4))
	check(direct.size() == 11, "Erasing paths changes actual route preference back")

