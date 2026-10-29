extends "res://tests/live_combat.gd"


func _run() -> void:
	await load_level("res://scenes/battle.tscn")
	var sky := game.get_node("CelestialCycle") as CelestialCycle
	sky.set_physics_process(false)
	check(sky.red_radius > sky.green_radius * 2, "The green sun has less than half the red sun's angular radius")
	sky.phase = 0.1
	sky.apply_cycle()
	var morning := sky.red_direction
	check(morning.y > 0 and sky.sun.light_energy > 0, "The red sun rises above the horizon and lights the world")
	sky.phase = 0.25
	sky.apply_cycle()
	check(sky.sun.light_energy <= 0.58 and sky.daylight > 0.9, "Even red noon stays deliberately dim")
	sky.phase = 0.7
	sky.apply_cycle()
	check(sky.red_direction.y < 0 and sky.sun.light_energy == 0, "The red sun sets below the horizon and stops direct lighting")
	check(sky.green_direction.y > 0 and sky.green_light.light_energy > 0, "The smaller green sun remains visible at red night")
	sky.phase = 0.9999
	sky._physics_process(0.1)
	check(sky.phase < 0.01, "The celestial day wraps into another complete orbit")
	for file in ["bell_old", "hit_stone", "heavy_impact", "phase_chime", "quest_chime", "wind_low"]:
		var sample := load("res://assets/audio/" + file + ".wav") as AudioStreamWAV
		check(sample != null and sample.data.size() > 4000 and sample.mix_rate == 11025, "Real retro WAV asset loads: " + file)
	var wind := GothicSoundscape.ambient_stream()
	check(wind.loop_mode == AudioStreamWAV.LOOP_FORWARD and wind.get_length() > 7.9, "Low gothic ambience is configured as an actual looping sample")
	var soundscape := game.get_node("Soundscape") as GothicSoundscape
	soundscape.remaining = 0.001
	soundscape._physics_process(0.01)
	check(soundscape.tolls == 1 and soundscape.remaining >= 18, "Distant bell tolls use a bounded intermittent schedule")
	player.set_mouse_captured(false)
	print("RIFTERMATH_CELESTIAL_AUDIO_RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
