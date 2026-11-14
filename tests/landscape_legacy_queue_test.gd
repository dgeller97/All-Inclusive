extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Layout = preload("res://scripts/layout_model.gd")
const SaveSlot = preload("res://scripts/save_slot.gd")
const Scene = preload("res://scenes/resort.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _old_layout(model: Layout) -> Dictionary:
	var data := model.snapshot()
	data.erase("landscape")
	data.version = 1
	return data


func _run() -> void:
	if not ProjectSettings.globalize_path(SaveSlot.PATH).replace("\\", "/").contains("/.tools/r4-legacy-queue"):
		push_error("Use isolated APPDATA under .tools/r4-legacy-queue.")
		quit(2)
		return
	var sim := Sim.new()
	sim.cash = 1000
	var custom: Layout = sim.layout.duplicate_layout()
	var occupied_tree_site := Rect2(304, 56, 48, 48)
	for prop in custom.landscape.props.duplicate():
		if occupied_tree_site.intersects(custom.prop_rect(prop)):
			custom.remove_prop(prop.id)
	var room := custom.add_building("bedroom", occupied_tree_site)
	custom.add_asset("bed", room.id, Vector2i(1, 1))
	check(sim.apply_construction(custom).ok and sim.cash == 800, "Create old paid custom bedroom over former baked tree")
	for second in range(20):
		sim.tick()
	var relocated: Layout = sim.layout.duplicate_layout()
	relocated.remove_building(room.id)
	var replacement := relocated.add_building("bedroom", Rect2(304, 0, 48, 48))
	relocated.add_asset("bed", replacement.id, Vector2i(1, 1))
	check(sim.apply_construction(relocated).ok and sim.pending_reserve == 100 and sim.cash == 700, "Old pending relocation reserves exact net $100")
	var old := sim.snapshot()
	old.layout = _old_layout(sim.layout)
	old.pending_layout = _old_layout(sim.pending_layout)
	var separate_active := Layout.new()
	var separate_pending := Layout.new()
	separate_active.restore(old.layout)
	separate_pending.restore(old.pending_layout)
	check(separate_pending.quote_diff(separate_active).net == 115, "Fixture reproduces $15 extra palm charge when old layouts migrate independently")
	var loaded := Sim.new()
	var restored := loaded.restore(old, false, false)
	check(restored, "R3 queued relocation migrates without charging for newly revealed default palm")
	if restored:
		check(loaded.pending_reserve == 100 and loaded.cash == 700 and loaded.pending_layout.quote_diff(loaded.layout).net == 100, "Migrated pending quote and reservation remain unchanged")
		while loaded.day == 1:
			loaded.tick()
		check(loaded.cash == 1060 and loaded.pending_reserve == 0, "Migrated queued relocation applies once with original finances")
	# A net-refund plan can silently pass hold checks while losing $15 of refund.
	var deletion: Layout = sim.layout.duplicate_layout()
	deletion.remove_building(room.id)
	var refund_state := old.duplicate(true)
	refund_state.pending_layout = _old_layout(deletion)
	refund_state.pending_reserve = 0
	refund_state.cash = 800
	var refund_sim := Sim.new()
	var refund_restored := refund_sim.restore(refund_state, false, false)
	check(refund_restored, "R3 queued demolition migrates")
	if refund_restored:
		check(refund_sim.pending_layout.quote_diff(refund_sim.layout).net == -100, "Revealed original scenery cannot reduce a queued demolition refund")
		while refund_sim.day == 1:
			refund_sim.tick()
		check(refund_sim.cash == 1260, "Queued demolition pays full original $100 refund at day boundary")
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.smoke_test_requested = true
	check(SaveSlot.write({"version": 3, "simulation": old, "draft": _old_layout(deletion), "speed": 1, "elapsed": 0.0, "camera": game.camera.snapshot()}), "Write synthetic R3 active/pending/draft checkpoint")
	game._load_run()
	check(game.started and game.saved_draft != null, "Controller loads R3 pending layout and separate saved draft")
	if game.saved_draft:
		check(game.saved_draft.quote_diff(game.simulation.layout).net == -100, "Saved draft does not charge for reintroduced default scenery")
	game.queue_free()
	await process_frame
	print("Landscape legacy queue: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
