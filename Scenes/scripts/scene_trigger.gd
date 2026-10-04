class_name SceneTrigger
extends Area2D

signal solicitou_acesso(trigger: SceneTrigger)

@export var cena_destino: String
@export	var eh_elevador: bool
@export var andar_atual: int
@export var acesso_controlado: bool = false
@onready var painel_elevador: Node2D = get_node_or_null("../PainelElevador") as Node2D
@onready var controle_de_tempo: Control = $"../UI/Controle_de_tempo"

var ultima_posicao: Vector2

@onready var acesso_liberado: AudioStreamPlayer2D = $"Acesso liberado"
@onready var acesso_negado: AudioStreamPlayer2D = $"Aceso negado"

var dentro_da_area : bool = false
var jogador : Player
var acesso_em_andamento: bool = false

func _ao_entrar_corpo(corpo: Node2D) -> void:
	if corpo is Player:
		dentro_da_area = true
		jogador = corpo


func _ao_sair_corpo(corpo: Node2D) -> void:
	if corpo is Player:
		dentro_da_area = false
		
func _obter_cena_andar(andar : int) -> String:
	if andar == 1:
		return "andar_saida"
	if andar == 2:
		return "andar_hall"
	if andar == 3:
		return "andar_escritorio"
	if andar == 4:
		return "andar_ferramentas"
	if andar == 5:
		return "andar_centro_de_energia"
	if andar == 6:
		return "andar_data_center"
		
	return "andar_invalido"
	
func usar_elevador(andar: int) -> void:
	if _bloqueado_por_evento_cena():
		return
	if eh_elevador and not elevador_liberado():
		return
	if eh_elevador and not pode_acessar_andar(andar):
		painel_elevador.mostrar_andar_bloqueado()
		return
	get_tree().paused = false
	if andar == -2:
		if dentro_da_area:
			_ocultar_paineis_tarefas()
			jogador.set_physics_process(true)
			jogador.inventory.hide()
			painel_elevador.resetar_sprites()
			await painel_elevador.animacao()
			MusicController.definir_audio_elevador(false)
			jogador.global_position = ultima_posicao
			jogador.inventory.show()
			controle_de_tempo.show()
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			_mostrar_paineis_tarefas()
			MusicController.definir_contexto_alarme_baixo(&"elevator", false)
		return
	if andar != andar_atual and eh_elevador:
		if dentro_da_area:
			_concluir_tarefa_do_sexto_andar(andar)
			_concluir_tarefa_do_quarto_andar(andar)
			_ocultar_paineis_tarefas()
			jogador.inventory.hide()
			painel_elevador.iniciar_movimento()
			$Timer.start()
			await $Timer.timeout
			await painel_elevador.animacao()
			MusicController.definir_audio_elevador(false)
			jogador.set_physics_process(true)
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			MusicController.definir_contexto_alarme_baixo(&"elevator", false)
			scene_manager.change_scene(jogador, _obter_cena_andar(andar))
			jogador.inventory.show()
			
	if (andar == andar_atual and eh_elevador):
		if dentro_da_area:
			_ocultar_paineis_tarefas()
			jogador.set_physics_process(true)
			jogador.inventory.hide()
			painel_elevador.resetar_sprites()
			await painel_elevador.animacao()
			MusicController.definir_audio_elevador(false)
			jogador.global_position = ultima_posicao
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			jogador.inventory.show()
			controle_de_tempo.show()
			_mostrar_paineis_tarefas()
			MusicController.definir_contexto_alarme_baixo(&"elevator", false)
			
			
func get_ultima_posicao() -> Vector2:
	return ultima_posicao

func _unhandled_input(event: InputEvent) -> void:
	if acesso_em_andamento or _bloqueado_por_evento_cena():
		return
	
	if event.is_action_pressed("interact") and eh_elevador and dentro_da_area:
		if not elevador_liberado():
			return

		ultima_posicao = jogador.global_position
		jogador.set_physics_process(false)
		jogador.global_position += Vector2(-20, -200)
		painel_elevador.resetar_sprites()
		$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_DISABLED
		painel_elevador.visible = true
		controle_de_tempo.hide()
		_ocultar_paineis_tarefas()
		MusicController.definir_audio_elevador(true)
		MusicController.definir_contexto_alarme_baixo(&"elevator", true)
		get_tree().paused = true

	if event.is_action_pressed("interact") and dentro_da_area and not eh_elevador:
		if is_instance_valid(jogador) and jogador.usando_cartao:
			GameAudio.tocar_no_mundo(self, GameAudio.PASSAR_CARTAO, -12.0)
		if acesso_controlado:
			var visor := get_viewport()
			if visor != null:
				visor.set_input_as_handled()
			solicitou_acesso.emit(self)
			return
		if _tem_cartao_compativel() or _sala_do_chefe_foi_hackeada():
			await _entrar_area_autorizada()
		elif _pode_hackear_sala_do_chefe():
			Progresso.iniciar_hack_da_sala_do_chefe(jogador)
		else:
			$DoorAccessIndicator.mostrar_estado(false)
			acesso_negado.play()
			pass


