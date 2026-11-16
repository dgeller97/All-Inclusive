extends Control

signal action_requested(action: String, value: Variant)

const Sim = preload("res://scripts/simulation.gd")
const DesignUI = preload("res://scripts/design_ui.gd")
const INK := Color("#3b2b38")
const CHROME := Color("#362836")
const CHROME_EDGE := Color("#8e6a64")
const DARK_BUTTON := Color("#4d3947")
const DARK_HOVER := Color("#644858")
const CREAM := Color("#fff1d6")
const GOLD := Color("#f3c881")
const PAPER := Color("#f9eacb")
const CARD := Color("#fff5e1")
const LINE := Color("#c8a980")
const MUTED := Color("#70565d")
const TEAL := Color("#235c54")
const TEAL_HOVER := Color("#316e63")
const MARGIN := 16.0
const SPEEDS := [1, 2, 4]
const DEVELOPER_BEACH_HEIGHT := 510.0
const GUARD_SITES := ["beach", "pool"]
const PANELS := {
	"package": ["Booking", "Booking desk", "Set the nightly room price", Vector2(372, 253)],
	"staff": ["Staff", "Staff assignments", "Manage the floating worker, dining capacity and lifeguard", Vector2(344, 346)],
	"pool": ["Leisure", "Pool and facilities", "Check pool upgrades and facility capacity", Vector2(336, 326)],
	"beach": ["Beach", "Beach and surf", "Manage ocean swimming and beach cleaning", Vector2(374, 332)],
	"reviews": ["Reviews", "Latest review", "Read the latest guest review", Vector2(336, 192)],
	"goals": ["Goals", "Day 3 targets", "Check the opening weekend targets", Vector2(330, 224)],
	"settings": ["Settings", "Settings", "Save, load, sound, or animation viewer (Esc)", Vector2(320, 285)],
	"design": ["Build", "Design mode", "Draw buildings, place furniture and edit the landscape", Vector2.ZERO],
}

class PixelIcon extends Control:
	const PATTERNS := {
		"beach": ["............", "...#######..", "...######...", "...#####....", "...####.....", "...#........", "...#........", "..####......", "............", ".##..##..##.", "...##..##...", "............"],
		"package": ["............", "..########..", ".#........#.", ".#.###....#.", ".#........#.", ".#.######.#.", ".#........#.", ".#.####...#.", ".#.......##.", ".#....#####.", "..######....", "............"],
		"staff": ["............", "...###..##..", "..#####.###.", "..#####.###.", "...###..##..", "............", "..#####.##..", ".#######.##.", ".#######.##.", ".#######.##.", "............", "............"],
		"pool": ["............", "...####.....", "..######....", ".########...", ".....#......", ".....#......", "............", ".##..##..##.", "...##..##...", ".##..##..##.", "...##..##...", "............"],
		"reviews": ["............", "..########..", ".#........#.", ".#........#.", ".#.#.##.#.#.", ".#........#.", ".#........#.", "..########..", "...##.......", "...#........", "............", "............"],
		"goals": ["............", "..########..", ".##......##.", ".##......##.", "..##....##..", "...######...", "....####....", ".....##.....", ".....##.....", "...######...", "............", "............"],
		"settings": ["............", "..#.........", "..#.........", ".###........", "..#.........", "......#.....", ".##########.", "......#.....", ".........#..", ".........###", ".........#..", "............"],
		"pause": ["............", "............", "...##.##....", "...##.##....", "...##.##....", "...##.##....", "...##.##....", "...##.##....", "...##.##....", "............", "............", "............"],
		"play": ["............", "............", "...##.......", "...####.....", "...######...", "...#######..", "...######...", "...####.....", "...##.......", "............", "............", "............"],
		"minus": ["............", "............", "............", "............", "............", "..########..", "..########..", "............", "............", "............", "............", "............"],
		"plus": ["............", "............", ".....##.....", ".....##.....", ".....##.....", "..########..", "..########..", ".....##.....", ".....##.....", ".....##.....", "............", "............"],
		"home": ["............", ".....##.....", "....####....", "...######...", "..########..", ".##########.", "...######...", "...##..##...", "...##..##...", "...##..##...", "............", "............"],
		"close": ["............", "............", "..##....##..", "...##..##...", "....####....", ".....##.....", ".....##.....", "....####....", "...##..##...", "..##....##..", "............", "............"],
	}
	var symbol := ""
	var tint := Color.WHITE

	func _draw() -> void:
		var rows: Array = DesignUI.PixelIcon.PATTERNS["design"] if symbol == "design" else PATTERNS.get(symbol, [])
		var pixel := maxf(1.0, floorf(minf(size.x, size.y) / 12.0))
		var start := ((size - Vector2.ONE * 12.0 * pixel) / 2.0).floor()
		for y in range(rows.size()):
			var row: String = rows[y]
			for x in range(row.length()):
				if row[x] == "#":
					draw_rect(Rect2(start + Vector2(x, y) * pixel, Vector2.ONE * pixel), tint)

