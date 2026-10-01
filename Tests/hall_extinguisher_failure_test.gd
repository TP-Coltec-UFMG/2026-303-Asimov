extends Node

var failures: Array[String] = []


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	_run.call_deferred()


func _run() -> void:
	SaveGame.clear_save()
	Configs.configs["job"] = "engenheiro_eletrico"
	Configs.configs["difficulty"] = "hard"
	Configs.configs["character"] = "character1"
	ContextualTutorial.set_process(false)
	var world := preload("res://Scenes/andar_hall.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await get_tree().process_frame
	await get_tree().process_frame
	Configs.configs["job"] = "engenheiro_eletrico"
	Configs.configs["difficulty"] = "hard"
	Configs.configs["character"] = "character1"
	Configs.configs["contextual_tutorial_seen"] = {"walk": true, "extinguisher": true}
	SaveLoad.save_data = Configs.configs.duplicate(true)
	var quest: Node = world.get_node("QuestController")
	quest.set_process(false)
	var player := world.player as Player
	player.checkpoint_enabled = false
	player.global_position = Vector2(80, 90)
	_expect(not quest._hall_extinguishers_exhausted(), "Extintores disponíveis no chão devem evitar a derrota.")
	var identifiers: Array[String] = []
	for item in world.get_node("Coletaveis").get_children():
		if item.get_script() == quest.EXTINGUISHER_SCRIPT:
			_expect(not str(item.save_id) in identifiers, "Cada extintor deve possuir um identificador único.")
			identifiers.append(str(item.save_id))
			item.combustivel = 0.0
	player.inventory.add_item("extintor", preload("res://Objects/extintor.tscn"))
	var extinguisher := player.inventory.get_item_control("extintor")
	extinguisher.combustivel = 1.0
	_expect(not quest._hall_extinguishers_exhausted(), "Uma carga restante no inventário deve evitar a derrota.")
	extinguisher.combustivel = 0.0
	_expect(quest._hall_extinguishers_exhausted(), "Sem nenhuma carga e com o acesso em chamas, a derrota deve ser detectada.")
	for fire_name in ["Fogo3", "Fogo5", "Fogo6"]:
		world.get_node("Perigos/" + fire_name).apagado = true
	_expect(not quest._hall_extinguishers_exhausted(), "O último extintor pode acabar junto com a extinção do último fogo, sem derrota.")
	world.get_node("Perigos/Fogo6").apagado = false
	SaveGame.save_global_state("hall_quest_01", {"test_old_progress": true})
	quest._process(0.3)
	await get_tree().create_timer(0.5, true, false, true).timeout
	_expect(player.npc_warning_active and player.npc_warning_layer.visible, "A derrota deve exibir a tela existente de aviso.")
	_expect(Engine.time_scale < 1.0, "O aviso deve usar câmera lenta.")
	_expect("OS EXTINTORES ACABARAM" in player.get_node("NonLethalWarning/Root/MessagePanel/Label").text, "A mensagem deve explicar a falta de extintores.")
	_expect(not player.is_physics_processing(), "O jogador não deve continuar a missão durante a derrota.")
	await get_tree().create_timer(2.5, true, false, true).timeout
	var restarted := get_tree().current_scene
	_expect(restarted != world and restarted.scene_file_path == "res://Scenes/andar_hall.tscn", "A derrota deve reiniciar diretamente no hall.")
	_expect(restarted.get_node("Coletaveis").get_child_count() >= 3, "Os extintores devem existir novamente no hall.")
	var fresh_extinguishers := 0
	for item in restarted.get_node("Coletaveis").get_children():
		if item.get_script() == preload("res://Objects/scripts/extintor.gd") and float(item.combustivel) == 100.0:
			fresh_extinguishers += 1
	_expect(fresh_extinguishers == 3, "O reinício deve restaurar os três extintores com carga completa.")
	_expect(restarted.player.inventory.get_item_control("extintor") == null, "O inventário não deve carregar o extintor esgotado do jogo anterior.")
	_expect(not SaveGame.office_mission_state().has("test_old_progress"), "O progresso anterior deve ser apagado.")
	_expect(Configs.configs["job"] == "engenheiro_eletrico" and Configs.configs["difficulty"] == "hard" and Configs.configs["character"] == "character1", "O reinício deve manter profissão, dificuldade e personagem.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "O reinício deve restaurar a velocidade normal.")
	_expect(ContextualTutorial._seen("walk") and ContextualTutorial._seen("extinguisher"), "Reiniciar por falta de extintores deve preservar os tutoriais já vistos.")
	_expect(not ContextualTutorial._seen("reload"), "Os tutoriais ainda não vistos devem continuar disponíveis.")
	var report := FileAccess.open("res://.hall-failure-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
