extends Node

@export var save_id: String = "hall_quest_01"

const EXTINGUISHER_SCRIPT := preload("res://Objects/scripts/extintor.gd")
const OBJECTIVE_HIGHLIGHT := preload("res://Scenes/scripts/hall_objective_highlight.gd")

var man_player: Player
var quest_ui: QuestMissionUI
var _inicializado: bool = false
signal orientacao_elevador_iniciada
signal pensamento_extintor_iniciado
var orientar_elevador: bool = false
var orientar_extintor: bool = false

var f1_acesso: bool = true
var f2_acesso: bool = true
var f3_acesso: bool = true

var M1_feito: bool = false
var M2_feito: bool = false

var _hide_scheduled: bool = false
var _todos_sairam: bool = false
var _pos_saida_iniciada: bool = false
var _dica_mostrada: bool = false
var _saida_pendente: int = 0
var _evacuacao_ativa: bool = false
var _elevador_terceiro_liberado: bool = false
var _chegou_terceiro_andar: bool = false
var _extinguisher_check_elapsed := 0.0
var _extinguisher_failure_started := false
var _route_check_elapsed := 0.0
var _exit_paths_pending := false
var _exit_paths_legacy_restore := false

func _ready() -> void:

	call_deferred("_inicializar")


func _inicializar() -> void:
	man_player = get_parent().player as Player
	if not is_instance_valid(man_player):
		return
	quest_ui = man_player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if not is_instance_valid(quest_ui):
		push_error("Player sem o painel QUEST_MISSION.")
		return
	_restore_progress()
	_apply_saved_visuals()
	_atualizar_linhas_tarefas()
	_inicializado = true
	for fire in get_parent().get_node("Perigos").get_children():
		if fire.has_signal("extincao_iniciada") and fire.name not in [&"Fogo3", &"Fogo5", &"Fogo6"]:
			fire.extincao_iniciada.connect(_on_non_objective_fire_extinction)
	man_player.balao_de_pensamento.pensamento_finalizado.connect(_on_pensamento_finalizado)
	man_player.balao_de_pensamento.pensamento_iniciado.connect(_on_pensamento_iniciado)

	MusicController._iniciar_musica_abertura()
	MusicController._parar_ambiente_fundo()
	MusicController._definir_volume_musica_abertura(1.0)
	_descartar_instrucoes_obsoletas()

	_on_pensamento_iniciado(man_player.balao_de_pensamento.pensamento_atual_id())
	_highlight_hall_objectives()
	man_player.balao_de_pensamento.atualizar_texto(
		_pensamento_id("pos_saida_2"),
		DialogueCatalog.text("hall.inicializar.player")
	)
	if _elevador_terceiro_liberado:
		_atualizar_tarefa_terceiro()

	if _hide_scheduled:
		_iniciar_espera_npcs()
		_start_npc_exit_paths(true)
		_atualizar_visibilidade()
		return

	_pensar("intro_1", "hall.intro.1")
	_pensar("intro_2", "hall.intro.2")
	_pensar("intro_4", "hall.intro.extinguisher")
	_atualizar_visibilidade()
	_tentar_finalizar_missao()


func _process(delta: float) -> void:
	if not _inicializado or _extinguisher_failure_started or M1_feito:
		return
	_extinguisher_check_elapsed += delta
	if _extinguisher_check_elapsed < 0.25:
		return
	_extinguisher_check_elapsed = 0.0
	if _hall_extinguishers_exhausted():
		_extinguisher_failure_started = true
		man_player.show_hall_extinguisher_failure()


func _hall_extinguishers_exhausted() -> bool:
	if not is_instance_valid(man_player) or man_player.npc_warning_active:
		return false
	var blocked_by_fire := false
	for fire_name in ["Fogo3", "Fogo5", "Fogo6"]:
		var fire := get_parent().get_node_or_null("Perigos/" + fire_name)
		if is_instance_valid(fire) and not fire.is_queued_for_deletion() and not bool(fire.apagado):
			blocked_by_fire = true
			break
	if not blocked_by_fire:
		return false
	var equipped := man_player.inventory.get_item_control("extintor")
	if is_instance_valid(equipped) and float(equipped.combustivel) > 0.0:
		return false
	for item in get_parent().get_node("Coletaveis").get_children():
		if item.get_script() == EXTINGUISHER_SCRIPT and not item.is_queued_for_deletion() and float(item.combustivel) > 0.0:
			return false
	return true


func _pensamento_id(id: String) -> String:
	return "hall:" + save_id + ":" + id


