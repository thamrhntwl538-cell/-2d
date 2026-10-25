extends Node2D
## Exact user-supplied Archivist pixels, streamed one bounded frame at a time.
## Original foot pivot and source-coordinate hitboxes remain authoritative.
signal event_crossed(name: String)
signal animation_finished()

const ROOT := "res://assets/minibosses/m26_imported/"
const HEIGHT := 194.0
const SOURCE_PIVOT := Vector2(380, 680)
const SOURCE_CELL := Vector2i(1100, 720)
const FRAME_CACHE_SIZE := 8

var visual_scale: float = HEIGHT / 350.0:
	set(value):
		visual_scale = maxf(.001, value)
		queue_redraw()
var playback_speed := 1.0
var facing := 1
var animation_name := "idle"
var phase := 1
var resolved_source_phase := 1
var playing := true
var animation_time := 0.0
var frame_index := 0
var _meta: Dictionary = {}
var _manifest: Dictionary = {}
var _source_poses: Dictionary = {}
var _spec: Dictionary = {}
var _frames: Array = []
var _reader: ZIPReader
var _texture: ImageTexture
var _draw_rect := Rect2()
var _texture_cache: Dictionary = {}
var _cache_order: Array[int] = []
var _current_key := ""
var _finished := false
var _revision := 0
var _emitted_event_indices: Dictionary = {}

func _init() -> void:
	set_process(false)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for source_phase in [1, 2]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "meta_p%d.json" % source_phase))
		if parsed is Dictionary:
			_meta[source_phase] = parsed
	var parsed_manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	if parsed_manifest is Dictionary:
		_manifest = parsed_manifest
	if FileAccess.file_exists(ROOT + "source_poses.json"):
		var poses: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_poses.json"))
		if poses is Dictionary:
			_source_poses = poses.get("clips", {})

func _ready() -> void:
	if _current_key.is_empty():
		set_animation("idle", 1)

func get_available_animations(source_phase: int = 1) -> Array[String]:
	var result: Array[String] = []
	var definitions: Dictionary = _meta.get(clampi(source_phase, 1, 2), {})
	for name in definitions:
		if _manifest.get("animations", {}).has("p%d/%s" % [source_phase, name]):
			result.append(str(name))
	return result

func set_animation(name: String, source_phase: int = 1, restart: bool = true) -> bool:
	var requested_phase := clampi(source_phase, 1, 2)
	var resolved := requested_phase
	var animations: Dictionary = _manifest.get("animations", {})
	var key := "p%d/%s" % [resolved, name]
	# p1 metadata intentionally lists phase-two-only moves; their actual sheets
	# live exclusively in p2. Resolve that source explicitly, never invent frames.
	if not animations.has(key) and requested_phase == 1:
		resolved = 2
		key = "p2/" + name
	if not animations.has(key):
		return false
	if name == animation_name and requested_phase == phase and not restart and not _current_key.is_empty():
		return true
	if key != _current_key:
		if _reader != null:
			_reader.close()
		_reader = ZIPReader.new()
		var entry: Dictionary = animations[key]
		if _reader.open(ROOT + str(entry.pack)) != OK:
			push_error("Cannot open Archivist frame pack: " + key)
			_current_key = ""
			return false
		var packed: Variant = JSON.parse_string(_reader.read_file("frames.json").get_string_from_utf8())
		if not packed is Dictionary or not packed.has("frames"):
			push_error("Invalid Archivist frame manifest: " + key)
			_current_key = ""
			return false
		_frames = packed.frames
		_texture_cache.clear()
		_cache_order.clear()
		_current_key = key
	animation_name = name
	phase = requested_phase
	resolved_source_phase = resolved
	_spec = _meta[resolved][name]
	animation_time = 0.0
	_finished = false
	_revision += 1
	_emitted_event_indices.clear()
	_set_frame(0)
	_emit_interval(-.000001, 0.0)
	return true

func set_facing(value: int) -> void:
	facing = -1 if value < 0 else 1
	queue_redraw()

