class_name SynthAudio
extends Node

var streams: Dictionary = {}
const ASSETS := {&"bell": "bell_old", &"hit": "hit_stone", &"kill": "heavy_impact", &"heavy": "heavy_impact", &"phase": "phase_chime", &"parry": "phase_chime", &"mend": "quest_chime", &"quest": "quest_chime"}


func _exit_tree() -> void:
	# Release active voices when a level/test closes before the hardware audio buffer.
	for voice in get_children():
		if voice is AudioStreamPlayer or voice is AudioStreamPlayer3D:
			voice.stop()
			voice.stream = null
	streams.clear()


func play_cue(cue: StringName) -> void:
	if get_child_count() >= 8:
		return
	if not streams.has(cue):
		streams[cue] = load("res://assets/audio/" + ASSETS[cue] + ".wav") if ASSETS.has(cue) else make_sound(cue)
	# A headless server still generates/validates PCM, but has no audible listener.
	if DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = streams[cue]
	player.volume_db = -21.0 if cue != &"parry" else -17.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_spatial(cue: StringName, at: Vector3, gain: float = -16.0) -> void:
	if get_child_count() >= 12 or DisplayServer.get_name() == "headless":
		return
	var file: String = ASSETS.get(cue, "bell_old")
	var voice := AudioStreamPlayer3D.new()
	voice.stream = load("res://assets/audio/" + file + ".wav")
	voice.volume_db = gain
	voice.max_distance = 85
	voice.unit_size = 8.0
	add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	voice.play()


static func make_sound(cue: StringName) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.16 if cue != &"parry" else 0.26
	var samples := int(duration * 22050)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var base: float = {&"cast": 300.0, &"hit": 95.0, &"kill": 55.0, &"parry": 850.0, &"air_cut": 510.0, &"mend": 620.0}.get(cue, 180.0)
	for i in range(samples):
		var t := float(i) / 22050
		var envelope := pow(1.0 - float(i) / samples, 2.2)
		var noise := sin(float(i) * 78.233) * sin(float(i) * 12.9898)
		var tone := sin(TAU * (base * t + 120.0 * t * t))
		var value := (tone * 0.35 + noise * 0.48) * envelope
		bytes.encode_s16(i * 2, int(clampf(value, -1, 1) * 28000))
	stream.data = bytes
	return stream
