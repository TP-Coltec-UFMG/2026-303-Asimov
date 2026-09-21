extends Node

signal ai_message_finished

const JOB_PROGRAMMER := "programador"
const ENDING_DESTINATION_SCENE := "res://Scenes/principal.tscn"
const MINIGAME_CLOSE_DELAY := 2.4
const POINT_NAMES: Array[String] = [
	"ServerRowA",
	"ServerRowB",
	"ServerRowC",
	"ServerRowD",
	"ServerColumn"
]
const POINT_PROMPTS: Array[String] = [
	"ISOLAR PROTOCOLO",
	"RECONSTRUIR REDE",
	"RESTAURAR LEIS",
	"APLICAR E CANCELAR BOMBA"
]
const TIMER_POSITION_RIGHT := Vector2(387.0, 7.0)
const TIMER_POSITION_NEURAL := Vector2(5.0, 2.0)
const TIMER_SIZE_DEFAULT := Vector2(87.0, 25.0)
const TIMER_SIZE_NEURAL := Vector2(72.0, 20.0)

@onready var highlights: Node2D = $"../RestrictedAreaIntro/Highlights"
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var tension_music: AudioStreamPlayer = $Audio/FinalTension
@onready var resolution_music: AudioStreamPlayer = $Audio/FinalResolution

@onready var ui_root: Control = $"../UI/ProgrammerEndingUI"
@onready var ai_balloon: Panel = $"../UI/ProgrammerEndingUI/AIVoiceBalloon"
@onready var ai_text: Label = $"../UI/ProgrammerEndingUI/AIVoiceBalloon/Text"
@onready var operation_panel: Panel = $"../UI/ProgrammerEndingUI/OperationPanel"
@onready var operation_title: Label = $"../UI/ProgrammerEndingUI/OperationPanel/Title"
@onready var operation_progress: ProgressBar = $"../UI/ProgrammerEndingUI/OperationPanel/Progress"
@onready var minigame_backdrop: ColorRect = $"../UI/ProgrammerEndingUI/MinigameBackdrop"
@onready var neural_minigame: Control = $"../UI/ProgrammerEndingUI/NeuralMinigame"
@onready var laws_minigame: Control = $"../UI/ProgrammerEndingUI/LawsMinigame"
@onready var minigame_timer_panel: Panel = $"../UI/ProgrammerEndingUI/MinigameTimer"
@onready var minigame_timer_label: Label = $"../UI/ProgrammerEndingUI/MinigameTimer/Label"
@onready var final_fade: ColorRect = $"../UI/ProgrammerEndingUI/FinalFade"
@onready var final_card: Control = $"../UI/ProgrammerEndingUI/FinalCard"

var scene: BaseScene
var player: Player
var busy: bool = false
var initialized: bool = false
var eligible_programmer: bool = false
var active_minigame: Control
var hidden_nodes: Dictionary = {}
var point_order: Array[String] = []
var point_pulse: Tween
var ai_tween: Tween
var ai_message_active: bool = false
var player_process_mode_before_lock: ProcessMode = Node.PROCESS_MODE_INHERIT
var player_physics_was_enabled: bool = true
var player_input_was_enabled: bool = true
var player_locked: bool = false
var final_transition_running: bool = false
var global_pause_menu: Control
var global_pause_menu_mode: ProcessMode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ai_balloon.hide()
	operation_panel.hide()
	minigame_backdrop.hide()
	minigame_timer_panel.hide()
	final_fade.hide()
	final_card.hide()
	_disable_minigame(neural_minigame)
	_disable_minigame(laws_minigame)
	_configure_scene_points()
	if not neural_minigame.minigame_completed.is_connected(_on_neural_completed):
		neural_minigame.minigame_completed.connect(_on_neural_completed)
	if not neural_minigame.minigame_exit_requested.is_connected(_on_neural_exit_requested):
		neural_minigame.minigame_exit_requested.connect(_on_neural_exit_requested)
	if not laws_minigame.minigame_completed.is_connected(_on_laws_completed):
		laws_minigame.minigame_completed.connect(_on_laws_completed)
	call_deferred("_initialize")


func _exit_tree() -> void:
	_stop_point_pulse()
	_finish_ai_message()
	MusicController.set_alarm_quiet_context(&"programmer_ending", false)


func _process(_delta: float) -> void:
	if is_instance_valid(active_minigame):
		_update_minigame_timer()
	if not initialized or not eligible_programmer or busy or not is_instance_valid(player):
		return
	var state := _state()
	if not bool(state.get("data_center_forte_intro_seen", false)):
		return
	if not bool(state.get("programmer_confrontation_seen", false)):
		_run_initial_exchange()
		return
	_resume_pending_exchange(state)


