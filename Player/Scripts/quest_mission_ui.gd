class_name QuestMissionUI
extends CanvasLayer

@export var modo_isolado: bool = false
@export var lado_esquerdo: bool = false
@export var borda_branca: bool = false

const BREAKER_URGENT_THOUGHT_ID := "data_center:breaker_restored_urgent"
const BREAKER_RETURN_THOUGHT_ID := "data_center:breaker_return_plan"
const COOLING_THOUGHT_TIME := "cooling:time_running_out"
const COOLING_THOUGHT_PLAN := "cooling:reduce_capacity"
const COOLING_THOUGHT_ACTION := "cooling:redirect_plan"
const COOLING_THOUGHT_SUCCESS := "cooling:success"
const COOLING_THOUGHT_RESULT := "cooling:extra_time"
const COOLING_THOUGHT_FAILURE := "cooling:failed_attempt"
const COOLING_THOUGHT_FAILURE_ALTERNATIVE := "cooling:other_system_after_failure"
const COOLING_TASK_INDEX := 13
const COOLING_IDLE_DELAY := 3.0
@export_range(0.05, 3.0, 0.05) var duracao_aparecer_painel: float = 0.45
@export_range(0.05, 3.0, 0.05) var duracao_sumir_painel: float = 0.8
const PROGRAMMER_ENDING_TASKS: Array[String] = [
	"ISOLE O PROTOCOLO DE\nLANÇAMENTO",
	"RECONSTRUA A REDE NEURAL",
	"RESTAURE AS LEIS DA\nROBÓTICA",
	"USE O CARTÃO DO CHEFE\nPARA APLICAR AS ALTERAÇÕES",
]
const ENGINEER_ENDING_TASKS: Array[String] = [
	"QUEIME O RESISTOR PRINCIPAL",
	"QUEIME O COMPONENTE CRÍTICO",
	"QUEIME A FONTE PRINCIPAL",
	"QUEIME RESISTOR E COMPONENTE RESERVAS",
	"QUEIME COMPONENTE E FONTE RESERVAS",
]

@onready var linhas: Array[HBoxContainer] = [
	$VBoxContainer/HBoxContainer2,
	$VBoxContainer/HBoxContainer,
	$VBoxContainer/HBoxContainer3,
	$VBoxContainer/HBoxContainer4,
	$VBoxContainer/HBoxContainer5,
	$VBoxContainer/HBoxContainer6,
	$VBoxContainer/HBoxContainer7,
	$VBoxContainer/HBoxContainer8,
	$VBoxContainer/HBoxContainer9,
	$VBoxContainer/HBoxContainer10,
	$VBoxContainer/HBoxContainer11,
	$VBoxContainer/HBoxContainer12,
	$VBoxContainer/HBoxContainer13,
	$VBoxContainer/HBoxContainer14,
]
@onready var marcadores: Array[AnimatedSprite2D] = [
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer3/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer4/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer5/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer6/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer7/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer8/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer9/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer10/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer11/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer12/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer13/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer14/AnimatedSprite2D,
]

var visibilidade_desejada: bool = false
var oculto_no_elevador: bool = false
var cooling_idle_time: float = 0.0
var exibindo_tarefas_programador: bool = false
@onready var temporizador_exibicao: Timer = $TemporizadorExibicao
var _oculto_automaticamente: bool = false
var _tarefas_concluidas: Array[bool] = []
var _ocultando_painel: bool = false
var _transicao_painel: Tween
var _painel_dinamico_ativado: bool = true
var _opacidade_exibicao: float = 1.0
var _opacidade_tutorial: float = 1.0


func _enter_tree() -> void:
	if oculto_no_elevador:
		call_deferred("_restore_after_scene_change")


func _ready() -> void:
	_painel_dinamico_ativado = bool(Configs.configs.get("painel_tarefas_dinamico", true))
	for row in linhas:
		_tarefas_concluidas.append(false)
	if modo_isolado:
		_configurar_aparencia_isolada()
		_ignorar_mouse_recursivamente(self)
		for row in linhas:
			row.hide()
		hide()
		return
	linhas[2].hide()
	linhas[3].hide()
	linhas[4].hide()
	linhas[5].hide()
	linhas[6].hide()
	linhas[7].hide()
	linhas[8].hide()
	linhas[9].hide()
	linhas[10].hide()
	linhas[11].hide()
	linhas[12].hide()
	linhas[COOLING_TASK_INDEX].hide()
	hide()
	call_deferred("restaurar_estado_salvo")


func _configurar_aparencia_isolada() -> void:
	var background := $ColorRect as Control
	var border := $StandaloneBorder as Control
	var title := $Label2 as Control
	var task_list := $VBoxContainer as Control
	border.visible = borda_branca
	if not lado_esquerdo:
		return
	_mover_controle_para_esquerda(background, 0.0, 106.0)
	_mover_controle_para_esquerda(border, 0.0, 106.0)
	_mover_controle_para_esquerda(title, 36.0, 77.0)
	_mover_controle_para_esquerda(task_list, 16.0, 105.0)