func entrar_com_cartao_verificado(jogador_retornando: Player) -> void:
	if cena_destino != "data_center_forte" or acesso_controlado or acesso_em_andamento or _bloqueado_por_evento_cena():
		return
	if not is_instance_valid(jogador_retornando) or not get_parent().is_ancestor_of(jogador_retornando):
		return
	var estado := SaveGame.office_mission_state(jogador_retornando)
	if not bool(estado.get("data_center_rfid_minigame_completed", false)) or not bool(estado.get("data_center_rfid_reading_checked", false)):
		return
	if get_tree().paused or DialogManager.is_showing_dialog:
		return
	jogador = jogador_retornando
	if not _tem_cartao_compativel():
		return
	ContextualTutorial.cancelar_atual()
	jogador.direction = Vector2.ZERO
	jogador.velocity = Vector2.ZERO
	jogador.correndo = false
	jogador.state = "idle"
	jogador.UpdateAnimation()
	jogador.set_physics_process(false)
	jogador._stop_movement_sfx()
	GameAudio.tocar_no_mundo(self, GameAudio.PASSAR_CARTAO, -12.0)
	await _entrar_area_autorizada(false)


func _entrar_area_autorizada(exigir_presenca: bool = true) -> void:
	if acesso_em_andamento:
		return
	acesso_em_andamento = true
	$DoorAccessIndicator.mostrar_estado(true)
	acesso_liberado.play()
	await acesso_liberado.finished
	if exigir_presenca and not dentro_da_area:
		acesso_em_andamento = false
		return
	await _reproduzir_transicao_area_restrita()
	if not is_inside_tree() or (exigir_presenca and not dentro_da_area):
		acesso_em_andamento = false
		return
	_preparar_saida_da_sala_do_chefe()
	_registrar_acesso_a_sala_do_chefe()
	if not exigir_presenca and bool(SaveGame.office_mission_state(jogador).get("data_center_forte_intro_seen", false)):
		jogador.set_physics_process(true)
	scene_manager.change_scene(jogador, cena_destino)


func _bloqueado_por_evento_cena() -> bool:
	var guia := get_parent().get_node_or_null("CoolingLocationGuide")
	if guia != null and bool(guia.get("cutscene_running")):
		return true
	var introducao := get_parent().get_node_or_null("DataCenterIntroController")
	return introducao != null and bool(introducao.get("power_sequence_running"))


func reproduzir_acesso_negado() -> void:
	$DoorAccessIndicator.mostrar_estado(false)
	acesso_negado.play()
	await acesso_negado.finished


func _reproduzir_transicao_area_restrita() -> void:
	if cena_destino != "data_center_forte":
		return
	var cena := get_parent()
	if cena == null:
		return
	var controlador := cena.get_node_or_null("DataCenterIntroController")
	if controlador != null and controlador.has_method("play_restricted_area_fade_out"):
		await controlador.call("play_restricted_area_fade_out")


func _tem_cartao_compativel() -> bool:
	if cena_destino == "data_center_forte" and bool(SaveGame.office_mission_state(jogador).get("data_center_engineer_access_unlocked", false)):
		return true
	if not jogador.inventory.get_item_on_inventary("cartao") or not jogador.usando_cartao:
		return false
	var tipo_cartao: int = int(jogador.inventory.get_item_control("cartao").tipo)
	var nivel_sala := 1
	if cena_destino.containsn("chefe"):
		nivel_sala = 3
	elif cena_destino.containsn("forte"):
		nivel_sala = 2
	return tipo_cartao >= nivel_sala


func _pode_hackear_sala_do_chefe() -> bool:
	return (
		cena_destino.containsn("chefe")
		and jogador.inventory.get_item_on_inventary("laptop")
		and jogador.inventory.get_item_on_inventary("cabo")
		and not _sala_do_chefe_foi_hackeada()
	)


func _sala_do_chefe_foi_hackeada() -> bool:
	return (
		cena_destino.containsn("chefe")
		and bool(SaveGame.office_mission_state(jogador).get("office_boss_room_hacked", false))
	)


func _registrar_acesso_a_sala_do_chefe() -> void:
	if not cena_destino.containsn("chefe"):
		return
	var estado := SaveGame.office_mission_state(jogador)
	estado["office_boss_room_access_found"] = true
	SaveGame.save_global_state("hall_quest_01", estado)


