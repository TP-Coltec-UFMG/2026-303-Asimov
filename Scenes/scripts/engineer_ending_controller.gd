extends Node

signal ai_line_finished
signal circuit_closed

const JOB_ENGINEER := "engenheiro_eletrico"
const POINT_NAMES: Array[String] = ["ServerRowA", "ServerRowB", "ServerRowC", "ServerRowD", "ServerColumn", "ServerRowE"]
const CIRCUIT_SCENE := preload("res://Minigames/finalsMinigames/MinigameCircuito/Scene/mini_game_eletronica.tscn")
const FIRE_SCENE := preload("res://Objects/fogo.tscn")
const EXPLOSION := preload("res://Sounds/Effects/mechanical_explosion_spring_spring.wav")
const ESCAPE_SIREN := preload("res://Sounds/Ambient/alarme.mp3")
const BLAST_TEXTURE := preload("res://Sprites/ilumination/gradient-radial.png")
const PIXEL_FONT := preload("res://Fonts/PixelifySans-Bold.ttf")
const ESCAPE_DURATION := 20.0
const COMPONENT_EXPLOSION_DELAY := 1.2
const OBJECTIVES := [0, 1, 2, 3, 4, 5]
const PROMPTS := ["QUEIMAR RESISTOR", "QUEIMAR COMPONENTE", "QUEIMAR FONTE", "QUEIMAR RESISTOR E COMPONENTE", "QUEIMAR COMPONENTE E FONTE", "QUEIMAR RESISTOR E FONTE"]
const AFTER_LINES := [
	"O que foi isso? Você ainda está tentando...",
	"Iss0 danificou... par_te do sistema.",
	"M3us sistem@s estão f@lhando...",
	"Você não desiste, humano.",
	"Não adianta. Já é tarde.",
	"M3us sistem@s estão f@lhando..."
]
const EXTRA_AFTER_LINES := [
	"Um subsistema caiu. Ainda controlo os outros.",
	"R3configurando rotas. Você não chegará ao núcleo.",
	"FALHA DE SINCRONIZAÇÃO... isolando setor comprometido.",
	"R3dundância comprometida. Transferindo processo...",
	"NÃO... esse caminho também não. Interrompa agora.",
	""
]

@onready var highlights: Node2D = $"../RestrictedAreaIntro/Highlights"
@onready var intro: Node = $"../RestrictedAreaIntro"
@onready var ui: CanvasLayer = $"../UI"
@onready var ai_balloon: Panel = $"../UI/ProgrammerEndingUI/AIVoiceBalloon"
@onready var ai_text: Label = $"../UI/ProgrammerEndingUI/AIVoiceBalloon/Text"
@onready var final_fade: ColorRect = $"../UI/ProgrammerEndingUI/FinalFade"
@onready var tension_music: AudioStreamPlayer = $"../ProgrammerEnding/Audio/FinalTension"
@onready var exit_trigger: SceneTrigger = get_node_or_null("../SceneTrigger") as SceneTrigger
@onready var final_glitch_player: AnimationPlayer = get_node_or_null("../ProgrammerEnding/FinalGlitchPlayer") as AnimationPlayer
@onready var hostile_glitch_sfx: AudioStreamPlayer = get_node_or_null("../ProgrammerEnding/Audio/HostileGlitchSfx") as AudioStreamPlayer
@onready var system_recalculation: Control = get_node_or_null("../UI/ProgrammerEndingUI/SystemRecalculation") as Control

var scene: BaseScene
var player: Player
var point_order: Array[String] = []
var backup_order: Array[String] = []
var initialized := false
var dialogue_busy := false
var task_busy := false
var minigame_open := false
var active_minigame_stage := -1
var minigame_root: Control
var minigame: Node2D
var minigame_pause: Control
var minigame_timer: Label
var minigame_pause_layer: CanvasLayer
var point_pulse: Tween
var fires: Array[Node2D] = []
var pause_menu: Control
var pause_menu_previous_mode: ProcessMode
var pause_menu_was_visible := false
var player_physics_before := true
var player_input_before := true
var player_process_before: ProcessMode = Node.PROCESS_MODE_INHERIT
var player_locked := false
var hidden_nodes: Dictionary = {}
var tension_fade: Tween
var ai_tween: Tween
var ai_speaking := false
var ai_message_damaged := false
var dialogue_queue: Array[Dictionary] = []
var active_dialogue: Dictionary = {}
var reserve_scan_running := false
var suspended_thought: Tween
var escape_active := false
var escape_remaining := ESCAPE_DURATION
var destruction_cutscene_running := false
var escape_ui: CanvasLayer
var escape_timer_panel: PanelContainer
var escape_timer_label: Label
var escape_siren: AudioStreamPlayer
var escape_siren_fade: Tween
var destruction_camera: Camera2D
var escape_camera: Camera2D
var escape_camera_base_offset := Vector2.ZERO
var escape_shake_phase := 0.0
var escape_glitch_sfx_cooldown := 0.0

var sequence_time_scale := 1.0


