extends Node2D

enum Stage { MOVE, RUN, PUSH, LIGHT, FIRE, INTERACT, EXIT, COMPLETE }
enum LightGuidance { EQUIP, SEARCH, STORE, COLLECT }

const CHARACTER_SELECTION_SCENE: String = "res://Scenes/slectionpage.tscn"
const MAIN_MENU_SCENE: String = "res://Scenes/principal.tscn"
const ROOM_BOUNDS: Array[Vector2] = [Vector2(-160.0, -90.0), Vector2(160.0, 90.0)]
const PLAYER_START: Vector2 = Vector2(-126.0, 43.0)
const TARGET_CRATE_START: Vector2 = Vector2(-8.0, 30.0)
const SPARE_CRATE_START: Vector2 = Vector2(40.0, -3.0)
const PLAYABLE_STAGE_COUNT: int = 7
const PULL_PRACTICE_DISTANCE: float = 6.0
const REPLACEMENT_PICKUP_DISTANCE: float = 24.0
const FLASHLIGHT_SCENE: PackedScene = preload("res://Objects/Lanterna.tscn")
const EXTINGUISHER_SCENE: PackedScene = preload("res://Objects/extintor.tscn")

@onready var player: Player = $TrainingPlayer
@onready var player_interaction_range: Area2D = $TrainingPlayer/InteractiongComponent/InteractRange
@onready var target_crate: ObjetoEmpurravel = $Props/TargetCrate
@onready var training_fire: Node2D = $Props/TrainingFire
@onready var extinguisher_pickup: Node2D = $Props/TrainingExtinguisherPickup
@onready var extinguisher_interactable: Area2D = $Props/TrainingExtinguisherPickup/Interectable
@onready var fire_label: Label = $Props/FireLabel
@onready var dark_zone_label: Label = $Props/DarkZoneLabel
@onready var move_zone: Area2D = $Zones/MoveZone
@onready var run_zone: Area2D = $Zones/RunZone
@onready var push_goal: Area2D = $Zones/PushGoal
@onready var console_area: Area2D = $Zones/ConsoleArea
@onready var exit_zone: Area2D = $Zones/ExitZone
@onready var floor_polygon: Polygon2D = $Room/Floor
@onready var training_light: CanvasModulate = $TrainingLight
@onready var door: Polygon2D = $Room/Door
@onready var console_screen: Polygon2D = $Room/Console/Screen

@onready var progress_label: Label = $UI/HUD/ObjectivePanel/Content/Progress
@onready var title_label: Label = $UI/HUD/ObjectivePanel/Content/Title
@onready var objective_label: Label = $UI/HUD/ObjectivePanel/Content/Objective
@onready var hint_label: Label = $UI/HUD/ObjectivePanel/Content/Hint
@onready var feedback_label: Label = $UI/HUD/Feedback

@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var pause_title: Label = $UI/PauseOverlay/Panel/Content/Title
@onready var pause_description: Label = $UI/PauseOverlay/Panel/Content/Description
@onready var resume_button: Button = $UI/PauseOverlay/Panel/Content/Resume
@onready var pause_menu_button: Button = $UI/PauseOverlay/Panel/Content/Menu
@onready var completion_overlay: Control = $UI/CompletionOverlay
@onready var completion_title: Label = $UI/CompletionOverlay/Panel/Content/Title
@onready var completion_continue: Button = $UI/CompletionOverlay/Panel/Content/Actions/Continue
@onready var completion_replay: Button = $UI/CompletionOverlay/Panel/Content/Actions/Replay
@onready var skip_confirmation: ConfirmationDialog = $UI/SkipConfirmation

var current_stage: Stage = Stage.MOVE
var tutorial_paused: bool = false
var dialog_paused_game: bool = false
var transition_locked: bool = false
var last_push_state: bool = false
var was_holding_target: bool = false
var push_reached_target: bool = false
var pull_practiced: bool = false
var release_practiced: bool = false
var pull_distance: float = 0.0
var last_target_crate_x: float = TARGET_CRATE_START.x
var last_near_console: bool = false
var last_light_equipped: bool = false
var last_flashlight_on: bool = false
var flashlight_was_used: bool = false
var light_guidance: LightGuidance = LightGuidance.EQUIP
var last_extinguisher_active: bool = false
var last_fire_percentage: int = -1
var training_flashlight: Node2D = null
var training_extinguisher: Node2D = null
var replacement_extinguisher_available: bool = false


