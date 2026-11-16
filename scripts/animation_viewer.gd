extends Control
## A synchronized animation inspector using the same map renderer as the resort.

signal viewer_closed

const Preview := preload("res://scripts/animation_preview.gd")
const ResortMap := preload("res://scripts/resort_map.gd")
const FRAME_SECONDS := 1.0 / 30.0
const SPEEDS := [0.25, 0.5, 1.0, 2.0]
const STUDIO := Color("#251e2b")
const PANEL := Color("#392d3d")
const LINE := Color("#655062")
const GOLD := Color("#ecc387")
const INK := Color("#f6e5ca")
const MUTED := Color("#d2b8be")

var clip_id := "dining"
var phase_id := "activity"
var playhead := 0.0
var duration := 0.0
var playing := false
var speed := 1.0
var view_zoom := 0.0
var full_occupancy := false
var guest_variant := 0
var panel_maps: Array[ResortMap] = []
var panel_viewports: Array[SubViewport] = []
var fixtures: Array[Dictionary] = []

var _phases: Array[Dictionary] = []
var _hosts: Array[SubViewportContainer] = []
var _grid: GridContainer
var _clip_picker: OptionButton
var _phase_picker: OptionButton
var _speed_picker: OptionButton
var _zoom_picker: OptionButton
var _occupancy_picker: OptionButton
var _variant_picker: OptionButton
var _play: Button
var _previous: Button
var _next: Button
var _done: Button
var _clock: Label
var _scrub: HSlider
var _status: Label
var _fit_size := Vector2.ONE
var _walk_size := Vector2(88, 84)


func _ready() -> void:
	hide()
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_controls()
	set_process(false)


func show_viewer() -> void:
	if visible:
		return
	show()
	if fixtures.is_empty():
		select_clip(clip_id)
	set_playing(true)
	_play.grab_focus()


func close() -> void:
	if not visible:
		return
	set_playing(false)
	_drop_panels()
	hide()
	viewer_closed.emit()


func select_clip(id: String) -> bool:
	if not Preview.catalog().has(id):
		return false
	var panels := Preview.build_panels(id)
	if panels.is_empty():
		_set_selection(_clip_picker, clip_id)
		_status.text = "This animation could not be prepared."
		_status.show()
		set_playing(false)
		return false
	_drop_panels()
	_status.hide()
	fixtures = panels
	clip_id = id
	_phases = Preview.phases(id)
	_set_selection(_clip_picker, clip_id)
	_grid.columns = 1 if Preview.fixed_coast(id) else 2
	_fit_size = Vector2.ONE
	for index in fixtures.size():
		var fixture := fixtures[index]
		var bounds: Rect2 = fixture.bounds
		_fit_size = _fit_size.max(bounds.size)
		_add_panel(index)
	_phase_picker.clear()
	_option(_phase_picker, "Whole sequence", "sequence")
	for phase in _phases:
		_option(_phase_picker, phase.label, phase.id)
	_phase_picker.disabled = _phases.size() < 2
	_scope_focus()
	select_phase("activity")
	return true


func select_phase(id: String) -> bool:
	var selected := _phase(id)
	if id != "sequence" and selected.is_empty():
		return false
	phase_id = id
	_set_selection(_phase_picker, id)
	duration = float(selected.length) if id != "sequence" else _sequence_duration()
	_scrub.max_value = duration
	seek(0.0)
	return true


func seek(seconds: float) -> void:
	if not is_finite(seconds) or fixtures.is_empty():
		return
	playhead = clampf(seconds, 0.0, duration)
	var segment := _phase_at(playhead)
	if segment.is_empty():
		return
	_scrub.set_value_no_signal(playhead)
	var frame := floori((playhead + 0.00001) / FRAME_SECONDS)
	_clock.text = "%s   %.2f / %.2f s   ·   Frame %03d" % [segment.phase.label, playhead, duration, frame]
	_walk_size = Vector2(88, 84)
	for index in fixtures.size():
		var fixture := fixtures[index]
		Preview.sample(fixture, clip_id, segment.phase, segment.age, segment.offset, full_occupancy, guest_variant)
		var map := panel_maps[index]
		var sim: Preview.Sim = fixture.sim
		map.present(sim, fixture.time)
		map.signs.hide()
		map.actors.queue_redraw()
		var follow: bool = segment.phase.id != "activity" or clip_id in ["walking", "ocean_evacuation"] or view_zoom > 0.0
		var bounds := _guest_bounds(map) if follow else Rect2()
		fixture.guest_bounds = bounds
		_walk_size = _walk_size.max(bounds.size + Vector2(22, 18))
	for index in fixtures.size():
		_position(index)


