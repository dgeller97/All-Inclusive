extends Control

const Sim = preload("res://scripts/simulation.gd")
const ResortMap = preload("res://scripts/resort_map.gd")
const ResortCamera = preload("res://scripts/resort_camera.gd")
const ResortUI = preload("res://scripts/resort_ui.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Layout = preload("res://scripts/layout_model.gd")
const ResortDesign = preload("res://scripts/resort_design.gd")
const DesignUI = preload("res://scripts/design_ui.gd")
const SAVE_VERSION := 8
const LEISURE_SAVE_VERSION := 7
const DINING_SAVE_VERSION := 6
const EXTERIOR_SAVE_VERSION := 5
const LANDSCAPE_SAVE_VERSION := 4
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
var exterior_view := false
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
var interface_layer: CanvasLayer
var dialog: Panel
var dialog_status: Label
var dialog_shadow: Panel
var dialog_load_button: Button
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var effects: Dictionary = {}
var animation_viewer: Control
var _viewer_return_focus: Control
var _viewer_ui_input := false


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
	if is_instance_valid(animation_viewer) and animation_viewer.visible:
		return
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
	if is_instance_valid(animation_viewer) and animation_viewer.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F8]:
			animation_viewer.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_open_animation_viewer()
		get_viewport().set_input_as_handled()
		return
	if not menu_mode.is_empty() and design and design.draft:
		return
	if design and design.draft:
		_design_input(event)
		return
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode not in [KEY_ESCAPE, KEY_SPACE, KEY_1, KEY_2, KEY_3, KEY_HOME]:
		return
	if not menu_mode.is_empty() and event.keycode != KEY_ESCAPE:
		return
	if event.keycode != KEY_ESCAPE and ui.has_transient_popup():
		return
	get_viewport().set_input_as_handled()
	if event.echo or not started or not menu_mode.is_empty():
		return
	match event.keycode:
		KEY_ESCAPE:
			if ui.close_transient_popup():
				return
			elif ui.has_open_panel():
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
	if camera:
		camera.home_center = Vector2(160, 120) if simulation.mode == "developer" else Vector2(280, 170)
		camera.home_zoom = 1.0 if simulation.mode == "developer" else 1.7


