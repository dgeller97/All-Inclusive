extends Node2D

const Layout = preload("res://scripts/layout_model.gd")
const Renderer = preload("res://scripts/building_renderer.gd")
const Landscape = preload("res://scripts/landscape_model.gd")
const LandscapeRenderer = preload("res://scripts/landscape_renderer.gd")
const GRID_INK := Color(0.20, 0.25, 0.27, 0.27)
const VALID_INK := Color("#b5edb0")
const INVALID_INK := Color("#ff9682")
const SELECTED_INK := Color("#ffd38a")

var draft: Layout
var tool := "select"
var category := "buildings"
var landscape_group := "terrain"
var building := "bedroom"
var asset := "bed"
var asset_rotation := 0
var brush_size := 1
var brush_value := "grass"
var prop_kind := "palm"
var pointer := Vector2.INF
var drag_origin := Vector2.INF
var stroke_active := false
var stroke_cells := {}
var stroke_tail := Vector2i.ZERO
var selection := {}
var settings_building_id := -1
var inspect_ceiling := false
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
	category = "buildings"
	landscape_group = "terrain"
	asset_rotation = 0
	brush_size = 1
	brush_value = "grass"
	selection = {}
	close_building_settings()
	feedback = ""
	feedback_valid = null
	pointer = Vector2.INF
	_reset_drag()
	_update_ghost()
	show()


func leave() -> void:
	_reset_drag()
	close_building_settings()
	draft = null
	hide()


func choose(action: String, value: Variant) -> void:
	_reset_drag()
	close_building_settings()
	feedback = ""
	feedback_valid = null
	match action:
		"category":
			if value != category:
				category = value
				if tool not in ["select", "bulldoze", "move"]:
					tool = "select"
				if category == "landscape":
					landscape_group = "terrain"
					if tool == "select" and selection.is_empty():
						brush_value = "grass"
						tool = "terrain"
		"landscape_group":
			landscape_group = value
			selection = {}
			match landscape_group:
				"terrain":
					tool = "terrain"
					brush_value = "grass"
				"path":
					tool = "path"
					brush_value = "stone"
				"scenery":
					tool = "select"
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
		"terrain", "path", "restore":
			if action == "terrain" and not Landscape.TERRAIN_CATALOG.has(value):
				return
			tool = action
			brush_value = value
		"brush_size":
			brush_size = value
		"prop":
			tool = "prop"
			if prop_kind != value:
				asset_rotation = 0
			prop_kind = value
		"move":
			if can_move():
				tool = "move"
				asset_rotation = selection.rotation
	_update_ghost()


func rotate_asset() -> void:
	if can_rotate():
		asset_rotation = (asset_rotation + 1) % 4
		feedback = ""
		feedback_valid = null
		_update_ghost()


func cancel_operation() -> void:
	close_building_settings()
	if is_drawing():
		_reset_drag()
	else:
		tool = "select"
		selection = {}
	feedback = ""
	feedback_valid = null
	_update_ghost()


func is_drawing() -> bool:
	return stroke_active or drag_origin.is_finite()


func can_rotate() -> bool:
	return tool in ["asset", "prop", "move"]


func can_move() -> bool:
	return _prop_selected()


func selected_tool() -> String:
	match tool:
		"building": return building
		"asset": return asset
		"terrain": return brush_value
		"path": return brush_value if not brush_value.is_empty() else "erase"
		"prop": return "scenery_bench" if prop_kind == "bench" else prop_kind
	return tool


func move_pointer(point: Vector2, extend_stroke: bool = false) -> void:
	if point == pointer:
		return
	pointer = point
	if point.is_finite():
		feedback = ""
		feedback_valid = null
	if stroke_active and extend_stroke:
		if Layout.WORLD_BOUNDS.has_point(point):
			_extend_stroke(_brush_cell(point))
		else:
			_reset_drag()
			feedback = "Stroke canceled outside the map."
			feedback_valid = false
	_update_ghost()