func _enter_tree() -> void:
	GlobalLevelManager.ChangeTilemapBounds(ROOM_BOUNDS)


func _ready() -> void:
	player.checkpoint_enabled = false
	target_crate.save_enabled = false
	_provision_training_items()
	_configure_training_pickup()
	_configure_training_player()
	_localize_static_ui()
	_connect_ui()
	_apply_accessibility_preferences()
	_set_stage(Stage.MOVE)
	HighContrast.apply_to_tree(self)
	await get_tree().process_frame
	_announce_objective()


func _provision_training_items() -> void:
	player.inventory.add_item("lanterna", FLASHLIGHT_SCENE)
	training_flashlight = player.inventory.get_item_control("lanterna")

	if training_flashlight == null:
		push_error("Não foi possível preparar a lanterna do tutorial.")


func _configure_training_pickup() -> void:
	extinguisher_interactable.interact = _collect_training_extinguisher


func _configure_training_player() -> void:
	for node_path: NodePath in [
		^"CanvasLayer/Control/Inteligencia",
		^"CanvasLayer/Control/Vida1",
		^"CanvasLayer/Control/Vida2",
		^"CanvasLayer/Control/Vida3",
		^"CanvasLayer/Control/FPSLabel"
	]:
		var node: CanvasItem = player.get_node_or_null(node_path) as CanvasItem
		if node != null:
			node.hide()


func _localize_static_ui() -> void:
	pause_title.text = tr("TUTORIAL_PLAY_PAUSE_TITLE")
	pause_description.text = tr("TUTORIAL_PLAY_PAUSE_DESCRIPTION")
	resume_button.text = tr("TUTORIAL_PLAY_RESUME")
	pause_menu_button.text = tr("TUTORIAL_PLAY_MAIN_MENU")
	completion_title.text = tr("TUTORIAL_PLAY_COMPLETE_TITLE")
	completion_replay.text = tr("TUTORIAL_PLAY_REPLAY")
	dark_zone_label.text = tr("TUTORIAL_PLAY_DARK_ZONE")
	extinguisher_interactable.interact_name = tr("TUTORIAL_PLAY_EXTINGUISHER_LABEL")
	fire_label.text = tr("TUTORIAL_PLAY_FIRE_LABEL")


func _exit_tree() -> void:
	if tutorial_paused or dialog_paused_game or current_stage == Stage.COMPLETE:
		get_tree().paused = false


func _physics_process(_delta: float) -> void:
	if get_tree().paused or transition_locked:
		return

	match current_stage:
		Stage.MOVE:
			if move_zone.overlaps_body(player):
				_advance_to(Stage.RUN)
		Stage.RUN:
			if (
				run_zone.overlaps_body(player)
				and player.correndo
				and player.velocity.length() > Player.VELOCIDADE_NORMAL
			):
				_advance_to(Stage.PUSH)
		Stage.PUSH:
			_update_push_feedback()
		Stage.LIGHT:
			_update_light_feedback()
		Stage.FIRE:
			_update_fire_feedback()
			if is_instance_valid(training_fire) and bool(training_fire.get("apagado")):
				_advance_to(Stage.INTERACT)
		Stage.INTERACT:
			_update_console_feedback()
			if (
				console_area.overlaps_body(player)
				and Input.is_action_just_pressed(&"interact")
			):
				console_screen.color = Color(0.3, 1.0, 0.48, 1.0)
				door.color = Color(0.16, 0.72, 0.34, 0.72)
				_advance_to(Stage.EXIT)
		Stage.EXIT:
			if exit_zone.overlaps_body(player):
				_complete_tutorial()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"esc") and current_stage != Stage.COMPLETE:
		if skip_confirmation.visible:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _connect_ui() -> void:
	resume_button.pressed.connect(_resume_tutorial)
	pause_menu_button.pressed.connect(_return_to_main_menu)
	completion_continue.pressed.connect(_finish_tutorial)
	completion_replay.pressed.connect(_replay_tutorial)
	skip_confirmation.confirmed.connect(_skip_tutorial)
	skip_confirmation.canceled.connect(_cancel_skip)
	skip_confirmation.close_requested.connect(_cancel_skip)

	for button: Button in [
		resume_button,
		pause_menu_button, completion_continue, completion_replay
	]:
		button.focus_entered.connect(_announce_button.bind(button))


