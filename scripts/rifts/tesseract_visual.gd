class_name TesseractVisual
extends MeshInstance3D

var age: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("bb83ff")
	material.emission_enabled = true
	material.emission = Color("bb83ff")
	material.emission_energy_multiplier = 1.4
	material_override = material


func _process(delta: float) -> void:
	age += delta
	var projected := PackedVector3Array()
	for i in range(16):
		var x := 1.0 if i & 1 else -1.0
		var y := 1.0 if i & 2 else -1.0
		var z := 1.0 if i & 4 else -1.0
		var w := 1.0 if i & 8 else -1.0
		var xx := x * cos(age * 0.7) - w * sin(age * 0.7)
		var ww := x * sin(age * 0.7) + w * cos(age * 0.7)
		projected.append(Vector3(xx, y * cos(age * 0.45) - z * sin(age * 0.45), y * sin(age * 0.45) + z * cos(age * 0.45)) * (0.8 / (2.7 - ww)))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	for i in range(16):
		for dimension in [1, 2, 4, 8]:
			var next: int = i ^ dimension
			if next > i:
				tool.add_vertex(projected[i])
				tool.add_vertex(projected[next])
	mesh = tool.commit()
