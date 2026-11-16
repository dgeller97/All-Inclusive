extends SceneTree
## Observes real CanvasItem submissions in headless Godot. No framebuffer is read.

const ResortMap = preload("res://scripts/resort_map.gd")
const Preview = preload("res://scripts/animation_preview.gd")
const Viewer = preload("res://scripts/animation_viewer.gd")
const Sim = preload("res://scripts/simulation.gd")
const Amenity = preload("res://scripts/amenity_renderer.gd")
const Buildings := preload("res://scripts/building_renderer.gd")
const Furniture := preload("res://scripts/furniture_depth.gd")
const CORE_CLIPS := ["dining", "buffet_collection", "main_pool"]
const PHASE_SAMPLES := {"approach": [0.05, 0.95], "activity": [0.08, 0.46, 0.85], "departure": [0.05, 0.95]}
const HOLD_COLORS := [Color("#d57756"), Color("#4f7d99"), Color("#f2bb6f")]
const UPRIGHT_TAGS := {
	"beach_lounge": ["lounge_back", "lounge_parasol"],
	"volleyball": ["volleyball_net", "volleyball_post"],
	"beach_bar": ["bar_counter", "bar_post", "bar_canopy"],
	"stage": ["stage_post", "stage_truss", "stage_banner"],
	"lap_pool": ["pool_rail", "gate_post"],
	"lagoon_pool": ["pool_rail", "gate_post"],
	"hot_tub": ["tub_rim", "gate_post"],
	"kids_pool": ["gate_post"],
	"waterpark": ["slide_channel", "slide_rail", "slide_support", "slide_ladder"],
	"basketball": ["hoop_pole", "hoop_backboard", "hoop_rim"],
	"climbing_wall": ["climbing_rock", "climbing_anchor", "climbing_mat_post"],
	"arcade": ["arcade_cabinet", "gate_post"],
	"cafe": ["cafe_counter", "cafe_canopy", "cafe_table"],
	"nightclub": ["club_truss", "club_speaker", "club_lamp"],
	"dining": ["dining_table", "room_wall"],
	"buffet_collection": ["furniture_counter", "room_wall"],
	"main_pool": ["pool_edge", "pool_ladder", "furniture_umbrella"],
}

class DrawProbe extends ResortMap:
	var commands: Array[Dictionary] = []
	var sprites: Array[Dictionary] = []
	var plates: Array[Dictionary] = []
	var planted: Dictionary = {}
	var frames := 0
	var inline_rope_marks := 0
	var _drawing_actor := {}

	func _draw_depth_item(item: Dictionary) -> void:
		commands.append(item)
		super._draw_depth_item(item)

	func _draw_actor(actor: Dictionary) -> void:
		_drawing_actor = actor
		super._draw_actor(actor)
		_drawing_actor = {}

	func _pose(family: Dictionary) -> Dictionary:
		if not planted.has(family.id):
			return super._pose(family)
		var foot: Vector2 = planted[family.id]
		return {"point": foot, "child": foot + Vector2(12, 0), "frame": 0, "facing": true, "swim": false}

	func _draw_plate(at: Vector2, has_food: bool) -> void:
		plates.append({"point": at, "index": commands.size() - 1})
		super._draw_plate(at, has_food)

	func _actor_region(destination: Rect2, source: Rect2) -> void:
		if not _drawing_actor.is_empty():
			sprites.append({"actor": _drawing_actor, "target": destination, "source": source, "index": commands.size() - 1})
		super._actor_region(destination, source)

	func _actor_block(rect: Rect2, tint: Color) -> void:
		if _drawing_actor.get("facility_action", "") in ["climb", "belay"] and tint.is_equal_approx(Color("#f4cd85")):
			inline_rope_marks += 1
		super._actor_block(rect, tint)

	func clear_trace() -> void:
		commands.clear()
		sprites.clear()
		plates.clear()
		frames = 0
		inline_rope_marks = 0

	func record_frame() -> void:
		frames += 1