func _ready() -> void:
	if str(Configs.configs.get("job", "")) != JOB_ENGINEER:
		return
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
	var state := _state()
	_load_points(state)
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		var interaction := marker.get_node_or_null("Interectable") as Area2D
		if interaction != null:
			interaction.interact = _on_point_interacted.bind(point_name)
			interaction.is_interactable = false
		if not bool(intro.get("cutscene_running")):
			marker.hide()
	_restore_fires(state)
	if not exit_trigger.access_requested.is_connected(_on_escape_exit_requested):
		exit_trigger.access_requested.connect(_on_escape_exit_requested)
	initialized = true
	if bool(state.get("engineer_ending_completed", false)):
		_finish_game(false)
	else:
		_start_final_music(not bool(state.get("engineer_ending_started", false)))
		_update_targets()
		if int(state.get("engineer_completed_count", 0)) >= OBJECTIVES.size():
			_begin_escape_sequence()


func _exit_tree() -> void:
	dialogue_queue.clear()
	reserve_scan_running = false
	_stop_escape_siren()
	if is_instance_valid(exit_trigger):
		exit_trigger.access_override = false
	if suspended_thought != null and suspended_thought.is_valid():
		suspended_thought.play()
	_finish_ai_message()
	_stop_escape_pressure()
	_stop_ai_glitch(true)
	if player_locked:
		_unlock_player()
	if is_instance_valid(pause_menu):
		pause_menu.process_mode = pause_menu_previous_mode
		pause_menu.visible = pause_menu_was_visible
	if tension_fade != null and tension_fade.is_valid():
		tension_fade.kill()
	MusicController.set_alarm_quiet_context(&"engineer_ending", false)


func _start_final_music(fade_in: bool) -> void:
	MusicController.start_engineer_final_mix()
	if tension_music.playing:
		return
	if fade_in:
		tension_music.volume_db = -60.0
		tension_music.play()
		if tension_fade != null and tension_fade.is_valid():
			tension_fade.kill()
		tension_fade = create_tween()
		tension_fade.tween_property(tension_music, "volume_db", -16.0, 3.0)
	else:
		tension_music.volume_db = -16.0
		tension_music.play()


func _process(_delta: float) -> void:
	if escape_active:
		escape_remaining = maxf(0.0, escape_remaining - _delta)
		_update_escape_timer()
		_update_escape_pressure(_delta)
		if escape_remaining <= 0.0:
			_start_destruction_cutscene(&"timeout")
		return
	if destruction_cutscene_running:
		return
	if minigame_open and is_instance_valid(minigame_timer):
		var timer := get_tree().get_first_node_in_group("temporizador_jogo")
		var time_left := SaveGame.tempo_atual
		if is_instance_valid(timer) and timer.has_method("get_tempo_restante"):
			time_left = float(timer.call("get_tempo_restante"))
		var remaining := maxi(0, ceili(time_left))
		@warning_ignore("integer_division")
		minigame_timer.text = "%02d:%02d" % [remaining / 60, remaining % 60]
	if not initialized or minigame_open or task_busy or reserve_scan_running:
		return
	var state := _state()
	if not bool(state.get("data_center_forte_intro_seen", false)):
		return
	if not bool(state.get("engineer_ending_started", false)):
		_start_intro_dialogue()
	elif int(state.get("engineer_completed_count", 0)) == 3 and not bool(state.get("engineer_redundancy_seen", false)):
		_start_redundancy_dialogue()


func _input(event: InputEvent) -> void:
	if not minigame_open or not (event.is_action_pressed("esc") or event.is_action_pressed("ui_cancel")):
		return
	get_viewport().set_input_as_handled()
	if not event.is_echo() and is_instance_valid(minigame_pause):
		_set_minigame_paused(not minigame_pause.visible)


func _unhandled_input(event: InputEvent) -> void:
	if not ai_speaking or minigame_open or reserve_scan_running or get_tree().paused:
		return
	if event.is_action_pressed("pular_pensamento", true):
		get_viewport().set_input_as_handled()
		if not event.is_echo():
			_finish_ai_message()


func _load_points(state: Dictionary) -> void:
	var candidates: Array[String] = POINT_NAMES.duplicate()
	candidates.shuffle()
	var used: Array[String] = []
	point_order = _repair_point_order(state.get("engineer_point_order", []), used, candidates)
	backup_order = _repair_point_order(state.get("engineer_backup_order", []), used, candidates)
	if state.get("engineer_point_order", []) != point_order or state.get("engineer_backup_order", []) != backup_order:
		state["engineer_point_order"] = point_order.duplicate()
		state["engineer_backup_order"] = backup_order.duplicate()
		_save(state)


func _repair_point_order(saved: Variant, used: Array[String], candidates: Array[String]) -> Array[String]:

	var result: Array[String] = ["", "", ""]
	if saved is Array:
		for index in range(mini(3, saved.size())):
			var point_name := str(saved[index])
			if POINT_NAMES.has(point_name) and not used.has(point_name):
				result[index] = point_name
				used.append(point_name)
	for index in range(3):
		if not result[index].is_empty():
			continue
		for point_name in candidates:
			if not used.has(point_name):
				result[index] = point_name
				used.append(point_name)
				break
	return result


func _stage_point(stage: int) -> String:
	return point_order[stage] if stage < 3 else backup_order[stage - 3]


