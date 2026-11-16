extends RefCounted
## A seat anchor is the ground under the sitter's feet. The upper body keeps
## its atlas dimensions. Only the legs and the chair are projected separately.

const WIDTH := 11
const ADULT_HEIGHT := 16
const CHILD_HEIGHT := 12
const ADULT_LIFT := 18
const CHILD_LIFT := 13
const CHILD_BOOSTER := 2.0


static func upper_body(ground: Vector2, child: bool, booster: float = 0.0) -> Rect2:
	var height := float(CHILD_LIFT if child else ADULT_LIFT) + booster
	return Rect2(ground.round() - Vector2(5, height),
		Vector2(WIDTH, CHILD_HEIGHT if child else ADULT_HEIGHT))


static func source(row: int, child: bool) -> Rect2:
	return Rect2(5, row * 24 + (7 if child else 1), WIDTH, CHILD_HEIGHT if child else ADULT_HEIGHT)


static func mouth(ground: Vector2, facing: float, child: bool, booster: float = 0.0) -> Vector2:
	return ground + Vector2(facing * 2.0, (-7.0 if child else -10.0) - booster)


static func shoulder(ground: Vector2, facing: float, child: bool, booster: float = 0.0) -> Vector2:
	return ground + Vector2(facing * 3.0, (-4.0 if child else -6.0) - booster)
