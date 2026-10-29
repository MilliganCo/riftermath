class_name CombatAtmosphere
extends Node

## A short combat memory drives one continuous bone / ember / soot palette.
## No time scaling, camera rotation, or input sensitivity changes are involved.
@export_range(1, 4, 1) var pixel_size: int = 2
@export_range(0.0, 0.4) var sharpness: float = 0.16
@export var peak_fov_bonus: float = 11.0
@export var quiet_fog_density: float = 0.0035
@export var peak_fog_density: float = 0.075
@export var activity_decay: float = 0.17

var intensity: float = 0.0
var pressure: float = 0.0
var nearby_threat: float = 0.0
var activity: float = 0.0
var environment: Environment
var post_material: ShaderMaterial
var player: PlayerController
var _world: Node3D
var _sky: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _sun_energy: float = 1.0
var _fill_energy: float = 0.3
var _sample_remaining: float = 0.0


func configure(world: Node3D, controller: PlayerController, env: Environment, material: ShaderMaterial) -> void:
	_world = world
	player = controller
	environment = env
	post_material = material
	_sky = env.sky.sky_material as ProceduralSkyMaterial if env != null and env.sky != null else null
	if _sky != null:
		_sky.use_debanding = false
	_sun = world.get_node_or_null("Sun") as DirectionalLight3D
	_fill = world.get_node_or_null("Fill") as DirectionalLight3D
	if _sun != null:
		_sun_energy = _sun.light_energy * 0.75
	if _fill != null:
		_fill_energy = _fill.light_energy * 0.75
	player.damaged.connect(_on_damaged)
	player.respawned.connect(reset)
	player.killed.connect(_on_killed)
	apply_visuals()


func add_impulse(strength: float) -> void:
	if is_instance_valid(player) and not player.dead:
		activity = clampf(activity + strength, 0.0, 1.0)


func _on_damaged(amount: float) -> void:
	add_impulse(clampf(amount / 100.0, 0.10, 0.24))


func _on_killed(_attacker: Node) -> void:
	reset()


func reset() -> void:
	activity = 0.0
	intensity = 0.0
	nearby_threat = 0.0
	_sample_remaining = 0.0
	apply_visuals()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.dead:
		return
	_sample_remaining -= delta
	if _sample_remaining <= 0.0:
		_sample_remaining = 0.20
		nearby_threat = sample_threat()
	activity = maxf(0.0, activity - delta * activity_decay)
	var motion := clampf((player.horizontal_speed() - player.run_speed) / 18.0, 0.0, 1.0) * 0.07
	var target := clampf(activity + nearby_threat + motion, 0.0, 1.0)
	# Exponential smoothing is independent of rendering FPS. Recovery is slower.
	var response := 1.2 if target > intensity else 0.30
	intensity = lerpf(intensity, target, 1.0 - exp(-response * delta))
	apply_visuals()


func sample_threat() -> float:
	var threat := 0.0
	var eye := player.camera.global_position
	for actor in CombatRules.actors(_world):
		if actor == player or not actor is Node3D:
			continue
		if actor is CombatBot:
			if actor.team_id == player.team_id:
				continue
		elif not actor is EnemyController or not actor.attack_enabled:
			continue
		var at := CombatRules.aim_point(actor)
		var distance := eye.distance_to(at)
		if distance < 26.0 and CombatRules.clear_line(_world, eye, at):
			threat += lerpf(0.15, 0.035, clampf(distance / 26.0, 0.0, 1.0))
	# Count only nearby hostile attacks headed toward us, never our own/friendly casts.
	var attacks := get_tree().get_nodes_in_group("rift_projectiles") + get_tree().get_nodes_in_group("enemy_bolts")
	for attack in attacks:
		if attack.is_queued_for_deletion():
			continue
		var source: Node = attack.get_source()
		if source == player or (is_instance_valid(source) and source.has_method("combat_team") and source.combat_team() == player.team_id):
			continue
		var offset: Vector3 = eye - attack.global_position
		if offset.length_squared() < 18.0 * 18.0 and offset.length_squared() > 0.01 and (-attack.global_basis.z).dot(offset.normalized()) > 0.55:
			if CombatRules.clear_line(_world, eye, attack.global_position):
				threat += 0.12
	return minf(0.48, threat)


func apply_visuals() -> void:
	intensity = clampf(intensity, 0.0, 1.0)
	var heat := smoothstep(0.10, 0.62, intensity)
	pressure = smoothstep(0.52, 0.96, intensity)
	if environment != null:
		environment.ambient_light_color = Color("e5cfaa").lerp(Color("d3a581"), heat * 0.65)
		var cycle := _world.get_node_or_null("CelestialCycle") as CelestialCycle
		var daylight_factor := lerpf(0.55, 0.85, cycle.daylight) if cycle != null else 1.0
		environment.ambient_light_energy = lerpf(0.62, 0.43, pressure) * daylight_factor
		environment.fog_enabled = true
		environment.fog_light_color = Color("30271f").lerp(Color("100c0b"), pressure)
		environment.fog_light_energy = 0.65
		environment.fog_sun_scatter = 0.0
		environment.fog_sky_affect = 1.0
		environment.fog_density = lerpf(quiet_fog_density, peak_fog_density, pressure)
	if _sky != null:
		_sky.sky_top_color = Color("191411").lerp(Color("080605"), pressure)
		_sky.sky_horizon_color = Color("514334").lerp(Color("17100d"), pressure)
		_sky.ground_horizon_color = _sky.sky_horizon_color
		_sky.ground_bottom_color = Color("17130f").lerp(Color("090706"), pressure)
	if _sun != null and not _world.has_node("CelestialCycle"):
		_sun.light_color = Color("ffe3b8").lerp(Color("e9b489"), heat * 0.75)
		_sun.light_energy = _sun_energy * lerpf(1.0, 0.63, pressure)
	if _fill != null and not _world.has_node("CelestialCycle"):
		_fill.light_color = Color("c6bca5").lerp(Color("ad8b75"), heat * 0.7)
		_fill.light_energy = _fill_energy * lerpf(1.0, 0.75, pressure)
	if post_material != null:
		post_material.set_shader_parameter("pixel_size", float(pixel_size))
		post_material.set_shader_parameter("sharpness", sharpness)
		post_material.set_shader_parameter("heat", heat)
		post_material.set_shader_parameter("pressure", pressure)
	if is_instance_valid(player):
		player.combat_fov_bonus = peak_fov_bonus * smoothstep(0.30, 1.0, intensity)