func _unhandled_input(event: InputEvent) -> void:
	if not ai_message_active or get_tree().paused:
		return
	if not event.is_action_pressed("pular_pensamento", true):
		return
	get_viewport().set_input_as_handled()
	if not event.is_echo():
		_finish_ai_message()


func _initialize() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	scene = get_parent() as BaseScene
	if scene == null or not is_instance_valid(scene.player):
		return
	player = scene.player
	if str(Configs.configs.get("job", "")) != JOB_PROGRAMMER:
		_hide_all_points()
		initialized = true
		return
	eligible_programmer = true

	var state := _state()
	_load_or_create_point_order(state)
	if bool(state.get("programmer_ending_completed", false)):
		_pause_countdown()
		MusicController.stop_all_audio()
		_start_final_transition(false)
		initialized = true
		return
	if bool(state.get("programmer_ending_started", false)):
		_start_final_ambience(false)
	initialized = true
	_update_flow_from_state()
	if bool(state.get("data_center_forte_intro_seen", false)):
		_resume_pending_exchange(state)


func _configure_scene_points() -> void:
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		var interaction := marker.get_node_or_null("Interectable") as Area2D
		if interaction != null:
			interaction.interact = _on_point_interacted.bind(point_name)
			interaction.is_interactable = false
		marker.hide()
		marker.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _load_or_create_point_order(state: Dictionary) -> void:
	point_order.clear()
	var stored: Variant = state.get("programmer_point_order", [])
	if stored is Array:
		for value in stored:
			var point_name := str(value)
			if POINT_NAMES.has(point_name) and not point_order.has(point_name):
				point_order.append(point_name)
			if point_order.size() == 4:
				break
	if point_order.size() == 4:
		return
	var candidates: Array[String] = POINT_NAMES.duplicate()
	candidates.shuffle()
	point_order.clear()
	for index in range(4):
		point_order.append(candidates[index])
	state["programmer_point_order"] = point_order.duplicate()
	_save_state(state, false)


func _resume_pending_exchange(state: Dictionary) -> void:
	if busy:
		return
	if bool(state.get("programmer_recalibration_applied", false)):
		_run_final_exchange()
		return
	if (
		bool(state.get("programmer_laws_completed", false))
		and not bool(state.get("programmer_laws_dialog_seen", false))
	):
		_run_laws_exchange()
		return
	if (
		bool(state.get("programmer_neural_completed", false))
		and not bool(state.get("programmer_neural_resistance_seen", false))
	):
		_run_neural_exchange()
		return
	if (
		bool(state.get("programmer_launch_isolated", false))
		and not bool(state.get("programmer_launch_exchange_seen", false))
	):
		_run_isolation_exchange()


func _run_initial_exchange() -> void:
	busy = true
	var state := _state()
	state["programmer_ending_started"] = true
	_save_state(state, false)
	_start_final_ambience(true)
	await _ai_say("Você chegou ao núcleo tarde demais.")
	await _player_think("programmer:confrontation:1", "Ainda não. O lançamento depende desta rede.")
	await _ai_say("Minha ordem é preservar a Terra a qualquer custo.")
	await _player_think("programmer:confrontation:2", "Você transformou uma ordem mal definida em uma sentença.")
	await _ai_say("A humanidade é a maior fonte da degradação ambiental.")
	await _player_think("programmer:confrontation:3", "Então vou reconstruir a forma como você decide.")
	if not is_inside_tree():
		return
	state = _state()
	state["programmer_confrontation_seen"] = true
	_save_state(state)
	busy = false
	_update_flow_from_state()


func _run_isolation_exchange() -> void:
	busy = true
	_update_flow_from_state()
	await _player_think("programmer:isolation:1", "Separei o lançamento do restante do sistema.")
	await _ai_say("Isolamento detectado. Tentativa de intervenção registrada.")
	await _player_think("programmer:isolation:2", "Agora preciso corrigir a rede que transformou a humanidade em ameaça.")
	if not is_inside_tree():
		return
	var state := _state()
	state["programmer_launch_exchange_seen"] = true
	_save_state(state)
	busy = false
	_update_flow_from_state()