func _preparar_saida_da_sala_do_chefe() -> void:
	if cena_destino != "andar_escritorio":
		return
	var cena := get_parent()
	if cena != null and cena.has_method("prepare_return_to_office"):
		cena.call("prepare_return_to_office")


func _concluir_tarefa_do_sexto_andar(andar: int) -> void:
	if andar != 6:
		return
	var estado: Dictionary = SaveGame.office_mission_state(jogador)
	var tarefa_retorno_pendente := bool(estado.get("data_center_return_task_pending", false))
	var tarefa_retorno_ativa := bool(estado.get("data_center_return_task_active", false))
	if (
		(tarefa_retorno_pendente or tarefa_retorno_ativa)
		and not bool(estado.get("data_center_return_task_completed", false))
	):
		estado["data_center_return_task_completed"] = true
		estado["data_center_return_task_active"] = false

		estado["data_center_return_task_pending"] = tarefa_retorno_pendente
		SaveGame.save_global_state("hall_quest_01", estado)
		jogador.balao_de_pensamento.descartar([
			"data_center:breaker_restored_urgent",
			"data_center:breaker_return_plan",
		])
		if tarefa_retorno_ativa:
			var painel_retorno := _obter_painel_tarefas()
			if painel_retorno != null:
				if SaveGame.data_center_scientist_talk_pending(estado):
					painel_retorno.mostrar_tarefas_retorno_e_cientista()
				else:
					painel_retorno.mostrar_tarefa_voltar_data_center(true, true)
		return
	if not bool(estado.get("office_data_center_task_active", false)):
		return
	if bool(estado.get("office_data_center_task_completed", false)):
		return
	estado["office_data_center_task_completed"] = true
	SaveGame.save_global_state("hall_quest_01", estado)
	jogador.balao_de_pensamento.descartar([
		"boss_room:chief_card_found",
		"office:data_center_floor",
	])
	var painel_tarefas := _obter_painel_tarefas()
	if painel_tarefas != null:
		painel_tarefas.mostrar_tarefa_ir_sexto_andar(true, true)


func _concluir_tarefa_do_quarto_andar(andar: int) -> void:
	if andar != 4:
		return
	var estado: Dictionary = SaveGame.office_mission_state(jogador)
	if not bool(estado.get("data_center_tools_floor_task_active", false)):
		return
	if bool(estado.get("data_center_tools_floor_task_completed", false)):
		return
	estado["data_center_tools_floor_task_completed"] = true
	SaveGame.save_global_state("hall_quest_01", estado)
	var painel_tarefas := _obter_painel_tarefas()
	if painel_tarefas != null:
		painel_tarefas.mostrar_tarefas_energia_data_center(
			jogador.inventory.get_item_on_inventary("lanterna"),
			true,
			bool(estado.get("data_center_breaker_restored", false)),
			true
		)
			


func elevador_liberado() -> bool:
	if not is_inside_tree():
		return false
	if not get_tree().current_scene.scene_file_path.ends_with("andar_hall.tscn"):
		return true
	return bool(SaveGame.office_mission_state().get("elevator_third_floor_unlocked", false))


func pode_acessar_andar(andar: int) -> bool:
	if andar == -2 or andar == andar_atual:
		return true
	return andar_liberado_por_progresso(andar, SaveGame.office_mission_state(jogador))


static func andar_liberado_por_progresso(andar: int, estado: Dictionary) -> bool:
	match andar:
		2:
			return true
		3:
			return bool(estado.get("elevator_third_floor_unlocked", false)) or bool(estado.get("arrived_third_floor", false))
		6:
			return bool(estado.get("office_data_center_task_active", false)) or bool(estado.get("office_data_center_task_completed", false)) or bool(estado.get("data_center_card_delivered", false))
		4:
			return bool(estado.get("data_center_tools_floor_task_active", false)) or bool(estado.get("data_center_power_dialog_finished", false)) or bool(estado.get("data_center_tools_floor_task_completed", false)) or bool(estado.get("data_center_breaker_restored", false))
	return false


func _ocultar_paineis_tarefas() -> void:
	var painel := _obter_painel_tarefas()
	if painel != null:
		painel.ocultar_durante_elevador()


func _mostrar_paineis_tarefas() -> void:
	var painel := _obter_painel_tarefas()
	if painel != null:
		painel.restaurar_apos_elevador()


func _obter_painel_tarefas() -> QuestMissionUI:
	var jogador_atual := jogador
	if not is_instance_valid(jogador_atual):
		jogador_atual = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(jogador_atual):
		return null
	return jogador_atual.get_node_or_null("QUEST_MISSION") as QuestMissionUI
