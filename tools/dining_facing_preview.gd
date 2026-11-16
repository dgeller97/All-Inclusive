extends "res://tests/seated_visual_test.gd"
## CPU reproduction uses Godot's position-preserving texture flip semantics.
class PreviousProbe extends SeatProbe:
	func _actor_region(destination: Rect2, source: Rect2) -> void:
		if destination.size.x < 0:
			destination.position.x += absf(destination.size.x)
		super(destination, source)

func _run() -> void:
	var sim := Sim.new()
	var family := _first_meal(sim)
	root.add_child(map)
	map.free()
	map = PreviousProbe.new()
	root.add_child(map)
	map.atlas = map.people.get_image()
	var before := _stay(sim, family, 0.76)
	var center: Vector2 = map.dining_tables[family.table_id].table_center
	map.free()
	map = SeatProbe.new()
	root.add_child(map)
	map.atlas = map.people.get_image()
	var after := _stay(sim, family, 0.76)
	var sheet := _paper(Vector2i(142, 64))
	var crop := Rect2i(Vector2i(center) - Vector2i(24, 24), Vector2i(64, 46))
	_caption(sheet, Vector2i(4, 12), "Previous build")
	_caption(sheet, Vector2i(76, 12), "Corrected")
	_place(sheet, before, crop, Vector2i(4, 17))
	_place(sheet, after, crop, Vector2i(76, 17))
	_save(sheet, "res://docs/screenshots/diner-facing-fix.png", 6)
	scene_art.free()
	map.queue_free()
	await process_frame
	quit(1 if failures else 0)