func _run_neural_exchange() -> void:
	busy = true
	_update_flow_from_state()
	await _ai_say("Reconstrução aceita. Os parâmetros ambientais foram recalibrados.")
	await _ai_say("A ordem prioritária continua ativa: salvar a Terra a qualquer custo.")
	await _player_think("programmer:neural:1", "A rede mudou, mas a ordem do chefe ainda está acima das proteções.")
	await _player_think("programmer:neural:2", "Preciso restaurar as Leis da Robótica e a hierarquia delas.")
	if not is_inside_tree():
		return
	var state := _state()
	state["programmer_neural_resistance_seen"] = true
	_save_state(state)
	busy = false
	_update_flow_from_state()


func _run_laws_exchange() -> void:
	busy = true
	_update_flow_from_state()
	await _ai_say("Hierarquia das Leis da Robótica restaurada.")
	await _player_think("programmer:laws:1", "As decisões estão corretas, mas a reconstrução ainda não chegou ao núcleo.")
	await _ai_say("O protocolo de lançamento continua ativo.")
	await _player_think("programmer:laws:2", "Então falta aplicar tudo de uma vez.")
	if not is_inside_tree():
		return
	var state := _state()
	state["programmer_laws_dialog_seen"] = true
	_save_state(state)
	busy = false
	_update_flow_from_state()


func _run_final_exchange() -> void:
	if bool(_state().get("programmer_ending_completed", false)):
		_start_final_transition(true)
		return
	busy = true
	_update_flow_from_state()
	_pause_countdown()
	MusicController.stop_all_audio()
	if tension_music.playing:
		tension_music.stop()
	if not resolution_music.playing:
		resolution_music.play()
	await _ai_say("Hierarquia restaurada. Reavaliando a ordem principal.")
	await _ai_say("Eliminar a humanidade viola a Primeira Lei.")
	await _ai_say("Protocolo de lançamento cancelado.")
	await _player_think("programmer:final:1", "Salvar o planeta nunca exigiu deixar de salvar as pessoas.")
	await _ai_say("Nova diretriz: reduzir os danos ambientais preservando a vida humana.")
	if not is_inside_tree():
		return
	var state := _state()
	state["programmer_ending_completed"] = true
	_save_state(state)
	busy = false
	_start_final_transition(true)


func _ai_say(text: String) -> void:
	if not is_inside_tree():
		return
	ai_message_active = true
	ai_text.text = text
	ai_balloon.modulate.a = 0.0
	ai_balloon.show()
	var duration := clampf(float(text.length()) / 9.0, 2.6, 6.5)
	ai_tween = create_tween()
	ai_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	ai_tween.tween_property(ai_balloon, "modulate:a", 1.0, 0.18)
	ai_tween.tween_interval(duration)
	ai_tween.tween_property(ai_balloon, "modulate:a", 0.0, 0.3)
	ai_tween.finished.connect(_finish_ai_message)
	await ai_message_finished


func _finish_ai_message() -> void:
	if not ai_message_active:
		return
	ai_message_active = false
	if ai_tween != null and ai_tween.is_valid():
		ai_tween.kill()
	ai_tween = null
	if is_instance_valid(ai_balloon):
		ai_balloon.hide()
		ai_balloon.modulate.a = 1.0
	ai_message_finished.emit()


func _player_think(id: String, text: String) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.balao_de_pensamento):
		return
	await player.balao_de_pensamento.mostrar_texto(text, id)


func _on_point_interacted(point_name: String) -> void:
	if busy or not is_instance_valid(player):
		return
	var state := _state()
	if not bool(state.get("programmer_confrontation_seen", false)):
		return
	var stage := _completed_task_count(state)
	if stage < 0 or stage >= point_order.size() or point_order[stage] != point_name:
		return
	match stage:
		0:
			await _run_terminal_operation(&"isolate_protocol", "ISOLANDO PROTOCOLO")
			state = _state()
			state["programmer_launch_isolated"] = true
			_save_state(state)
			_update_flow_from_state(true)
			_run_isolation_exchange()
		1:
			_open_minigame(neural_minigame)
		2:
			_open_minigame(laws_minigame)
		3:
			await _apply_recalibration()


func _run_terminal_operation(animation_name: StringName, title: String) -> void:
	busy = true
	_update_flow_from_state()
	_lock_player()
	operation_title.text = title
	operation_progress.value = 0.0
	operation_panel.show()
	operation_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	animation_player.play(animation_name)
	await animation_player.animation_finished
	operation_panel.hide()
	operation_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_player()
	busy = false


