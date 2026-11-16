extends RefCounted
## Builds isolated, ordinary layouts and supplies the phase records read by ResortMap.

const Sim := preload("res://scripts/simulation.gd")
const Layout := preload("res://scripts/layout_model.gd")
const CORE_CLIPS := {
	"dining": "Dining table",
	"buffet_collection": "Buffet collection",
	"main_pool": "Main pool",
	"walking": "Walking to a room",
	"ocean_swim": "Ocean swimming",
	"ocean_evacuation": "Red-flag evacuation",
}
const SPOT := Vector2i(-24, 17)
const WALK_ORIGIN := Vector2(-424, 8)
const WALK_SIZE := Vector2(240, 240)


static func catalog() -> Dictionary:
	var entries := CORE_CLIPS.duplicate()
	for group: Array in Layout.Landscape.FACILITY_GROUPS.values():
		for kind: String in group:
			entries[kind] = Layout.Landscape.PROP_CATALOG[kind].label
	return entries


static func fixed_coast(clip: String) -> bool:
	return clip in ["ocean_swim", "ocean_evacuation"]


static func phases(clip: String) -> Array[Dictionary]:
	if Sim.LEISURE_DURATIONS.has(clip):
		return [
			_phase("approach", "Approach", "to_leisure", Sim.LEISURE_WALK_DURATION),
			_phase("activity", "Activity", "leisure", Sim.LEISURE_DURATIONS[clip]),
			_phase("departure", "Departure", "from_leisure", Sim.LEISURE_WALK_DURATION),
		]
	match clip:
		"dining":
			return [
				_phase("approach", "Carrying food", "to_table", Sim.TABLE_WALK_DURATION),
				_phase("activity", "Eating", "eating", Sim.EAT_DURATION),
				_phase("departure", "Leaving the table", "to_pool", 4),
			]
		"buffet_collection":
			return [
				_phase("approach", "Approach", "to_buffet", 4),
				_phase("activity", "Collecting food", "service", Sim.DURATIONS[1]),
				_phase("departure", "Carrying food", "to_table", Sim.TABLE_WALK_DURATION),
			]
		"main_pool":
			return [
				_phase("approach", "Approach", "to_pool", 4),
				_phase("activity", "Swimming", "service", Sim.DURATIONS[2]),
				_phase("departure", "Departure", "return_room", 4),
			]
		"walking":
			return [_phase("activity", "Walking", "to_room", 4)]
		"ocean_swim":
			return [
				_phase("approach", "Walk to shore", "to_ocean", Sim.OCEAN_WALK_DURATION),
				_phase("activity", "Wade and swim", "ocean_swim", Sim.OCEAN_SWIM_DURATION),
				_phase("departure", "Return to shore", "from_ocean", Sim.OCEAN_WALK_DURATION + Sim.OCEAN_WADE_DURATION),
			]
		"ocean_evacuation":
			return [_phase("activity", "Evacuation", "evacuate", Sim.OCEAN_WALK_DURATION + Sim.OCEAN_WADE_DURATION)]
	return []


static func _phase(id: String, label: String, family_phase: String, length: int) -> Dictionary:
	return {"id": id, "label": label, "family_phase": family_phase, "length": float(length)}


static func build_panels(clip: String) -> Array[Dictionary]:
	# Allocators are shared by all Layout instances, including the active game.
	# Inspector models never become live layouts, so the allocator can be restored.
	var layout_id := Layout._next_id
	var prop_id := Layout.Landscape._next_prop_id
	var panels: Array[Dictionary] = []
	for turn in range(1 if fixed_coast(clip) else 4):
		var panel := _build(clip, turn)
		if panel.is_empty():
			panels.clear()
			break
		panels.append(panel)
	Layout._next_id = layout_id
	Layout.Landscape._next_prop_id = prop_id
	return panels


static func _build(clip: String, turn: int) -> Dictionary:
	var sim := Sim.new()
	var plan := sim.layout
	var fixture := {"sim": sim, "rotation": turn, "focus_id": -1, "bounds": Rect2(), "tables": [],
		"capacity": 1, "station": 0, "base_time": 81, "time": 81.0, "phase": {}}
	if not fixed_coast(clip):
		for prop in plan.landscape.props.duplicate():
			plan.remove_prop(prop.id)
	if Sim.LEISURE_DURATIONS.has(clip):
		var added := plan.add_prop(clip, SPOT, turn)
		if not added.ok:
			return {}
		var venue := plan.amenity_by_id(added.id)
		if venue.is_empty():
			return {}
		fixture.focus_id = venue.id
		fixture.capacity = venue.capacity
		fixture.bounds = plan.prop_visual_rect(plan.landscape.prop_by_id(venue.id))
		fixture.base_time = Sim.SHOW_START - Sim.LEISURE_WALK_DURATION if clip in Sim.NIGHTLIFE else 81
	elif not _build_core(clip, turn, fixture):
		return {}
	sim._reset_room_slots()
	fixture.tables = plan.dining_tables()
	if clip == "dining":
		if fixture.tables.size() < 2:
			return {}
		fixture.capacity = fixture.tables.size()
	return fixture


