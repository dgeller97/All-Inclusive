extends Node2D

enum Condition { CALM, CAUTION, CLOSED }

const SHORE_PROFILE := preload("res://assets/art/resort_shore.png")
const Landscape = preload("res://scripts/landscape_model.gd")
const LandscapeRenderer = preload("res://scripts/landscape_renderer.gd")
const MAP_LEFT := -160
const MAP_TOP := -120
const MAP_RIGHT := 800
const SURF_PERIOD := 112.0
const CONDITION_NAMES := ["Calm", "Caution", "Closed"]
const CONDITION_COLORS := [Color("#78c897"), Color("#ffce70"), Color("#f66b65")]

var _time := 0.0
var _shore := PackedInt32Array()
var _landscape: Landscape
var _landscape_revision := -1
var _disturbed_rows := PackedByteArray()
var _painted_water: Array[Vector2i] = []
var _flags: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var profile := SHORE_PROFILE.get_image()
	_shore.resize(profile.get_height())
	_disturbed_rows.resize(profile.get_height())
	for row in range(_shore.size()):
		var encoded := profile.get_pixel(0, row)
		_shore[row] = MAP_LEFT + encoded.r8 + (encoded.g8 << 8)


func set_landscape(landscape: Landscape) -> void:
	if _landscape == landscape and _landscape_revision == landscape.revision:
		return
	_landscape = landscape
	_landscape_revision = landscape.revision
	if _disturbed_rows.is_empty():
		_disturbed_rows.resize(int(Landscape.WORLD_BOUNDS.size.y))
	_disturbed_rows.fill(0)
	_painted_water.clear()
	for cell: Vector2i in landscape.terrain_overrides:
		if not landscape.ground_signature(cell).begins_with("paint:"):
			continue
		var first_row := cell.y * Landscape.GRID - MAP_TOP
		for row in range(first_row, first_row + Landscape.GRID):
			_disturbed_rows[row] = 1
		if landscape.terrain_overrides[cell] == "water":
			_painted_water.append(cell)
	_flags.clear()
	for prop in landscape.props:
		if prop.kind == "beach_flag":
			_flags.append(prop.duplicate(true))
	queue_redraw()


func present(total_sim_time: float) -> void:
	if _time == total_sim_time:
		return
	_time = total_sim_time
	queue_redraw()


func condition_name() -> String:
	return CONDITION_NAMES[condition_at(_time)]


func condition_color() -> Color:
	return CONDITION_COLORS[condition_at(_time)]


static func condition_at(total_sim_time: float) -> Condition:
	var energy := _wave_energy(total_sim_time)
	if energy >= 0.74:
		return Condition.CLOSED
	if energy >= 0.34:
		return Condition.CAUTION
	return Condition.CALM


static func _wave_energy(total_sim_time: float) -> float:
	return (1.0 - cos(TAU * fposmod(total_sim_time, SURF_PERIOD) / SURF_PERIOD)) * 0.5


func _draw() -> void:
	if _shore.is_empty():
		return
	var energy := _wave_energy(_time)
	_draw_open_water(energy)
	_draw_breakers(energy)
	_draw_wash(energy)
	_draw_painted_water()
	_draw_flags()


func _draw_open_water(energy: float) -> void:
	for i in range(108):
		var row := (i * 47 + 16) % _shore.size()
		var y := MAP_TOP + row
		var phase := _time * (0.68 + (i % 4) * 0.12) + i * 2.4
		var height := (sin(phase) + 1.0) * 0.5
		var x := _shore[row] + 38 + (i * 113) % 318
		x += roundi(cos(phase * 0.65) * (3.0 + energy * 5.0))
		var width := 3 + (i * 13) % 13
		var glint := Color(0.74, 0.94, 0.87, (0.09 + energy * 0.28) * height)
		_draw_water_run(x, y, width, glint)
		if i % 3 == 0:
			var shadow := Color(0.16, 0.41, 0.53, (0.07 + energy * 0.17) * height)
			_draw_water_run(x + 3, y + 2, width - 1, shadow)


func _draw_breakers(energy: float) -> void:
	for wave in range(4):
		var travel := fposmod(_time * 0.19 + wave * 0.25, 1.0)
		var fade := sin(travel * PI)
		var reach := 15.0 + energy * 54.0
		var swell := 4.0 + (1.0 - travel) * reach
		var crest := Color(0.79, 0.98, 0.88, fade * (0.15 + energy * 0.52))
		var trough := Color(0.16, 0.43, 0.48, fade * (0.08 + energy * 0.22))
		for segment in range(17):
			var first_row := segment * 37 + (wave * 13 + segment * 7) % 26
			var length := 4 + (segment * 3 + wave * 7) % 8 + roundi(energy * 9.0)
			for step in range(length):
				var row := first_row + step
				if row >= _shore.size():
					break
				var curve := sin(row * 0.067 + wave * 1.3) * (1.8 + energy * 3.5)
				var x := _shore[row] + maxi(1, roundi(swell + curve))
				var width := 1 + roundi(sin(float(step) / length * PI) * (1.0 + energy * 2.0))
				_draw_water_run(x, MAP_TOP + row, width, crest)
				_draw_water_run(x + width + 2, MAP_TOP + row, width + 2, trough)


func _draw_wash(energy: float) -> void:
	for row in range(_shore.size()):
		var wash := sin(row * 0.17 - _time * 2.2) + sin(row * 0.057 + _time * 1.17)
		if wash < 1.1 - energy * 0.62:
			continue
		var length := 1 + roundi((wash - 0.45) * (1.0 + energy * 3.2))
		var color := Color(0.91, 1.0, 0.87, (0.18 + energy * 0.31) * minf(wash * 0.7, 1.0))
		_draw_water_run(_shore[row], MAP_TOP + row, length, color)


func _draw_water_run(x: int, y: int, width: int, color: Color) -> void:
	var row := y - MAP_TOP
	if row < 0 or row >= _shore.size():
		return
	var start := maxi(x, MAP_LEFT)
	var end := mini(MAP_RIGHT, x + width)
	if _disturbed_rows[row] == 0:
		start = maxi(start, _shore[row])
		if end > start:
			draw_rect(Rect2(start, y, end - start, 1), color)
		return
	var run_start := end
	for pixel in range(start, end):
		if _landscape.is_water_pixel(Vector2(pixel, y)):
			run_start = mini(run_start, pixel)
		elif run_start < pixel:
			draw_rect(Rect2(run_start, y, pixel - run_start, 1), color)
			run_start = end
	if run_start < end:
		draw_rect(Rect2(run_start, y, end - run_start, 1), color)


func _draw_painted_water() -> void:
	for cell in _painted_water:
		var phase := sin(_time * 2.1 + cell.x * 6.2 + cell.y * 4.7)
		if phase < 0.22:
			continue
		var pixel := cell * Landscape.GRID + Vector2i(2, 2 + posmod(cell.x + cell.y, 4))
		var glint := Color(0.74, 0.94, 0.87, 0.25 * phase)
		var width := 2 + posmod(cell.x * 3 + cell.y, 4)
		draw_rect(Rect2(pixel.x, pixel.y, width, 1), glint)


func _draw_flags() -> void:
	var color := condition_color()
	var wind := 0.9 + _wave_energy(_time) * 2.4
	var fold := roundf(sin(_time * 4.8) * wind)
	var tip := roundf(sin(_time * 4.8 - 0.95) * wind)
	for prop in _flags:
		var anchor := LandscapeRenderer.prop_anchor(prop)
		LandscapeRenderer.draw_beach_flag(self, anchor, prop.rotation, color, fold, tip)