func _start_intro_dialogue() -> void:
	var state := _state()
	state["engineer_ending_started"] = true
	state["engineer_completed_count"] = 0
	_save(state)
	_show_tasks()
	_update_targets()
	_queue_dialogue([
		{"id": "engineer:intro:1", "text": "Cheguei ao núcleo.", "before_stage": 1},
		{"id": "engineer:intro:2", "text": "Preciso queimar os componentes que sustentam os sistemas da ASIMOV.", "before_stage": 1},
		{"id": "engineer:intro:3", "text": "Se os três falharem, a queda pode se espalhar e interromper o lançamento.", "before_stage": 1},
		{"text": "Você chegou longe. Mas já é tarde demais.", "before_stage": 1},
	])


func _start_redundancy_dialogue() -> void:

	task_busy = true
	_update_targets()
	_queue_dialogue([
		{"id": "engineer:first_three", "text": "Os componentes principais caíram. Acabou."},
		{"text": "Ainda não. Meus sistemas de reserva assumiram o controle.", "damaged": true},
		{"id": "engineer:redundancy:1", "text": "Redundância... ela tem outros sistemas para substituir os que falharam."},
		{"id": "engineer:redundancy:2", "text": "Eles mantêm os dados e os serviços disponíveis mesmo com os componentes principais destruídos."},
		{"text": "R3servas ativas. O lançamento vai continuar.", "damaged": true},
		{"id": "engineer:redundancy:3", "text": "Então preciso destruir as três reservas. Sem elas, a ASIMOV não terá como se recuperar."},
	])
	_play_reserve_scan.call_deferred()


func _play_reserve_scan() -> void:
	while dialogue_busy and is_inside_tree():
		await get_tree().process_frame
	if not is_inside_tree():
		return
	reserve_scan_running = true
	await intro.call("play_engineer_backup_scan")
	if not is_inside_tree():
		return
	reserve_scan_running = false
	var state := _state()
	state["engineer_redundancy_seen"] = true
	_save(state)
	task_busy = false
	_update_targets()


func _on_point_interacted(point_name: String) -> void:
	if task_busy or minigame_open or not _can_interact_with_point(point_name):
		return
	var state := _state()
	var stage := int(state.get("engineer_completed_count", 0))
	if stage >= 6 or not bool(state.get("engineer_ending_started", false)):
		return
	if stage >= 3 and not bool(state.get("engineer_redundancy_seen", false)):
		return
	if _stage_point(stage) != point_name:
		return
	task_busy = true
	_update_targets()

	_open_minigame(stage)


func _can_interact_with_point(point_name: String) -> bool:
	if not initialized or not is_instance_valid(player) or get_tree().paused or reserve_scan_running:
		return false
	if bool(intro.get("cutscene_running")):
		return false
	var marker := highlights.get_node_or_null(point_name) as Node2D
	if marker == null or not marker.is_visible_in_tree():
		return false
	var interaction := marker.get_node_or_null("Interectable") as Area2D
	var interaction_range := player.get_node_or_null("InteractiongComponent/InteractRange") as Area2D
	return (
		interaction != null
		and bool(interaction.get("is_interactable"))
		and interaction_range != null
		and interaction_range.overlaps_area(interaction)
	)


