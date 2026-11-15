extends Control

signal action_requested(action: String, value: Variant)

const Layout = preload("res://scripts/layout_model.gd")
const Renderer = preload("res://scripts/building_renderer.gd")
const CHROME := Color("#362836")
const EDGE := Color("#8e6a64")
const INK := Color("#3b2b38")
const CREAM := Color("#fff1d6")
const GOLD := Color("#f3c881")
const MUTED := Color("#d0b8b4")
const VALID := Color("#a8e0b5")
const INVALID := Color("#ffb5aa")
const MARGIN := 16.0
const CONTEXT_SIZE := Vector2(1248, 120)
const PALETTE_SIZE := Vector2(1000, 114)
const BUILDING_SETTINGS_SIZE := Vector2(344, 264)
const BUILDINGS := {"bedroom": "Bedroom", "reception": "Reception", "buffet": "Buffet", "pool": "Pool"}
const ASSETS := {
	"bed": "Bed", "desk": "Desk", "counter": "Counter", "table": "Table",
	"lounger": "Lounger", "umbrella": "Umbrella", "plant": "Plant", "bench": "Bench",
}
const CATEGORIES := {"buildings": "Buildings", "furniture": "Furniture", "facilities": "Facilities", "landscape": "Landscape"}
const LANDSCAPE_GROUPS := {"terrain": "Terrain", "path": "Paths", "scenery": "Scenery"}
const TERRAIN := {"grass": "Grass", "sand": "Sand", "dirt": "Dirt", "restore": "Restore"}
const PATHS := {"stone": "Stone", "boardwalk": "Boardwalk", "erase": "Erase path"}
const SCENERY := {"palm": "Palm", "bush": "Shrub", "rock": "Rock", "scenery_bench": "Bench", "beach_flag": "Beach flag"}
const FACILITIES := {"beach_lounge": "Beach lounge", "volleyball": "Volleyball court", "beach_bar": "Beach bar", "stage": "Evening stage"}
const TOOL_COLORS := {
	"grass": Color("#a7c57a"), "sand": Color("#f9d894"), "dirt": Color("#d59c73"),
	"stone": Color("#cbd1d6"), "boardwalk": Color("#e5ac75"),
	"palm": Color("#a7c57a"), "bush": Color("#a7c57a"), "rock": Color("#cbd1d6"),
	"beach_flag": Color("#ffa78d"),
	"beach_lounge": Color("#f6c88a"), "volleyball": Color("#ffd698"),
	"beach_bar": Color("#8ed6c6"), "stage": Color("#f5a7ae"),
}


