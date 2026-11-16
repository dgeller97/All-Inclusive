extends RefCounted
## Offshore trajectories are decided at birth and shared by the renderer and shore accounting.

const Landscape := preload("res://scripts/landscape_model.gd")
const Calendar := preload("res://scripts/resort_calendar.gd")
const DEFAULT_SEED := 7219
const UNITS_PER_PERCENT := 100
const MAX_DEPOSIT := 100 * UNITS_PER_PERCENT
const MAX_FLIGHT := 108
const PULSE_SECONDS := 4
const FORCED_LANE := 8
const WORLD := Landscape.WORLD_BOUNDS


static func births(clock: int, climate_day: int, seed: int, intensity: int, immediate: bool = false) -> Array[Dictionary]:
	var rafts: Array[Dictionary] = []
	if clock < 0 or not immediate and clock % PULSE_SECONDS != 0:
		return rafts
	var pressure: float = Calendar.state(climate_day, 0).sargassum_pressure if intensity == -1 else intensity / 100.0
	if pressure <= 0.0:
		return rafts
	var weather := _weather(clock, seed)
	for lane in range(PULSE_SECONDS):
		var intensity_at_birth := clampf(pressure * lerpf(0.75, 1.3, weather), 0.0, 1.0)
		if _noise(clock * 13 + lane * 7 + 3, seed) < intensity_at_birth:
			rafts.append(raft(clock, lane, seed))
	return rafts


static func raft(clock: int, lane: int, seed: int) -> Dictionary:
	var id := clock * 16 + lane
	var weather := _weather(clock, seed)
	var rows := int(WORLD.size.y) - 64
	var row := int(WORLD.position.y) + 32 + posmod(clock * 43 + lane * 233 + seed, rows)
	var width := roundi(lerpf(8.0, 49.0, pow(_noise(id + 41, seed), lerpf(1.65, 0.75, weather))))
	var height := roundi(lerpf(5.0, 25.0, clampf(width / 62.0 + _noise(id + 112, seed) * 0.37, 0.0, 1.0)))
	return {"id": id, "born_at": clock, "lands_at": clock + roundi(lerpf(72, MAX_FLIGHT, _noise(id + 14, seed))),
		"row": row, "size": Vector2(width, height), "variant": floori(_noise(id + 170, seed) * 8.0),
		"origin_x": WORLD.end.x - 28.0 - roundf(_noise(id + 87, seed) * 32.0),
		"weather": weather, "drift": roundi(lerpf(-19, 19, _noise(id + 254, seed))),
		"mass": clampi(roundi(width * height / 20.0), 4, 38)}


static func sample(rafts: Array, clock: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var coast := Landscape.coastline()
	for patch: Dictionary in rafts:
		var age: float = clock - patch.born_at
		var duration: int = patch.lands_at - patch.born_at
		if age < 0.0 or age >= duration:
			continue
		var progress := age / duration
		var row: int = patch.row + roundi(sin(progress * PI) * patch.drift)
		var shore_x := coast[row - int(WORLD.position.y)]
		var x := lerpf(maxf(shore_x + 12.0, patch.origin_x), shore_x + 2.0, progress)
		var opacity := minf(clampf((age + 2.0) / 7.0, 0.0, 1.0), clampf((duration - age) / 1.25, 0.0, 1.0))
		result.append({"id": patch.id, "point": Vector2(roundf(x), row), "progress": progress,
			"opacity": opacity, "variant": patch.variant, "size": patch.size, "weather": patch.weather})
	return result


static func legacy_deposits(amount: int) -> Array[Dictionary]:
	var deposits: Array[Dictionary] = []
	var total := clampi(amount, 0, 100) * UNITS_PER_PERCENT
	if total == 0:
		return deposits
	var rows := 24
	for index in rows:
		var row := roundi(WORLD.position.y + WORLD.size.y * (float(index) + 0.5) / rows)
		deposits.append({"row": row, "amount": total / rows + int(index < total % rows)})
	return deposits


static func deposit_total(deposits: Array) -> int:
	var total := 0
	for pile: Dictionary in deposits:
		total += int(pile.amount)
	return total


static func amount(deposits: Array) -> int:
	return ceili(float(deposit_total(deposits)) / UNITS_PER_PERCENT)


static func deposit(deposits: Array[Dictionary], row: int, mass: int) -> void:
	var room := MAX_DEPOSIT - deposit_total(deposits)
	if room < mass:
		# At saturation, keep current landfalls visible as old material is washed out.
		remove(deposits, mass - room)
	for pile in deposits:
		if pile.row == row:
			pile.amount += mass
			return
	deposits.append({"row": row, "amount": mass})


static func remove(deposits: Array[Dictionary], mass: int) -> void:
	while mass > 0 and not deposits.is_empty():
		var pile := deposits[0]
		var removed := mini(pile.amount, mass)
		pile.amount -= removed
		mass -= removed
		if pile.amount == 0:
			deposits.pop_front()


static func wash(deposits: Array[Dictionary]) -> void:
	for index in range(deposits.size() - 1, -1, -1):
		var pile := deposits[index]
		pile.amount -= maxi(1, ceili(pile.amount * 0.18))
		if pile.amount <= 0:
			deposits.remove_at(index)


static func valid_deposits(value: Variant) -> bool:
	if not value is Array or value.size() > int(WORLD.size.y):
		return false
	var rows := {}
	for pile in value:
		if not pile is Dictionary or not pile.get("row") is int or not pile.get("amount") is int:
			return false
		if pile.row < int(WORLD.position.y) or pile.row >= int(WORLD.end.y) or pile.amount < 1 or pile.amount > MAX_DEPOSIT or rows.has(pile.row):
			return false
		rows[pile.row] = true
	return deposit_total(value) <= MAX_DEPOSIT


static func valid_rafts(value: Variant, clock: int, seed: int) -> bool:
	if not value is Array or value.size() > MAX_FLIGHT * (PULSE_SECONDS + 1):
		return false
	var ids := {}
	for entry in value:
		if not entry is Dictionary or not entry.get("id") is int or entry.id < 0 or ids.has(entry.id):
			return false
		var birth: int = entry.id / 16
		var lane: int = entry.id % 16
		if birth > clock or birth + MAX_FLIGHT <= clock or lane not in [0, 1, 2, 3, FORCED_LANE]:
			return false
		if entry != raft(birth, lane, seed) or entry.lands_at <= clock:
			return false
		ids[entry.id] = true
	return true


static func _weather(clock: int, seed: int) -> float:
	var front := clock / 143
	var within := smoothstep(0.0, 143.0, float(clock % 143))
	return lerpf(_noise(front * 19 + 12354, seed), _noise((front + 1) * 19 + 12354, seed), within)


static func _noise(key: int, seed: int) -> float:
	var word := posmod(key * 374761393 + seed * 668265263, 4294967291)
	word = ((word ^ (word >> 13)) * 1274126177) & 0xffffffff
	return float((word ^ (word >> 16)) & 0xffff) / 65536.0
