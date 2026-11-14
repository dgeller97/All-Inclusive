extends Control

signal action_requested(action: String, value: Variant)

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
const PALETTE_SIZE := Vector2(1176, 90)
const BUILDINGS := {"bedroom": "Bedroom", "reception": "Reception", "buffet": "Buffet", "pool": "Pool"}
const ASSETS := {
	"bed": "Bed", "desk": "Desk", "counter": "Counter", "table": "Table",
	"lounger": "Lounger", "umbrella": "Umbrella", "plant": "Plant", "bench": "Bench",
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
var _tool_group := ButtonGroup.new()
var _tool_buttons: Dictionary = {}
var _tool_icons: Dictionary = {}
var _tool_labels: Dictionary = {}


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
	resized.connect(_layout)
	_layout()
	refresh(_state)


func refresh(data: Dictionary) -> void:
	_state = data
	visible = data.get("active", false)
	if _context == null or not visible:
		return

	var tool: String = data.get("tool", "select")
	var building: String = data.get("building", "bedroom")
	var asset: String = data.get("asset", "bed")
	var turn := posmod(int(data.get("rotation", 0)), 4) * 90
	var instruction: String = data.get("instruction", "")
	_instruction.text = instruction if not instruction.is_empty() else _tool_instruction(tool, building, asset, turn)
	_feedback.text = data.get("feedback", "")
	var feedback_color := CREAM
	if data.has("feedback_valid"):
		feedback_color = VALID if data.feedback_valid else INVALID
	_feedback.add_theme_color_override("font_color", feedback_color)
	var selection: String = data.get("selection", "")
	_selection.text = "Selected · " + selection if not selection.is_empty() else ""

	var selected_key := tool
	if tool == "building":
		selected_key = building
	elif tool == "asset":
		selected_key = asset
	for id in _tool_buttons:
		var selected: bool = id == selected_key
		_tool_buttons[id].set_pressed_no_signal(selected)
		_tool_icons[id].set_tint(INK if selected else GOLD)
		_tool_labels[id].add_theme_color_override("font_color", INK if selected else CREAM)
	_rotate.disabled = not data.get("can_rotate", tool == "asset")
	_rotate.accessibility_name = "Rotate clockwise (R), %d degrees" % turn
	_rotate.get_node("Icon").set_tint(MUTED if _rotate.disabled else GOLD)

	_refresh_apply(data)


func is_pointer_over_ui(point: Vector2) -> bool:
	if not is_visible_in_tree() or _context == null:
		return false
	return _context.get_global_rect().has_point(point) or _palette.get_global_rect().has_point(point)


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
	_save.disabled = not data.get("can_save_draft", true)

	var pending: bool = data.get("has_pending", false)
	_cancel_pending.visible = pending
	var pending_day: int = data.get("pending_day", 0)
	var reserve: int = data.get("pending_reserve", 0)
	var pending_notice := "Day %d plan queued" % pending_day if pending_day > 0 else "Plan queued for tomorrow"
	if reserve > 0:
		pending_notice += " · $%d reserved" % reserve
	_pending_notice.text = pending_notice if pending else ""
	_cancel_pending.tooltip_text = "Cancel the queued plan and release $%d to resort cash." % reserve if reserve > 0 else "Cancel the queued plan."


func _tool_instruction(tool: String, building: String, asset: String, rotation: int) -> String:
	match tool:
		"building":
			return "%s · Left-drag a footprint on the 8 px grid." % BUILDINGS.get(building, "Building")
		"asset":
			return "%s · Left-click to place on the grid. Rotation %d°." % [ASSETS.get(asset, "Furniture"), rotation]
		"bulldoze":
			return "Bulldoze · Left-click a building or piece of furniture to remove it from the draft."
	return "Select · Left-click a building or piece of furniture to inspect it."


func _build_context() -> void:
	_context = _surface("DesignContext", CONTEXT_SIZE)
	_label(_context, Rect2(14, 6, 152, 35), "Design mode", 22, CREAM)
	_mode = _label(_context, Rect2(173, 8, 504, 33), "", 15, GOLD)
	_divider(_context, Rect2(13, 46, 1222, 1))
	_instruction = _label(_context, Rect2(14, 52, 704, 22), "", 16, CREAM)
	_feedback = _label(_context, Rect2(14, 77, 704, 20), "", 15, CREAM)
	_selection = _label(_context, Rect2(14, 97, 704, 21), "", 14, MUTED)
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


func _build_palette() -> void:
	_palette = _surface("DesignPalette", PALETTE_SIZE)
	_label(_palette, Rect2(12, 6, 145, 19), "Tools", 13, GOLD)
	_label(_palette, Rect2(176, 6, 290, 19), "Draw buildings", 13, GOLD)
	_label(_palette, Rect2(488, 6, 190, 19), "Place furniture", 13, GOLD)
	_label(_palette, Rect2(674, 6, 490, 19), "Middle-drag to pan · Wheel to zoom · Esc or right-click to cancel tool", 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_divider(_palette, Rect2(165, 12, 1, 66))
	_divider(_palette, Rect2(477, 12, 1, 66))
	_add_tool("select", "Select", 12, "tool", "select", "Select and inspect an existing object.")
	_add_tool("bulldoze", "Bulldoze", 86, "bulldoze", null, "Remove a building or piece of furniture from the draft.")
	var x := 176
	for id in BUILDINGS:
		_add_tool(id, BUILDINGS[id], x, "building", id, "Draw a %s footprint by dragging on the grid." % String(BUILDINGS[id]).to_lower())
		x += 74
	x = 488
	for id in ASSETS:
		_add_tool(id, ASSETS[id], x, "asset", id, "Place %s furniture with a click on the grid." % String(ASSETS[id]).to_lower())
		x += 74
	_rotate = _button(_palette, Rect2(1086, 30, 78, 54), "", "rotate")
	_rotate.tooltip_text = "Rotate clockwise by 90° (R)."
	_rotate.accessibility_name = "Rotate clockwise (R)"
	_icon(_rotate, "rotate", 78.0)
	_label(_rotate, Rect2(2, 29, 74, 23), "Rotate (R)", 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER)


func _add_tool(id: String, words: String, x: float, action: String, value: Variant, help: String) -> void:
	var button := _button(_palette, Rect2(x, 30, 70, 54), "", action, value)
	button.name = id.capitalize()
	button.toggle_mode = true
	button.button_group = _tool_group
	button.tooltip_text = help
	button.accessibility_name = words
	_tool_buttons[id] = button
	_tool_icons[id] = _icon(button, id, 70.0)
	_tool_labels[id] = _label(button, Rect2(2, 29, 66, 23), words, 13, CREAM, HORIZONTAL_ALIGNMENT_CENTER)


func _layout() -> void:
	var factor := minf(1.0, maxf(1.0, size.x - MARGIN * 2.0) / CONTEXT_SIZE.x)
	_context.scale = Vector2.ONE * factor
	_palette.scale = Vector2.ONE * factor
	_context.position = Vector2(roundf((size.x - CONTEXT_SIZE.x * factor) / 2.0), MARGIN)
	_palette.position = Vector2(roundf((size.x - PALETTE_SIZE.x * factor) / 2.0), size.y - MARGIN - PALETTE_SIZE.y * factor)


func _request(action: String, value: Variant) -> void:
	if is_visible_in_tree():
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