var _status: Panel
var _transport: Panel
var _view_control: Panel
var _building_view: Button
var _dock: Panel
var _camera: Panel
var _toast: Panel
var _popover: Panel
var _toast_label: Label
var _clock_heading: Label
var _clock: Label
var _date_heading: Label
var _temperature: Label
var _cash: Label
var _rating: Label
var _pause: Button
var _pause_icon: PixelIcon
var _speed_buttons: Array[Button] = []
var _dock_buttons: Dictionary = {}
var _dock_icons: Dictionary = {}
var _dock_labels: Dictionary = {}
var _body: Dictionary = {}
var _buttons: Array[Button] = []
var _surfaces: Array[Control] = []
var _ui_font: SystemFont
var _heading_font: SystemFont
var _panel_id := ""
var _state: Dictionary = {}
var _interactive := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_font = _font(600)
	_heading_font = _font(700)
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", _box(CHROME, CHROME_EDGE, 4, 1, 7))
	theme.set_font("font", "TooltipLabel", _ui_font)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	theme.set_color("font_color", "TooltipLabel", CREAM)
	_build_status()
	_build_transport()
	_build_view_control()
	_build_dock()
	_build_camera()
	_toast = _surface(self, Rect2(0, 0, 350, 37), CHROME, CHROME_EDGE)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _label(_toast, Rect2(14, 0, 322, 37), "", 14, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.hide()
	resized.connect(_layout)
	_layout()
	refresh(_state)


func refresh(data: Dictionary) -> void:
	_state = data
	var sim: Sim = data.get("simulation")
	if _status == null or sim == null:
		return
	_clock_heading.text = "DAY %d / %d" % [sim.day, Sim.FINAL_DAY] if sim.day <= Sim.FINAL_DAY else "DAY %d" % sim.day
	var calendar := sim.calendar_state()
	_clock.text = calendar.time_label
	_date_heading.text = "%s %d · Y%d" % [str(calendar.month_name).to_upper(), calendar.day_in_month, calendar.year]
	_temperature.text = "%d°C" % roundi(calendar.temperature_c)
	_cash.text = "$%d" % sim.cash
	_rating.text = "—" if sim.reviews.is_empty() else "%.1f / 100" % sim.average()
	var paused: bool = data.get("paused", false)
	_pause.text = "Resume" if paused else "Pause"
	_pause.accessibility_name = _pause.text
	_pause_icon.symbol = "play" if paused else "pause"
	_pause_icon.tint = INK if paused else CREAM
	_pause_icon.queue_redraw()
	_pause.set_pressed_no_signal(paused)
	for i in range(_speed_buttons.size()):
		_speed_buttons[i].set_pressed_no_signal(SPEEDS[i] == data.get("speed", 1))
	var exterior: bool = data.get("exterior_view", false)
	_building_view.text = "Show interiors" if exterior else "Show exterior"
	_building_view.accessibility_name = _building_view.text
	_building_view.tooltip_text = "Reveal the interiors of all buildings." if exterior else "Show roofs and façades for all enclosed buildings."
	_set_notice(data.get("notice", ""))
	var has_pending: bool = data.get("has_pending", false)
	_dock_labels.design.text = "Build ·" if has_pending else "Build"
	_dock_buttons.design.tooltip_text = "Construction queued for Day %d. Open Build to review." % (sim.day + 1) if has_pending else PANELS.design[2]
	_refresh_panel(sim)


func open_panel(id: String) -> void:
	if not _interactive or id == _panel_id or id == "design" or not PANELS.has(id) or not is_instance_valid(_dock):
		return
	_clear_popover()
	_panel_id = id
	var entry: Array = PANELS[id]
	var panel_size: Vector2 = entry[3]
	var sim: Sim = _state.get("simulation")
	var developer := sim != null and sim.mode == "developer"
	if id == "beach" and developer:
		panel_size.y = DEVELOPER_BEACH_HEIGHT
	_popover = _surface(self, Rect2(Vector2.ZERO, panel_size), PAPER, LINE)
	var icon := _icon(_popover, Rect2(15, 12, 24, 24), id, TEAL)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(_popover, Rect2(45, 9, panel_size.x - 94, 30), entry[1], 20, INK, HORIZONTAL_ALIGNMENT_LEFT, _heading_font)
	var close := _button(_popover, Rect2(panel_size.x - 42, 9, 31, 30), "", close_panel, false)
	close.tooltip_text = "Close %s (Esc)" % String(entry[1]).to_lower()
	close.accessibility_name = close.tooltip_text
	_icon(close, Rect2(4, 3, 24, 24), "close", INK)
	_divider(_popover, Rect2(13, 46, panel_size.x - 26, 1), LINE)
	match id:
		"package": _build_package()
		"staff": _build_staff()
		"pool": _build_pool()
		"beach": _build_beach(developer)
		"reviews": _build_reviews()
		"goals": _build_goals()
		"settings": _build_settings()
	_layout_popover()
	_sync_dock()
	if sim != null:
		_refresh_panel(sim)
	action_requested.emit("open_panel", id)


func close_panel() -> void:
	if _panel_id.is_empty():
		return
	var closed := _panel_id
	var focused := get_viewport().gui_get_focus_owner()
	var focus_was_inside := focused != null and _popover.is_ancestor_of(focused)
	_clear_popover()
	_sync_dock()
	if _interactive and focus_was_inside:
		_dock_buttons[closed].grab_focus()
	action_requested.emit("close_panel", closed)


func has_open_panel() -> bool:
	return not _panel_id.is_empty()


func has_transient_popup() -> bool:
	var month: OptionButton = _body.get("developer_month")
	return month != null and month.get_popup().visible


func close_transient_popup() -> bool:
	if has_transient_popup():
		_body.developer_month.get_popup().hide()
		return true
	return false


func is_pointer_over_ui(point: Vector2) -> bool:
	if not _interactive or not is_visible_in_tree():
		return false
	for surface in _surfaces:
		if surface.is_visible_in_tree() and surface.get_global_rect().has_point(point):
			return true
	if has_transient_popup():
		return true
	return is_instance_valid(_popover) and _popover.get_global_rect().has_point(point)


func set_interactive(enabled: bool) -> void:
	_interactive = enabled
	if not enabled:
		close_panel()
	for button in _buttons:
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for surface in _surfaces:
		surface.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	set_process_input(enabled)


func _input(event: InputEvent) -> void:
	if not _interactive or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.pressed and has_open_panel():
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] and not is_pointer_over_ui(event.position):
			close_panel()
			get_viewport().set_input_as_handled()