var checks := 0
var failures := 0
var audited := 0
var full_samples := 0
var single_samples := 0
var live_climbing := {}
var viewer_draws := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var clips := Sim.LEISURE_DURATIONS.keys() + CORE_CLIPS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip=") and arg.trim_prefix("--clip=") in clips:
			clips = [arg.trim_prefix("--clip=")]
			break
	for clip in clips:
		await _audit_clip(clip)
	if "climbing_wall" in clips:
		await _check_viewer_parity()
	if "dining" in clips:
		_check_furniture_colors()
	_check(audited == clips.size() * 4, "Each selected clip completed four-rotation audits")
	_check(full_samples == clips.size() * 28 and single_samples == clips.size() * 4, "Each rotation completed seven full phases and one single activity sample")
	print("Depth occlusion: %d checks, %d failures, %d clip-rotations, %d full samples, %d single samples" %
		[checks, failures, audited, full_samples, single_samples])
	quit(1 if failures else 0)


func _audit_clip(clip: String) -> void:
	var fixtures := Preview.build_panels(clip)
	var phases := Preview.phases(clip)
	_check(fixtures.size() == 4, "Real model fixtures exist for every turn of " + clip)
	_check(phases.size() == 3, "Approach, activity and departure are sampled for " + clip)
	if fixtures.size() != 4 or phases.size() != 3:
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := DrawProbe.new()
	viewport.add_child(map)
	map.actors.draw.connect(map.record_frame)
	for fixture in fixtures:
		var offset := 0.0
		map.position = Vector2(viewport.size) * 0.5 - fixture.bounds.get_center()
		for phase in phases:
			for fraction: float in PHASE_SAMPLES[phase.id]:
				var age := 5.47 if clip == "climbing_wall" and phase.id == "activity" and fraction == 0.46 else float(phase.length) * fraction
				await _render(map, fixture, clip, phase, age, offset)
				_check_phase(map, fixture, clip, phase, age, fixture.capacity)
				full_samples += 1
				if phase.id == "activity" and fraction == 0.46:
					_check_activity(map, fixture, clip)
					await _render(map, fixture, clip, phase, age, offset, false)
					_check_phase(map, fixture, clip, phase, age, 1)
					single_samples += 1
			offset += float(phase.length)
		if clip == "arcade":
			await _check_incidental_gate(map, fixture, phases[0])
		if clip == "dining":
			await _check_roof(map, fixture, phases[1])
		if clip == "volleyball" and int(fixture.rotation) % 2 == 1:
			await _check_volleyball_crossing(map, fixture, phases[1])
		audited += 1
	viewport.queue_free()
	await process_frame


func _render(map: DrawProbe, fixture: Dictionary, clip: String, phase: Dictionary, age: float, offset: float, full := true, exterior := false) -> void:
	Preview.sample(fixture, clip, phase, age, offset, full, 0)
	map.clear_trace()
	map.present(fixture.sim, fixture.time, null, false, exterior)
	map.actors.queue_redraw()
	await process_frame
	await process_frame


func _check_phase(map: DrawProbe, fixture: Dictionary, clip: String, phase: Dictionary, age: float, guests_expected: int) -> void:
	var context := "%s %d° %s at %.2fs with %d families" % [clip, fixture.rotation * 90, phase.id, age, guests_expected]
	_check(map.frames > 0 and not map.commands.is_empty(), "Actual production draw phase dispatches for " + context)
	_check(map.simulation.families.size() == guests_expected and map.simulation.families.all(func(family: Dictionary) -> bool:
		return family.phase == phase.family_phase), "Production phase and reservation count: " + context)
	var guests := map.sprites.filter(func(record: Dictionary) -> bool: return record.actor.row != 3)
	_check(guests.size() >= guests_expected * 2, "Production submits each adult and child before spatial occlusion: " + context)
	var previous := -INF
	var ordered := true
	for record in guests:
		var ground: Vector2 = record.actor.ground
		ordered = ordered and ground.is_finite() and ground.y >= previous
		previous = ground.y
	_check(ordered, "Actor overlap follows ground support rather than raised sprite Y: " + context)


