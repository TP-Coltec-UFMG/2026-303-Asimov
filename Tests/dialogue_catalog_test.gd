extends Node

var failures: Array[String] = []


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	ContextualTutorial.set_process(false)
	_run.call_deferred()


func _run() -> void:
	var data: Dictionary = DialogueCatalog.DATA.data
	var actors: Dictionary = data["actors"]
	for line_id: String in data["lines"]:
		var line := DialogueCatalog.get_line(line_id)
		_expect(actors.has(line["sender_id"]) and actors.has(line["recipient_id"]), "Participantes inválidos: " + line_id)
		_expect(line["text"] is String and not str(line["text"]).is_empty(), "Texto vazio: " + line_id)
		_expect(line["thought"] is bool, "Tipo de pensamento inválido: " + line_id)
		if line["thought"]:
			_expect(line["sender_id"] == line["recipient_id"], "Pensamento deve pertencer ao próprio personagem: " + line_id)
	for sequence_id: String in data["sequences"]:
		var lines := DialogueCatalog.entries(sequence_id)
		_expect(not lines.is_empty(), "Sequência vazia: " + sequence_id)
		for line in lines:
			_expect(line["text"] == line["texto"], "Os adaptadores devem preservar a mesma fala.")
	for path in [
		"res://Scenes/scripts/data_center_intro_controller.gd",
		"res://Scenes/scripts/engineer_ending_controller.gd",
		"res://Scenes/scripts/programmer_ending_controller.gd",
		"res://Scenes/scripts/office_intro_controller.gd",
		"res://Scenes/scripts/quest_mission.gd",
		"res://Scenes/scripts/sala_chefe.gd",
		"res://Scenes/scripts/base_scene.gd",
		"res://Player/Scripts/quest_mission_ui.gd",
		"res://Player/Scripts/player.gd",
		"res://Objects/scripts/dijuntor.gd",
		"res://Minigames/Minigame5/Scripts/mini_game_cartao.gd",
	]:
		var script: Script = load(path)
		_expect(script != null and script.can_instantiate(), "Script inválido após migração: " + path)
	var balloon: Node = preload("res://NPC'S/BalaoDeFalaNPC.tscn").instantiate()
	add_child(balloon)
	balloon.enfileirar_dialogo("hall.intro.extinguisher", "checkpoint:thought")
	_expect(balloon.label.text == "Preciso de um extintor.", "O pensamento deve preservar seu texto.")
	var saved: Dictionary = balloon.get_checkpoint_state()
	_expect(saved["ativo"]["sender_id"] == "player" and saved["ativo"]["recipient_id"] == "player", "O checkpoint deve guardar os participantes do pensamento.")
	balloon.pular_pensamento()
	balloon.enfileirar_dialogo("hall.intro.extinguisher", "checkpoint:thought")
	_expect(not balloon.esta_ocupado(), "Um pensamento concluído não deve se repetir automaticamente.")
	balloon.enfileirar_dialogo("hall.intro.extinguisher", "checkpoint:thought", true)
	_expect(balloon.pensamento_atual_id() == "checkpoint:thought", "Pensamentos repetíveis devem continuar funcionando.")
	balloon.load_checkpoint_state(saved)
	_expect(balloon.pensamento_atual_id() == "checkpoint:thought" and balloon._ativo["line_id"] == "hall.intro.extinguisher", "O pensamento deve voltar do checkpoint no mesmo ponto.")
	balloon.pular_pensamento()
	balloon.queue_free()
	var npc: Node = preload("res://NPC'S/Clarxs.tscn").instantiate()
	npc.save_enabled = false
	npc.sprite_sheet = preload("res://NPC'S/NPC/06_purple_crimson.png")
	npc.dialog_sequence_id = "office.scientist.with_cable"
	add_child(npc)
	_expect(npc.dialog_texts.size() == 7 and npc.dialog_texts[4] == "Alex: Encontrei um cabo. Só falta um notebook.", "O cientista deve escolher a variante correta para o item encontrado antes da conversa.")
	npc.queue_free()
	DialogManager.start_catalog_dialog("data_center.card_delivery", "catalog:original", 1)
	var original_box: Node = DialogManager.dialog_box
	_expect(DialogManager.current_line_data["sender_id"] == "scientist", "A fala atual deve identificar seu remetente.")
	DialogManager.interrupt_with_catalog_dialog("data_center.power_failure.before", "catalog:interruption", false)
	_expect(DialogManager.current_line_data["sender_id"] == "player", "A interrupção deve identificar a fala do jogador.")
	DialogManager.dialog_box.call("_fechar_dialogo")
	await get_tree().create_timer(1.0).timeout
	_expect(not DialogManager.is_showing_dialog, "A queda deve aguardar a interação com o NPC para retomar.")
	_expect(DialogManager.resume_suspended_dialog("catalog:original"), "A conversa do JSON deve permitir retomada.")
	_expect(DialogManager.dialog_box == original_box and int(original_box.indice_atual) == 1, "A conversa deve retomar a mesma fala.")
	_expect(DialogManager.current_sequence_id == "data_center.card_delivery" and DialogManager.current_line_data["recipient_id"] == "player", "A retomada deve preservar a sequência e seus participantes.")
	DialogManager.dialog_box.call("_fechar_dialogo")
	await get_tree().create_timer(1.0).timeout
	var report := FileAccess.open("res://.dialogue-catalog-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "lines": data["lines"].size(), "sequences": data["sequences"].size()}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
