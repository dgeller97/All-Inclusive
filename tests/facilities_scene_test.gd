extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Game = preload("res://scripts/resort.gd")
const Sim = preload("res://scripts/simulation.gd")
const Layout = Sim.Layout
const SaveSlot = preload("res://scripts/save_slot.gd")
const FACILITY_PRICES := {"beach_lounge": "$40", "volleyball": "$100", "beach_bar": "$100", "stage": "$120"}
const MOVE_CELLS := {
	"beach_lounge": Vector2i(59, 14), "volleyball": Vector2i(44, 9),
	"beach_bar": Vector2i(51, 32), "stage": Vector2i(39, 32),
}

var game: Game
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/r8-facilities-scene-"):
		push_error("Use isolated APPDATA under .tools/r8-facilities-scene-<id>.")
		quit(2)
		return
	game = Scene.instantiate() as Game
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	_test_catalogs()
	_test_starter_edits()
	_test_selection_priority()
	_test_purchase_and_queue()
	_test_developer()
	game.queue_free()
	await process_frame
	print("Facilities scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_catalogs() -> void:
	game._new_run()
	_open_build()
	var ui := game.design_ui
	_check(ui._tool_buttons.bedroom.get_node("Price").text == "$160", "Buildings show their visible construction price")
	_audit_catalog("Buildings")
	_choose(ui._category_buttons.furniture)
	_check(ui._tool_buttons.bed.get_node("Price").text == "$40", "Furniture shows its visible construction price")
	_audit_catalog("Furniture")
	_choose(ui._category_buttons.facilities)
	_check(ui._category_buttons.facilities.text == "Facilities" and ui._category_buttons.facilities.button_pressed
		and not ui._landscape_buttons.terrain.is_visible_in_tree(), "Facilities opens directly from Build")
	for kind in FACILITY_PRICES:
		var button: Button = ui._tool_buttons[kind]
		var price: Label = button.get_node("Price")
		var name_label: Label = ui._tool_labels[kind]
		_check(price.is_visible_in_tree() and price.text == FACILITY_PRICES[kind]
			and name_label.is_visible_in_tree() and name_label.text == Layout.Landscape.PROP_CATALOG[kind].label
			and "families" in button.tooltip_text and price.text in button.accessibility_name,
			"Facilities shows the name, price and capacity for %s" % kind)
	_audit_catalog("Facilities")
	_choose(ui._category_buttons.landscape)
	_check(not ui._landscape_buttons.has("amenities") and not ui._tool_buttons.stage.is_visible_in_tree(),
		"Landscape contains only Terrain, Paths, and Scenery")
	_audit_catalog("Terrain")
	_choose(ui._landscape_buttons.path)
	_audit_catalog("Paths")
	_choose(ui._landscape_buttons.scenery)
	_check(ui._tool_buttons.palm.get_node("Price").text == "$15", "Scenery shows its visible construction price")
	_audit_catalog("Scenery")
	_context("Discard")


func _test_starter_edits() -> void:
	_open_build()
	var ui := game.design_ui
	var original := game.simulation.layout.snapshot()
	var starter_venues := game.simulation.layout.amenities()
	_check(game.design.category == "buildings" and not ui._move.is_visible_in_tree(), "Build opens on Buildings with no Move target")
	for venue in starter_venues:
		_choose(ui._tool_buttons.select)
		_click_world(venue.rect.get_center())
		_check(game.design.selection.get("id") == venue.id and ui._move.is_visible_in_tree() and not ui._move.disabled,
			"Buildings Select recognizes the starter %s and offers Move" % venue.kind)
		if venue.kind == "beach_lounge":
			_choose(ui._tool_buttons.bulldoze)
			_check(game.design.tool == "bulldoze" and ui._move.is_visible_in_tree() and not ui._move.disabled,
				"A selected facility still offers Move after choosing Bulldoze")
		_choose(ui._move)
		_check(ui._rotate.is_visible_in_tree() and not ui._rotate.disabled, "Rotate is available during %s Move in Buildings" % venue.kind)
		if venue.kind == "beach_lounge":
			_choose(ui._category_buttons.furniture)
			_choose(ui._category_buttons.buildings)
			_check(game.design.tool == "move" and game.design.selection.get("id") == venue.id,
				"Switching catalogs preserves an active Move")
			_cancel_operation()
			_check(game.design.draft.amenity_by_id(venue.id) == venue and not ui._move.is_visible_in_tree(),
				"Escape cancels a Move preview and clears selection")
			_click_world(venue.rect.get_center())
			_choose(ui._move)
		_choose(ui._rotate)
		var destination := Vector2(MOVE_CELLS[venue.kind]) * Layout.GRID
		_click_world(destination + Vector2(4, 4))
		var moved := game.design.draft.amenity_by_id(venue.id)
		_check(moved.get("rotation") == (int(venue.rotation) + 1) % 4
			and moved.rect.position == destination and game.design.category == "buildings",
			"Routed %s Move keeps the ID and updates its footprint and rotation" % venue.kind)
		_choose(ui._tool_buttons.bulldoze)
		_click_world(moved.rect.get_center())
		_check(game.design.draft.amenity_by_id(venue.id).is_empty() and "removed" in game.design.feedback,
			"Buildings Bulldoze removes the starter %s from the draft" % venue.kind)
	_check("Cost $0" in ui._quote.text and "Refund $0" in ui._quote.text and game.simulation.cash == 140
		and game.simulation.layout.snapshot() == original, "Starter moves and removals leave cash and the active resort unchanged")
	_context("Discard")
	_open_build()
	_check(game.design.draft.amenities() == starter_venues, "Discard restores all unsaved starter venues")
	_context("Discard")


func _test_selection_priority() -> void:
	_open_build()
	var ui := game.design_ui
	var draft := game.design.draft
	_choose(ui._category_buttons.facilities)
	var overlap_point := Vector2(39, 223)
	var palm := draft.prop_at(overlap_point)
	var reception := draft.building_at(overlap_point)
	_check(palm.get("kind") == "palm" and reception.get("kind") == "reception" and not draft.prop_rect(palm).has_point(overlap_point),
		"Fixture overlaps palm artwork with a reception footprint")
	_click_world(overlap_point)
	_check(game.design.selected_building().get("id") == reception.id and ui._open_building_settings.is_visible_in_tree()
		and not ui._move.is_visible_in_tree(), "Reception footprint shields the palm artwork and offers Building settings from Facilities")
	_choose(ui._open_building_settings)
	_check(ui._building_settings.is_visible_in_tree(), "Building settings opens from Facilities")
	_cancel_operation()
	_choose(ui._category_buttons.landscape)
	_check(game.design.selected_building().get("id") == reception.id and ui._open_building_settings.is_visible_in_tree(),
		"Landscape keeps the building selection and Settings control")
	_choose(ui._category_buttons.facilities)
	var bed := draft.assets[0]
	var bed_point := draft.asset_rect(bed).get_center()
	_click_world(bed_point)
	_check(game.design.selection.get("id") == bed.id and not ui._open_building_settings.is_visible_in_tree(),
		"Furniture is selected before its building from Facilities")
	_choose(ui._tool_buttons.bulldoze)
	_click_world(bed_point)
	_check(draft.asset_at(bed_point).is_empty() and not draft.building_at(bed_point).is_empty(),
		"Bulldozing from Facilities removes the bed without its building")
	_click_world(overlap_point)
	_check(draft.building_by_id(reception.id).is_empty() and not draft.landscape.prop_by_id(palm.id).is_empty(),
		"Bulldoze removes the building under a palm's overhang")
	_context("Discard")


func _test_purchase_and_queue() -> void:
	_open_build()
	var ui := game.design_ui
	var sim := game.simulation
	var bar := sim.layout.amenities("beach_bar")[0]
	_choose(ui._tool_buttons.bulldoze)
	_click_world(bar.rect.get_center())
	_choose(ui._category_buttons.facilities)
	_choose(ui._tool_buttons.beach_bar)
	_click_world(bar.rect.position + Vector2(4, 4))
	var added := game.design.draft.amenities("beach_bar")
	_check(added.size() == 1 and added[0].id != bar.id and sim.cash == 140
		and sim.layout.amenity_by_id(bar.id) == bar and "Cost $100" in ui._quote.text,
		"Buying a facility changes only the draft and shows the purchase quote")
	if added.size() != 1:
		_context("Discard")
		return
	var purchased := added[0]
	_context("Save draft")
	_context("Discard")
	game._load_run()
	sim = game.simulation
	_open_build()
	_check(SaveSlot.read().version == Game.SAVE_VERSION and game.design.draft.amenity_by_id(purchased.id) == purchased
		and sim.layout.amenity_by_id(bar.id) == bar and sim.cash == 140, "A saved facility purchase restores as an unpaid draft")
	_context("Apply now")
	_check(sim.cash == 40 and sim.layout.landscape.prop_by_id(purchased.id).get("paid_cost") == 100,
		"Apply charges and records the purchase price once")
	while sim.second < Sim.SHOW_START and not _bar_in_use(purchased.id):
		sim.tick()
	_check(_bar_in_use(purchased.id), "Guests reserve the purchased bar once the resort opens")
	var cash := sim.cash
	var live_families := sim.families.duplicate(true)
	_open_build()
	_choose(ui._tool_buttons.bulldoze)
	_click_world(purchased.rect.get_center())
	_check(ui._apply.text == "Apply tomorrow" and not ui._apply.disabled and "Refund $50" in ui._quote.text
		and sim.cash == cash and sim.families == live_families, "Occupied bar removal quotes half the purchase price and waits until tomorrow")
	_context("Apply tomorrow")
	_check(sim.pending_layout != null and sim.pending_layout.amenities("beach_bar").is_empty()
		and sim.layout.amenity_by_id(purchased.id) == purchased and sim.families == live_families and sim.cash == cash,
		"Queuing bar demolition preserves the live venue, reservations and cash")
	_open_build()
	_check(ui._pending_notice.text == "Day 2 plan queued", "Queued removal is visible when reopening Build")
	_context("Cancel queued plan")
	_check(sim.pending_layout == null and sim.layout.amenity_by_id(purchased.id) == purchased
		and sim.families == live_families and sim.cash == cash, "Cancel keeps the active bar and guests")
	_context("Apply tomorrow")
	game._save_run()
	game._load_run()
	sim = game.simulation
	_check(sim.pending_layout != null and sim.families == live_families and sim.layout.amenity_by_id(purchased.id) == purchased,
		"Current save restores the queued demolition and in-progress bar visit")
	while sim.second < Sim.DAY_LENGTH - 1:
		sim.tick()
	_check(sim.day == 1 and not sim.layout.amenity_by_id(purchased.id).is_empty() and sim.reviews.size() == 4,
		"The occupied resort completes its stays before demolition activates")
	var before_close := sim.cash
	sim.tick()
	_check(sim.day == 2 and sim.pending_layout == null and sim.layout.amenities("beach_bar").is_empty()
		and sim.cash == before_close - Sim.PAYROLL + 50, "Day 2 clears the queued bar and credits the $50 refund once")


func _test_developer() -> void:
	game._new_run("developer")
	var ui := game.design_ui
	var sim := game.simulation
	_open_build()
	_choose(ui._category_buttons.facilities)
	for kind in FACILITY_PRICES:
		var price: Label = ui._tool_buttons[kind].get_node("Price")
		_check(price.is_visible_in_tree() and price.text == "Free", "Developer marks %s visibly Free" % kind)
	_audit_catalog("Developer Facilities")
	var stage := sim.layout.amenities("stage")[0]
	_choose(ui._tool_buttons.bulldoze)
	_click_world(stage.rect.get_center())
	_choose(ui._tool_buttons.stage)
	_click_world(stage.rect.position + Vector2(4, 4))
	_context("Apply now")
	var replacement := sim.layout.amenities("stage")[0]
	_check(replacement.id != stage.id and sim.layout.landscape.prop_by_id(replacement.id).paid_cost == 0 and sim.cash == 140,
		"Developer applies a newly built stage for $0")
	_open_build()
	_choose(ui._tool_buttons.bulldoze)
	_click_world(replacement.rect.get_center())
	_context("Apply now")
	_check(sim.layout.amenities("stage").is_empty() and sim.cash == 140, "Developer demolition has no resale refund")


func _bar_in_use(id: int) -> bool:
	for family in game.simulation.families:
		if family.amenity_id == id and family.phase == "leisure":
			return true
	return false


func _audit_catalog(title: String) -> void:
	var palette := game.design_ui._palette
	var controls: Array[Control] = []
	for child in palette.get_children():
		if child is Control and child.is_visible_in_tree():
			var overlaps: Array[String] = []
			for prior in controls:
				if prior.get_global_rect().intersects(child.get_global_rect()):
					overlaps.append(prior.name)
			_check(overlaps.is_empty(), "%s control %s overlaps %s" % [title, child.name, ", ".join(overlaps)])
			controls.append(child)
	_audit_control(palette, Rect2(Vector2.ZERO, root.get_visible_rect().size), title)


func _audit_control(control: Control, parent_bounds: Rect2, title: String) -> void:
	var bounds := control.get_global_rect()
	_check(parent_bounds.encloses(bounds), "%s control %s is within its panel" % [title, control.get_path()])
	if control is Label or control is Button:
		var font := control.get_theme_font("font")
		var font_size := control.get_theme_font_size("font_size")
		var width := font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_check(width <= control.size.x, "%s text fits: %s" % [title, control.text])
	for child in control.get_children():
		if child is Control and child.is_visible_in_tree():
			_audit_control(child, bounds, title)


func _open_build() -> void:
	_choose(game.ui._dock_buttons.design)
	_check(game.design.draft != null, "Routed Build click opens the layout draft")


func _context(title: String) -> void:
	for child in game.design_ui._context.get_children():
		if child is Button and child.text == title and child.is_visible_in_tree():
			_choose(child)
			return
	_check(false, "Design action exists: " + title)


func _choose(button: Button) -> void:
	_click(button.get_global_rect().get_center())


func _click_world(point: Vector2) -> void:
	_click(game.camera.world_to_screen(point))


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)


func _cancel_operation() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = pressed
		root.push_input(event, true)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
