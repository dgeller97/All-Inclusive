extends SceneTree
## Render-canvas boundary regression: world Z ordering cannot cover interface text.
const Scene := preload("res://scenes/resort.tscn")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var game := Scene.instantiate()
	viewport.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	_check(game.menu_mode == "welcome" and game.overlay.visible, "Reproduce welcome over the live labeled resort")
	var plaque: CanvasItem = game.map.renderer._plaque_layer
	_check(plaque.z_index > game.overlay.z_index, "Exercise world plaques above interface local Z, as in reported regression")
	_check(plaque.get_canvas() == game.map.get_canvas(), "Plaques retain the world canvas")
	for size in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		viewport.size = size
		await process_frame
		await process_frame
		_check(game.overlay.size == Vector2(size), "Modal shade fills resized viewport")
		_check(Rect2(Vector2.ZERO, Vector2(size)).encloses(game.dialog.get_global_rect()), "Welcome stays within viewport")
		for surface in [game.ui, game.design_ui, game.overlay]:
			_check_above_world(surface, plaque)
		for label: Label in game.dialog.find_children("*", "Label", true, false):
			if not label.text.contains("Developer showcase:"):
				continue
			_check(label.size.y >= label.get_minimum_size().y, "Welcome explanation fits actual font minimum height")
			for button: Button in game.dialog.find_children("*", "Button", true, false):
				_check(not label.get_global_rect().intersects(button.get_global_rect()), "Welcome explanation does not overlap " + button.text)
	game._open_animation_viewer()
	await process_frame
	_check_above_world(game.animation_viewer, plaque)
	_check(game.animation_viewer.get_index() > game.overlay.get_index(), "Viewer covers welcome on the same interface canvas")
	for preview in game.animation_viewer.panel_maps:
		_check(preview.renderer._plaque_layer.get_canvas() != game.overlay.get_canvas(), "Viewer map labels stay confined to their own viewport")
	game.animation_viewer.close()
	game._new_run("regular")
	for panel_id in game.ui.PANELS:
		game.ui.open_panel(panel_id)
		await process_frame
		_check_above_world(game.ui._popover, plaque)
	game.ui.close_panel()
	game._enter_design()
	await process_frame
	_check_above_world(game.design_ui, plaque)
	_check(game.design_ui.visible, "Construction UI still opens")
	viewport.queue_free()
	await process_frame
	print("World/UI canvas isolation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check_above_world(surface: CanvasItem, world: CanvasItem) -> void:
	var layer := surface.get_canvas_layer_node()
	_check(surface.get_canvas() != world.get_canvas(), "Interface and world use separate render canvases")
	_check(layer != null and layer.layer > 0 and not layer.follow_viewport_enabled and layer.transform == Transform2D.IDENTITY,
		"Interface is above default world canvas without following camera transforms")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