func step_frame(direction: int) -> void:
	set_playing(false)
	var current := playhead / FRAME_SECONDS
	if direction > 0:
		seek(float(floori(current + 0.00001) + 1) * FRAME_SECONDS)
	elif direction < 0:
		seek(float(ceili(current - 0.00001) - 1) * FRAME_SECONDS)


func set_playing(value: bool) -> void:
	playing = value and visible and not fixtures.is_empty()
	if _play:
		_play.text = "Pause" if playing else "Play"
	set_process(playing)


func set_speed(value: float) -> void:
	if not is_finite(value):
		return
	speed = clampf(value, SPEEDS[0], SPEEDS[-1])
	_set_selection(_speed_picker, speed)


func set_full_occupancy(value: bool) -> void:
	full_occupancy = value
	_set_selection(_occupancy_picker, value)
	seek(playhead)


func set_view_zoom(value: float) -> void:
	if value in [0.0, 2.0, 4.0]:
		view_zoom = value
		_set_selection(_zoom_picker, value)
		seek(playhead)


func set_guest_variant(index: int) -> void:
	guest_variant = clampi(index, 0, 2)
	_set_selection(_variant_picker, guest_variant)
	seek(playhead)


func _process(delta: float) -> void:
	if not playing or duration <= 0.0:
		return
	seek(fposmod(playhead + delta * speed, duration))


func _phase(id: String) -> Dictionary:
	for record in _phases:
		if record.id == id:
			return record
	return {}


func _sequence_duration() -> float:
	var total := 0.0
	for record in _phases:
		total += float(record.length)
	return total


func _phase_at(seconds: float) -> Dictionary:
	var start := 0.0
	for index in _phases.size():
		var record := _phases[index]
		var length: float = record.length
		if phase_id == record.id:
			return {"phase": record, "age": clampf(seconds, 0.0, length), "offset": start}
		if phase_id == "sequence" and (seconds < start + length or index == _phases.size() - 1):
			return {"phase": record, "age": clampf(seconds - start, 0.0, length), "offset": start}
		start += length
	return {}