func set_playing(value: bool) -> void:
	playing = value

func advance(delta: float) -> void:
	if not playing or _spec.is_empty() or _finished or delta <= 0.0 or playback_speed <= 0.0:
		return
	var remaining := delta * playback_speed
	var duration := float(_spec.duration)
	var looped := bool(_spec.loop)
	var revision := _revision
	while remaining > 0.0:
		var previous := animation_time
		var amount := minf(remaining, duration - previous)
		animation_time = minf(duration, previous + amount)
		remaining = maxf(0.0, remaining - amount)
		_emit_interval(previous, animation_time)
		if revision != _revision:
			return
		if animation_time >= duration - .0000001:
			if looped:
				animation_time = 0.0
				_emitted_event_indices.clear()
				_emit_interval(-.000001, 0.0)
				if revision != _revision:
					return
			else:
				animation_time = duration
				_finished = true
				_update_frame()
				animation_finished.emit()
				return
		elif amount <= 0.0:
			break
	_update_frame()

func seek(seconds: float) -> void:
	if _spec.is_empty():
		return
	var duration := float(_spec.duration)
	if bool(_spec.loop):
		animation_time = fposmod(seconds, duration)
		_finished = false
	else:
		animation_time = clampf(seconds, 0.0, duration)
		_finished = animation_time >= duration
	# Scrubbing is silent. Record earlier events as consumed so resuming at an
	# exact event time cannot replay it, including floating-point boundaries.
	_emitted_event_indices.clear()
	var events: Array = _spec.get("events", [])
	for index in range(events.size()):
		var event: Dictionary = events[index]
		var when := float(event.get("time", float(event.get("u", 0.0)) * duration))
		if when <= animation_time + .00000001:
			_emitted_event_indices[index] = true
	_update_frame()

func _emit_interval(begin: float, end: float) -> void:
	var events: Array = _spec.get("events", [])
	var revision := _revision
	for index in range(events.size()):
		var event: Dictionary = events[index]
		var when := float(event.get("time", float(event.get("u", 0.0)) * float(_spec.duration)))
		if not _emitted_event_indices.has(index) and when > begin - .00000001 and when <= end + .00000001:
			_emitted_event_indices[index] = true
			event_crossed.emit(str(event.name))
			if revision != _revision:
				return

func _update_frame() -> void:
	var count := int(_spec.get("frames", 1))
	var progress := clampf(animation_time / float(_spec.duration), 0.0, 1.0)
	# Match HTML curFrame(): round(u * F) for loops, round(u * (F-1))
	# for one-shots. Time is duration-based, without an extra fps clock drift.
	var multiplier := count if bool(_spec.loop) else count - 1
	_set_frame(clampi(int(floor(progress * multiplier + .5)), 0, count - 1))

