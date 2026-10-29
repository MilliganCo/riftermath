class_name GothicSoundscape
extends Node

var world: Node3D
var tolls: int = 0
var remaining: float = 7.0


func _exit_tree() -> void:
	for voice in get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
			voice.stream = null


func configure(level: Node3D) -> void:
	world = level
	if DisplayServer.get_name() != "headless":
		var ambience := AudioStreamPlayer.new()
		ambience.stream = ambient_stream()
		ambience.volume_db = -33
		add_child(ambience)
		ambience.play()


static func ambient_stream() -> AudioStreamWAV:
	var stream := load("res://assets/audio/wind_low.wav").duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _physics_process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0 and is_instance_valid(world):
		remaining = 18.0 + float(tolls % 3) * 3
		var at := Vector3(16, 14, -28)
		if world.has_meta("bell_position"):
			at = world.get_meta("bell_position")
		world.get_node("Audio").play_spatial(&"bell", at, -17.0)
		tolls += 1