func _set_stage(next_stage: Stage) -> void:
	current_stage = next_stage
	transition_locked = false
	if next_stage == Stage.PUSH:
		_reset_push_training_progress()
	last_push_state = player.empurrando
	last_near_console = false
	last_light_equipped = player.usando_lanterna
	last_flashlight_on = false
	last_extinguisher_active = false
	last_fire_percentage = -1
	feedback_label.text = ""
	training_light.color = Color("010101") if next_stage == Stage.LIGHT else Color.WHITE

	var displayed_stage: int = mini(int(current_stage) + 1, PLAYABLE_STAGE_COUNT)
	progress_label.text = tr("TUTORIAL_PLAY_STEP_COUNTER").format({
		"current": displayed_stage,
		"total": PLAYABLE_STAGE_COUNT
	})

	match current_stage:
		Stage.MOVE:
			title_label.text = tr("TUTORIAL_PLAY_MOVE_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_MOVE_OBJECTIVE").format({
				"keys": _movement_keys_text()
			})
			hint_label.text = tr("TUTORIAL_PLAY_MOVE_HINT")
		Stage.RUN:
			title_label.text = tr("TUTORIAL_PLAY_RUN_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_RUN_OBJECTIVE").format({
				"run": _action_labels(&"correr"),
				"keys": _movement_keys_text()
			})
			hint_label.text = tr("TUTORIAL_PLAY_RUN_HINT")
		Stage.PUSH:
			title_label.text = tr("TUTORIAL_PLAY_PUSH_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_PUSH_OBJECTIVE").format({
				"push": _action_labels(&"empurrar")
			})
			hint_label.text = tr("TUTORIAL_PLAY_PUSH_HINT")
		Stage.LIGHT:
			_prepare_light_stage()
			title_label.text = tr("TUTORIAL_PLAY_LIGHT_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_LIGHT_OBJECTIVE").format({
				"equip": _action_labels(&"use_lanterna"),
				"toggle": _action_labels(&"acende_lanterna")
			})
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_HINT")
		Stage.FIRE:
			_prepare_fire_stage()
			title_label.text = tr("TUTORIAL_PLAY_FIRE_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_FIRE_OBJECTIVE").format({
				"equip": _action_labels(&"use_extintor"),
				"use": _action_labels(&"usar_extintor")
			})
			hint_label.text = tr("TUTORIAL_PLAY_FIRE_HINT")
		Stage.INTERACT:
			title_label.text = tr("TUTORIAL_PLAY_INTERACT_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_INTERACT_OBJECTIVE").format({
				"interact": _action_labels(&"interact")
			})
			hint_label.text = tr("TUTORIAL_PLAY_INTERACT_HINT")
		Stage.EXIT:
			title_label.text = tr("TUTORIAL_PLAY_EXIT_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_EXIT_OBJECTIVE")
			hint_label.text = tr("TUTORIAL_PLAY_EXIT_HINT")

	_update_world_markers()
	_update_accessible_names()


func _advance_to(next_stage: Stage) -> void:
	if transition_locked:
		return
	transition_locked = true
	_set_stage(next_stage)
	feedback_label.text = tr("TUTORIAL_PLAY_SUCCESS")
	_speak(tr("TUTORIAL_PLAY_SUCCESS") + " " + _objective_text_for_speech())


func _complete_tutorial() -> void:
	if transition_locked:
		return
	transition_locked = true
	current_stage = Stage.COMPLETE
	player.velocity = Vector2.ZERO
	player.reset_sprite_player()
	completion_continue.text = (
		tr("TUTORIAL_RETURN_MENU")
		if Configs.tutorial_return_scene == MAIN_MENU_SCENE
		else tr("TUTORIAL_GO_SELECTION")
	)
	completion_overlay.visible = true
	get_tree().paused = true
	completion_continue.grab_focus()
	_speak(tr("TUTORIAL_PLAY_COMPLETE_SPEECH"))


func _update_world_markers() -> void:
	move_zone.visible = current_stage == Stage.MOVE
	run_zone.visible = current_stage == Stage.RUN
	push_goal.visible = current_stage == Stage.PUSH
	$Props/TargetCrate/Highlight.visible = current_stage == Stage.PUSH
	$Props/TargetCrate/AccessibleLabel.visible = current_stage == Stage.PUSH
	dark_zone_label.visible = current_stage == Stage.LIGHT
	extinguisher_pickup.visible = current_stage == Stage.LIGHT and training_extinguisher == null
	if current_stage == Stage.FIRE and replacement_extinguisher_available:
		extinguisher_pickup.visible = true
	if is_instance_valid(training_fire):
		training_fire.visible = current_stage == Stage.FIRE
	fire_label.visible = current_stage == Stage.FIRE
	$Room/Console/Marker.visible = current_stage == Stage.INTERACT
	exit_zone.visible = current_stage == Stage.EXIT


