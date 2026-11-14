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
const STATIONS := ["Reception", "Buffet", "Pool"]
const PANELS := {
	"package": ["Booking", "Booking desk", "Choose a package and set the room price", Vector2(372, 224)],
	"staff": ["Staff", "Staff assignments", "Assign the floating worker", Vector2(344, 254)],
	"pool": ["Pool", "Pool terrace", "Check the pool terrace", Vector2(320, 192)],
	"reviews": ["Reviews", "Latest review", "Read the latest guest review", Vector2(336, 192)],
	"goals": ["Goals", "Day 3 targets", "Check the opening weekend targets", Vector2(330, 224)],
	"settings": ["Settings", "Settings", "Save, load, or change sound (Esc)", Vector2(320, 236)],
	"design": ["Build", "Build and furnish", "Draw and furnish buildings", Vector2.ZERO],
}

class PixelIcon extends Control:
	const PATTERNS := {
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
var _dock: Panel
var _camera: Panel
var _toast: Panel
var _popover: Panel
var _toast_label: Label
var _clock_heading: Label
var _clock: Label
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
	_clock.text = "%02d:%02d" % [floori(sim.second / 60.0), sim.second % 60]
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
		"reviews": _build_reviews()
		"goals": _build_goals()
		"settings": _build_settings()
	_layout_popover()
	_sync_dock()
	var sim: Sim = _state.get("simulation")
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


func is_pointer_over_ui(point: Vector2) -> bool:
	if not _interactive or not is_visible_in_tree():
		return false
	for surface in _surfaces:
		if surface.is_visible_in_tree() and surface.get_global_rect().has_point(point):
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
	_status = _surface(self, Rect2(MARGIN, MARGIN, 304, 57), CHROME, CHROME_EDGE)
	_surfaces.append(_status)
	_clock_heading = _label(_status, Rect2(13, 6, 81, 18), "DAY 1 / 3", 12, GOLD)
	_clock = _label(_status, Rect2(13, 24, 81, 27), "00:00", 22, CREAM)
	_divider(_status, Rect2(91, 10, 1, 37), CHROME_EDGE)
	_label(_status, Rect2(104, 6, 91, 18), "CASH", 12, GOLD)
	_cash = _label(_status, Rect2(104, 24, 91, 27), "$140", 22, CREAM)
	_divider(_status, Rect2(195, 10, 1, 37), CHROME_EDGE)
	_label(_status, Rect2(208, 6, 86, 18), "RATING", 12, GOLD)
	_rating = _label(_status, Rect2(208, 24, 89, 27), "—", 17, CREAM)


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
	_dock = _surface(self, Rect2(0, 0, 511, 63), CHROME, CHROME_EDGE)
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
	var options: Array[Button] = []
	for i in range(Sim.PACKAGES.size()):
		var package: Dictionary = Sim.PACKAGES[i]
		var option := _button(_popover, Rect2(14 + i * 116, 58, 111, 57), "%s\n$%d" % [package.name, package.price], _request.bind("package", i), false, true)
		option.tooltip_text = "%d families · %s · %+d rating" % [package.bookings, package.cue, package.value]
		option.accessibility_name = "%s package, $%d" % [package.name, package.price]
		options.append(option)
	_body.options = options
	_body.effective = _label(_popover, Rect2(15, 122, 342, 23), "", 16, INK)
	_body.details = _label(_popover, Rect2(15, 146, 342, 23), "", 15, MUTED)
	_divider(_popover, Rect2(14, 179, 344, 1), LINE)
	_body.booking = _label(_popover, Rect2(15, 185, 342, 26), "", 14, TEAL)


func _build_staff() -> void:
	var options: Array[Button] = []
	for i in range(STATIONS.size()):
		var option := _button(_popover, Rect2(14, 57 + i * 49, 316, 42), "", _request.bind("staff", i), false, true)
		option.tooltip_text = "Assign the floating worker to %s" % STATIONS[i].to_lower()
		options.append(option)
	_body.options = options
	_label(_popover, Rect2(15, 211, 314, 27), "The floating worker adds one service slot.", 14, MUTED)


func _build_pool() -> void:
	_body.pool_status = _label(_popover, Rect2(15, 57, 290, 27), "", 17, INK)
	_label(_popover, Rect2(15, 86, 290, 23), "Adds a pool slot and improves reviews.", 14, MUTED)
	_label(_popover, Rect2(15, 110, 290, 20), "Needs two accessible loungers and an umbrella.", 13, MUTED)
	_button(_popover, Rect2(14, 138, 292, 37), "Open Build", _request.bind("build"), false)


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
	_button(_popover, Rect2(14, 155, 292, 41), "Quit to desktop", _request.bind("quit"), false)
	_label(_popover, Rect2(15, 202, 291, 22), "Clock paused while Settings is open.", 13, MUTED)


func _refresh_panel(sim: Sim) -> void:
	match _panel_id:
		"package":
			var next_day := sim.day + int(sim.booked_package >= 0)
			var package: Dictionary = Sim.PACKAGES[sim.selected_package]
			for i in range(_body.options.size()):
				_body.options[i].set_pressed_no_signal(i == sim.selected_package)
			var room_limit: int = sim.pending_layout.readiness().room_count if sim.pending_layout else sim.rooms.size()
			_body.effective.text = "Day %d · up to %d families" % [next_day, mini(package.bookings, room_limit)]
			_body.details.text = "%s · %+d rating" % [package.cue, package.value]
			if sim.booked_package < 0:
				_body.booking.text = "Bookings open at 00:20"
			else:
				var booked: Dictionary = Sim.PACKAGES[sim.booked_package]
				_body.booking.text = "Booked today · %d families · %s $%d" % [sim.booked_count, booked.name, booked.price]
		"staff":
			for i in range(STATIONS.size()):
				var option: Button = _body.options[i]
				var selected := i == sim.float_station
				option.text = "%s%s   %d/%d active · %d waiting" % [STATIONS[i], " +1" if selected else "", sim.count_at(i, "service"), sim.capacity(i), sim.count_at(i, "queue")]
				option.accessibility_name = option.text
				option.set_pressed_no_signal(selected)
		"pool":
			_body.pool_status.text = "Terrace installed" if sim.terrace else "Terrace needs furnishings"
		"reviews":
			if sim.reviews.is_empty():
				_body.score.text = "No reviews yet"
				_body.review_source.text = ""
				_body.review_note.text = "The first families check out from 03:20."
			else:
				var review: Dictionary = sim.reviews.back()
				_body.score.text = "%d / 100" % review.score
				_body.review_source.text = "Room %s · Day %d" % [char(65 + review.room), review.day]
				_body.review_note.text = review.note
		"goals":
			var stays: int = sim.milestone.get("stays", sim.reviews.size())
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


func _layout() -> void:
	_transport.position = Vector2(size.x - MARGIN - _transport.size.x, MARGIN)
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
	button.pressed.connect(callback)
	parent.add_child(button)
	_buttons.append(button)
	return button