func _check_activity(map: DrawProbe, fixture: Dictionary, clip: String) -> void:
	for tag: String in UPRIGHT_TAGS[clip]:
		var layers := _indices(map, tag)
		_check(not layers.is_empty() and layers.all(func(index: int) -> bool:
			return map.commands[index].get("texture") != null and map.commands[index].bounds.has_area()),
			"The %s surface is a real textured depth part for %s at %d°" % [tag, clip, int(fixture.rotation) * 90])
	match clip:
		"climbing_wall": _check_climbing(map, fixture)
		"arcade": _check_arcade(map, fixture)
		"hot_tub": _check_tub(map, fixture)
		"dining": _check_dining(map, fixture)
		"main_pool": _check_main_pool(map, fixture)
		"basketball":
			var balls := _indices(map, "basketball_ball")
			_check(balls.size() == 2 and balls.any(func(index: int) -> bool:
				var ball: Dictionary = map.commands[index]
				return ball.depth > ball.point.y + 12.0), "A raised basketball uses its ground path, not its screen height, for depth")
		"volleyball":
			_check(_indices(map, "volleyball_ball").size() == 1, "The single ball is submitted separately from the volleyball players")
		"waterpark":
			var slide := _indices(map, "slide_")
			var riders := map.sprites.filter(func(sprite: Dictionary) -> bool: return sprite.actor.get("facility_action", "") == "slide")
			_check(riders.size() == 3 and riders.any(func(sprite: Dictionary) -> bool:
				var pieces := _find_coverage(map, sprite, slide)
				return pieces.opaque > pieces.covered), "Foreground supports never conceal every rider in the full waterpark")
		"stage":
			_check(_indices(map, "stage_performer").size() == 1, "The stage performer has a separate contact-depth draw")
		"nightclub":
			_check(_indices(map, "club_lights").size() == 4, "The club's lamps and booth effects submit independently")


func _check_climbing(map: DrawProbe, fixture: Dictionary) -> void:
	var turn: int = fixture.rotation
	live_climbing[turn] = _draw_signature(map.commands)
	var context := "climbing 5.47s at %d°" % (turn * 90)
	var venue: Dictionary = map.amenities[fixture.focus_id]
	var front := turn < 2
	var art := Amenity.layers(venue.kind, turn).filter(func(piece: Dictionary) -> bool: return str(piece.tag).begins_with("climbing_rock"))
	var holds := 0
	for piece in art:
		var image: Image = piece.image
		for row in image.get_height():
			for column in image.get_width():
				var color := image.get_pixel(column, row)
				if color.a > 0.5 and HOLD_COLORS.any(func(bright: Color) -> bool: return bright.to_html(false) == color.to_html(false)):
					holds += 1
	_check(not art.is_empty() and (holds > 0 if front else holds == 0), "Colored climbing holds belong to the readable front face: " + context)
	var climber := _action_sprite(map, "climb")
	var belayer := _action_sprite(map, "belay")
	_check(not climber.is_empty() and not belayer.is_empty() and map.inline_rope_marks == 0,
		"Climber, belayer and their props use separate real draw submissions: " + context)
	if climber.is_empty() or belayer.is_empty():
		return
	var rock := _indices(map, "climbing_rock")
	var figure_coverage := _find_coverage(map, climber, rock)
	var belay_coverage := _find_coverage(map, belayer, rock)
	if turn == 0:
		_check(belay_coverage.covered == 0 and rock.all(func(index: int) -> bool: return index < belayer.index),
			"The lower belayer remains in front of the wall in front view: " + context)
	elif turn == 2:
		_check(belay_coverage.covered + figure_coverage.covered > 0,
			"The rear wall really covers overlapping opaque actor texels: " + context)
	elif turn % 2 == 1:
		_check(rock.any(func(index: int) -> bool: return index < climber.index)
			and rock.any(func(index: int) -> bool: return index > climber.index),
			"The visible side wall spans far and near depths around the lifted climber: " + context)
		if turn == 3:
			_check(figure_coverage.covered > 0 and belay_coverage.covered == 0,
				"Rear side masks the climber's overlap and leaves the unobstructed belayer visible: " + context)
	var rope := _indices(map, "climbing_rope")
	var supports := {}
	var marks_over_rock := 0
	var occluded_marks := 0
	for index in rope:
		var segment := map.commands[index]
		supports[segment.depth] = true
		if rock.any(func(face: int) -> bool: return _piece_covers(map.commands[face], Vector2i(segment.point))):
			marks_over_rock += 1
		if rock.any(func(face: int) -> bool: return face > index and _piece_covers(map.commands[face], Vector2i(segment.point))):
			occluded_marks += 1
	_check(rope.size() > 1 and supports.size() > 1, "Rope is segmented for varying physical depth: " + context)
	if turn == 2:
		_check(marks_over_rock > 0 and occluded_marks == marks_over_rock,
			"The rear wall covers exactly the rope segments behind its silhouette: " + context)
	elif turn == 3:
		_check(occluded_marks > 0 and occluded_marks < rope.size(),
			"Rear rock occludes only the rope overlap: %s (%d covered, %d overlap, %d submitted)" % [context, occluded_marks, marks_over_rock, rope.size()])


