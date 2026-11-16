extends SceneTree

const Layout = preload("res://scripts/layout_model.gd")
var checks := 0
var failures := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var layout := Layout.new()
	check(layout.readiness().ok, "Starter hotel operates")
	check(layout.room_points().size() == 4, "Four accessible furnished rooms")
	for point in layout.room_points():
		check(not layout.route(Layout.ENTRY, point).is_empty(), "Guests reach beds through doors")
	check(not layout.add_building("bedroom", Rect2(400, 320, 64, 80)).ok, "Ocean rejects construction")
	check(not layout.add_building("bedroom", Rect2(24, 48, 64, 80)).ok, "Overlap rejected")
	check(not layout.add_building("bedroom", Rect2(-80, -80, 16, 16)).ok, "Minimum size enforced")
	check(not layout.add_building("bedroom", Rect2(-79, -80, 64, 80)).ok, "Off-grid rejected")
	var room: Dictionary = layout.buildings[0]
	check(not layout.add_asset("plant", room.id, Vector2i(4, 8)).ok, "Door approach protected")
	check(not layout.add_asset("plant", room.id, Vector2i(1, 1)).ok, "Furniture overlap rejected")
	check(not layout.add_asset("counter", room.id, Vector2i(3, 2)).ok, "Furniture type enforced")
	var pool: Dictionary = layout.buildings[-1]
	check(not layout.add_asset("plant", pool.id, Vector2i(4, 3)).ok, "Pool water protected")
	var draft = layout.duplicate_layout()
	check(draft.add_asset("lounger", pool.id, Vector2i(1, 2)).ok, "Left deck lounger")
	check(draft.add_asset("lounger", pool.id, Vector2i(16, 2)).ok, "Right deck lounger")
	check(draft.add_asset("umbrella", pool.id, Vector2i(2, 7)).ok, "Bottom deck umbrella")
	check(draft.readiness().terrace, "Physical furnishings award terrace")
	check(draft.quote_diff(layout).net == 100, "Regular construction quote")
	check(draft.quote_diff(layout, true).net == 0, "Developer construction free")
	draft.stamp_paid(layout)
	var paid = draft.duplicate_layout()
	draft.remove_asset(draft.assets[-1].id)
	check(draft.quote_diff(paid).refund == 20, "Only half actual paid cost refunded")
	var free = layout.duplicate_layout()
	free.add_asset("plant", room.id, Vector2i(5, 2))
	free.stamp_paid(layout, true)
	check(layout.quote_diff(free).refund == 0, "Free assets cannot mint cash")
	var before := layout.snapshot()
	var encoded: Dictionary = JSON.parse_string(JSON.stringify(before))
	check(layout.restore(encoded), "JSON save round trip")
	check(layout.readiness().ok, "Restored geometry still operational")
	var corrupt := before.duplicate(true)
	corrupt.assets[0].cell = [999, 999]
	check(not layout.restore(corrupt), "Invalid furniture rejects whole save")
	check(layout.readiness().ok, "Failed restore leaves prior hotel intact")
	corrupt = before.duplicate(true)
	corrupt.assets[0].id = corrupt.buildings[0].id
	check(not layout.restore(corrupt), "Duplicate IDs rejected")
	var empty = layout.duplicate_layout()
	for building in empty.buildings.duplicate():
		empty.remove_building(building.id)
	check(not empty.readiness().ok, "Incomplete drafts cannot open")
	check(empty.assets.is_empty(), "Bulldozing cascades furniture removal")
	var restored = Layout.new()
	check(restored.restore(empty.snapshot()), "Incomplete draft can still be saved")
	var isolated = layout.duplicate_layout()
	isolated.remove_building(isolated.buildings[4].id)
	check(isolated.add_building("bedroom", Rect2(24, 128, 64, 48)).ok, "Place wall across original bedroom exit")
	check(isolated.room_points().size() == 4 and isolated.building_unit(room.id).size() == 2,
		"The shared wall opens a passage and keeps the original bedroom reachable")
	var rotated = layout.duplicate_layout()
	var placed: Dictionary = rotated.add_asset("bench", room.id, Vector2i(5, 3), 1)
	check(placed.ok, "Rotated furnishing fits")
	check(rotated.asset_rect(rotated.assets[-1]).size == Vector2(8, 24), "Rotation swaps occupied footprint")
	print("Layout model: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
