extends Node

const GUIDE_DELAY := 0.8

@export_node_path("CanvasItem") var darkness_overlay_path: NodePath
@export var play_on_first_data_center_entry: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var cutscene_camera: Camera2D = $CutsceneCamera
@onready var area_focus: Marker2D = $AreaFocus
@onready var highlight: Node2D = $Highlight
@onready var area_light: PointLight2D = $Highlight/AreaLight
@onready var black_overlay: ColorRect = $Overlay/Black

var scene: BaseScene
var player: Player
var player_camera: Camera2D
var animation_playback: AnimationNodeStateMachinePlayback
var initialized := false
var cutscene_running := false
var guide_hold_active := false
var guide_hold_pulse: Tween
var active_wait := 0.0
var passive_pulse: Tween
var player_camera_was_enabled := true
var player_process_mode := Node.PROCESS_MODE_INHERIT
var player_physics_enabled := true
var player_input_enabled := true
var interaction_input_enabled := true
var locked_triggers: Array[Dictionary] = []
var pause_menu_mode := Node.PROCESS_MODE_INHERIT
var darkness_overlay: CanvasItem
var darkness_overlay_was_visible := false
var darkness_revealed := false


func _ready() -> void:
	animation_tree.active = false
	area_light.enabled = false
	_apply_reset()
	call_deferred("_initialize")


func _initialize() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	scene = get_parent() as BaseScene
	if scene == null or not is_instance_valid(scene.player):
		return
	player = scene.player
	player_camera = player.get_node_or_null("Camera2D") as Camera2D
	if not darkness_overlay_path.is_empty():
		darkness_overlay = scene.get_node_or_null(darkness_overlay_path) as CanvasItem
	initialized = true
	_refresh_passive_highlight()


func _process(delta: float) -> void:
	if cutscene_running:
		if guide_hold_active:
			_keep_guide_visible()
		return
	if not initialized or not is_instance_valid(player):
		return
	var state := SaveGame.office_mission_state(player)
	var intro_pending := (
		play_on_first_data_center_entry
		and not bool(state.get("cooling_location_intro_seen", false))
	)
	if not intro_pending:
		active_wait = 0.0
		_refresh_passive_highlight()
		return
	if not _can_start_cutscene():
		active_wait = 0.0
		return
	active_wait += delta
	if active_wait >= GUIDE_DELAY:
		active_wait = 0.0
		_start_cutscene()


func _guide_is_active(state: Dictionary) -> bool:
	return (
		bool(state.get("cooling_optional_task_active", false))
		and not bool(state.get("cooling_optional_task_completed", false))
		and not bool(state.get("cooling_optional_task_cancelled", false))
	)


func _can_start_cutscene() -> bool:
	var programmer_ending := scene.get_node_or_null("ProgrammerEnding")
	if programmer_ending != null and bool(programmer_ending.get("busy")):
		return false
	var data_center_intro := scene.get_node_or_null("DataCenterIntroController")
	if data_center_intro != null and bool(data_center_intro.get("access_sequence_busy")):
		return false
	return (
		get_tree().current_scene == scene
		and not get_tree().paused
		and not DialogManager.is_showing_dialog
		and player.is_physics_processing()
		and not player.balao_de_pensamento.esta_ocupado()
		and is_instance_valid(player_camera)
	)


func _start_cutscene() -> void:
	if cutscene_running:
		return
	cutscene_running = true
	_stop_passive_pulse()
	_lock_player()
	_set_area_revealed(true)
	area_light.enabled = true
	_apply_reset()
	black_overlay.show()
	black_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	highlight.show()
	cutscene_camera.global_position = area_focus.global_position
	# Abre o enquadramento para mostrar a entrada e o entorno da refrigeração.
	cutscene_camera.zoom = player_camera.zoom * 0.68
	cutscene_camera.enabled = true
	cutscene_camera.make_current()
	player_camera.enabled = false
	animation_tree.active = true
	animation_playback = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	if animation_playback == null:
		_finish_cutscene(false)
		return
	await _play_state(&"Reveal", &"reveal")
	if not _cutscene_is_valid():
		return
	guide_hold_active = true
	# The AnimationTree's Hold state was hiding the title/highlight before the
	# camera move ended. Freeze it during the presentation and keep these visuals
	# under direct control until the intentional fade-out starts.
	animation_tree.active = false
	_keep_guide_visible()
	guide_hold_pulse = create_tween().set_loops()
	guide_hold_pulse.tween_property(highlight, "modulate:a", 0.72, 1.25)
	guide_hold_pulse.tween_property(highlight, "modulate:a", 1.0, 1.25)
	await get_tree().create_timer(5.0).timeout
	if not _cutscene_is_valid():
		return
	guide_hold_active = false
	_stop_guide_hold_pulse()
	highlight.modulate = Color.WHITE
	animation_tree.active = true
	await _play_state(&"Conceal", &"conceal")
	if not _cutscene_is_valid():
		return
	_restore_player_camera()
	_set_area_revealed(false)
	area_light.enabled = false
	await _play_state(&"Finish", &"finish")
	if not _cutscene_is_valid():
		return
	_finish_cutscene(true)


func _play_state(state_name: StringName, animation_name: StringName) -> void:
	animation_playback.start(state_name, true)
	while _cutscene_is_valid():
		var finished: StringName = await animation_tree.animation_finished
		if finished == animation_name:
			return


