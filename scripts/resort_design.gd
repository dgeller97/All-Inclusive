extends Node2D

const Layout = preload("res://scripts/layout_model.gd")
const Renderer = preload("res://scripts/building_renderer.gd")
const GRID_INK := Color(0.20, 0.25, 0.27, 0.27)
const VALID_INK := Color("#b5edb0")
const INVALID_INK := Color("#ff9682")
const SELECTED_INK := Color("#ffd38a")

var draft: Layout
var tool := "select"
var building := "bedroom"
var asset := "bed"
var asset_rotation := 0
var pointer := Vector2.INF
var drag_origin := Vector2.INF
var selection := {}
var feedback := ""
var feedback_valid: Variant = null
var ghost := Rect2()
var ghost_check := {}
var furniture: Texture2D


func _ready() -> void:
	furniture = Renderer.FURNITURE
	hide()


func enter(source: Layout) -> void:
	draft = source.duplicate_layout()
	tool = "select"
	asset_rotation = 0
	selection = {}
	feedback = ""
	feedback_valid = null
	pointer = Vector2.INF
	drag_origin = Vector2.INF
	_update_ghost()
	show()


func leave() -> void:
	draft = null
	hide()


func choose(action: String, value: Variant) -> void:
	drag_origin = Vector2.INF
	feedback = ""
	feedback_valid = null
	match action:
		"tool":
			tool = "select"
		"building":
			tool = "building"
			building = value
		"asset":
			tool = "asset"
			if asset != value:
				asset_rotation = 0
			asset = value
		"bulldoze":
			tool = "bulldoze"
	_update_ghost()


func rotate_asset() -> void:
	if tool == "asset":
		asset_rotation = (asset_rotation + 1) % 4
		feedback = ""
		feedback_valid = null
		_update_ghost()


func cancel_operation() -> void:
	if drag_origin.is_finite():
		drag_origin = Vector2.INF
	else:
		tool = "select"
		selection = {}
	feedback = ""
	feedback_valid = null
	_update_ghost()


func move_pointer(point: Vector2) -> void:
	if point == pointer:
		return
	pointer = point
	if point.is_finite():
		feedback = ""
		feedback_valid = null
	_update_ghost()


func press(point: Vector2) -> bool:
	move_pointer(point)
	match tool:
		"building":
			drag_origin = _cell_origin(point)
			_update_ghost()
		"asset":
			if not ghost_check.ok:
				_report(ghost_check)
				return false
			var target := draft.building_at(point)
			var result := draft.add_asset(asset, target.id, _asset_cell(target), asset_rotation)
			_report(result, "%s placed." % Layout.ASSET_CATALOG[asset].label)
			_update_ghost()
			return result.ok
		_:
			var furnishing := draft.asset_at(point)
			var target := furnishing if not furnishing.is_empty() else draft.building_at(point)
			if tool == "select":
				selection = target
				queue_redraw()
			elif target.is_empty():
				feedback = "Click a furnishing or a building to bulldoze it."
				feedback_valid = false
			else:
				var object_name := _object_name(target)
				var result := draft.remove_asset(target.id) if target.has("cell") else draft.remove_building(target.id)
				selection = {}
				_report(result, "%s removed." % object_name)
				queue_redraw()
				return result.ok
	return false


func release(point: Vector2) -> bool:
	if not drag_origin.is_finite():
		return false
	move_pointer(point)
	var result := {}
	if point.is_finite():
		result = draft.add_building(building, ghost)
		_report(result, "%s built." % Layout.BUILDING_CATALOG[building].label)
	drag_origin = Vector2.INF
	_update_ghost()
	return result.get("ok", false)


func selection_text() -> String:
	if selection.is_empty():
		return ""
	var item := _object_name(selection)
	if selection.has("cell"):
		return "%s · %d°" % [item, selection.rotation * 90]
	var bounds := draft.building_rect(selection)
	return "%s · %d × %d tiles" % [item, bounds.size.x / Layout.GRID, bounds.size.y / Layout.GRID]


func placement_feedback() -> Dictionary:
	if not feedback.is_empty():
		return {"text": feedback, "valid": feedback_valid}
	if not ghost_check.is_empty():
		if not ghost_check.ok:
			return {"text": ghost_check.reason, "valid": false}
		return {"text": "Release to build." if tool == "building" else "Click to place.", "valid": true}
	return {"text": feedback, "valid": feedback_valid}


func _report(result: Dictionary, success: String = "") -> void:
	feedback = success if result.ok else result.reason
	feedback_valid = result.ok


func _object_name(entity: Dictionary) -> String:
	var catalog := Layout.ASSET_CATALOG if entity.has("cell") else Layout.BUILDING_CATALOG
	return catalog[entity.kind].label


func _cell_origin(point: Vector2) -> Vector2:
	return (point / Layout.GRID).floor() * Layout.GRID


func _asset_cell(target: Dictionary) -> Vector2i:
	return Vector2i((_cell_origin(pointer) - draft.building_rect(target).position) / Layout.GRID)


func _update_ghost() -> void:
	ghost_check.clear()
	ghost = Rect2()
	queue_redraw()
	if not pointer.is_finite() or not draft:
		return
	var cell := _cell_origin(pointer)
	if tool == "building":
		if drag_origin.is_finite():
			var top_left := cell.min(drag_origin)
			var bottom_right := cell.max(drag_origin) + Vector2.ONE * Layout.GRID
			ghost = Rect2(top_left, bottom_right - top_left)
			ghost_check = draft.validate_building(building, ghost)
		else:
			ghost = Rect2(cell, Vector2.ONE * Layout.GRID)
	elif tool == "asset":
		var target := draft.building_at(pointer)
		var size := Vector2(draft.asset_size(asset, asset_rotation)) * Layout.GRID
		ghost = Rect2(cell, size)
		ghost_check = draft.validate_asset(asset, -1 if target.is_empty() else target.id,
			Vector2i.ZERO if target.is_empty() else _asset_cell(target), asset_rotation)


func _draw() -> void:
	if not draft:
		return
	var bounds := Layout.WORLD_BOUNDS
	for x in range(int(bounds.position.x), int(bounds.end.x), Layout.GRID):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), GRID_INK)
	for y in range(int(bounds.position.y), int(bounds.end.y), Layout.GRID):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), GRID_INK)
	if not selection.is_empty():
		var rect := draft.asset_rect(selection) if selection.has("cell") else draft.building_rect(selection)
		draw_rect(rect, SELECTED_INK, false, 2.0)
	if ghost.has_area():
		var ink := VALID_INK if ghost_check.get("ok", true) else INVALID_INK
		draw_rect(ghost, Color(ink, 0.26))
		if tool == "asset" and furniture:
			var atlas_origin := Vector2(asset_rotation, Renderer.FURNITURE_ROWS[asset]) * Renderer.ATLAS_CELL
			draw_texture_rect_region(furniture, ghost, Rect2(atlas_origin, ghost.size), Color(1, 1, 1, 0.72))
		draw_rect(ghost, ink, false, 1.0)