class PixelIcon extends Control:
	const PATTERNS := {
		"design": ["............", ".##########.", ".#..#.....#.", ".#..#.....#.", ".####..#####", ".#.....#....", ".#.....#....", ".#.###.####.", ".#.#......#.", ".#.####...#.", ".##########.", "............"],
		"select": ["............", "..#.........", "..##........", "..###.......", "..####......", "..#####.....", "..######....", "..#######...", "..##.##.....", "..#...##....", "......##....", "............"],
		"bulldoze": ["............", ".......###..", "......#..#..", ".....#####..", "...#######..", "...#######.#", ".#########.#", ".#####.....#", "..##########", "...#..#..#..", "....#####...", "............"],
		"bedroom": ["............", ".....##.....", "....####....", "...######...", "..########..", ".##########.", "..#......#..", "..#.##...#..", "..#.#.#..#..", "..#.#.#..#..", "..#######...", "............"],
		"reception": ["............", ".....##.....", ".....##.....", "....####....", "...######...", "...######...", "..########..", "..########..", ".##########.", ".....##.....", "............", "............"],
		"buffet": ["............", "......##....", "....####....", "..####......", "..##........", ".....##.....", "...######...", "..########..", "..########..", ".##########.", "..########..", "............"],
		"pool": ["............", "....####....", "...######...", "..########..", "......#.....", "......#.....", "............", ".##..##..##.", "...##..##...", ".##..##..##.", "...##..##...", "............"],
		"bed": ["............", ".##.........", ".##.........", ".##.###.....", ".#######..#.", ".##########.", ".##########.", ".##########.", ".##......##.", ".##......##.", "............", "............"],
		"desk": ["............", "....###.....", "....#.#.....", "...#####....", ".##########.", ".##########.", "..##...###..", "..##...###..", "..##...###..", "..##....##..", "............", "............"],
		"counter": ["............", "....##......", "........#...", "..#...####..", ".##########.", ".##########.", "..########..", "..#..##..#..", "..########..", "..########..", "............", "............"],
		"table": ["............", ".....##.....", "..#.####.#..", "..#.####.#..", ".##.####.##.", ".##.####.##.", "..#.####.#..", "..#.####.#..", ".....##.....", "............", "............", "............"],
		"lounger": ["............", "............", ".##.........", ".###........", "..###.......", "...####.....", "....#######.", "...########.", "...##....##.", "............", "............", "............"],
		"umbrella": ["............", ".....##.....", "...######...", "..########..", ".##########.", ".#..####..#.", ".....##.....", ".....##.....", ".....##.....", "....####....", "............", "............"],
		"plant": ["............", ".....##.....", "..##.##.....", "...###.###..", "....#####...", ".....##.....", "..########..", "...######...", "...######...", "....####....", "............", "............"],
		"bench": ["............", "............", "..########..", "..########..", "..#......#..", ".##########.", ".##########.", "..##....##..", "..##....##..", "............", "............", "............"],
		"rotate": ["............", "....####....", "...##..##.#.", "..##....###.", ".##.....###.", ".##...#####.", ".##.........", "..##........", "...##..##...", "....####....", "............", "............"],
		"move": ["............", ".....##.....", "....####....", "...######...", ".....##.....", ".#...##...#.", "###########.", ".#...##...#.", ".....##.....", "...######...", "....####....", ".....##....."],
		"grass": ["............", "...#....#...", "..##...##...", ".###...##...", "...#.#.#....", ".#.###.#..#.", ".######..##.", "..#########.", ".##########.", ".##########.", "............", "............"],
		"sand": ["............", "............", "......#.....", ".....###....", "....#####...", "...#######..", "..####.#.##.", ".###.##.###.", ".##########.", "............", "............", "............"],
		"dirt": ["............", "............", "............", ".....###....", "...#####....", "..########..", ".###.##.###.", ".#.#####.##.", ".##########.", ".##########.", "............", "............"],
		"restore": ["............", "...####.....", "..##..##....", ".##....##...", ".##.....#...", ".##...#####.", "..##....#...", "...####.....", "........#...", "....#######.", "............", "............"],
		"stone": ["............", ".....##.....", "....####....", "............", "...######...", "...######...", "............", "..########..", ".##########.", ".##########.", "............", "............"],
		"boardwalk": ["............", "...######...", "............", "...######...", "............", "..########..", "............", "..########..", "............", ".##########.", ".##########.", "............"],
		"erase": ["............", "............", "........##..", "......##..#.", "....##....#.", "..##.....#..", ".#......#...", ".##....#....", "..###.#.....", "....#######.", "............", "............"],
		"palm": ["............", "...######...", ".##########.", "####.##.####", "##...##...##", ".....##.....", "....##......", "....##......", "...##.......", "...##.......", "..####......", "............"],
		"bush": ["............", "............", ".....##.....", "....####....", "..#######...", ".##########.", ".###.######.", "#########.##", "############", ".##########.", "............", "............"],
		"rock": ["............", "............", "............", "....####....", "...######...", "..########..", ".########.#.", ".##########.", ".##########.", "............", "............", "............"],
		"beach_flag": ["............", "...######...", "...########.", "...########.", "...######...", "...##.......", "...##.......", "...##.......", "...##.......", "..####......", "............", "............"],
		"beach_lounge": ["............", "....####....", "..########..", ".##########.", ".....##.....", ".....##.....", "..##.##.....", "..###.......", "...#######..", "...#######..", "...#.....#..", "............"],
		"volleyball": ["............", ".....##.....", "....####....", ".....##.....", ".#........#.", ".##########.", ".#.#.#.#..#.", ".##########.", ".#.#.#.#..#.", ".#........#.", ".#........#.", "............"],
		"beach_bar": ["............", "........##..", ".......##...", "......##....", "..########..", "...######...", "....####....", ".....##.....", ".....##.....", "...######...", "............", "............"],
		"stage": ["............", ".##########.", ".#.#.##.#.#.", ".#........#.", ".#........#.", ".#...##...#.", ".#..#..#..#.", ".#...##...#.", ".##########.", "############", "............", "............"],
	}
	var symbol := ""
	var tint := Color("#f3c881")

	func set_tint(color: Color) -> void:
		if tint != color:
			tint = color
			queue_redraw()

	func _draw() -> void:
		var rows: Array = PATTERNS.get(symbol, [])
		for y in range(rows.size()):
			var row: String = rows[y]
			for x in range(row.length()):
				if row[x] == "#":
					draw_rect(Rect2(Vector2(x, y) * 2.0, Vector2(2, 2)), tint)


