class_name CelestialCycle
extends Node

@export var period: float = 180.0
@export var red_radius: float = 0.075
@export var green_radius: float = 0.032
var phase: float = 0.08
var red_direction := Vector3.ZERO
var green_direction := Vector3(-0.3, 0.43, -0.85).normalized()
var daylight: float = 0.0
var sky_material: ShaderMaterial
var atmosphere: CombatAtmosphere
var sun: DirectionalLight3D
var green_light: DirectionalLight3D
var _sample: float = 0.0


func configure(world: Node3D, mood: CombatAtmosphere) -> void:
	atmosphere = mood
	atmosphere._sky = null
	sun = world.get_node("Sun") as DirectionalLight3D
	green_light = DirectionalLight3D.new()
	green_light.name = "GreenSunLight"
	green_light.light_color = Color("819078")
	green_light.shadow_enabled = false
	world.add_child(green_light)
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/twin_suns.gdshader")
	sky.sky_material = sky_material
	atmosphere.environment.sky = sky
	apply_cycle()


func _physics_process(delta: float) -> void:
	phase = fposmod(phase + delta / period, 1.0)
	_sample -= delta
	if _sample <= 0:
		_sample = 0.10
		apply_cycle()


func apply_cycle() -> void:
	var angle := phase * TAU
	red_direction = Vector3(0.36, sin(angle) * 0.68, -cos(angle) * 0.85).normalized()
	daylight = smoothstep(-0.10, 0.70, red_direction.y)
	var darkness := atmosphere.pressure
	sky_material.set_shader_parameter("red_direction", red_direction)
	sky_material.set_shader_parameter("green_direction", green_direction)
	sky_material.set_shader_parameter("red_radius", red_radius)
	sky_material.set_shader_parameter("green_radius", green_radius)
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("pressure", darkness)
	var up := Vector3.FORWARD if absf(red_direction.y) > 0.97 else Vector3.UP
	sun.look_at_from_position(Vector3.ZERO, -red_direction, up)
	sun.light_color = Color("c78e72").lerp(Color("e2c49a"), daylight)
	sun.light_energy = lerpf(0.0, 0.58, daylight) * (1.0 - darkness * 0.42)
	green_light.look_at_from_position(Vector3.ZERO, -green_direction)
	green_light.light_energy = 0.10 * (1.0 - darkness * 0.30)
	var fill := get_parent().get_node_or_null("Fill") as DirectionalLight3D
	if fill != null:
		fill.light_energy = 0.07
		fill.light_color = Color("b4a080")