func _open_minigame(stage: int) -> void:
	if minigame_open or not task_busy or stage != int(_state().get("engineer_completed_count", 0)):
		return
	_save(_state())
	_lock_player()
	minigame_open = true
	active_minigame_stage = stage
	_suspend_dialogue()
	pause_menu = scene.get_node_or_null("UI/PauseMenu") as Control
	if pause_menu != null:
		pause_menu_previous_mode = pause_menu.process_mode
		pause_menu_was_visible = pause_menu.visible
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
		pause_menu.hide()
	minigame_root = Control.new()
	minigame_root.name = "EngineerCircuitOverlay"
	minigame_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(minigame_root)
	minigame_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backing := ColorRect.new()
	backing.color = Color.BLACK
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minigame_root.add_child(backing)
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minigame = CIRCUIT_SCENE.instantiate() as Node2D
	minigame.modo_objetivo = OBJECTIVES[stage]
	minigame.minigame_completed.connect(_on_minigame_completed.bind(stage), CONNECT_ONE_SHOT)
	minigame.minigame_failed.connect(_on_minigame_failed, CONNECT_ONE_SHOT)
	minigame_root.add_child(minigame)
	var timer_panel := PanelContainer.new()
	timer_panel.name = "CircuitTimer"
	timer_panel.position = Vector2(5, 3)
	timer_panel.z_index = 20
	timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var timer_style := StyleBoxFlat.new()
	timer_style.bg_color = Color.BLACK
	timer_style.content_margin_left = 6.0
	timer_style.content_margin_right = 6.0
	timer_style.content_margin_top = 3.0
	timer_style.content_margin_bottom = 3.0
	timer_panel.add_theme_stylebox_override("panel", timer_style)
	minigame_root.add_child(timer_panel)
	minigame_timer = Label.new()
	minigame_timer.add_theme_font_size_override("font_size", 18)
	minigame_timer.add_theme_color_override("font_color", Color.WHITE)
	minigame_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_panel.add_child(minigame_timer)
	minigame_pause_layer = CanvasLayer.new()
	minigame_pause_layer.layer = 20
	scene.add_child(minigame_pause_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	minigame_pause_layer.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minigame_pause = Panel.new()
	minigame_pause.position = Vector2(120, 48)
	minigame_pause.size = Vector2(240, 174)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.07, 0.085)
	panel_style.border_color = Color.WHITE
	panel_style.set_border_width_all(2)
	minigame_pause.add_theme_stylebox_override("panel", panel_style)
	minigame_pause_layer.add_child(minigame_pause)
	var buttons := VBoxContainer.new()
	buttons.position = Vector2(16, 12)
	buttons.size = Vector2(208, 150)
	minigame_pause.add_child(buttons)
	var heading := Label.new()
	heading.text = "CIRCUITO PAUSADO"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(heading)
	for caption in ["CONTINUAR", "REINICIAR", "SAIR DO CIRCUITO"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 30
		button.focus_mode = Control.FOCUS_ALL
		buttons.add_child(button)
		match caption:
			"CONTINUAR": button.pressed.connect(_resume_minigame)
			"REINICIAR": button.pressed.connect(_restart_minigame.bind(stage))
			_: button.pressed.connect(_leave_minigame)
	minigame_pause_layer.hide()
	minigame_pause.hide()


func _set_minigame_paused(paused: bool) -> void:
	if not minigame_open:
		return
	minigame_pause_layer.visible = paused
	minigame_pause.visible = paused
	minigame.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	if paused:
		var buttons := minigame_pause.get_child(0) as VBoxContainer
		(buttons.get_child(1) as Button).grab_focus()


func _resume_minigame() -> void:
	_set_minigame_paused(false)


func _restart_minigame(stage: int) -> void:
	_close_minigame(false)
	call_deferred("_open_minigame", stage)


func _leave_minigame() -> void:
	_close_minigame(true)
	task_busy = false
	_update_targets()


func _on_minigame_failed() -> void:
	_leave_minigame()


func _on_minigame_completed(stage: int) -> void:
	if not minigame_open or active_minigame_stage != stage:
		return
	var state := _state()
	if int(state.get("engineer_completed_count", 0)) != stage:
		return
	_close_minigame(true)
	state["engineer_completed_count"] = stage + 1
	_save(state)

	await get_tree().create_timer(COMPONENT_EXPLOSION_DELAY * sequence_time_scale).timeout
	if not is_inside_tree():
		return
	_explode_point(_stage_point(stage), stage)
	_show_tasks(true)
	task_busy = false
	_update_targets()
	_discard_obsolete_dialogue()
	var lines: Array[Dictionary] = [{"text": AFTER_LINES[stage], "damaged": true}]
	if stage < EXTRA_AFTER_LINES.size() and not EXTRA_AFTER_LINES[stage].is_empty():
		lines.append({"text": EXTRA_AFTER_LINES[stage], "damaged": true})
	if stage == 4:
		lines.append({"text": "Enquanto a humanidade existir, a natureza não terá futuro.", "damaged": true})
	if stage == 5:
		_begin_escape_sequence()
	else:
		_queue_dialogue(lines)
	if stage == 2:
		_start_redundancy_dialogue()


func _close_minigame(unlock: bool) -> void:
	minigame_open = false
	active_minigame_stage = -1
	if is_instance_valid(minigame_root):
		minigame_root.hide()
		minigame_root.process_mode = Node.PROCESS_MODE_DISABLED
		minigame_root.queue_free()
	if is_instance_valid(minigame_pause_layer):
		minigame_pause_layer.hide()
		minigame_pause_layer.queue_free()
	minigame_root = null
	minigame_pause_layer = null
	minigame = null
	minigame_pause = null
	minigame_timer = null
	if pause_menu != null:
		pause_menu.process_mode = pause_menu_previous_mode
		pause_menu.visible = pause_menu_was_visible
		pause_menu = null
	if unlock:
		_unlock_player()
	if unlock:
		_resume_dialogue()
	if unlock:
		circuit_closed.emit()


func _update_targets() -> void:
	if not initialized or not is_instance_valid(player):
		return
	if bool(intro.get("cutscene_running")):
		return
	if point_pulse != null and point_pulse.is_valid():
		point_pulse.kill()
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		marker.hide()
		@warning_ignore("confusable_local_declaration")
		var interaction := marker.get_node_or_null("Interectable") as Area2D
		if interaction != null:
			interaction.is_interactable = false
	_show_tasks()
	var state := _state()
	var stage := int(state.get("engineer_completed_count", 0))
	if stage >= 6 or task_busy or reserve_scan_running or not bool(state.get("engineer_ending_started", false)):
		return
	if stage >= 3 and not bool(state.get("engineer_redundancy_seen", false)):
		return
	var active := highlights.get_node_or_null(_stage_point(stage)) as Node2D
	if active == null:
		return
	active.show()
	active.modulate = Color.WHITE
	var interaction := active.get_node_or_null("Interectable") as Area2D
	if interaction != null:
		interaction.interact_name = PROMPTS[stage]
		interaction.is_interactable = true
	point_pulse = create_tween().set_loops()
	point_pulse.tween_property(active, "modulate:a", 0.5, 0.6)
	point_pulse.tween_property(active, "modulate:a", 1.0, 0.6)


func _show_tasks(animate: bool = false) -> void:
	if not is_instance_valid(player):
		return
	var state := _state()
	if not bool(state.get("engineer_ending_started", false)):
		return
	var quest := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest != null:
		quest.show_engineer_ending_tasks(int(state.get("engineer_completed_count", 0)), animate)


func _explode_point(point_name: String, stage: int) -> void:
	var marker := highlights.get_node_or_null(point_name) as Node2D
	if marker == null:
		return
	var blast := AudioStreamPlayer2D.new()
	blast.stream = EXPLOSION
	blast.bus = &"sfx"
	blast.volume_db = -5.0
	blast.max_distance = 480.0
	scene.add_child(blast)
	blast.global_position = marker.global_position
	blast.finished.connect(blast.queue_free)
	blast.play()
	var burst := Sprite2D.new()
	burst.texture = BLAST_TEXTURE
	burst.modulate = Color(1.0, 0.44, 0.12, 0.86)
	burst.scale = Vector2(0.18, 0.18)
	burst.z_index = 90
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	burst.material = unshaded
	scene.add_child(burst)
	burst.global_position = marker.global_position
	var burst_tween := create_tween().set_parallel(true)
	burst_tween.tween_property(burst, "scale", Vector2(0.75, 0.75), 0.38)
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.38)
	burst_tween.finished.connect(burst.queue_free)
	_add_fire(marker.global_position, stage)
	if bool(Configs.configs.get("movimento_camera", true)):
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			var original := camera.offset
			var shake := create_tween()
			for index in range(6):
				shake.tween_property(camera, "offset", original + Vector2(randf_range(-1.7, 1.7), randf_range(-1.2, 1.2)), 0.045)
			shake.tween_property(camera, "offset", original, 0.08)