var _state: Dictionary = {}
var _context: Panel
var _palette: Panel
var _mode: Label
var _instruction: Label
var _feedback: Label
var _selection: Label
var _quote: Label
var _apply_reason: Label
var _pending_notice: Label
var _apply: Button
var _save: Button
var _cancel_pending: Button
var _rotate: Button
var _move: Button
var _brush_label: Label
var _tool_group := ButtonGroup.new()
var _tool_buttons: Dictionary = {}
var _tool_icons: Dictionary = {}
var _tool_labels: Dictionary = {}
var _tool_sections: Dictionary = {}
var _tool_prices: Dictionary = {}
var _category_buttons: Dictionary = {}
var _landscape_buttons: Dictionary = {}
var _brush_buttons: Dictionary = {}
var _open_building_settings: Button
var _building_settings: Panel
var _name_field: LineEdit
var _set_name: Button
var _name_status: Label
var _surface_settings: Control
var _finish_fields: Dictionary = {}
var _inspect_ceiling: Button
var _settings_building_id := -1
var _committed_name := ""


func _init() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI Variable Text", "Segoe UI", "Arial"])
	font.font_weight = 600
	theme.default_font = font
	theme.set_stylebox("panel", "TooltipPanel", _box(CHROME, EDGE, 4, 1, 7))
	theme.set_font_size("font_size", "TooltipLabel", 14)
	theme.set_color("font_color", "TooltipLabel", CREAM)
	_build_context()
	_build_palette()
	_build_building_settings()
	resized.connect(_layout)
	_layout()
	refresh(_state)


func refresh(data: Dictionary) -> void:
	_state = data
	visible = data.get("active", false)
	if _context == null or not visible:
		if _building_settings:
			_close_building_settings()
		return

	var tool: String = data.get("tool", "select")
	var category: String = data.get("category", "buildings")
	var group: String = data.get("landscape_group", "terrain")
	var turn := posmod(int(data.get("rotation", 0)), 4) * 90
	_instruction.text = _tool_instruction(data, turn)
	_feedback.text = data.get("feedback", "")
	var feedback_color := CREAM
	if data.has("feedback_valid"):
		feedback_color = VALID if data.feedback_valid else INVALID
	_feedback.add_theme_color_override("font_color", feedback_color)
	var selection: String = data.get("selection", "")
	_selection.text = "Selected · " + selection if not selection.is_empty() else ""
	_selection.tooltip_text = selection
	_refresh_building_settings(data)

	var in_landscape := category == "landscape"
	var section := group if in_landscape else category
	_refresh_choices(_category_buttons, category)
	_refresh_choices(_landscape_buttons, group, in_landscape)
	var selected_key: String = data.get("selected_tool", tool)
	var regular := String(data.get("mode", "developer")).to_lower() == "regular"
	for id in _tool_buttons:
		var selected: bool = id == selected_key
		var button: Button = _tool_buttons[id]
		button.visible = _tool_sections[id] in ["", section]
		button.set_pressed_no_signal(selected)
		_tool_icons[id].set_tint(INK if selected else TOOL_COLORS.get(id, GOLD))
		_tool_labels[id].add_theme_color_override("font_color", INK if selected else CREAM)
		if button.visible and _tool_prices.has(id):
			var price: Dictionary = _tool_prices[id]
			var words := "$%d" % price.cost if regular else "Free"
			if price.label.text != words:
				price.label.text = words
				button.accessibility_name = "%s, %s" % [_tool_labels[id].text, words]
				button.tooltip_text = "%s · %s" % [price.help, words]
			price.label.add_theme_color_override("font_color", INK if selected else GOLD)
	var can_move: bool = data.get("can_move", false)
	var can_rotate: bool = data.get("can_rotate", false)
	_move.visible = in_landscape or can_move
	_move.disabled = not can_move
	_move.get_node("Icon").set_tint(MUTED if _move.disabled else (INK if tool == "move" else GOLD))
	_rotate.visible = can_rotate or section in ["furniture", "scenery", "facilities"]
	_rotate.disabled = not can_rotate
	_rotate.accessibility_name = "Rotate clockwise (R), %d degrees" % turn
	_rotate.get_node("Icon").set_tint(MUTED if _rotate.disabled else GOLD)
	_brush_label.visible = section in ["terrain", "path"]
	_refresh_choices(_brush_buttons, data.get("brush_size", 1), _brush_label.visible)

	_refresh_apply(data)


