extends RefCounted
## Native-size pixel geometry; all coordinates are world contact points.
const IVORY := Color("#fff0c8")
const SHADE := Color("#8c6860")
const RED := Color("#dd6556")
const DARK_RED := Color("#a44648")
const SKIN := Color("#e8af7b")
const HAIR := Color("#704e43")
const INK := Color("#483747")

static func post(block: Callable, foot: Vector2, facing: bool) -> void:
	var f := 1 if facing else -1
	var at := foot.round()
	block.call(Rect2(at + Vector2(-7, 0), Vector2(15, 2)), Color("#48374730"))
	for x in [-5, 4]:
		block.call(Rect2(at + Vector2(x, -12), Vector2(2, 13)), SHADE)
		block.call(Rect2(at + Vector2(x, -12), Vector2(1, 12)), IVORY)
	block.call(Rect2(at + Vector2(-6, -12), Vector2(13, 3)), IVORY)
	block.call(Rect2(at + Vector2(-6, -10), Vector2(13, 1)), RED)
	block.call(Rect2(at + Vector2(-f * 5 - 1, -22), Vector2(3, 12)), IVORY)
	for y in [-7, -3]:
		block.call(Rect2(at + Vector2(-3, y), Vector2(6, 1)), IVORY)
	# Rescue board hangs on the chair, below the seated guard.
	block.call(Rect2(at + Vector2(7, -9), Vector2(3, 8)), RED)
	block.call(Rect2(at + Vector2(8, -8), Vector2(1, 3)), IVORY)

static func guard(block: Callable, foot: Vector2, seated: bool, swimming: bool, facing: bool, time: float) -> void:
	var f := 1 if facing else -1
	var at := foot.round() - Vector2(0, 11 if seated else 0)
	if swimming:
		at.y += roundf(sin(time * 5.0 + foot.x) * 1.0)
		block.call(Rect2(at + Vector2(-7, 0), Vector2(15, 2)), Color("#b2f2e6"))
	var top := at - Vector2(0, 10 if swimming else 18)
	block.call(Rect2(top + Vector2(-3, 0), Vector2(6, 6)), HAIR)
	block.call(Rect2(top + Vector2(-2, 1), Vector2(5, 5)), SKIN)
	block.call(Rect2(top + Vector2(-4, 0), Vector2(8, 2)), IVORY)
	block.call(Rect2(top + Vector2(f * 3, 1), Vector2(3, 1)), RED)
	block.call(Rect2(top + Vector2(f, 3), Vector2(2, 1)), INK)
	block.call(Rect2(top + Vector2(-3, 6), Vector2(7, 6 if swimming else 7)), RED)
	block.call(Rect2(top + Vector2(-1, 7), Vector2(2, 4)), IVORY)
	block.call(Rect2(top + Vector2(-2, 8), Vector2(4, 2)), IVORY)
	if swimming:
		var stroke := roundf(sin(time * 7.0) * 2.0)
		block.call(Rect2(at + Vector2(-6, -5 + stroke), Vector2(3, 2)), SKIN)
		block.call(Rect2(at + Vector2(5, -5 - stroke), Vector2(3, 2)), SKIN)
	else:
		block.call(Rect2(top + Vector2(-5, 7), Vector2(2, 6)), SKIN)
		block.call(Rect2(top + Vector2(4, 7), Vector2(2, 6)), SKIN)
		block.call(Rect2(top + Vector2(-3, 13), Vector2(7, 3)), DARK_RED)
		if seated:
			block.call(Rect2(at + Vector2(-2 if facing else -6, -3), Vector2(8, 2)), SKIN)
			block.call(Rect2(at + Vector2(4 if facing else -6, -2), Vector2(2, 4)), SKIN)
		else:
			var stride := roundf(sin(time * 8.0))
			block.call(Rect2(at + Vector2(-3, -3), Vector2(2, 4 + stride)), SKIN)
			block.call(Rect2(at + Vector2(2, -3), Vector2(2, 4 - stride)), SKIN)

static func rescue_float(block: Callable, at: Vector2) -> void:
	var point := at.round()
	block.call(Rect2(point + Vector2(-5, -1), Vector2(11, 4)), DARK_RED)
	block.call(Rect2(point + Vector2(-4, -2), Vector2(9, 4)), RED)
	block.call(Rect2(point + Vector2(-3, -2), Vector2(2, 3)), IVORY)
	block.call(Rect2(point + Vector2(2, -2), Vector2(2, 3)), IVORY)
