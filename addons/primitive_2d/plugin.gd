@tool
extends EditorPlugin

const VERTEX_HIT_RADIUS := 10.0
const EDGE_HIT_RADIUS := 8.0
const HANDLE_RADIUS := 5.0
const HANDLE_RADIUS_ACTIVE := 7.0
const HANDLE_COLOR := Color(1, 1, 0)
const HANDLE_COLOR_HOVER := Color(1, 0.6, 0)
const HANDLE_COLOR_DRAG := Color(1, 0, 0)

var edited_node: Primitive2D = null
var edited_animated: AnimatedPrimitive2D = null
var dragged_index: int = -1
var hovered_index: int = -1
var drag_start_vertices: PackedVector2Array = PackedVector2Array()

var current_keyframe_index: int = -1
var keyframe_toolbar: VBoxContainer = null
var keyframe_spinbox: SpinBox = null
var keyframe_time_label: Label = null
var time_spinbox: SpinBox = null
var length_spinbox: SpinBox = null
var snap_checkbox: CheckBox = null
var add_keyframe_button: Button = null
var delete_keyframe_button: Button = null
var keyframe_timeline: KeyframeTimelineTrack = null
var tween_option: OptionButton = null
var ease_option: OptionButton = null
var _timeline_drag_start_time: float = 0.0
var _length_drag_start: float = 0.0
var snap_enabled: bool = false


func _enter_tree() -> void:
	keyframe_toolbar = VBoxContainer.new()
	keyframe_toolbar.visible = false

	var controls_row := HBoxContainer.new()
	keyframe_toolbar.add_child(controls_row)

	var label := Label.new()
	label.text = "Keyframe:"
	controls_row.add_child(label)

	keyframe_spinbox = SpinBox.new()
	keyframe_spinbox.min_value = 0
	keyframe_spinbox.max_value = 0
	keyframe_spinbox.step = 1
	keyframe_spinbox.value_changed.connect(_on_keyframe_spinbox_changed)
	controls_row.add_child(keyframe_spinbox)

	keyframe_time_label = Label.new()
	controls_row.add_child(keyframe_time_label)

	var time_label := Label.new()
	time_label.text = "Time (s):"
	controls_row.add_child(time_label)

	time_spinbox = SpinBox.new()
	time_spinbox.min_value = 0.0
	time_spinbox.max_value = 3600.0
	time_spinbox.step = 0.01
	time_spinbox.value_changed.connect(_on_time_spinbox_changed)
	controls_row.add_child(time_spinbox)

	add_keyframe_button = Button.new()
	add_keyframe_button.text = "+ Add"
	add_keyframe_button.pressed.connect(_on_add_keyframe_pressed)
	controls_row.add_child(add_keyframe_button)

	delete_keyframe_button = Button.new()
	delete_keyframe_button.text = "− Delete"
	delete_keyframe_button.pressed.connect(_on_delete_keyframe_pressed)
	controls_row.add_child(delete_keyframe_button)

	var length_row := HBoxContainer.new()
	keyframe_toolbar.add_child(length_row)

	var length_label := Label.new()
	length_label.text = "Length (s):"
	length_row.add_child(length_label)

	length_spinbox = SpinBox.new()
	length_spinbox.min_value = 0.0
	length_spinbox.max_value = 3600.0
	length_spinbox.step = 0.01
	length_spinbox.value_changed.connect(_on_length_spinbox_changed)
	length_row.add_child(length_spinbox)

	snap_checkbox = CheckBox.new()
	snap_checkbox.text = "Snap 0.1s"
	snap_checkbox.toggled.connect(_on_snap_toggled)
	length_row.add_child(snap_checkbox)

	var easing_row := HBoxContainer.new()
	keyframe_toolbar.add_child(easing_row)

	var tween_label := Label.new()
	tween_label.text = "Tween:"
	easing_row.add_child(tween_label)

	tween_option = OptionButton.new()
	_populate_enum_option_button(tween_option, "Tween", "TransitionType", "TRANS_")
	tween_option.item_selected.connect(_on_tween_option_selected)
	easing_row.add_child(tween_option)

	var ease_label := Label.new()
	ease_label.text = "Ease:"
	easing_row.add_child(ease_label)

	ease_option = OptionButton.new()
	_populate_enum_option_button(ease_option, "Tween", "EaseType", "EASE_")
	ease_option.item_selected.connect(_on_ease_option_selected)
	easing_row.add_child(ease_option)

	keyframe_timeline = KeyframeTimelineTrack.new()
	keyframe_timeline.marker_pressed.connect(_on_timeline_marker_pressed)
	keyframe_timeline.marker_dragged.connect(_on_timeline_marker_dragged)
	keyframe_timeline.marker_released.connect(_on_timeline_marker_released)
	keyframe_timeline.length_pressed.connect(_on_length_pressed)
	keyframe_timeline.length_dragged.connect(_on_length_dragged)
	keyframe_timeline.length_released.connect(_on_length_released)
	keyframe_toolbar.add_child(keyframe_timeline)

	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, keyframe_toolbar)


