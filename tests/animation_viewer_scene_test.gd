extends SceneTree
const Scene = preload("res://scenes/resort.tscn")
const Save = preload("res://scripts/save_slot.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path(Save.PATH).replace("\\", "/").contains("/.tools/r14-scene"):
		printerr("Use isolated APPDATA under .tools/r14-scene")
		quit(2)
		return
	var game := Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	var existed := Save.exists()
	var save_bytes := FileAccess.get_file_as_bytes(Save.PATH) if existed else PackedByteArray()
	var welcome_state: Dictionary = game.simulation.snapshot()
	var clicked := false
	for button in game.dialog.find_children("*", "Button", true, false):
		if button.text.begins_with("Animation viewer"):
			button.pressed.emit()
			clicked = true
			break
	check(clicked and game.animation_viewer.visible and not game.started, "Viewer opens directly from welcome without starting a run")
	for backwards in [false, true]:
		for step in range(14):
			var tab := InputEventKey.new()
			tab.keycode = KEY_TAB
			tab.shift_pressed = backwards
			tab.pressed = true
			root.push_input(tab, true)
			tab.pressed = false
			root.push_input(tab, true)
			var focused := root.gui_get_focus_owner()
			check(is_instance_valid(focused) and game.animation_viewer.is_ancestor_of(focused), "Tab stays inside viewer over welcome")
	game.animation_viewer.find_child("PlayPause", true, false).grab_focus()
	var was_playing: bool = game.animation_viewer.playing
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	root.push_input(space, true)
	space.pressed = false
	root.push_input(space, true)
	check(game.animation_viewer.playing != was_playing and not game.started and game.menu_mode == "welcome"
		and game.simulation.snapshot() == welcome_state, "Space operates viewer without starting or changing the covered welcome run")
	game.animation_viewer.close()
	check(not game.animation_viewer.visible and game.menu_mode == "welcome", "Close returns to welcome")
	game._new_run("developer")
	game._process(65.25)
	var state: Dictionary = game.simulation.snapshot()
	var elapsed: float = game.elapsed
	var notice_time: float = game.toast_time
	var camera: Dictionary = game.camera.snapshot()
	var paused: bool = game.paused
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F8
	game._input(key)
	check(game.animation_viewer.visible, "F8 opens viewer during live game")
	game._process(30.0)
	key.keycode = KEY_SPACE
	game._input(key)
	check(game.simulation.snapshot() == state and game.elapsed == elapsed and game.toast_time == notice_time,
		"Inspecting animations freezes simulation, fractional clock and notifications without consuming IDs")
	check(game.paused == paused and game.camera.snapshot() == camera and not game.camera.interaction_allowed.call(),
		"Viewer keys do not toggle game pause or move the resort camera")
	key.keycode = KEY_ESCAPE
	game._input(key)
	check(not game.animation_viewer.visible and game.paused == paused, "Escape returns to unchanged live pause state")
	game.ui.open_panel("settings")
	var settings_clicked := false
	for button in game.ui._popover.find_children("*", "Button", true, false):
		if button.text.begins_with("Animation viewer"):
			button.pressed.emit()
			settings_clicked = true
			break
	check(settings_clicked and game.animation_viewer.visible, "Settings button opens viewer")
	check(not game.ui.is_processing_input(), "Underlying Settings cannot intercept viewer mouse clicks")
	var click := InputEventMouseButton.new()
	click.position = Vector2(640, 350)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	check(game.settings_open and game.ui.has_open_panel(), "Viewer click does not dismiss underlying Settings")
	game.animation_viewer.close()
	check(game.settings_open and game.ui.has_open_panel() and game.ui.is_processing_input(), "Settings remains open and paused on return with input restored")
	game.ui.close_panel()
	game._enter_design()
	var draft: Dictionary = game.design.draft.snapshot()
	game.design.choose("building", "bedroom")
	game.design.press(Vector2(-400, 400))
	game._open_animation_viewer()
	check(not game.design.is_drawing(), "Opening viewer cancels unfinished construction gesture without committing it")
	key.keycode = KEY_R
	game._input(key)
	game._process(10.0)
	game.animation_viewer.close()
	check(game.design.draft.snapshot() == draft, "Animation review preserves an open construction draft")
	check(Save.exists() == existed and (not existed or FileAccess.get_file_as_bytes(Save.PATH) == save_bytes),
		"Viewer never writes or replaces the player's saved run")
	game.queue_free()
	await process_frame
	print("Animation viewer scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
