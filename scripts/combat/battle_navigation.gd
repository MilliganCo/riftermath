class_name BattleNavigation
extends Node

const STEP: float = 1.5
const HALF: int = 23
@export var cell_step: float = STEP
@export var half_cells: int = HALF
var graph := AStar3D.new()
var cells: Dictionary = {}
var arena: BattleArena


func configure(level: BattleArena) -> void:
	arena = level
	graph.clear()
	cells.clear()
	var id := 0
	for x in range(-half_cells, half_cells + 1):
		for z in range(-half_cells, half_cells + 1):
			var position_2d := Vector2(x, z) * cell_step
			var ids: Array[int] = []
			for height in arena.walkable_heights(position_2d):
				if arena.navigation_blocked(position_2d, height + 0.05):
					continue
				ids.append(id)
				graph.add_point(id, Vector3(position_2d.x, height + 0.05, position_2d.y))
				id += 1
			if not ids.is_empty(): cells[Vector2i(x, z)] = ids
	var max_step := cell_step * 0.55 + 0.02
	for cell: Vector2i in cells:
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var next: Vector2i = cell + offset
			if not cells.has(next):
				continue
			for from_id: int in cells[cell]:
				var a := graph.get_point_position(from_id)
				for to_id: int in cells[next]:
					var b := graph.get_point_position(to_id)
					if absf(a.y - b.y) > max_step: continue
					if absf(a.y - b.y) > 0.03 and not arena.walk_transition(a, b): continue
					if offset.x != 0 and offset.y != 0:
						if not _compatible(cell + Vector2i(offset.x, 0), a.y, max_step) or not _compatible(cell + Vector2i(0, offset.y), a.y, max_step):
							continue
					graph.connect_points(from_id, to_id)


func _compatible(cell: Vector2i, y: float, limit: float) -> bool:
	for id: int in cells.get(cell, []):
		if absf(graph.get_point_position(id).y - y) <= limit:
			return true
	return false


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := graph.get_closest_point(from)
	var b := graph.get_closest_point(to)
	if a < 0 or b < 0:
		return PackedVector3Array()
	return graph.get_point_path(a, b, true)
