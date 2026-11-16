extends SceneTree
## Godot flips negative draw_texture_rect_region sizes in place, keeping position.
const Probe := preload("res://tests/seated_proportions_test.gd").Probe
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := Probe.new()
	root.add_child(map)
	for row in [0, 1, 2, 3, 4]:
		for action in ["standing", "walking", "seated", "resting", "swimming"]:
			var actor := {"point": Vector2(100, 100), "row": row,
				"frame": 1 if action == "walking" else 0, "facing": true,
				"swim": action == "swimming", "meal": "seated" if action == "seated" else "",
				"leisure": "stage" if action == "resting" else "",
				"plate": Vector2(110, 92), "meal_age": 0.7, "leisure_age": 0.5, "leisure_slot": 0}
			var right: Dictionary = map.draw_guest(actor)[0]
			actor.facing = false
			var left: Dictionary = map.draw_guest(actor)[0]
			# RenderingServer retains destination.position when size.x is negative.
			check(left.destination.position == right.destination.position,
				"%s row %d keeps body over same chair/feet when facing left" % [action, row])
			check(left.destination.size.abs() == right.destination.size.abs(), "Facing preserves dimensions")
			check(left.destination.size.x < 0 and right.destination.size.x > 0, "Facing flips texture")
	map.queue_free()
	await process_frame
	print("Actor facing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
