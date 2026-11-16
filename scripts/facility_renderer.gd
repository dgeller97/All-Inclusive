extends RefCounted
## Pixel art and the fixed geometry used by the activities. Lifts stay vertical
## after the ground layout turns, including hoops, cabinets and slide supports.

const KINDS := ["lap_pool", "lagoon_pool", "hot_tub", "kids_pool", "waterpark",
	"basketball", "climbing_wall", "arcade", "cafe", "nightclub"]
const Depth := preload("res://scripts/render_depth.gd")
const INK := Color("#443549")
const SHADE := Color("#56435757")
const IVORY := Color("#f8e5b9")
const TILE := Color("#dba477")
const TILE_SHADE := Color("#a56c58")
const WATER := Color("#58a9aa")
const BLUE := Color("#4f7d99")
const AQUA := Color("#9ad8cc")
const PLUM := Color("#704c70")
const MAGENTA := Color("#ca7694")
const LIME := Color("#c5cd7e")
const CORAL := Color("#d57756")
const GOLD := Color("#f2bb6f")
const WOOD := Color("#b58164")
const STONE := Color("#968e8b")

const LAP_WATER := Rect2(8, 9, 80, 38)
const LAGOON_WATER := Rect2(10, 8, 76, 57)
const TUB_WATER := Rect2(6, 5, 28, 25)
const KIDS_WATER := Rect2(7, 7, 50, 36)
const SLIDE_WATER := Rect2(50, 23, 54, 48)
const RIM := Vector3(40, 16, 16)
const CLIMB_BASE := Vector2(27, 22)
const CLIMB_ANCHOR := Vector3(27, 18, 31)
const CAFE_TABLES := [Vector2(16, 30), Vector2(48, 30)]
const CAFE_COUNTER := Vector2(32, 15)
const ARCADE_Y := 12.0
const CLUB_LAMPS := [Vector3(15, 8, 14), Vector3(40, 7, 14), Vector3(65, 8, 14)]

var _image: Image
var _base: Image
var _parts: Array[Dictionary]
var _origin: Vector2
var _size: Vector2
var _turn: int


static func ground_point(origin: Vector2, size: Vector2, rotation: int, local: Vector2) -> Vector2:
	match rotation:
		1: return origin + Vector2(size.y - local.y, local.x)
		2: return origin + size - local
		3: return origin + Vector2(local.y, size.x - local.x)
	return origin + local


static func paint(image: Image, origin: Vector2, size: Vector2, turn: int, kind: String, parts: Array[Dictionary]) -> void:
	var art := new()
	art._image = image
	art._base = image
	art._parts = parts
	art._origin = origin
	art._size = size
	art._turn = turn
	match kind:
		"lap_pool": art._lap_pool()
		"lagoon_pool": art._lagoon_pool()
		"hot_tub": art._hot_tub()
		"kids_pool": art._kids_pool()
		"waterpark": art._waterpark()
		"basketball": art._basketball()
		"climbing_wall": art._climbing()
		"arcade": art._arcade()
		"cafe": art._cafe()
		"nightclub": art._nightclub()


func _begin_piece() -> void:
	_image = Image.create(_base.get_width(), _base.get_height(), false, Image.FORMAT_RGBA8)


func _end_piece(tag: String, contact: Vector2, bias: float = 0.0) -> void:
	var item := Depth.piece(_image, _at(contact).y - _origin.y + bias, tag)
	if not item.is_empty():
		_parts.append(item)
	_image = _base


static func water_contains(kind: String, local: Vector2) -> bool:
	match kind:
		"lap_pool": return LAP_WATER.has_point(local)
		"lagoon_pool": return _ellipse_contains(LAGOON_WATER, local)
		"hot_tub": return _ellipse_contains(TUB_WATER, local)
		"kids_pool": return _ellipse_contains(KIDS_WATER, local)
		"waterpark": return _ellipse_contains(SLIDE_WATER, local)
	return false


