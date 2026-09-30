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
	var controller := preload("res://Scenes/scripts/office_intro_controller.gd").new()
	controller.player = player
	for first_item in ["laptop", "cabo"]:
		for laptop in [false, true]:
			for cable in [false, true]:
				for dialog_finished in [false, true]:
					var state := {
						"elevator_third_floor_unlocked": true,
						"office_first_hacking_item": first_item,
						"office_laptop_collected": laptop,
						"office_cable_collected": cable,
						"office_dialog_finished": dialog_finished,
						"office_hack_boss_room_ready": laptop and cable
					}
					SaveGame.save_global_state("hall_quest_01", state)
					var expected_completed: bool = laptop if first_item == "cabo" else cable
					if laptop or cable:
						quest.refresh_saved_state()
						_check_row(quest, first_item, expected_completed, "restauração")
						controller._show_boss_room_access_task()
						_check_row(quest, first_item, expected_completed, "após conversa")
					controller._show_hacking_item_task(state)
					_check_row(quest, first_item, expected_completed, "coleta")
	controller.free()
	var panel_script := preload("res://Objects/scripts/painel_elevador.gd")
	_expect(panel_script.mission_destination({}) == -1, "Sem missão de andar, não deve haver destaque.")
	_expect(panel_script.mission_destination({"elevator_third_floor_unlocked": true}) == 3, "Após o hall, o destino deve ser o escritório.")
	_expect(panel_script.mission_destination({"office_data_center_task_active": true}) == 6, "Com o cartão, o destino deve ser o data center.")
	_expect(panel_script.mission_destination({"data_center_power_outage": true, "data_center_power_dialog_finished": true}) == 4, "A queda de energia deve priorizar o disjuntor.")
	_expect(panel_script.mission_destination({"data_center_power_outage": true}) == 6, "Antes da explicação, o destino deve ser o cientista.")
	_expect(panel_script.mission_destination({"data_center_return_task_active": true, "data_center_breaker_restored": true}) == 6, "Após o reparo, o destino deve ser o data center.")
	SaveGame.save_global_state("hall_quest_01", {"elevator_third_floor_unlocked": true})
	var trigger := SceneTrigger.new()
	trigger.body_p = player
	trigger.andar_atual = 2
	var panel := preload("res://Objects/painel_elevador.tscn").instantiate()
	panel.scene_trigger = trigger
	add_child(panel)
	panel.show()
	panel._process(0.0)
	await get_tree().process_frame
	_expect(panel.mission_floor == 3, "O botão do escritório deve receber a borda.")
	_expect(is_instance_valid(panel.mission_border), "O destaque deve estar visível.")
	if is_instance_valid(panel.mission_border):
		_expect(panel.mission_border.size == panel.get_node("andar3").size, "A borda deve ocupar o botão inteiro.")
	panel.mission_hint_enabled = false
	panel._process(0.0)
	_expect(panel.mission_border == null, "Durante a viagem, a borda deve desaparecer.")
	panel.queue_free()
	trigger.free()
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_row(quest: QuestMissionUI, first_item: String, completed: bool, context: String) -> void:
	var expected_text := "ENCONTRE UM NOTEBOOK" if first_item == "cabo" else "ENCONTRE UM CABO"
	_expect((quest.rows[3].get_node("Label3") as Label).text == expected_text, context + ": deve pedir o item correto.")
	_expect(quest._completed_rows[3] == completed, context + ": a conclusão deve corresponder ao item mostrado.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