func _update_push_feedback() -> void:
	var holding_target: bool = player.objeto_manipulado == target_crate
	var crate_delta_x: float = target_crate.global_position.x - last_target_crate_x
	last_target_crate_x = target_crate.global_position.x

	if holding_target and not was_holding_target and not push_reached_target:
		hint_label.text = tr("TUTORIAL_PLAY_PUSH_ACTIVE")
		_speak(hint_label.text)

	if holding_target and not push_reached_target and push_goal.overlaps_body(target_crate):
		push_reached_target = true
		title_label.text = tr("TUTORIAL_PLAY_PULL_TITLE")
		objective_label.text = tr("TUTORIAL_PLAY_PULL_OBJECTIVE")
		hint_label.text = tr("TUTORIAL_PLAY_PULL_HINT")
		_update_accessible_names()
		_speak(_objective_text_for_speech())
	elif holding_target and push_reached_target and not pull_practiced:
		var held_side_x: float = player.lado_objeto_manipulado.x
		if absf(crate_delta_x) > 0.01 and crate_delta_x * held_side_x < 0.0:
			pull_distance += absf(crate_delta_x)
		if pull_distance >= PULL_PRACTICE_DISTANCE:
			pull_practiced = true
			title_label.text = tr("TUTORIAL_PLAY_RELEASE_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_RELEASE_OBJECTIVE").format({
				"push": _action_labels(&"empurrar")
			})
			hint_label.text = tr("TUTORIAL_PLAY_RELEASE_HINT")
			_update_accessible_names()
			_speak(_objective_text_for_speech())

	if was_holding_target and not holding_target:
		if pull_practiced:
			release_practiced = true
			target_crate.modulate = Color(0.55, 1.0, 0.62, 1.0)
			_advance_to(Stage.LIGHT)
			return
		elif push_reached_target:
			hint_label.text = tr("TUTORIAL_PLAY_PULL_RELEASED_EARLY").format({
				"push": _action_labels(&"empurrar")
			})
			_speak(hint_label.text)
		else:
			hint_label.text = tr("TUTORIAL_PLAY_PUSH_HINT")

	last_push_state = player.empurrando
	was_holding_target = holding_target


func _reset_push_training_progress() -> void:
	was_holding_target = false
	push_reached_target = false
	pull_practiced = false
	release_practiced = false
	pull_distance = 0.0
	last_target_crate_x = target_crate.global_position.x


func _prepare_light_stage() -> void:
	player.reset_sprite_player()
	flashlight_was_used = false
	light_guidance = LightGuidance.EQUIP
	extinguisher_pickup.visible = true
	extinguisher_interactable.is_interactable = true
	extinguisher_interactable.monitorable = true
	extinguisher_interactable.monitoring = true
	if training_flashlight == null:
		return
	training_flashlight.set("lanterna_acessa", false)
	training_flashlight.call("set_luz", false)


func _flashlight_is_on() -> bool:
	return (
		training_flashlight != null
		and player.usando_lanterna
		and bool(training_flashlight.get("lanterna_acessa"))
	)


func _update_light_feedback() -> void:
	if player.usando_lanterna != last_light_equipped:
		last_light_equipped = player.usando_lanterna
		if player.usando_lanterna:
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_EQUIPPED").format({
				"toggle": _action_labels(&"acende_lanterna")
			})
			_speak(hint_label.text)
		elif not flashlight_was_used:
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_HINT")

	var flashlight_on: bool = _flashlight_is_on()
	if flashlight_on != last_flashlight_on:
		last_flashlight_on = flashlight_on
		if flashlight_on:
			flashlight_was_used = true
			_show_light_guidance(LightGuidance.SEARCH)

	if (
		flashlight_was_used
		and player_interaction_range.overlaps_area(extinguisher_interactable)
	):
		_show_light_guidance(
			LightGuidance.STORE if player.usando_lanterna else LightGuidance.COLLECT
		)


