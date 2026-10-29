class_name GestureCapture
extends Node

signal incision_started
signal path_changed(points: PackedVector2Array)
signal gesture_released(points: PackedVector2Array, camera_pose: Transform3D, duration: float)
signal cancelled

@export var meters_per_pixel: float = 0.0075
@export var point_spacing: float = 0.025
@export var max_points: int = 96
@export var max_path_length: float = GestureRecognizer.MAX_SCAR_LENGTH
@export var plane_distance: float = 2.0
@export var plane_extents := Vector2(2.8, 1.55)

var active: bool = false
var points := PackedVector2Array()
var duration: float = 0.0
var player: PlayerController
var _cursor := Vector2.ZERO
var _drawn_length: float = 0.0


func _ready() -> void:
	player = get_parent() as PlayerController
	player.respawned.connect(cancel)
	player.mouse_capture_changed.connect(_on_mouse_capture_changed)


func _process(delta: float) -> void:
	if active:
		duration += delta
		if not player.mouse_captured:
			cancel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		cancel()
	if not player.mouse_captured:
		return
	if event.is_action_pressed("draw_rift"):
		begin()
	elif event is InputEventMouseMotion and active:
		feed_relative(event.relative)
	elif event.is_action_released("draw_rift") and active:
		release()


func begin() -> void:
	if active:
		return
	active = true
	player.drawing = true
	duration = 0.0
	_cursor = Vector2.ZERO
	_drawn_length = 0.0
	points = PackedVector2Array([Vector2.ZERO])
	incision_started.emit()
	path_changed.emit(points)


func feed_relative(relative: Vector2) -> void:
	if not active or not relative.is_finite():
		return
	_cursor += Vector2(relative.x, -relative.y) * meters_per_pixel
	_cursor = _cursor.clamp(-plane_extents, plane_extents)
	if _cursor.distance_to(points[-1]) < point_spacing:
		return
	var remaining := max_path_length - _drawn_length
	if remaining < point_spacing:
		return
	var distance := _cursor.distance_to(points[-1])
	if distance > remaining:
		_cursor = points[-1].lerp(_cursor, remaining / distance)
	_drawn_length += minf(distance, remaining)
	if points.size() >= max_points:
		# Compact older samples, retaining the original start and recent endpoint.
		var compact := PackedVector2Array()
		for i in range(0, points.size(), 2):
			compact.append(points[i])
		points = compact
	points.append(_cursor)
	path_changed.emit(points)


func release() -> void:
	if not active:
		return
	# One release transform for every point: camera turns never mix coordinate frames.
	var pose := player.camera.global_transform.translated_local(Vector3(0, 0, -plane_distance))
	active = false
	player.drawing = false
	gesture_released.emit(points.duplicate(), pose, duration)


func cancel() -> void:
	if not active:
		return
	active = false
	player.drawing = false
	points.clear()
	cancelled.emit()


func _on_mouse_capture_changed(captured: bool) -> void:
	if not captured:
		cancel()