func _set_frame(value: int) -> void:
	if _frames.is_empty() or _reader == null:
		return
	frame_index = clampi(value, 0, _frames.size() - 1)
	if _texture_cache.has(frame_index):
		var cached: Dictionary = _texture_cache[frame_index]
		_texture = cached.texture
		_draw_rect = cached.rect
		_cache_order.erase(frame_index)
		_cache_order.append(frame_index)
	else:
		var frame: Dictionary = _frames[frame_index]
		var image := Image.new()
		if image.load_png_from_buffer(_reader.read_file(str(frame.file))) != OK:
			push_error("Cannot decode Archivist frame %s/%d" % [_current_key, frame_index])
			return
		var rectangle: Array = frame.rect
		var main_rect := Rect2i(int(rectangle[0]), int(rectangle[1]), int(rectangle[2]), int(rectangle[3]))
		var rendered_rect := main_rect
		if frame.has("extra_file"):
			var extra_image := Image.new()
			if extra_image.load_png_from_buffer(_reader.read_file(str(frame.extra_file))) != OK:
				push_error("Cannot decode Archivist exterior frame %s/%d" % [_current_key, frame_index])
				return
			var exterior: Array = frame.extra_rect
			var extra_rect := Rect2i(int(exterior[0]), int(exterior[1]), int(exterior[2]), int(exterior[3]))
			rendered_rect = main_rect.merge(extra_rect)
			image.convert(Image.FORMAT_RGBA8)
			extra_image.convert(Image.FORMAT_RGBA8)
			var merged := Image.create(rendered_rect.size.x, rendered_rect.size.y, false, Image.FORMAT_RGBA8)
			merged.blit_rect(extra_image, Rect2i(Vector2i.ZERO, extra_image.get_size()), extra_rect.position - rendered_rect.position)
			# Unmasked blit preserves every original RGBA byte. Merge into one
			# texture so linear filtering cannot leave seams at cell boundaries.
			merged.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), main_rect.position - rendered_rect.position)
			image = merged
		_texture = ImageTexture.create_from_image(image)
		_draw_rect = Rect2(rendered_rect)
		_texture_cache[frame_index] = {"texture": _texture, "rect": _draw_rect}
		_cache_order.append(frame_index)
		while _cache_order.size() > FRAME_CACHE_SIZE:
			_texture_cache.erase(_cache_order.pop_front())
	queue_redraw()

func _draw() -> void:
	if _texture == null or _frames.is_empty():
		return
	var origin := _draw_rect.position - SOURCE_PIVOT
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(facing), 1.0) * visual_scale)
	draw_texture(_texture, origin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func get_active_hitboxes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _spec.is_empty():
		return result
	var progress := animation_time / float(_spec.duration)
	for definition in _spec.get("hitboxes", []):
		if progress >= float(definition.u0) and progress <= float(definition.u1):
			var hit: Dictionary = definition.duplicate(true)
			hit["rect"] = Rect2(float(definition.x), float(definition.y), float(definition.w), float(definition.h))
			hit["kind"] = str(definition.k)
			hit["source_coordinates"] = true
			result.append(hit)
	return result

func get_hitboxes_world() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hit in get_active_hitboxes():
		var rectangle: Rect2 = hit.rect
		var first := to_global(rectangle.position * Vector2(float(facing), 1.0) * visual_scale)
		var opposite := to_global(rectangle.end * Vector2(float(facing), 1.0) * visual_scale)
		var world := hit.duplicate(true)
		world["rect"] = Rect2(first, opposite - first).abs()
		world["source_coordinates"] = false
		result.append(world)
	return result

func get_frame_source_rect() -> Rect2:
	if _frames.is_empty():
		return Rect2()
	var rectangle: Array = _frames[frame_index].rect
	return Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))

func get_pose() -> Dictionary:
	var clip: Dictionary = _source_poses.get(_current_key, {})
	var poses: Array = clip.get("frames", [])
	if poses.is_empty():
		return {}
	return poses[clampi(frame_index, 0, poses.size() - 1)].duplicate(true)

func get_snapshot() -> Dictionary:
	return {
		"animation": animation_name, "phase": phase,
		"resolved_source_phase": resolved_source_phase,
		"time": animation_time, "frame": frame_index,
		"frames": int(_spec.get("frames", 0)), "duration": float(_spec.get("duration", 0.0)),
		"fps": float(_spec.get("fps", 0.0)), "loop": bool(_spec.get("loop", false)),
		"facing": facing, "playing": playing, "finished": _finished,
		"playback_speed": playback_speed, "visual_scale": visual_scale,
		"source_origin": SOURCE_PIVOT, "source_pivot": SOURCE_PIVOT,
		"source_cell": SOURCE_CELL, "source_frame_rect": get_frame_source_rect(),
		"draw_frame_rect": _draw_rect,
		"active_hitboxes": get_active_hitboxes(), "cache_frames": _texture_cache.size(),
		"source_key": _current_key,
		"pose": get_pose(),
	}

func _exit_tree() -> void:
	if _reader != null:
		_reader.close()
	_texture_cache.clear()
	_texture = null
