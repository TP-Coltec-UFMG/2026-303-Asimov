class_name QuestMissionUI
extends CanvasLayer

@onready var rows: Array[HBoxContainer] = [
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
]
@onready var markers: Array[AnimatedSprite2D] = [
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
]

var desired_visible: bool = false
var hidden_for_elevator: bool = false


func _enter_tree() -> void:
	if hidden_for_elevator:
		call_deferred("_restore_after_scene_change")


func _ready() -> void:
	rows[2].hide()
	rows[3].hide()
	rows[4].hide()
	rows[5].hide()
	rows[6].hide()
	rows[7].hide()
	rows[8].hide()
	rows[9].hide()
	rows[10].hide()
	rows[11].hide()
	hide()
	call_deferred("refresh_saved_state")


func set_panel_visible(value: bool) -> void:
	desired_visible = value
	visible = value and not get_tree().paused and not hidden_for_elevator


func hide_during_elevator() -> void:
	hidden_for_elevator = true
	hide()


func restore_after_elevator() -> void:
	hidden_for_elevator = false
	visible = desired_visible and not get_tree().paused


func hide_all_tasks() -> void:
	for row in rows:
		row.hide()
	set_panel_visible(false)


func _restore_after_scene_change() -> void:
	if is_inside_tree() and hidden_for_elevator:
		restore_after_elevator()


func set_task_visible(index: int, value: bool) -> void:
	if index >= 0 and index < rows.size():
		rows[index].visible = value


func set_task_text(index: int, value: String) -> void:
	if index >= 0 and index < rows.size():
		(rows[index].get_node("Label3") as Label).text = value


func set_task_completed(index: int, completed: bool, animate: bool = false) -> void:
	if index < 0 or index >= markers.size():
		return
	var marker := markers[index]
	marker.stop()
	marker.animation = &"default"
	if completed and animate:
		marker.play(&"default")
	elif completed:
		marker.frame = maxi(marker.sprite_frames.get_frame_count(&"default") - 1, 0)
	else:
		marker.frame = 0
		marker.frame_progress = 0.0


func complete_third_floor() -> void:
	show_only_third_floor_task(true, true)


func show_only_third_floor_task(completed: bool, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "IR PARA O TERCEIRO ANDAR")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func show_talk_to_npc_task(completed: bool, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "FALE COM O NPC")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func show_find_boss_room_access_task(completed: bool = false, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "ENCONTRE UMA FORMA DE\nENTRAR NA SALA DO CHEFE")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func show_boss_room_and_cable_tasks(
	boss_room_completed: bool = false,
	cable_completed: bool = false,
	animate_cable: bool = false,
	hack_ready: bool = false,
	hack_completed: bool = false,
	show_boss_card_task: bool = false,
	boss_card_completed: bool = false,
	find_laptop: bool = false
) -> void:
	for index in range(rows.size()):
		set_task_visible(
			index,
			index == 2
			or index == 3
			or (index == 4 and hack_ready)
			or (index == 5 and show_boss_card_task)
		)
	set_task_text(2, "ENCONTRE UMA FORMA DE\nENTRAR NA SALA DO CHEFE")
	set_task_completed(2, boss_room_completed)
	set_task_text(3, "ENCONTRE UM NOTEBOOK" if find_laptop else "ENCONTRE UM CABO")
	set_task_completed(3, cable_completed, animate_cable)
	set_task_text(4, "HACKEIE A SALA DO CHEFE!")
	set_task_completed(4, hack_completed)
	set_task_text(5, "PEGUE O CARTÃO DO CHEFE")
	set_task_completed(5, boss_card_completed)
	set_panel_visible(true)


func show_find_hacking_item_task(
	find_laptop: bool,
	completed: bool = false,
	animate: bool = false
) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 3)
	set_task_text(3, "ENCONTRE UM NOTEBOOK" if find_laptop else "ENCONTRE UM CABO")
	set_task_completed(3, completed, animate)
	set_panel_visible(true)


