extends SceneTree

const Scene := preload("res://scenes/resort.tscn")
const Game := preload("res://scripts/resort.gd")
const Sim := preload("res://scripts/simulation.gd")
const SaveSlot := preload("res://scripts/save_slot.gd")

var checks := 0
var failures := 0
var game: Game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/").contains("/.tools/r18-ui-"):
		push_error("Use isolated APPDATA under .tools/r18-ui-<id>.")
		quit(2)
		return
	game = Scene.instantiate() as Game
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	_test_regular()
	await _test_developer()
	game.queue_free()
	await process_frame
	print("Environment and staffing UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_regular() -> void:
	game._new_run("regular")
	var sim := game.simulation
	_open("beach")
	_check(game.ui._body.has("seaweed") and game.ui._body.has("offshore"), "Regular Beach shows separate shore and offshore measurements")
	_check(not game.ui._body.has("developer_month") and not game.ui._body.has("drill"), "Regular Beach has no Developer controls")
	game.ui.action_requested.emit("developer_month", 7)
	game.ui.action_requested.emit("developer_sargassum", 100)
	game.ui.action_requested.emit("developer_arrival", null)
	game.ui.action_requested.emit("developer_rescue_drill", null)
	_check(sim.developer_month() == 0 and sim.sargassum_intensity == -1 and sim.rescue.is_empty(),
		"Controller rejects Developer actions during Regular play")
	_open("staff")
	var body := game.ui._body
	var beach: Button = body.guard_sites.beach
	var pool: Button = body.guard_sites.pool
	_check("Hire" in beach.text and "$60" in body.guard_cost.text and "$25/day" in body.guard_cost.text,
		"Staff displays hire price and daily payroll before purchase")
	_check(body.options.size() == 3 and "Tables" in body.tables.text, "Floating staff and dining capacity remain available")
	var cash := sim.cash
	sim.cash = Sim.LIFEGUARD_HIRE_COST - 1
	game._refresh()
	_check(beach.disabled and pool.disabled and "cash" in beach.tooltip_text, "Staff disables unaffordable hires with a reason")
	sim.cash = cash
	game._refresh()
	_click(beach)
	_check(sim.lifeguard_assignment == "beach" and sim.cash == cash - Sim.LIFEGUARD_HIRE_COST
		and beach.button_pressed and "Available" in body.guard_status.text, "Actual Staff click hires one beach guard and updates state")
	_click(pool)
	_check(sim.lifeguard_assignment == "pool" and sim.cash == cash - Sim.LIFEGUARD_HIRE_COST
		and pool.button_pressed and "Main pool" in body.guard_status.text and "$25/day payroll" in body.guard_cost.text,
		"Reassignment changes the one guard's post and preserves hire cash")
	_audit_panel("Regular Staff")
	while sim.day == 1 and not sim.stopped:
		sim.tick()
	_check("$145 payroll" in game.last_notice, "Day close toast uses actual total payroll after a Regular hire")


func _test_developer() -> void:
	game._new_run("developer")
	var sim := game.simulation
	while sim.second < 85:
		sim.tick()
	var families := sim.families.duplicate(true)
	var clock := [sim.day, sim.second, sim.booked_price, game.elapsed]
	var plan := sim.layout
	_open("beach")
	var body := game.ui._body
	var month: OptionButton = body.developer_month
	_check(month.item_count == 13 and month.selected == 0, "Month lists Auto and all twelve months")
	_check(body.drill.disabled and "Staff" in body.drill.tooltip_text, "Developer drill explains how to hire first")
	_audit_panel("Developer Beach")
	_click(month)
	await process_frame
	var menu := month.get_popup()
	_check(menu.visible, "Routed click opens the embedded month menu")
	if menu.visible:
		_check(root.get_visible_rect().grow(1).encloses(Rect2(menu.position, menu.size)),
			"The month popup at %s with size %s fits the root viewport %s" % [menu.position, menu.size, root.get_visible_rect()])
		_check(game.ui.is_pointer_over_ui(Vector2(1050, 470)), "Month popup blocks map pointer input")
		_key(root, KEY_ESCAPE)
		await process_frame
		_check(not menu.visible and game.ui.has_open_panel(), "Escape dismisses the month menu before the Beach panel")
		_click(month)
		await process_frame
		menu.set_focused_item(7)
		_key(root, KEY_ENTER)
		await process_frame
	_check(sim.developer_month() == 7 and sim.calendar_state().month == 7 and "JULY" in game.ui._date_heading.text,
		"Keyboard month selection updates the visible calendar and actual environment (%d / %d / popup %s)" % [sim.developer_month(), month.selected, menu.visible])
	_check(clock == [sim.day, sim.second, sim.booked_price, game.elapsed] and sim.families == families and sim.layout == plan,
		"Selecting a month preserves in-progress guests, clock, bookings and layout")
	_click(month)
	await process_frame
	_key(root, KEY_F8)
	await process_frame
	_check(not menu.visible and is_instance_valid(game.animation_viewer) and game.animation_viewer.visible,
		"F8 dismisses the month popup before opening the modal viewer")
	game.ui.action_requested.emit("developer_sargassum", 100)
	_check(sim.sargassum_intensity == -1, "The background Beach panel cannot send a Developer action through the viewer")
	_key(root, KEY_F8)
	await process_frame
	_check(game.ui._panel_id == "beach" and not game.animation_viewer.visible and root.gui_get_focus_owner() == month,
		"Closing the viewer restores the existing Beach panel and month button focus without reopening its menu")

	var slider: HSlider = body.intensity
	_click(slider, 0.8)
	_check(sim.sargassum_intensity in range(75, 86) and body.intensity_value.text == "%d%%" % sim.sargassum_intensity,
		"Routed intensity slider applies a numeric offshore setting (%s / %s)" % [sim.sargassum_intensity, body.intensity_value.text])
	_click(body.intensity_auto)
	_check(sim.sargassum_intensity == -1 and body.intensity_auto.button_pressed and "Auto" in body.intensity_value.text,
		"Auto restores seasonal offshore intensity")
	var count := sim.floating_sargassum().size()
	var before := sim.sargassum
	_click(body.arrival)
	_check(sim.floating_sargassum().size() == count + 1 and sim.sargassum == before
		and str(count + 1) in body.offshore.text, "Force arrival creates one live patch without instantly changing recorded shore buildup")

	var cash := sim.cash
	_open("staff")
	body = game.ui._body
	_click(body.guard_sites.beach)
	_check(sim.lifeguard_assignment == "beach" and sim.cash == cash and "No extra payroll" in body.guard_cost.text,
		"Developer hires from Staff without a fee or extra payroll")
	for site in ["beach", "pool"]:
		_open("staff")
		_click(game.ui._body.guard_sites[site])
		_open("beach")
		body = game.ui._body
		_check(not body.drill.disabled, "Developer may start a drill at " + site)
		_click(body.drill)
		_check(sim.rescue.get("drill", false) and sim.rescue.get("site", "") == site
			and "Drill" in body.beach_guard.text and body.drill.disabled, "Drill update uses the real " + site + " guard")
		if sim.rescue.get("family", -1) == -1:
			_check("Volunteer" in body.beach_guard.text and "volunteer" in game.last_notice,
				"Volunteer exercises are identified in both the live status and start notice")
		_open("staff")
		var guard := game.ui._body
		_check(guard.guard_sites.beach.disabled and guard.guard_sites.pool.disabled and "Drill" in guard.guard_status.text,
			"Both assignment actions are disabled while the guard is busy")
		var contact: int = sim.rescue.contact_at
		var drop: int = sim.rescue.drop_at
		while sim.second < contact:
			sim.tick()
		game._refresh()
		_check("Towing to safety" in guard.guard_status.text, "Staff reports the active tow")
		while sim.second < drop:
			sim.tick()
		game._refresh()
		_check("Returning to post" in guard.guard_status.text, "Staff reports the return to the chair after the guest reaches safety")
		for i in 32:
			if sim.rescue.is_empty():
				break
			sim.tick()
		_open("beach")
		_check(sim.rescue.is_empty() and sim.last_rescue.get("outcome", "") == "drill_complete"
			and "drill complete" in game.ui._body.beach_guard.text, "Finished " + site + " drill is visible")
	_check(not SaveSlot.exists(), "Management and developer controls do not silently write a save")


func _audit_panel(context: String) -> void:
	var panel: Panel = game.ui._popover
	var frame := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var panel_rect := panel.get_global_rect()
	_check(frame.encloses(panel_rect) and not panel_rect.intersects(game.ui._status.get_global_rect())
		and not panel_rect.intersects(game.ui._dock.get_global_rect()), context + " remains between the status bar and bottom dock")
	var controls: Array[Control] = []
	for node in panel.get_children():
		if node is Label or node is Button or node is Slider:
			var bounds: Rect2 = node.get_global_rect()
			_check(panel_rect.encloses(bounds) and bounds.size.x >= node.get_combined_minimum_size().x,
				"%s fits control %s" % [context, node.name])
			for previous in controls:
				_check(not bounds.intersects(previous.get_global_rect()), "%s keeps %s (%s) separate from %s (%s)" % [
					context, node.name, bounds, previous.name, previous.get_global_rect()])
			controls.append(node)


func _open(panel: String) -> void:
	if game.ui._panel_id != panel:
		_click(game.ui._dock_buttons[panel])


func _click(control: Control, horizontal := 0.5) -> void:
	var bounds := control.get_global_rect()
	var point := bounds.position + bounds.size * Vector2(horizontal, 0.5)
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


func _key(viewport: Viewport, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		viewport.push_input(event, true)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