func _pensar(id: String, line_id: String) -> void:
	man_player.balao_de_pensamento.enfileirar_dialogo(line_id, _pensamento_id(id))


func _on_non_objective_fire_extinction() -> void:
	man_player.balao_de_pensamento.enfileirar_dialogo("hall.on_non_objective_fire_extinction.player", _pensamento_id("fogo_fora_da_saida"), true)


func _descartar_instrucoes_obsoletas() -> void:

	var ids: Array[String] = [_pensamento_id("intro_3")]
	if M1_feito:
		ids.append_array([_pensamento_id("intro_4"), _pensamento_id("aviso_1"), _pensamento_id("aviso_2")])
	if M2_feito:
		ids.append(_pensamento_id("pedras"))
	if M1_feito and M2_feito:
		ids.append_array([_pensamento_id("intro_1"), _pensamento_id("intro_2"), _pensamento_id("intro_3")])
	if not ids.is_empty():
		man_player.balao_de_pensamento.descartar(ids)


func _atualizar_visibilidade() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _inicializado or not is_instance_valid(quest_ui):
		return
	quest_ui.definir_painel_visivel(true)


func _on_pensamento_iniciado(id: String) -> void:
	if id == _pensamento_id("intro_4") or id == _pensamento_id("pedras"):
		_highlight_hall_objectives()
	if id == _pensamento_id("intro_2") and not orientar_elevador:
		orientar_elevador = true
		orientacao_elevador_iniciada.emit()
	if id == _pensamento_id("intro_4") and not orientar_extintor:
		orientar_extintor = true
		pensamento_extintor_iniciado.emit()


func _highlight_hall_objectives() -> void:
	_clear_objective_highlights()
	get_parent().get_node("ElevatorRoute").set_guidance_visible(M1_feito and not M2_feito and not _hide_scheduled)
	if _hide_scheduled or not M1_feito:
		return
	if not M2_feito:
		var navigation := get_parent().get_node("HallNPCNavigation")
		var passage: Rect2 = get_parent().get_node("ElevatorRoute").bounds
		for object in get_parent().get_node("Coletaveis").get_children():
			if object is ObjetoEmpurravel:
				var sprite := object.get_node("Sprite2D") as Sprite2D
				if passage.intersects(navigation.sprite_bounds(sprite)):
					_add_objective_highlight(sprite)


func _add_objective_highlight(target: Node2D) -> void:
	var previous := target.get_node_or_null("ObjectiveHighlight")
	if previous != null:
		target.remove_child(previous)
		previous.queue_free()
	var highlight := Node2D.new()
	highlight.name = "ObjectiveHighlight"
	highlight.set_script(OBJECTIVE_HIGHLIGHT)
	highlight.add_to_group(&"hall_objective_highlight")
	target.add_child(highlight)


func _clear_objective_highlights() -> void:
	for highlight in get_tree().get_nodes_in_group(&"hall_objective_highlight"):
		if get_parent().is_ancestor_of(highlight) and not highlight.is_queued_for_deletion():
			highlight.fade_out()


func _on_pensamento_finalizado(id: String) -> void:
	if id == _pensamento_id("intro_2"):
		_atualizar_visibilidade()
	elif id == _pensamento_id("saida"):
		_atualizar_visibilidade()
	elif id == _pensamento_id("pos_saida_2"):
		_liberar_elevador_terceiro()

func _liberar_elevador_terceiro() -> void:
	if _elevador_terceiro_liberado:
		return
	_elevador_terceiro_liberado = true
	var estado := SaveGame.office_mission_state()
	estado["elevator_third_floor_unlocked"] = true
	estado["indicator_remaining"] = 10.0
	SaveGame.save_global_state(save_id, estado)
	_save_progress_and_checkpoint()
	_instanciar_indicador_final()
	_atualizar_tarefa_terceiro()
	_atualizar_visibilidade()


func _atualizar_tarefa_terceiro() -> void:
	quest_ui.definir_texto_tarefa(3, "IR PARA O TERCEIRO ANDAR")
	quest_ui.mostrar_apenas_tarefa_terceiro_andar(_chegou_terceiro_andar)


func _atualizar_linhas_tarefas() -> void:
	if _elevador_terceiro_liberado:
		_atualizar_tarefa_terceiro()
		return
	quest_ui.definir_tarefa_visivel(0, true)
	quest_ui.definir_tarefa_visivel(1, true)
	quest_ui.definir_tarefa_visivel(2, _hide_scheduled)
	if _hide_scheduled:
		quest_ui.definir_texto_tarefa(2, "ESPERE TODO MUNDO SAIR")
		quest_ui.definir_tarefa_concluida(2, _todos_sairam)
	quest_ui.definir_tarefa_visivel(3, false)