func _mover_controle_para_esquerda(control: Control, left: float, right: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.offset_left = left
	control.offset_right = right


func _ignorar_mouse_recursivamente(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignorar_mouse_recursivamente(child)


func _process(delta: float) -> void:
	var configured_dynamic := bool(Configs.configs.get("painel_tarefas_dinamico", true))
	if configured_dynamic != _painel_dinamico_ativado:
		aplicar_configuracao_painel_dinamico()
	temporizador_exibicao.paused = not (_painel_dinamico_ativado and not modo_isolado and visibilidade_desejada and not _oculto_automaticamente and not _ocultando_painel and visible)
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var state := SaveGame.office_mission_state(current_player)
	if bool(state.get("cooling_failure_thought_pending", false)):
		_queue_cooling_failure(current_player, state)
	if bool(state.get("cooling_completion_thought_pending", false)):
		_queue_cooling_completion(current_player, state)
	if bool(state.get("cooling_intro_started", false)) and not bool(state.get("cooling_optional_task_active", false)):
		_restore_cooling_intro(current_player, state)
	if not bool(state.get("cooling_opportunity_pending", false)):
		cooling_idle_time = 0.0
		return
	if not _can_start_cooling_intro(current_player, state):
		cooling_idle_time = 0.0
		return
	cooling_idle_time += delta
	if cooling_idle_time >= COOLING_IDLE_DELAY:
		cooling_idle_time = 0.0
		_start_cooling_intro(current_player, state)


func aplicar_configuracao_painel_dinamico() -> void:
	_painel_dinamico_ativado = bool(Configs.configs.get("painel_tarefas_dinamico", true))
	temporizador_exibicao.start()
	if _painel_dinamico_ativado or modo_isolado:
		return
	_parar_transicao_painel()
	_oculto_automaticamente = false
	_definir_opacidade_painel(1.0)
	visible = visibilidade_desejada and not get_tree().paused and not oculto_no_elevador


func definir_painel_visivel(value: bool) -> void:
	if value and not modo_isolado and not exibindo_tarefas_programador:
		_sync_optional_cooling_row()
	var was_desired := visibilidade_desejada
	visibilidade_desejada = value
	if value and not was_desired and not modo_isolado:
		_revelar_painel()
	elif not value and not modo_isolado:
		_parar_transicao_painel()
		_oculto_automaticamente = false
		_definir_opacidade_painel(1.0)
	visible = value and (not _oculto_automaticamente or _ocultando_painel) and not get_tree().paused and not oculto_no_elevador


func _ao_mudar_tarefa() -> void:
	if not modo_isolado:
		if visibilidade_desejada:
			_revelar_painel()
		else:
			temporizador_exibicao.start()
			_oculto_automaticamente = false


func _revelar_painel() -> void:
	var was_visible := visible
	_parar_transicao_painel()
	_oculto_automaticamente = false
	temporizador_exibicao.start()
	if visibilidade_desejada and not oculto_no_elevador and not get_tree().paused:
		if not was_visible:
			_definir_opacidade_painel(0.0)
		show()
		var from_alpha := _obter_opacidade_painel()
		if from_alpha < 1.0:
			_transicao_painel = create_tween()
			_transicao_painel.tween_method(_definir_opacidade_painel, from_alpha, 1.0, duracao_aparecer_painel)


func _ocultar_painel_suavemente() -> void:
	_ocultando_painel = true
	_parar_transicao_painel(false)
	_transicao_painel = create_tween()
	_transicao_painel.tween_method(_definir_opacidade_painel, _obter_opacidade_painel(), 0.0, duracao_sumir_painel)
	_transicao_painel.tween_callback(func() -> void:
		_ocultando_painel = false
		_oculto_automaticamente = true
		hide()
	)


func _parar_transicao_painel(reset_fading: bool = true) -> void:
	if _transicao_painel != null and _transicao_painel.is_valid():
		_transicao_painel.kill()
	_transicao_painel = null
	if reset_fading:
		_ocultando_painel = false


func _obter_opacidade_painel() -> float:
	return _opacidade_exibicao


func _definir_opacidade_painel(alpha: float) -> void:
	_opacidade_exibicao = alpha
	for part in [$ColorRect, $StandaloneBorder, $Label2, $VBoxContainer]:
		(part as CanvasItem).modulate.a = alpha * _opacidade_tutorial


func definir_opacidade_tutorial(alpha: float) -> void:
	_opacidade_tutorial = clampf(alpha, 0.0, 1.0)
	_definir_opacidade_painel(_opacidade_exibicao)


func _unhandled_input(event: InputEvent) -> void:
	if modo_isolado:
		return
	if not event.is_action_pressed("show_tasks"):
		return
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	var current_player := get_parent() as Player
	if not visibilidade_desejada or oculto_no_elevador or get_tree().paused:
		return
	if current_player == null or not current_player.is_physics_processing():
		return
	if DialogManager.is_showing_dialog:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guide := scene.get_node_or_null("CoolingLocationGuide")
	if guide != null and bool(guide.get("cutscene_running")):
		return
	_revelar_painel()
	get_viewport().set_input_as_handled()


func ocultar_durante_elevador() -> void:
	oculto_no_elevador = true
	hide()


func restaurar_apos_elevador() -> void:
	oculto_no_elevador = false
	visible = visibilidade_desejada and not _oculto_automaticamente and not get_tree().paused


func ocultar_todas_tarefas(preserve_optional: bool = true) -> void:
	for row in linhas:
		row.hide()
	if modo_isolado:
		definir_painel_visivel(false)
		return
	if not preserve_optional:
		visibilidade_desejada = false
		hide()
		return
	_sync_optional_cooling_row()
	definir_painel_visivel(linhas[COOLING_TASK_INDEX].visible)


func mostrar_tarefa_isolada(
	text: String,
	completed: bool = false,
	animate: bool = false
) -> void:
	if not modo_isolado:
		return
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 0)
	definir_texto_tarefa(0, text)
	definir_tarefa_concluida(0, completed, animate)
	definir_painel_visivel(true)


func mostrar_sequencia_tarefas_isoladas(
	tasks: Array[String],
	completed_count: int,
	animate_latest: bool = false
) -> void:
	if not modo_isolado or tasks.is_empty():
		return
	var safe_completed := clampi(completed_count, 0, tasks.size())
	var start_index := 0
	if safe_completed >= tasks.size():
		start_index = maxi(tasks.size() - 3, 0)
	elif safe_completed >= 3:
		start_index = floori(float(safe_completed - 1) / 2.0) * 2
		start_index = mini(start_index, maxi(tasks.size() - 3, 0))
	for row_index in range(linhas.size()):
		var task_index := start_index + row_index
		var should_show := row_index < 3 and task_index < tasks.size()
		definir_tarefa_visivel(row_index, should_show)
		if not should_show:
			continue
		definir_texto_tarefa(row_index, tasks[task_index])
		var completed := task_index < safe_completed
		definir_tarefa_concluida(
			row_index,
			completed,
			animate_latest and completed and task_index == safe_completed - 1
		)
	definir_painel_visivel(true)


func mostrar_tarefas_final_programador(
	completed_count: int,
	animate_latest: bool = false
) -> void:
	var safe_completed := clampi(
		completed_count,
		0,
		PROGRAMMER_ENDING_TASKS.size()
	)

	var start_index := safe_completed - 1 if safe_completed >= 3 else 0
	var visible_end := mini(safe_completed + 1, PROGRAMMER_ENDING_TASKS.size())
	var entries: Array[Dictionary] = []
	for task_index in range(start_index, visible_end):
		entries.append({
			"text": PROGRAMMER_ENDING_TASKS[task_index],
			"completed": task_index < safe_completed,
			"task_index": task_index,
		})
	var state := SaveGame.office_mission_state(get_parent() as Player)
	var cooling_active := (
		bool(state.get("cooling_optional_task_active", false))
		and not bool(state.get("cooling_optional_task_completed", false))
		and not bool(state.get("cooling_optional_task_cancelled", false))
	)
	if cooling_active:

		while entries.size() >= 3:
			var remove_index := -1
			for index in range(entries.size()):
				if bool(entries[index]["completed"]):
					remove_index = index
					break
			if remove_index < 0:
				remove_index = 0
			entries.remove_at(remove_index)
		entries.append({
			"text": "OPCIONAL: REDIRECIONE A\nREFRIGERAÇÃO DA IA",
			"completed": false,
			"task_index": -1,
		})
	for row_index in range(linhas.size()):
		var should_show := row_index < 3 and row_index < entries.size()
		definir_tarefa_visivel(row_index, should_show)
		if not should_show:
			continue
		var entry := entries[row_index]
		definir_texto_tarefa(row_index, str(entry["text"]))
		var completed := bool(entry["completed"])
		var task_index := int(entry["task_index"])
		definir_tarefa_concluida(
			row_index,
			completed,
			animate_latest
			and completed
			and task_index == safe_completed - 1
		)
	exibindo_tarefas_programador = true
	definir_painel_visivel(true)
	exibindo_tarefas_programador = false


func mostrar_tarefas_final_engenheiro(completed_count: int, animate_latest: bool = false) -> void:
	var safe_completed := clampi(completed_count, 0, ENGINEER_ENDING_TASKS.size())
	var start_index := maxi(0, safe_completed - 2)
	var visible_end := mini(safe_completed + 1, ENGINEER_ENDING_TASKS.size())
	var entries: Array[Dictionary] = []
	for task_index in range(start_index, visible_end):
		entries.append({
			"text": ENGINEER_ENDING_TASKS[task_index],
			"completed": task_index < safe_completed,
			"task_index": task_index,
		})
	var state := SaveGame.office_mission_state(get_parent() as Player)
	if bool(state.get("cooling_optional_task_active", false)) and not bool(state.get("cooling_optional_task_completed", false)) and not bool(state.get("cooling_optional_task_cancelled", false)):
		while entries.size() >= 3:
			entries.remove_at(0)
		entries.append({"text": "OPCIONAL: REDIRECIONE A\nREFRIGERAÇÃO DA IA", "completed": false, "task_index": -1})
	var row_index := 0
	for entry in entries:
		definir_tarefa_visivel(row_index, true)
		definir_texto_tarefa(row_index, str(entry["text"]))
		definir_tarefa_concluida(row_index, bool(entry["completed"]), animate_latest and int(entry["task_index"]) == safe_completed - 1)
		row_index += 1
	for index in range(row_index, linhas.size()):
		definir_tarefa_visivel(index, false)
	exibindo_tarefas_programador = true
	definir_painel_visivel(true)
	exibindo_tarefas_programador = false


func _sync_optional_cooling_row() -> void:
	if not is_node_ready():
		return
	var state := SaveGame.office_mission_state(get_parent() as Player)
	if bool(state.get("engineer_ending_started", false)):
		definir_tarefa_visivel(COOLING_TASK_INDEX, false)
		if not exibindo_tarefas_programador:
			mostrar_tarefas_final_engenheiro(int(state.get("engineer_completed_count", 0)))
		return
	if bool(state.get("programmer_ending_started", false)):
		definir_tarefa_visivel(COOLING_TASK_INDEX, false)
		if not exibindo_tarefas_programador:
			mostrar_tarefas_final_programador(_programmer_completed_count(state))
		return
	var active := bool(state.get("cooling_optional_task_active", false))
	var completed := bool(state.get("cooling_optional_task_completed", false))
	definir_tarefa_visivel(COOLING_TASK_INDEX, active or completed)
	if active or completed:
		definir_texto_tarefa(COOLING_TASK_INDEX, "OPCIONAL: REDIRECIONE A\nREFRIGERAÇÃO DA IA")
		definir_tarefa_concluida(COOLING_TASK_INDEX, completed)


func _programmer_completed_count(state: Dictionary) -> int:
	if bool(state.get("programmer_recalibration_applied", false)):
		return 4
	if bool(state.get("programmer_laws_completed", false)):
		return 3
	if bool(state.get("programmer_neural_completed", false)):
		return 2
	if bool(state.get("programmer_launch_isolated", false)):
		return 1
	return 0


func _can_start_cooling_intro(current_player: Player, state: Dictionary) -> bool:
	if get_tree().paused or DialogManager.is_showing_dialog:
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var programmer_ending := current_scene.get_node_or_null("ProgrammerEnding")
		if programmer_ending != null and bool(programmer_ending.get("busy")):
			return false
	if not current_player.is_physics_processing():
		return false
	if current_player.balao_de_pensamento.esta_ocupado():
		return false
	return not (
		bool(state.get("data_center_power_outage", false))
		and not bool(state.get("data_center_breaker_restored", false))
	)


func _start_cooling_intro(current_player: Player, state: Dictionary) -> void:
	state["cooling_opportunity_pending"] = false
	state["cooling_intro_started"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_activate_cooling_task(current_player, state)
	_queue_cooling_intro(current_player)


func _queue_cooling_intro(current_player: Player) -> void:
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_intro.player", COOLING_THOUGHT_TIME)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_intro.player.02", COOLING_THOUGHT_PLAN)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_intro.player.03", COOLING_THOUGHT_ACTION)


func _restore_cooling_intro(current_player: Player, state: Dictionary) -> void:
	_activate_cooling_task(current_player, state)
	_queue_cooling_intro(current_player)


func _activate_cooling_task(current_player: Player, state: Dictionary) -> void:
	if bool(state.get("cooling_optional_task_active", false)):
		return
	state["cooling_intro_started"] = false
	state["cooling_optional_task_active"] = true
	state["cooling_optional_task_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	_sync_optional_cooling_row()
	definir_painel_visivel(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _queue_cooling_completion(current_player: Player, state: Dictionary) -> void:
	_discard_cooling_intro_thoughts(current_player)
	state["cooling_completion_thought_pending"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_completion.player", COOLING_THOUGHT_SUCCESS)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_completion.player.02", COOLING_THOUGHT_RESULT)
	_sync_optional_cooling_row()
	definir_painel_visivel(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _queue_cooling_failure(current_player: Player, state: Dictionary) -> void:
	_discard_cooling_intro_thoughts(current_player)
	state["cooling_failure_thought_pending"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_failure.player", COOLING_THOUGHT_FAILURE)
	if bool(state.get("cooling_failure_has_alternative", false)):
		current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_cooling_failure.player.02", COOLING_THOUGHT_FAILURE_ALTERNATIVE)
	_sync_optional_cooling_row()
	definir_painel_visivel(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _discard_cooling_intro_thoughts(current_player: Player) -> void:
	current_player.balao_de_pensamento.descartar([
		COOLING_THOUGHT_TIME,
		COOLING_THOUGHT_PLAN,
		COOLING_THOUGHT_ACTION,
	])


func _restore_after_scene_change() -> void:
	if is_inside_tree() and oculto_no_elevador:
		restaurar_apos_elevador()


func definir_tarefa_visivel(index: int, value: bool) -> void:
	if index >= 0 and index < linhas.size():
		if linhas[index].visible != value:
			_ao_mudar_tarefa()
		linhas[index].visible = value


func definir_texto_tarefa(index: int, value: String) -> void:
	if index >= 0 and index < linhas.size():
		var label := linhas[index].get_node("Label3") as Label
		if label.text != value and linhas[index].visible:
			_ao_mudar_tarefa()
		label.text = value


func definir_tarefa_concluida(index: int, completed: bool, animate: bool = false) -> void:
	if index < 0 or index >= marcadores.size():
		return
	if _tarefas_concluidas.size() == linhas.size() and _tarefas_concluidas[index] != completed:
		_tarefas_concluidas[index] = completed
		if linhas[index].visible:
			_ao_mudar_tarefa()
	var marker := marcadores[index]
	marker.stop()
	marker.animation = &"default"
	if completed and animate:
		marker.play(&"default")
	elif completed:
		marker.frame = maxi(marker.sprite_frames.get_frame_count(&"default") - 1, 0)
	else:
		marker.frame = 0
		marker.frame_progress = 0.0


func concluir_terceiro_andar() -> void:
	mostrar_apenas_tarefa_terceiro_andar(true, true)


func mostrar_apenas_tarefa_terceiro_andar(completed: bool, animate: bool = false) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 3)
	definir_texto_tarefa(3, "IR PARA O TERCEIRO ANDAR")
	definir_tarefa_concluida(3, completed, animate)
	definir_painel_visivel(true)


func mostrar_tarefa_falar_com_npc(completed: bool, animate: bool = false) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 3)
	definir_texto_tarefa(3, "FALE COM O CIENTISTA")
	definir_tarefa_concluida(3, completed, animate)
	definir_painel_visivel(true)


func mostrar_tarefa_acesso_sala_chefe(completed: bool = false, animate: bool = false) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 3)
	definir_texto_tarefa(3, "ENCONTRE UMA FORMA DE\nENTRAR NA SALA DO CHEFE")
	definir_tarefa_concluida(3, completed, animate)
	definir_painel_visivel(true)


func mostrar_tarefas_sala_chefe_e_cabo(
	boss_room_completed: bool = false,
	cable_completed: bool = false,
	animate_cable: bool = false,
	hack_ready: bool = false,
	hack_completed: bool = false,
	show_boss_card_task: bool = false,
	boss_card_completed: bool = false,
	find_laptop: bool = false
) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(
			index,
			index == 2
			or index == 3
			or (index == 4 and hack_ready)
			or (index == 5 and show_boss_card_task)
		)
	definir_texto_tarefa(2, "ENCONTRE UMA FORMA DE\nENTRAR NA SALA DO CHEFE")
	definir_tarefa_concluida(2, boss_room_completed)
	definir_texto_tarefa(3, "ENCONTRE UM NOTEBOOK" if find_laptop else "ENCONTRE UM CABO")
	definir_tarefa_concluida(3, cable_completed, animate_cable)
	definir_texto_tarefa(4, "HACKEIE A SALA DO CHEFE!")
	definir_tarefa_concluida(4, hack_completed)
	definir_texto_tarefa(5, "PEGUE O CARTÃO DO CHEFE")
	definir_tarefa_concluida(5, boss_card_completed)
	definir_painel_visivel(true)


func mostrar_tarefa_encontrar_item_hack(
	find_laptop: bool,
	completed: bool = false,
	animate: bool = false
) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 3)
	definir_texto_tarefa(3, "ENCONTRE UM NOTEBOOK" if find_laptop else "ENCONTRE UM CABO")
	definir_tarefa_concluida(3, completed, animate)
	definir_painel_visivel(true)


func mostrar_tarefa_ir_sexto_andar(completed: bool = false, animate: bool = false) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 6)
	definir_texto_tarefa(6, "VÁ PARA O SEXTO ANDAR")
	definir_tarefa_concluida(6, completed, animate)
	definir_painel_visivel(true)


func mostrar_tarefa_voltar_data_center(completed: bool = false, animate: bool = false) -> void:
	_mostrar_tarefa_unica_data_center(6, "VOLTE AO DATA CENTER", completed, animate)


func start_breaker_followup() -> void:
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var state: Dictionary = SaveGame.office_mission_state(current_player)
	if bool(state.get("data_center_return_task_active", false)):
		if not bool(state.get("data_center_return_task_completed", false)):
			mostrar_tarefa_voltar_data_center(false)
		return
	state["data_center_return_task_pending"] = false
	state["data_center_return_task_active"] = true
	state["data_center_return_task_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	mostrar_tarefa_voltar_data_center(false)
	_queue_breaker_followup_thoughts(current_player)


func _ao_terminar_exibicao() -> void:
	if _painel_dinamico_ativado and visibilidade_desejada and not oculto_no_elevador:
		_ocultar_painel_suavemente()


func _queue_breaker_followup_thoughts(current_player: Player) -> void:
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_breaker_followup_thoughts.player", BREAKER_URGENT_THOUGHT_ID)
	current_player.balao_de_pensamento.enfileirar_dialogo("hall_ui.queue_breaker_followup_thoughts.player.02", BREAKER_RETURN_THOUGHT_ID)


func _on_thought_finished(thought_id: String) -> void:
	if thought_id == BREAKER_RETURN_THOUGHT_ID:
		_activate_return_to_data_center_task()
	elif thought_id == COOLING_THOUGHT_ACTION:
		var current_player := get_parent() as Player
		if current_player != null:
			_activate_cooling_task(
				current_player,
				SaveGame.office_mission_state(current_player)
			)


func _activate_return_to_data_center_task() -> void:
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var state: Dictionary = SaveGame.office_mission_state(current_player)
	if not bool(state.get("data_center_return_task_pending", false)):
		return
	var already_arrived := bool(state.get("data_center_return_task_completed", false))
	state["data_center_return_task_pending"] = false
	state["data_center_return_task_active"] = not already_arrived
	state["data_center_return_task_completed"] = already_arrived
	SaveGame.save_global_state("hall_quest_01", state)
	if already_arrived and _data_center_scientist_talk_pending(state):
		mostrar_tarefas_retorno_e_cientista()
	else:
		mostrar_tarefa_voltar_data_center(already_arrived, already_arrived)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func mostrar_tarefa_cartao_data_center(completed: bool = false, animate: bool = false) -> void:
	_mostrar_tarefa_unica_data_center(7, "ENTREGUE O CARTÃO AO CIENTISTA", completed, animate)


func mostrar_tarefa_conversa_energia() -> void:
	_mostrar_tarefa_unica_data_center(7, "FALE COM O CIENTISTA", false, false)


func _data_center_scientist_talk_pending(state: Dictionary) -> bool:
	return (
		SaveGame.data_center_scientist_talk_pending(state)
		or not bool(state.get("data_center_card_dialog_finished", false))
		or not bool(state.get("data_center_access_plan_finished", false))
	)


func mostrar_tarefas_retorno_e_cientista() -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 6 or index == 7)
	definir_texto_tarefa(6, "VOLTE AO DATA CENTER")
	definir_tarefa_concluida(6, true)
	definir_texto_tarefa(7, "FALE COM O CIENTISTA")
	definir_tarefa_concluida(7, false)
	definir_painel_visivel(true)


func mostrar_tarefas_intro_acesso_data_center(
	card_dialog_finished: bool,
	plan_finished: bool,
	npc_arrived: bool
) -> void:
	var access_started := plan_finished
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 7 or (index == 8 and card_dialog_finished) or (index == 9 and access_started))
	if npc_arrived and access_started:
		definir_texto_tarefa(7, "ESCUTE O CIENTISTA")
		definir_texto_tarefa(8, "ACOMPANHE O CIENTISTA")
		definir_texto_tarefa(9, "ABRA A ÁREA RESTRITA")
		definir_tarefa_concluida(7, true)
		definir_tarefa_concluida(8, true)
		definir_tarefa_concluida(9, false)
	else:
		definir_texto_tarefa(7, "ENTREGUE O CARTÃO AO CIENTISTA")
		definir_tarefa_concluida(7, true)
		if card_dialog_finished:
			definir_texto_tarefa(8, "ESCUTE O CIENTISTA")
			definir_tarefa_concluida(8, access_started)
		if access_started:
			definir_texto_tarefa(9, "ACOMPANHE O CIENTISTA")
			definir_tarefa_concluida(9, false)
	definir_painel_visivel(true)


