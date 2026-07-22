@tool
class_name KeyframeTimelineTrack
extends Control

signal marker_pressed(index: int)
signal marker_dragged(index: int, new_time: float)
signal marker_released(index: int)

signal length_pressed()
signal length_dragged(new_length: float)
signal length_released()

const MARKER_RADIUS := 6.0
const TRACK_MARGIN := 16.0
const LENGTH_HANDLE_HIT := 8.0
const MIN_VIEW_SPAN := 0.2
const MAX_VIEW_SPAN_FACTOR := 4.0
const ZOOM_IN_FACTOR := 0.85
const ZOOM_OUT_FACTOR := 1.0 / 0.85

var times: Array[float] = []
var selected_index: int = -1
var total_length: float = 1.0

var view_start: float = 0.0
var view_span: float = 1.0

var _dragging_index: int = -1
var _dragging_length: bool = false
var _user_zoomed: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(240, 44)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_data(new_times: Array[float], new_selected: int, new_total_length: float) -> void:
	times = new_times
	selected_index = new_selected
	total_length = max(new_total_length, 0.001)

	if not _user_zoomed:
		view_start = 0.0
		view_span = total_length
	else:
		view_span = min(view_span, total_length * MAX_VIEW_SPAN_FACTOR)
		view_start = clamp(view_start, 0.0, max(total_length - view_span, 0.0))
		_ensure_selection_visible()

	queue_redraw()


func _ensure_selection_visible() -> void:
	if selected_index < 0 or selected_index >= times.size():
		return
	var t := times[selected_index]
	if t < view_start or t > view_start + view_span:
		view_start = clamp(t - view_span / 2.0, 0.0, max(total_length - view_span, 0.0))


func _time_to_x(t: float) -> float:
	var w := size.x - TRACK_MARGIN * 2.0
	if view_span <= 0.0:
		return TRACK_MARGIN
	return TRACK_MARGIN + ((t - view_start) / view_span) * w


func _x_to_time(x: float) -> float:
	var w := size.x - TRACK_MARGIN * 2.0
	if w <= 0.0:
		return view_start
	return view_start + (x - TRACK_MARGIN) / w * view_span


func _find_marker_at(x: float) -> int:
	var best_idx := -1
	var best_dist := MARKER_RADIUS + 4.0
	for i in times.size():
		var d := abs(_time_to_x(times[i]) - x)
		if d <= best_dist:
			best_dist = d
			best_idx = i
	return best_idx


func _is_near_length_handle(x: float) -> bool:
	return abs(_time_to_x(total_length) - x) <= LENGTH_HANDLE_HIT


func _min_length() -> float:
	var m := 0.0
	for t in times:
		m = max(m, t)
	return m


func _draw() -> void:
	var mid_y := size.y * 0.4
	draw_line(Vector2(TRACK_MARGIN, mid_y), Vector2(size.x - TRACK_MARGIN, mid_y), Color(1, 1, 1, 0.3), 2.0)

	var font := get_theme_default_font()

	var length_x := _time_to_x(total_length)
	if length_x >= -LENGTH_HANDLE_HIT and length_x <= size.x + LENGTH_HANDLE_HIT:
		draw_line(Vector2(length_x, 4.0), Vector2(length_x, size.y - 14.0), Color(0.3, 0.9, 1.0, 0.9), 2.0)
		var length_label := "L=%.2f" % total_length
		draw_string(font, Vector2(length_x - 20.0, size.y - 2.0), length_label, HORIZONTAL_ALIGNMENT_CENTER, 40, 10, Color(0.3, 0.9, 1.0, 0.9))

	for i in times.size():
		var x := _time_to_x(times[i])
		if x < -MARKER_RADIUS or x > size.x + MARKER_RADIUS:
			continue
		var color := Color(1, 1, 0) if i == selected_index else Color(0.6, 0.6, 0.6)
		var radius := MARKER_RADIUS + 1.0 if i == selected_index else MARKER_RADIUS
		draw_circle(Vector2(x, mid_y), radius, color)
		var label := "%.2f" % times[i]
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
		draw_string(font, Vector2(x - label_size.x / 2.0, mid_y + 18.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_button(event)
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_handle_wheel_zoom(event)
	elif event is InputEventMouseMotion:
		_handle_motion(event)


func _handle_left_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		var idx := _find_marker_at(event.position.x)
		if idx != -1:
			_dragging_index = idx
			marker_pressed.emit(idx)
			accept_event()
			return
		if _is_near_length_handle(event.position.x):
			_dragging_length = true
			length_pressed.emit()
			accept_event()
	else:
		if _dragging_index != -1:
			var idx := _dragging_index
			_dragging_index = -1
			marker_released.emit(idx)
			accept_event()
		elif _dragging_length:
			_dragging_length = false
			length_released.emit()
			accept_event()


func _handle_motion(event: InputEventMouseMotion) -> void:
	if _dragging_index != -1:
		var t: float = clamp(_x_to_time(event.position.x), 0.0, total_length)
		times[_dragging_index] = t
		queue_redraw()
		marker_dragged.emit(_dragging_index, t)
		accept_event()
	elif _dragging_length:
		var new_length: float = max(_x_to_time(event.position.x), _min_length())
		total_length = new_length
		queue_redraw()
		length_dragged.emit(new_length)
		accept_event()


func _handle_wheel_zoom(event: InputEventMouseButton) -> void:
	_user_zoomed = true
	var zoom_factor := ZOOM_IN_FACTOR if event.button_index == MOUSE_BUTTON_WHEEL_UP else ZOOM_OUT_FACTOR
	var t_at_cursor := _x_to_time(event.position.x)
	var max_span := total_length * MAX_VIEW_SPAN_FACTOR
	var new_span: float = clamp(view_span * zoom_factor, MIN_VIEW_SPAN, max_span)
	var ratio: float = 0.0 if view_span <= 0.0 else (t_at_cursor - view_start) / view_span
	view_start = t_at_cursor - ratio * new_span
	view_span = new_span
	view_start = clamp(view_start, -view_span, total_length)
	queue_redraw()
	accept_event()
