extends Control

const Sim = preload("res://scripts/simulation.gd")
const ResortMap = preload("res://scripts/resort_map.gd")
const ResortCamera = preload("res://scripts/resort_camera.gd")
const ResortUI = preload("res://scripts/resort_ui.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Layout = preload("res://scripts/layout_model.gd")
const ResortDesign = preload("res://scripts/resort_design.gd")
const DesignUI = preload("res://scripts/design_ui.gd")
const SAVE_VERSION := 3
const INK := Color("#382936")
const FRAME := Color("#332633")
const GOLD := Color("#e5bc78")
const CREAM := Color("#fff0d5")
const PAPER := Color("#f4e7cb")
const CARD := Color("#fff3d9")
const LINE := Color("#d7bf9c")
const MUTED := Color("#725d63")
const GREEN := Color("#27645d")
const WINE := Color("#754456")
const SOFT_RED := Color("#8a3c3d")
const STATION_NAMES := ["Reception", "Buffet", "Pool"]
const SPEEDS := [1, 2, 4]
const VIEW_SIZE := Vector2(1280, 720)

var simulation: Sim
var map: ResortMap
var camera: ResortCamera
var ui: ResortUI
var design: ResortDesign
var design_ui: DesignUI
var saved_draft: Layout
var speed := 1
var elapsed := 0.0
var paused := false
var settings_open := false
var started := false
var muted := false
var smoke_test_requested := false
var menu_mode := ""
var ui_font: Font
var display_font: Font

var toast_time := 0.0
var last_notice := ""

var overlay: ColorRect
var dialog: Panel
var dialog_status: Label
var dialog_shadow: Panel
var dialog_load_button: Button
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Dictionary = {}


func _ready() -> void:
	smoke_test_requested = "--smoke-test" in OS.get_cmdline_user_args()
	ui_font = _system_font(["Segoe UI Variable Text", "Segoe UI", "Arial"], 600)
	display_font = _system_font(["Segoe UI Variable Text", "Segoe UI", "Arial"], 700)
	_build_screen()
	_setup_audio()
	_set_simulation(Sim.new())
	_refresh()
	_open_dialog("welcome")
	if smoke_test_requested:
		call_deferred("_smoke_test")


func _process(delta: float) -> void:
	if not simulation:
		return
	var advancing := started and not paused and not settings_open and menu_mode.is_empty() and not simulation.stopped and design.draft == null
	if advancing:
		elapsed += delta * speed
		while elapsed >= 1.0 and not simulation.stopped:
			elapsed -= 1.0
			simulation.tick()
			_refresh()
		if simulation.stopped:
			elapsed = 0.0
			_open_dialog("recap")
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			last_notice = ""
			_refresh_ui()
	_present_map()


func _input(event: InputEvent) -> void:
	if design and design.draft:
		_design_input(event)
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode not in [KEY_ESCAPE, KEY_SPACE, KEY_1, KEY_2, KEY_3, KEY_HOME]:
		return
	if not menu_mode.is_empty() and event.keycode != KEY_ESCAPE:
		return
	get_viewport().set_input_as_handled()
	if event.echo or not started or not menu_mode.is_empty():
		return
	match event.keycode:
		KEY_ESCAPE:
			if ui.has_open_panel():
				ui.close_panel()
			else:
				ui.open_panel("settings")
		KEY_SPACE: _toggle_pause()
		KEY_1: _set_speed(1)
		KEY_2: _set_speed(2)
		KEY_3: _set_speed(4)
		KEY_HOME: camera.home()


func _set_simulation(value: Sim) -> void:
	if simulation:
		simulation.event_happened.disconnect(_on_simulation_event)
	simulation = value
	simulation.event_happened.connect(_on_simulation_event)


func _build_screen() -> void:
	camera = ResortCamera.new()
	camera.name = "ResortCamera"
	camera.size = VIEW_SIZE
	add_child(camera)
	camera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.configure(ResortMap.WORLD_BOUNDS, Vector2(265, 150), 1.8)

	map = ResortMap.new()
	map.name = "ResortMap"
	camera.world.add_child(map)
	design = ResortDesign.new()
	design.name = "DesignPreview"
	camera.world.add_child(design)

	ui = ResortUI.new()
	ui.name = "ResortUI"
	add_child(ui)
	ui.action_requested.connect(_on_ui_action)
	design_ui = DesignUI.new()
	design_ui.name = "DesignUI"
	add_child(design_ui)
	design_ui.action_requested.connect(_on_design_action)
	camera.pointer_blocked = func(point: Vector2) -> bool:
		return design_ui.is_pointer_over_ui(point) if design.draft else ui.is_pointer_over_ui(point)
	camera.interaction_allowed = func() -> bool:
		return started and menu_mode.is_empty() and not settings_open
	camera.view_changed.connect(_on_camera_changed)

	overlay = ColorRect.new()
	overlay.color = Color(0.12, 0.07, 0.12, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()


func _on_ui_action(action: String, value: Variant) -> void:
	if action == "open_panel" or action == "close_panel":
		settings_open = action == "open_panel" and value == "settings"
		camera.cancel_drag()
		if menu_mode.is_empty():
			_play_effect(&"click")
		_refresh_ui()
		return
	if not started or not menu_mode.is_empty():
		return
	_play_effect(&"click")
	match action:
		"package": _set_package(value)
		"staff": _set_station(value)
		"build": _enter_design()
		"pause": _toggle_pause()
		"speed": _set_speed(value)
		"save": _save_run()
		"load": _load_run()
		"mute": _toggle_mute()
		"quit": get_tree().quit()
		"zoom_in": camera.zoom_in()
		"zoom_out": camera.zoom_out()
		"home": camera.home()


func _present_map(layout_changed: bool = false) -> void:
	map.present(simulation, float(simulation.second) + elapsed, design.draft, layout_changed)


func _enter_design() -> void:
	if design.draft or simulation.stopped:
		return
	ui.set_interactive(false)
	ui.hide()
	camera.cancel_drag()
	camera.allow_left_drag = false
	var source := saved_draft if saved_draft else simulation.layout
	if simulation.pending_layout and not saved_draft:
		source = simulation.pending_layout
	design.enter(source)
	_present_map()
	_refresh_design_ui()


func _leave_design() -> void:
	design.leave()
	camera.cancel_drag()
	camera.allow_left_drag = true
	ui.show()
	ui.set_interactive(true)
	_refresh_design_ui()
	_refresh()


func _design_world_point(viewport_point: Vector2) -> Vector2:
	if design_ui.is_pointer_over_ui(viewport_point):
		return Vector2.INF
	var point := camera.get_global_transform().affine_inverse() * viewport_point
	if not Rect2(Vector2.ZERO, camera.size).has_point(point):
		return Vector2.INF
	return camera.screen_to_world(point)


func _design_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				design.cancel_operation()
			KEY_R:
				design.rotate_asset()
			KEY_HOME:
				camera.home()
			_:
				return
		get_viewport().set_input_as_handled()
		_refresh_design_ui()
	elif event is InputEventMouseMotion:
		design.move_pointer(_design_world_point(event.position))
		_refresh_design_ui()
	elif event is InputEventMouseButton:
		var point := _design_world_point(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and point.is_finite():
			design.cancel_operation()
			get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not point.is_finite() and (event.pressed or not design.drag_origin.is_finite()):
				return
			var edited := design.press(point) if event.pressed else design.release(point)
			if edited:
				_present_map(true)
				_play_effect(&"click")
			get_viewport().set_input_as_handled()
		_refresh_design_ui()


func _on_camera_changed(_zoom: float) -> void:
	if design.draft:
		design.move_pointer(_design_world_point(get_viewport().get_mouse_position()))
		_refresh_design_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and design and design.draft:
		if design.drag_origin.is_finite():
			design.cancel_operation()
			_refresh_design_ui()


func _on_design_action(action: String, value: Variant) -> void:
	if not design.draft:
		return
	_play_effect(&"click")
	match action:
		"tool", "building", "asset", "bulldoze":
			design.choose(action, value)
		"rotate":
			design.rotate_asset()
		"apply":
			var result := simulation.apply_construction(design.draft)
			if result.ok:
				saved_draft = null
				_leave_design()
				var message := "Construction queued for Day %d." % (simulation.day + 1) if result.defer else "Construction applied."
				_toast(message)
				return
			design.feedback = result.reason
			design.feedback_valid = false
		"discard":
			_leave_design()
			return
		"save_draft":
			if _write_run(design.draft):
				saved_draft = design.draft.duplicate_layout()
				design.feedback = "Run and draft saved."
				design.feedback_valid = true
			else:
				design.feedback = "Could not save the draft. Try again."
				design.feedback_valid = false
		"cancel_pending":
			if simulation.cancel_construction():
				design.feedback = "Queued construction canceled. The draft is still editable."
				design.feedback_valid = true
	_refresh_design_ui()


func _refresh_design_ui() -> void:
	if not design.draft:
		design_ui.refresh({"active": false})
		return
	var result := simulation.construction_status(design.draft)
	var placement := design.placement_feedback()
	var state := {
		"active": true, "tool": design.tool, "building": design.building, "asset": design.asset,
		"rotation": design.asset_rotation, "feedback": placement.text, "selection": design.selection_text(),
		"mode": simulation.mode, "cost": result.cost, "refund": result.refund, "cash": simulation.cash,
		"can_apply": result.ok, "apply_reason": result.reason, "defer_apply": result.defer,
		"apply_day": simulation.day + 1, "has_pending": simulation.pending_layout != null,
		"pending_day": simulation.day + 1, "pending_reserve": simulation.pending_reserve,
	}
	if placement.valid != null:
		state.feedback_valid = placement.valid
	if simulation.mode == "regular" and simulation.pending_reserve > 0:
		var net_label := "-$%d" % -result.net if result.net < 0 else "$%d" % result.net
		state.quote_label = "Cost $%d  ·  Refund $%d  ·  Net %s  ·  Available $%d incl. hold" % [
			result.cost, result.refund, net_label, result.available,
		]
	design_ui.refresh(state)


func _system_font(families: Array[String], weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(families)
	font.font_weight = weight
	return font


func _style(fill: Color, border: Color, radius: int, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	return style


func _panel(parent: Node, rect: Rect2, fill: Color, border: Color, radius: int) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border, radius))
	parent.add_child(panel)
	return panel


func _label(parent: Control, rect: Rect2, words: String, font_size: int, ink: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, font: Font = null) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = words
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", ui_font if font == null else font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)
	return label


func _button(parent: Control, rect: Rect2, words: String, action: Callable,
		font_size: int = 15, primary: bool = false) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = words
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, Color("#d98136"), 4, 2))
	button.pressed.connect(_play_effect.bind(&"click"))
	button.pressed.connect(action)
	parent.add_child(button)
	var normal := GREEN if primary else CARD
	var hover := Color("#36736a") if primary else Color("#f9ddb0")
	var border := GREEN if primary else LINE
	var ink := CREAM if primary else INK
	button.add_theme_stylebox_override("normal", _style(normal, border, 4))
	button.add_theme_stylebox_override("hover", _style(hover, border, 4))
	button.add_theme_stylebox_override("pressed", _style(hover.darkened(0.06), border, 4))
	button.add_theme_stylebox_override("disabled", _style(Color("#e8d9bc"), LINE, 4))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button


func _refresh() -> void:
	_present_map()
	map.actors.queue_redraw()
	map.signs.queue_redraw()
	_refresh_ui()


func _refresh_ui() -> void:
	ui.refresh({
		"simulation": simulation,
		"paused": paused,
		"speed": speed,
		"muted": muted,
		"can_load": SaveSlot.exists(),
		"notice": last_notice,
		"has_pending": simulation.pending_layout != null,
	})


func _format_rating(rating: float) -> String:
	return "%.1f" % snappedf(rating, 0.1)


func _set_package(index: int) -> void:
	simulation.selected_package = index
	var effective_day: int = simulation.day + int(simulation.booked_package >= 0)
	_toast("%s package selected for Day %d." % [Sim.PACKAGES[index].name, effective_day])
	_refresh()


func _set_station(index: int) -> void:
	if simulation.float_station != index:
		simulation.float_station = index
		_toast("Float assigned to %s. Active service continues." % STATION_NAMES[index].to_lower())
	_refresh()


func _toggle_pause() -> void:
	if started and menu_mode.is_empty():
		paused = not paused
		_refresh()


func _set_speed(rate: int) -> void:
	if started and menu_mode.is_empty():
		speed = rate
		paused = false
		_refresh()


func _on_simulation_event(kind: StringName, details: Dictionary) -> void:
	match kind:
		&"bookings":
			_toast("%d families booked today." % details.count)
		&"checkin":
			_toast("Room %s checked in  ·  +$%d" % [char(65 + details.room), details.price])
		&"upgrade":
			_toast("Pool terrace installed  ·  +1 pool slot")
		&"review":
			_toast("Room %s reviewed their stay  ·  %d/100" % [char(65 + details.room), details.score])
		&"day_close":
			_toast("Day %d closed  ·  %d stays  ·  $120 payroll  ·  $%d cash" % [details.day, details.stays, details.cash], 12.0)
		&"construction_applied":
			_toast("Queued construction applied on Day %d." % simulation.day, 12.0)
	_play_effect(kind)


func _toast(words: String, seconds: float = 5.0) -> void:
	last_notice = words
	toast_time = seconds
	_refresh_ui()


func _open_dialog(mode: String) -> void:
	_remove_dialog()
	menu_mode = mode
	camera.cancel_drag()
	ui.set_interactive(false)
	overlay.show()
	match mode:
		"welcome": _build_welcome()
		"new_run": _build_new_run()
		"recap": _build_recap()


func _remove_dialog() -> void:
	if is_instance_valid(dialog):
		overlay.remove_child(dialog)
		dialog.queue_free()
		dialog = null
	if is_instance_valid(dialog_shadow):
		overlay.remove_child(dialog_shadow)
		dialog_shadow.queue_free()
		dialog_shadow = null
	dialog_status = null
	dialog_load_button = null


func _close_dialog() -> void:
	_remove_dialog()
	overlay.hide()
	menu_mode = ""
	ui.set_interactive(true)
	_refresh()


func _make_dialog(width: float, height: float) -> void:
	var dimensions := Vector2(width, height)
	dialog_shadow = _panel(overlay, Rect2(Vector2.ZERO, dimensions), Color(0.13, 0.08, 0.13, 0.50), Color.TRANSPARENT, 5)
	dialog_shadow.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	dialog_shadow.position.y += 5.0
	dialog = _panel(overlay, Rect2(Vector2.ZERO, dimensions), PAPER, GOLD, 5)
	dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_panel(dialog, Rect2(24, 19, width - 48, 3), GREEN, GREEN, 1)
	dialog_status = _label(dialog, Rect2(26, height - 50, width - 52, 32), "", 14, SOFT_RED)
	dialog_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_welcome() -> void:
	_make_dialog(624, 435)
	_label(dialog, Rect2(30, 34, 564, 55), "All Inclusive", 43, INK, HORIZONTAL_ALIGNMENT_LEFT, display_font)
	_label(dialog, Rect2(31, 100, 558, 25), "Welcome families for three days at your tropical resort.", 18, INK)
	_label(dialog, Rect2(31, 132, 560, 46), "Families check in at reception, settle into a bedroom,\neat at the buffet, then head to the pool.", 16, MUTED)
	var objectives := _panel(dialog, Rect2(29, 189, 566, 63), CARD, LINE, 4)
	_label(objectives, Rect2(13, 4, 535, 23), "YOUR DAY 3 TARGETS", 12, WINE)
	_label(objectives, Rect2(13, 28, 535, 23), "8 completed stays    ·    75 average rating    ·    Pool terrace", 16, INK)
	_label(dialog, Rect2(31, 261, 560, 62), "Use Booking before 00:20 and Staff to shorten queues.\nUse Build to draw buildings and furnish the pool deck.\nDrag the map to explore, scroll to zoom, and press Home to reset.", 15, INK)

	var start := _button(dialog, Rect2(29, 344, 182, 42), "Regular resort", _new_run.bind("regular"), 16, true)
	_button(dialog, Rect2(221, 344, 214, 42), "Developer · Free build", _new_run.bind("developer"), 15)
	_add_load_button(Rect2(445, 344, 150, 42), 15)
	_focus_dialog_button.call_deferred(start)


func _build_recap() -> void:
	_make_dialog(574, 426)
	var result: Dictionary = simulation.milestone
	var success: bool = result.stays >= 8 and result.average >= 75.0 and result.terrace
	_label(dialog, Rect2(29, 31, 515, 51), "Day 3 recap", 38, INK, HORIZONTAL_ALIGNMENT_LEFT, display_font)
	_label(dialog, Rect2(30, 86, 513, 30), "Every target met" if success else "Your opening weekend is complete", 19, GREEN if success else WINE)
	var rows := [
		{"text": "%d completed stays   ·   Target 8" % result.stays, "achieved": result.stays >= 8},
		{"text": "%s average rating   ·   Target 75" % _format_rating(result.average), "achieved": result.average >= 75.0},
		{"text": "Pool terrace installed" if result.terrace else "Pool terrace pending", "achieved": result.terrace},
	]
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var card := _panel(dialog, Rect2(29, 125 + i * 37, 516, 33), CARD, LINE, 4)
		_label(card, Rect2(11, 0, 388, 33), row.text, 16, INK)
		_label(card, Rect2(395, 0, 110, 33), "Met" if row.achieved else "Missed", 14, GREEN if row.achieved else SOFT_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(dialog, Rect2(31, 243, 508, 27), "$%d cash at closing" % result.cash, 18, INK)

	var resume := _button(dialog, Rect2(29, 279, 516, 40), "Continue to Day 4", _continue_run, 17, true)
	_button(dialog, Rect2(29, 326, 252, 40), "Start a fresh run", _open_dialog.bind("new_run"))
	_add_load_button(Rect2(289, 326, 256, 40))
	_focus_dialog_button.call_deferred(resume)


func _add_load_button(rect: Rect2, font_size: int = 15) -> void:
	dialog_load_button = _button(dialog, rect, "Load saved run", _load_run, font_size)
	dialog_load_button.disabled = not SaveSlot.exists()


func _build_new_run() -> void:
	_make_dialog(540, 204)
	_label(dialog, Rect2(29, 29, 480, 45), "Start a fresh run", 32, INK, HORIZONTAL_ALIGNMENT_LEFT, display_font)
	_label(dialog, Rect2(29, 78, 480, 23), "Regular mode charges for construction and furnishings.", 16, MUTED)
	var start := _button(dialog, Rect2(29, 117, 154, 42), "Regular resort", _new_run.bind("regular"), 15, true)
	_button(dialog, Rect2(193, 117, 194, 42), "Developer · Free build", _new_run.bind("developer"), 15)
	_button(dialog, Rect2(397, 117, 114, 42), "Back", _open_dialog.bind("recap"), 15)
	_focus_dialog_button.call_deferred(start)


func _focus_dialog_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _new_run(mode: String = "regular") -> void:
	_set_simulation(Sim.new())
	simulation.mode = mode
	saved_draft = null
	started = true
	paused = false
	speed = 1
	elapsed = 0.0
	last_notice = ""
	toast_time = 0.0
	ui.close_panel()
	camera.home()
	_close_dialog()
	_start_music()


func _continue_run() -> void:
	simulation.continue_after_recap()
	elapsed = 0.0
	paused = false
	_close_dialog()
	_toast("Day %d is open." % simulation.day)
	_start_music()


func _save_run() -> void:
	if _write_run(saved_draft):
		var clock := "%02d:%02d" % [floori(simulation.second / 60.0), simulation.second % 60]
		_toast("Run saved at Day %d  ·  %s" % [simulation.day, clock])
	else:
		_show_save_error("Could not save the run. Try again.")


func _write_run(draft: Layout) -> bool:
	return SaveSlot.write({
		"version": SAVE_VERSION, "simulation": simulation.snapshot(),
		"draft": draft.snapshot() if draft else {}, "elapsed": elapsed,
		"speed": speed, "camera": camera.snapshot(),
	})


func _load_run() -> void:
	var data: Dictionary = SaveSlot.read()
	var loaded := Sim.new()
	var valid: bool = (
		data.get("version") in [1, 2, SAVE_VERSION] and data.get("simulation") is Dictionary
		and data.get("speed") is int and data.speed in SPEEDS and data.get("elapsed") is float
		and is_finite(data.elapsed) and data.elapsed >= 0.0 and data.elapsed < 1.0
		and loaded.restore(data.simulation, data.version < SAVE_VERSION)
	)
	var draft: Layout
	if valid and data.version == SAVE_VERSION:
		valid = data.get("draft") is Dictionary
		if valid and not data.draft.is_empty():
			draft = Layout.new()
			valid = draft.restore(data.draft)
	if not valid:
		_show_save_error("The save is missing or unreadable. Your current run is safe.")
		return
	_set_simulation(loaded)
	saved_draft = draft
	speed = data.speed
	elapsed = data.elapsed
	started = true
	paused = true
	ui.close_panel()
	camera.home()
	if data.get("camera") is Dictionary:
		camera.restore(data.camera)
	if simulation.stopped:
		_refresh()
		_open_dialog("recap")
	else:
		_close_dialog()
		_toast("Run loaded. Open Build to resume your draft." if saved_draft else "Saved run loaded  ·  Clock paused")
	_start_music()


func _show_save_error(words: String) -> void:
	if is_instance_valid(dialog_status):
		dialog_status.text = words
		dialog_status.add_theme_color_override("font_color", SOFT_RED)
	else:
		_toast(words, 8.0)


func _setup_audio() -> void:
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		muted = settings.get_value("audio", "muted", false) == true
	music = _audio_player("res://assets/audio/music_resort.wav", -13.0, true)
	ambience = _audio_player("res://assets/audio/ambience_surf.wav", -16.0, true)
	var cue_files := {
		&"click": "ui_click",
		&"checkin": "guest_checkin",
		&"upgrade": "resort_upgrade",
		&"day_close": "day_close",
		&"review": "guest_review",
	}
	for event in cue_files:
		var volume := -12.0 if event == &"click" else -7.0
		var player := _audio_player("res://assets/audio/%s.wav" % cue_files[event], volume)
		if player:
			effects[event] = player
	_apply_mute()


func _audio_player(path: String, volume: float, loop: bool = false) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var player := AudioStreamPlayer.new()
	player.stream = load(path) as AudioStream
	player.volume_db = volume
	if loop and player.stream is AudioStreamWAV:
		var track := player.stream as AudioStreamWAV
		var frames := roundi(track.get_length() * track.mix_rate)
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_begin = 0
		track.loop_end = frames
	add_child(player)
	return player


func _start_music() -> void:
	if smoke_test_requested:
		return
	if music and not music.playing:
		music.play()
	if ambience and not ambience.playing:
		ambience.play()


func _play_effect(event: StringName) -> void:
	if not smoke_test_requested and effects.has(event):
		effects[event].play()


func _toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	var settings := ConfigFile.new()
	settings.set_value("audio", "muted", muted)
	settings.save("user://settings.cfg")
	_refresh()


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, muted)


func _smoke_test() -> void:
	_new_run()
	var draft: Layout = simulation.layout.duplicate_layout()
	var pool: Dictionary = draft.buildings.back()
	draft.add_asset("lounger", pool.id, Vector2i(1, 2))
	draft.add_asset("lounger", pool.id, Vector2i(16, 2))
	draft.add_asset("umbrella", pool.id, Vector2i(2, 7))
	for i in range(3 * Sim.DAY_LENGTH):
		simulation.tick()
		if simulation.day == 2 and simulation.second == 0:
			simulation.apply_construction(draft)
	_refresh()
	if simulation.cash != 1120 or simulation.reviews.size() != 12 or not simulation.terrace or not simulation.stopped:
		push_error("All Inclusive smoke test failed: %s" % simulation.snapshot())
		get_tree().quit(1)
		return
	if not is_equal_approx(simulation.average(), 95.25):
		push_error("All Inclusive smoke test rating mismatch: %f" % simulation.average())
		get_tree().quit(1)
		return
	map.present(simulation, float(simulation.second))
	if (
		not map.base_art or map.base_art.get_size() != ResortMap.WORLD_BOUNDS.size
		or not map.renderer or not map.people or map.ocean.condition_name() != "Closed"
		or not music or not ambience or effects.size() != 5
	):
		push_error("All Inclusive smoke test could not load all production art and audio.")
		get_tree().quit(1)
		return
	_open_dialog("recap")
	print("ALL INCLUSIVE SMOKE PASS — 12 stays, 95.25 rating, $1120, furnished terrace, modular map, ocean and audio loaded")
	get_tree().quit()