func _exit_tree() -> void:
	remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, keyframe_toolbar)
	keyframe_toolbar.queue_free()


func _handles(object: Object) -> bool:
	return object is Primitive2D


func _edit(object: Object) -> void:
	edited_node = object as Primitive2D
	edited_animated = object as AnimatedPrimitive2D
	dragged_index = -1
	hovered_index = -1
	if edited_animated != null:
		keyframe_toolbar.visible = true
		if edited_animated.keyframes.size() > 0:
			_select_keyframe(0)
		else:
			edited_animated.editing_keyframe_index = -1
			current_keyframe_index = -1
			_refresh_toolbar()
	else:
		keyframe_toolbar.visible = false
	update_overlays()


func _make_visible(visible: bool) -> void:
	keyframe_toolbar.visible = visible and edited_animated != null
	if not visible:
		if edited_animated != null:
			edited_animated.editing_keyframe_index = -1
		edited_node = null
		edited_animated = null
		dragged_index = -1
		hovered_index = -1
		current_keyframe_index = -1
	update_overlays()


func _select_keyframe(idx: int) -> void:
	if edited_animated == null or edited_animated.keyframes.is_empty():
		return
	idx = clamp(idx, 0, edited_animated.keyframes.size() - 1)
	current_keyframe_index = idx
	edited_animated.editing_keyframe_index = idx
	var kf := edited_animated.keyframes[idx]
	edited_node.vertices = kf.vertices
	edited_node.fill_color = kf.fill_color
	edited_node.outline_color = kf.outline_color
	edited_node.outline_width = kf.outline_width
	_refresh_toolbar()
	update_overlays()


func _ensure_valid_selection() -> void:
	if edited_animated == null:
		return
	var count := edited_animated.keyframes.size()
	if count == 0:
		if current_keyframe_index != -1:
			current_keyframe_index = -1
			edited_animated.editing_keyframe_index = -1
			_refresh_toolbar()
		return
	if current_keyframe_index < 0 or current_keyframe_index >= count:
		_select_keyframe(clamp(current_keyframe_index, 0, count - 1))


func _refresh_toolbar() -> void:
	if edited_animated == null:
		return
	var count := edited_animated.keyframes.size()
	keyframe_spinbox.editable = count > 0
	keyframe_spinbox.max_value = max(count - 1, 0)
	keyframe_spinbox.set_value_no_signal(max(current_keyframe_index, 0))
	delete_keyframe_button.disabled = count == 0
	time_spinbox.editable = count > 0
	length_spinbox.set_value_no_signal(edited_animated.timeline_length)

	var times: Array[float] = []
	for kf in edited_animated.keyframes:
		times.append(kf.time)
	keyframe_timeline.set_data(times, current_keyframe_index, edited_animated.timeline_length)

	if count > 0 and current_keyframe_index >= 0:
		var kf := edited_animated.keyframes[current_keyframe_index]
		keyframe_time_label.text = "of %d" % count
		time_spinbox.set_value_no_signal(kf.time)
		tween_option.disabled = false
		ease_option.disabled = false
		tween_option.select(tween_option.get_item_index(kf.tween_type))
		ease_option.select(ease_option.get_item_index(kf.ease_type))
	else:
		keyframe_time_label.text = "(no keyframes)"
		time_spinbox.set_value_no_signal(0.0)
		tween_option.disabled = true
		ease_option.disabled = true


