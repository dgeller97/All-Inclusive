extends SceneTree

## Headless geometry audit; does not capture or interact with the desktop.
const ResortUI = preload("res://scripts/resort_ui.gd")
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var ui := ResortUI.new()
	host.add_child(ui)
	var sim := Sim.new()
	ui.refresh({"simulation": sim, "paused": false, "speed": 1, "muted": false, "can_load": false})
	await process_frame
	_audit(ui, Rect2(Vector2.ZERO, host.size), "Initial HUD")
	for id in ResortUI.PANELS:
		ui.open_panel(id)
		await process_frame
		_audit(ui, Rect2(Vector2.ZERO, host.size), "Day1 " + id)
	ui.close_panel()
	for second in range(720):
		sim.tick()
	ui.refresh({"simulation": sim, "paused": true, "speed": 4, "muted": true, "can_load": true})
	for id in ResortUI.PANELS:
		ui.open_panel(id)
		await process_frame
		_audit(ui, Rect2(Vector2.ZERO, host.size), "Day3 " + id)
	print("UI layout audit: %d geometry checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		push_error(failure)
	host.queue_free()
	await process_frame
	quit(1 if not failures.is_empty() else 0)


func _audit(node: Node, viewport_rect: Rect2, label: String) -> void:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.size.x > 0 and child.size.y > 0:
			checks += 1
			var bounds: Rect2 = child.get_global_rect()
			if not viewport_rect.grow(1.0).encloses(bounds):
				failures.append("%s: %s outside viewport: %s" % [label, child.get_path(), bounds])
			if child.get_parent() is Panel or child.get_parent() is Button:
				checks += 1
				var parent_rect: Rect2 = child.get_parent().get_global_rect()
				if not parent_rect.grow(1.0).encloses(bounds):
					failures.append("%s: %s extends outside its panel/button: %s" % [label, child.get_path(), bounds])
		_audit(child, viewport_rect, label)
