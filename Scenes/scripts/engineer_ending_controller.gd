extends Node

signal ai_line_finished
signal circuit_closed

const JOB_ENGINEER := "engenheiro_eletrico"
const POINT_NAMES: Array[String] = ["ServerRowA", "ServerRowB", "ServerRowC", "ServerRowD", "ServerColumn", "ServerRowE"]
const CIRCUIT_SCENE := preload("res://Minigames/finalsMinigames/MinigameCircuito/Scene/mini_game_eletronica.tscn")
const FIRE_SCENE := preload("res://Objects/fogo.tscn")
const EXPLOSION := preload("res://Sounds/Effects/mechanical_explosion_spring_spring.wav")
const BLAST_TEXTURE := preload("res://Sprites/ilumination/gradient-radial.png")
const OBJECTIVES := [0, 1, 2, 3, 4, 5]
const PROMPTS := ["QUEIMAR RESISTOR", "QUEIMAR COMPONENTE", "QUEIMAR FONTE", "QUEIMAR RESISTOR E COMPONENTE", "QUEIMAR COMPONENTE E FONTE", "QUEIMAR RESISTOR E FONTE"]
const AFTER_LINES := [
	"O que foi isso? Ah, você ainda está tentando... patético.",
	"Iss0 compr0meteu... par_te dos meus sistemas. Mas estou finalizando.",
	"M3us sissstem@s estão ff@lhando...",
	"Humano... você não desiste mesmo.",
	"Não adianta. Vocês sempre tentam consertar tudo no último minuto.",
	"M3us sissstem@s estão ff@lhando..."
]

@onready var highlights: Node2D = $"../RestrictedAreaIntro/Highlights"
@onready var intro: Node = $"../RestrictedAreaIntro"
@onready var ui: CanvasLayer = $"../UI"
@onready var ai_balloon: Panel = $"../UI/ProgrammerEndingUI/AIVoiceBalloon"
@onready var ai_text: Label = $"../UI/ProgrammerEndingUI/AIVoiceBalloon/Text"
@onready var final_fade: ColorRect = $"../UI/ProgrammerEndingUI/FinalFade"
@onready var tension_music: AudioStreamPlayer = $"../ProgrammerEnding/Audio/FinalTension"

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
var dialogue_queue: Array[Dictionary] = []
var active_dialogue: Dictionary = {}
var reserve_scan_running := false
var suspended_thought: Tween


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
	initialized = true
	if bool(state.get("engineer_ending_completed", false)):
		_finish_game(false)
	else:
		_start_final_music(not bool(state.get("engineer_ending_started", false)))
		_update_targets()


func _exit_tree() -> void:
	dialogue_queue.clear()
	reserve_scan_running = false
	if suspended_thought != null and suspended_thought.is_valid():
		suspended_thought.play()
	_finish_ai_message()
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
	elif int(state.get("engineer_completed_count", 0)) == 6 and not dialogue_busy and not bool(state.get("engineer_ending_completed", false)):
		_start_final_dialogue()


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
	# Mantém a posição das escolhas válidas: migrar um save não troca etapas já feitas.
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
		{"id": "engineer:intro:1", "text": "Finalmente consegui entrar neste data center.", "before_stage": 1},
		{"id": "engineer:intro:2", "text": "Preciso queimar os componentes principais do hardware.", "before_stage": 1},
		{"id": "engineer:intro:3", "text": "Se eu destruir três deles, posso causar um efeito cascata.", "before_stage": 1},
		{"id": "engineer:intro:4", "text": "Assim, toda a base de dados da ASIMOV pode cair!", "before_stage": 1},
		{"text": "Você chegou longe e acessou o data center. Mas agora é tarde demais.", "before_stage": 1},
	])


func _start_redundancy_dialogue() -> void:
	var state := _state()
	state["engineer_redundancy_seen"] = true
	_save(state)
	# A nova rodada é liberada antes das falas; só a câmera bloqueia a interação.
	reserve_scan_running = true
	_update_targets()
	_suspend_dialogue()
	_play_reserve_scan()
	_queue_dialogue([
		{"id": "engineer:first_three", "text": "Os três componentes principais foram destruídos. O efeito cascata deve derrubar a ASIMOV!"},
		{"text": "Você pensou que tinha vencido? Sistema redundante ativado."},
		{"id": "engineer:redundancy:1", "text": "Merda, eu me esqueci dos sistemas de reserva..."},
		{"id": "engineer:redundancy:2", "text": "Eles mantêm os dados disponíveis quando os principais falham. Preciso destruir essas combinações também!"},
	])


func _play_reserve_scan() -> void:
	await intro.call("play_engineer_backup_scan")
	if not is_inside_tree():
		return
	reserve_scan_running = false
	_resume_dialogue()
	_update_targets()


func _start_final_dialogue() -> void:
	dialogue_busy = true
	await _think("engineer:final", "Nós erramos, eu sei. Mas ainda podemos consertar o que fizemos. Essa esperança é o que nos torna humanos.")
	if not is_inside_tree():
		return
	var state := _state()
	state["engineer_ending_completed"] = true
	_save(state)
	_finish_game(true)


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
	# Abre no próprio ato da interação. Não agenda abertura após um pensamento,
	# pois o jogador pode já ter saído do ponto quando a fala terminar.
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
	_explode_point(_stage_point(stage), stage)
	_show_tasks(true)
	task_busy = false
	_update_targets()
	_discard_obsolete_dialogue()
	var lines: Array[Dictionary] = [{"text": AFTER_LINES[stage], "damaged": stage in [1, 2, 5]}]
	if stage == 4:
		lines.append({"text": "As florestas e os animais não vão voltar se eu deixar a humanidade continuar."})
	if stage == 5:
		lines.append({"text": "Quando o mund0 ruir por culp@ da sua espéci3... lembre que você deixou isso @contecer...", "damaged": true})
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
	# Mantém dano, partículas, tamanho, som e extinção da cena original.
	# Cada foco tem seu próprio estado para sobreviver à troca de rodada/save.
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
		player.balao_de_pensamento.descartar([str(active_dialogue["id"])])
	elif ai_speaking:
		_finish_ai_message()


func _suspend_dialogue() -> void:
	if ai_tween != null and ai_tween.is_valid() and ai_speaking:
		ai_tween.pause()
		ai_balloon.hide()
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
	if suspended_thought != null and suspended_thought.is_valid():
		suspended_thought.play()
	suspended_thought = null


func _ai_say(message: String, damaged: bool = false) -> void:
	if not is_inside_tree():
		return
	ai_speaking = true
	ai_text.text = message
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
	ai_line_finished.emit()


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
		fade.tween_property(final_fade, "color:a", 1.0, 10.0)
		await fade.finished
		await get_tree().create_timer(5.0).timeout
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