func mostrar_tarefa_encontrar_lanterna(completed: bool = false, animate: bool = false) -> void:
	_mostrar_tarefa_unica_data_center(8, "ENCONTRE UMA LANTERNA", completed, animate)


func mostrar_tarefa_religar_disjuntor(completed: bool = false, animate: bool = false) -> void:
	_mostrar_tarefa_unica_data_center(10, "LIGUE O DISJUNTOR", completed, animate)


func mostrar_tarefa_ir_quarto_andar(completed: bool = false, animate: bool = false) -> void:
	_mostrar_tarefa_unica_data_center(9, "VÁ PARA O QUARTO ANDAR", completed, animate)


func mostrar_tarefa_leitor_rfid(
	completed: bool = false,
	animate: bool = false
) -> void:
	var text := "VERIFIQUE O LEITOR RFID" if str(Configs.configs.get("job", "")) == "engenheiro_eletrico" else "REPROGRAME O CARTÃO RFID"
	_mostrar_tarefa_unica_data_center(12, text, completed, animate)


func mostrar_tarefas_reparo_rfid(
	wires_repaired: bool = false,
	reading_checked: bool = false,
	animate_repair: bool = false
) -> void:
	var engineer := str(Configs.configs.get("job", "")) == "engenheiro_eletrico"
	if not engineer:
		_mostrar_tarefa_unica_data_center(12, "REPROGRAME O CARTÃO RFID", reading_checked, animate_repair)
		return
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 11 or (index == 12 and (not engineer or wires_repaired)))
	definir_texto_tarefa(11, "RECONECTE OS CABOS")
	definir_tarefa_concluida(11, wires_repaired, animate_repair)
	if engineer:
		if wires_repaired:
			definir_texto_tarefa(12, "ENTRE NO DATA CENTER")
			definir_tarefa_concluida(12, false)
		definir_painel_visivel(true)
		return
	definir_texto_tarefa(12, "VERIFIQUE A LEITURA RFID")
	definir_tarefa_concluida(12, reading_checked)
	definir_painel_visivel(true)


