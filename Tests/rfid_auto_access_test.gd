extends Node

var failures: Array[String] = []


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	_run.call_deferred()


func _run() -> void:
	SaveGame.save_data = {}
	SaveGame.checkpoint_scene_path = ""
	SaveGame.state_player = {}
	SaveGame.restore_checkpoint_pending = false
	SaveGame.tempo_atual = 300.0
	Configs.configs["job"] = "programador"
	ContextualTutorial.set_process(false)
	var player := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	player.checkpoint_enabled = false
	player.starting_gun_enabled = false
	add_child(player)
	scene_manager.player = player
	scene_manager.last_scene_name = "DATA_CENTER_FORTE"
	var state := {
		"data_center_card_delivered": true,
		"data_center_card_dialog_finished": true,
		"data_center_access_plan_finished": true,
		"data_center_breaker_restored": true,
		"data_center_return_task_completed": true,
		"data_center_scientist_followup_done": true,
		"data_center_access_npc_arrived": true,
		"data_center_access_boss_card_given": true,
		"data_center_access_boss_dialog_finished": true,
		"data_center_rfid_reader_rechecked": true,
		"cooling_location_cutscene_seen": true,
		"data_center_forte_intro_seen": true
	}
	SaveGame.save_global_state("hall_quest_01", state)
	var world := preload("res://Scenes/andar_data_center.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await get_tree().create_timer(0.4).timeout
	_expect(get_tree().current_scene == world, "Cancelar o minigame não pode provocar entrada automática.")
	var controller := world.get_node("DataCenterIntroController") as DataCenterIntroController
	var trigger := world.get_node("SceneTrigger2") as SceneTrigger
	trigger.reproduzir_acesso_negado()
	var indicator: Node2D = trigger.get_node("DoorAccessIndicator")
	_expect(indicator.visible and not indicator.liberado, "O cartão negado deve acender o indicador vermelho da porta.")
	var door_collision := trigger.get_node("CollisionShape2D") as CollisionShape2D
	_expect(is_equal_approx(indicator.global_position.x, door_collision.global_position.x) and indicator.global_position.y < door_collision.global_position.y, "O indicador deve ficar acima da porta, respeitando o deslocamento do leitor.")
	indicator.mostrar_estado(true)
	_expect(indicator.liberado and indicator.cor_estado == indicator.cor_liberado, "O acesso liberado deve trocar o indicador para verde.")
	var elevator_indicator: Node2D = world.get_node("SceneTrigger/DoorAccessIndicator")
	elevator_indicator.mostrar_estado(false)
	_expect(not elevator_indicator.visible, "O indicador das portas não deve aparecer no elevador.")
	trigger.entrar_com_cartao_verificado(player)
	await get_tree().create_timer(0.2).timeout
	_expect(not trigger.acesso_em_andamento, "O leitor não pode aceitar automaticamente um RFID ainda incompleto.")
	state["data_center_rfid_minigame_completed"] = true
	state["data_center_rfid_reading_checked"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	controller._restore_access_progress(state)
	await get_tree().create_timer(0.2).timeout
	_expect(get_tree().current_scene == world and not trigger.acesso_em_andamento, "Continuar um save concluído não deve repetir a entrada automática.")
	state["data_center_rfid_auto_access_pending"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	player.reset_sprite_player()
	controller._restore_access_progress(state)
	var deadline := Time.get_ticks_msec() + 5000
	while get_tree().current_scene == world and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.05).timeout
	_expect(player.usando_cartao, "O cartão do chefe deve ser equipado automaticamente.")
	_expect(get_tree().current_scene.scene_file_path == "res://Scenes/data_center_forte.tscn", "Concluir o RFID deve usar o leitor e entrar na área restrita sem apertar E novamente.")
	_expect(player.is_physics_processing(), "Ao entrar sem repetir a cutscene, o jogador deve continuar podendo se mover.")
	_expect(not bool(state.get("data_center_rfid_auto_access_pending", true)), "A entrada automática deve ser consumida uma única vez.")
	var report := FileAccess.open("res://.rfid-auto-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