func _instanciar_indicador_final() -> void:
	if float(SaveGame.office_mission_state().get("indicator_remaining", 0.0)) <= 0.0:
		return
	var pai := get_parent().get_node_or_null("Interativos")
	if pai == null or pai.has_node("ElevatorIndicator"):
		return
	var antigo := pai.get_node_or_null("Line2D")
	if antigo != null:
		antigo._liberar_indicador()
	orientar_elevador = true
	var novo := preload("res://Scenes/elevator_indicator.tscn").instantiate()
	novo.get_node("Line2D").ciclo_final = true
	pai.add_child(novo)


func _on_fogo_3_fogo_apagou() -> void:
	if not f1_acesso:
		return

	f1_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_5_fogo_apagou() -> void:
	if not f2_acesso:
		return

	f2_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_6_fogo_apagou() -> void:
	if not f3_acesso:
		return

	f3_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _physics_process(delta: float) -> void:
	if _exit_paths_pending:
		_exit_paths_pending = false
		_start_npc_exit_paths(_exit_paths_legacy_restore)
	if not _inicializado or _hide_scheduled:
		return
	_route_check_elapsed += delta
	if _route_check_elapsed < 0.25:
		return
	_route_check_elapsed = 0.0
	var clear: bool = not get_parent().get_node("ElevatorRoute").get_clear_route().is_empty()
	if clear == M2_feito:
		_tentar_finalizar_missao()
		return
	M2_feito = clear
	quest_ui.definir_tarefa_concluida(1, clear, clear)
	get_parent().get_node("ElevatorRoute").set_guidance_visible(M1_feito and not clear)
	if clear and M1_feito:
		_clear_objective_highlights()
	if clear and not M1_feito:
		_pensar("aviso_1", "hall.exit.fire_warning")
		_pensar("aviso_2", "hall.exit.unsafe")

	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _update_fire_task() -> void:
	if f1_acesso:
		return

	if f2_acesso:
		return

	if f3_acesso:
		return

	if M1_feito:
		return

	M1_feito = true
	quest_ui.definir_tarefa_concluida(0, true, true)
	_highlight_hall_objectives()

	if not M2_feito:
		_pensar("pedras", "hall.exit.debris")


func _tentar_finalizar_missao() -> bool:
	if not _inicializado:
		return false
	_descartar_instrucoes_obsoletas()
	if not M1_feito:
		return false

	if not M2_feito:
		return false

	if _hide_scheduled:
		return false
	if not Engine.is_in_physics_frame():
		return false

	_hide_scheduled = true

	_start_npc_exit_paths()
	_pensar("saida", "hall.exit.evacuate")
	_pos_saida_iniciada = true
	_iniciar_espera_npcs()
	_save_progress_and_checkpoint()
	return true


func _start_npc_exit_paths(legacy_restore: bool = false) -> void:
	if not Engine.is_in_physics_frame():
		_exit_paths_pending = true
		_exit_paths_legacy_restore = legacy_restore
		return
	var npcs := get_node_or_null("../NPCs")

	if npcs == null:
		return
	var route_checker := get_parent().get_node("ElevatorRoute")
	var route: PackedVector2Array = route_checker.get_clear_route()

	for npc in npcs.get_children():
		if npc.is_queued_for_deletion():
			continue

		var path := npc.get_node_or_null("Line2D2") as NPCPath

		if path == null:
			continue
		route_checker.prepare_exit_path(npc, path, route)

		if legacy_restore:
			if not npc.get_script():
				continue

			if npc.get("checkpoint_restored") != false:
				continue

			path.start_path()

			var points: Variant = npc.get("path_points")

			if points is Array and not points.is_empty():
				npc.global_position = points[0]

		else:
			path.start_path()


func _iniciar_espera_npcs() -> void:
	quest_ui.definir_tarefa_visivel(2, true)
	if _todos_sairam:
		_concluir_saida_depois_da_animacao(null)
		return
	quest_ui.definir_texto_tarefa(2, "ESPERE TODO MUNDO SAIR")
	quest_ui.definir_tarefa_concluida(2, false)
	var npcs := get_node_or_null("../NPCs")
	_saida_pendente = 0
	_evacuacao_ativa = true
	if npcs != null:
		for npc in npcs.get_children():
			if npc.is_queued_for_deletion():
				continue
			_saida_pendente += 1
			if npc.has_signal("npc_saiu"):
				if not npc.npc_saiu.is_connected(_on_npc_saiu):
					npc.npc_saiu.connect(_on_npc_saiu, CONNECT_ONE_SHOT)
			elif not npc.tree_exiting.is_connected(_on_npc_saiu):
				npc.tree_exiting.connect(_on_npc_saiu, CONNECT_ONE_SHOT)
	if _saida_pendente == 0:
		_concluir_saida_npcs()


