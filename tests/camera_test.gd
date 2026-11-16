extends SceneTree

const ResortCamera = preload("res://scripts/resort_camera.gd")
const Landscape := preload("res://scripts/landscape_model.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	var camera := ResortCamera.new()
	camera.size = Vector2(1280, 720)
	root.add_child(camera)
	camera.configure(Landscape.WORLD_BOUNDS)
	check(is_equal_approx(camera.zoom_level, 1.8), "Home zoom")
	check(camera.screen_to_world(Vector2(640, 360)).is_equal_approx(Vector2(265, 150)), "Home focuses resort")
	var cursor := Vector2(710, 350)
	var anchor := camera.screen_to_world(cursor)
	camera.zoom_at(cursor, 1.15)
	check(camera.screen_to_world(cursor).is_equal_approx(anchor), "Wheel zoom preserves cursor's world point")
	check(camera.world_to_screen(anchor).is_equal_approx(cursor), "Map label forward transform matches camera")
	var position_before := camera.world.position
	camera.pan_by(Vector2(-45, 26))
	check(camera.world.position.is_equal_approx(position_before + Vector2(-45, 26)), "Drag delta moves map")
	camera.pan_by(Vector2(100000, 100000))
	check(camera.world.position.is_equal_approx(-camera.world_bounds.position * camera.zoom_level), "Top-left map bounds clamp")
	camera.pan_by(Vector2(-100000, -100000))
	check(camera.world.position.is_equal_approx(camera.size - camera.world_bounds.end * camera.zoom_level), "Bottom-right map bounds clamp")
	camera.zoom_at(cursor, 1000)
	check(is_equal_approx(camera.zoom_level, 4.0), "Maximum zoom clamps")
	camera.zoom_at(cursor, 0.0001)
	check(is_equal_approx(camera.zoom_level, camera.minimum_zoom()), "Minimum zoom fills map without blank margins")
	check(camera.world_to_screen(camera.world_bounds.position).x <= 0.01, "World covers left viewport edge")
	check(camera.world_to_screen(camera.world_bounds.end).x >= camera.size.x - 0.01, "World covers right viewport edge")
	camera.home()
	camera.zoom_in()
	camera.pan_by(Vector2(-80, -35))
	var saved := camera.snapshot()
	camera.home()
	check(camera.restore(saved), "Camera save restore accepted")
	check(camera.snapshot().center.is_equal_approx(saved.center), "Saved camera center restored")
	check(is_equal_approx(camera.zoom_level, saved.zoom), "Saved zoom restored")
	var good := camera.snapshot()
	for bad in [{}, {"zoom": NAN, "center": Vector2.ZERO}, {"zoom": 2, "center": "bad"}, {"zoom": -1, "center": Vector2.ZERO}, {"zoom": 2, "center": Vector2(INF, 0)}]:
		check(not camera.restore(bad), "Malformed camera state rejected")
		check(camera.snapshot() == good, "Malformed camera state preserves current camera")
	camera.home()
	position_before = camera.world.position
	_press(camera, Vector2(600, 300), MOUSE_BUTTON_LEFT)
	_move(camera, Vector2(602, 300), MOUSE_BUTTON_MASK_LEFT)
	check(not camera.is_dragging() and camera.world.position == position_before, "Small click movement does not pan")
	_move(camera, Vector2(620, 310), MOUSE_BUTTON_MASK_LEFT)
	check(camera.is_dragging() and camera.world.position.is_equal_approx(position_before + Vector2(20, 10)), "Left drag crosses threshold and pans")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	camera._input(release)
	check(not camera.is_dragging(), "Release over UI clears drag")
	camera.pointer_blocked = func(point: Vector2) -> bool: return point.x > 1000
	position_before = camera.world.position
	_press(camera, Vector2(1100, 300), MOUSE_BUTTON_LEFT)
	_move(camera, Vector2(1150, 330), MOUSE_BUTTON_MASK_LEFT)
	check(not camera.is_dragging() and camera.world.position == position_before, "UI region cannot start a pan")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(1100, 300)
	var zoom_before: float = camera.zoom_level
	camera._gui_input(wheel)
	check(camera.zoom_level == zoom_before, "UI scrolling cannot zoom world")
	camera.interaction_allowed = func() -> bool: return false
	_press(camera, Vector2(600, 300), MOUSE_BUTTON_MIDDLE)
	check(not camera.is_dragging(), "Modal blocks middle drag")
	camera.interaction_allowed = Callable()
	_press(camera, Vector2(600, 300), MOUSE_BUTTON_MIDDLE)
	check(camera.is_dragging(), "Middle drag starts immediately")
	_move(camera, Vector2(650, 320), MOUSE_BUTTON_MASK_MIDDLE)
	check(camera.world.position.is_equal_approx(position_before + Vector2(50, 20)), "Middle drag pans")
	camera._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not camera.is_dragging(), "Focus loss cancels held drag")
	camera.home()
	var center_before: Vector2 = camera.screen_to_world(camera.size * 0.5)
	camera.size = Vector2(1000, 600)
	await process_frame
	check(camera.screen_to_world(camera.size * 0.5).is_equal_approx(center_before), "Resize preserves world center")
	print("Camera checks: %d/%d passed" % [checks - failures, checks])
	camera.queue_free()
	await process_frame
	quit(1 if failures else 0)


func _press(camera: Control, point: Vector2, button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = point
	camera._gui_input(event)


func _move(camera: Control, point: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.button_mask = mask
	camera._gui_input(event)