func _check_arcade(map: DrawProbe, fixture: Dictionary) -> void:
	var turn: int = fixture.rotation
	var cabinet := _indices(map, "arcade_cabinet")
	var player := _action_sprite(map, "arcade", 0, 4)
	_check(cabinet.size() == 4 and not player.is_empty(), "Every arcade station has its own cabinet geometry at %d°" % (turn * 90))
	if player.is_empty():
		return
	var coverage := _find_coverage(map, player, cabinet)
	if turn == 0:
		_check(coverage.covered == 0, "South-facing players appear in front of their cabinets")
	elif turn == 2:
		_check(coverage.covered > 0 and coverage.covered < coverage.opaque, "North-facing players are partly behind their cabinets")
	else:
		_check(cabinet.any(func(index: int) -> bool: return index < player.index)
			and cabinet.any(func(index: int) -> bool: return index > player.index), "Side-view cabinets span distinct actor depths")


func _check_tub(map: DrawProbe, fixture: Dictionary) -> void:
	var rims := _indices(map, "tub_rim")
	var venue: Dictionary = map.amenities[fixture.focus_id]
	var center := Vector2i(Amenity.at(venue, Vector2(20, 17)))
	_check(rims.size() > 1 and rims.all(func(index: int) -> bool: return not _piece_covers(map.commands[index], center)),
		"Raised near rim has an opening over the tub water at %d°" % (int(fixture.rotation) * 90))
	_check(map.sprites.any(func(record: Dictionary) -> bool: return record.actor.get("swim", false)), "Soaker still submits a genuine swimmer crop")


func _check_dining(map: DrawProbe, fixture: Dictionary) -> void:
	var tables := _indices(map, "dining_table")
	var plates_above := not map.plates.is_empty()
	for plate in map.plates:
		for index in tables:
			if index > plate.index and _piece_covers(map.commands[index], Vector2i(plate.point.round())):
				plates_above = false
	_check(map.plates.size() >= int(fixture.capacity) * 2 and plates_above,
		"Every dinner place setting remains on top of overlapping table pixels at %d°" % (int(fixture.rotation) * 90))


func _check_main_pool(map: DrawProbe, fixture: Dictionary) -> void:
	var rims := _indices(map, "pool_edge")
	var water := Vector2i(map.pool_water.get_center())
	var no_slab := not rims.is_empty() and rims.all(func(index: int) -> bool: return not _piece_covers(map.commands[index], water))
	_check(no_slab and map.sprites.any(func(sprite: Dictionary) -> bool: return sprite.actor.get("swim", false)),
		"Near pool coping doesn't repaint the water or suppress the actual swims at %d°" % (int(fixture.rotation) * 90))


