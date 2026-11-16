extends SceneTree
const Scene = preload("res://scenes/resort.tscn")
const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/").contains("/.tools/r13-scene"):
		printerr("Use isolated APPDATA under .tools/r13-scene")
		quit(2)
		return
	var game := Scene.instantiate()
	root.add_child(game)
	game.smoke_test_requested = true
	game.set_process(false)
	await process_frame
	var choices: Array[Node] = game.dialog.find_children("*", "Button", true, false)
	var clicked := false
	for button in choices:
		if button.text == "Developer showcase":
			button.pressed.emit()
			clicked = true
			break
	check(clicked and game.started and game.simulation.mode == "developer", "Welcome button starts Developer showcase")
	check(game.menu_mode.is_empty() and not game.paused, "Showcase starts running")
	var layout: Layout = game.simulation.layout
	for kind: String in Layout.BUILDING_CATALOG:
		check(layout.buildings.any(func(item: Dictionary) -> bool: return item.kind == kind), "Showcase includes building " + kind)
	for kind: String in Layout.ASSET_CATALOG:
		check(layout.assets.any(func(item: Dictionary) -> bool: return item.kind == kind), "Showcase includes furnishing " + kind)
	for kind: String in Layout.Landscape.PROP_CATALOG:
		check(layout.landscape.props.any(func(item: Dictionary) -> bool: return item.kind == kind), "Showcase includes outdoor asset " + kind)
	check(layout.readiness().ok and game.simulation.terrace, "Fully furnished showcase is operational")
	check(game.map.base_art.get_size() == Layout.WORLD_BOUNDS.size, "Expanded production terrain covers the world")
	check(game.camera.world_bounds == Layout.WORLD_BOUNDS and game.camera.home_zoom < 1.7, "Developer opens with expanded overview")
	var home_zoom: float = game.camera.zoom_level
	game.camera.zoom_in()
	game.camera.pan_by(Vector2(180, -90))
	check(game.camera.zoom_level > home_zoom, "Showcase can zoom closer to inspect guests")
	game.camera.home()
	check(is_equal_approx(game.camera.zoom_level, home_zoom), "Home returns to showcase overview")
	var observed := {}
	for tick in range(3 * Sim.DAY_LENGTH):
		game._process(1.0)
		for family: Dictionary in game.simulation.families:
			if family.phase == "leisure":
				observed[family.leisure_kind] = true
	for kind: String in Sim.LEISURE_DURATIONS:
		check(observed.has(kind), "Controller guests actually use " + kind)
	check(game.simulation.stopped and game.simulation.reviews.size() == 12, "Showcase completes three normal guest days")
	game._new_run("developer")
	var draft: Layout = game.simulation.layout.duplicate_layout()
	var club: Dictionary = draft.amenities("nightclub")[0]
	check(draft.remove_prop(club.id).ok, "Preplaced nightclub can be bulldozed")
	var cash: int = game.simulation.cash
	check(game.simulation.apply_construction(draft).ok and game.simulation.cash == cash, "Developer edits commit free")
	game._save_run()
	var saved: Dictionary = game.simulation.layout.snapshot()
	game._new_run("regular")
	check(game.simulation.layout.amenities("nightclub").is_empty() and not game.simulation.terrace, "Regular resort retains starter progression")
	game._load_run()
	check(game.simulation.mode == "developer" and game.paused, "Saved Developer run reloads paused")
	var restored: Dictionary = game.simulation.layout.snapshot()
	check(restored.buildings == saved.buildings and restored.assets == saved.assets and restored.landscape == saved.landscape,
		"Reload preserves edited showcase exactly, without reinjecting assets")
	var old := Sim.new()
	old.mode = "developer"
	game._set_simulation(old)
	game._save_run()
	game._new_run("developer")
	game._load_run()
	check(game.simulation.layout.amenities("nightclub").is_empty(), "Old Developer saves remain user layouts on load")
	game.queue_free()
	await process_frame
	print("Developer scene: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
