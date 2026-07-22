@tool
class_name PrimitiveKeyframe
extends Resource

@export var time: float = 0.0
@export var vertices: PackedVector2Array = PackedVector2Array()
@export var fill_color: Color = Color.WHITE
@export var outline_color: Color = Color.BLACK
@export var outline_width: float = 2.0
@export var tween_type: Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