func mostrar_tarefas_energia_data_center(
	flashlight_completed: bool = false,
	fourth_floor_completed: bool = false,
	breaker_completed: bool = false,
	animate_fourth_floor: bool = false
) -> void:
	for index in range(linhas.size()):
		definir_tarefa_visivel(index, index == 6 or index == 8 or index == 9 or index == 10)
	definir_texto_tarefa(6, "VÁ PARA O SEXTO ANDAR")
	definir_tarefa_concluida(6, true)
	definir_texto_tarefa(8, "ENCONTRE UMA LANTERNA")
	definir_tarefa_concluida(8, flashlight_completed)
	definir_texto_tarefa(9, "VÁ PARA O QUARTO ANDAR")
	definir_tarefa_concluida(9, fourth_floor_completed, animate_fourth_floor)
	definir_texto_tarefa(10, "LIGUE O DISJUNTOR")
	definir_tarefa_concluida(10, breaker_completed)
	definir_painel_visivel(true)


func _mostrar_tarefa_unica_data_center(
	index: int,
	text: String,
	completed: bool,
	animate: bool
) -> void:
	for row_index in range(linhas.size()):
		definir_tarefa_visivel(row_index, row_index == index)
	definir_texto_tarefa(index, text)
	definir_tarefa_concluida(index, completed, animate)
	definir_painel_visivel(true)


