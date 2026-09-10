extends Node

const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
const DATA_CENTER_SCENE := "res://Scenes/andar_data_center.tscn"


func _ready() -> void:
	await get_tree().process_frame
	SaveGame.save_data = {
		"__global": {
			"hall_quest_01": {
				"elevator_third_floor_unlocked": true,
				"office_data_center_task_active": true,
				"office_data_center_task_completed": true,
				"data_center_card_delivered": true,
				"data_center_card_dialog_finished": true,
				"data_center_power_outage": true,
				"data_center_power_dialog_finished": true,
				"data_center_tools_floor_task_active": true,
				"data_center_tools_floor_task_completed": true,
				"data_center_flashlight_collected": true,
				"data_center_breaker_restored": true,
				"data_center_time_reduced": true,
				"data_center_time_restored": true
			}
		}
	}
	# Evita que o teste escreva no save real do usuário.
	SaveGame.checkpoint_scene_path = "res://tests/isolated_checkpoint.tscn"
	SaveGame.checkpoint_pos = Vector2.ZERO
	SaveGame.state_player = {"isolated_test": true}
	var player := PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	scene_manager.player = player
	var data_center_packed := load(DATA_CENTER_SCENE) as PackedScene
	var data_center := data_center_packed.instantiate()
	get_tree().root.add_child(data_center)
	get_tree().current_scene = data_center
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null:
		_fail("O andar do data center não carregou.")
		return
	var controller := scene.get_node_or_null("DataCenterIntroController") as DataCenterIntroController
	var npc := scene.get_node_or_null("NPCs/NPC1") as Node2D
	var trigger := scene.get_node_or_null("SceneTrigger2") as SceneTrigger
	if controller == null or npc == null or trigger == null:
		_fail("A sequência não encontrou controller, NPC ou acesso forte.")
		return

	controller._start_access_plan_dialog()
	_finish_dialog()
	for _frame in 360:
		await get_tree().process_frame
		if bool(SaveGame.office_mission_state(player).get("data_center_access_npc_arrived", false)):
			break
	if not bool(SaveGame.office_mission_state(player).get("data_center_access_npc_arrived", false)):
		_fail("O NPC não concluiu o caminho até o acesso forte.")
		return
	if not npc.global_position.is_equal_approx((scene.get_node("NPCs/AcessoForteNPCDestino") as Marker2D).global_position):
		_fail("O NPC terminou fora do ponto configurado na cena.")
		return

	_finish_dialog()
	if _card_type(player) != 2:
		_fail("O cartão forte não foi entregue ao player.")
		return
	player.usando_cartao = true
	player.inventory.set_equipped_item("cartao")
	await _request_access(controller, trigger)
	if not bool(SaveGame.office_mission_state(player).get("data_center_access_strong_card_failed", false)):
		_fail("A primeira tentativa não foi registrada como bloqueada.")
		return
	_finish_dialog()
	if _card_type(player) != 3:
		_fail("O cartão do chefe não substituiu o cartão forte.")
		return
	var inventory_save := player.inventory.get_save_state()
	if not inventory_save.has("cartao") or str(inventory_save["cartao"].get("scene_path", "")) != "res://Objects/cartao_chefe.tscn":
		_fail("O cartão entregue pelo NPC não entrou no snapshot do inventário.")
		return
	player.usando_cartao = true
	player.inventory.set_equipped_item("cartao")
	await _request_access(controller, trigger)
	_finish_dialog()

	var state := SaveGame.office_mission_state(player)
	var quest := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if not bool(state.get("data_center_access_decryption_task_active", false)):
		_fail("A tarefa de descriptografar não foi salva.")
		return
	if quest == null or not quest.rows[11].visible:
		_fail("A tarefa de descriptografar não apareceu no painel.")
		return
	if get_tree().current_scene.scene_file_path != DATA_CENTER_SCENE:
		_fail("A porta abriu antes do minigame de descriptografia.")
		return

	# Reentra no andar com o mesmo player para validar a retomada do save.
	scene.remove_child(player)
	scene_manager.player = player
	get_tree().current_scene = null
	scene.queue_free()
	await get_tree().process_frame
	var reloaded_scene := data_center_packed.instantiate()
	get_tree().root.add_child(reloaded_scene)
	get_tree().current_scene = reloaded_scene
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var reloaded_npc := reloaded_scene.get_node("NPCs/NPC1") as Node2D
	var reloaded_destination := reloaded_scene.get_node("NPCs/AcessoForteNPCDestino") as Marker2D
	if not reloaded_npc.global_position.is_equal_approx(reloaded_destination.global_position):
		_fail("O save não restaurou o NPC junto ao acesso forte.")
		return
	if _card_type(player) != 3:
		_fail("O save não preservou o cartão do chefe entregue pelo NPC.")
		return
	quest = player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest == null or not quest.rows[11].visible:
		_fail("O save não restaurou a última tarefa da sequência.")
		return
	print("DATA_CENTER_ACCESS_FLOW_OK")
	get_tree().quit(0)


func _finish_dialog() -> void:
	if not DialogManager.is_showing_dialog:
		return
	var box: Node = DialogManager.dialog_box
	if box != null:
		box.queue_free()
	DialogManager._on_dialog_finished()


func _request_access(controller: DataCenterIntroController, trigger: SceneTrigger) -> void:
	controller._on_access_requested(trigger)
	await get_tree().process_frame
	var denied_sound := trigger.get_node("Aceso negado") as AudioStreamPlayer2D
	denied_sound.finished.emit()
	await get_tree().process_frame


func _card_type(player: Player) -> int:
	var card := player.inventory.get_item_control("cartao")
	return int(card.get("tipo")) if card != null else 0


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
