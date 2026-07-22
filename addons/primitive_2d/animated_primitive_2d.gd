@tool
@icon("res://addons/primitive_2d/icon_animated_primitive2d.svg")
class_name AnimatedPrimitive2D
extends Primitive2D

@export var keyframes: Array[PrimitiveKeyframe] = []:
	set(value):
		keyframes = value
		timeline_length = max(timeline_length, _max_keyframe_time())
		update_configuration_warnings()

@export var timeline_length: float = 1.0:
	set(value):
		timeline_length = max(value, _max_keyframe_time())

@export var autoplay: bool = true
@export var loop: bool = true

var editing_keyframe_index: int = -1
var _playing: bool = false
var _playback_time: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	set_process(true)
	if autoplay:
		play()


func play() -> void:
	_playing = true


func stop() -> void:
	_playing = false


func seek(time: float) -> void:
	_playback_time = time
	_apply_animation_at(time)


func _process(delta: float) -> void:
	if not _playing or keyframes.size() < 2:
		return
	var sorted := _sorted_keyframes()
	var duration: float = max(timeline_length, sorted[-1].time)
	if duration <= 0.0:
		return
	_playback_time += delta
	if _playback_time >= duration:
		if loop:
			_playback_time = fmod(_playback_time, duration)
		else:
			_playback_time = duration
			_playing = false
	_apply_animation_at(_playback_time, sorted)


func _max_keyframe_time() -> float:
	var m := 0.0
	for kf in keyframes:
		m = max(m, kf.time)
	return m


func _sorted_keyframes() -> Array[PrimitiveKeyframe]:
	var sorted := keyframes.duplicate()
	sorted.sort_custom(func(a, b): return a.time < b.time)
	return sorted


func _apply_animation_at(time: float, sorted: Array[PrimitiveKeyframe] = []) -> void:
	if sorted.is_empty():
		sorted = _sorted_keyframes()
	if sorted.size() < 2:
		return

	var idx := 0
	for i in range(sorted.size() - 1):
		if time <= sorted[i + 1].time:
			idx = i
			break
		idx = sorted.size() - 2

	var a := sorted[idx]
	var b := sorted[idx + 1]
	var span := b.time - a.time
	var t: float = 0.0 if span <= 0.0 else clamp((time - a.time) / span, 0.0, 1.0)

	if a.vertices.size() == b.vertices.size() and a.vertices.size() > 0:
		var verts := PackedVector2Array()
		verts.resize(a.vertices.size())
		for i in a.vertices.size():
			verts[i] = Tween.interpolate_value(a.vertices[i], b.vertices[i] - a.vertices[i], t, 1.0, a.tween_type, a.ease_type)
		vertices = verts
	else:
		vertices = a.vertices if t < 1.0 else b.vertices

	fill_color = Tween.interpolate_value(a.fill_color, b.fill_color - a.fill_color, t, 1.0, a.tween_type, a.ease_type)
	outline_color = Tween.interpolate_value(a.outline_color, b.outline_color - a.outline_color, t, 1.0, a.tween_type, a.ease_type)
	outline_width = Tween.interpolate_value(a.outline_width, b.outline_width - a.outline_width, t, 1.0, a.tween_type, a.ease_type)


func _on_vertices_changed(value: PackedVector2Array) -> void:
	if editing_keyframe_index >= 0 and editing_keyframe_index < keyframes.size():
		keyframes[editing_keyframe_index].vertices = value
	update_configuration_warnings()


func _on_fill_color_changed(value: Color) -> void:
	if editing_keyframe_index >= 0 and editing_keyframe_index < keyframes.size():
		keyframes[editing_keyframe_index].fill_color = value


func _on_outline_color_changed(value: Color) -> void:
	if editing_keyframe_index >= 0 and editing_keyframe_index < keyframes.size():
		keyframes[editing_keyframe_index].outline_color = value


func _on_outline_width_changed(value: float) -> void:
	if editing_keyframe_index >= 0 and editing_keyframe_index < keyframes.size():
		keyframes[editing_keyframe_index].outline_width = value


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if keyframes.size() >= 2:
		var expected := keyframes[0].vertices.size()
		for kf in keyframes:
			if kf.vertices.size() != expected:
				warnings.append("All AnimatedPrimitive2D keyframes must have the same vertex count to morph correctly.")
				break
	return warnings
