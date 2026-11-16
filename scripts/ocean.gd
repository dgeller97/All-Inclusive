extends Node2D

enum Condition { CALM, CAUTION, CLOSED }

const Landscape = preload("res://scripts/landscape_model.gd")
const LandscapeRenderer = preload("res://scripts/landscape_renderer.gd")
const Calendar = preload("res://scripts/resort_calendar.gd")
const MAP_LEFT := Landscape.WORLD_ORIGIN.x
const MAP_TOP := Landscape.WORLD_ORIGIN.y
const MAP_RIGHT := Landscape.REGION.end.x * Landscape.GRID
const SURF_PERIOD := 112.0
const CONDITION_NAMES := ["Calm", "Caution", "Closed"]
const CONDITION_COLORS := [Color("#78c897"), Color("#ffce70"), Color("#f66b65")]
const SEAWEED := [Color("#805544"), Color("#9a6b47"), Color("#a67c4a"), Color("#bd915a")]
const SEASON_LENGTH := Calendar.DAYS_PER_MONTH * Calendar.DAY_LENGTH * 8
const YEAR_LENGTH := Calendar.DAYS_PER_MONTH * Calendar.DAY_LENGTH * 12
const DRIFT_INTERVAL := 32.0
const DRIFT_LANES := 32

var _time := 0.0
var _shore := PackedInt32Array()
var _landscape: Landscape
var _landscape_revision := -1
var _disturbed_rows := PackedByteArray()
var _painted_water: Array[Vector2i] = []
var _flags: Array[Dictionary] = []
var _sargassum := 0
var _flag := -1
var _seaweed_texture: ImageTexture
var _seaweed_origin := Vector2.ZERO
var _seaweed_dirty := true
var _flags_interleaved := false
var _swim_access := {}
var _buoy_points := PackedVector2Array()
var _field_active := false
var _field_rafts: Array = []
var _field_deposits: Array = []
static var _patches: Dictionary = {}
static var _patch_images: Dictionary = {}
static var _patch_textures: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shore = Landscape.coastline()
	_disturbed_rows.resize(_shore.size())


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
	_seaweed_dirty = true
	queue_redraw()


func present(total_sim_time: float, sargassum: int = 0, condition: int = -1) -> void:
	if _time == total_sim_time and _sargassum == sargassum and _flag == condition:
		return
	_time = total_sim_time
	if _sargassum != sargassum:
		_sargassum = clampi(sargassum, 0, 100)
		_seaweed_dirty = true
	_flag = condition
	queue_redraw()


func present_field(rafts: Array, deposits: Array) -> void:
	# Simulation owns this ledger. Drawing never creates, consumes or deposits a raft.
	if not _field_active or _field_deposits != deposits:
		_field_deposits = deposits.duplicate(true)
		_seaweed_dirty = true
	_field_active = true
	_field_rafts = rafts
	queue_redraw()


func condition_name() -> String:
	return CONDITION_NAMES[_flag if _flag >= 0 else condition_at(_time)]


func condition_color() -> Color:
	return CONDITION_COLORS[_flag if _flag >= 0 else condition_at(_time)]


func offshore(point: Vector2) -> Vector2:
	var row := clampi(floori(point.y) - MAP_TOP, 0, _shore.size() - 1)
	return Vector2(clampf(point.x, _shore[row] + 7.0, MAP_RIGHT - 9.0), point.y)


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
	_draw_floating_sargassum()
	_draw_sargassum()
	_draw_swim_buoys()
	_draw_painted_water()
	_draw_flags()


func set_swim_access(access: Dictionary) -> void:
	if _swim_access == access:
		return
	_swim_access = access.duplicate()
	_buoy_points.clear()
	if not access.is_empty() and not _shore.is_empty():
		# Cover the actual four adult/child lanes, including coast-clamped targets.
		var water: Vector2 = access.water
		var top := clampf(water.y - 30, MAP_TOP + 10, Landscape.WORLD_BOUNDS.end.y - 10)
		var bottom := clampf(water.y + 46, top + 1, Landscape.WORLD_BOUNDS.end.y - 10)
		var edge := water.x + 27.0
		for lane in 4:
			var target := water + Vector2(lane * 3, [0, -12, 12, 20][lane])
			edge = maxf(edge, offshore(target).x + 18)
			edge = maxf(edge, offshore(target + Vector2(-7, 8)).x + 18)
		for y in range(int(top), int(bottom) + 1):
			edge = maxf(edge, float(_shore[y - MAP_TOP]) + 22)
		edge = minf(edge, MAP_RIGHT - 10)
		var corners := [Vector2(_shore[int(top) - MAP_TOP] + 9, top), Vector2(edge, top),
			Vector2(edge, bottom), Vector2(_shore[int(bottom) - MAP_TOP] + 9, bottom)]
		for index in 3:
			var from: Vector2 = corners[index]
			var to: Vector2 = corners[index + 1]
			var steps := maxi(1, ceili(from.distance_to(to) / 16.0))
			for step in steps:
				_buoy_points.append(from.lerp(to, float(step) / steps).round())
		_buoy_points.append(corners[3])
	queue_redraw()


