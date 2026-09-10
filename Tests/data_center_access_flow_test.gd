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
	SaveGame.checkpoint_world_state = {}
	SaveGame.restore_checkpoint_pending = false
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
		_fail("O NPC terminou fora do ponto configurado na cena: %s != %s" % [npc.global_position, (scene.get_node("NPCs/AcessoForteNPCDestino") as Marker2D).global_position])
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
	if not bool(state.get("data_center_rfid_inspection_task_active", false)):
		_fail("A tarefa de verificar o leitor RFID não foi salva.")
		return
	if quest == null or not quest.rows[12].visible or quest.rows[11].visible:
		_fail("A tarefa de verificar o leitor RFID não apareceu corretamente.")
		return
	if get_tree().current_scene.scene_file_path != DATA_CENTER_SCENE:
		_fail("A porta abriu depois da segunda leitura recusada.")
		return

	await _inspect_reader(controller, trigger, player)
	state = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_rfid_wires_task_active", false)):
		_fail("A inspeção não revelou a tarefa de reconectar os cabos.")
		return
	if not quest.rows[11].visible or not quest.rows[12].visible:
		_fail("As duas tarefas do leitor RFID não apareceram juntas.")
		return
	var access_interactable := scene.get_node("SceneTrigger2/Interectable")
	if str(access_interactable.get("interact_name")) != "Consertar os fios":
		_fail("O leitor não exibiu a representação de conserto.")
		return
	if int(access_interactable.get("prompt_font_size")) != 10:
		_fail("A representação do leitor não recebeu o font_size menor.")
		return

	trigger.dentro_da_area = true
	trigger.body_p = player
	var interact_event := InputEventAction.new()
	interact_event.action = "interact"
	interact_event.pressed = true
	trigger._unhandled_input(interact_event)
	for _frame in 20:
		await get_tree().process_frame
		if _current_scene_path().ends_with("Minigame2/Main.tscn"):
			break
	if not _current_scene_path().ends_with("Minigame2/Main.tscn"):
		_fail("O minigame de reconexão não foi iniciado.")
		return
	var minigame: Variant = get_tree().current_scene
	var first_right: Dictionary = _matching_right(minigame, minigame.esquerda[0])
	await _click_minigame(minigame, minigame.esquerda[0].node.position)
	await _click_minigame(minigame, first_right.node.position)
	if minigame.quantidade_conectados != 1:
		_fail("O minigame não detectou o clique do mouse pelo Viewport.")
		return
	await _press_minigame_key(minigame, KEY_R)
	if minigame.quantidade_conectados != 0:
		_fail("O minigame não detectou a tecla R pelo Viewport.")
		return
	for left_entry in minigame.esquerda:
		var matching_right: Dictionary = _matching_right(minigame, left_entry)
		if matching_right.is_empty():
			_fail("O minigame gerou um conector sem par.")
			return
		await _click_minigame(minigame, left_entry.node.position)
		await _click_minigame(minigame, matching_right.node.position)
	for _frame in 180:
		await get_tree().process_frame
		if _current_scene_path() == DATA_CENTER_SCENE:
			break
	if _current_scene_path() != DATA_CENTER_SCENE:
		_fail("O minigame concluído não retornou ao data center.")
		return
	state = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_rfid_wires_repaired", false)):
		_fail("O conserto dos cabos não foi salvo.")
		return
	scene = get_tree().current_scene
	quest = player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest == null or not quest.rows[11].visible or not quest.rows[12].visible:
		_fail("O painel não restaurou as duas tarefas depois do minigame.")
		return
	if quest.markers[11].frame == 0:
		_fail("A tarefa de reconectar os cabos não voltou concluída.")
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
	if quest == null or not quest.rows[11].visible or not quest.rows[12].visible:
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


func _inspect_reader(
	controller: DataCenterIntroController,
	trigger: SceneTrigger,
	player: Player
) -> void:
	controller._on_access_requested(trigger)
	for _step in 12:
		await get_tree().process_frame
		if player.balao_de_pensamento.visible:
			player.balao_de_pensamento.pular_pensamento()
		if bool(SaveGame.office_mission_state(player).get("data_center_rfid_wires_task_active", false)):
			return


func _card_type(player: Player) -> int:
	var card := player.inventory.get_item_control("cartao")
	return int(card.get("tipo")) if card != null else 0


func _current_scene_path() -> String:
	var current_scene := get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""


func _matching_right(minigame: Variant, left_entry: Dictionary) -> Dictionary:
	for right_entry in minigame.direita:
		if int(right_entry.id) == int(left_entry.id):
			return right_entry
	return {}


func _click_minigame(minigame: Variant, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = minigame.to_global(position)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	minigame.get_viewport().push_input(event, true)
	await get_tree().process_frame


func _press_minigame_key(minigame: Variant, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	minigame.get_viewport().push_input(event, true)
	await get_tree().process_frame


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