static func _ellipse_contains(bounds: Rect2, local: Vector2) -> bool:
	return ((local - bounds.get_center()) / (bounds.size * 0.5)).length_squared() < 1.0


static func slide_start(slot: int) -> Vector3:
	return Vector3(16, 34 + slot * 12, 23)


static func slide_point(slot: int, progress: float) -> Vector3:
	var outset := slide_start(slot)
	return Vector3(lerpf(outset.x, 67, progress), outset.y - sin(progress * PI) * 7.0,
		outset.z * (1.0 - progress * progress))


static func cabinet_at(player: int) -> Vector2:
	return Vector2(7 + player * 14, ARCADE_Y)


static func climb_face(x: float) -> float:
	return 22.0 + (x - CLIMB_BASE.x) * 0.125


func _at(local: Vector2, height: float = 0.0) -> Vector2:
	return ground_point(_origin, _size, _turn, local) - Vector2(0, height)


func _xyz(local: Vector3) -> Vector2:
	return _at(Vector2(local.x, local.y), local.z)


func _block(at: Vector2, extent: Vector2, color: Color) -> void:
	var bounds := Rect2i(Vector2i(at.round()), Vector2i(extent.round()))
	bounds = bounds.intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
	if bounds.has_area():
		_image.fill_rect(bounds, color)


func _plane(bounds: Rect2, color: Color, lift: float = 0.0) -> void:
	var a := _at(bounds.position, lift)
	var b := _at(bounds.end, lift)
	_block(a.min(b), (a - b).abs(), color)