func show_go_to_sixth_floor_task(completed: bool = false, animate: bool = false) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 6)
	set_task_text(6, "VÁ PARA O SEXTO ANDAR")
	set_task_completed(6, completed, animate)
	set_panel_visible(true)


func show_data_center_card_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(7, "ENTREGUE O CARTÃO AO CIENTISTA", completed, animate)


func show_find_flashlight_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(8, "ENCONTRE UMA LANTERNA", completed, animate)


func show_restore_breaker_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(9, "LIGUE O DISJUNTOR", completed, animate)


func show_go_to_fourth_floor_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(10, "VÁ PARA O QUARTO ANDAR", completed, animate)


func show_decrypt_data_center_access_task(
	completed: bool = false,
	animate: bool = false
) -> void:
	_show_single_data_center_task(11, "DESCRIPTOGRAFE O ACESSO", completed, animate)


func show_data_center_power_tasks(
	flashlight_completed: bool = false,
	fourth_floor_completed: bool = false,
	breaker_completed: bool = false,
	animate_fourth_floor: bool = false
) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 6 or index == 8 or index == 9 or index == 10)
	set_task_text(6, "VÁ PARA O SEXTO ANDAR")
	set_task_completed(6, true)
	set_task_text(8, "ENCONTRE UMA LANTERNA")
	set_task_completed(8, flashlight_completed)
	set_task_text(9, "LIGUE O DISJUNTOR")
	set_task_completed(9, breaker_completed)
	set_task_text(10, "VÁ PARA O QUARTO ANDAR")
	set_task_completed(10, fourth_floor_completed, animate_fourth_floor)
	set_panel_visible(true)


func _show_single_data_center_task(
	index: int,
	text: String,
	completed: bool,
	animate: bool
) -> void:
	for row_index in range(rows.size()):
		set_task_visible(row_index, row_index == index)
	set_task_text(index, text)
	set_task_completed(index, completed, animate)
	set_panel_visible(true)


func refresh_saved_state() -> void:
	var current_player := get_parent() as Player
	var state: Dictionary = SaveGame.office_mission_state(current_player)
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
	var tools_floor_task_active := bool(state.get("data_center_tools_floor_task_active", false))
	var tools_floor_task_completed := bool(state.get("data_center_tools_floor_task_completed", false))
	var breaker_completed := bool(state.get("data_center_breaker_restored", false))
	var decryption_task_active := bool(state.get("data_center_access_decryption_task_active", false))
	var flashlight_completed := bool(state.get("data_center_flashlight_collected", false)) or (
		current_player != null
		and current_player.inventory.get_item_on_inventary("lanterna")
	)
	var hack_ready := bool(state.get("office_hack_boss_room_ready", false)) or (
		laptop_collected and cable_collected
	)
	if decryption_task_active:
		show_decrypt_data_center_access_task(false)
	elif tools_floor_task_active:
		show_data_center_power_tasks(
			flashlight_completed,
			tools_floor_task_completed,
			breaker_completed
		)
	elif data_center_task_active:
		show_go_to_sixth_floor_task(data_center_task_completed)
	elif data_center_task_pending:
		hide_all_tasks()
	elif unlocked:
		set_task_completed(0, true)
		set_task_completed(1, true)
		set_task_completed(2, true)
		if laptop_collected:
			show_boss_room_and_cable_tasks(
				boss_room_access_found,
				cable_collected,
				false,
				hack_ready,
				hack_completed,
				boss_room_visited,
				boss_card_collected,
				find_laptop
			)
		elif dialog_finished:
			show_find_boss_room_access_task(boss_room_access_found)
		elif npc_ready:
			show_talk_to_npc_task(false)
		else:
			show_only_third_floor_task(arrived)
	else:
		set_task_visible(3, false)
		set_task_visible(4, false)
		set_task_visible(5, false)
		set_task_visible(6, false)
		set_task_visible(11, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED and is_node_ready() and not hidden_for_elevator:
		restore_after_elevator()