func swim_buoy_points() -> PackedVector2Array:
	return _buoy_points.duplicate()


func floating_sargassum(at_time: float = NAN) -> Array[Dictionary]:
	if _field_active and is_nan(at_time):
		var authoritative: Array[Dictionary] = []
		authoritative.assign(_field_rafts)
		return authoritative
	# Reconstruct arrival cohorts from simulation time, so pause/load never resets a raft.
	var result: Array[Dictionary] = []
	if _shore.is_empty():
		return result
	var clock := maxf(0.0, _time if is_nan(at_time) else at_time)
	var season_start := floorf(clock / YEAR_LENGTH) * YEAR_LENGTH
	var age := clock - season_start
	if age > SEASON_LENGTH + 112:
		return result
	for lane in DRIFT_LANES:
		var duration := 72.0 + float((lane * 13) % 37)
		var delay := float((lane * 7) % 23)
		var last := floori((age - delay) / DRIFT_INTERVAL)
		for cohort in range(maxi(0, last - 3), last + 1):
			var birth := cohort * DRIFT_INTERVAL + delay
			var travel := (age - birth) / duration
			if birth >= SEASON_LENGTH or travel < 0.0 or travel >= 1.0:
				continue
			var day := floori((season_start + birth) / Calendar.DAY_LENGTH) + 1
			var pressure: float = Calendar.state(day, 0).sargassum_pressure
			# Lane density is stable within a cohort, with more rafts in summer.
			if float((lane * 17 + cohort * 7) % 32) / 32.0 > 0.28 + pressure * 0.72:
				continue
			var row := 14 + (lane * 29 + cohort * 43 + floori(_shore.size() * 0.4)) % (_shore.size() - 28)
			var y := MAP_TOP + row + roundi(sin(travel * PI) * 9.0)
			var coast := float(_shore[y - MAP_TOP])
			var deep := maxf(coast + 16.0, MAP_RIGHT - 22.0 - float(lane % 4) * 11.0)
			var x := lerpf(deep, coast + 2.0, travel)
			var fade := minf(clampf((age - birth + 2.0) / 7.0, 0, 1), clampf((1.0 - travel) * 12.0, 0, 1))
			result.append({"id": int(season_start) + cohort * DRIFT_LANES + lane,
				"point": Vector2(roundf(x), y), "progress": travel, "opacity": fade,
				"variant": posmod(lane * 3 + cohort, 8)})
	return result


static func sargassum_patch(variant: int) -> Array[Dictionary]:
	variant = posmod(variant, 8)
	if _patches.has(variant):
		return _patches[variant]
	var pixels: Array[Dictionary] = []
	var radius := 7 + variant % 5
	for y in range(-5, 6):
		for x in range(-radius, radius + 1):
			var grain := posmod((x * 73856093) ^ (y * 19349663) ^ (variant * 83492791), 101)
			var shape := float(x * x) / float(radius * radius) + float(y * y) / 22.0
			if shape > 0.65 + float(grain) / 125.0 or grain < 22:
				continue
			pixels.append({"point": Vector2i(x, y), "color": SEAWEED[posmod(grain + y, 4)]})
	_patches[variant] = pixels
	return pixels


static func sargassum_patch_image(variant: int, dimensions := Vector2i(25, 14)) -> Image:
	variant = posmod(variant, 8)
	dimensions = Vector2i(clampi(dimensions.x, 7, 73), clampi(dimensions.y, 5, 41))
	var key := "%d:%d:%d" % [variant, dimensions.x, dimensions.y]
	if not _patch_images.has(key):
		var image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		var radius := Vector2(dimensions - Vector2i(3, 3)) * 0.5
		var center := Vector2(dimensions) * 0.5
		var ink: Array[Vector2i] = []
		for y in range(1, dimensions.y - 1):
			for x in range(1, dimensions.x - 1):
				var point := (Vector2(x, y) - center) / radius
				var grain := posmod((x * 73856093) ^ (y * 19349663) ^ (variant * 83492791), 101)
				var edge := 0.83 + sin(point.x * 8 + variant) * 0.17 + cos(point.y * 10 + variant) * 0.12
				if point.length_squared() < edge and grain > 18:
					ink.append(Vector2i(x, y))
		for pixel in ink:
			image.set_pixelv(pixel + Vector2i(1, 1), Color("#24574660"))
		for pixel in ink:
			var grain := posmod((pixel.x * 73856093) ^ (pixel.y * 19349663) ^ (variant * 83492791), 101)
			image.set_pixelv(pixel, SEAWEED[posmod(grain + pixel.y, 4)])
		_patch_images[key] = image
	return _patch_images[key]


