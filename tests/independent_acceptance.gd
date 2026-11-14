extends SceneTree

const Scene = preload("res://scenes/resort.tscn")
const Sim = preload("res://scripts/simulation.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Ocean = preload("res://scripts/ocean.gd")

var passed := 0
var failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var save_path := ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/")
	if not save_path.contains("/.tools/tester-appdata"):
		push_error("Use an isolated APPDATA directory under .tools/tester-appdata before running this test.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if "--v1" in args:
		await _test_v1_slot()
	elif "--v2" in args:
		await _test_upgraded_legacy_slot()
	elif "--resume" in args:
		await _test_relaunch()
	else:
		_test_economy()
		_test_staffing()
		_test_recap()
		_test_ocean_cycle()
		await _test_scene()
	await process_frame
	await process_frame
	print("Independent acceptance: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _test_economy() -> void:
	var sim := Sim.new()
	var charged: Array[int] = []
	sim.event_happened.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"checkin":
			charged.append(data.price)
	)
	sim.selected_package = 0
	_tick(sim, 19)
	_check(sim.booked_package == -1 and sim.families.is_empty(), "No arrival or locked package before 00:20")
	_tick(sim, 1)
	sim.selected_package = 2
	_tick(sim, 100)
	_check(sim.booked_package == 0 and charged == [90, 90, 90, 90] and sim.cash == 500,
		"Post-booking changes preserve four $90 Budget check-ins")
	_tick(sim, 120)
	_check(sim.cash == 380 and not sim.terrace, "Budget starts Day 2 with $380 and the original pool")
	_tick(sim, 28)
	_check(sim.cash == 550 and sim.apply_construction(_terrace_plan(sim)).defer and sim.cash == 450, "First Premium check-in permits a $100 reservation for tomorrow")
	_tick(sim, 95)
	_check(sim.booked_package == 2 and sim.families.size() == 3 and charged.slice(4) == [170, 170, 170],
		"Day 2 locks three $170 Premium bookings")


func _test_staffing() -> void:
	var pool_float := Sim.new()
	pool_float.float_station = 2
	_tick(pool_float, 180)
	var pool_waits: Array = pool_float.families.map(func(family: Dictionary) -> int: return family.waits[2])
	_check(pool_waits == [0, 0, 0, 0] and pool_float.families[3].waits[1] == 0 and pool_float.families[3].dining_wait == 24,
		"Pool staffing eliminates pool waits while the fourth family still waits 24 seconds for a table")

	var transfer := Sim.new()
	_tick(transfer, 55)
	var deadline: int = transfer.families[1].until
	_check(transfer.capacity(1) == 2 and transfer.count_at(1, "service") == 1, "Buffet float opens a second counter slot")
	transfer.float_station = 2
	_tick(transfer, 1)
	_check(transfer.capacity(1) == 1 and transfer.families[1].phase == "service" and transfer.families[1].until == deadline,
		"Mid-service transfer preserves food-collection deadlines")
	_tick(transfer, 6)
	_check(transfer.families[2].phase == "service" and transfer.families[2].since == 62
		and transfer.families[1].phase == "wait_table", "Table waiting releases the counter to the next family")
	_tick(transfer, 177)
	_check(_closed(transfer), "Rooms and guest phases clear before closing after staff transfer")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261112
	var schedules_ok := true
	for schedule in range(24):
		var sim := Sim.new()
		sim.selected_package = schedule % 3
		for day in range(2):
			if day == 1 and sim.cash >= 100:
				sim.apply_construction(_terrace_plan(sim)).ok
			for second in range(239):
				if rng.randi_range(1, 8) == 1:
					sim.float_station = rng.randi_range(0, 2)
				sim.tick()
				if second % 7 == 0:
					var restored := Sim.new()
					var state := sim.snapshot()
					schedules_ok = schedules_ok and restored.restore(state) and _same_state(restored.snapshot(), state)
			schedules_ok = schedules_ok and _closed(sim)
			sim.tick()
	_check(schedules_ok, "48 seeded staff-schedule days close cleanly and sampled live states restore")


func _test_recap() -> void:
	var sim := Sim.new()
	_tick(sim, 158)
	_check(sim.cash == 620 and sim.rooms == [0, 1, 2, 3] and not sim.terrace,
		"Standard Day 1 posts four room charges and keeps the original pool")
	_check(sim.families[3].waits[2] == 12 and sim.families[3].dining_wait == 24 and sim.families[3].phase == "rest", "Standard with one table yields a 12-second peak pool wait and a 24-second peak dining wait")
	_tick(sim, 81)
	_check(_closed(sim) and _scores(sim) == [92, 91, 86, 80], "Day 1 closes with four exact checkout ratings and all rooms released")
	_check(sim.reviews.slice(1).all(func(review: Dictionary) -> bool: return review.note == "Long dining table wait"),
		"Day 1 penalized reviews identify table waits")
	_tick(sim, 1)
	_check(sim.cash == 500 and sim.apply_construction(_terrace_plan(sim)).ok and sim.cash == 400 and sim.terrace,
		"One $120 payroll, followed by $100 of terrace furnishings")
	sim.float_station = 2
	_check(sim.capacity(2) == 3, "Terrace capacity stacks with a floating worker")
	sim.float_station = 1
	_tick(sim, 480)
	_check(sim.stopped and sim.milestone == {"stays": 12, "average": 93.25, "terrace": true, "cash": 1120}
		and _scores(sim).slice(4) == [100, 99, 95, 91, 100, 99, 95, 91],
		"Standard full success gives 12 stays, 93.25 rating and $1120, with remaining dining wait penalties")
	var milestone := sim.milestone.duplicate()
	var before := sim.snapshot()
	_tick(sim, 40)
	_check(sim.snapshot() == before, "Recap stops payroll, time and guest changes")
	sim.continue_after_recap()
	_tick(sim, 240)
	_check(sim.day == 5 and sim.reviews.size() == 16 and sim.cash == 1480 and sim.milestone == milestone,
		"Sandbox closes Day 4 normally and preserves the Day 3 milestone")

	for package in [0, 1, 2]:
		var fixed := Sim.new()
		fixed.selected_package = package
		_tick(fixed, 240)
		var opening_day_two_cash := fixed.cash
		fixed.apply_construction(_terrace_plan(fixed))
		_tick(fixed, 480 - fixed.second)
		print("Fixed package %s: Day 2 opening $%d, %d stays, %.2f rating, $%d at recap" % [
			Sim.PACKAGES[package].name, opening_day_two_cash, fixed.milestone.stays,
			fixed.milestone.average, fixed.milestone.cash,
		])


func _test_scene() -> void:
	var game = _open_scene()
	await process_frame
	_check(game.menu_mode == "welcome" and not game.started and game.dialog_load_button.disabled,
		"Clean profile opens with onboarding and disabled Load")
	_check(game.dialog.get_global_rect().get_center().is_equal_approx(game.overlay.size / 2.0), "Welcome dialog is centered over the resort")
	_check(root.gui_get_focus_owner() == _button(game.dialog, "Regular resort"), "Welcome gives keyboard focus to the start button")
	game._process(5.0)
	_check(game.simulation.second == 0, "Welcome does not spend simulation time")
	_button(game.dialog, "Regular resort").pressed.emit()
	game.ui.open_panel("pool")
	_check(game.ui._cash.text == "$140" and game.simulation.rooms == [-1, -1, -1, -1]
		and game.ui._body.pool_status.text == "Terrace needs furnishings",
		"Opening resort shows cash, free rooms and furnishing status in the Pool panel")
	game.ui.close_panel()
	_test_pointer_navigation(game)
	var music := game.music.stream as AudioStreamWAV
	var surf := game.ambience.stream as AudioStreamWAV
	_check(game.effects.size() == 5 and game.music.playing and game.ambience.playing
		and music.loop_mode == AudioStreamWAV.LOOP_FORWARD and music.loop_end == 1411200
		and surf.loop_mode == AudioStreamWAV.LOOP_FORWARD and surf.loop_end == 705600,
		"All five cues load and music and surf start with exact forward loops")
	game.ui.open_panel("settings")
	game.ui._body.sound.pressed.emit()
	_check(AudioServer.is_bus_mute(0) and "Sound off" in game.ui._body.sound.text, "Settings mute switches the audio bus and label")
	game.ui._body.sound.pressed.emit()
	game.ui.close_panel()
	# Keep synthetic long frames from issuing many cue playbacks in one audio buffer.
	game.smoke_test_requested = true
	game.music.stop()
	game.ambience.stop()
	for cue: AudioStreamPlayer in game.effects.values():
		cue.stop()
	await create_timer(0.1).timeout
	game._process(1.0)
	game.ui._speed_buttons[1].pressed.emit()
	game._process(1.0)
	_key(KEY_3)
	game._process(1.0)
	_check(game.speed == 4 and game.simulation.second == 7, "Normal button and keyboard paths advance 1, 2 and 4 ticks in one simulated frame second")
	game._process(0.125)
	game.ui._dock_buttons["staff"].grab_focus()
	_key(KEY_SPACE)
	_check(game.paused and not game.ui.has_open_panel(), "Space toggles pause without activating the focused dock button")
	var frozen: Dictionary = game.simulation.snapshot()
	var position: float = game.map.time
	var surf_phase: float = game.map.ocean._time
	game._process(10.0)
	_check(game.paused and game.simulation.snapshot() == frozen and game.map.time == position
		and game.map.ocean._time == surf_phase,
		"Pause holds clock, fractional animation time and full simulation state")
	_key(KEY_ESCAPE)
	await process_frame
	_check(game.settings_open and game.ui._panel_id == "settings", "Escape opens Settings with a dock button focused")
	game._process(10.0)
	_key(KEY_ESCAPE)
	_check(not game.ui.has_open_panel() and not game.settings_open and game.paused and game.simulation.snapshot() == frozen,
		"Escape closes Settings and preserves a prior manual pause")
	_key(KEY_1)
	_check(not game.paused and game.speed == 1, "Speed shortcut resumes from pause")
	game._process(48.0)
	var state: Dictionary = game.simulation.snapshot()
	var invalid_state := state.duplicate(true)
	invalid_state.families[0].station = 0
	_check(not Sim.new().restore(invalid_state), "Malformed occupied-family reception service is rejected")
	game._process(39.0)
	game.ui.open_panel("settings")
	game.ui.open_panel("package")
	_check(not game.settings_open and game.ui._panel_id == "package", "Switching from Settings clears its clock pause")
	game.ui._body.options[2].pressed.emit()
	game.ui._speed_buttons[1].pressed.emit()
	_check(game.simulation.count_at(1, "wait_table") == 1 and game.simulation.count_at(2, "service") == 1,
		"Checkpoint contains dining-table wait and active pool service")
	_check("Day 2" in game.ui._body.effective.text and "3 families" in game.ui._body.effective.text
		and "Higher expectations" in game.ui._body.details.text and "Standard $120" in game.ui._body.booking.text,
		"Booking panel distinguishes the current booking lock from next-day Premium demand")
	_key(KEY_ESCAPE)
	_check(not game.ui.has_open_panel() and not game.settings_open, "Escape closes an open contextual panel before opening Settings")
	game.camera.zoom_in()
	game.camera.pan_by(Vector2(30, -50))
	_key(KEY_ESCAPE)
	await process_frame
	game._process(4.0)
	_check(game.simulation.second == 94 and game.elapsed == 0.5 and game.map.ocean._time == 94.5,
		"Settings stops the clock and surf without discarding fractional progress")
	_button(game.ui._popover, "Save run").pressed.emit()
	var saved: Dictionary = SaveSlot.read()
	_check(saved.get("simulation") == game.simulation.snapshot() and saved.get("speed") == 2
		and saved.get("elapsed") == 0.5 and saved.get("camera") == game.camera.snapshot(),
		"Save button writes live state, fractional time, chosen speed and camera")
	_key(KEY_ESCAPE)
	game._process(0.25)
	_check(not game.paused and game.simulation.second == 95 and game.elapsed == 0.0, "Closing Settings restores the previous running speed")
	_check(SaveSlot.read() == saved, "Advancing without explicit save does not overwrite the slot")
	game.queue_free()
	await process_frame
	await _test_relaunch(true)


func _test_relaunch(test_failures := false) -> void:
	var game = _open_scene()
	game.smoke_test_requested = true
	await process_frame
	var saved: Dictionary = SaveSlot.read()
	_check(not game.dialog_load_button.disabled and not saved.is_empty(), "Reopened scene enables the existing save slot")
	game.dialog_load_button.pressed.emit()
	game._process(0.0)
	_check(game.started and game.paused and game.menu_mode.is_empty() and game.speed == 2 and game.map.time == 94.5
		and _same_state(game.simulation.snapshot(), saved.get("simulation")) and game.map.ocean._time == 94.5,
		"Load restores occupied rooms, queues, prices, speed and fractional animation time paused")
	var loaded_view: Dictionary = game.camera.snapshot()
	var saved_view: Dictionary = saved.get("camera", {})
	_check(is_equal_approx(loaded_view.zoom, saved_view.get("zoom", 0.0))
		and loaded_view.center.is_equal_approx(saved_view.get("center", Vector2.ZERO)),
		"Load restores the saved camera view")
	var continuous := Sim.new()
	if not continuous.restore(saved.get("simulation", {})):
		_check(false, "Reopened checkpoint decodes for continuation comparison")
		game.free()
		return
	game.ui._speed_buttons[2].pressed.emit()
	game._process(146.0 / 4.0)
	_tick(continuous, 146)
	_check(_same_state(game.simulation.snapshot(), continuous.snapshot()) and game.simulation.cash == 500
		and game.simulation.reviews.size() == 4 and game.simulation.day_recaps.size() == 1,
		"Loaded run advances at 4× with one payroll and exactly four Day 1 reviews")
	game.ui.open_panel("pool")
	_check(_button(game.ui._popover, "Open Build") != null, "Pool panel offers a shortcut to Build")
	_button(game.ui._popover, "Open Build").pressed.emit()
	_check(game.design.draft != null and game.design_ui.visible, "Pool shortcut enters the design editor")
	game._on_design_action("discard", null)
	game._process(5.0)
	_check(game.simulation.second == 20 and game.map.ocean._time == 260.5 and game.map.ocean.condition_name() == "Caution",
		"On Day 2 the ocean uses total simulation time instead of restarting its cycle")
	if test_failures:
		await _test_invalid_slots(game, saved)
	game._new_run()
	game._process(720.0)
	await process_frame
	var recap_text := _label_texts(game.dialog)
	_check(game.menu_mode == "recap" and "Pool terrace pending" in recap_text and "Missed" in recap_text
		and recap_text.count("Met") == 2, "Recap marks only the terrace target missed after a no-upgrade Standard run")
	_button(game.dialog, "Start a fresh run").pressed.emit()
	_button(game.dialog, "Regular resort").pressed.emit()
	_check(game.simulation.day == 1 and game.simulation.cash == 140 and game.simulation.reviews.is_empty(), "Fresh-run recovery resets the simulation")
	game.queue_free()


func _test_invalid_slots(game, saved: Dictionary) -> void:
	_key(KEY_ESCAPE)
	await process_frame
	var current: Dictionary = game.simulation.snapshot()
	var invalid := saved.duplicate(true)
	invalid.simulation.families[0].waits[0] = "bad"
	_check(SaveSlot.write(invalid), "Nested-invalid fixture written with a valid checksum")
	game.ui._body.load.pressed.emit()
	_check(_same_state(game.simulation.snapshot(), current) and "unreadable" in game.last_notice,
		"Invalid nested waits show an error and preserve the current run")
	var file := FileAccess.open(SaveSlot.PATH, FileAccess.WRITE)
	if file:
		file.store_buffer(PackedByteArray([1, 2, 3]))
		file.close()
	game.ui._body.load.pressed.emit()
	_check(_same_state(game.simulation.snapshot(), current) and SaveSlot.read().is_empty() and "unreadable" in game.last_notice,
		"Truncated slot shows an error and preserves the current run")
	_check(SaveSlot.write(saved), "Restored the isolated fixture for the second process")


func _test_ocean_cycle() -> void:
	var expected := [
		[0.0, Ocean.Condition.CALM], [29.0, Ocean.Condition.CAUTION],
		[56.0, Ocean.Condition.CLOSED], [84.0, Ocean.Condition.CAUTION],
		[112.0, Ocean.Condition.CALM],
	]
	for sample in expected:
		_check(Ocean.condition_at(sample[0]) == sample[1], "Ocean flag at simulated second %.0f" % sample[0])
	for threshold in [0.34, 0.74]:
		var transition := acos(1.0 - 2.0 * threshold) * Ocean.SURF_PERIOD / TAU
		var before := Ocean.condition_at(transition - 0.01)
		var after := Ocean.condition_at(transition + 0.01)
		_check(after == before + 1 and Ocean.condition_at(Ocean.SURF_PERIOD - transition + 0.01) == before,
			"Ocean crosses the %.2f wave-energy threshold in both directions" % threshold)


func _test_pointer_navigation(game) -> void:
	var map_point := Vector2(775, 375)
	var home: Dictionary = game.camera.snapshot()
	var dock: Button = game.ui._dock_buttons["staff"]
	var dock_point := dock.get_global_rect().get_center()
	_click(dock_point)
	_check(game.ui._panel_id == "staff" and game.camera.snapshot() == home,
		"Routed Staff icon click opens one panel and leaves the camera fixed")
	_scroll_up(game.ui._popover.get_global_rect().get_center())
	_check(game.camera.snapshot() == home, "Wheel input over a contextual panel leaves the camera fixed")
	game.ui._body.options[0].pressed.emit()
	_check(game.simulation.float_station == 0, "Staff option applies its worker assignment")
	game.ui._body.options[1].pressed.emit()
	_drag(map_point, map_point + Vector2(80, 30), MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT)
	_check(not game.ui.has_open_panel() and game.camera.snapshot() == home,
		"An outside click dismisses the panel without beginning a drag")
	_scroll_up(dock_point)
	_check(game.camera.snapshot() == home, "Wheel input over the dock leaves the camera fixed")
	var label_layer := game.map.signs as Node2D
	var label_before := label_layer.get_global_transform().origin
	_drag(map_point, map_point + Vector2(80, 30), MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MASK_LEFT)
	_check(game.camera.snapshot() != home and not game.camera.is_dragging()
		and label_layer.get_global_transform().origin != label_before and dock.get_global_rect().get_center() == dock_point,
		"Routed hold-left drag moves world labels with the map while the dock stays fixed")
	var center_before: Vector2 = game.camera.snapshot().center
	_drag(map_point, map_point + Vector2(-40, -20), MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_MASK_MIDDLE)
	_check(game.camera.snapshot().center != center_before and not game.camera.is_dragging(), "Routed middle drag moves the map")
	var anchor: Vector2 = game.camera.screen_to_world(map_point)
	_scroll_up(map_point)
	_check(game.camera.zoom_level > home.zoom and game.camera.screen_to_world(map_point).is_equal_approx(anchor),
		"Routed wheel zoom preserves the world point under the cursor")
	var transport_zoom: float = game.camera.zoom_level
	var camera_controls := game.ui._camera as Panel
	var zoom_out: Button
	for child in camera_controls.get_children():
		if child is Button and child.tooltip_text == "Zoom out":
			zoom_out = child
	_click(zoom_out.get_global_rect().get_center())
	_check(game.camera.zoom_level < transport_zoom, "On-screen zoom button changes the view")
	_key(KEY_HOME)
	_check(game.camera.snapshot() == home, "Home resets the map to the opening view")
	_click(dock_point)
	var close := _button(game.ui._popover, "")
	_click(close.get_global_rect().get_center())
	_check(not game.ui.has_open_panel(), "Panel close button dismisses the panel")


func _test_v1_slot() -> void:
	if SaveSlot.exists():
		_check(false, "Original-save test requires a clean isolated profile")
		return
	var raw := FileAccess.get_file_as_bytes("res://tests/fixtures/v1_active_save.sav")
	var file := FileAccess.open(SaveSlot.PATH, FileAccess.WRITE)
	if raw.is_empty() or not file:
		_check(false, "Original active-save fixture is available and can be staged")
		return
	file.store_buffer(raw)
	file.close()
	var game = _open_scene()
	game.smoke_test_requested = true
	await process_frame
	var home: Dictionary = game.camera.snapshot()
	var saved := SaveSlot.read()
	_check(not saved.has("camera") and not game.dialog_load_button.disabled, "Original save is offered by the Welcome screen")
	game.dialog_load_button.pressed.emit()
	_check(game.started and game.paused and game.simulation.day == 1 and game.simulation.second == 58
		and game.simulation.cash == 620 and game.speed == 1 and game.simulation.selected_package == 1
		and game.simulation.float_station == 1 and not -1 in game.simulation.rooms,
		"Original release save restores Day 1 00:58, $620, Standard, buffet staffing and four occupied rooms")
	var loaded: Dictionary = game.simulation.snapshot()
	for key in ["mode", "layout", "pending_layout", "pending_reserve", "booked_count", "meal_version"]:
		loaded.erase(key)
	for family in loaded.families:
		for key in ["table_id", "dining_wait", "legacy_meal"]:
			family.erase(key)
	_check(loaded == saved.get("simulation") and game.simulation.mode == "regular"
		and game.simulation.layout.readiness().ok and game.camera.snapshot() == home
		and game.map.ocean.condition_name() == "Closed"
		and game.map.ocean.condition_color() == Ocean.CONDITION_COLORS[Ocean.Condition.CLOSED],
		"Original save retains its exact simulation, defaults to Home, and restores the red Closed flag")
	_key(KEY_1)
	game._process(1.0)
	_check(game.simulation.second == 59 and not game.paused, "Original save resumes through the global speed control")
	game.queue_free()


func _test_upgraded_legacy_slot() -> void:
	# Construct the old data shape from the authentic v1 fixture and set the legacy terrace flag.
	var raw := FileAccess.get_file_as_bytes("res://tests/fixtures/v1_active_save.sav")
	if raw.size() <= SaveSlot.HASH_LENGTH:
		_check(false, "Original active-save fixture is available")
		return
	var saved: Dictionary = bytes_to_var(raw.slice(SaveSlot.HASH_LENGTH))
	saved.version = 2
	saved.simulation.terrace = true
	saved.camera = {"zoom": 2.2, "center": Vector2(265, 150)}
	if not SaveSlot.write(saved):
		_check(false, "Synthetic upgraded v2 save can be staged")
		return
	var game = _open_scene()
	game.smoke_test_requested = true
	await process_frame
	game.dialog_load_button.pressed.emit()
	_check(game.paused and game.simulation.mode == "regular" and game.simulation.cash == saved.simulation.cash,
		"Synthetic v2 save preserves management state and defaults to Regular")
	_check(game.simulation.terrace and game.simulation.layout.readiness().terrace and game.simulation.capacity(2) == 2,
		"Upgraded legacy terrace migrates to functional pool furnishings")
	var furnishings: Array = game.simulation.layout.assets.filter(func(item: Dictionary) -> bool:
		return item.kind in ["lounger", "umbrella"]
	)
	_check(furnishings.size() == 3 and furnishings.all(func(item: Dictionary) -> bool: return item.paid_cost == 0),
		"Migrated loungers and umbrella carry no construction refund credit")
	_check(is_equal_approx(game.camera.zoom_level, 2.2), "Legacy camera state still restores")
	game.queue_free()


func _click(point: Vector2) -> void:
	_move_pointer(point)
	_mouse_button(point, MOUSE_BUTTON_LEFT, true)
	_mouse_button(point, MOUSE_BUTTON_LEFT, false)


func _scroll_up(point: Vector2) -> void:
	_move_pointer(point)
	_mouse_button(point, MOUSE_BUTTON_WHEEL_UP, true)
	_mouse_button(point, MOUSE_BUTTON_WHEEL_UP, false)


func _drag(from: Vector2, to: Vector2, button: MouseButton, mask: MouseButtonMask) -> void:
	_move_pointer(from)
	_mouse_button(from, button, true)
	_move_pointer(to, mask, to - from)
	_mouse_button(to, button, false)


func _move_pointer(point: Vector2, mask: MouseButtonMask = 0, relative: Vector2 = Vector2.ZERO) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	motion.button_mask = mask
	root.push_input(motion, true)


func _mouse_button(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = point
	event.global_position = point
	event.pressed = pressed
	if pressed and button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(event, true)


func _open_scene() -> Control:
	var game := Scene.instantiate() as Control
	root.add_child(game)
	game.set_process(false)
	return game


func _button(parent: Node, title: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == title:
			return child
	return null


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _label_texts(parent: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in parent.get_children():
		if child is Label:
			labels.append(child.text)
		labels.append_array(_label_texts(child))
	return labels


func _closed(sim: Sim) -> bool:
	return sim.rooms == [-1, -1, -1, -1] and sim.families.all(func(family: Dictionary) -> bool: return family.phase == "gone")


func _scores(sim: Sim) -> Array:
	return sim.reviews.map(func(review: Dictionary) -> int: return review.score)


func _tick(sim: Sim, seconds: int) -> void:
	for second in range(seconds):
		sim.tick()


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS | " + label)
	else:
		failed += 1
		push_error("FAIL | " + label)


func _terrace_plan(sim: Sim) -> Sim.Layout:
	var draft: Sim.Layout = sim.layout.duplicate_layout()
	var pool: Dictionary = draft.buildings.back()
	draft.add_asset("lounger", pool.id, Vector2i(1, 2))
	draft.add_asset("lounger", pool.id, Vector2i(16, 2))
	draft.add_asset("umbrella", pool.id, Vector2i(2, 7))
	return draft


func _same_state(left: Dictionary, right: Dictionary) -> bool:
	left = left.duplicate(true)
	right = right.duplicate(true)
	left.layout.erase("next_id")
	right.layout.erase("next_id")
	if not left.pending_layout.is_empty():
		left.pending_layout.erase("next_id")
	if not right.pending_layout.is_empty():
		right.pending_layout.erase("next_id")
	return left == right