func _finish_cutscene(save_seen: bool) -> void:
	guide_hold_active = false
	_stop_guide_hold_pulse()
	animation_tree.active = false
	_set_area_revealed(false)
	area_light.enabled = false
	_restore_player_camera()
	black_overlay.color.a = 0.0
	black_overlay.hide()
	black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_player()
	cutscene_running = false
	if save_seen and is_instance_valid(player):
		var state := SaveGame.office_mission_state(player)
		state["cooling_location_intro_seen"] = true
		state["cooling_location_cutscene_seen"] = true
		SaveGame.save_global_state("hall_quest_01", state)
		if player.checkpoint_enabled:
			SaveGame.create_checkpoint(player)
	_refresh_passive_highlight()


func _keep_guide_visible() -> void:
	# Hold the title and entrance highlight for the full reveal.
	if is_instance_valid($Overlay/Title):
		$Overlay/Title.show()
		$Overlay/Title.modulate.a = 1.0
	highlight.show()
	area_light.enabled = true


func _stop_guide_hold_pulse() -> void:
	if guide_hold_pulse != null and guide_hold_pulse.is_valid():
		guide_hold_pulse.kill()
	guide_hold_pulse = null


func _lock_player() -> void:
	player_camera_was_enabled = player_camera.enabled
	player_process_mode = player.process_mode
	player_physics_enabled = player.is_physics_processing()
	player_input_enabled = player.is_processing_input()
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	player.set_physics_process(false)
	player.set_process_input(false)
	var interaction_component := player.get_node_or_null("InteractiongComponent")
	if interaction_component != null:
		interaction_input_enabled = interaction_component.is_processing_unhandled_input()
		interaction_component.set_process_unhandled_input(false)
	locked_triggers.clear()
	for child in scene.get_children():
		if child is SceneTrigger:
			var prompt := child.get_node_or_null("Interectable")
			locked_triggers.append({
				"trigger": child,
				"input_enabled": child.is_processing_unhandled_input(),
				"prompt": prompt,
				"prompt_enabled": bool(prompt.get("is_interactable")) if prompt != null else false
			})
			child.set_process_unhandled_input(false)
			if prompt != null:
				prompt.set("is_interactable", false)
	var pause_menu := scene.get_node_or_null("UI/PauseMenu")
	if pause_menu != null:
		pause_menu_mode = pause_menu.process_mode
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED


func _unlock_player() -> void:
	if is_instance_valid(player):
		player.process_mode = player_process_mode
		player.set_physics_process(player_physics_enabled)
		player.set_process_input(player_input_enabled)
		var interaction_component := player.get_node_or_null("InteractiongComponent")
		if interaction_component != null:
			interaction_component.set_process_unhandled_input(interaction_input_enabled)
	for locked in locked_triggers:
		var trigger: Node = locked.get("trigger")
		if is_instance_valid(trigger):
			trigger.set_process_unhandled_input(bool(locked.get("input_enabled", true)))
		var prompt: Node = locked.get("prompt")
		if is_instance_valid(prompt):
			prompt.set("is_interactable", bool(locked.get("prompt_enabled", true)))
	locked_triggers.clear()
	if is_instance_valid(scene):
		var pause_menu := scene.get_node_or_null("UI/PauseMenu")
		if pause_menu != null:
			pause_menu.process_mode = pause_menu_mode


func _restore_player_camera() -> void:
	if is_instance_valid(player_camera) and player_camera.is_inside_tree():
		player_camera.enabled = player_camera_was_enabled
		if player_camera_was_enabled:
			player_camera.make_current()
			player_camera.reset_smoothing()
			player_camera.force_update_scroll()
	cutscene_camera.enabled = false


func _refresh_passive_highlight() -> void:
	if not initialized or cutscene_running:
		return
	var active := _guide_is_active(SaveGame.office_mission_state(player))
	if not active:
		_stop_passive_pulse()
		highlight.hide()
		return
	if highlight.visible and passive_pulse != null and passive_pulse.is_valid():
		return
	highlight.show()
	highlight.scale = Vector2.ONE
	highlight.modulate = Color(1.0, 1.0, 1.0, 0.62)
	passive_pulse = create_tween().set_loops()
	passive_pulse.tween_property(highlight, "modulate:a", 0.38, 0.9)
	passive_pulse.tween_property(highlight, "modulate:a", 0.72, 0.9)


func _stop_passive_pulse() -> void:
	if passive_pulse != null and passive_pulse.is_valid():
		passive_pulse.kill()
	passive_pulse = null


func _set_area_revealed(value: bool) -> void:
	if not is_instance_valid(darkness_overlay):
		return
	if value:
		if not darkness_revealed:
			darkness_overlay_was_visible = darkness_overlay.visible
			darkness_revealed = true
		darkness_overlay.hide()
	elif darkness_revealed:
		darkness_overlay.visible = darkness_overlay_was_visible
		darkness_revealed = false


func _apply_reset() -> void:
	animation_player.play(&"RESET")
	animation_player.advance(0.001)
	animation_player.stop()


func _cutscene_is_valid() -> bool:
	return (
		cutscene_running
		and is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and get_tree().current_scene == scene
	)


func _exit_tree() -> void:
	_stop_passive_pulse()
	_set_area_revealed(false)
	if is_instance_valid(area_light):
		area_light.enabled = false
	_stop_guide_hold_pulse()
	if cutscene_running:
		guide_hold_active = false
		cutscene_running = false
		_restore_player_camera()
		_unlock_player()
