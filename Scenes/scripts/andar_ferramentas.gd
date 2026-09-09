extends BaseScene


func _ready() -> void:
	super._ready()
	call_deferred("_configurar_missao_do_data_center")


func _configurar_missao_do_data_center() -> void:
	if not is_instance_valid(player):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_tools_floor_task_active", false)):
		var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
		if quest_ui != null:
			quest_ui.show_data_center_power_tasks(
				player.inventory.get_item_on_inventary("lanterna"),
				bool(state.get("data_center_tools_floor_task_completed", false)),
				bool(state.get("data_center_breaker_restored", false))
			)
	if bool(state.get("data_center_power_outage", false)) and not bool(state.get("data_center_breaker_restored", false)):
		var canvas_modulate := get_node_or_null("Iluminacao/CanvasModulate") as CanvasModulate
		if canvas_modulate != null:
			canvas_modulate.color = Color("#020202")