func _draw_floating_sargassum() -> void:
	for raft in floating_sargassum():
		var point: Vector2 = raft.point
		var bob := roundi(sin(_time * 1.7 + raft.id) * 0.75)
		var dimensions := Vector2i(raft.get("size", Vector2(25, 14)))
		var image := sargassum_patch_image(raft.variant, dimensions)
		var key := "%d:%d:%d" % [raft.variant, image.get_width(), image.get_height()]
		if not _patch_textures.has(key):
			_patch_textures[key] = ImageTexture.create_from_image(image)
		var origin := Vector2i(point) - image.get_size() / 2 + Vector2i(0, bob)
		# Native-size cached pixels, sliced only where necessary to preserve the coast.
		for y in image.get_height():
			var row := origin.y + y - MAP_TOP
			if row < 0 or row >= _shore.size():
				continue
			var start := maxi(origin.x, maxi(MAP_LEFT, _shore[row]))
			var end := mini(origin.x + image.get_width(), MAP_RIGHT)
			if end <= start:
				continue
			if _disturbed_rows[row] == 0:
				_draw_patch_row(_patch_textures[key], image, Rect2(start - origin.x, y, end - start, 1),
					Vector2(start, origin.y + y), raft.opacity * 0.88)
				continue
			var first := start
			for x in range(start, end + 1):
				var wet := x < end and (_disturbed_rows[row] == 0 or _landscape.is_water_pixel(Vector2(x, origin.y + y)))
				if wet:
					continue
				if x > first:
					_draw_patch_row(_patch_textures[key], image, Rect2(first - origin.x, y, x - first, 1),
						Vector2(first, origin.y + y), raft.opacity * 0.88)
				first = x + 1


func _draw_patch_row(texture: Texture2D, _image: Image, source: Rect2, at: Vector2, opacity: float) -> void:
	draw_texture_rect_region(texture, Rect2(at, source.size), source, Color(1, 1, 1, opacity))


func _draw_swim_buoys() -> void:
	var floating := PackedVector2Array()
	for index in _buoy_points.size():
		var point := _buoy_points[index]
		point.y += roundf(sin(_time * 2.0 + index * 0.8) * (0.65 + _wave_energy(_time) * 0.6))
		floating.append(point)
		if index > 0:
			var previous := floating[index - 1]
			var steps := maxi(1, ceili(previous.distance_to(point)))
			for step in steps:
				var progress := float(step) / steps
				var link := previous.lerp(point, progress)
				link.y += sin(progress * PI)
				_draw_water_run(roundi(link.x), roundi(link.y), 1, Color("#e2d9b4b0"))
	for point in floating:
		var x := roundi(point.x)
		var y := roundi(point.y)
		_draw_water_run(x - 3, y + 2, 7, Color("#245b6590"))
		_draw_water_run(x - 2, y - 3, 4, Color("#fff0c8"))
		_draw_water_run(x - 3, y - 2, 6, Color("#ed9b52"))
		_draw_water_run(x - 3, y - 1, 6, Color("#fff0c8"))
		_draw_water_run(x - 2, y, 4, Color("#cb7547"))
		_draw_water_run(x - 4, y + 3, 3, Color("#a2d7c284"))


func _draw_open_water(energy: float) -> void:
	for i in range(roundi(_shore.size() * 0.18)):
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
		for segment in range(ceili(_shore.size() / 37.0)):
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