func _refresh_choices(buttons: Dictionary, selected: Variant, show_buttons: bool = true) -> void:
	for id in buttons:
		var button: Button = buttons[id]
		button.visible = show_buttons
		button.set_pressed_no_signal(id == selected)


func is_pointer_over_ui(point: Vector2) -> bool:
	if not is_visible_in_tree() or _context == null:
		return false
	return (
		_context.get_global_rect().has_point(point) or _palette.get_global_rect().has_point(point)
		or (_building_settings.visible and _building_settings.get_global_rect().has_point(point))
	)


func editing_building_name() -> bool:
	return _building_settings.visible and _name_field.has_focus()


func cancel_building_name_edit() -> void:
	_name_field.text = _committed_name
	_name_field.release_focus()
	_update_name_edit_state()


func show_building_name_result(result: Dictionary) -> void:
	if result.ok:
		_name_field.text = _committed_name
		_name_field.release_focus()
		_name_status.text = "Name set in the draft."
		_name_status.add_theme_color_override("font_color", VALID)
		_set_name.disabled = true
		_refresh_apply(_state)
	else:
		_name_status.text = result.reason
		_name_status.add_theme_color_override("font_color", INVALID)
		_name_field.grab_focus()


func _refresh_building_settings(data: Dictionary) -> void:
	var selected: Dictionary = data.get("selected_building", {})
	var settings_open: bool = data.get("building_settings_open", false)
	_open_building_settings.visible = not selected.is_empty() and not settings_open
	_selection.size.x = 542 if _open_building_settings.visible else 704
	if not settings_open:
		_close_building_settings()
		return
	var pool: bool = selected.kind == "pool"
	var display_name := Layout.building_name(selected)
	if _settings_building_id != selected.id or _committed_name != display_name:
		_settings_building_id = selected.id
		_committed_name = display_name
		_name_field.text = display_name
		_name_status.text = ""
	_surface_settings.visible = not pool
	_building_settings.size.y = 120 if pool else BUILDING_SETTINGS_SIZE.y
	for surface in _finish_fields:
		var field: OptionButton = _finish_fields[surface]
		var choices: Array = Layout.FINISH_CATALOG[surface].keys()
		field.select(choices.find(selected.finishes[surface]))
	_inspect_ceiling.set_pressed_no_signal(data.get("inspect_ceiling", false))
	_building_settings.show()
	_set_name.disabled = _name_field.text == _committed_name


func _close_building_settings() -> void:
	_settings_building_id = -1
	_building_settings.hide()
	_name_field.release_focus()
	for field in _finish_fields.values():
		field.get_popup().hide()


func _update_name_edit_state() -> void:
	_set_name.disabled = _name_field.text == _committed_name
	_name_status.text = ""
	_refresh_apply(_state)


func _commit_name(_submitted: String = "") -> void:
	_request("building_name", _name_field.text)