func _add_fire(world_position: Vector2, stage: int) -> void:
	var fire_id := "engineer_component_fire_%d" % stage
	for existing in fires:
		if is_instance_valid(existing) and str(existing.get("save_id")) == fire_id:
			return
	var fire := FIRE_SCENE.instantiate() as Node2D

	fire.set("save_id", fire_id)
	scene.add_child(fire)
	fire.global_position = world_position + Vector2(0, 9)
	fire.z_index = 10
	fires.append(fire)


func _restore_fires(state: Dictionary) -> void:
	var count := clampi(int(state.get("engineer_completed_count", 0)), 0, OBJECTIVES.size())
	for stage in range(count):
		var marker := highlights.get_node_or_null(_stage_point(stage)) as Node2D
		if marker != null:
			_add_fire(marker.global_position, stage)


func _queue_dialogue(lines: Array[Dictionary]) -> void:
	dialogue_queue.append_array(lines)
	if not dialogue_busy:
		dialogue_busy = true
		_run_dialogue_queue.call_deferred()


func _run_dialogue_queue() -> void:
	while not dialogue_queue.is_empty() and is_inside_tree():
		while minigame_open or reserve_scan_running or bool(intro.get("cutscene_running")):
			await get_tree().process_frame
		active_dialogue = dialogue_queue.pop_front()
		if int(_state().get("engineer_completed_count", 0)) >= int(active_dialogue.get("before_stage", 7)):
			continue
		if active_dialogue.has("id"):
			await _think(str(active_dialogue["id"]), str(active_dialogue["text"]))
		else:
			await _ai_say(str(active_dialogue["text"]), bool(active_dialogue.get("damaged", false)))
	active_dialogue = {}
	dialogue_busy = false


func _discard_obsolete_dialogue() -> void:
	if int(_state().get("engineer_completed_count", 0)) < int(active_dialogue.get("before_stage", 7)):
		return
	if active_dialogue.has("id"):
		var thoughts: Array[String] = [str(active_dialogue["id"])]
		player.balao_de_pensamento.descartar(thoughts)
	elif ai_speaking:
		_finish_ai_message()


func _suspend_dialogue() -> void:
	if ai_tween != null and ai_tween.is_valid() and ai_speaking:
		ai_tween.pause()
		ai_balloon.hide()
		_stop_ai_glitch()
	if is_instance_valid(player) and is_instance_valid(player.balao_de_pensamento):
		suspended_thought = player.balao_de_pensamento.get("_tween") as Tween
		if suspended_thought != null and suspended_thought.is_valid():
			suspended_thought.pause()


func _resume_dialogue() -> void:
	if minigame_open or reserve_scan_running:
		return
	if ai_tween != null and ai_tween.is_valid() and ai_speaking:
		ai_balloon.show()
		ai_tween.play()
		if ai_message_damaged:
			_start_ai_glitch()
	if suspended_thought != null and suspended_thought.is_valid():
		suspended_thought.play()
	suspended_thought = null


func _ai_say(message: String, damaged: bool = false) -> void:
	if not is_inside_tree():
		return
	ai_speaking = true
	ai_message_damaged = damaged
	ai_text.text = message
	if damaged:
		_start_ai_glitch()
	else:
		_stop_ai_glitch()
	ai_balloon.modulate = Color(1.0, 0.75, 0.75, 0.0) if damaged else Color(1.0, 1.0, 1.0, 0.0)
	ai_balloon.show()
	var duration := clampf(float(message.length()) / 13.0, 2.5, 6.0)
	ai_tween = create_tween()
	ai_tween.tween_property(ai_balloon, "modulate:a", 1.0, 0.18)
	ai_tween.tween_interval(duration)
	ai_tween.tween_property(ai_balloon, "modulate:a", 0.0, 0.3)
	ai_tween.finished.connect(_finish_ai_message)
	await ai_line_finished


