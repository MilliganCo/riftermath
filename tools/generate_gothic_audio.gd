extends SceneTree

const RATE: int = 11025
const SPECS := {"bell_old": [3.6, 117.0], "hit_stone": [0.32, 72.0], "heavy_impact": [0.70, 48.0], "phase_chime": [0.85, 550.0], "quest_chime": [1.8, 294.0], "wind_low": [8.0, 42.0]}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/audio"))
	for cue: String in SPECS:
		var duration: float = SPECS[cue][0]
		var base: float = SPECS[cue][1]
		var samples := int(duration * RATE)
		var dry := PackedFloat32Array()
		dry.resize(samples)
		for i in range(samples):
			var t := float(i) / RATE
			var value := 0.0
			if cue == "wind_low":
				value = (sin(TAU * 42 * t) * 0.3 + sin(TAU * 63 * t) * 0.17 + sin(TAU * 77 * t) * 0.08) * (0.7 + sin(TAU * t / 8) * 0.15)
			elif cue in ["bell_old", "phase_chime", "quest_chime"]:
				for partial in range(5):
					var ratio: float = [1.0, 2.71, 4.13, 5.38, 6.79][partial]
					var strike := base * (1.0 if cue != "quest_chime" or t < 0.55 else 1.5)
					value += sin(TAU * strike * ratio * t) * exp(-t * (1.0 + partial * 0.72)) / (2.8 + partial * 1.6)
				value *= minf(1, t * 180)
			else:
				var noise := sin(i * 78.233) * sin(i * 12.9898)
				value = (sin(TAU * (base * t - 16 * t * t)) * 0.55 + noise * 0.28) * exp(-t * (13 if cue == "hit_stone" else 7)) * minf(1, t * 300)
			dry[i] = value
		var data := PackedByteArray()
		data.resize(samples * 2)
		for i in range(samples):
			var value := dry[i]
			if cue != "wind_low":
				for delay in [0.13, 0.27, 0.43]:
					var previous := i - int(delay * RATE)
					if previous >= 0: value += dry[previous] * 0.16
			# A deliberately coarse DAC character inside a portable 16-bit WAV container.
			value = roundf(clampf(value, -0.95, 0.95) * 128) / 128
			data.encode_s16(i * 2, int(value * 30000))
		var stream := AudioStreamWAV.new()
		stream.mix_rate = RATE
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.data = data
		var error := stream.save_to_wav("res://assets/audio/" + cue + ".wav")
		if error != OK:
			push_error("Cannot save " + cue + ": " + str(error))
			quit(1)
			return
		print("GOTHIC_AUDIO_ASSET: ", cue, " samples=", samples, " seconds=", stream.get_length())
	quit(0)