func _build_screen() -> void:
	camera = ResortCamera.new()
	camera.name = "ResortCamera"
	camera.size = VIEW_SIZE
	add_child(camera)
	camera.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera.configure(ResortMap.WORLD_BOUNDS, Vector2(280, 170), 1.7)

	map = ResortMap.new()
	map.name = "ResortMap"
	camera.world.add_child(map)
	design = ResortDesign.new()
	design.name = "DesignPreview"
	camera.world.add_child(design)

	# World depth (including elevated building plaques) must never outrank menus.
	# Canvas layers isolate that ordering without changing guest/object occlusion.
	interface_layer = CanvasLayer.new()
	interface_layer.name = "Interface"
	interface_layer.layer = 1
	add_child(interface_layer)
	ui = ResortUI.new()
	ui.name = "ResortUI"
	interface_layer.add_child(ui)
	ui.action_requested.connect(_on_ui_action)
	design_ui = DesignUI.new()
	design_ui.name = "DesignUI"
	interface_layer.add_child(design_ui)
	design_ui.action_requested.connect(_on_design_action)
	camera.pointer_blocked = func(point: Vector2) -> bool:
		return design_ui.is_pointer_over_ui(point) if design.draft else ui.is_pointer_over_ui(point)
	camera.interaction_allowed = func() -> bool:
		return started and menu_mode.is_empty() and not settings_open and not (is_instance_valid(animation_viewer) and animation_viewer.visible)
	camera.view_changed.connect(_on_camera_changed)

	overlay = ColorRect.new()
	overlay.color = Color(0.12, 0.07, 0.12, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	interface_layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()


func _on_ui_action(action: String, value: Variant) -> void:
	if is_instance_valid(animation_viewer) and animation_viewer.visible:
		return
	if action == "open_panel" or action == "close_panel":
		settings_open = action == "open_panel" and value == "settings"
		camera.cancel_drag()
		if menu_mode.is_empty():
			_play_effect(&"click")
		_refresh_ui()
		return
	if not started or not menu_mode.is_empty():
		return
	if action in ["developer_month", "developer_sargassum", "developer_arrival", "developer_rescue_drill"] and simulation.mode != "developer":
		return
	if action == "room_price":
		simulation.set_price(value)
		_refresh_ui()
		return
	if action == "developer_sargassum":
		if simulation.set_developer_sargassum_intensity(value):
			_refresh()
		return
	_play_effect(&"click")
	match action:
		"package": _set_package(value)
		"swim_policy":
			if simulation.set_swim_policy(value):
				_refresh()
		"clean_beach":
			var result := simulation.clean_beach()
			_toast("Removed %d%% sargassum buildup." % result.removed if result.ok else result.reason)
			_refresh()
		"staff": _set_station(value)
		"hire_lifeguard", "assign_lifeguard": _set_guard_site(value, action == "hire_lifeguard")
		"developer_month":
			if simulation.set_developer_month(value):
				_refresh()
		"developer_arrival":
			if simulation.seed_sargassum_arrival():
				_toast("New offshore patch drifting toward shore.")
				_refresh()
			else:
				_toast("An offshore patch could not be added.")
		"developer_rescue_drill": _start_rescue_drill()
		"build": _enter_design()
		"building_view":
			exterior_view = not exterior_view
			_refresh()
		"pause": _toggle_pause()
		"speed": _set_speed(value)
		"save": _save_run()
		"load": _load_run()
		"mute": _toggle_mute()
		"animations": _open_animation_viewer()
		"quit": get_tree().quit()
		"zoom_in": camera.zoom_in()
		"zoom_out": camera.zoom_out()
		"home": camera.home()


func _open_animation_viewer() -> void:
	if is_instance_valid(animation_viewer) and animation_viewer.visible:
		return
	ui.close_transient_popup()
	_viewer_return_focus = get_viewport().gui_get_focus_owner()
	_viewer_ui_input = ui.is_processing_input()
	ui.set_process_input(false)
	camera.cancel_drag()
	if design.draft and design.is_drawing():
		design._reset_drag()
		design._update_ghost()
	if not is_instance_valid(animation_viewer):
		animation_viewer = load("res://scripts/animation_viewer.gd").new()
		animation_viewer.name = "AnimationViewer"
		interface_layer.add_child(animation_viewer)
		animation_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		animation_viewer.viewer_closed.connect(_on_animation_viewer_closed)
	animation_viewer.show_viewer()


func _on_animation_viewer_closed() -> void:
	ui.set_process_input(_viewer_ui_input)
	if is_instance_valid(_viewer_return_focus) and _viewer_return_focus.is_visible_in_tree():
		_viewer_return_focus.grab_focus()
	_viewer_return_focus = null


func _present_map(layout_changed: bool = false) -> void:
	var ceiling_id := design.settings_building_id if design.inspect_ceiling else -1
	var shown_exterior := design.inspect_exterior if design.draft else exterior_view
	map.present(simulation, float(simulation.second) + elapsed, design.draft, layout_changed, shown_exterior, ceiling_id)


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
	if event is InputEventKey and design_ui.editing_building_name():
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			design_ui.cancel_building_name_edit()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if design.settings_building_id >= 0:
					design.close_building_settings()
				else:
					design.cancel_operation()
			KEY_R:
				if design.rotate_asset():
					_present_map(true)
			KEY_HOME:
				if design.is_drawing():
					design.cancel_operation()
				camera.home()
			_:
				return
		get_viewport().set_input_as_handled()
		_refresh_design_ui()
	elif event is InputEventMouseMotion:
		design.move_pointer(_design_world_point(event.position), bool(event.button_mask & MOUSE_BUTTON_MASK_LEFT))
		_refresh_design_ui()
	elif event is InputEventMouseButton:
		var point := _design_world_point(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (point.is_finite() or design.is_drawing()):
			design.cancel_operation()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if design.is_drawing():
				design.cancel_operation()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and camera.is_dragging():
				get_viewport().set_input_as_handled()
				return
			if not point.is_finite() and (event.pressed or not design.is_drawing()):
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
		if design.is_drawing():
			design.cancel_operation()
			_refresh_design_ui()


func _on_design_action(action: String, value: Variant) -> void:
	if not design.draft or not menu_mode.is_empty():
		return
	_play_effect(&"click")
	match action:
		"tool", "building", "asset", "bulldoze", "category", "landscape_group", "facility_group", "terrain", "path", "restore", "brush_size", "prop", "move":
			design.choose(action, value)
		"rotate":
			if design.rotate_asset():
				_present_map(true)
		"open_building_settings":
			camera.cancel_drag()
			design.open_building_settings()
		"close_building_settings":
			design.close_building_settings()
		"inspect_ceiling":
			design.toggle_ceiling_inspection()
		"inspect_exterior":
			design.set_exterior_inspection(not design.inspect_exterior)
		"building_name":
			var result := design.draft.set_building_name(design.settings_building_id, value)
			if result.ok:
				_present_map(true)
			_refresh_design_ui()
			design_ui.show_building_name_result(result)
			return
		"building_finish":
			var result := design.draft.set_building_finish(design.settings_building_id, value.surface, value.choice)
			if result.ok:
				if value.surface in ["facade", "roof"]:
					design.set_exterior_inspection(true)
				_present_map(true)
		"apply":
			if design.is_drawing():
				design.cancel_operation()
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
			if design.is_drawing():
				design.cancel_operation()
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
	var ceiling_id := design.settings_building_id if design.inspect_ceiling else -1
	if map.ceiling_id != ceiling_id or map.exterior_view != design.inspect_exterior:
		_present_map()
	var result := simulation.construction_status(design.draft)
	var placement := design.placement_feedback()
	var state := {
		"active": true, "tool": design.tool, "selected_tool": design.selected_tool(),
		"category": design.category, "landscape_group": design.landscape_group, "facility_group": design.facility_group,
		"brush_size": design.brush_size, "can_move": design.can_move(), "can_rotate": design.can_rotate(),
		"rotation": design.displayed_rotation(), "feedback": placement.text, "selection": design.selection_text(),
		"selected_building": design.selected_building(), "building_settings_open": design.settings_building_id >= 0,
		"inspect_ceiling": design.inspect_ceiling, "inspect_exterior": design.inspect_exterior,
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
		"exterior_view": exterior_view,
		"speed": speed,
		"muted": muted,
		"can_load": SaveSlot.exists(),
		"notice": last_notice,
		"has_pending": simulation.pending_layout != null,
	})


func _format_rating(rating: float) -> String:
	return "%.1f" % snappedf(rating, 0.1)


func _set_package(index: int) -> void:
	simulation.set_price(Sim.PACKAGES[index].price)
	var effective_day: int = simulation.day + int(simulation.booked_package >= 0)
	_toast("%s package selected for Day %d." % [Sim.PACKAGES[index].name, effective_day])
	_refresh()


func _set_station(index: int) -> void:
	if simulation.float_station != index:
		simulation.float_station = index
		_toast("Float assigned to %s. Active service continues." % simulation.station_name(index))
	_refresh()


func _set_guard_site(site: String, hire: bool) -> void:
	var ok: bool = simulation.hire_lifeguard(site) if hire else simulation.assign_lifeguard(site)
	if ok:
		var site_name := "beach" if site == "beach" else "main pool"
		_toast("Lifeguard hired for the %s." % site_name if hire else "Lifeguard reassigned to the %s." % site_name)
		_refresh()
	elif not simulation.rescue.is_empty():
		_toast("The lifeguard is assisting a swimmer.")
	elif not simulation.lifeguard_site_available(site):
		_toast("No usable lifeguard post at this site.")
	elif hire and simulation.cash < Sim.LIFEGUARD_HIRE_COST:
		_toast("Hiring a lifeguard costs $%d." % Sim.LIFEGUARD_HIRE_COST)


func _start_rescue_drill() -> void:
	if simulation.start_rescue_drill():
		var label := "Beach" if simulation.lifeguard_assignment == "beach" else "Main pool"
		var volunteer: bool = int(simulation.rescue.get("family", -1)) < 0
		_toast("%s drill started with a volunteer." % label if volunteer else "%s rescue drill started." % label)
		_refresh()
	elif simulation.lifeguard_assignment.is_empty():
		_toast("Hire a lifeguard in Staff to run a drill.")
	elif not simulation.rescue.is_empty():
		_toast("Finish the active rescue before starting a drill.")
	elif not simulation.lifeguard_site_available(simulation.lifeguard_assignment):
		_toast("The assigned site has no usable lifeguard post.")
	else:
		_toast("Wait until tomorrow to start another drill.")


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
			_toast("%s checked in  ·  +$%d" % [simulation.room_name(details.room), details.price])
		&"upgrade":
			_toast("Pool terrace installed  ·  +1 pool slot")
		&"review":
			_toast("%s reviewed their stay  ·  %d/100" % [simulation.room_name(details.room), details.score])
		&"ocean_incident":
			_toast("Fatal ocean incident. The surviving guest is leaving.", 12.0)
		&"rescue_started":
			if not details.get("drill", false):
				_toast("The lifeguard is responding to a swimmer.", 8.0)
		&"rescue_finished":
			match details.get("outcome", ""):
				"rescued": _toast("The lifeguard brought the swimmer to safety.", 8.0)
				"drill_complete": _toast("Rescue drill complete.")
				"self_recovered": _toast("The swimmer returned to safety.", 8.0)
		&"day_close":
			_toast("Day %d closed  ·  %d stays  ·  $%d payroll  ·  $%d cash" % [details.day, details.stays,
				details.get("payroll", Sim.PAYROLL), details.cash], 12.0)
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
	if design.draft:
		design.close_building_settings()
		_refresh_design_ui()
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
	_make_dialog(624, 510)
	_label(dialog, Rect2(30, 34, 564, 55), "All Inclusive", 43, INK, HORIZONTAL_ALIGNMENT_LEFT, display_font)
	_label(dialog, Rect2(31, 100, 558, 25), "Welcome families for three days at your tropical resort.", 18, INK)
	_label(dialog, Rect2(31, 132, 560, 46), "Families check in, settle into a bedroom, collect food,\neat at a restaurant table, then head to the pool.", 16, MUTED)
	var objectives := _panel(dialog, Rect2(29, 189, 566, 63), CARD, LINE, 4)
	_label(objectives, Rect2(13, 4, 535, 23), "YOUR DAY 3 TARGETS", 12, WINE)
	_label(objectives, Rect2(13, 28, 535, 23), "8 completed stays    ·    75 average rating    ·    Pool terrace", 16, INK)
	_label(dialog, Rect2(31, 257, 560, 99), "Set the room price before 08:00 and use Staff to shorten queues.\nUse Beach for swimming rules and Build to reshape the resort.\nDrag to explore, scroll to zoom, and press Home to reset.\nDeveloper showcase: every asset placed, with free editing.", 15, INK)

	var start := _button(dialog, Rect2(29, 365, 182, 42), "Regular resort", _new_run.bind("regular"), 16, true)
	_button(dialog, Rect2(221, 365, 214, 42), "Developer showcase", _new_run.bind("developer"), 15)
	_add_load_button(Rect2(445, 365, 150, 42), 15)
	_button(dialog, Rect2(29, 418, 566, 36), "Animation viewer · Compare all four rotations (F8)", _open_animation_viewer, 15)
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
	_make_dialog(540, 232)
	_label(dialog, Rect2(29, 29, 480, 45), "Start a fresh run", 32, INK, HORIZONTAL_ALIGNMENT_LEFT, display_font)
	_label(dialog, Rect2(29, 78, 480, 50), "Regular: build your resort and pay construction costs.\nDeveloper: every asset placed, ready to watch and freely edit.", 16, MUTED)
	var start := _button(dialog, Rect2(29, 145, 154, 42), "Regular resort", _new_run.bind("regular"), 15, true)
	_button(dialog, Rect2(193, 145, 194, 42), "Developer showcase", _new_run.bind("developer"), 15)
	_button(dialog, Rect2(397, 145, 114, 42), "Back", _open_dialog.bind("recap"), 15)
	_focus_dialog_button.call_deferred(start)


func _focus_dialog_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree():
		button.grab_focus()


func _new_run(mode: String = "regular") -> void:
	var fresh := Sim.new()
	if not fresh.configure_new_run(mode):
		_show_save_error("Could not prepare the new resort. Your current run is intact.")
		return
	_set_simulation(fresh)
	saved_draft = null
	started = true
	paused = false
	exterior_view = false
	speed = 1
	elapsed = 0.0
	last_notice = ""
	toast_time = 0.0
	ui.close_panel()
	camera.home()
	_close_dialog()
	_start_music()
	if mode == "developer":
		_toast("Every asset is placed. Guests explore activities across three days. Build edits are free.", 9.0)


func _continue_run() -> void:
	simulation.continue_after_recap()
	elapsed = 0.0
	paused = false
	_close_dialog()
	_toast("Day %d is open." % simulation.day)
	_start_music()


func _save_run() -> void:
	if _write_run(saved_draft):
		var clock: String = simulation.calendar_state().time_label
		_toast("Run saved at Day %d  ·  %s" % [simulation.day, clock])
	else:
		_show_save_error("Could not save the run. Try again.")


func _write_run(draft: Layout) -> bool:
	return SaveSlot.write({
		"version": SAVE_VERSION, "simulation": simulation.snapshot(),
		"draft": draft.snapshot() if draft else {}, "elapsed": elapsed,
		"speed": speed, "camera": camera.snapshot(), "exterior_view": exterior_view,
	})


func _load_run() -> void:
	var data: Dictionary = SaveSlot.read()
	var version: Variant = data.get("version")
	var has_landscape: bool = version in [LANDSCAPE_SAVE_VERSION, EXTERIOR_SAVE_VERSION, DINING_SAVE_VERSION, LEISURE_SAVE_VERSION, SAVE_VERSION]
	var has_appearance: bool = version in [EXTERIOR_SAVE_VERSION, DINING_SAVE_VERSION, LEISURE_SAVE_VERSION, SAVE_VERSION]
	var has_meals: bool = version in [DINING_SAVE_VERSION, LEISURE_SAVE_VERSION, SAVE_VERSION]
	var has_leisure: bool = version in [LEISURE_SAVE_VERSION, SAVE_VERSION]
	if has_landscape and _save_changes_protected_coast(data):
		_show_save_error("This save changes the protected coast. Your file and run are intact.")
		return
	var loaded := Sim.new()
	var valid: bool = (
		(version in [1, 2, 3] or has_landscape) and data.get("simulation") is Dictionary
		and data.get("speed") is int and data.speed in SPEEDS and data.get("elapsed") is float
		and is_finite(data.elapsed) and data.elapsed >= 0.0 and data.elapsed < 1.0
		and loaded.restore(data.simulation, version < 3, has_landscape, has_meals, has_leisure, version == SAVE_VERSION)
	)
	var draft: Layout
	if valid and data.version >= 3:
		valid = data.get("draft") is Dictionary
		if valid and not data.draft.is_empty():
			draft = Layout.new(false)
			valid = ((not has_landscape or data.draft.get("landscape") is Dictionary)
				and (version != SAVE_VERSION or data.draft.get("version") == 4) and draft.restore(data.draft))
			if valid and not data.draft.has("landscape"):
				Sim.prune_migrated_scenery(draft, loaded.layout)
	if not valid:
		_show_save_error("The save is missing or unreadable. Your current run is safe.")
		return
	_set_simulation(loaded)
	saved_draft = draft
	speed = data.speed
	elapsed = data.elapsed
	started = true
	paused = true
	exterior_view = has_appearance and data.get("exterior_view") == true
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


func _save_changes_protected_coast(data: Dictionary) -> bool:
	var saved_sim: Variant = data.get("simulation")
	if not saved_sim is Dictionary:
		return false
	for layout in [saved_sim.get("layout"), saved_sim.get("pending_layout"), data.get("draft")]:
		if layout is Dictionary:
			var landscape: Variant = layout.get("landscape")
			if landscape is Dictionary and Layout.Landscape.has_protected_water_edits(landscape):
				return true
	return false


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
	if not _smoke_landscape():
		push_error("All Inclusive smoke test could not load the editable landscape defaults.")
		get_tree().quit(1)
		return
	var draft: Layout = simulation.layout.duplicate_layout()
	var pool: Dictionary = draft.buildings.back()
	draft.add_asset("lounger", pool.id, Vector2i(1, 2))
	draft.add_asset("lounger", pool.id, Vector2i(16, 2))
	draft.add_asset("umbrella", pool.id, Vector2i(2, 7))
	var collected := false
	var waited_for_table := false
	var ate_at_table := false
	var left_table := false
	var activities := {}
	var swam_in_ocean := false
	var saw_daylight := false
	var saw_night := false
	for i in range(3 * Sim.DAY_LENGTH):
		simulation.tick()
		var daylight: float = simulation.calendar_state().daylight
		saw_daylight = saw_daylight or daylight > 0.9
		saw_night = saw_night or daylight < 0.1
		collected = collected or simulation.count_at(1, "service") > 0
		waited_for_table = waited_for_table or simulation.count_at(1, "wait_table") > 0
		ate_at_table = ate_at_table or simulation.count_at(1, "eating") > 0
		left_table = left_table or simulation.count_at(1, "to_pool") > 0
		for family in simulation.families:
			swam_in_ocean = swam_in_ocean or family.phase == "ocean_swim"
			for kind in family.leisure_completed:
				activities[kind] = true
		if simulation.day == 2 and simulation.second == 0:
			simulation.apply_construction(draft)
	_refresh()
	if not (collected and waited_for_table and ate_at_table and left_table):
		push_error("All Inclusive smoke test did not exercise the full restaurant meal.")
		get_tree().quit(1)
		return
	if not Sim.STARTER_LEISURE.all(func(kind: String) -> bool: return activities.has(kind)):
		push_error("All Inclusive smoke test did not exercise all four beach activities.")
		get_tree().quit(1)
		return
	if simulation.cash != 1120 or simulation.reviews.size() != 12 or not simulation.terrace or not simulation.stopped:
		push_error("All Inclusive smoke test failed: %s" % simulation.snapshot())
		get_tree().quit(1)
		return
	if not is_equal_approx(simulation.average(), 1145.0 / 12.0):
		push_error("All Inclusive smoke test rating mismatch: %f" % simulation.average())
		get_tree().quit(1)
		return
	if not (saw_daylight and saw_night and swam_in_ocean and simulation.sargassum > 0 and simulation.ocean_incidents.is_empty()
		and _smoke_risk_and_rotation()):
		push_error("All Inclusive smoke test failed the calendar, ocean risk, pricing, or construction checks.")
		get_tree().quit(1)
		return
	if not _smoke_new_facilities():
		push_error("All Inclusive smoke test failed to exercise the ten new facilities.")
		get_tree().quit(1)
		return
	if not _smoke_developer_showcase():
		push_error("All Inclusive smoke test failed the Developer showcase.")
		get_tree().quit(1)
		return
	if not await _smoke_animation_viewer():
		push_error("All Inclusive smoke test failed the animation viewer.")
		get_tree().quit(1)
		return
	var baseline := simulation.snapshot()
	var layout_id := Layout._next_id
	var prop_id := Layout.Landscape._next_prop_id
	set_process(false)
	var coast_and_rescue := await _smoke_r18_coast_and_rescue()
	Layout._next_id = layout_id
	Layout.Landscape._next_prop_id = prop_id
	map.present(simulation, float(simulation.second))
	if not coast_and_rescue or simulation.snapshot() != baseline:
		push_error("All Inclusive smoke test failed R18 offshore landfall, lifeguard drills, or rescue save continuation.")
		get_tree().quit(1)
		return
	if (
		not map.base_art or map.base_art.get_size() != ResortMap.WORLD_BOUNDS.size
		or not map.renderer or not map.people or map.ocean.condition_name() != "Closed"
		or not music or not ambience or effects.size() != 5
	):
		push_error("All Inclusive smoke test could not load all production art and audio.")
		get_tree().quit(1)
		return
	_open_dialog("recap")
	print("ALL INCLUSIVE SMOKE PASS — 12 stays, %.2f rating, $1120; dining, terrace, ten new facility visits, calendar, surf risk, sargassum, price lock, construction, art and audio; expanded Developer showcase visits all 14 activities; 20 animation viewer clips; R18 month and intensity, offshore landfall, both lifeguard posts and drills, active rescue restore" % simulation.average())
	get_tree().quit()


func _smoke_r18_coast_and_rescue() -> bool:
	var trial := Sim.new()
	if not trial.configure_new_run("developer") or not trial.set_developer_month(7) or not trial.set_developer_sargassum_intensity(70):
		return false
	if trial.day != 1 or trial.second != 0 or trial.calendar_state().month != 7 or trial.sargassum_intensity != 70:
		return false
	var forced := Sim.Sargassum.raft(0, Sim.Sargassum.FORCED_LANE, trial.sargassum_seed)
	if not trial.seed_sargassum_arrival() or not trial.floating_sargassum().any(func(patch: Dictionary) -> bool: return patch.id == forced.id):
		return false
	map.present(trial, 0.0)
	await get_tree().process_frame
	for i in range(forced.lands_at):
		trial.tick()
	if trial.floating_sargassum().any(func(patch: Dictionary) -> bool: return patch.id == forced.id):
		return false
	if not trial.beach_deposits.any(func(pile: Dictionary) -> bool: return pile.row == forced.row and pile.amount >= forced.mass):
		return false
	var cash_before := trial.cash
	if not trial.hire_lifeguard("beach") or trial.cash != cash_before:
		return false
	for site in ["beach", "pool"]:
		if trial.lifeguard_assignment != site and not trial.assign_lifeguard(site):
			return false
		map.present(trial, float(trial.second))
		if not map._depth_plan().any(func(item: Dictionary) -> bool: return item.tag == "lifeguard" and item.seated):
			return false
		await get_tree().process_frame
		if not trial.start_rescue_drill() or trial.rescue.site != site:
			return false
		trial.tick()
		if site == "beach":
			var restored := Sim.new()
			if not restored.restore(trial.snapshot()) or restored.rescue != trial.rescue or restored.rescue_positions() != trial.rescue_positions():
				return false
			trial = restored
		map.present(trial, float(trial.second))
		var plan := map._depth_plan()
		if not plan.any(func(item: Dictionary) -> bool: return item.tag == "lifeguard" and not item.seated):
			return false
		if not plan.any(func(item: Dictionary) -> bool: return item.tag == "rescue_float"):
			return false
		await get_tree().process_frame
		for i in range(Sim.RESCUE_DURATION):
			trial.tick()
		if not trial.rescue.is_empty() or trial.last_rescue.get("site") != site or trial.last_rescue.get("outcome") != "drill_complete":
			return false
	return true


func _smoke_developer_showcase() -> bool:
	var trial := Sim.new()
	if not trial.configure_new_run("developer") or not trial.layout.readiness().ok:
		return false
	for kind: String in Layout.ASSET_CATALOG:
		if not trial.layout.assets.any(func(item: Dictionary) -> bool: return item.kind == kind):
			return false
	for kind: String in Layout.Landscape.PROP_CATALOG:
		if not trial.layout.landscape.props.any(func(item: Dictionary) -> bool: return item.kind == kind):
			return false
	var observed := {}
	for tick in range(3 * Sim.DAY_LENGTH):
		trial.tick()
		for family: Dictionary in trial.families:
			if family.phase == "leisure":
				observed[family.leisure_kind] = true
	return trial.reviews.size() == 12 and Sim.LEISURE_DURATIONS.keys().all(func(kind: String) -> bool: return observed.has(kind))


func _smoke_animation_viewer() -> bool:
	var before := simulation.snapshot()
	_open_animation_viewer()
	if not is_instance_valid(animation_viewer) or not animation_viewer.visible:
		return false
	var clips := Sim.LEISURE_DURATIONS.keys() + ["dining", "buffet_collection", "main_pool", "walking", "ocean_swim", "ocean_evacuation"]
	var valid := true
	for clip: String in clips:
		animation_viewer.select_clip(clip)
		animation_viewer.seek(animation_viewer.duration * 0.5)
		var count := 1 if clip in ["ocean_swim", "ocean_evacuation"] else 4
		valid = valid and animation_viewer.clip_id == clip and animation_viewer.panel_maps.size() == count and animation_viewer.panel_viewports.size() == count
		await get_tree().process_frame
	animation_viewer.close()
	return valid and not animation_viewer.visible and simulation.snapshot() == before


func _smoke_risk_and_rotation() -> bool:
	var plan: Layout = simulation.layout.duplicate_layout()
	var building_id: int = plan.buildings[3].id
	if not plan.rotate_building(building_id).ok or not plan.set_building_finish(building_id, "roof", "slate").ok:
		return false
	var risky := Sim.new()
	risky.set_price(135)
	risky.set_swim_policy("allow_red")
	for i in range(Sim.DAY_LENGTH * 6):
		if risky.stopped:
			risky.continue_after_recap()
		risky.tick()
		if not risky.ocean_incidents.is_empty():
			break
	var resumed := Sim.new()
	return (risky.booked_price == 135 and risky.ocean_incidents.size() == 1 and risky.reviews.back().score == 0
		and resumed.restore(risky.snapshot()) and resumed.ocean_incidents == risky.ocean_incidents)


func _smoke_new_facilities() -> bool:
	var tested := 0
	for kind in Sim.LEISURE_DURATIONS:
		if kind in Sim.STARTER_LEISURE:
			continue
		var trial := Sim.new()
		trial.set_swim_policy("closed")
		for prop in trial.layout.landscape.props.duplicate():
			trial.layout.remove_prop(prop.id)
		var placed := trial.layout.add_prop(kind, Vector2i(-12, -8), tested % 4)
		if not placed.ok or trial.layout.amenity_by_id(placed.id).is_empty():
			return false
		var visited := false
		for second in range(Sim.DAY_LENGTH - 1):
			trial.tick()
			if trial.families.any(func(family: Dictionary) -> bool: return family.phase == "leisure" and family.leisure_kind == kind):
				visited = true
				break
		if not visited:
			return false
		tested += 1
	return tested == 10


func _smoke_landscape() -> bool:
	var landscape := simulation.layout.landscape
	var counts := {}
	for prop in landscape.props:
		counts[prop.kind] = counts.get(prop.kind, 0) + 1
	var region := Layout.Landscape.REGION
	var path_counts := {}
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var path := landscape.path_at(Vector2i(x, y))
			if not path.is_empty():
				path_counts[path] = path_counts.get(path, 0) + 1
	return (
		map.landscape_renderer != null and counts == {
			"palm": 38, "bush": 24, "rock": 4, "beach_flag": 1,
			"beach_lounge": 1, "volleyball": 1, "beach_bar": 1, "stage": 1,
		}
		and path_counts == {"stone": 158, "boardwalk": 56} and landscape.terrain_at(Vector2i(95, 14)) == "water"
		and landscape.terrain_at(Vector2i(44, 14)) == "dirt"
	)