func sargassum_pixels(amount: int) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	if amount <= 0 or not _landscape:
		return pixels
	for row in range(1, _shore.size() - 1):
		var y := MAP_TOP + row
		var cluster := roundi(24.0 + 17.0 * sin(row * 0.087) + 7.0 * cos(row * 0.217))
		var drift := roundi(sin(row * 0.071) * 4.0 + cos(row * 0.16) * 2.0)
		for offset in range(-17, 9):
			var x := _shore[row] + offset
			var grain := posmod((row * 73856093) ^ (offset * 19349663) ^ ((row + offset) * 83492791), 57)
			if cluster + grain + absi(offset - drift) * 4 >= amount:
				continue
			var point := Vector2i(x, y)
			var cell := Vector2i(floori(float(x) / Landscape.GRID), floori(float(y) / Landscape.GRID))
			if offset >= 0 or _landscape.terrain_at(cell) == "sand" and _landscape.path_at(cell).is_empty():
				pixels.append(point)
	return pixels


func _draw_sargassum() -> void:
	if _seaweed_dirty:
		_seaweed_dirty = false
		_seaweed_texture = null
		var pixels := deposited_pixels() if _field_active else sargassum_pixels(_sargassum)
		if not pixels.is_empty():
			var bounds := Rect2i(pixels[0], Vector2i.ONE)
			for point in pixels:
				bounds = bounds.merge(Rect2i(point, Vector2i.ONE))
			var image := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
			for point in pixels:
				var pigment := (point.x + point.y * point.y) & 3
				image.set_pixelv(point - bounds.position, SEAWEED[pigment])
			_seaweed_texture = ImageTexture.create_from_image(image)
			_seaweed_origin = Vector2(bounds.position)
	if _seaweed_texture:
		draw_texture(_seaweed_texture, _seaweed_origin)


func deposited_pixels() -> Array[Vector2i]:
	var pixels: Array[Vector2i] = []
	if not _landscape:
		return pixels
	var occupied := {}
	for deposit in _field_deposits:
		var amount := maxi(0, int(deposit.amount))
		if amount == 0:
			continue
		var center := int(deposit.row)
		var radius := mini(20, 3 + roundi(sqrt(float(amount)) * 1.4))
		var depth := mini(17, 1 + roundi(sqrt(float(amount)) * 0.8))
		for y in range(maxi(MAP_TOP, center - radius), mini(MAP_TOP + _shore.size(), center + radius + 1)):
			var taper := sqrt(maxf(0.0, 1.0 - pow(float(y - center) / (radius + 1), 2)))
			var width := maxi(1, roundi(depth * taper))
			for offset in range(-width, 3):
				var grain := posmod((y * 73856093) ^ (offset * 19349663) ^ (center * 83492791), 101)
				if grain < 24 or (absi(offset) > width - 2 and grain < 55):
					continue
				var x := _shore[y - MAP_TOP] + offset
				var cell := Vector2i(floori(float(x) / Landscape.GRID), floori(float(y) / Landscape.GRID))
				if offset >= 0 or (_landscape.terrain_at(cell) == "sand" and _landscape.path_at(cell).is_empty()):
					occupied[Vector2i(x, y)] = true
	for pixel: Vector2i in occupied:
		pixels.append(pixel)
	return pixels


func _draw_water_run(x: int, y: int, width: int, color: Color) -> void:
	var row := y - MAP_TOP
	if row < 0 or row >= _shore.size():
		return
	var start := maxi(x, MAP_LEFT)
	var end := mini(MAP_RIGHT, x + width)
	if _disturbed_rows[row] == 0:
		start = maxi(start, _shore[row])
		if end > start:
			_water_block(Rect2(start, y, end - start, 1), color)
		return
	var run_start := end
	for pixel in range(start, end):
		if _landscape.is_water_pixel(Vector2(pixel, y)):
			run_start = mini(run_start, pixel)
		elif run_start < pixel:
			_water_block(Rect2(run_start, y, pixel - run_start, 1), color)
			run_start = end
	if run_start < end:
		_water_block(Rect2(run_start, y, end - run_start, 1), color)


func _water_block(rect: Rect2, color: Color) -> void:
	draw_rect(rect, color)


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
	if _flags_interleaved:
		return
	for prop in _flags:
		draw_flag(self, prop)


func set_flags_interleaved(enabled: bool) -> void:
	if _flags_interleaved != enabled:
		_flags_interleaved = enabled
		queue_redraw()


func draw_flag(canvas: CanvasItem, prop: Dictionary) -> void:
	var color := condition_color()
	var wind := 0.9 + _wave_energy(_time) * 2.4
	var fold := roundf(sin(_time * 4.8) * wind)
	var tip := roundf(sin(_time * 4.8 - 0.95) * wind)
	var anchor := LandscapeRenderer.prop_anchor(prop)
	LandscapeRenderer.draw_beach_flag(canvas, anchor, prop.rotation, color, fold, tip)