static func _build_core(clip: String, turn: int, fixture: Dictionary) -> bool:
	var sim: Sim = fixture.sim
	var plan := sim.layout
	match clip:
		"dining", "buffet_collection":
			var buffet := _building(plan, "buffet")
			for asset: Dictionary in plan.assets.duplicate():
				if asset.building_id == buffet.id and asset.kind == ("table" if clip == "dining" else "counter"):
					plan.remove_asset(asset.id)
			if clip == "dining":
				for cell: Vector2i in [Vector2i(6, 3), Vector2i(11, 3)]:
					var placed := plan.add_asset("table", buffet.id, cell, turn)
					if not placed.ok:
						return false
					var bounds := plan.asset_rect({"kind": "table", "building_id": buffet.id, "cell": [cell.x, cell.y], "rotation": turn})
					fixture.bounds = bounds if not fixture.bounds.has_area() else fixture.bounds.merge(bounds)
					if fixture.focus_id == -1:
						fixture.focus_id = placed.id
			else:
				var counter := plan.add_asset("counter", buffet.id, Vector2i(3, 2), turn)
				if not counter.ok:
					return false
				fixture.focus_id = counter.id
				fixture.bounds = plan.asset_rect({"kind": "counter", "building_id": buffet.id, "cell": [3, 2], "rotation": turn}).grow(11)
				fixture.station = 1
				fixture.capacity = sim.capacity(1)
		"main_pool":
			var pool := _building(plan, "pool")
			for item in [["lounger", Vector2i(1, 2)], ["lounger", Vector2i(16, 2)], ["umbrella", Vector2i(2, 7)]]:
				if not plan.add_asset(item[0], pool.id, item[1]).ok:
					return false
			for step in range(turn):
				if not plan.rotate_building(pool.id).ok:
					return false
			var rotated_pool := plan.building_by_id(pool.id)
			sim.float_station = 2
			sim.terrace = plan.readiness().terrace
			fixture.focus_id = pool.id
			fixture.capacity = sim.capacity(2)
			fixture.station = 2
			fixture.bounds = plan.building_rect(rotated_pool)
		"walking":
			return _walking(plan, turn, fixture)
		"ocean_swim", "ocean_evacuation":
			var access := plan.ocean_access()
			if access.is_empty():
				return false
			fixture.bounds = Rect2(access.shore - Vector2(22, 17), Vector2(90, 48))
			fixture.capacity = 4 if clip == "ocean_swim" else 1
			fixture.base_time = 95 if clip == "ocean_swim" else 51
	return fixture.bounds.has_area()


static func _walking(plan: Layout, turn: int, fixture: Dictionary) -> bool:
	for building in plan.buildings.duplicate():
		if building.kind in ["reception", "bedroom"]:
			plan.remove_building(building.id)
	var lobby := plan.add_building("reception", _walk_rect(plan, Rect2(24, 96, 64, 48), turn), turn)
	if not lobby.ok or not _walk_furnishing(plan, "desk", lobby.id, Vector2(64, 48), turn):
		return false
	var bounds := plan.building_rect(plan.building_by_id(lobby.id))
	for y in [96, 32, 160]:
		var room := plan.add_building("bedroom", _walk_rect(plan, Rect2(160, y, 48, 48), turn), turn)
		if not room.ok or not _walk_furnishing(plan, "bed", room.id, Vector2(48, 48), turn):
			return false
		bounds = bounds.merge(plan.building_rect(plan.building_by_id(room.id)))
	var rooms := plan.room_points()
	if rooms.size() != 3:
		return false
	fixture.focus_id = lobby.id
	fixture.capacity = rooms.size()
	fixture.bounds = bounds
	return true


static func _walk_rect(plan: Layout, local: Rect2, turn: int) -> Rect2:
	for step in range(turn):
		local = plan._rotate_rect(local, WALK_SIZE)
	local.position += WALK_ORIGIN
	return local


static func _walk_furnishing(plan: Layout, kind: String, id: int, room: Vector2, turn: int) -> bool:
	var local := Rect2(Vector2.ONE * Layout.GRID, Vector2(plan.asset_size(kind)) * Layout.GRID)
	for step in range(turn):
		local = plan._rotate_rect(local, room)
		room = Vector2(room.y, room.x)
	return plan.add_asset(kind, id, Vector2i(local.position / Layout.GRID), turn).ok


static func _building(plan: Layout, kind: String) -> Dictionary:
	for building: Dictionary in plan.buildings:
		if building.kind == kind:
			return building
	return {}


static func sample(fixture: Dictionary, clip: String, phase: Dictionary, age: float,
		sequence_offset: float, full: bool, variant: int) -> void:
	var sim: Sim = fixture.sim
	var start: float = fixture.base_time + sequence_offset
	var time := start + age
	fixture.time = time
	fixture.phase = phase
	sim.second = floori(time)
	sim.families.clear()
	var count: int = fixture.capacity if full else 1
	for slot in range(count):
		var id := variant + slot * 3
		var record := {
			"id": id, "room": slot % sim.rooms.size(), "station": fixture.station, "phase": phase.family_phase,
			"since": start, "until": start + phase.length, "joined": start,
			"waits": [0, 0, 0], "upgraded_swim": sim.terrace, "slot": slot,
			"table_id": -1, "dining_wait": 1.0,
		}
		record.merge(Sim.LEISURE_DEFAULTS)
		record.merge(Sim.OCEAN_DEFAULTS)
		if Sim.LEISURE_DURATIONS.has(clip):
			record.amenity_id = fixture.focus_id
			record.leisure_kind = clip
			record.leisure_slot = slot
			record.leisure_step = 3 if clip in Sim.NIGHTLIFE else 2 if clip in Sim.REFRESHMENTS else 1
		if clip in ["dining", "buffet_collection", "main_pool"] and not fixture.tables.is_empty():
			record.table_id = fixture.tables[slot % fixture.tables.size()].id
		if fixed_coast(clip):
			record.ocean_return_wet = true
			record.ocean_fatality = clip == "ocean_evacuation"
		sim.families.append(record)