func _show_light_guidance(next_guidance: LightGuidance) -> void:
	if light_guidance == next_guidance:
		return
	light_guidance = next_guidance

	match light_guidance:
		LightGuidance.SEARCH:
			title_label.text = tr("TUTORIAL_PLAY_LIGHT_SEARCH_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_LIGHT_SEARCH_OBJECTIVE")
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_SEARCH_HINT")
		LightGuidance.STORE:
			title_label.text = tr("TUTORIAL_PLAY_LIGHT_STORE_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_LIGHT_STORE_OBJECTIVE").format({
				"equip": _action_labels(&"use_lanterna"),
				"interact": _action_labels(&"interact")
			})
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_STORE_HINT")
		LightGuidance.COLLECT:
			title_label.text = tr("TUTORIAL_PLAY_LIGHT_COLLECT_TITLE")
			objective_label.text = tr("TUTORIAL_PLAY_LIGHT_COLLECT_OBJECTIVE").format({
				"interact": _action_labels(&"interact")
			})
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_COLLECT_HINT")

	_update_accessible_names()
	_speak(_objective_text_for_speech())


func _collect_training_extinguisher() -> void:
	if transition_locked:
		return
	if current_stage == Stage.LIGHT:
		if not flashlight_was_used:
			hint_label.text = tr("TUTORIAL_PLAY_LIGHT_EQUIPPED").format({
				"toggle": _action_labels(&"acende_lanterna")
			})
			_speak(hint_label.text)
			return
		if player.usando_lanterna:
			_show_light_guidance(LightGuidance.STORE)
			return
	elif current_stage == Stage.FIRE:
		if not replacement_extinguisher_available:
			return
	else:
		return

	if not player.inventory.add_item("extintor", EXTINGUISHER_SCENE):
		push_error("Não foi possível coletar o extintor do tutorial.")
		return

	training_extinguisher = player.inventory.get_item_control("extintor")
	if training_extinguisher == null:
		push_error("O extintor coletado não foi encontrado no inventário.")
		return

	extinguisher_interactable.is_interactable = false
	extinguisher_interactable.set_deferred("monitorable", false)
	extinguisher_interactable.set_deferred("monitoring", false)
	extinguisher_pickup.hide()

	if current_stage == Stage.LIGHT:
		_advance_to(Stage.FIRE)
	else:
		replacement_extinguisher_available = false
		_show_fire_instructions()
		feedback_label.text = tr("TUTORIAL_PLAY_FUEL_REPLACED")
		_speak(feedback_label.text + " " + _objective_text_for_speech())


func _prepare_fire_stage() -> void:
	player.reset_sprite_player()
	replacement_extinguisher_available = false
	extinguisher_pickup.hide()
	if training_extinguisher == null or not is_instance_valid(training_extinguisher):
		player.inventory.remove_item("extintor")
		player.inventory.add_item("extintor", EXTINGUISHER_SCENE)
		training_extinguisher = player.inventory.get_item_control("extintor")
	if training_extinguisher != null:
		training_extinguisher.set("combustivel", 100.0)
		training_extinguisher.set("combustivel_acabou", false)
		training_extinguisher.call("set_fumaca", false)
	_reset_training_fire()


func _reset_training_fire() -> void:
	if not is_instance_valid(training_fire):
		return
	training_fire.set("vida_fogo", 100.0)
	training_fire.set("apagado", false)
	training_fire.set("extintor_atingindo", false)
	training_fire.set("dar_dano_no_corpo", false)
	training_fire.set_process(false)
	var particles: GPUParticles2D = training_fire.get_node(
		"GPUParticles2D"
	) as GPUParticles2D
	var fire_area: Area2D = training_fire.get_node("AreaFogo") as Area2D
	var fire_collision: CollisionShape2D = training_fire.get_node(
		"AreaFogo/CollisionShape2D"
	) as CollisionShape2D
	particles.emitting = true
	particles.amount_ratio = 1.0
	fire_area.monitorable = true
	fire_area.monitoring = true
	fire_collision.set_deferred("disabled", false)
	training_fire.call("atualizar_fogo")