func press(point: Vector2) -> bool:
	move_pointer(point)
	match tool:
		"building":
			drag_origin = _cell_origin(point)
			_update_ghost()
		"terrain", "path", "restore":
			if not Layout.WORLD_BOUNDS.has_point(point):
				return false
			stroke_active = true
			stroke_tail = _brush_cell(point)
			_stamp_brush(stroke_tail, stroke_cells)
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
		"prop", "move":
			if not ghost_check.get("ok", false):
				if not ghost_check.is_empty():
					_report(ghost_check)
				return false
			var cell := _brush_cell(point)
			var result: Dictionary
			if tool == "move":
				result = draft.move_prop(selection.id, cell, asset_rotation)
				_report(result, "%s moved." % _object_name(selection))
				if result.ok:
					selection = draft.prop_at(Vector2(cell) * Layout.GRID + Vector2(4, 4))
					tool = "select"
			else:
				result = draft.add_prop(prop_kind, cell, asset_rotation)
				_report(result, "%s placed." % Landscape.PROP_CATALOG[prop_kind].label)
			_update_ghost()
			return result.ok
		"select", "bulldoze":
			return _edit_object_at(point)
	return false


func release(point: Vector2) -> bool:
	if stroke_active:
		move_pointer(point, true)
		if not stroke_active:
			return false
		var result := draft.paint_landscape_stroke(tool, brush_value, stroke_cells.keys())
		var changed: int = result.get("changed", 0)
		var message := "These tiles already have that finish."
		if changed > 0:
			message = "%d tiles updated." % changed if changed > 1 else "1 tile updated."
		_report(result, message)
		_reset_drag()
		_update_ghost()
		return result.ok and changed > 0
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


func selected_building() -> Dictionary:
	if tool == "select" and selection.has("rect"):
		return selection
	return {}


func open_building_settings() -> void:
	settings_building_id = selected_building().get("id", -1)


func close_building_settings() -> void:
	settings_building_id = -1
	inspect_ceiling = false


func toggle_ceiling_inspection() -> void:
	if settings_building_id >= 0 and selected_building().get("kind") != "pool":
		inspect_ceiling = not inspect_ceiling


func placement_feedback() -> Dictionary:
	if not feedback.is_empty():
		return {"text": feedback, "valid": feedback_valid}
	if not ghost_check.is_empty():
		if not ghost_check.ok:
			return {"text": ghost_check.reason, "valid": false}
		if tool in ["terrain", "path", "restore"]:
			return {"text": "Release to finish the stroke." if stroke_active else "Click or drag to paint.", "valid": true}
		if tool == "move":
			return {"text": "Click to move.", "valid": true}
		return {"text": "Release to build." if tool == "building" else "Click to place.", "valid": true}
	return {"text": feedback, "valid": feedback_valid}


func _report(result: Dictionary, success: String = "") -> void:
	feedback = success if result.ok else result.reason
	feedback_valid = result.ok


func _object_name(entity: Dictionary) -> String:
	if entity.has("offset"):
		return Landscape.PROP_CATALOG[entity.kind].label
	if entity.has("cell"):
		return Layout.ASSET_CATALOG[entity.kind].label
	return Layout.building_name(entity)


func _cell_origin(point: Vector2) -> Vector2:
	return (point / Layout.GRID).floor() * Layout.GRID


func _brush_cell(point: Vector2) -> Vector2i:
	return Vector2i((point / Layout.GRID).floor())


func _reset_drag() -> void:
	drag_origin = Vector2.INF
	stroke_active = false
	stroke_cells.clear()


func _stamp_brush(cell: Vector2i, cells: Dictionary) -> void:
	var radius := brush_size >> 1
	var brush := Rect2i(cell - Vector2i.ONE * radius, Vector2i.ONE * brush_size)
	brush = brush.intersection(Rect2i(_brush_cell(Layout.WORLD_BOUNDS.position), Vector2i(Layout.WORLD_BOUNDS.size / Layout.GRID)))
	for y in range(brush.position.y, brush.end.y):
		for x in range(brush.position.x, brush.end.x):
			cells[Vector2i(x, y)] = true