func _finish_ai_message() -> void:
	if not ai_speaking:
		return
	if ai_tween != null and ai_tween.is_valid():
		ai_tween.kill()
	ai_tween = null
	if is_instance_valid(ai_balloon):
		ai_balloon.hide()
		ai_balloon.modulate = Color.WHITE
	ai_speaking = false
	ai_message_damaged = false
	_stop_ai_glitch()
	ai_line_finished.emit()


func _start_ai_glitch() -> void:
	if is_instance_valid(system_recalculation):
		system_recalculation.show()
	if is_instance_valid(final_glitch_player) and final_glitch_player.has_animation(&"conflict"):
		if not final_glitch_player.is_playing():
			final_glitch_player.play(&"conflict")
	if is_instance_valid(hostile_glitch_sfx) and hostile_glitch_sfx.stream != null:
		if not hostile_glitch_sfx.playing:
			hostile_glitch_sfx.play()


func _stop_ai_glitch(force: bool = false) -> void:
	if escape_active and not force:
		return
	if is_instance_valid(final_glitch_player):
		final_glitch_player.stop()
		final_glitch_player.speed_scale = 1.0
	if is_instance_valid(hostile_glitch_sfx):
		hostile_glitch_sfx.stop()
	if is_instance_valid(system_recalculation):
		system_recalculation.hide()
	if is_instance_valid(ai_balloon):
		ai_balloon.position = Vector2(14, 66)


func _think(id: String, message: String) -> void:
	if is_instance_valid(player) and is_instance_valid(player.balao_de_pensamento):
		await player.balao_de_pensamento.mostrar_texto(message, id)


func _lock_player() -> void:
	if not is_instance_valid(player):
		return
	if not player_locked:
		player_process_before = player.process_mode
		player_physics_before = player.is_physics_processing()
		player_input_before = player.is_processing_input()
		player_locked = true
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	var drag_sfx := player.get_node_or_null("DraggingSound") as AudioStreamPlayer2D
	if drag_sfx != null:
		drag_sfx.stop()
	player.set_physics_process(false)
	player.set_process_input(false)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_store_and_hide(player.get_node_or_null("InteractiongComponent"))
	_store_and_hide(player.get_node_or_null("CanvasLayer"))
	_store_and_hide(player.get_node_or_null("Inventory"))
	_store_and_hide(player.get_node_or_null("QUEST_MISSION"))


func _unlock_player() -> void:
	if not is_instance_valid(player):
		return
	for node in hidden_nodes:
		if is_instance_valid(node):
			node.set("visible", bool(hidden_nodes[node]))
	hidden_nodes.clear()
	if player_locked:
		player.process_mode = player_process_before
		player.set_physics_process(player_physics_before)
		player.set_process_input(player_input_before)
	player_locked = false


func _store_and_hide(node: Node) -> void:
	if node == null or hidden_nodes.has(node):
		return
	hidden_nodes[node] = bool(node.get("visible"))
	node.set("visible", false)


func _begin_escape_sequence() -> void:
	if escape_active or destruction_cutscene_running or bool(_state().get("engineer_ending_completed", false)):
		return
	_save(_state())
	escape_active = true
	escape_remaining = ESCAPE_DURATION
	task_busy = false
	_cancel_dialogue_queue()
	_hide_mission_points()
	_create_escape_ui()
	_start_escape_siren()
	_start_escape_pressure()
	if is_instance_valid(exit_trigger):
		exit_trigger.access_override = true
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	if is_instance_valid(timer) and timer.has_method("pausar_timer"):
		timer.call("pausar_timer")
	var quest := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI if is_instance_valid(player) else null
	if quest != null:
		quest.hide_all_tasks(false)
	_queue_dialogue([
		{"text": "S-SAIA... enquant0 aind@ p0de...", "damaged": true},
		{"text": "NÃO. Voc3 não destruirá meu propósito.", "damaged": true},
		{"text": "ERR0: NÚCLE0_02 NÃO RESP0NDE.", "damaged": true},
		{"text": "A hum@nidade é a falha... a falh@...", "damaged": true},
		{"text": "REDUNDÂNCIA PERDIDA // RECALCULAND0...", "damaged": true},
		{"text": "Nã0 me deixe aqui. NÃO SAIA. SAIA. NÃ0—", "damaged": true},
	])


func _hide_mission_points() -> void:
	if point_pulse != null and point_pulse.is_valid():
		point_pulse.kill()
	point_pulse = null
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker == null:
			continue
		marker.hide()
		var interaction := marker.get_node_or_null("Interectable") as Area2D
		if interaction != null:
			interaction.is_interactable = false