func _build_status() -> void:
	_status = _surface(self, Rect2(MARGIN, MARGIN, 428, 57), CHROME, CHROME_EDGE)
	_surfaces.append(_status)
	_clock_heading = _label(_status, Rect2(13, 6, 81, 18), "DAY 1 / 3", 12, GOLD)
	_clock = _label(_status, Rect2(13, 24, 81, 27), "00:00", 22, CREAM)
	_divider(_status, Rect2(91, 10, 1, 37), CHROME_EDGE)
	_label(_status, Rect2(104, 6, 91, 18), "CASH", 12, GOLD)
	_cash = _label(_status, Rect2(104, 24, 91, 27), "$140", 22, CREAM)
	_divider(_status, Rect2(195, 10, 1, 37), CHROME_EDGE)
	_label(_status, Rect2(208, 6, 86, 18), "RATING", 12, GOLD)
	_rating = _label(_status, Rect2(208, 24, 89, 27), "—", 17, CREAM)
	_divider(_status, Rect2(298, 10, 1, 37), CHROME_EDGE)
	_date_heading = _label(_status, Rect2(309, 6, 112, 18), "MARCH 1 · Y1", 12, GOLD)
	_date_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_temperature = _label(_status, Rect2(309, 24, 112, 27), "26°C", 17, CREAM)


func _build_transport() -> void:
	_transport = _surface(self, Rect2(0, 0, 254, 50), CHROME, CHROME_EDGE)
	_surfaces.append(_transport)
	_pause = _button(_transport, Rect2(6, 6, 101, 38), "Pause", _request.bind("pause"), true, true)
	_pause.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for style_name in ["normal", "hover", "pressed", "hover_pressed"]:
		_pause.get_theme_stylebox(style_name).content_margin_left = 33
	_pause.tooltip_text = "Pause or resume (Space)"
	_pause_icon = _icon(_pause, Rect2(5, 7, 24, 24), "pause", CREAM)
	for i in range(SPEEDS.size()):
		var rate: int = SPEEDS[i]
		var button := _button(_transport, Rect2(112 + i * 46, 6, 43, 38), "%d×" % rate, _request.bind("speed", rate), true, true)
		button.tooltip_text = "Resume at %d× speed (key %d)" % [rate, i + 1]
		button.accessibility_name = button.tooltip_text
		_speed_buttons.append(button)


