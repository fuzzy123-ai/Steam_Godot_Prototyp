extends Resource
class_name VehicleDefinition

@export var vehicle_id: StringName = &"basic_tank"
@export var display_name: String = "Basic Tank"
@export_multiline var description: String = ""
@export var tank_scene: PackedScene
@export var visual_scene: PackedScene
@export var stats: VehicleStats
@export var weapon_stats: Resource
@export var preview_color: Color = Color(0.24, 0.36, 0.42, 1.0)
@export var sort_order: int = 0
