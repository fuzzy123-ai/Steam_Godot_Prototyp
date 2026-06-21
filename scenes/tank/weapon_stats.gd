extends Resource
class_name WeaponStats

@export var weapon_name: String = "Cannon"
@export var damage: float = 35.0
@export var projectile_speed: float = 42.0
@export var reload_seconds: float = 0.8
@export var ammo_capacity: int = 6
@export var spawned_projectile: PackedScene
@export var can_fire_while_reloading: bool = false
@export var line_of_fire_required: bool = true
