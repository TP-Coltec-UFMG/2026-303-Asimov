extends Node

var falhas: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	SaveGame.checkpoint_scene_path = ""
	SaveGame.state_player = {}
	SaveGame.restore_checkpoint_pending = false
	SaveGame.tempo_atual = 300.0
	ContextualTutorial.set_process(false)
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	add_child(jogador)
	scene_manager.player = jogador
	var estado := {"cooling_location_cutscene_seen": true}
	SaveGame.save_global_state("hall_quest_01", estado)
	var mapa := preload("res://Scenes/andar_data_center.tscn").instantiate()
	get_tree().root.add_child(mapa)
	get_tree().current_scene = mapa
	await get_tree().create_timer(0.25).timeout
	var controle := mapa.get_node("DataCenterIntroController") as DataCenterIntroController
	jogador.global_position = Vector2(30, -180)
	estado["data_center_card_delivered"] = true
	estado["data_center_card_dialog_finished"] = true
	for fase: String in ["before", "during", "after"]:
		estado["data_center_outage_phase"] = fase
		estado["data_center_outage_pending"] = true
		controle._ensure_outage_schedule(estado)
		_conferir(estado["data_center_outage_phase"] == "approach", "Saves antigos devem usar a aproximação, sem sorteio.")
	controle._begin_power_failure()
	_conferir(not controle.power_sequence_running, "A energia não pode cair antes da conversa.")
	controle._on_dialog_finished(controle.ACCESS_PLAN_DIALOG_ID)
	controle._on_outage_timer_timeout()
	_conferir(not controle.power_sequence_running, "A queda deve esperar a aproximação do leitor.")
	controle.outage_timer.stop()
	jogador.global_position = controle.access_destination.global_position
	DialogManager.start_dialog(["Conversa em andamento"], "teste:conversa")
	controle._on_outage_timer_timeout()
	_conferir(not controle.power_sequence_running, "A queda não pode interromper uma conversa.")
	DialogManager.dialog_box.call("_fechar_dialogo")
	await get_tree().create_timer(0.7).timeout
	controle.outage_timer.stop()
	controle.rfid_verification_running = true
	controle._on_outage_timer_timeout()
	_conferir(not controle.power_sequence_running, "A queda não pode iniciar durante a verificação RFID.")
	controle.rfid_verification_running = false
	controle._on_outage_timer_timeout()
	_conferir(controle.power_sequence_running, "Chegar ao leitor após a conversa deve iniciar o aviso.")
	_conferir(not bool(estado.get("data_center_power_outage", false)), "A reação do cientista deve preceder o apagão.")
	for luz in controle.regular_lights:
		_conferir(not luz.visible, "O aviso deve começar com uma piscada isolada.")
	_conferir(not mapa.get_node("Iluminacao/LuzDeEmergencia/PointLight2D").visible, "A luz de emergência deve aguardar o apagão.")
	controle._on_access_requested(controle.access_trigger)
	_conferir(not controle.access_sequence_busy, "O aviso deve impedir a abertura de minigames.")
	await get_tree().create_timer(0.2).timeout
	for luz in controle.regular_lights:
		_conferir(luz.visible == bool(controle.regular_light_visibility[luz]), "Após a primeira piscada, as luzes devem estabilizar.")
	await get_tree().create_timer(1.25).timeout
	_conferir(controle.som_falha.playing, "A drenagem deve tocar o efeito elétrico.")
	_conferir(not bool(estado.get("data_center_power_outage", false)), "O apagão deve esperar a sequência de drenagem.")
	await get_tree().create_timer(3.0).timeout
	_conferir(bool(estado.get("data_center_power_outage", false)), "O aviso deve terminar no apagão.")
	_conferir(mapa.get_node("Iluminacao/LuzDeEmergencia/PointLight2D").visible, "A emergência deve acender após a queda.")
	_conferir(not mapa.has_node("Iluminacao/LuzDeEmergencia2") and not mapa.has_node("Iluminacao/LuzDeEmergencia3"), "Deve haver apenas um feixe de emergência no alto.")
	_conferir(not DialogManager.is_showing_dialog, "A explicação do apagão deve aguardar interação.")
	_conferir(controle.recipient.get("caminho_atual") == controle.caminho_paineis, "O cientista deve caminhar até os painéis.")
	var limite := Time.get_ticks_msec() + 10000
	while not bool(estado.get("data_center_power_panel_reached", false)) and Time.get_ticks_msec() < limite:
		await get_tree().create_timer(0.1).timeout
	_conferir(bool(estado.get("data_center_power_panel_reached", false)), "O cientista precisa alcançar os painéis.")
	_conferir(controle.recipient.global_position.distance_to(controle.destino_paineis.global_position) < 6.0, "O cientista deve parar em frente aos painéis.")
	_conferir(not controle.recipient.get("acompanhar_player_com_olhar"), "O cientista deve olhar para o painel.")
	var painel := jogador.get_node("QUEST_MISSION") as QuestMissionUI
	_conferir(painel.linhas[7].visible, "O painel de tarefas deve pedir para falar com o cientista.")
	painel.restaurar_estado_salvo()
	_conferir(painel.linhas[7].visible, "Restaurar as tarefas não pode antecipar a busca pelo disjuntor.")
	controle._restore_progress()
	_conferir(not DialogManager.is_showing_dialog and controle.recipient.get("caminho_atual") == null, "Restaurar o apagão deve manter o cientista no painel sem iniciar conversa.")
	controle._on_recipient_interaction_requested(controle.recipient)
	_conferir(DialogManager.current_dialog_id == controle.POWER_DIALOG_ID, "Interagir deve abrir a explicação do apagão.")
	var falas := DialogueCatalog.texts("data_center.power_failure.panel")
	_conferir(falas[1].contains("lanterna") and falas[1].contains("4º"), "A conversa deve explicar a lanterna e o andar do disjuntor.")
	DialogManager.dialog_box.call("_fechar_dialogo")
	await get_tree().create_timer(0.7).timeout
	_conferir(bool(estado.get("data_center_power_dialog_finished", false)), "A conversa deve liberar a missão do disjuntor.")
	var resultado := FileAccess.open("res://.outage-test-results.json", FileAccess.WRITE)
	resultado.store_string(JSON.stringify({"completed": true, "failures": falhas}))
	resultado.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