func _check_volleyball_crossing(map: DrawProbe, fixture: Dictionary, phase: Dictionary) -> void:
	# The low end is over the left player at 0.24 s and over the right player at
	# 1.75 s in this fixed fixture. Turning the court reverses which is screen-near.
	var low_first := int(fixture.rotation) == 1
	for age: float in [0.24, 1.75]:
		await _render(map, fixture, "volleyball", phase, age, 4.0)
		var net := _indices(map, "volleyball_net")
		var ball := _indices(map, "volleyball_ball")
		var far_side := low_first == (age == 0.24)
		_check(not net.is_empty() and ball.size() == 1 and (ball[0] < net.front() if far_side else ball[0] > net.back()),
			"The ball crosses the net's physical depth at %d° and %.2f seconds" % [int(fixture.rotation) * 90, age])


func _check_incidental_gate(map: DrawProbe, fixture: Dictionary, phase: Dictionary) -> void:
	var venue: Dictionary = fixture.sim.layout.amenity_by_id(fixture.focus_id)
	var gate := Amenity.at(venue, Vector2(22, 37))
	# South is the screen-near side in every turn. The gate contact is known
	# from the physical post, independent of the computed painter order.
	map.planted = {0: gate - Vector2(0, 2), 3: gate + Vector2(0, 3)}
	await _render(map, fixture, "arcade", phase, float(phase.length) * 0.95, 0.0)
	var far := _sprite_at(map, map.planted[0])
	var near := _sprite_at(map, map.planted[3])
	map.planted.clear()
	var posts := _indices(map, "gate_post")
	_check(not far.is_empty() and not near.is_empty() and far.actor.leisure == "" and near.actor.leisure == "",
		"Gate boundary probe submits two passers with no activity tag")
	if far.is_empty() or near.is_empty():
		return
	var far_occlusion := _find_coverage(map, far, posts)
	var near_occlusion := _find_coverage(map, near, posts)
	_check(far_occlusion.covered > 0 and near_occlusion.overlap > 0 and near_occlusion.covered == 0,
		"A real gate post covers the far passer while the near passer remains in front at %d°" % (int(fixture.rotation) * 90))


func _check_roof(map: DrawProbe, fixture: Dictionary, phase: Dictionary) -> void:
	var room: Dictionary = fixture.sim.layout.building_at(fixture.sim.layout.station_point(1))
	var bounds: Rect2 = fixture.sim.layout.building_rect(room)
	await _render(map, fixture, "dining", phase, 5.0, 4.0, true, true)
	_check(not _indices(map, "exterior").is_empty() and map.sprites.all(func(record: Dictionary) -> bool: return record.actor.row == 3),
		"Exterior view draws the opaque roof and hides diners under it")
	map.planted = {0: Vector2(bounds.get_center().x, bounds.position.y - 2),
		3: Vector2(bounds.get_center().x, bounds.end.y + 3)}
	await _render(map, fixture, "dining", phase, 5.0, 4.0, true, true)
	var far := _sprite_at(map, map.planted[0])
	var near := _sprite_at(map, map.planted[3])
	map.planted.clear()
	var roofs := _indices(map, "exterior")
	_check(not far.is_empty() and not near.is_empty(), "Both outside visitors are submitted and sorted against the roof")
	if far.is_empty() or near.is_empty():
		return
	var far_occlusion := _find_coverage(map, far, roofs)
	var near_occlusion := _find_coverage(map, near, roofs)
	_check(far_occlusion.covered > 0 and near_occlusion.covered == 0,
		"Exterior overhang covers a far outside visitor and leaves a front visitor visible")


func _sprite_at(map: DrawProbe, foot: Vector2) -> Dictionary:
	for sprite in map.sprites:
		if sprite.actor.row < 3 and sprite.actor.ground.is_equal_approx(foot):
			return sprite
	return {}


func _indices(map: DrawProbe, prefix: String) -> Array[int]:
	var result: Array[int] = []
	for index in range(map.commands.size()):
		if str(map.commands[index].get("tag", "")).begins_with(prefix):
			result.append(index)
	return result


func _action_sprite(map: DrawProbe, action: String, slot := -1, row := -1) -> Dictionary:
	for sprite in map.sprites:
		if sprite.actor.get("facility_action", "") == action and (slot == -1 or sprite.actor.leisure_slot == slot) and (row == -1 or sprite.actor.row == row):
			return sprite
	return {}