func _extend_stroke(cell: Vector2i) -> void:
	# Include neighboring cells at corners so a thin diagonal path is connected.
	var delta := (cell - stroke_tail).abs()
	var direction := (cell - stroke_tail).sign()
	var steps := Vector2i.ZERO
	while steps != delta:
		if (1 + 2 * steps.x) * delta.y <= (1 + 2 * steps.y) * delta.x:
			stroke_tail.x += direction.x
			steps.x += 1
		else:
			stroke_tail.y += direction.y
			steps.y += 1
		_stamp_brush(stroke_tail, stroke_cells)


func _prop_selected() -> bool:
	return selection.has("offset")


func _edit_object_at(point: Vector2) -> bool:
	var target := draft.asset_at(point)
	if target.is_empty():
		# A building's footprint takes priority over overhanging scenery.
		target = draft.building_at(point)
	if target.is_empty():
		target = draft.prop_at(point)
	if tool == "select":
		if not target.has("rect") or target.id != settings_building_id:
			close_building_settings()
		selection = target
		queue_redraw()
		return false
	if target.is_empty():
		feedback = "Click a building, furnishing, or outdoor object to remove it."
		feedback_valid = false
		return false
	var result: Dictionary
	if target.has("offset"):
		result = draft.remove_prop(target.id)
	elif target.has("cell"):
		result = draft.remove_asset(target.id)
	else:
		result = draft.remove_building(target.id)
	selection = {}
	_report(result, "%s removed." % _object_name(target))
	queue_redraw()
	return result.ok


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
	elif tool in ["terrain", "path", "restore"]:
		if not Layout.WORLD_BOUNDS.has_point(pointer):
			return
		var center := _brush_cell(pointer)
		var cells := stroke_cells
		if not stroke_active:
			cells = {}
			_stamp_brush(center, cells)
		var size := Vector2.ONE * brush_size * Layout.GRID
		ghost = Rect2(Vector2(center - Vector2i.ONE * (brush_size >> 1)) * Layout.GRID, size)
		ghost = ghost.intersection(Layout.WORLD_BOUNDS)
		ghost_check = draft.validate_landscape_stroke(tool, brush_value, cells.keys())
	elif tool in ["prop", "move"]:
		var prop := _prop_ghost()
		ghost = draft.prop_rect(prop)
		ghost_check = draft.validate_prop(prop.kind, _brush_cell(pointer), prop.rotation,
			prop.get("variant", 0), prop.get("id", -1))


func _prop_ghost() -> Dictionary:
	var cell := _brush_cell(pointer)
	var prop := selection.duplicate() if tool == "move" else {"kind": prop_kind, "offset": [4, 4]}
	prop.cell = [cell.x, cell.y]
	prop.rotation = asset_rotation
	return prop


func _draw() -> void:
	if not draft:
		return
	var bounds := Layout.WORLD_BOUNDS
	for x in range(int(bounds.position.x), int(bounds.end.x), Layout.GRID):
		draw_line(Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), GRID_INK)
	for y in range(int(bounds.position.y), int(bounds.end.y), Layout.GRID):
		draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), GRID_INK)
	if not selection.is_empty():
		var rect: Rect2
		if _prop_selected():
			rect = draft.prop_visual_rect(selection)
		else:
			rect = draft.asset_rect(selection) if selection.has("cell") else draft.building_rect(selection)
		draw_rect(rect, SELECTED_INK, false, 2.0)
	if ghost.has_area():
		var ink := VALID_INK if ghost_check.get("ok", true) else INVALID_INK
		for cell in stroke_cells:
			draw_rect(Rect2(Vector2(cell) * Layout.GRID, Vector2.ONE * Layout.GRID), Color(ink, 0.40))
		draw_rect(ghost, Color(ink, 0.26))
		if tool == "asset" and furniture:
			var atlas_origin := Vector2(asset_rotation, Renderer.FURNITURE_ROWS[asset]) * Renderer.ATLAS_CELL
			draw_texture_rect_region(furniture, ghost, Rect2(atlas_origin, ghost.size), Color(1, 1, 1, 0.72))
		elif tool in ["prop", "move"]:
			LandscapeRenderer.draw_prop(self, _prop_ghost(), Color(1, 1, 1, 0.72))
		draw_rect(ghost, ink, false, 1.0)
