extends SceneTree
## Verify framing through the actual runtime pose fields, without raster emulation.

const Viewer := preload("res://scripts/animation_viewer.gd")
const Preview := preload("res://scripts/animation_preview.gd")
const Map := preload("res://scripts/resort_map.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var inspector := Viewer.new()
	root.add_child(inspector)
	inspector.show_viewer()
	inspector.set_playing(false)
	inspector.set_full_occupancy(true)
	for clip: String in Preview.catalog():
		_check(inspector.select_clip(clip), "%s can open" % clip)
		await process_frame
		for phase in Preview.phases(clip):
			_check(inspector.select_phase(phase.id), "%s offers %s" % [clip, phase.id])
			for percentage in [0.05, 0.48, 0.94]:
				inspector.seek(inspector.duration * percentage)
				_check(_guests_framed(inspector), "%s %s %.2f fits its guest bodies" % [clip, phase.id, percentage])
			var later := inspector.playhead
			var forward := _positions(inspector)
			inspector.seek(0.0)
			inspector.seek(later)
			_check(forward == _positions(inspector), "%s %s seek is independent of playback history" % [clip, phase.id])
	inspector.select_clip("walking")
	inspector.set_full_occupancy(false)
	await process_frame
	inspector.seek(1.3)
	_check(inspector.panel_maps.all(func(map: Map) -> bool: return map.scale.x >= 2.0),
		"Walking Fit tracks one family at readable scale across all angles")
	var time := inspector.playhead
	inspector.set_view_zoom(4.0)
	_check(is_equal_approx(time, inspector.playhead) and inspector.panel_maps.all(func(map: Map) -> bool: return map.scale.x == 4.0),
		"Fixed 4× zoom retains playback position and matches every panel")
	inspector.seek(0.021)
	inspector.step_frame(1)
	_check(is_equal_approx(inspector.playhead, Viewer.FRAME_SECONDS), "Step forward reaches the next frame boundary, even after an arbitrary seek")
	inspector.step_frame(-1)
	_check(is_zero_approx(inspector.playhead), "Step back reaches frame zero")
	inspector.close()
	inspector.queue_free()
	await process_frame
	print("Animation viewer fixtures: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)


func _guests_framed(viewer: Viewer) -> bool:
	for index in viewer.panel_maps.size():
		var map := viewer.panel_maps[index]
		var bounds := Rect2(Vector2.ZERO, Vector2(viewer.panel_viewports[index].size)).grow(-1)
		for family: Dictionary in map.simulation.families:
			var pose := map._pose(family)
			for child: bool in [false, true]:
				if not child and pose.get("child_only", false):
					continue
				var sprite := map._guest_sprite(family, pose, child)
				var foot: Vector2 = sprite.point
				if not bounds.has_point(map.transform * foot) or not bounds.has_point(map.transform * (foot - Vector2(0, 20))):
					return false
	return not viewer.panel_maps.is_empty()


func _positions(viewer: Viewer) -> PackedVector2Array:
	var points := PackedVector2Array()
	for map: Map in viewer.panel_maps:
		for family: Dictionary in map.simulation.families:
			var pose := map._pose(family)
			points.append(map._guest_sprite(family, pose, false).point)
			points.append(map._guest_sprite(family, pose, true).point)
	return points


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)