func _resort_and_select(target_kf: PrimitiveKeyframe) -> void:
	if edited_animated == null:
		return
	var sorted := edited_animated.keyframes.duplicate()
	sorted.sort_custom(func(a, b): return a.time < b.time)
	edited_animated.keyframes = sorted
	var idx := sorted.find(target_kf)
	if idx != -1:
		_select_keyframe(idx)
	else:
		_refresh_toolbar()


func _on_keyframe_spinbox_changed(value: float) -> void:
	_select_keyframe(int(value))


func _populate_enum_option_button(option_button: OptionButton, class_name_str: String, enum_name: String, prefix: String) -> void:
	option_button.clear()
	for constant_name in ClassDB.class_get_enum_constants(class_name_str, enum_name):
		var value := ClassDB.class_get_integer_constant(class_name_str, constant_name)
		var label: String = constant_name.trim_prefix(prefix).capitalize()
		option_button.add_item(label, value)


func _on_tween_option_selected(index: int) -> void:
	if edited_animated == null or current_keyframe_index < 0 or current_keyframe_index >= edited_animated.keyframes.size():
		return
	var value := tween_option.get_item_id(index)
	var kf: PrimitiveKeyframe = edited_animated.keyframes[current_keyframe_index]
	if kf.tween_type == value:
		return
	var old_value := kf.tween_type
	var undo := get_undo_redo()
	undo.create_action("Change Primitive2D Keyframe Tween Type")
	undo.add_do_property(kf, "tween_type", value)
	undo.add_undo_property(kf, "tween_type", old_value)
	undo.commit_action()


func _on_ease_option_selected(index: int) -> void:
	if edited_animated == null or current_keyframe_index < 0 or current_keyframe_index >= edited_animated.keyframes.size():
		return
	var value := ease_option.get_item_id(index)
	var kf: PrimitiveKeyframe = edited_animated.keyframes[current_keyframe_index]
	if kf.ease_type == value:
		return
	var old_value := kf.ease_type
	var undo := get_undo_redo()
	undo.create_action("Change Primitive2D Keyframe Ease Type")
	undo.add_do_property(kf, "ease_type", value)
	undo.add_undo_property(kf, "ease_type", old_value)
	undo.commit_action()


func _snap_time(t: float) -> float:
	return round(t / 0.1) * 0.1 if snap_enabled else t


func _on_snap_toggled(pressed: bool) -> void:
	snap_enabled = pressed


func _on_time_spinbox_changed(value: float) -> void:
	if edited_animated == null or current_keyframe_index < 0 or current_keyframe_index >= edited_animated.keyframes.size():
		return
	var kf: PrimitiveKeyframe = edited_animated.keyframes[current_keyframe_index]
	var snapped := _snap_time(value)
	if is_equal_approx(kf.time, snapped):
		return
	var old_time := kf.time
	var undo := get_undo_redo()
	undo.create_action("Change Primitive2D Keyframe Time")
	undo.add_do_property(kf, "time", snapped)
	undo.add_undo_property(kf, "time", old_time)
	undo.commit_action()
	_resort_and_select(kf)


func _on_timeline_marker_pressed(idx: int) -> void:
	if edited_animated == null or idx < 0 or idx >= edited_animated.keyframes.size():
		return
	_select_keyframe(idx)
	_timeline_drag_start_time = edited_animated.keyframes[idx].time


func _on_timeline_marker_dragged(idx: int, new_time: float) -> void:
	if edited_animated == null or idx < 0 or idx >= edited_animated.keyframes.size():
		return
	edited_animated.keyframes[idx].time = _snap_time(new_time)
	_refresh_toolbar()


func _on_timeline_marker_released(idx: int) -> void:
	if edited_animated == null or idx < 0 or idx >= edited_animated.keyframes.size():
		return
	var kf: PrimitiveKeyframe = edited_animated.keyframes[idx]
	if not is_equal_approx(kf.time, _timeline_drag_start_time):
		var undo := get_undo_redo()
		undo.create_action("Change Primitive2D Keyframe Time")
		undo.add_do_property(kf, "time", kf.time)
		undo.add_undo_property(kf, "time", _timeline_drag_start_time)
		undo.commit_action()
	_resort_and_select(kf)