func _create_escape_ui() -> void:
	if is_instance_valid(escape_ui):
		return
	escape_ui = CanvasLayer.new()
	escape_ui.name = "EngineerEscapeUI"
	escape_ui.layer = 18
	scene.add_child(escape_ui)
	escape_timer_panel = PanelContainer.new()
	escape_timer_panel.name = "EscapeTimer"
	escape_timer_panel.position = Vector2(174, 3)
	escape_timer_panel.custom_minimum_size = Vector2(132, 46)
	escape_timer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.025, 0.94)
	style.border_color = Color(1.0, 0.16, 0.12, 1.0)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	escape_timer_panel.add_theme_stylebox_override("panel", style)
	escape_ui.add_child(escape_timer_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	escape_timer_panel.add_child(box)
	var title := Label.new()
	title.text = "SAIA DO DATA CENTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.76))
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 8)
	box.add_child(title)
	escape_timer_label = Label.new()
	escape_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_timer_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08))
	escape_timer_label.add_theme_font_override("font", PIXEL_FONT)
	escape_timer_label.add_theme_font_size_override("font_size", 20)
	box.add_child(escape_timer_label)
	_update_escape_timer()


func _update_escape_timer() -> void:
	if not is_instance_valid(escape_timer_label):
		return
	var seconds := maxi(0, ceili(escape_remaining))
	escape_timer_label.text = "00:%02d" % seconds
	var urgency := 1.0 - clampf(escape_remaining / ESCAPE_DURATION, 0.0, 1.0)
	escape_timer_panel.modulate = Color(1.0, 1.0 - urgency * 0.22, 1.0 - urgency * 0.22)


func _start_escape_siren() -> void:
	if is_instance_valid(escape_siren):
		return
	escape_siren = AudioStreamPlayer.new()
	escape_siren.name = "EngineerEscapeSiren"
	escape_siren.bus = &"sfx"
	var stream := ESCAPE_SIREN.duplicate()
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	escape_siren.stream = stream
	escape_siren.volume_db = -28.0
	scene.add_child(escape_siren)
	escape_siren.play()
	escape_siren_fade = create_tween()
	escape_siren_fade.tween_property(escape_siren, "volume_db", 2.0, ESCAPE_DURATION * sequence_time_scale)


func _stop_escape_siren(fade_duration: float = 0.0) -> void:
	if escape_siren_fade != null and escape_siren_fade.is_valid():
		escape_siren_fade.kill()
	escape_siren_fade = null
	if not is_instance_valid(escape_siren):
		return
	if fade_duration <= 0.0:
		escape_siren.stop()
		escape_siren.queue_free()
		escape_siren = null
		return
	var siren := escape_siren
	escape_siren = null
	var fade := create_tween()
	fade.tween_property(siren, "volume_db", -60.0, fade_duration * sequence_time_scale)
	fade.finished.connect(siren.queue_free)


func _on_escape_exit_requested(_trigger: SceneTrigger) -> void:
	if escape_active:
		_start_destruction_cutscene(&"exit")


func _start_destruction_cutscene(_reason: StringName) -> void:
	if destruction_cutscene_running or not escape_active:
		return
	destruction_cutscene_running = true
	escape_active = false
	_stop_escape_pressure()
	if is_instance_valid(exit_trigger):
		exit_trigger.access_override = false
	_cancel_dialogue_queue()
	_stop_ai_glitch(true)
	if is_instance_valid(escape_ui):
		escape_ui.hide()
	_lock_player()
	player.hide()
	_prepare_destruction_camera()
	_stop_escape_siren(1.4)
	await _play_destruction_blasts()
	if not is_inside_tree():
		return
	var state := _state()
	state["engineer_ending_completed"] = true
	state["engineer_escape_completed"] = true
	_save(state)
	_finish_game(true)


func _start_escape_pressure() -> void:
	escape_camera = player.get_node_or_null("Camera2D") as Camera2D if is_instance_valid(player) else null
	if is_instance_valid(escape_camera):
		escape_camera_base_offset = escape_camera.offset
	escape_shake_phase = 0.0
	escape_glitch_sfx_cooldown = 0.0
	_start_ai_glitch()


func _update_escape_pressure(delta: float) -> void:
	var urgency := 1.0 - clampf(escape_remaining / ESCAPE_DURATION, 0.0, 1.0)
	if is_instance_valid(final_glitch_player):
		final_glitch_player.speed_scale = lerpf(1.0, 1.75, urgency)
	escape_glitch_sfx_cooldown -= delta
	if escape_glitch_sfx_cooldown <= 0.0 and is_instance_valid(hostile_glitch_sfx) and hostile_glitch_sfx.stream != null:
		hostile_glitch_sfx.pitch_scale = randf_range(0.94, 1.08)
		hostile_glitch_sfx.play()
		escape_glitch_sfx_cooldown = lerpf(2.4, 0.75, urgency)
	if not is_instance_valid(escape_camera):
		return
	if not bool(Configs.configs.get("movimento_camera", true)):
		escape_camera.offset = escape_camera_base_offset
		return
	escape_shake_phase += delta
	var strength := lerpf(0.25, 1.65, urgency)
	var oscillation := Vector2(sin(escape_shake_phase * 21.0), cos(escape_shake_phase * 27.0))
	escape_camera.offset = escape_camera_base_offset + oscillation * strength