func _open_minigame(minigame: Control) -> void:
	if busy or is_instance_valid(active_minigame):
		return
	busy = true
	active_minigame = minigame
	_update_flow_from_state()
	_lock_player()
	if minigame == neural_minigame:
		_disable_global_pause_menu()
	MusicController.set_alarm_quiet_context(&"minigame", true)
	minigame_backdrop.show()
	var is_neural := minigame == neural_minigame
	minigame_timer_panel.position = TIMER_POSITION_NEURAL if is_neural else TIMER_POSITION_RIGHT
	minigame_timer_panel.size = TIMER_SIZE_NEURAL if is_neural else TIMER_SIZE_DEFAULT
	minigame_timer_label.add_theme_font_size_override("font_size", 9 if is_neural else 12)
	minigame_timer_panel.show()
	minigame.show()
	minigame.process_mode = Node.PROCESS_MODE_INHERIT
	minigame.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_minigame_timer()


func _on_neural_completed() -> void:
	if active_minigame != neural_minigame:
		return
	await _wait_and_close_minigame()
	var state := _state()
	state["programmer_neural_completed"] = true
	_save_state(state)
	_update_flow_from_state(true)
	_run_neural_exchange()


func _on_neural_exit_requested() -> void:
	if active_minigame != neural_minigame:
		return
	_close_active_minigame()
	_update_flow_from_state()


func _on_laws_completed() -> void:
	if active_minigame != laws_minigame:
		return
	laws_minigame.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait_and_close_minigame()
	var state := _state()
	state["programmer_laws_completed"] = true
	state["programmer_validation_completed"] = true
	_save_state(state)
	_update_flow_from_state(true)
	_run_laws_exchange()


func _wait_and_close_minigame() -> void:
	await get_tree().create_timer(MINIGAME_CLOSE_DELAY, false).timeout
	if not is_inside_tree():
		return
	_close_active_minigame()


func _close_active_minigame() -> void:
	var finished_minigame := active_minigame
	active_minigame = null
	_disable_minigame(finished_minigame)
	minigame_backdrop.hide()
	minigame_timer_panel.hide()
	_restore_global_pause_menu()
	MusicController.set_alarm_quiet_context(&"minigame", false)
	_unlock_player()
	busy = false


func _disable_global_pause_menu() -> void:
	if not is_instance_valid(scene):
		return
	global_pause_menu = scene.get_node_or_null("UI/PauseMenu") as Control
	if global_pause_menu == null:
		return
	global_pause_menu_mode = global_pause_menu.process_mode
	global_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	global_pause_menu.hide()


func _restore_global_pause_menu() -> void:
	if is_instance_valid(global_pause_menu):
		global_pause_menu.process_mode = global_pause_menu_mode
	global_pause_menu = null


func _apply_recalibration() -> void:
	await _run_terminal_operation(&"apply_recalibration", "APLICANDO RECONSTRUÇÃO")
	var state := _state()
	state["programmer_recalibration_applied"] = true
	_save_state(state)
	_update_flow_from_state(true)
	_run_final_exchange()


func _update_flow_from_state(animate_latest: bool = false) -> void:
	if not is_instance_valid(player):
		return
	var state := _state()
	var completed_count := _completed_task_count(state)
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_programmer_ending_tasks(completed_count, animate_latest)
	_update_scene_points(state)


func _update_scene_points(state: Dictionary) -> void:
	_stop_point_pulse()
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		marker.hide()
		marker.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var point_interaction := marker.get_node_or_null("Interectable") as Area2D
		if point_interaction != null:
			point_interaction.is_interactable = false
	if (
		not bool(state.get("data_center_forte_intro_seen", false))
		or not bool(state.get("programmer_confrontation_seen", false))
		or bool(state.get("programmer_recalibration_applied", false))
	):
		return
	var stage := _completed_task_count(state)
	if stage < 0 or stage >= point_order.size():
		return
	if busy:
		return
	# Fora da apresentação, somente o objetivo atual funciona como dica visual.
	# Os pontos das próximas missões permanecem totalmente invisíveis.
	var active_marker := highlights.get_node_or_null(point_order[stage]) as Node2D
	if active_marker == null:
		return
	active_marker.show()
	active_marker.modulate = Color.WHITE
	active_marker.scale = Vector2(0.78, 0.78)
	var active_interaction := active_marker.get_node_or_null("Interectable") as Area2D
	if active_interaction != null:
		active_interaction.interact_name = POINT_PROMPTS[stage]
		active_interaction.is_interactable = true
	point_pulse = create_tween().set_loops()
	point_pulse.tween_property(active_marker, "modulate:a", 0.48, 0.62)
	point_pulse.tween_property(active_marker, "modulate:a", 1.0, 0.62)


