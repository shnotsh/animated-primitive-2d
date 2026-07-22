@tool
@icon("res://addons/primitive_2d/icon_primitive2d.svg")
class_name Primitive2D
extends Control

@export var vertices: PackedVector2Array = PackedVector2Array():
	set(value):
		vertices = value
		_on_vertices_changed(value)
		queue_redraw()

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		_on_fill_color_changed(value)
		queue_redraw()

@export var draw_outline: bool = true:
	set(value):
		draw_outline = value
		queue_redraw()

@export var outline_color: Color = Color.BLACK:
	set(value):
		outline_color = value
		_on_outline_color_changed(value)
		queue_redraw()

@export var outline_width: float = 2.0:
	set(value):
		outline_width = value
		_on_outline_width_changed(value)
		queue_redraw()


func _on_vertices_changed(_value: PackedVector2Array) -> void:
	pass


func _on_fill_color_changed(_value: Color) -> void:
	pass


func _on_outline_color_changed(_value: Color) -> void:
	pass


func _on_outline_width_changed(_value: float) -> void:
	pass


func _draw() -> void:
	if vertices.size() >= 3:
		draw_colored_polygon(vertices, fill_color)

	if draw_outline and vertices.size() >= 2:
		var closed_points := vertices.duplicate()
		closed_points.append(vertices[0])
		draw_polyline(closed_points, outline_color, outline_width, true)