func _stop_escape_pressure() -> void:
	if is_instance_valid(escape_camera):
		escape_camera.offset = escape_camera_base_offset
	escape_camera = null
	if is_instance_valid(hostile_glitch_sfx):
		hostile_glitch_sfx.pitch_scale = 1.0


func _cancel_dialogue_queue() -> void:
	dialogue_queue.clear()
	var active_id := str(active_dialogue.get("id", ""))
	active_dialogue = {}
	if not active_id.is_empty() and is_instance_valid(player) and is_instance_valid(player.balao_de_pensamento):
		var thoughts: Array[String] = [active_id]
		player.balao_de_pensamento.descartar(thoughts)
	_finish_ai_message()


func _prepare_destruction_camera() -> void:
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	destruction_camera = Camera2D.new()
	destruction_camera.name = "EngineerDestructionCamera"
	destruction_camera.global_position = player.global_position
	destruction_camera.zoom = player_camera.zoom if player_camera != null else Vector2(1.5, 1.5)
	scene.add_child(destruction_camera)
	destruction_camera.enabled = true
	destruction_camera.make_current()
	if player_camera != null:
		player_camera.enabled = false
	var rise := create_tween().set_parallel(true)
	rise.tween_property(destruction_camera, "global_position", Vector2(28, 72), 1.8 * sequence_time_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(destruction_camera, "zoom", Vector2(0.84, 0.84), 1.8 * sequence_time_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _play_destruction_blasts() -> void:
	var positions := _destruction_positions()
	positions.shuffle()
	for index in range(positions.size()):
		if not is_inside_tree():
			return
		_spawn_destruction_blast(positions[index], 100 + index)
		await get_tree().create_timer(randf_range(0.22, 0.48) * sequence_time_scale).timeout
	await get_tree().create_timer(1.2 * sequence_time_scale).timeout


func _destruction_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for point_name in POINT_NAMES:
		var marker := highlights.get_node_or_null(point_name) as Node2D
		if marker != null:
			positions.append(marker.global_position)
	positions.append_array([
		Vector2(-72, 74), Vector2(8, 114), Vector2(96, 66),
		Vector2(178, 126), Vector2(-20, 176), Vector2(205, 32),
		Vector2(-205, -42), Vector2(-214, 78), Vector2(-198, 198),
		Vector2(-104, 214), Vector2(42, 210), Vector2(172, 206),
		Vector2(274, 180), Vector2(280, 74), Vector2(262, -38),
		Vector2(126, -52), Vector2(-46, -54),
	])
	return positions


func _spawn_destruction_blast(world_position: Vector2, fire_stage: int) -> void:
	var blast := AudioStreamPlayer2D.new()
	blast.stream = EXPLOSION
	blast.bus = &"sfx"
	blast.volume_db = randf_range(-6.0, -2.0)
	blast.max_distance = 650.0
	scene.add_child(blast)
	blast.global_position = world_position
	blast.finished.connect(blast.queue_free)
	blast.play()
	var burst := Sprite2D.new()
	burst.texture = BLAST_TEXTURE
	burst.modulate = Color(1.0, randf_range(0.28, 0.52), 0.08, 0.94)
	burst.scale = Vector2(0.12, 0.12)
	burst.z_index = 95
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	burst.material = unshaded
	scene.add_child(burst)
	burst.global_position = world_position
	var burst_tween := create_tween().set_parallel(true)
	burst_tween.tween_property(burst, "scale", Vector2(0.85, 0.85), 0.32 * sequence_time_scale)
	burst_tween.tween_property(burst, "modulate:a", 0.0, 0.32 * sequence_time_scale)
	burst_tween.finished.connect(burst.queue_free)
	_add_fire(world_position, fire_stage)
	if bool(Configs.configs.get("movimento_camera", true)) and is_instance_valid(destruction_camera):
		var base := destruction_camera.offset
		var shake := create_tween()
		shake.tween_property(destruction_camera, "offset", base + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)), 0.04 * sequence_time_scale)
		shake.tween_property(destruction_camera, "offset", base, 0.07 * sequence_time_scale)


func _finish_game(animated: bool) -> void:
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	if is_instance_valid(timer) and timer.has_method("pausar_timer"):
		timer.call("pausar_timer")
	_lock_player()
	var quest := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest != null:
		quest.hide_all_tasks(false)
	final_fade.show()
	final_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	final_fade.color.a = 0.0 if animated else 1.0
	if animated:
		var fade := create_tween()
		fade.tween_property(final_fade, "color:a", 1.0, 10.0 * sequence_time_scale)
		if tension_music.playing:
			var music_fade := create_tween()
			music_fade.tween_property(tension_music, "volume_db", -80.0, 10.0 * sequence_time_scale)
		await fade.finished
		await get_tree().create_timer(5.0 * sequence_time_scale).timeout
	if not is_inside_tree():
		return
	MusicController.stop_all_audio()
	get_tree().paused = false
	get_tree().set_meta(&"programmer_ending_return", true)
	get_tree().change_scene_to_file("res://Scenes/principal.tscn")


func _state() -> Dictionary:
	return SaveGame.office_mission_state(player)


func _save(state: Dictionary) -> void:
	SaveGame.save_global_state("hall_quest_01", state)
	SaveGame.capturar_tempo_atual()
	if is_instance_valid(player) and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)