func _update_fire_feedback() -> void:
	if training_extinguisher == null or not is_instance_valid(training_fire):
		return
	if bool(training_extinguisher.get("combustivel_acabou")):
		_spawn_replacement_extinguisher()
		return

	var extinguisher_active: bool = bool(
		training_extinguisher.get("extintor_ligado")
	)
	if extinguisher_active != last_extinguisher_active:
		last_extinguisher_active = extinguisher_active
		if extinguisher_active:
			hint_label.text = tr("TUTORIAL_PLAY_FIRE_ACTIVE")
			_speak(hint_label.text)
		else:
			hint_label.text = tr("TUTORIAL_PLAY_FIRE_HINT")

	var remaining: int = int(ceilf(float(training_fire.get("vida_fogo"))))
	if remaining != last_fire_percentage:
		last_fire_percentage = remaining
		feedback_label.text = tr("TUTORIAL_PLAY_FIRE_PROGRESS").format({
			"remaining": remaining
		})


func _spawn_replacement_extinguisher() -> void:
	if replacement_extinguisher_available:
		return

	var empty_extinguisher: Node2D = training_extinguisher
	player.reset_sprite_player()
	player.inventory.remove_item("extintor")
	training_extinguisher = null
	if is_instance_valid(empty_extinguisher):
		empty_extinguisher.queue_free()

	var horizontal_side: float = -1.0 if player.global_position.x > 0.0 else 1.0
	extinguisher_pickup.global_position = Vector2(
		clampf(
			player.global_position.x + horizontal_side * REPLACEMENT_PICKUP_DISTANCE,
			-135.0,
			135.0
		),
		clampf(player.global_position.y + 12.0, -68.0, 68.0)
	)
	extinguisher_interactable.is_interactable = true
	extinguisher_interactable.set_deferred("monitorable", true)
	extinguisher_interactable.set_deferred("monitoring", true)
	extinguisher_pickup.show()
	replacement_extinguisher_available = true

	title_label.text = tr("TUTORIAL_PLAY_FUEL_EMPTY_TITLE")
	objective_label.text = tr("TUTORIAL_PLAY_FUEL_EMPTY_OBJECTIVE").format({
		"interact": _action_labels(&"interact")
	})
	hint_label.text = tr("TUTORIAL_PLAY_FUEL_EMPTY_HINT")
	feedback_label.text = ""
	_update_accessible_names()
	_speak(_objective_text_for_speech())


func _show_fire_instructions() -> void:
	title_label.text = tr("TUTORIAL_PLAY_FIRE_TITLE")
	objective_label.text = tr("TUTORIAL_PLAY_FIRE_OBJECTIVE").format({
		"equip": _action_labels(&"use_extintor"),
		"use": _action_labels(&"usar_extintor")
	})
	hint_label.text = tr("TUTORIAL_PLAY_FIRE_HINT")
	_update_accessible_names()


func _update_console_feedback() -> void:
	var near_console: bool = console_area.overlaps_body(player)
	if near_console == last_near_console:
		return
	last_near_console = near_console
	if near_console:
		hint_label.text = tr("TUTORIAL_PLAY_INTERACT_READY").format({
			"interact": _action_labels(&"interact")
		})
		_speak(hint_label.text)
	else:
		hint_label.text = tr("TUTORIAL_PLAY_INTERACT_HINT")


func _reset_current_stage() -> void:
	player.reset_sprite_player()
	player.velocity = Vector2.ZERO
	player.cansaco = 0.0
	target_crate.global_position = TARGET_CRATE_START
	target_crate.modulate = Color.WHITE
	console_screen.color = Color(0.18, 0.86, 0.95, 1.0)
	door.color = Color(0.7, 0.18, 0.18, 0.88)

	match current_stage:
		Stage.MOVE:
			player.global_position = PLAYER_START
		Stage.RUN:
			player.global_position = Vector2(-83.0, 43.0)
		Stage.PUSH:
			player.global_position = Vector2(-32.0, 30.0)
			_reset_push_training_progress()
		Stage.LIGHT:
			player.global_position = Vector2(22.0, -36.0)
			_prepare_light_stage()
		Stage.FIRE:
			player.global_position = Vector2(62.0, 30.0)
			_prepare_fire_stage()
		Stage.INTERACT:
			player.global_position = Vector2(75.0, -35.0)
		Stage.EXIT:
			player.global_position = Vector2(88.0, 42.0)

	feedback_label.text = tr("TUTORIAL_PLAY_RESET_DONE")
	_announce_objective()


func _toggle_pause() -> void:
	if tutorial_paused:
		_resume_tutorial()
		return
	tutorial_paused = true
	get_tree().paused = true
	pause_overlay.visible = true
	resume_button.grab_focus()
	_speak(tr("TUTORIAL_PLAY_PAUSED"))