func _on_length_spinbox_changed(value: float) -> void:
	if edited_animated == null:
		return
	var snapped := _snap_time(value)
	if is_equal_approx(edited_animated.timeline_length, snapped):
		return
	var old_length := edited_animated.timeline_length
	var undo := get_undo_redo()
	undo.create_action("Change Primitive2D Timeline Length")
	undo.add_do_property(edited_animated, "timeline_length", snapped)
	undo.add_undo_property(edited_animated, "timeline_length", old_length)
	undo.commit_action()
	_refresh_toolbar()


func _on_length_pressed() -> void:
	if edited_animated == null:
		return
	_length_drag_start = edited_animated.timeline_length


func _on_length_dragged(new_length: float) -> void:
	if edited_animated == null:
		return
	edited_animated.timeline_length = _snap_time(new_length)
	_refresh_toolbar()


func _on_length_released() -> void:
	if edited_animated == null:
		return
	var new_length := edited_animated.timeline_length
	if not is_equal_approx(new_length, _length_drag_start):
		var undo := get_undo_redo()
		undo.create_action("Change Primitive2D Timeline Length")
		undo.add_do_property(edited_animated, "timeline_length", new_length)
		undo.add_undo_property(edited_animated, "timeline_length", _length_drag_start)
		undo.commit_action()
	_refresh_toolbar()


func _on_add_keyframe_pressed() -> void:
	if edited_animated == null:
		return

	var kf := PrimitiveKeyframe.new()
	if edited_animated.keyframes.is_empty():
		kf.time = 0.0
		kf.vertices = edited_node.vertices.duplicate()
		kf.fill_color = edited_node.fill_color
		kf.outline_color = edited_node.outline_color
		kf.outline_width = edited_node.outline_width
	else:
		var sorted := edited_animated.keyframes.duplicate()
		sorted.sort_custom(func(a, b): return a.time < b.time)
		var base: PrimitiveKeyframe = edited_animated.keyframes[current_keyframe_index] if current_keyframe_index >= 0 else sorted[-1]
		var base_idx := sorted.find(base)
		if base_idx != -1 and base_idx < sorted.size() - 1:
			var next_kf: PrimitiveKeyframe = sorted[base_idx + 1]
			kf.time = _snap_time((base.time + next_kf.time) / 2.0)
		else:
			kf.time = _snap_time(base.time + 1.0)
		kf.vertices = base.vertices.duplicate()
		kf.fill_color = base.fill_color
		kf.outline_color = base.outline_color
		kf.outline_width = base.outline_width
		kf.tween_type = base.tween_type
		kf.ease_type = base.ease_type

	var before := edited_animated.keyframes.duplicate()
	var after := edited_animated.keyframes.duplicate()
	after.append(kf)

	var undo := get_undo_redo()
	undo.create_action("Add Primitive2D Keyframe")
	undo.add_do_property(edited_animated, "keyframes", after)
	undo.add_undo_property(edited_animated, "keyframes", before)
	undo.commit_action()

	_resort_and_select(kf)


func _on_delete_keyframe_pressed() -> void:
	if edited_animated == null or edited_animated.keyframes.is_empty():
		return

	var idx := current_keyframe_index
	var before := edited_animated.keyframes.duplicate()
	var after := edited_animated.keyframes.duplicate()
	after.remove_at(idx)

	var undo := get_undo_redo()
	undo.create_action("Delete Primitive2D Keyframe")
	undo.add_do_property(edited_animated, "keyframes", after)
	undo.add_undo_property(edited_animated, "keyframes", before)
	undo.commit_action()

	if after.is_empty():
		edited_animated.editing_keyframe_index = -1
		current_keyframe_index = -1
		_refresh_toolbar()
	else:
		_select_keyframe(clamp(idx, 0, after.size() - 1))


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if edited_node == null:
		return false

	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return _handle_left_button(event)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			return _handle_right_button(event)

	return false


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if edited_node == null:
		return
	_ensure_valid_selection()
	var xform := _screen_transform()
	for i in edited_node.vertices.size():
		var screen_pos: Vector2 = xform * edited_node.vertices[i]
		var color := HANDLE_COLOR
		var radius := HANDLE_RADIUS
		if i == dragged_index:
			color = HANDLE_COLOR_DRAG
			radius = HANDLE_RADIUS_ACTIVE
		elif i == hovered_index:
			color = HANDLE_COLOR_HOVER
			radius = HANDLE_RADIUS_ACTIVE
		overlay.draw_circle(screen_pos, radius, color)