func _add_panel(index: int) -> void:
	var label := "Fixed coastline" if Preview.fixed_coast(clip_id) else "%d°" % (90 * index)
	var card := PanelContainer.new()
	card.name = "Angle%d" % index
	card.add_theme_stylebox_override("panel", _style(PANEL, LINE, 5, 7))
	_expand(card)
	_grid.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)
	var title := _label(label, 15, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var host := SubViewportContainer.new()
	host.name = "PreviewSurface"
	host.stretch = true
	host.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	host.mouse_filter = MOUSE_FILTER_IGNORE
	host.custom_minimum_size = Vector2(180, 110)
	_expand(host)
	stack.add_child(host)
	var viewport := SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(320, 180)
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	host.add_child(viewport)
	var map := ResortMap.new()
	map.name = "RuntimeResortMap"
	viewport.add_child(map)
	map.ocean.visible = Preview.fixed_coast(clip_id)
	_hosts.append(host)
	panel_maps.append(map)
	panel_viewports.append(viewport)
	host.resized.connect(func() -> void: _position(index))


func _position(index: int) -> void:
	if index >= fixtures.size() or index >= _hosts.size():
		return
	var ext := _hosts[index].size
	if ext.x <= 0.0 or ext.y <= 0.0:
		return
	var fixture := fixtures[index]
	var map := panel_maps[index]
	var bounds: Rect2 = fixture.bounds
	# Use the same scale across the rotations and follow the real guest route
	# while traveling or inspecting at a fixed magnification.
	var guests: Rect2 = fixture.get("guest_bounds", Rect2())
	var focus := guests.get_center() if guests.has_area() else bounds.get_center()
	var span := _walk_size if clip_id == "walking" else _fit_size + Vector2(44, 45)
	if guests.has_area():
		span = span.max(_walk_size)
	var world := Preview.Layout.WORLD_BOUNDS
	var minimum := maxf(ext.x / world.size.x, ext.y / world.size.y)
	var fit := clampf(minf(ext.x / span.x, ext.y / span.y), minimum, maxf(4.0, minimum))
	var zoom := maxf(view_zoom, minimum) if view_zoom > 0.0 else fit
	var view := ext / zoom
	var half := view * 0.5
	focus = focus.clamp(world.position + half, world.end - half)
	map.scale = Vector2.ONE * zoom
	map.position = (ext * 0.5 - focus * zoom).round()


func _guest_bounds(map: ResortMap) -> Rect2:
	var region := Rect2()
	for family: Dictionary in map.simulation.families:
		var pose := map._pose(family)
		for child: bool in [false, true]:
			if not child and pose.get("child_only", false):
				continue
			var foot: Vector2 = map._guest_sprite(family, pose, child).point
			if foot.is_finite():
				var body := Rect2(foot - Vector2(7, 21), Vector2(14, 23))
				region = body if not region.has_area() else region.merge(body)
	return region


func _drop_panels() -> void:
	for viewport in panel_viewports:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for card in _grid.get_children():
		_grid.remove_child(card)
		card.queue_free()
	fixtures.clear()
	_hosts.clear()
	panel_maps.clear()
	panel_viewports.clear()


func _build_controls() -> void:
	var background := ColorRect.new()
	background.color = STUDIO
	background.mouse_filter = MOUSE_FILTER_STOP
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_STOP
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["top", "bottom", "left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	var heading := _label("Animation Viewer", 26, INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	_done = _button("Close", close)
	_done.name = "CloseViewer"
	header.add_child(_done)

	var pickers := HBoxContainer.new()
	pickers.add_theme_constant_override("separation", 12)
	column.add_child(pickers)
	_clip_picker = _picker(pickers, "Animation", "ClipPicker", true)
	_phase_picker = _picker(pickers, "Phase", "PhasePicker")
	_occupancy_picker = _picker(pickers, "Occupancy", "OccupancyPicker")
	_variant_picker = _picker(pickers, "Adult appearance", "GuestPicker")
	var catalog := Preview.catalog()
	for id: String in catalog:
		_option(_clip_picker, catalog[id], id)
	_option(_occupancy_picker, "One family", false)
	_option(_occupancy_picker, "Full", true)
	for index in range(3):
		_option(_variant_picker, "Guest %d" % (index + 1), index)
	_clip_picker.item_selected.connect(func(index: int) -> void: select_clip(_clip_picker.get_item_metadata(index)))
	_phase_picker.item_selected.connect(func(index: int) -> void: select_phase(_phase_picker.get_item_metadata(index)))
	_occupancy_picker.item_selected.connect(func(index: int) -> void: set_full_occupancy(_occupancy_picker.get_item_metadata(index)))
	_variant_picker.item_selected.connect(func(index: int) -> void: set_guest_variant(_variant_picker.get_item_metadata(index)))
	_status = _label("", 14, GOLD)
	_status.hide()
	column.add_child(_status)

	_grid = GridContainer.new()
	_grid.name = "Angles"
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_expand(_grid)
	column.add_child(_grid)

	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 8)
	column.add_child(playback)
	_previous = _button("‹ Frame", func() -> void: step_frame(-1))
	_previous.name = "PreviousFrame"
	playback.add_child(_previous)
	_play = _button("Play", func() -> void: set_playing(not playing))
	_play.name = "PlayPause"
	_play.custom_minimum_size.x = 72
	playback.add_child(_play)
	_next = _button("Frame ›", func() -> void: step_frame(1))
	_next.name = "NextFrame"
	playback.add_child(_next)
	_speed_picker = OptionButton.new()
	_speed_picker.name = "SpeedPicker"
	_speed_picker.tooltip_text = "Playback speed"
	_tint_button(_speed_picker)
	for value: float in SPEEDS:
		_option(_speed_picker, "%s×" % str(value), value)
	_set_selection(_speed_picker, speed)
	_speed_picker.item_selected.connect(func(index: int) -> void: set_speed(_speed_picker.get_item_metadata(index)))
	playback.add_child(_speed_picker)
	_zoom_picker = OptionButton.new()
	_zoom_picker.name = "ZoomPicker"
	_zoom_picker.tooltip_text = "Preview magnification"
	_tint_button(_zoom_picker)
	_option(_zoom_picker, "Zoom to fit", 0.0)
	_option(_zoom_picker, "2× zoom", 2.0)
	_option(_zoom_picker, "4× zoom", 4.0)
	_zoom_picker.item_selected.connect(func(index: int) -> void: set_view_zoom(_zoom_picker.get_item_metadata(index)))
	playback.add_child(_zoom_picker)
	_scrub = HSlider.new()
	_scrub.name = "Timeline"
	_scrub.tooltip_text = "Seek to any moment in the selected phase"
	_scrub.step = 0.001
	_scrub.custom_minimum_size = Vector2(130, 30)
	_scrub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scrub.add_theme_color_override("font_color", INK)
	playback.add_child(_scrub)
	_scrub.value_changed.connect(func(value: float) -> void:
		set_playing(false)
		seek(value))
	_clock = _label("", 14, MUTED)
	_clock.name = "Clock"
	_clock.custom_minimum_size.x = 325
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	playback.add_child(_clock)


func _scope_focus() -> void:
	var items: Array[Control] = [_done, _clip_picker]
	if not _phase_picker.disabled:
		items.append(_phase_picker)
	items.append_array([_occupancy_picker, _variant_picker, _previous, _play, _next, _speed_picker, _zoom_picker, _scrub])
	for index in items.size():
		var current := items[index]
		var previous := current.get_path_to(items[posmod(index - 1, items.size())])
		var next := current.get_path_to(items[(index + 1) % items.size()])
		current.focus_previous = previous
		current.focus_next = next
		current.focus_neighbor_left = previous
		current.focus_neighbor_top = previous
		current.focus_neighbor_right = next
		current.focus_neighbor_bottom = next


func _picker(parent: BoxContainer, title: String, node_name: String, wide: bool = false) -> OptionButton:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	if wide:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	column.add_child(_label(title, 13, MUTED))
	var list := OptionButton.new()
	list.name = node_name
	list.custom_minimum_size.x = 140
	list.fit_to_longest_item = true
	_tint_button(list)
	column.add_child(list)
	return list


func _option(list: OptionButton, text: String, value: Variant) -> void:
	list.add_item(text)
	list.set_item_metadata(list.item_count - 1, value)


func _set_selection(list: OptionButton, value: Variant) -> void:
	if not list:
		return
	for index in list.item_count:
		if list.get_item_metadata(index) == value:
			list.select(index)
			return


func _expand(item: Control) -> void:
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _label(value: String, point: int, ink: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", point)
	label.add_theme_color_override("font_color", ink)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	_tint_button(button)
	button.pressed.connect(action)
	return button


func _tint_button(button: Button) -> void:
	button.custom_minimum_size.y = 31
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _style(PANEL, LINE, 4, 9))
	button.add_theme_stylebox_override("hover", _style(PANEL.lightened(0.13), GOLD, 4, 9))
	button.add_theme_stylebox_override("pressed", _style(PANEL.darkened(0.1), GOLD, 4, 9))
	var focus := _style(Color.TRANSPARENT, GOLD, 4, 9)
	button.add_theme_stylebox_override("focus", focus)


func _style(fill: Color, edge: Color, radius: int, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box