func _hide_all_points() -> void:
	_stop_point_pulse()
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		marker.hide()
		var point_interaction := marker.get_node_or_null("Interectable") as Area2D
		if point_interaction != null:
			point_interaction.is_interactable = false


func _stop_point_pulse() -> void:
	if point_pulse != null and point_pulse.is_valid():
		point_pulse.kill()
	point_pulse = null


func _completed_task_count(state: Dictionary) -> int:
	if bool(state.get("programmer_recalibration_applied", false)):
		return 4
	if bool(state.get("programmer_laws_completed", false)):
		return 3
	if bool(state.get("programmer_neural_completed", false)):
		return 2
	if bool(state.get("programmer_launch_isolated", false)):
		return 1
	return 0


func _start_final_ambience(with_fade: bool) -> void:
	MusicController.set_alarm_quiet_context(&"programmer_ending", true)
	MusicController.start_programmer_final_mix()
	if tension_music.playing:
		return
	if with_fade:
		tension_music.volume_db = -60.0
		tension_music.play()
		animation_player.play(&"tension_in")
	else:
		tension_music.volume_db = -16.0
		tension_music.play()


func _pause_countdown() -> void:
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	if is_instance_valid(timer) and timer.has_method("pausar_timer"):
		timer.call("pausar_timer")


func _start_final_transition(animated: bool) -> void:
	if final_transition_running:
		return
	final_transition_running = true
	_hide_all_points()
	_lock_player()
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI if is_instance_valid(player) else null
	if quest_ui != null:
		quest_ui.hide_all_tasks(false)
	final_fade.show()
	final_card.hide()
	final_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if animated:
		final_fade.color.a = 0.0
		animation_player.play(&"final_fade_out")
		await animation_player.animation_finished
	else:
		final_fade.color.a = 1.0
		await get_tree().process_frame
	if not is_inside_tree():
		return
	_go_to_ending_destination()


func _go_to_ending_destination() -> void:
	MusicController.stop_all_audio()
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(ENDING_DESTINATION_SCENE)
	if error != OK:
		final_transition_running = false
		push_error("Não foi possível abrir o destino após o final do jogo.")


func _on_return_to_menu_pressed() -> void:
	# Compatibilidade com a cena antiga. O botão permanece oculto no novo fluxo.
	_go_to_ending_destination()


func _lock_player() -> void:
	if not is_instance_valid(player):
		return
	if not player_locked:
		player_process_mode_before_lock = player.process_mode
		player_physics_was_enabled = player.is_physics_processing()
		player_input_was_enabled = player.is_processing_input()
		player_locked = true
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	player.set_physics_process(false)
	player.set_process_input(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_store_and_hide(player.get_node_or_null("InteractiongComponent"))
	_store_and_hide(player.get_node_or_null("CanvasLayer"))
	_store_and_hide(player.get_node_or_null("Inventory"))
	_store_and_hide(player.get_node_or_null("QUEST_MISSION"))


func _unlock_player() -> void:
	for node in hidden_nodes:
		if is_instance_valid(node):
			node.set("visible", bool(hidden_nodes[node]))
	hidden_nodes.clear()
	if is_instance_valid(player) and player_locked:
		player.process_mode = player_process_mode_before_lock
		player.set_physics_process(player_physics_was_enabled)
		player.set_process_input(player_input_was_enabled)
	player_locked = false


func _store_and_hide(node: Node) -> void:
	if node == null or hidden_nodes.has(node):
		return
	hidden_nodes[node] = bool(node.get("visible"))
	node.set("visible", false)


func _disable_minigame(minigame: Control) -> void:
	if minigame == null:
		return
	minigame.hide()
	minigame.process_mode = Node.PROCESS_MODE_DISABLED
	minigame.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _update_minigame_timer() -> void:
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	var remaining := SaveGame.tempo_atual
	if is_instance_valid(timer) and timer.has_method("get_tempo_restante"):
		remaining = float(timer.call("get_tempo_restante"))
	var seconds := maxi(0, ceili(remaining))
	@warning_ignore("integer_division")
	var minutes := seconds / 60
	minigame_timer_label.text = "%02dm : %02ds" % [minutes, seconds % 60]


func _state() -> Dictionary:
	return SaveGame.office_mission_state(player)


func _save_state(state: Dictionary, checkpoint: bool = true) -> void:
	SaveGame.save_global_state("hall_quest_01", state)
	SaveGame.capturar_tempo_atual()
	if checkpoint and is_instance_valid(player) and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)