func _refresh_apply(data: Dictionary) -> void:
	var regular := String(data.get("mode", "developer")).to_lower() == "regular"
	_mode.text = "Paused  ·  " + ("Regular · Construction costs" if regular else "Developer · Free build")
	var cost: int = data.get("cost", 0)
	var refund: int = data.get("refund", 0)
	var cash: int = data.get("cash", 0)
	var net := cost - refund
	_quote.text = data.get("quote_label", "")
	if regular and _quote.text.is_empty():
		var net_label := "-$%d" % -net if net < 0 else "$%d" % net
		_quote.text = "Cost $%d   ·   Refund $%d   ·   Net %s   ·   Cash $%d" % [cost, refund, net_label, cash]

	var can_apply: bool = data.get("can_apply", false)
	var reason: String = data.get("apply_reason", "")
	if not can_apply and reason.is_empty() and regular and net > cash:
		reason = "Need $%d more to apply these changes." % (net - cash)
	var name_dirty := _building_settings.visible and _name_field.text != _committed_name
	if name_dirty:
		reason = "Set or cancel the building name edit first."
		can_apply = false
	_apply_reason.text = reason
	var tomorrow: bool = data.get("defer_apply", false)
	var apply_day: int = data.get("apply_day", 0)
	var action_help := "Apply this layout now and return to the resort."
	if tomorrow:
		action_help = "Queue this layout for tomorrow and return to the resort."
		if apply_day > 0:
			action_help = "Queue this layout for Day %d and return to the resort." % apply_day
	_apply.text = "Apply tomorrow" if tomorrow else "Apply now"
	_apply.accessibility_name = _apply.text
	_apply.disabled = not can_apply
	_apply.tooltip_text = reason if not can_apply and not reason.is_empty() else action_help
	_save.disabled = name_dirty or not data.get("can_save_draft", true)

	var pending: bool = data.get("has_pending", false)
	_cancel_pending.visible = pending
	var pending_day: int = data.get("pending_day", 0)
	var reserve: int = data.get("pending_reserve", 0)
	var pending_notice := "Day %d plan queued" % pending_day if pending_day > 0 else "Plan queued for tomorrow"
	if reserve > 0:
		pending_notice += " · $%d reserved" % reserve
	_pending_notice.text = pending_notice if pending else ""
	_cancel_pending.tooltip_text = "Cancel the queued plan and release $%d to resort cash." % reserve if reserve > 0 else "Cancel the queued plan."


func _tool_instruction(data: Dictionary, rotation: int) -> String:
	var id: String = data.get("selected_tool", "")
	match data.get("tool", "select"):
		"building":
			return "%s · Left-drag a footprint on the grid." % BUILDINGS.get(id, "Building")
		"asset":
			return "%s · Left-click inside a building to place. Rotation %d°." % [ASSETS.get(id, "Furniture"), rotation]
		"terrain", "path", "restore":
			if id == "restore":
				return "Restore · Left-drag to reset the original ground and paths."
			return "%s · Left-drag on dry land. Release to finish the stroke." % (TERRAIN.get(id) if TERRAIN.has(id) else PATHS[id])
		"prop":
			var amenity: Dictionary = Layout.Landscape.PROP_CATALOG.get(id, {})
			if amenity.has("capacity"):
				return "%s · Left-click on dry land. Rotation %d°." % [amenity.label, rotation]
			return "%s · Left-click to place outdoors. Rotation %d°." % [SCENERY[id], rotation]
		"move":
			return "Move · Left-click a new location for the selected outdoor object."
		"bulldoze":
			return "Bulldoze · Left-click a placed object to remove it from the draft."
	return "Select · Left-click a placed object to inspect it."