func _resume_tutorial() -> void:
	tutorial_paused = false
	pause_overlay.visible = false
	get_tree().paused = false
	_speak(tr("TUTORIAL_PLAY_RESUMED"))


func _show_skip_confirmation() -> void:
	dialog_paused_game = true
	get_tree().paused = true
	skip_confirmation.title = tr("TUTORIAL_SKIP_TITLE")
	skip_confirmation.dialog_text = tr("TUTORIAL_SKIP_CONFIRMATION")
	skip_confirmation.ok_button_text = tr("TUTORIAL_SKIP_CONFIRM")
	skip_confirmation.cancel_button_text = tr("TUTORIAL_CANCEL")
	skip_confirmation.popup_centered(Vector2i(340, 130))
	_speak(skip_confirmation.dialog_text)


func _cancel_skip() -> void:
	if not dialog_paused_game:
		return
	dialog_paused_game = false
	get_tree().paused = false


func _skip_tutorial() -> void:
	dialog_paused_game = false
	get_tree().paused = false
	Configs.configs["tutorial_seen"] = true
	_save_config()
	_change_to_return_scene()


func _finish_tutorial() -> void:
	get_tree().paused = false
	Configs.configs["tutorial_seen"] = true
	Configs.configs["tutorial_completed"] = true
	_save_config()
	_change_to_return_scene()


func _replay_tutorial() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	Configs.tutorial_return_scene = MAIN_MENU_SCENE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _change_to_return_scene() -> void:
	var destination: String = Configs.tutorial_return_scene
	if destination.is_empty() or not ResourceLoader.exists(destination):
		destination = CHARACTER_SELECTION_SCENE
	var error: Error = get_tree().change_scene_to_file(destination)
	if error != OK:
		push_error("Não foi possível sair do tutorial para: " + destination)


func _save_config() -> void:
	SaveLoad.save_data = Configs.configs.duplicate(true)
	SaveLoad._save()


func _apply_accessibility_preferences() -> void:
	var interface_index: int = int(Configs.configs.get("interface_size", 0))
	var scale_factor: float = 1.0
	if interface_index == 1:
		scale_factor = 0.9
	elif interface_index == 2:
		scale_factor = 1.12
	_set_font_size_recursive($UI, scale_factor)

	if bool(Configs.configs.get("alto_contraste", false)):
		floor_polygon.color = Color.BLACK
		for marker: Polygon2D in [
			$Zones/MoveZone/Marker, $Zones/RunZone/Marker,
			$Zones/PushGoal/Marker, $Zones/ExitZone/Marker
		]:
			marker.color.a = 0.85


func _set_font_size_recursive(node: Node, scale_factor: float) -> void:
	if node is Control:
		var control: Control = node as Control
		var base_size: int = control.get_theme_font_size(&"font_size")
		if base_size > 0:
			control.add_theme_font_size_override(
				&"font_size",
				maxi(8, int(round(float(base_size) * scale_factor)))
			)
	for child: Node in node.get_children():
		_set_font_size_recursive(child, scale_factor)


func _update_accessible_names() -> void:
	progress_label.accessibility_name = progress_label.text
	title_label.accessibility_name = title_label.text
	objective_label.accessibility_name = objective_label.text
	hint_label.accessibility_name = hint_label.text
	dark_zone_label.accessibility_name = dark_zone_label.text
	fire_label.accessibility_name = fire_label.text


func _announce_objective() -> void:
	_speak(_objective_text_for_speech())


func _objective_text_for_speech() -> String:
	return "%s. %s. %s" % [title_label.text, objective_label.text, hint_label.text]


func _announce_button(button: Button) -> void:
	_speak(button.text)


func _speak(text: String) -> void:
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(text)


func _movement_keys_text() -> String:
	return "%s/%s/%s/%s" % [
		_action_labels(&"up"), _action_labels(&"left"),
		_action_labels(&"down"), _action_labels(&"right")
	]


func _action_labels(action: StringName) -> String:
	if not InputMap.has_action(action):
		return str(action)
	var labels: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var label: String = _event_label(event)
		if not label.is_empty() and not labels.has(label):
			labels.append(label)
	return "/".join(labels) if not labels.is_empty() else str(action)


func _event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var code: Key = key_event.physical_keycode
		if code == KEY_NONE:
			code = key_event.keycode
		return OS.get_keycode_string(code)
	if event is InputEventMouseButton:
		return tr("TUTORIAL_MOUSE_LEFT")
	return event.as_text()
