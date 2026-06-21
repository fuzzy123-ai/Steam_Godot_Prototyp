extends Resource
class_name VehicleStats

@export var vehicle_name: String = "Basic Tank"
@export var max_forward_speed: float = 8.0
@export var max_reverse_speed: float = 4.0
@export var track_turn_speed: float = 1.8
@export var acceleration: float = 18.0
@export var brake_strength: float = 20.0
@export var turret_turn_speed: float = 8.0
@export var health: float = 100.0
@export var mass: float = 20.0
@export var slope_start_angle_degrees: float = 8.0
@export var max_climb_angle_degrees: float = 35.0
@export_range(0.05, 1.0, 0.01) var min_slope_speed_factor: float = 0.35
@export_range(0.0, 1.0, 0.01) var slope_slowdown_strength: float = 0.65
@export var shot_damage: float = 35.0
@export var shot_speed: float = 42.0
@export var fire_cooldown_seconds: float = 0.8
