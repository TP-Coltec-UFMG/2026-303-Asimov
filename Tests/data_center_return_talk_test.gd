extends Node

var failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var player := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	player.checkpoint_enabled = false
	add_child(player)
	scene_manager.player = player
	await get_tree().process_frame
	var quest := player.get_node("QUEST_MISSION") as QuestMissionUI
	var state := {
		"data_center_card_delivered": true,
		"data_center_card_dialog_finished": true,
		"data_center_access_plan_finished": true,
		"data_center_breaker_restored": true,
		"data_center_return_task_completed": true,
		"data_center_rfid_inspection_task_active": true,
		"data_center_access_resume_talk_needed": true
	}
	SaveGame.save_global_state("hall_quest_01", state)
	quest.refresh_saved_state()
	_expect(quest.rows[6].visible and quest.rows[7].visible, "O retorno concluído e a conversa pendente devem aparecer juntos.")
	_expect(not quest.rows[12].visible, "A tarefa RFID deve aguardar a conversa pendente.")
	_expect((quest.rows[7].get_node("Label3") as Label).text == "FALE COM O CIENTISTA", "O painel deve orientar a falar com o cientista.")
	state["data_center_access_resume_talk_needed"] = false
	state["data_center_interrupted_dialog"] = {"id": "data_center:access_plan", "lines": ["Fala"], "index": 0}
	SaveGame.save_global_state("hall_quest_01", state)
	quest.refresh_saved_state()
	_expect(quest.rows[7].visible, "Uma fala interrompida também deve manter a tarefa de conversar.")
	state.erase("data_center_interrupted_dialog")
	SaveGame.save_global_state("hall_quest_01", state)
	quest.refresh_saved_state()
	_expect(quest.rows[7].visible, "Um save antigo com o retorno concluído também deve pedir a conversa.")
	state["data_center_scientist_followup_done"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	quest.refresh_saved_state()
	_expect(quest.rows[12].visible and not quest.rows[7].visible, "Após a conversa, a tarefa RFID deve voltar.")
	state["data_center_access_resume_talk_needed"] = true
	state["data_center_scientist_followup_done"] = false
	state["data_center_return_task_pending"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	quest._activate_return_to_data_center_task()
	_expect(quest.rows[6].visible and quest.rows[7].visible, "Concluir o retorno não pode apagar a tarefa de conversar.")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: retorno ao data center mantém a conversa pendente no painel.")
	get_tree().quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
