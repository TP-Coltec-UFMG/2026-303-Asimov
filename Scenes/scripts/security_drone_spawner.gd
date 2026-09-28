class_name SecurityDroneSpawner
extends Node

const DRONE_SCENE := preload("res://Objects/security_drone.tscn")
const DIFFICULTY_SETTINGS := preload("res://Scripts/Data/difficulty_settings.gd")
const SCREEN_MARGIN: float = 18.0
const MINIMUM_PLAYER_DISTANCE: float = 105.0
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-188, -62),
	Vector2(250, -62),
	Vector2(-188, 188),
	Vector2(250, 188),
	Vector2(-198, 70),
	Vector2(258, 105)
]

var elapsed: float = 0.0
var ending_was_active: bool = false
var player: Player


func _process(delta: float) -> void:
	player = _find_player()
	var ending_active := _ending_is_active()
	if not ending_active:
		elapsed = 0.0
		ending_was_active = false
		return
	if not ending_was_active:
		ending_was_active = true
		elapsed = 0.0
		return
	if not _gameplay_allows_spawn():
		return
	var profile := DIFFICULTY_SETTINGS.drone_profile()
	var spawn_interval := float(profile.get("spawn_interval", 30.0))
	elapsed += delta
	if elapsed < spawn_interval:
		return
	if _active_drone_count() >= int(profile.get("max_active", 3)):
		elapsed = spawn_interval - 0.5
		return
	if _spawn_reinforcement():
		elapsed = 0.0
	else:
		elapsed = spawn_interval - 0.5


func _active_drone_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"security_drones"):
		var drone := node as SecurityDrone
		if drone != null and drone.visible and not drone.destroyed:
			count += 1
	return count


func _find_player() -> Player:
	var scene := get_parent() as BaseScene
	if scene != null and is_instance_valid(scene.player):
		return scene.player
	return get_tree().get_first_node_in_group("player") as Player


func _ending_is_active() -> bool:
	if not is_instance_valid(player):
		return false
	var state: Dictionary = SaveGame.office_mission_state(player)
	return (
		bool(state.get("programmer_ending_started", false))
		and not bool(state.get("programmer_ending_completed", false))
	) or (
		bool(state.get("engineer_ending_started", false))
		and not bool(state.get("engineer_ending_completed", false))
	)


func _gameplay_allows_spawn() -> bool:
	if not is_instance_valid(player) or not player.is_physics_processing():
		return false
	var intro := get_parent().get_node_or_null("RestrictedAreaIntro")
	if intro != null and bool(intro.get("cutscene_running")):
		return false
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	return camera != null and camera.enabled and camera.is_current()


func _spawn_reinforcement() -> bool:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	var safe_points: Array[Vector2] = []
	for point in SPAWN_POINTS:
		var global_point := (get_parent() as Node2D).to_global(point)
		if global_point.distance_to(player.global_position) < MINIMUM_PLAYER_DISTANCE:
			continue
		if not _point_is_visible(global_point, camera):
			safe_points.append(point)
	if safe_points.is_empty():
		return false
	safe_points.shuffle()
	var drone := DRONE_SCENE.instantiate() as SecurityDrone
	drone.persistent_mission_state = false
	drone.position = safe_points[0]
	get_parent().add_child(drone)
	return true


func _point_is_visible(global_point: Vector2, camera: Camera2D) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size / camera.zoom
	var visible_rect := Rect2(
		camera.get_screen_center_position() - viewport_size * 0.5 - Vector2.ONE * SCREEN_MARGIN,
		viewport_size + Vector2.ONE * SCREEN_MARGIN * 2.0
	)
	return visible_rect.has_point(global_point)
