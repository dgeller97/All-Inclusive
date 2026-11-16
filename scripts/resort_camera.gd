extends Control

## A bounded, cursor-anchored map view. UI remains outside `world`.
signal view_changed(zoom_level: float)

const ZOOM_STEP := 1.15
const MAX_ZOOM := 4.0
const DRAG_THRESHOLD := 5.0
const Landscape := preload("res://scripts/landscape_model.gd")

var world := Node2D.new()
var world_bounds := Landscape.WORLD_BOUNDS
var home_center := Vector2(265, 150)
var home_zoom := 1.8
var zoom_level := 1.8
var pointer_blocked := Callable()
var interaction_allowed := Callable()
var allow_left_drag := true
var _configured := false
var _last_size := Vector2.ZERO
var _drag_button := MOUSE_BUTTON_NONE
var _drag_start := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _drag_active := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_NONE
	world.name = "World"
	add_child(world)


func _ready() -> void:
	resized.connect(_on_resized)
	_last_size = size
	if not _configured:
		configure(world_bounds, home_center, home_zoom)


func configure(bounds: Rect2, center: Vector2 = Vector2(265, 150), initial_zoom: float = 1.8) -> void:
	assert(bounds.size.x > 0.0 and bounds.size.y > 0.0, "Camera bounds must have positive area")
	world_bounds = bounds
	home_center = center
	home_zoom = initial_zoom
	_configured = true
	_last_size = size
	home()


func minimum_zoom() -> float:
	# Fill the viewport at the widest zoom, avoiding blank margins around the map.
	return maxf(0.1, maxf(size.x / world_bounds.size.x, size.y / world_bounds.size.y))


func maximum_zoom() -> float:
	return maxf(MAX_ZOOM, minimum_zoom())


func screen_to_world(point: Vector2) -> Vector2:
	return (point - world.position) / zoom_level


func world_to_screen(point: Vector2) -> Vector2:
	return point * zoom_level + world.position


func zoom_at(point: Vector2, factor: float) -> void:
	if not is_finite(factor) or factor <= 0.0:
		return
	var anchor := screen_to_world(point)
	zoom_level = clampf(zoom_level * factor, minimum_zoom(), maximum_zoom())
	world.position = point - anchor * zoom_level
	_apply_transform()


func zoom_in() -> void:
	zoom_at(size * 0.5, ZOOM_STEP)


func zoom_out() -> void:
	zoom_at(size * 0.5, 1.0 / ZOOM_STEP)


func home() -> void:
	cancel_drag()
	zoom_level = clampf(home_zoom, minimum_zoom(), maximum_zoom())
	world.position = size * 0.5 - home_center * zoom_level
	_apply_transform()


func pan_by(delta: Vector2) -> void:
	if not delta.is_finite():
		return
	world.position += delta
	_apply_transform()


func snapshot() -> Dictionary:
	return {"zoom": zoom_level, "center": screen_to_world(size * 0.5)}


func restore(data: Dictionary) -> bool:
	var saved_zoom: Variant = data.get("zoom")
	var saved_center: Variant = data.get("center")
	if not (saved_zoom is float or saved_zoom is int) or not saved_center is Vector2:
		return false
	if not is_finite(float(saved_zoom)) or float(saved_zoom) <= 0.0 or not saved_center.is_finite():
		return false
	cancel_drag()
	zoom_level = clampf(float(saved_zoom), minimum_zoom(), maximum_zoom())
	world.position = size * 0.5 - saved_center * zoom_level
	_apply_transform()
	return true


func is_dragging() -> bool:
	return _drag_active


func cancel_drag() -> void:
	_drag_button = MOUSE_BUTTON_NONE
	_drag_active = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func _apply_transform() -> void:
	world.scale = Vector2.ONE * zoom_level
	var lower := size - world_bounds.end * zoom_level
	var upper := -world_bounds.position * zoom_level
	world.position = Vector2(
		clampf(world.position.x, lower.x, upper.x),
		clampf(world.position.y, lower.y, upper.y)
	)
	view_changed.emit(zoom_level)


func _on_resized() -> void:
	if not _configured:
		return
	var center := screen_to_world(_last_size * 0.5)
	_last_size = size
	zoom_level = clampf(zoom_level, minimum_zoom(), maximum_zoom())
	world.position = size * 0.5 - center * zoom_level
	_apply_transform()


func _point_allowed(point: Vector2) -> bool:
	if interaction_allowed.is_valid() and not bool(interaction_allowed.call()):
		return false
	if pointer_blocked.is_valid() and bool(pointer_blocked.call(get_global_transform() * point)):
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


func _input(event: InputEvent) -> void:
	# Releases can land over a menu or outside the clipped map. Never latch a drag.
	if event is InputEventMouseButton and not event.pressed and event.button_index == _drag_button:
		cancel_drag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not _point_allowed(event.position):
			cancel_drag()
			return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_at(event.position, ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE or (allow_left_drag and event.button_index == MOUSE_BUTTON_LEFT):
			if event.pressed:
				_drag_button = event.button_index
				_drag_start = event.position
				_last_pointer = event.position
				_drag_active = event.button_index == MOUSE_BUTTON_MIDDLE
				if _drag_active:
					mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				cancel_drag()
			accept_event()
	elif event is InputEventMouseMotion and _drag_button != MOUSE_BUTTON_NONE:
		if not _point_allowed(event.position):
			cancel_drag()
			return
		var required_mask := MOUSE_BUTTON_MASK_LEFT if _drag_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_MIDDLE
		if not (event.button_mask & required_mask):
			cancel_drag()
			return
		if not _drag_active:
			if event.position.distance_to(_drag_start) < DRAG_THRESHOLD:
				return
			_drag_active = true
			mouse_default_cursor_shape = Control.CURSOR_DRAG
			pan_by(event.position - _drag_start)
		else:
			pan_by(event.position - _last_pointer)
		_last_pointer = event.position
		accept_event()