func _screen_transform() -> Transform2D:
	return EditorInterface.get_editor_viewport_2d().global_canvas_transform * edited_node.get_global_transform()


func _find_vertex_at(screen_pos: Vector2) -> int:
	var xform := _screen_transform()
	var best_idx := -1
	var best_dist := VERTEX_HIT_RADIUS
	for i in edited_node.vertices.size():
		var v_screen: Vector2 = xform * edited_node.vertices[i]
		var d := v_screen.distance_to(screen_pos)
		if d <= best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _find_edge_at(screen_pos: Vector2) -> int:
	var verts := edited_node.vertices
	var n := verts.size()
	if n < 2:
		return -1
	var xform := _screen_transform()
	var best_idx := -1
	var best_dist := EDGE_HIT_RADIUS
	for i in n:
		var a: Vector2 = xform * verts[i]
		var b: Vector2 = xform * verts[(i + 1) % n]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(screen_pos, a, b)
		var d := closest.distance_to(screen_pos)
		if d <= best_dist:
			best_dist = d
			best_idx = i + 1
	return best_idx


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if dragged_index != -1:
		var local_pos: Vector2 = _screen_transform().affine_inverse() * event.position
		var verts := edited_node.vertices
		verts[dragged_index] = local_pos
		edited_node.vertices = verts
		update_overlays()
		return true

	var idx := _find_vertex_at(event.position)
	if idx != hovered_index:
		hovered_index = idx
		update_overlays()
	return false


func _handle_left_button(event: InputEventMouseButton) -> bool:
	if not event.pressed:
		return _end_drag()

	var idx := _find_vertex_at(event.position)
	if idx != -1:
		dragged_index = idx
		drag_start_vertices = edited_node.vertices.duplicate()
		return true

	if event.double_click:
		return _insert_vertex_at(event.position)

	return false


func _end_drag() -> bool:
	if dragged_index == -1:
		return false
	var after := edited_node.vertices.duplicate()
	if after != drag_start_vertices:
		var undo := get_undo_redo()
		undo.create_action("Move Primitive2D Vertex")
		undo.add_do_property(edited_node, "vertices", after)
		undo.add_undo_property(edited_node, "vertices", drag_start_vertices)
		undo.commit_action()
	dragged_index = -1
	return true


func _insert_vertex_at(screen_pos: Vector2) -> bool:
	var insert_idx := _find_edge_at(screen_pos)
	if insert_idx == -1:
		return false
	var local_pos: Vector2 = _screen_transform().affine_inverse() * screen_pos
	var before := edited_node.vertices.duplicate()
	var after := edited_node.vertices.duplicate()
	after.insert(insert_idx, local_pos)
	var undo := get_undo_redo()
	undo.create_action("Insert Primitive2D Vertex")
	undo.add_do_property(edited_node, "vertices", after)
	undo.add_undo_property(edited_node, "vertices", before)
	undo.commit_action()
	update_overlays()
	return true


func _handle_right_button(event: InputEventMouseButton) -> bool:
	var idx := _find_vertex_at(event.position)
	if idx == -1:
		return false
	var before := edited_node.vertices.duplicate()
	var after := edited_node.vertices.duplicate()
	after.remove_at(idx)
	var undo := get_undo_redo()
	undo.create_action("Delete Primitive2D Vertex")
	undo.add_do_property(edited_node, "vertices", after)
	undo.add_undo_property(edited_node, "vertices", before)
	undo.commit_action()
	update_overlays()
	return true
