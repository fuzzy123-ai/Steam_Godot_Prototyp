extends Control

@export var icon_color: Color = Color(0.92, 0.96, 1.0, 1.0)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.35)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.26
	var tooth_inner := radius * 1.15
	var tooth_outer := radius * 1.48
	var tooth_width := maxf(2.0, radius * 0.22)
	_draw_gear(center + Vector2(1.5, 1.5), radius, tooth_inner, tooth_outer, tooth_width, shadow_color)
	_draw_gear(center, radius, tooth_inner, tooth_outer, tooth_width, icon_color)
	draw_circle(center, radius * 0.42, Color(0.055, 0.06, 0.068, 1.0))
	draw_arc(center, radius * 0.42, 0.0, TAU, 40, icon_color, maxf(2.0, radius * 0.14), true)


func _draw_gear(center: Vector2, radius: float, tooth_inner: float, tooth_outer: float, tooth_width: float, color: Color) -> void:
	for index: int in range(8):
		var angle := TAU * float(index) / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(center + direction * tooth_inner, center + direction * tooth_outer, color, tooth_width, true)
	draw_arc(center, radius, 0.0, TAU, 48, color, maxf(3.0, radius * 0.3), true)
