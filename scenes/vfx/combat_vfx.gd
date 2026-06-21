extends Node3D

enum EffectKind {
	MUZZLE_FLASH,
	IMPACT_SPARK,
	TERRAIN_DUST,
}

@export var effect_kind: EffectKind = EffectKind.IMPACT_SPARK
@export_range(0.05, 2.0, 0.01) var duration: float = 0.35
@export var auto_play: bool = false
@export var free_when_finished: bool = true

var _elapsed: float = 0.0
var _normal: Vector3 = Vector3.UP
var _shot_direction: Vector3 = Vector3.FORWARD
var _pieces: Array[MeshInstance3D] = []
var _base_scales: Dictionary = {}
var _base_colors: Dictionary = {}
var _growth_factors: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if auto_play:
		play()


func play(surface_normal: Vector3 = Vector3.UP, shot_direction: Vector3 = Vector3.FORWARD) -> void:
	_reset_generated()
	_elapsed = 0.0
	_normal = surface_normal.normalized() if surface_normal.length_squared() > 0.001 else Vector3.UP
	_shot_direction = shot_direction.normalized() if shot_direction.length_squared() > 0.001 else Vector3.FORWARD

	match effect_kind:
		EffectKind.MUZZLE_FLASH:
			_build_muzzle_flash()
		EffectKind.TERRAIN_DUST:
			_build_terrain_dust()
		_:
			_build_impact_spark()

	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.18, 1.0, t)

	for piece: MeshInstance3D in _pieces:
		if not is_instance_valid(piece):
			continue
		var base_scale: Vector3 = _base_scales.get(piece, Vector3.ONE)
		var growth := float(_growth_factors.get(piece, 1.0))
		piece.scale = base_scale * lerpf(1.0, growth, t)

		var material := piece.material_override as StandardMaterial3D
		if material != null:
			var base_color: Color = _base_colors.get(piece, Color.WHITE)
			base_color.a *= fade
			material.albedo_color = base_color
			if material.emission_enabled:
				material.emission = Color(base_color.r, base_color.g, base_color.b, 1.0)

	if t >= 1.0:
		set_process(false)
		if free_when_finished:
			queue_free()


func _build_muzzle_flash() -> void:
	_add_sphere(
		Vector3(0.0, 0.0, -0.22),
		Vector3(0.34, 0.34, 0.46),
		Color(1.0, 0.72, 0.18, 0.92),
		3.8,
		1.25
	)
	_add_sphere(
		Vector3(0.0, 0.0, -0.48),
		Vector3(0.18, 0.18, 0.32),
		Color(1.0, 0.96, 0.62, 0.9),
		5.5,
		1.6
	)

	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.position = Vector3(0.0, 0.0, -0.25)
	light.light_color = Color(1.0, 0.74, 0.32, 1.0)
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)


func _build_impact_spark() -> void:
	_add_sphere(
		_normal * 0.08,
		Vector3(0.28, 0.28, 0.28),
		Color(1.0, 0.78, 0.32, 0.88),
		3.2,
		1.8
	)
	_add_ring(Color(1.0, 0.48, 0.2, 0.52), 0.34, 10, 2.3)


func _build_terrain_dust() -> void:
	_add_sphere(
		_normal * 0.08,
		Vector3(0.35, 0.22, 0.35),
		Color(0.58, 0.52, 0.43, 0.52),
		0.0,
		2.4
	)
	_add_ring(Color(0.46, 0.42, 0.36, 0.42), 0.52, 12, 2.8)
	_add_ring(Color(0.68, 0.62, 0.52, 0.28), 0.82, 14, 2.1)


func _add_ring(color: Color, radius: float, count: int, growth: float) -> void:
	var basis := _surface_basis()
	for index: int in range(count):
		var angle := TAU * float(index) / float(count)
		var radial := (basis.x * cos(angle) + basis.z * sin(angle)).normalized()
		var lift := _normal * 0.05
		var offset := radial * radius + lift
		var size := 0.12 + 0.04 * float(index % 3)
		_add_sphere(offset, Vector3(size, size, size), color, 0.0, growth)


func _add_sphere(offset: Vector3, scale_value: Vector3, color: Color, emission_energy: float, growth: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0

	var piece := MeshInstance3D.new()
	piece.name = "VfxPiece"
	piece.position = offset
	piece.scale = scale_value
	piece.mesh = mesh
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piece.material_override = _make_material(color, emission_energy)
	add_child(piece)

	_pieces.append(piece)
	_base_scales[piece] = scale_value
	_base_colors[piece] = color
	_growth_factors[piece] = growth


func _make_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = emission_energy
	return material


func _surface_basis() -> Basis:
	var tangent := _normal.cross(Vector3.UP)
	if tangent.length_squared() <= 0.001:
		tangent = _normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(_normal).normalized()
	return Basis(tangent, _normal, bitangent)


func _reset_generated() -> void:
	for child: Node in get_children():
		child.queue_free()
	_pieces.clear()
	_base_scales.clear()
	_base_colors.clear()
	_growth_factors.clear()