func _build_context() -> void:
	_context = _surface("DesignContext", CONTEXT_SIZE)
	_label(_context, Rect2(14, 6, 152, 35), "Design mode", 22, CREAM)
	_mode = _label(_context, Rect2(173, 8, 504, 33), "", 15, GOLD)
	_divider(_context, Rect2(13, 46, 1222, 1))
	_instruction = _label(_context, Rect2(14, 52, 704, 22), "", 16, CREAM)
	_feedback = _label(_context, Rect2(14, 77, 704, 20), "", 15, CREAM)
	_selection = _label(_context, Rect2(14, 97, 704, 21), "", 14, MUTED)
	_selection.mouse_filter = Control.MOUSE_FILTER_PASS
	_open_building_settings = _button(_context, Rect2(558, 92, 151, 25), "Building settings", "open_building_settings")
	_open_building_settings.hide()
	_quote = _label(_context, Rect2(723, 52, 511, 22), "", 15, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_apply_reason = _label(_context, Rect2(723, 73, 511, 26), "", 14, INVALID, HORIZONTAL_ALIGNMENT_RIGHT)
	_pending_notice = _label(_context, Rect2(723, 97, 511, 21), "", 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_cancel_pending = _button(_context, Rect2(707, 7, 165, 33), "Cancel queued plan", "cancel_pending")
	_cancel_pending.hide()
	_save = _button(_context, Rect2(880, 7, 102, 33), "Save draft", "save_draft")
	_save.tooltip_text = "Save your resort run with the current design draft, including unfinished edits."
	var discard := _button(_context, Rect2(990, 7, 90, 33), "Discard", "discard")
	discard.tooltip_text = "Return to the resort and discard changes since the last draft save."
	_apply = _button(_context, Rect2(1088, 7, 148, 33), "Apply now", "apply", null, true)


func _build_building_settings() -> void:
	_building_settings = _surface("BuildingSettings", BUILDING_SETTINGS_SIZE)
	_label(_building_settings, Rect2(13, 5, 253, 31), "Building settings", 18, CREAM)
	_button(_building_settings, Rect2(271, 7, 61, 26), "Close", "close_building_settings")
	_divider(_building_settings, Rect2(12, 40, 320, 1))
	_label(_building_settings, Rect2(13, 50, 64, 30), "Name", 14, GOLD)
	_name_field = LineEdit.new()
	_name_field.name = "BuildingName"
	_name_field.position = Vector2(80, 50)
	_name_field.size = Vector2(174, 35)
	_name_field.accessibility_name = "Building name"
	_name_field.placeholder_text = "Building name"
	_name_field.tooltip_text = "Enter up to %d characters, then choose Set name or press Enter." % Layout.MAX_BUILDING_NAME_LENGTH
	_name_field.mouse_force_pass_scroll_events = false
	_name_field.add_theme_font_size_override("font_size", 15)
	_name_field.add_theme_stylebox_override("normal", _box(Color("#4d3947"), EDGE, 4, 1, 7))
	_name_field.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("#e28a39"), 4, 2))
	_name_field.add_theme_color_override("font_color", CREAM)
	_name_field.text_changed.connect(func(_words: String) -> void: _update_name_edit_state())
	_name_field.text_submitted.connect(_commit_name)
	_building_settings.add_child(_name_field)
	_set_name = _button(_building_settings, Rect2(260, 50, 72, 35), "Set name", "commit_building_name", null, true)
	_name_status = _label(_building_settings, Rect2(13, 86, 318, 31), "", 13, VALID)
	_name_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_surface_settings = Control.new()
	_surface_settings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building_settings.add_child(_surface_settings)
	var y := 118.0
	for surface: String in Layout.FINISH_CATALOG:
		_label(_surface_settings, Rect2(13, y, 64, 30), surface.capitalize(), 14, GOLD)
		var field := OptionButton.new()
		field.name = surface.capitalize()
		field.position = Vector2(80, y)
		field.size = Vector2(252, 34)
		field.accessibility_name = "%s finish" % surface.capitalize()
		field.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		field.mouse_force_pass_scroll_events = false
		field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		field.add_theme_font_size_override("font_size", 14)
		field.add_theme_stylebox_override("normal", _box(Color("#4d3947"), EDGE, 4, 1, 7))
		field.add_theme_stylebox_override("hover", _box(Color("#644858"), EDGE, 4, 1, 7))
		field.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("#e28a39"), 4, 2))
		var choices: Array = Layout.FINISH_CATALOG[surface].keys()
		for choice: String in choices:
			field.add_icon_item(Renderer.finish_preview(surface, choice), Layout.FINISH_CATALOG[surface][choice].label)
			field.set_item_metadata(field.item_count - 1, choice)
		field.item_selected.connect(_select_finish.bind(surface, field))
		_surface_settings.add_child(field)
		_finish_fields[surface] = field
		y += 37.0
	_inspect_ceiling = _button(_surface_settings, Rect2(80, y + 3, 252, 29), "Inspect ceiling", "inspect_ceiling")
	_inspect_ceiling.toggle_mode = true
	_inspect_ceiling.tooltip_text = "Show the ceiling finish inside this building. Click again to return to the floor plan."
	_building_settings.hide()


