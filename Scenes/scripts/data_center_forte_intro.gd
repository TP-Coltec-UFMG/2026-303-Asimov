extends Node

const JOB_PROGRAMMER := "programador"
const MISSION_POINT_NAMES: Array[String] = [
	"ServerRowA",
	"ServerRowB",
	"ServerRowC",
	"ServerRowD",
	"ServerColumn",
]

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var cutscene_camera: Camera2D = $CutsceneCamera
@onready var highlights: Node2D = $Highlights
@onready var black_overlay: ColorRect = $Overlay/Black

var scene: BaseScene
var player: Player
var player_camera: Camera2D
var ambient_modulate: CanvasModulate
var ambient_original_color := Color.BLACK
var animation_playback: AnimationNodeStateMachinePlayback
var cutscene_running: bool = false
var player_camera_was_enabled: bool = true
var pause_menu_process_mode: ProcessMode = Node.PROCESS_MODE_INHERIT
var hidden_nodes: Dictionary = {}


func _ready() -> void:
	black_overlay.color = Color.BLACK
	animation_tree.active = false
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
	# BaseScene posiciona o Player e atualiza sua câmera por chamadas adiadas.
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
	if ambient_modulate != null:
		ambient_original_color = ambient_modulate.color
	_apply_reset_animation()
	_prepare_gameplay()
	_prepare_camera()
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if animation_playback == null:
		_restore_gameplay()
		cutscene_running = false
		return

	await _play_animation_state(&"IntroOpen", &"intro_open")
	if not _cutscene_is_valid():
		return
	await _scan_data_center()
	if not _cutscene_is_valid():
		return
	await _play_animation_state(&"IntroClose", &"intro_close")
	if not _cutscene_is_valid():
		return

	_restore_gameplay()
	cutscene_running = false
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_forte_intro_seen"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _apply_reset_animation() -> void:
	animation_player.play(&"RESET")
	animation_player.advance(0.001)
	animation_player.stop()


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
	for marker_name_text in _mission_marker_order():
		if not _cutscene_is_valid():
			return
		var marker := highlights.get_node_or_null(marker_name_text) as Node2D
		if marker == null:
			continue
		var marker_name := StringName(marker.name)
		var animation_name := StringName("scan_" + str(marker.name).to_snake_case())
		await _play_animation_state(marker_name, animation_name)


func _mission_marker_order() -> Array[String]:
	var result: Array[String] = []
	# O final do engenheiro ainda não possui pontos próprios; não mostramos
	# indicações que não terão função nessa rota.
	if str(Configs.configs.get("job", "")) != JOB_PROGRAMMER:
		return result
	var state := SaveGame.office_mission_state(player)
	var stored: Variant = state.get("programmer_point_order", [])
	if stored is Array:
		for value in stored:
			var point_name := str(value)
			if MISSION_POINT_NAMES.has(point_name) and not result.has(point_name):
				result.append(point_name)
			if result.size() == 4:
				return result
	var candidates: Array[String] = MISSION_POINT_NAMES.duplicate()
	candidates.shuffle()
	result.clear()
	for index in range(4):
		result.append(candidates[index])
	state["programmer_point_order"] = result.duplicate()
	SaveGame.save_global_state("hall_quest_01", state)
	return result


func _play_animation_state(state_name: StringName, animation_name: StringName) -> void:
	if animation_playback == null or not animation_tree.active:
		return
	animation_playback.start(state_name, true)
	while _cutscene_is_valid():
		var finished_animation: StringName = await animation_tree.animation_finished
		if finished_animation == animation_name:
			return


func _store_and_hide(node: Node) -> void:
	if node == null:
		return
	hidden_nodes[node] = bool(node.get("visible"))
	node.set("visible", false)


func _restore_gameplay() -> void:
	animation_tree.active = false
	for marker in highlights.get_children():
		if marker is CanvasItem:
			(marker as CanvasItem).hide()
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
		player.set_physics_process(true)


func _cutscene_is_valid() -> bool:
	return (
		cutscene_running
		and is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and get_tree().current_scene == scene
	)