func _find_coverage(map: DrawProbe, sprite: Dictionary, pieces: Array[int]) -> Dictionary:
	var atlas := map.people.get_image()
	var target: Rect2 = sprite.target
	var source: Rect2 = sprite.source
	var opaque := 0
	var overlap := 0
	var covered := 0
	for row in range(int(source.size.y)):
		for column in range(int(source.size.x)):
			# Godot flips a negative texture width in place. Its destination origin stays put.
			var texture_column := int(source.size.x) - 1 - column if target.size.x < 0.0 else column
			var texel := Vector2i(source.position) + Vector2i(texture_column, row)
			if atlas.get_pixelv(texel).a < 0.5:
				continue
			opaque += 1
			var world := Vector2i(target.position) + Vector2i(column, row)
			var intersects := false
			var overwritten := false
			for index in pieces:
				if _piece_covers(map.commands[index], world):
					intersects = true
					overwritten = overwritten or index > sprite.index
			overlap += int(intersects)
			covered += int(overwritten)
	return {"opaque": opaque, "overlap": overlap, "covered": covered}


func _piece_covers(item: Dictionary, world: Vector2i) -> bool:
	var image: Image = item.get("image")
	if not image:
		return false
	var bounds: Rect2 = item.bounds
	var local := world - Vector2i(bounds.position)
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(local) and image.get_pixelv(local).a > 0.5


func _check_viewer_parity() -> void:
	var viewer := Viewer.new()
	root.add_child(viewer)
	viewer.show_viewer()
	viewer.set_playing(false)
	viewer.select_clip("climbing_wall")
	viewer.select_phase("activity")
	viewer.set_full_occupancy(true)
	if viewer.panel_maps.size() != 4:
		_check(false, "The viewer exposes all four reported climbing layouts")
		viewer.queue_free()
		await process_frame
		return
	for turn in range(4):
		var map: ResortMap = viewer.panel_maps[turn]
		map.actors.draw.connect(_record_viewer_draw.bind(turn))
	viewer.seek(5.47)
	await process_frame
	await process_frame
	_check(viewer_draws.size() == 4, "The actual viewer dispatches all four production climbing draws at the reported frame")
	for turn in range(4):
		var map: ResortMap = viewer.panel_maps[turn]
		_check(map.get_script() == ResortMap and _draw_signature(map._depth_plan()) == live_climbing.get(turn, []),
			"Viewer uses exactly the same depth submission as the ordinary resort at %d°" % (turn * 90))
	viewer.close()
	viewer.queue_free()
	await process_frame


func _record_viewer_draw(turn: int) -> void:
	viewer_draws[turn] = true


func _draw_signature(commands: Array[Dictionary]) -> Array:
	return commands.map(func(item: Dictionary) -> Array: return [item.kind, item.tag, item.depth, item.bounds])


func _check_furniture_colors() -> void:
	var atlas := Buildings.FURNITURE.get_image()
	for kind: String in ["table", "counter", "umbrella"]:
		var size: Array = Sim.Layout.ASSET_CATALOG[kind].size
		var canonical := Vector2(size[0] * Sim.Layout.GRID, size[1] * Sim.Layout.GRID)
		for turn in range(4):
			var footprint := Vector2(canonical.y, canonical.x) if turn % 2 else canonical
			var original := atlas.get_region(Rect2i(Buildings.furniture_source(kind, turn, footprint)))
			var strata := Furniture.data(kind, turn)
			var joined: Image = strata.base_image.duplicate()
			for layer in strata.layers:
				var image: Image = layer.image
				var old_atlas_offset := Vector2i(layer.offset + Buildings.FURNITURE_LIFT)
				joined.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), old_atlas_offset)
			var matches := original.get_size() == joined.get_size()
			for y in original.get_height():
				for x in original.get_width():
					var expected := original.get_pixel(x, y)
					var actual := joined.get_pixel(x, y)
					matches = matches and is_equal_approx(expected.a, actual.a) and (expected.a == 0.0 or expected.to_html() == actual.to_html())
			_check(matches, "Splitting %s depth retains the original opaque atlas ink at %d°" % [kind, turn * 90])


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