func _select_finish(index: int, surface: String, field: OptionButton) -> void:
	_request("building_finish", {"surface": surface, "choice": field.get_item_metadata(index)})


func _build_palette() -> void:
	_palette = _surface("DesignPalette", PALETTE_SIZE)
	_add_choices(_category_buttons, CATEGORIES, 12, 104, "category")
	_add_choices(_landscape_buttons, LANDSCAPE_GROUPS, 453, 70, "landscape_group")
	_label(_palette, Rect2(680, 6, 308, 24), "Middle-drag pan · Wheel zoom · Esc cancels", 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_tool("select", "Select", 12, "tool", "select", "Select and inspect an existing object.")
	_add_tool("bulldoze", "Bulldoze", 86, "bulldoze", null, "Remove an object from the draft.")
	_move = _add_tool("move", "Move", 160, "move", null, "Move the selected outdoor object.")
	_divider(_palette, Rect2(237, 37, 1, 69))
	_add_catalog(BUILDINGS, "buildings", "building", Layout.BUILDING_CATALOG)
	_add_catalog(ASSETS, "furniture", "asset", Layout.ASSET_CATALOG)
	_add_catalog(TERRAIN, "terrain", "terrain")
	_add_catalog(PATHS, "path", "path")
	_add_catalog(SCENERY, "scenery", "prop", Layout.Landscape.PROP_CATALOG)
	_add_catalog(FACILITIES, "facilities", "prop", Layout.Landscape.PROP_CATALOG, 124.0)
	_brush_label = _label(_palette, Rect2(686, 35, 210, 20), "Brush size", 13, GOLD)
	for index in range(3):
		var brush_size := 1 + index * 2
		var words := "%d × %d" % [brush_size, brush_size]
		var button := _button(_palette, Rect2(686 + index * 62, 60, 58, 26), words, "brush_size", brush_size)
		button.name = "Brush%d" % brush_size
		button.toggle_mode = true
		button.accessibility_name = "%s tile brush" % words
		_brush_buttons[brush_size] = button
	_rotate = _button(_palette, Rect2(910, 34, 78, 50), "", "rotate")
	_rotate.tooltip_text = "Rotate clockwise by 90° (R)."
	_rotate.accessibility_name = "Rotate clockwise (R)"
	_icon(_rotate, "rotate", 78.0)
	_label(_rotate, Rect2(2, 27, 74, 21), "Rotate (R)", 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER)


func _add_choices(buttons: Dictionary, names: Dictionary, x: float, width: float, action: String) -> void:
	for id in names:
		var button := _button(_palette, Rect2(x, 5, width, 25), names[id], action, id)
		button.name = id.capitalize()
		button.toggle_mode = true
		buttons[id] = button
		x += width + 4


func _add_catalog(catalog: Dictionary, section: String, action: String,
		items: Dictionary = {}, tile_width: float = 70.0) -> void:
	var x := 247.0
	for id in catalog:
		var words: String = catalog[id]
		var value: String = id
		var request := action
		var help := words
		match id:
			"restore":
				request = "restore"
				help = "Restore the original ground and path in each tile."
			"erase":
				value = ""
				help = "Erase stone and boardwalk paths."
			"scenery_bench":
				value = "bench"
		var item: Dictionary = items.get(value, {})
		if item.has("capacity"):
			help = "%s · %d families" % [item.label, item.capacity]
		var cost: int = item.get("cost", -1)
		var button := _add_tool(id, words, x, request, value, help, section, tile_width, cost >= 0)
		if cost >= 0:
			var price_label := _label(button, Rect2(2, 50, tile_width - 4, 23), "", 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			price_label.name = "Price"
			_tool_prices[id] = {"label": price_label, "cost": cost, "help": help}
		x += tile_width + 4.0


func _add_tool(id: String, words: String, x: float, action: String, value: Variant,
		help: String, section: String = "", tile_width: float = 70.0, priced: bool = false) -> Button:
	var button := _button(_palette, Rect2(x, 34, tile_width, 74 if priced else 50), "", action, value)
	button.name = id.capitalize()
	button.toggle_mode = true
	button.button_group = _tool_group
	button.tooltip_text = help
	button.accessibility_name = words
	_tool_buttons[id] = button
	_tool_sections[id] = section
	_tool_icons[id] = _icon(button, "bench" if id == "scenery_bench" else id, tile_width)
	_tool_labels[id] = _label(button, Rect2(2, 27, tile_width - 4, 20), words, 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	return button


func _layout() -> void:
	var factor := minf(1.0, maxf(1.0, size.x - MARGIN * 2.0) / CONTEXT_SIZE.x)
	_context.scale = Vector2.ONE * factor
	_palette.scale = Vector2.ONE * factor
	_building_settings.scale = Vector2.ONE * factor
	_context.position = Vector2(roundf((size.x - CONTEXT_SIZE.x * factor) / 2.0), MARGIN)
	_palette.position = Vector2(roundf((size.x - PALETTE_SIZE.x * factor) / 2.0), size.y - MARGIN - PALETTE_SIZE.y * factor)
	_building_settings.position = Vector2(size.x - MARGIN - BUILDING_SETTINGS_SIZE.x * factor,
		_context.position.y + CONTEXT_SIZE.y * factor + 10)


func _request(action: String, value: Variant) -> void:
	if is_visible_in_tree():
		if action == "commit_building_name":
			_commit_name()
		else:
			action_requested.emit(action, value)


func _surface(element_name: String, bounds: Vector2) -> Panel:
	var panel := Panel.new()
	panel.name = element_name
	panel.size = bounds
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_force_pass_scroll_events = false
	var style := _box(CHROME, EDGE, 5)
	style.shadow_color = Color(0.13, 0.08, 0.12, 0.58)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


func _button(parent: Control, bounds: Rect2, words: String, action: String,
		value: Variant = null, primary: bool = false) -> Button:
	var button := Button.new()
	button.name = action.capitalize()
	button.position = bounds.position
	button.size = bounds.size
	button.text = words
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_force_pass_scroll_events = false
	button.add_theme_font_size_override("font_size", 14)
	var normal := Color("#235c54") if primary else Color("#4d3947")
	var hover := Color("#316e63") if primary else Color("#644858")
	button.add_theme_stylebox_override("normal", _box(normal, EDGE, 4))
	button.add_theme_stylebox_override("hover", _box(hover, EDGE, 4))
	button.add_theme_stylebox_override("pressed", _box(GOLD, GOLD, 4))
	button.add_theme_stylebox_override("hover_pressed", _box(GOLD.lightened(0.1), GOLD, 4))
	button.add_theme_stylebox_override("disabled", _box(Color("#42363e"), Color("#67505b"), 4))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, Color("#e28a39"), 4, 2))
	for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(color_name, CREAM)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_hover_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(_request.bind(action, value))
	parent.add_child(button)
	return button


func _label(parent: Control, bounds: Rect2, words: String, points: int, color: Color,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = bounds.position
	label.size = bounds.size
	label.text = words
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _icon(parent: Control, symbol: String, width: float) -> PixelIcon:
	var icon := PixelIcon.new()
	icon.name = "Icon"
	icon.symbol = symbol
	icon.position = Vector2((width - 24.0) / 2.0, 4)
	icon.size = Vector2(24, 24)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon


func _divider(parent: Control, bounds: Rect2) -> void:
	var line := ColorRect.new()
	line.position = bounds.position
	line.size = bounds.size
	line.color = EDGE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _box(fill: Color, border: Color, radius: int, width: int = 1, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style
