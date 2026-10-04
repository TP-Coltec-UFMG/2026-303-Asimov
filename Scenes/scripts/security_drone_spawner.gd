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

@onready var intervalo: Timer = $Intervalo

var intervalo_configurado: float = 30.0
var final_estava_ativo: bool = false
var player: Player


func _ready() -> void:
	intervalo_configurado = float(DIFFICULTY_SETTINGS.drone_profile().get("spawn_interval", 30.0))


func _process(_delta: float) -> void:
	player = _encontrar_jogador()
	if not _final_esta_ativo():
		intervalo.stop()
		final_estava_ativo = false
		return
	intervalo.paused = not _pode_criar_reforco()
	if not final_estava_ativo:
		final_estava_ativo = true
		intervalo.start(intervalo_configurado)


func _on_intervalo_timeout() -> void:
	var profile := DIFFICULTY_SETTINGS.drone_profile()
	if _contar_drones_ativos() >= int(profile.get("max_active", 3)) or not _criar_reforco():
		intervalo.start(0.5)
	else:
		intervalo.start(intervalo_configurado)


func _contar_drones_ativos() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"security_drones"):
		var drone := node as SecurityDrone
		if drone != null and drone.visible and not drone.destruido:
			count += 1
	return count


func _encontrar_jogador() -> Player:
	var scene := get_parent() as BaseScene
	if scene != null and is_instance_valid(scene.player):
		return scene.player
	return get_tree().get_first_node_in_group("player") as Player


func _final_esta_ativo() -> bool:
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


func _pode_criar_reforco() -> bool:
	if not is_instance_valid(player) or not player.is_physics_processing():
		return false
	var intro := get_parent().get_node_or_null("RestrictedAreaIntro")
	if intro != null and bool(intro.get("cutscene_running")):
		return false
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	return camera != null and camera.enabled and camera.is_current()


func _criar_reforco() -> bool:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return false
	var safe_points: Array[Vector2] = []
	for point in SPAWN_POINTS:
		var global_point := (get_parent() as Node2D).to_global(point)
		if global_point.distance_to(player.global_position) < MINIMUM_PLAYER_DISTANCE:
			continue
		if not _ponto_esta_visivel(global_point, camera):
			safe_points.append(point)
	if safe_points.is_empty():
		return false
	safe_points.shuffle()
	var drone := DRONE_SCENE.instantiate() as SecurityDrone
	drone.salvar_estado_missao = false
	drone.position = safe_points[0]
	get_parent().add_child(drone)
	return true


func _ponto_esta_visivel(global_point: Vector2, camera: Camera2D) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size / camera.zoom
	var visible_rect := Rect2(
		camera.get_screen_center_position() - viewport_size * 0.5 - Vector2.ONE * SCREEN_MARGIN,
		viewport_size + Vector2.ONE * SCREEN_MARGIN * 2.0
	)
	return visible_rect.has_point(global_point)
