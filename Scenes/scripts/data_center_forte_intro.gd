extends Node

@export var overview_position := Vector2(33.0, 70.0)
@export var overview_zoom := Vector2(0.82, 0.82)
@export_range(0.1, 5.0, 0.1) var reveal_duration: float = 1.6
@export_range(0.1, 5.0, 0.1) var camera_open_duration: float = 2.4
@export_range(0.1, 5.0, 0.1) var camera_return_duration: float = 1.5
@export var reveal_ambient_color := Color(0.24, 0.28, 0.31, 1.0)

@onready var cutscene_camera: Camera2D = $CutsceneCamera
@onready var highlights: Node2D = $Highlights
@onready var black_overlay: ColorRect = $Overlay/Black

var scene: BaseScene
var player: Player
var player_camera: Camera2D
var ambient_modulate: CanvasModulate
var ambient_original_color := Color.BLACK
var cutscene_running: bool = false
var player_camera_was_enabled: bool = true
var pause_menu_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var hidden_nodes: Dictionary = {}


func _ready() -> void:
	black_overlay.color = Color.BLACK
	if not _should_play_intro():
		black_overlay.hide()
		return
	call_deferred("_start_intro")


func _exit_tree() -> void:
	if cutscene_running:
		_restore_gameplay()


func _should_play_intro() -> bool:
	if scene_manager.last_scene_name.to_lower() != "andar_data_center":
		return false
	if SaveGame.restore_checkpoint_pending:
		return false
	var state: Dictionary = SaveGame.office_mission_state()
	return (
		bool(state.get("data_center_rfid_minigame_completed", false))
		and not bool(state.get("data_center_forte_intro_seen", false))
	)


func _start_intro() -> void:
	# BaseScene posiciona o Player e atualiza sua camera por chamadas adiadas.
	# Dois quadros garantem que a camera cinematografica assuma depois disso.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	scene = get_parent() as BaseScene
	if scene == null or not is_instance_valid(scene.player):
		black_overlay.hide()
		return
	player = scene.player
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	ambient_modulate = scene.get_node_or_null("Iluminacao/CanvasModulate") as CanvasModulate
	if player_camera == null:
		black_overlay.hide()
		player.set_physics_process(true)
		return

	cutscene_running = true
	_prepare_gameplay()
	_prepare_camera()
	if ambient_modulate != null:
		ambient_original_color = ambient_modulate.color
	await get_tree().create_timer(0.25, false).timeout
	if not _cutscene_is_valid():
		return

	var camera_open := create_tween()
	camera_open.set_parallel(true)
	camera_open.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	camera_open.tween_property(
		cutscene_camera,
		"global_position",
		overview_position,
		camera_open_duration
	)
	camera_open.tween_property(
		cutscene_camera,
		"zoom",
		overview_zoom,
		camera_open_duration
	)

	var reveal := create_tween()
	reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_property(black_overlay, "color:a", 0.0, reveal_duration)
	reveal.tween_callback(black_overlay.hide)
	if ambient_modulate != null:
		var ambient_reveal := create_tween()
		ambient_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		ambient_reveal.tween_property(
			ambient_modulate,
			"color",
			reveal_ambient_color,
			reveal_duration
		)

	await camera_open.finished
	if not _cutscene_is_valid():
		return
	await get_tree().create_timer(0.35, false).timeout
	await _scan_data_center()
	if not _cutscene_is_valid():
		return
	await _darken_data_center()
	if not _cutscene_is_valid():
		return

	var camera_return := create_tween()
	camera_return.set_parallel(true)
	camera_return.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	camera_return.tween_property(
		cutscene_camera,
		"global_position",
		player.global_position,
		camera_return_duration
	)
	camera_return.tween_property(
		cutscene_camera,
		"zoom",
		player_camera.zoom,
		camera_return_duration
	)
	await camera_return.finished
	if not _cutscene_is_valid():
		return

	_restore_gameplay()
	cutscene_running = false
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_forte_intro_seen"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _prepare_gameplay() -> void:
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	player.set_physics_process(false)
	_store_and_hide(player.get_node_or_null("InteractiongComponent"))
	_store_and_hide(player.get_node_or_null("CanvasLayer"))
	_store_and_hide(player.get_node_or_null("Inventory"))
	_store_and_hide(player.get_node_or_null("QUEST_MISSION"))
	_store_and_hide(scene.get_node_or_null("UI"))
	var pause_menu := scene.get_node_or_null("UI/PauseMenu")
	if pause_menu != null:
		pause_menu_process_mode = pause_menu.process_mode
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED


func _prepare_camera() -> void:
	player_camera_was_enabled = player_camera.enabled
	cutscene_camera.global_position = player.global_position
	cutscene_camera.zoom = player_camera.zoom
	cutscene_camera.enabled = true
	cutscene_camera.make_current()
	player_camera.enabled = false


func _scan_data_center() -> void:
	var markers: Array[Node] = highlights.get_children()
	markers.shuffle()
	for marker in markers:
		if not _cutscene_is_valid():
			return
		await _pulse_highlight(marker as Node2D)
		await get_tree().create_timer(0.12, false).timeout


func _pulse_highlight(marker: Node2D) -> void:
	if marker == null:
		return
	marker.show()
	marker.scale = Vector2(0.78, 0.78)
	marker.modulate = Color(1, 1, 1, 0)
	var appear := create_tween()
	appear.set_parallel(true)
	appear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(marker, "scale", Vector2.ONE, 0.22)
	appear.tween_property(marker, "modulate:a", 1.0, 0.16)
	await appear.finished
	var pulse := create_tween()
	pulse.set_loops(2)
	pulse.tween_property(marker, "modulate:a", 0.45, 0.16)
	pulse.tween_property(marker, "modulate:a", 1.0, 0.16)
	await pulse.finished
	await get_tree().create_timer(0.28, false).timeout
	var disappear := create_tween()
	disappear.set_parallel(true)
	disappear.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	disappear.tween_property(marker, "scale", Vector2(1.1, 1.1), 0.22)
	disappear.tween_property(marker, "modulate:a", 0.0, 0.22)
	await disappear.finished
	marker.hide()


func _store_and_hide(node: Node) -> void:
	if node == null:
		return
	hidden_nodes[node] = bool(node.get("visible"))
	node.set("visible", false)


func _restore_gameplay() -> void:
	for node in hidden_nodes:
		if is_instance_valid(node):
			node.set("visible", bool(hidden_nodes[node]))
	hidden_nodes.clear()
	if is_instance_valid(scene):
		var pause_menu := scene.get_node_or_null("UI/PauseMenu")
		if pause_menu != null:
			pause_menu.process_mode = pause_menu_process_mode
	if is_instance_valid(player_camera) and player_camera.is_inside_tree():
		player_camera.enabled = player_camera_was_enabled
		if player_camera_was_enabled:
			player_camera.make_current()
			player_camera.reset_smoothing()
			player_camera.force_update_scroll()
	if is_instance_valid(cutscene_camera):
		cutscene_camera.enabled = false
	if is_instance_valid(ambient_modulate):
		ambient_modulate.color = ambient_original_color
	black_overlay.color.a = 0.0
	black_overlay.hide()
	if is_instance_valid(player):
		# O fade da sala anterior traz o Player com a física desativada.
		# Ao terminar a apresentação, a jogabilidade sempre precisa voltar.
		player.set_physics_process(true)


func _cutscene_is_valid() -> bool:
	return (
		cutscene_running
		and is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and get_tree().current_scene == scene
	)


func _darken_data_center() -> void:
	if ambient_modulate == null:
		await get_tree().create_timer(0.35, false).timeout
		return
	var darken := create_tween()
	darken.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	darken.tween_property(ambient_modulate, "color", ambient_original_color, 0.8)
	await darken.finished