func _segment(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in range(steps + 1):
		_block(a.lerp(b, float(i) / steps).round() - Vector2.ONE * floorf(width * 0.5), Vector2.ONE * width, color)


func _edgeline(a: Vector2, b: Vector2, color: Color, height: float = 0.0, width: float = 1.0) -> void:
	_segment(_at(a, height), _at(b, height), color, width)


func _upright(at: Vector2, width: float, height: float, color: Color, base: float = 0.0) -> void:
	_block(_at(at, base + height) - Vector2(floorf(width * 0.5), 0.0), Vector2(width, height), color)


func _oval(bounds: Rect2, color: Color, lift: float = 0.0) -> void:
	var half := bounds.size * 0.5
	var center := bounds.get_center()
	for y in range(ceili(bounds.position.y), ceili(bounds.end.y)):
		var dy := ((y + 0.5) - center.y) / half.y
		var span := half.x * sqrt(maxf(0.0, 1.0 - dy * dy))
		_plane(Rect2(ceilf(center.x - span), y, maxf(0.0, floorf(span * 2.0)), 1), color, lift)


func _frame(bounds: Rect2, edge: Color, color: Color, width: float = 1.0) -> void:
	_plane(bounds, edge)
	_plane(bounds.grow(-width), color)


func _deck(edge: Color = TILE_SHADE, surface: Color = TILE) -> void:
	var pad := Rect2(Vector2(2, 3), _size - Vector2(4, 5))
	_frame(pad, edge, surface, 2)
	for row in range(8, int(_size.y) - 5, 6):
		_plane(Rect2(4, row, _size.x - 8, 1), surface.lightened(0.15))
		for col in range(8 + posmod(row * 3, 10), int(_size.x) - 5, 12):
			_plane(Rect2(col, row - 3, 1, 4), surface.darkened(0.11))


func _gate(trim: Color) -> void:
	var middle := _size.x * 0.5
	var threshold := Rect2(middle - 7, _size.y - 8, 14, 8)
	_plane(threshold, trim.darkened(0.22))
	_plane(threshold.grow(-1), trim)
	for x in [middle - 6, middle + 6]:
		var post := Vector2(x, _size.y - 3)
		_begin_piece()
		_upright(post, 3, 5, INK)
		_upright(post, 1, 4, IVORY)
		_end_piece("gate_post", post)
	_plane(Rect2(middle - 3, _size.y - 4, 6, 2), IVORY)


func _lining(bounds: Rect2, shade: Color, water: Color, round_basin: bool = true) -> void:
	if round_basin:
		_oval(bounds.grow(4), shade)
		_oval(bounds.grow(3), IVORY)
		_oval(bounds.grow(1), water.darkened(0.25))
		_oval(bounds, water)
	else:
		_frame(bounds.grow(4), shade, IVORY, 1)
		_frame(bounds.grow(1), water.darkened(0.25), water, 1)


func _ripples(bounds: Rect2, kind: String, color: Color) -> void:
	for y in range(int(bounds.position.y) + 4, int(bounds.end.y) - 3, 6):
		for x in range(int(bounds.position.x) + 3 + posmod(y, 9), int(bounds.end.x) - 6, 12):
			var at := Vector2(x, y)
			if water_contains(kind, at) and water_contains(kind, at + Vector2(5, 0)):
				_plane(Rect2(at, Vector2(3 + ((x + y) % 3), 1)), color)
				if (x + y) % 4 == 0:
					_plane(Rect2(at + Vector2(2, 2), Vector2(2, 1)), color.darkened(0.13))


func _ladder(place: Vector2, edge: Vector2) -> void:
	var along := Vector2(edge.y, -edge.x)
	for offset in [-3, 3]:
		var base: Vector2 = place + along * offset
		_edgeline(base - edge * 4, base + edge * 5, BLUE)
		var rail := base - edge * 4
		_begin_piece()
		_upright(rail, 1, 4, IVORY)
		_end_piece("pool_rail", rail)
	for depth in [1, 3, 5]:
		var step: Vector2 = place + edge * depth
		_edgeline(step - along * 3, step + along * 3, AQUA)


func _lap_pool() -> void:
	_deck(Color("#8b776f"), Color("#c2aaa0"))
	_lining(LAP_WATER, BLUE, Color("#60b5be"), false)
	_ripples(LAP_WATER, "lap_pool", Color("#76c6ca"))
	for lane in [18, 28, 38]:
		_plane(Rect2(9, lane, 78, 1), BLUE)
		for x in range(10, 86, 5):
			_plane(Rect2(x, lane, 3, 1), GOLD if x < 25 or x > 72 else IVORY)
	for y in [12, 22, 32, 42]:
		_plane(Rect2(4, y, 4, 5), BLUE, 1)
		_plane(Rect2(4, y, 4, 1), IVORY, 1)
	for lane in [13, 23, 33, 43]:
		_ladder(Vector2(88, lane), Vector2.LEFT)
	_gate(BLUE)


func _lagoon_pool() -> void:
	_deck(Color("#947864"), Color("#dfa774"))
	_lining(LAGOON_WATER, Color("#7f7a6c"), Color("#69b8a7"))
	_oval(Rect2(18, 13, 59, 35), Color("#559b98"))
	_ripples(LAGOON_WATER, "lagoon_pool", AQUA)
	_ladder(Vector2(48, 63), Vector2.UP)
	for x in [11, 77]:
		_frame(Rect2(x, 66, 11, 5), TILE_SHADE, GOLD)
		_plane(Rect2(x + 3, 66, 1, 5), IVORY)
	_gate(Color("#518f82"))


func _hot_tub() -> void:
	_deck(Color("#855b57"), Color("#9f705d"))
	_oval(TUB_WATER.grow(4), Color("#6f5351"))
	_oval(TUB_WATER.grow(3), WOOD, 2)
	_oval(TUB_WATER.grow(1), IVORY, 2)
	_oval(TUB_WATER, Color("#68ada9"))
	_oval(TUB_WATER.grow(-5), Color("#7cc1b3"))
	_ripples(TUB_WATER, "hot_tub", Color("#b2e1c9"))
	# The raised foreground rim hides a swimmer at the waterline without
	# repainting the water underneath.
	_tub_lip()
	_frame(Rect2(14, 28, 10, 5), INK, WOOD)
	_plane(Rect2(15, 29, 8, 1), IVORY)
	_frame(Rect2(29, 29, 8, 6), TILE_SHADE, MAGENTA)
	_gate(Color("#936d60"))


func _tub_lip() -> void:
	var center := _at(TUB_WATER.get_center())
	var outside := TUB_WATER.size * 0.5 + Vector2(3, 3)
	var inside := TUB_WATER.size * 0.5 + Vector2(0.5, 0.5)
	if _turn % 2 == 1:
		outside = Vector2(outside.y, outside.x)
		inside = Vector2(inside.y, inside.x)
	for bottom in range(0, ceili(outside.y)):
		_begin_piece()
		for x in range(-ceili(outside.x), ceili(outside.x) + 1):
			var distance := Vector2(x, bottom + 0.5)
			if (distance / outside).length_squared() <= 1.0 and (distance / inside).length_squared() >= 1.0:
				_block(center + Vector2(x, bottom - 2), Vector2.ONE, IVORY if (distance / (outside - Vector2.ONE)).length_squared() < 1.0 else WOOD)
		var item := Depth.piece(_image, center.y - _origin.y + bottom, "tub_rim")
		if not item.is_empty():
			_parts.append(item)
		_image = _base


func _kids_pool() -> void:
	_deck(Color("#a28c71"), Color("#efd0a0"))
	_lining(KIDS_WATER, CORAL, Color("#89c7bb"))
	_ripples(KIDS_WATER, "kids_pool", Color("#b3e5cf"))
	for fish in [Vector2(19, 27), Vector2(31, 16), Vector2(42, 32)]:
		_plane(Rect2(fish, Vector2(5, 3)), GOLD)
		_plane(Rect2(fish - Vector2(2, 0), Vector2(1, 3)), CORAL)
		_plane(Rect2(fish + Vector2(4, 1), Vector2.ONE), INK)
	for pos in [Vector2(14, 47), Vector2(42, 47)]:
		_frame(Rect2(pos, Vector2(8, 5)), CORAL, GOLD)
		_plane(Rect2(pos + Vector2(2, 1), Vector2(4, 3)), IVORY)
	_gate(CORAL)


func _waterpark() -> void:
	_deck(Color("#9b796c"), Color("#ddae80"))
	_lining(SLIDE_WATER, BLUE, Color("#64b8bc"))
	_ripples(SLIDE_WATER, "waterpark", AQUA)
	_ladder(Vector2(79, 68), Vector2.UP)
	for slot in range(3):
		var start := slide_start(slot)
		var base := Vector2(start.x, start.y)
		_plane(Rect2(base - Vector2(6, 5), Vector2(18, 10)), SHADE)
		for corner in [base - Vector2(3, 3), base + Vector2(3, 3)]:
			_begin_piece()
			_upright(corner, 2, start.z, INK)
			_end_piece("slide_support", corner)
		_begin_piece()
		for rung in range(2, int(start.z), 4):
			_edgeline(base - Vector2(3, 3), base + Vector2(3, 3), GOLD, rung)
		_end_piece("slide_ladder", base, -0.2)
		var ramp_support := slide_point(slot, 0.47)
		_begin_piece()
		_upright(Vector2(ramp_support.x, ramp_support.y), 3, ramp_support.z, Color("#815a68"))
		_end_piece("slide_support", Vector2(ramp_support.x, ramp_support.y), -0.3)
	for slot in range(3):
		var stripe: Color = [CORAL, GOLD, Color("#5d9fb0")][slot]
		for i in range(26):
			var ride := slide_point(slot, float(i) / 25.0)
			var local := Vector2(ride.x, ride.y)
			_begin_piece()
			_plane(Rect2(local - Vector2(2, 3), Vector2(4, 7)), INK, ride.z - 1.0)
			_plane(Rect2(local - Vector2(2, 3), Vector2(4, 7)), stripe, ride.z)
			_end_piece("slide_channel", local, -0.6)
			for side in [-1, 1]:
				var rim := local + Vector2(0, side * 3)
				_begin_piece()
				_plane(Rect2(rim - Vector2(1, 0), Vector2(3, 1)), stripe.lightened(0.38), ride.z + 1.0)
				_end_piece("slide_rail", rim, -0.35 if _turn % 2 == 1 else 0.0)
		var tower := slide_start(slot)
		_begin_piece()
		_plane(Rect2(tower.x - 5, tower.y - 4, 9, 9), stripe, tower.z)
		_end_piece("slide_platform", Vector2(tower.x, tower.y), -0.3)
		for post: Vector2 in [Vector2(tower.x - 4, tower.y - 4), Vector2(tower.x + 3, tower.y + 4)]:
			_begin_piece()
			_upright(post, 1, 4, IVORY, tower.z)
			_end_piece("slide_post", post)
	_gate(Color("#6695a7"))


func _basketball() -> void:
	_deck(Color("#986453"), Color("#b2745b"))
	_frame(Rect2(6, 5, 68, 51), Color("#724d53"), Color("#cd8762"), 2)
	_frame(Rect2(10, 7, 60, 43), IVORY, Color("#c78460"))
	_frame(Rect2(28, 7, 24, 20), IVORY, Color("#9c6264"))
	_circle(Vector2(40, 26), 10, IVORY, 0, PI)
	_circle(Vector2(40, 17), 28, IVORY, PI * 0.14, PI * 0.86)
	_plane(Rect2(10, 38, 6, 1), IVORY)
	_plane(Rect2(64, 38, 6, 1), IVORY)
	var pole := Vector2(40, 10)
	_begin_piece()
	_upright(pole, 3, 22, INK)
	_upright(pole, 1, 21, IVORY)
	_end_piece("hoop_pole", pole)
	for col in range(31, 49, 3):
		_begin_piece()
		for h in range(16, 23):
			_edgeline(Vector2(col, 11), Vector2(col + 3, 11), INK if h == 16 or h == 22 else IVORY, h, 2)
		_end_piece("hoop_backboard", Vector2(col + 1.5, 11))
	var rim_at := _xyz(RIM)
	_begin_piece()
	_segment(_at(pole, 16), rim_at, INK, 2)
	_block(rim_at - Vector2(3, 0), Vector2(7, 2), CORAL)
	_block(rim_at - Vector2(2, 2), Vector2(5, 1), GOLD)
	for tip in [-2, 2]:
		_segment(rim_at + Vector2(tip, 1), rim_at + Vector2(tip * 0.5, 5), IVORY)
	_end_piece("hoop_rim", Vector2(RIM.x, RIM.y), 0.25)
	_gate(Color("#895c63"))


func _circle(center: Vector2, radius: float, color: Color, from: float, to: float) -> void:
	var previous := _at(center + Vector2.from_angle(from) * radius)
	for index in range(1, 20):
		var angle := lerpf(from, to, float(index) / 19.0)
		var next := _at(center + Vector2.from_angle(angle) * radius)
		_segment(previous, next, color)
		previous = next


func _climbing() -> void:
	_deck(Color("#817779"), Color("#baa58e"))
	_frame(Rect2(6, 16, 44, 22), PLUM, Color("#8caba2"), 2)
	_plane(Rect2(8, 34, 39, 1), AQUA)
	var front := _turn < 2
	var holds := [Vector2i(16, 5), Vector2i(30, 8), Vector2i(23, 13),
		Vector2i(35, 16), Vector2i(19, 20), Vector2i(26, 25)]
	for col in range(10, 44, 2):
		var middle := float(col) + 1.0
		var face := climb_face(middle)
		var last := clampi(31 - floori(absf(middle - 27.0) * 0.48), 20, 31)
		_begin_piece()
		for height in range(last + 1):
			var band := floori(height / 5.0) + floori(middle / 7.0)
			var shade: Color = [Color("#a28f7d"), Color("#ac9a86"), Color("#b5a38c")][posmod(band, 3)]
			var back := 10.0 + float(height) * 0.09
			_plane(Rect2(col, back, 2, face - back), shade.darkened(0.08 if front else 0.19), height)
			if front:
				_plane(Rect2(col, face - 1.0, 2, 2), shade, height)
			elif height % 6 == 1:
				_plane(Rect2(col, back, 2, 1), shade.darkened(0.29), height)
		_plane(Rect2(col, 10.0 + last * 0.09, 2, 2), Color("#c0ae97"), last)
		if front:
			for grip: Vector2i in holds:
				if grip.x < col or grip.x >= col + 2:
					continue
				var position := _at(Vector2(grip.x, climb_face(grip.x)), grip.y)
				_block(position - Vector2(1, 0), Vector2(4, 2), [CORAL, BLUE, GOLD][grip.y % 3])
		var near_edge := middle + (0.85 if _turn == 1 else -0.85 if _turn == 3 else 0.0)
		var contact := Vector2(near_edge, 10.0 if _turn == 2 else face + 0.5)
		_end_piece("climbing_rock_front" if front else "climbing_rock_back", contact)
	_begin_piece()
	var anchor := Vector2(CLIMB_ANCHOR.x, CLIMB_ANCHOR.y)
	_upright(anchor, 2, 3, IVORY, CLIMB_ANCHOR.z)
	_end_piece("climbing_anchor", anchor, 0.05)
	for side in [-1, 1]:
		var post := Vector2(27 + side * 16, 33)
		_begin_piece()
		_upright(post, 2, 4, INK)
		_end_piece("climbing_mat_post", post)
	_gate(PLUM)


func _arcade() -> void:
	_deck(Color("#5a4657"), Color("#917b84"))
	_frame(Rect2(5, 5, 46, 28), INK, Color("#746176"), 2)
	for x in range(7, 50, 4):
		_plane(Rect2(x, 32, 2, 1), MAGENTA)
	for player in range(4):
		var base := cabinet_at(player)
		var color: Color = [MAGENTA, BLUE, GOLD, Color("#70a49d")][player]
		var profile := Rect2(base - Vector2(4, 3), Vector2(8, 7))
		_begin_piece()
		for height in range(1, 14):
			_plane(profile, INK if height < 3 or height > 12 else color.darkened(0.25), height)
		if _turn != 2:
			var center := _at(base + Vector2(0, 2), 10)
			var screen := 7 if _turn == 0 else 4
			_block(center - Vector2(floori(screen * 0.5), 2), Vector2(screen, 5), INK)
			_block(center - Vector2(floori(screen * 0.5) - 1, 1), Vector2(screen - 2, 3), color.lightened(0.45))
			_block(center, Vector2(1, 1), IVORY)
			_plane(Rect2(base + Vector2(-4, 2), Vector2(8, 3)), color, 4)
			_plane(Rect2(base + Vector2(1, 3), Vector2(2, 1)), GOLD, 4)
		else:
			_plane(Rect2(base + Vector2(-2, -3), Vector2(4, 1)), color.darkened(0.45), 8)
		_end_piece("arcade_cabinet", base)
	_gate(Color("#8b6e97"))


func _cafe() -> void:
	_deck(Color("#8b6357"), Color("#ddb58b"))
	var counter := Rect2(7, 6, 50, 9)
	_frame(counter, INK, WOOD, 2)
	for band in (9 if _turn % 2 == 0 else 25):
		var segment := Rect2(7, 6 + band, 50, 1) if _turn % 2 == 0 else Rect2(7 + band * 2, 6, 2, 9)
		_begin_piece()
		_plane(segment, TILE_SHADE, 4)
		_plane(segment.intersection(Rect2(7, 7, 50, 7)), IVORY, 5)
		_end_piece("cafe_counter", segment.get_center())
	for x in [13, 45]:
		var foot := Vector2(x, 10)
		_begin_piece()
		_upright(foot, 9, 8, PLUM, 4)
		_upright(foot, 5, 3, AQUA, 7)
		_upright(foot + Vector2(2, 0), 1, 2, IVORY, 7)
		_end_piece("cafe_register", foot)
	for x in [8, 56]:
		_begin_piece()
		_upright(Vector2(x, 7), 2, 16, TILE_SHADE)
		_upright(Vector2(x, 7), 1, 15, IVORY)
		_end_piece("cafe_canopy_post", Vector2(x, 7))
	for x in range(18, 44, 5):
		_begin_piece()
		_plane(Rect2(x, 11, 2, 2), CORAL, 5)
		_end_piece("cafe_counter_stock", Vector2(x, 11))
	for band in (5 if _turn % 2 == 0 else 25):
		var segment := Rect2(7, 5 + band, 50, 1) if _turn % 2 == 0 else Rect2(7 + band * 2, 5, 2, 5)
		_begin_piece()
		_plane(segment, CORAL, 16)
		for left in range(7, 57, 5):
			_plane(segment.intersection(Rect2(left + 1, 5, 2, 5)), IVORY, 16)
		_end_piece("cafe_canopy", segment.get_center(), 0.25)
	for table: Vector2 in CAFE_TABLES:
		_oval(Rect2(table - Vector2(7, 5), Vector2(14, 10)), TILE_SHADE)
		_begin_piece()
		_oval(Rect2(table - Vector2(6, 4), Vector2(12, 8)), IVORY, 3)
		_plane(Rect2(table - Vector2(2, 1), Vector2(4, 2)), CORAL, 3)
		_end_piece("cafe_table", table)
		for side in [-1, 1]:
			var chair := table + Vector2(side * 9, 3)
			_frame(Rect2(chair - Vector2(2, 2), Vector2(5, 5)), TILE_SHADE, GOLD)
	_gate(CORAL)


func _nightclub() -> void:
	_deck(Color("#5d4e6c"), Color("#866b8c"))
	_frame(Rect2(8, 5, 64, 13), INK, Color("#997599"), 2)
	_frame(Rect2(9, 21, 62, 34), INK, Color("#785686"), 2)
	for y in range(23, 53, 5):
		for x in range(11, 69, 6):
			var shade: Color = (Color("#a37aad") if (x + y) % 2 == 0 else Color("#845e92"))
			_plane(Rect2(x, y, 5, 4), shade)
	for band in (9 if _turn % 2 == 0 else 12):
		var segment := Rect2(28, 8 + band, 24, 1) if _turn % 2 == 0 else Rect2(28 + band * 2, 8, 2, 9)
		_begin_piece()
		_plane(segment, INK, 4)
		_plane(segment.intersection(Rect2(30, 9, 20, 5)), PLUM, 5)
		_end_piece("club_booth", segment.get_center())
	for x in [34, 46]:
		_begin_piece()
		_oval(Rect2(x - 3, 9, 6, 5), BLUE, 5)
		_plane(Rect2(x, 11, 1, 1), IVORY, 5)
		_end_piece("club_decks", Vector2(x, 11.5), 0.3)
	for x in [12, 68]:
		_begin_piece()
		_upright(Vector2(x, 12), 4, 17, INK)
		_upright(Vector2(x, 12), 1, 16, AQUA)
		_end_piece("club_truss_post", Vector2(x, 12))
		_begin_piece()
		_upright(Vector2(x, 17), 6, 10, PLUM)
		_upright(Vector2(x, 17), 3, 4, INK, 3)
		_end_piece("club_speaker", Vector2(x, 17))
	for x in range(12, 68, 4):
		_begin_piece()
		_edgeline(Vector2(x, 8), Vector2(x + 4, 8), INK, 17, 3)
		_end_piece("club_truss", Vector2(x + 2, 8))
	for lamp: Vector3 in CLUB_LAMPS:
		_begin_piece()
		_block(_xyz(lamp) - Vector2(2, 1), Vector2(5, 4), INK)
		_block(_xyz(lamp) - Vector2(1, 0), Vector2(3, 2), GOLD)
		_end_piece("club_lamp", Vector2(lamp.x, lamp.y))
	_gate(PLUM)