func _build_dock() -> void:
	_dock = _surface(self, Rect2(0, 0, PANELS.size() * 72 + 7, 63), CHROME, CHROME_EDGE)
	_surfaces.append(_dock)
	var i := 0
	for id in PANELS:
		var entry: Array = PANELS[id]
		var action := _request.bind("build") if id == "design" else _toggle_panel.bind(id)
		var button := _button(_dock, Rect2(6 + i * 72, 6, 67, 51), "", action, true, id != "design")
		button.tooltip_text = entry[2]
		button.accessibility_name = entry[1]
		_dock_buttons[id] = button
		_dock_icons[id] = _icon(button, Rect2(21, 3, 24, 24), id, GOLD)
		_dock_labels[id] = _label(button, Rect2(1, 27, 65, 20), entry[0], 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		i += 1


func _build_view_control() -> void:
	_view_control = _surface(self, Rect2(0, 0, 143, 50), CHROME, CHROME_EDGE)
	_surfaces.append(_view_control)
	_building_view = _button(_view_control, Rect2(6, 6, 131, 38), "Show exterior", _request.bind("building_view"), true)
	_building_view.name = "BuildingView"


func _build_camera() -> void:
	_camera = _surface(self, Rect2(0, 0, 154, 50), CHROME, CHROME_EDGE)
	_camera.tooltip_text = "Drag the resort to explore. Scroll to zoom."
	_surfaces.append(_camera)
	var zoom_out := _button(_camera, Rect2(6, 6, 37, 38), "", _request.bind("zoom_out"), true)
	zoom_out.tooltip_text = "Zoom out"
	zoom_out.accessibility_name = "Zoom out"
	_icon(zoom_out, Rect2(6, 7, 24, 24), "minus", CREAM)
	var zoom_in := _button(_camera, Rect2(48, 6, 37, 38), "", _request.bind("zoom_in"), true)
	zoom_in.tooltip_text = "Zoom in"
	zoom_in.accessibility_name = "Zoom in"
	_icon(zoom_in, Rect2(6, 7, 24, 24), "plus", CREAM)
	var home := _button(_camera, Rect2(90, 6, 58, 38), "Home", _request.bind("home"), true)
	home.tooltip_text = "Reset the resort view (Home). Drag the map to explore."
	home.accessibility_name = "Reset the resort view"


func _build_package() -> void:
	_body.effective = _label(_popover, Rect2(15, 54, 340, 27), "", 16, INK)
	var slider := HSlider.new()
	slider.name = "RoomPrice"
	slider.position = Vector2(20, 88)
	slider.size = Vector2(332, 24)
	slider.min_value = Sim.MIN_PRICE
	slider.max_value = Sim.MAX_PRICE
	slider.step = Sim.PRICE_STEP
	slider.accessibility_name = "Nightly room price"
	slider.tooltip_text = "Nightly room price per family"
	slider.mouse_force_pass_scroll_events = false
	slider.add_theme_stylebox_override("slider", _box(LINE, LINE, 3, 0, 2))
	slider.add_theme_stylebox_override("grabber_area", _box(TEAL, TEAL, 3, 0, 2))
	slider.add_theme_stylebox_override("grabber_area_highlight", _box(TEAL_HOVER, TEAL_HOVER, 3, 0, 2))
	_popover.add_child(slider)
	slider.value_changed.connect(_room_price_changed)
	_body.slider = slider
	_label(_popover, Rect2(15, 112, 100, 19), "$%d" % Sim.MIN_PRICE, 12, MUTED)
	_label(_popover, Rect2(257, 112, 100, 19), "$%d" % Sim.MAX_PRICE, 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var options: Array[Button] = []
	for i in range(Sim.PACKAGES.size()):
		var package: Dictionary = Sim.PACKAGES[i]
		var option := _button(_popover, Rect2(14 + i * 116, 138, 111, 34), "%s $%d" % [package.name, package.price], _request.bind("package", i), false, true)
		option.tooltip_text = "%d families · %s · %+d rating" % [package.bookings, package.cue, package.value]
		option.accessibility_name = "%s package, $%d" % [package.name, package.price]
		options.append(option)
	_body.options = options
	_body.details = _label(_popover, Rect2(15, 179, 342, 23), "", 15, MUTED)
	_divider(_popover, Rect2(14, 212, 344, 1), LINE)
	_body.booking = _label(_popover, Rect2(15, 217, 342, 26), "", 14, TEAL)


func _room_price_changed(value: float) -> void:
	_request("room_price", roundi(value))


func _build_staff() -> void:
	var options: Array[Button] = []
	for i in range(Sim.STATIONS.size()):
		var option := _button(_popover, Rect2(14, 57 + i * 49, 316, 42), "", _request.bind("staff", i), false, true)
		option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		options.append(option)
	_body.options = options
	_body.tables = _label(_popover, Rect2(15, 209, 314, 25), "", 15, INK)
	_divider(_popover, Rect2(14, 242, 316, 1), LINE)
	_label(_popover, Rect2(15, 247, 104, 23), "Lifeguard", 16, INK)
	_body.guard_cost = _label(_popover, Rect2(120, 248, 209, 22), "", 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_body.guard_status = _label(_popover, Rect2(15, 272, 314, 21), "", 14, TEAL)
	_body.guard_sites = {}
	for i in GUARD_SITES.size():
		var site: String = GUARD_SITES[i]
		var button := _button(_popover, Rect2(14 + i * 161, 300, 155, 32), site.capitalize(),
			_select_guard_site.bind(site), false, true)
		button.name = "Lifeguard" + site.capitalize()
		_body.guard_sites[site] = button


func _select_guard_site(site: String) -> void:
	var action := "assign_lifeguard" if _body.get("guard_hired", false) else "hire_lifeguard"
	_request(action, site)


func _build_pool() -> void:
	_body.pool_status = _label(_popover, Rect2(15, 53, 305, 25), "", 17, INK)
	_label(_popover, Rect2(15, 78, 305, 20), "Two loungers and an umbrella add a pool slot.", 13, MUTED)
	_divider(_popover, Rect2(15, 105, 306, 1), LINE)
	_body.amenities = {}
	_body.amenity_rows = {}
	var scroll := ScrollContainer.new()
	scroll.name = "FacilityCapacity"
	scroll.position = Vector2(14, 108)
	scroll.size = Vector2(307, 109)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_force_pass_scroll_events = false
	scroll.accessibility_name = "Facility capacity"
	_popover.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 1)
	scroll.add_child(list)
	for kind in Sim.LEISURE_DURATIONS:
		var info: Dictionary = Sim.Layout.Landscape.PROP_CATALOG[kind]
		var row := Control.new()
		row.custom_minimum_size = Vector2(287, 25)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(row)
		_body.amenity_rows[kind] = row
		_label(row, Rect2(1, 0, 142, 25), info.label, 14, INK)
		_body.amenities[kind] = _label(row, Rect2(145, 0, 142, 25), "", 14, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_popover, Rect2(15, 222, 305, 21), "Nightclub and stage open at midnight.", 13, MUTED)
	_label(_popover, Rect2(15, 245, 305, 21), "Each activity adds 1 rating point, up to 3.", 13, MUTED)
	_button(_popover, Rect2(14, 275, 308, 37), "Open Build", _request.bind("build"), false)


func _build_beach(developer: bool) -> void:
	_body.surf = _label(_popover, Rect2(15, 52, 345, 24), "", 17, TEAL)
	_body.swimmers = _label(_popover, Rect2(15, 77, 345, 22), "", 14, MUTED)
	var names := ["Safe flags", "Allow red risk", "Closed"]
	var hints := ["Allow green and yellow flags. Swimmers leave when the flag turns red.",
		"Guests may enter red-flag surf and can drown.", "Close ocean swimming at every flag."]
	_body.policies = {}
	for i in range(Sim.SWIM_POLICIES.size()):
		var policy: String = Sim.SWIM_POLICIES[i]
		var button := _button(_popover, Rect2(14 + i * 116, 106, 112, 37), names[i], _request.bind("swim_policy", policy), false, true)
		button.tooltip_text = hints[i]
		button.accessibility_name = names[i]
		_body.policies[policy] = button
	_body.swim_warning = _label(_popover, Rect2(15, 149, 344, 39), "", 14, MUTED)
	_body.swim_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_divider(_popover, Rect2(14, 194, 346, 1), LINE)
	_body.seaweed = _label(_popover, Rect2(15, 200, 184, 25), "", 15, INK)
	_body.offshore = _label(_popover, Rect2(202, 200, 158, 25), "", 14, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	_body.clean = _button(_popover, Rect2(14, 232, 346, 33), "Clean beach", _request.bind("clean_beach"), false)
	_body.clean.tooltip_text = "Remove up to 60 percentage points of sargassum buildup."
	_body.incidents = _label(_popover, Rect2(15, 273, 345, 22), "", 14, MUTED)
	_body.beach_guard = _label(_popover, Rect2(15, 296, 345, 22), "", 14, TEAL)
	_body.beach_guard.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if developer:
		_build_developer_beach()


func _build_developer_beach() -> void:
	_divider(_popover, Rect2(14, 323, 346, 1), LINE)
	_label(_popover, Rect2(15, 329, 344, 22), "Developer tests", 16, INK)
	_label(_popover, Rect2(15, 357, 85, 32), "Month", 14, INK)
	var month := OptionButton.new()
	month.name = "DeveloperMonth"
	month.position = Vector2(103, 357)
	month.size = Vector2(257, 32)
	month.accessibility_name = "Simulation month"
	month.tooltip_text = "Preview a season without advancing the resort day or guest activity."
	_style_button(month, false, false)
	month.add_item("Calendar auto", 0)
	for i in Sim.Calendar.MONTHS.size():
		month.add_item(Sim.Calendar.MONTHS[i], i + 1)
	month.item_selected.connect(func(index: int) -> void: _request("developer_month", month.get_item_id(index)))
	_popover.add_child(month)
	_buttons.append(month)
	var menu := month.get_popup()
	menu.add_theme_stylebox_override("panel", _box(PAPER, LINE, 4, 1, 6))
	menu.add_theme_stylebox_override("hover", _box(TEAL, TEAL, 3))
	menu.add_theme_font_override("font", _ui_font)
	menu.add_theme_font_size_override("font_size", 14)
	menu.add_theme_color_override("font_color", INK)
	menu.add_theme_color_override("font_hover_color", CREAM)
	menu.window_input.connect(_month_menu_input)
	_body.developer_month = month
	_label(_popover, Rect2(15, 398, 158, 19), "Offshore intensity", 14, INK)
	_body.intensity_value = _label(_popover, Rect2(181, 398, 179, 19), "", 14, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	var intensity := HSlider.new()
	intensity.name = "DeveloperIntensity"
	intensity.position = Vector2(15, 427)
	intensity.size = Vector2(238, 28)
	intensity.max_value = 100
	intensity.step = 1
	intensity.accessibility_name = "Offshore sargassum intensity"
	intensity.tooltip_text = "Set intensity for new offshore patches. Existing patches continue drifting."
	intensity.mouse_force_pass_scroll_events = false
	intensity.add_theme_stylebox_override("slider", _box(LINE, LINE, 3, 0, 2))
	intensity.add_theme_stylebox_override("grabber_area", _box(TEAL, TEAL, 3, 0, 2))
	intensity.add_theme_stylebox_override("grabber_area_highlight", _box(TEAL_HOVER, TEAL_HOVER, 3, 0, 2))
	intensity.value_changed.connect(_developer_intensity_changed)
	_popover.add_child(intensity)
	_body.intensity = intensity
	_body.intensity_auto = _button(_popover, Rect2(265, 425, 95, 30), "Auto", _request.bind("developer_sargassum", -1), false, true)
	_body.intensity_auto.tooltip_text = "Use the selected month's natural offshore intensity."
	_body.arrival = _button(_popover, Rect2(14, 462, 172, 34), "Force offshore arrival", _request.bind("developer_arrival"), false)
	_body.arrival.tooltip_text = "Send one new patch toward the shore at its normal drift speed."
	_body.drill = _button(_popover, Rect2(192, 462, 168, 34), "Start rescue drill", _request.bind("developer_rescue_drill"), false)
	_body.drill.name = "DeveloperRescueDrill"


func _developer_intensity_changed(value: float) -> void:
	_request("developer_sargassum", roundi(value))


func _month_menu_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		var month: OptionButton = _body.developer_month
		month.get_popup().set_input_as_handled()
		close_transient_popup()
		month.grab_focus()
		_request("animations")


func _build_reviews() -> void:
	_body.score = _label(_popover, Rect2(15, 56, 307, 40), "", 29, TEAL, HORIZONTAL_ALIGNMENT_LEFT, _heading_font)
	_body.review_source = _label(_popover, Rect2(15, 100, 307, 20), "", 14, MUTED)
	_body.review_note = _label(_popover, Rect2(15, 126, 307, 50), "", 16, INK)
	_body.review_note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.review_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_goals() -> void:
	var values: Array[Label] = []
	for i in range(3):
		var row := _surface(_popover, Rect2(14, 58 + i * 49, 302, 41), CARD, LINE)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(row, Rect2(10, 0, 161, 41), ["Completed stays", "Average rating", "Pool terrace"][i], 15, INK)
		values.append(_label(row, Rect2(174, 0, 118, 41), "", 15, TEAL, HORIZONTAL_ALIGNMENT_RIGHT))
	_body.values = values


func _build_settings() -> void:
	_button(_popover, Rect2(14, 57, 143, 41), "Save run", _request.bind("save"), false)
	_body.load = _button(_popover, Rect2(163, 57, 143, 41), "Load run", _request.bind("load"), false)
	_body.sound = _button(_popover, Rect2(14, 106, 292, 41), "Sound on", _request.bind("mute"), false)
	_button(_popover, Rect2(14, 155, 292, 41), "Animation viewer (F8)", _request.bind("animations"), false)
	_button(_popover, Rect2(14, 204, 292, 41), "Quit to desktop", _request.bind("quit"), false)
	_label(_popover, Rect2(15, 251, 291, 22), "Clock paused while Settings is open.", 13, MUTED)


func _refresh_panel(sim: Sim) -> void:
	match _panel_id:
		"package":
			var next_day := sim.day + int(sim.booked_price > 0)
			_body.slider.set_value_no_signal(sim.selected_price)
			for i in range(_body.options.size()):
				_body.options[i].set_pressed_no_signal(Sim.PACKAGES[i].price == sim.selected_price)
			var room_limit: int = sim.pending_layout.readiness().room_count if sim.pending_layout and sim.booked_price > 0 else sim.rooms.size()
			_body.effective.text = "$%d per family  ·  Day %d" % [sim.selected_price, next_day]
			_body.details.text = "Up to %d families  ·  %+.1f rating for price" % [mini(Sim.price_demand(sim.selected_price), room_limit), Sim.price_value(sim.selected_price)]
			if sim.booked_price == 0:
				_body.booking.text = "Bookings open at 08:00"
			else:
				_body.booking.text = "Booked today · %d families at $%d" % [sim.booked_count, sim.booked_price]
		"staff":
			for i in range(Sim.STATIONS.size()):
				var option: Button = _body.options[i]
				var selected := i == sim.float_station
				var station := sim.station_name(i)
				var service := "%d/%d collecting · %d in buffet line" if i == 1 else "%d/%d active · %d waiting"
				option.text = "%s%s\n%s" % [station, " +1" if selected else "", service % [sim.count_at(i, "service"), sim.capacity(i), sim.count_at(i, "queue")]]
				option.tooltip_text = "Assign the floating worker to %s for one more service slot" % station
				option.accessibility_name = option.text
				option.set_pressed_no_signal(selected)
			_body.tables.text = "Tables %d/%d in use · %d waiting to eat" % [sim.occupied_tables(), sim.layout.dining_tables().size(), sim.count_at(1, "wait_table")]
			_refresh_lifeguard(sim)
		"pool":
			_body.pool_status.text = "Terrace installed" if sim.terrace else "Terrace needs furnishings"
			for kind in _body.amenities:
				var rows := sim.layout.amenities(kind)
				var placed := not rows.is_empty() or sim.layout.landscape.props.any(func(prop: Dictionary) -> bool: return prop.kind == kind)
				_body.amenity_rows[kind].visible = kind in Sim.STARTER_LEISURE or placed
				var available := 0
				var occupied := 0
				for amenity in rows:
					available += amenity.capacity
					occupied += sim.occupied_amenity(amenity.id)
				if available > 0:
					_body.amenities[kind].text = "%d / %d families" % [occupied, available]
				else:
					_body.amenities[kind].text = "No guest access" if placed else "Not built"
		"beach":
			_refresh_beach(sim)
		"reviews":
			if sim.reviews.is_empty():
				_body.score.text = "No reviews yet"
				_body.review_source.text = ""
				_body.review_note.text = "The first families check out after 02:00."
			else:
				var review: Dictionary = sim.reviews.back()
				_body.score.text = "%d / 100" % review.score
				_body.review_source.text = "Room %s · Day %d" % [char(65 + review.room), review.day]
				if review.leisure_bonus > 0:
					_body.review_source.text += " · +%d from activities" % review.leisure_bonus
				_body.review_note.text = review.note
		"goals":
			var stays: int = sim.milestone.get("stays", sim.reviews.size() - sim.ocean_incidents.size())
			var average: float = sim.milestone.get("average", sim.average())
			var terrace: bool = sim.milestone.get("terrace", sim.terrace)
			_body.values[0].text = "%d / 8" % stays
			_body.values[1].text = "%.1f / 75" % average if stays > 0 else "— / 75"
			_body.values[2].text = "Installed" if terrace else "Pending"
			var met := [stays >= 8, average >= 75.0, terrace]
			for i in range(met.size()):
				_body.values[i].add_theme_color_override("font_color", TEAL if met[i] else MUTED)
		"settings":
			_body.load.disabled = not _state.get("can_load", false)
			var muted: bool = _state.get("muted", false)
			_body.sound.text = "Sound off · Turn on" if muted else "Sound on · Turn off"


func _refresh_beach(sim: Sim) -> void:
	var condition := sim.surf_condition()
	_body.surf.text = ["Green flag · Calm surf", "Yellow flag · Caution", "Red flag · Dangerous surf"][condition]
	_body.surf.add_theme_color_override("font_color", [TEAL, Color("#78501d"), Color("#8a3c3d")][condition])
	var swimmers := sim.count_at(2, "ocean_swim")
	_body.swimmers.text = "No guest access to the shoreline" if sim.layout.ocean_access().is_empty() else "%d families in the ocean" % swimmers
	for policy in _body.policies:
		_body.policies[policy].set_pressed_no_signal(policy == sim.swim_policy)
	var warning := "Green and yellow flags allow swimming. Red flags send swimmers ashore."
	if sim.swim_policy == "closed":
		warning = "Ocean swimming is closed. Beach activities stay open."
	elif sim.swim_policy == "allow_red":
		warning = "Red-flag swimming is allowed. Guests can drown in dangerous surf."
	_body.swim_warning.text = warning
	_body.swim_warning.add_theme_color_override("font_color", Color("#8a3c3d") if sim.swim_policy == "allow_red" else MUTED)
	_body.seaweed.text = "Shore buildup · %d%%" % sim.sargassum
	_body.offshore.text = "Offshore patches · %d" % sim.floating_sargassum().size()
	var cost := Sim.BEACH_CLEAN_COST if sim.mode == "regular" else 0
	_body.clean.text = "Clean beach · $%d" % cost if cost > 0 else "Clean beach · Free"
	_body.clean.disabled = sim.sargassum == 0 or (cost > 0 and sim.cash < cost)
	var incidents := sim.ocean_incidents.size()
	_body.incidents.text = "Fatal incidents · %d" % incidents
	if incidents > 0:
		var latest: Dictionary = sim.ocean_incidents.back()
		var time: String = Sim.Calendar.state(latest.day, latest.second).time_label
		_body.incidents.text += "  ·  Latest Day %d at %s" % [latest.day, time]
	_body.beach_guard.text = _beach_guard_text(sim)
	if _body.has("developer_month"):
		_refresh_developer_beach(sim)


func _refresh_lifeguard(sim: Sim) -> void:
	var assignment := sim.lifeguard_assignment
	var hired := not assignment.is_empty()
	var busy := not sim.rescue.is_empty()
	var free := sim.mode == "developer"
	_body.guard_hired = hired
	if hired:
		_body.guard_cost.text = "No extra payroll" if free else "$%d/day payroll" % Sim.LIFEGUARD_PAYROLL
		var status := "Available" if sim.lifeguard_site_available(assignment) else "Post inaccessible"
		_body.guard_status.text = "%s · %s" % [_site_name(assignment), _rescue_activity(sim) if busy else status]
	else:
		_body.guard_cost.text = "Free to hire" if free else "$%d hire · $%d/day" % [Sim.LIFEGUARD_HIRE_COST, Sim.LIFEGUARD_PAYROLL]
		_body.guard_status.text = "No lifeguard on duty"
	for site: String in GUARD_SITES:
		var button: Button = _body.guard_sites[site]
		var site_name := _site_name(site)
		button.text = site_name if hired else "Hire · " + site_name
		button.accessibility_name = "%s lifeguard for %s" % ["Assign" if hired else "Hire", site_name]
		button.set_pressed_no_signal(assignment == site)
		var reachable: bool = sim.lifeguard_site_available(site)
		var affordable := hired or free or sim.cash >= Sim.LIFEGUARD_HIRE_COST
		button.disabled = busy or not reachable or not affordable
		if busy:
			button.tooltip_text = "The lifeguard is assisting a swimmer."
		elif not reachable:
			button.tooltip_text = "This site has no usable lifeguard post."
		elif not affordable:
			button.tooltip_text = "Hiring costs $%d. There is not enough cash." % Sim.LIFEGUARD_HIRE_COST
		else:
			button.tooltip_text = "Cover the main pool only." if site == "pool" else "Cover the ocean swimming area."


func _beach_guard_text(sim: Sim) -> String:
	if not sim.rescue.is_empty():
		var drill: bool = sim.rescue.get("drill", false)
		var who := " · Volunteer" if drill and sim.rescue.get("family", -1) == -1 else ""
		return "%s · %s%s" % [_site_name(sim.rescue.site), _rescue_activity(sim), who]
	if not sim.last_rescue.is_empty():
		var result: String = {
			"rescued": "Swimmer rescued",
			"drill_complete": "Rescue drill complete",
			"self_recovered": "Swimmer recovered",
			"fatal": "Fatal incident",
		}.get(sim.last_rescue.outcome, "")
		if not result.is_empty():
			return "Latest · %s · %s" % [_site_name(sim.last_rescue.site), result]
	if sim.lifeguard_assignment == "beach":
		return "Beach guard · Available" if sim.lifeguard_site_available("beach") else "Beach guard · Post inaccessible"
	return "No lifeguard assigned to the beach"


func _rescue_activity(sim: Sim) -> String:
	var rescue := sim.rescue
	var action := "Drill" if rescue.get("drill", false) else "Rescue"
	var activity := "Swimming out"
	if sim.second >= rescue.drop_at:
		activity = "Returning to post"
	elif rescue.phase == "tow":
		activity = "Towing to safety"
	return "%s · %s" % [action, activity]


func _site_name(site: String) -> String:
	return "Beach" if site == "beach" else "Main pool"


func _refresh_developer_beach(sim: Sim) -> void:
	_body.developer_month.select(sim.developer_month())
	var automatic := sim.sargassum_intensity == -1
	var intensity := roundi(float(sim.calendar_state().sargassum_pressure) * 100.0) if automatic else sim.sargassum_intensity
	_body.intensity.set_value_no_signal(intensity)
	_body.intensity_value.text = ("Auto · " if automatic else "") + "%d%%" % intensity
	_body.intensity_auto.set_pressed_no_signal(automatic)
	_body.drill.disabled = not sim.can_start_rescue_drill()
	if sim.lifeguard_assignment.is_empty():
		_body.drill.tooltip_text = "Hire a lifeguard in Staff first."
	elif not sim.rescue.is_empty():
		_body.drill.tooltip_text = "A rescue or drill is already underway."
	elif not sim.lifeguard_site_available(sim.lifeguard_assignment):
		_body.drill.tooltip_text = "Assign the lifeguard to an accessible post in Staff."
	elif _body.drill.disabled:
		_body.drill.tooltip_text = "There is not enough time left today."
	else:
		_body.drill.tooltip_text = "Practice at the assigned site. A volunteer fills in if no guest is available."


func _layout() -> void:
	_transport.position = Vector2(size.x - MARGIN - _transport.size.x, MARGIN)
	_view_control.position = Vector2(_status.position.x + _status.size.x + 10.0, MARGIN)
	_dock.position = Vector2(MARGIN, size.y - MARGIN - _dock.size.y)
	_camera.position = Vector2(size.x - MARGIN - _camera.size.x, size.y - MARGIN - _camera.size.y)
	_layout_toast()
	_layout_popover()


func _layout_popover() -> void:
	if not is_instance_valid(_popover):
		return
	var source: Button = _dock_buttons[_panel_id]
	var center_x := _dock.position.x + source.position.x + source.size.x / 2.0
	var x := clampf(center_x - _popover.size.x / 2.0, MARGIN, size.x - MARGIN - _popover.size.x)
	_popover.position = Vector2(roundf(x), _dock.position.y - _popover.size.y - 10.0)


func _layout_toast() -> void:
	var left := _dock.position.x + _dock.size.x + 14.0
	var right := _camera.position.x - 14.0
	var toast_width := minf(_toast.size.x, right - left)
	_toast.position = Vector2(roundf(left + (right - left - toast_width) / 2.0), size.y - MARGIN - _toast.size.y)


func _set_notice(words: String) -> void:
	_toast.visible = not words.is_empty()
	_toast_label.text = words
	var max_width := _camera.position.x - (_dock.position.x + _dock.size.x) - 28.0
	var text_width := _ui_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_toast.size.x = clampf(ceilf(text_width) + 28.0, 160.0, maxf(160.0, max_width))
	_toast_label.size.x = _toast.size.x - 28.0
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_layout_toast()


func _toggle_panel(id: String) -> void:
	if id == _panel_id:
		close_panel()
	else:
		open_panel(id)


func _clear_popover() -> void:
	if is_instance_valid(_popover):
		for i in range(_buttons.size() - 1, -1, -1):
			if _popover.is_ancestor_of(_buttons[i]):
				_buttons.remove_at(i)
		remove_child(_popover)
		_popover.queue_free()
		_popover = null
	_panel_id = ""
	_body.clear()


func _sync_dock() -> void:
	for id in _dock_buttons:
		var selected: bool = id == _panel_id
		_dock_buttons[id].set_pressed_no_signal(selected)
		_dock_icons[id].tint = INK if selected else GOLD
		_dock_icons[id].queue_redraw()
		_dock_labels[id].add_theme_color_override("font_color", INK if selected else CREAM)


func _request(action: String, value: Variant = null) -> void:
	if _interactive:
		action_requested.emit(action, value)


func _font(weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI Variable Text", "Segoe UI", "Arial"])
	font.font_weight = weight
	return font


func _box(fill: Color, edge: Color, radius: int, width: int = 1, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


func _surface(parent: Control, rect: Rect2, fill: Color, edge: Color) -> Panel:
	var surface := Panel.new()
	surface.position = rect.position
	surface.size = rect.size
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := _box(fill, edge, 5)
	if parent == self:
		style.shadow_color = Color(0.13, 0.08, 0.12, 0.58)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 3)
	surface.add_theme_stylebox_override("panel", style)
	parent.add_child(surface)
	return surface


func _divider(parent: Control, rect: Rect2, ink: Color) -> void:
	var line := ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = ink
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _label(parent: Control, rect: Rect2, words: String, points: int, ink: Color,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, face: Font = null) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = words
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _ui_font if face == null else face)
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)
	return label


func _icon(parent: Control, rect: Rect2, symbol: String, ink: Color) -> PixelIcon:
	var icon := PixelIcon.new()
	icon.position = rect.position
	icon.size = rect.size
	icon.symbol = symbol
	icon.tint = ink
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _button(parent: Control, rect: Rect2, words: String, callback: Callable,
		dark: bool, toggle: bool = false, primary: bool = false) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.text = words
	button.toggle_mode = toggle
	_style_button(button, dark, primary)
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button


func _style_button(button: Button, dark: bool, primary: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _ui_font)
	button.add_theme_font_size_override("font_size", 15)
	var fill := DARK_BUTTON if dark else (TEAL if primary else CARD)
	var hover := DARK_HOVER if dark else (TEAL_HOVER if primary else Color("#f6dfb4"))
	var edge := CHROME_EDGE if dark else (TEAL if primary else LINE)
	var ink := CREAM if dark or primary else INK
	var selected := GOLD if dark else TEAL
	var selected_ink := INK if dark else CREAM
	button.add_theme_stylebox_override("normal", _box(fill, edge, 4))
	button.add_theme_stylebox_override("hover", _box(hover, edge, 4))
	button.add_theme_stylebox_override("pressed", _box(selected, selected, 4))
	button.add_theme_stylebox_override("hover_pressed", _box(selected.lightened(0.10), selected, 4))
	button.add_theme_stylebox_override("disabled", _box(Color("#e8d7b8"), LINE, 4))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("#e28a39"), 4, 2))
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_pressed_color", selected_ink)
	button.add_theme_color_override("font_hover_pressed_color", selected_ink)
	button.add_theme_color_override("font_disabled_color", MUTED)