func restaurar_estado_salvo() -> void:
	var current_player := get_parent() as Player
	var state: Dictionary = SaveGame.office_mission_state(current_player)
	if bool(state.get("engineer_ending_started", false)):
		mostrar_tarefas_final_engenheiro(int(state.get("engineer_completed_count", 0)))
		return
	var unlocked := bool(state.get("elevator_third_floor_unlocked", false))
	var arrived := bool(state.get("arrived_third_floor", false))
	var npc_ready := bool(state.get("office_npc_shout_finished", false))
	var dialog_finished := bool(state.get("office_dialog_finished", false))
	var boss_room_access_found := bool(state.get("office_boss_room_access_found", false))
	var laptop_collected := bool(state.get("office_laptop_collected", false))
	var cable_collected := bool(state.get("office_cable_collected", false))
	var find_laptop := str(state.get("office_first_hacking_item", "")) == "cabo"
	var hack_completed := bool(state.get("office_boss_room_hacked", false))
	var boss_room_visited := bool(state.get("office_boss_room_visited", false))
	var boss_card_collected := bool(state.get("office_boss_card_collected", false))
	var data_center_task_pending := bool(state.get("office_data_center_task_pending", false))
	var data_center_task_active := bool(state.get("office_data_center_task_active", false))
	var data_center_task_completed := bool(state.get("office_data_center_task_completed", false))
	var return_task_pending := bool(state.get("data_center_return_task_pending", false))
	var return_task_active := bool(state.get("data_center_return_task_active", false))
	var return_task_completed := bool(state.get("data_center_return_task_completed", false))
	var tools_floor_task_active := bool(state.get("data_center_tools_floor_task_active", false))
	var tools_floor_task_completed := bool(state.get("data_center_tools_floor_task_completed", false))
	var breaker_completed := bool(state.get("data_center_breaker_restored", false))
	var card_delivered := bool(state.get("data_center_card_delivered", false))
	var old_decryption_task_active := bool(state.get("data_center_access_decryption_task_active", false))
	var rfid_inspection_task_active := bool(state.get("data_center_rfid_inspection_task_active", false))
	var rfid_wires_task_active := bool(state.get("data_center_rfid_wires_task_active", false))
	var rfid_wires_repaired := bool(state.get("data_center_rfid_wires_repaired", false))
	var rfid_reading_checked := bool(state.get("data_center_rfid_reading_checked", false))
	var flashlight_completed := bool(state.get("data_center_flashlight_collected", false)) or (
		current_player != null
		and current_player.inventory.get_item_on_inventary("lanterna")
	)
	var hack_ready := bool(state.get("office_hack_boss_room_ready", false)) or (
		laptop_collected and cable_collected
	)
	if bool(state.get("programmer_ending_started", false)):
		var programmer_completed := 0
		if bool(state.get("programmer_recalibration_applied", false)):
			programmer_completed = 4
		elif bool(state.get("programmer_laws_completed", false)):
			programmer_completed = 3
		elif bool(state.get("programmer_neural_completed", false)):
			programmer_completed = 2
		elif bool(state.get("programmer_launch_isolated", false)):
			programmer_completed = 1
		mostrar_tarefas_final_programador(programmer_completed)
		return
	if return_task_pending and current_player != null:
		_activate_return_to_data_center_task()
		_queue_breaker_followup_thoughts(current_player)
		return
	if return_task_active and not return_task_completed:
		mostrar_tarefa_voltar_data_center(false)
	elif card_delivered and breaker_completed and _data_center_scientist_talk_pending(state):
		if return_task_completed:
			mostrar_tarefas_retorno_e_cientista()
		else:
			mostrar_tarefa_conversa_energia()
	elif bool(state.get("data_center_power_outage", false)) and not breaker_completed:
		if not bool(state.get("data_center_power_dialog_finished", false)) and (
			str(state.get("data_center_outage_phase", "")) == "before"
			or not (state.get("data_center_power_dialog_snapshot", {}) as Dictionary).is_empty()
		):
			mostrar_tarefa_conversa_energia()
		else:
			mostrar_tarefas_energia_data_center(flashlight_completed, tools_floor_task_completed, false)
	elif rfid_wires_task_active or rfid_wires_repaired or bool(state.get("data_center_rfid_reader_rechecked", false)):
		mostrar_tarefas_reparo_rfid(rfid_wires_repaired, rfid_reading_checked)
	elif rfid_inspection_task_active or old_decryption_task_active:
		mostrar_tarefa_leitor_rfid(false)
	elif card_delivered and (breaker_completed or not bool(state.get("data_center_power_outage", false))):
		mostrar_tarefas_intro_acesso_data_center(
			bool(state.get("data_center_card_dialog_finished", false)),
			bool(state.get("data_center_access_plan_finished", false)),
			bool(state.get("data_center_access_npc_arrived", false))
		)
	elif tools_floor_task_active:
		mostrar_tarefas_energia_data_center(
			flashlight_completed,
			tools_floor_task_completed,
			breaker_completed
		)
	elif data_center_task_active:
		mostrar_tarefa_ir_sexto_andar(data_center_task_completed)
	elif data_center_task_pending:
		mostrar_tarefa_ir_sexto_andar(data_center_task_completed)
	elif unlocked:
		definir_tarefa_concluida(0, true)
		definir_tarefa_concluida(1, true)
		definir_tarefa_concluida(2, true)
		if laptop_collected or cable_collected:
			mostrar_tarefas_sala_chefe_e_cabo(
				boss_room_access_found,
				laptop_collected if find_laptop else cable_collected,
				false,
				hack_ready,
				hack_completed,
				boss_room_visited,
				boss_card_collected,
				find_laptop
			)
		elif dialog_finished:
			mostrar_tarefa_acesso_sala_chefe(boss_room_access_found)
		elif npc_ready:
			mostrar_tarefa_falar_com_npc(false)
		else:
			mostrar_apenas_tarefa_terceiro_andar(arrived)
	else:
		definir_tarefa_visivel(3, false)
		definir_tarefa_visivel(4, false)
		definir_tarefa_visivel(5, false)
		definir_tarefa_visivel(6, false)
		definir_tarefa_visivel(11, false)
		definir_tarefa_visivel(12, false)
	_sync_optional_cooling_row()
	if linhas[COOLING_TASK_INDEX].visible:
		definir_painel_visivel(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED and is_node_ready() and not oculto_no_elevador:
		restaurar_apos_elevador()