func _on_npc_saiu() -> void:
	if not _evacuacao_ativa or not is_inside_tree():
		return
	_saida_pendente = maxi(_saida_pendente - 1, 0)
	if _saida_pendente == 0:
		_concluir_saida_npcs()


func _concluir_saida_npcs() -> void:
	if _todos_sairam:
		return
	_todos_sairam = true
	_evacuacao_ativa = false
	quest_ui.definir_tarefa_concluida(2, true, true)
	_concluir_saida_depois_da_animacao(quest_ui.marcadores[2])


func _concluir_saida_depois_da_animacao(marcador: AnimatedSprite2D) -> void:
	if marcador != null:
		await marcador.animation_finished
	if not is_inside_tree() or is_queued_for_deletion() or not _pos_saida_iniciada:
		return
	_liberar_elevador_terceiro()
	_pensar("pos_saida_1", "hall.after_exit.1")
	_pensar("pos_saida_2", "hall.after_exit.2")
	_save_progress_and_checkpoint()


func _save_progress_and_checkpoint() -> void:
	SaveGame.save_object_state(
		save_id,
		{
			"fire_1_done": not f1_acesso,
			"fire_2_done": not f2_acesso,
			"fire_3_done": not f3_acesso,
			"task_fire_done": M1_feito,
			"task_elevator_done": M2_feito,
			"exit_started": _hide_scheduled,
			"everyone_out": _todos_sairam,
			"post_exit_started": _pos_saida_iniciada,
			"office_hint_shown": _dica_mostrada
			,"elevator_third_floor_unlocked": _elevador_terceiro_liberado
			,"arrived_third_floor": _chegou_terceiro_andar
		}
	)

	var player := get_tree().get_first_node_in_group("player") as Player

	if player != null and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _restore_progress() -> void:
	var saved_value: Variant = SaveGame.load_object_state(save_id)

	if saved_value is Dictionary:
		var saved_state: Dictionary = saved_value

		f1_acesso = not bool(
			saved_state.get("fire_1_done", false)
		)

		f2_acesso = not bool(
			saved_state.get("fire_2_done", false)
		)

		if saved_state.has("fire_3_done"):
			f3_acesso = not bool(
				saved_state.get("fire_3_done", false)
			)
		else:
			f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = bool(
			saved_state.get("task_fire_done", false)
		)

		M2_feito = bool(
			saved_state.get("task_elevator_done", false)
		)

		_hide_scheduled = bool(saved_state.get("exit_started", M1_feito and M2_feito))
		_todos_sairam = bool(saved_state.get("everyone_out", false))
		_pos_saida_iniciada = bool(saved_state.get("post_exit_started", false))
		_dica_mostrada = bool(saved_state.get("office_hint_shown", false))
		_elevador_terceiro_liberado = bool(saved_state.get("elevator_third_floor_unlocked", false))
		_chegou_terceiro_andar = bool(saved_state.get("arrived_third_floor", false))

	else:
		f1_acesso = not _is_saved_fire_extinguished("fogo04")
		f2_acesso = not _is_saved_fire_extinguished("fogo05")
		f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = (
			not f1_acesso
			and not f2_acesso
			and not f3_acesso
		)
	var global_state: Variant = SaveGame.office_mission_state(man_player)
	if global_state is Dictionary:
		_elevador_terceiro_liberado = bool(global_state.get("elevator_third_floor_unlocked", _elevador_terceiro_liberado))
		_chegou_terceiro_andar = bool(global_state.get("arrived_third_floor", _chegou_terceiro_andar))

	if not f1_acesso and not f2_acesso and not f3_acesso:
		M1_feito = true


func _is_saved_fire_extinguished(fire_save_id: String) -> bool:
	var fire_state: Variant = SaveGame.load_object_state(fire_save_id)

	return (
		fire_state is Dictionary
		and bool(fire_state.get("apagado", false))
	)


func _apply_saved_visuals() -> void:
	quest_ui.definir_tarefa_concluida(0, M1_feito)
	quest_ui.definir_tarefa_concluida(1, M2_feito)
	quest_ui.definir_tarefa_concluida(2, _todos_sairam)
	quest_ui.definir_tarefa_concluida(3, _chegou_terceiro_andar)
