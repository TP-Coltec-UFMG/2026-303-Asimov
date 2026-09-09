class_name DataCenterIntroController
extends Node

const CARD_DIALOG_ID: String = "data_center:card_delivery"
const POWER_DIALOG_ID: String = "data_center:power_failure"
const FLASHLIGHT_ITEM_ID: String = "lanterna"
const POWER_OFF_COLOR := Color("#020202")
const POWER_FLICKER_COUNT: int = 3
const POWER_FLICKER_OFF_TIME: float = 0.12
const POWER_FLICKER_ON_TIME: float = 0.10

var player: Player
var recipient: Node2D
var regular_lights: Array[PointLight2D] = []
var regular_light_visibility: Dictionary = {}
var normal_canvas_color: Color = Color.WHITE
var power_sequence_running: bool = false


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	var scene := get_parent() as BaseScene
	if scene == null or not is_instance_valid(scene.player):
		push_error("DataCenterIntroController não encontrou o Player.")
		return
	player = scene.player
	recipient = get_node_or_null("../NPCs/NPC1") as Node2D
	if recipient == null:
		push_error("DataCenterIntroController precisa de NPCs/NPC1.")
		return
	_prepare_recipient()
	_cache_regular_lights()
	_connect_world_objects()
	if not DialogManager.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.dialog_finished.connect(_on_dialog_finished)
	_restore_progress()


func _prepare_recipient() -> void:
	recipient.set("dialog_enabled", false)
	recipient.set("interaction_override", true)
	recipient.set("interaction_prompt", "ESPAÇO: ENTREGAR CARTÃO")
	if recipient.has_signal(&"interaction_requested") and not recipient.is_connected(&"interaction_requested", _on_recipient_interaction_requested):
		recipient.connect(&"interaction_requested", _on_recipient_interaction_requested)


func _restore_progress() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_breaker_restored", false)):
		MusicController._stop_power_outage_audio()
		_restore_power_visuals()
		_show_power_tasks(true, true, true)
		return
	if bool(state.get("data_center_power_outage", false)):
		_apply_power_outage_visuals()
		_set_power_outage_music(true)
		if bool(state.get("data_center_power_dialog_finished", false)):
			_show_power_tasks(
				player.inventory.get_item_on_inventary(FLASHLIGHT_ITEM_ID),
				bool(state.get("data_center_tools_floor_task_completed", false))
			)
		else:
			call_deferred("_start_power_failure_dialog")
		return
	if bool(state.get("data_center_card_delivered", false)):
		if bool(state.get("data_center_card_dialog_finished", false)):
			call_deferred("_begin_power_failure")
		else:
			call_deferred("_start_card_dialog")
		return
	_show_card_task(false)


func _on_recipient_interaction_requested(_npc: Node2D) -> void:
	if not _is_current_scene() or DialogManager.is_showing_dialog:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_card_delivered", false)):
		return
	if not _has_boss_card():
		player.balao_de_pensamento.enfileirar(
			"data_center:need_boss_card",
			"Preciso entregar o cartão do chefe."
		)
		return
	_deliver_boss_card()


func _deliver_boss_card() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_card_delivered"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	player.inventory.remove_item("cartao")
	player.reset_sprite_player()
	_show_card_task(true, true)
	_save_checkpoint()
	_start_card_dialog()


func _start_card_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Alex: Encontrei o chefe, mas ele fugiu. A sala estava vazia.",
		"Cientista: Fugiu? Isso explica muita coisa... A IA está quebrando todas as leis de Asimov.",
		"Alex: Então não sobrou ninguém para impedir isso?",
		"Cientista: Estamos tentando conter os sistemas, mas ela está tomando o prédio inteiro."
	], CARD_DIALOG_ID)


func _on_dialog_finished(dialog_id: String) -> void:
	if not _is_current_scene():
		return
	if dialog_id == CARD_DIALOG_ID:
		var state: Dictionary = SaveGame.office_mission_state(player)
		state["data_center_card_dialog_finished"] = true
		SaveGame.save_global_state("hall_quest_01", state)
		_save_checkpoint()
		_begin_power_failure()
	elif dialog_id == POWER_DIALOG_ID:
		var state: Dictionary = SaveGame.office_mission_state(player)
		state["data_center_power_dialog_finished"] = true
		state["data_center_tools_floor_task_active"] = true
		SaveGame.save_global_state("hall_quest_01", state)
		_show_power_tasks(
			player.inventory.get_item_on_inventary(FLASHLIGHT_ITEM_ID),
			false
		)
		_save_checkpoint()


func _begin_power_failure() -> void:
	if power_sequence_running or not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_power_outage", false)):
		_apply_power_outage_visuals()
		_start_power_failure_dialog()
		return
	power_sequence_running = true
	for _index in POWER_FLICKER_COUNT:
		_set_regular_lights_visible(false)
		await get_tree().create_timer(POWER_FLICKER_OFF_TIME, false).timeout
		if not _is_current_scene():
			return
		_set_regular_lights_visible(true)
		await get_tree().create_timer(POWER_FLICKER_ON_TIME, false).timeout
		if not _is_current_scene():
			return
	state = SaveGame.office_mission_state(player)
	state["data_center_power_outage"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_apply_power_outage_visuals()
	_reduce_remaining_time_once()
	_set_power_outage_music(true)
	power_sequence_running = false
	_save_checkpoint()
	_start_power_failure_dialog()


func _start_power_failure_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Cientista: A IA está drenando a energia do prédio! O disjuntor desarmou!",
		"Alex: Eu posso ligar o disjuntor de novo.",
		"Cientista: O disjuntor fica no andar das ferramentas, no 4º andar. Lá não há luzes de emergência.",
		"Cientista: Você vai precisar de uma lanterna. Vi uma na mesa de alguém."
	], POWER_DIALOG_ID)


func _cache_regular_lights() -> void:
	var lighting := get_node_or_null("../Iluminacao")
	if lighting == null:
		return
	var canvas_modulate := lighting.get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas_modulate != null:
		normal_canvas_color = canvas_modulate.color
	for node in lighting.find_children("*", "PointLight2D", true, false):
		var light := node as PointLight2D
		if light != null and not _belongs_to_emergency_light(light, lighting):
			regular_lights.append(light)
			regular_light_visibility[light] = light.visible
	_turn_off_emergency_lights(lighting)


func _belongs_to_emergency_light(node: Node, lighting: Node) -> bool:
	var current: Node = node
	while current != null and current != lighting:
		if current.has_method("liga_luz") or current.has_method("desliga_luz"):
			return true
		current = current.get_parent()
	return false


func _set_regular_lights_visible(value: bool) -> void:
	for light in regular_lights:
		if is_instance_valid(light):
			light.visible = value and bool(regular_light_visibility.get(light, true))


func _apply_power_outage_visuals() -> void:
	_set_regular_lights_visible(false)
	var lighting := get_node_or_null("../Iluminacao")
	if lighting == null:
		return
	var canvas_modulate := lighting.get_node_or_null("CanvasModulate") as CanvasModulate
	if canvas_modulate != null:
		canvas_modulate.color = POWER_OFF_COLOR
	_turn_on_emergency_lights(lighting)


func _turn_off_emergency_lights(lighting: Node) -> void:
	for node in lighting.find_children("*", "", true, false):
		if node.has_method("desliga_luz"):
			node.call("desliga_luz")


func _turn_on_emergency_lights(lighting: Node) -> void:
	for node in lighting.find_children("*", "", true, false):
		if node.has_method("liga_luz"):
			node.call("liga_luz")


func _reduce_remaining_time_once() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_time_reduced", false)):
		return
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	if timer == null or not timer.has_method("get_tempo_restante"):
		push_warning("Temporizador não encontrado para reduzir o tempo do data center.")
		return
	var remaining := float(timer.call("get_tempo_restante"))
	timer.call("carregar_tempo_restante", remaining * 0.5)
	state["data_center_time_reduced"] = true
	SaveGame.save_global_state("hall_quest_01", state)


func _connect_world_objects() -> void:
	for pickup in get_tree().get_nodes_in_group("pickup_component"):
		_connect_pickup(pickup)
	for node in get_tree().get_nodes_in_group("dijuntor"):
		_connect_breaker(node)
	# Objetos existentes não precisam de grupo: detectamos pelo tipo do item
	# para que a lanterna adicionada pelo editor já funcione automaticamente.
	for node in get_parent().find_children("*", "PickupComponent", true, false):
		_connect_pickup(node)
	for node in get_parent().find_children("*", "", true, false):
		if node.has_method("interagir_dijuntor"):
			_connect_breaker(node)


func _connect_pickup(node: Node) -> void:
	if node == null or str(node.get("item_id")) != FLASHLIGHT_ITEM_ID:
		return
	if node.has_signal(&"interagiu") and not node.is_connected(&"interagiu", _on_flashlight_collected):
		node.connect(&"interagiu", _on_flashlight_collected)


func _connect_breaker(node: Node) -> void:
	var pickup := node.get_node_or_null("PickupComponent")
	if pickup != null and pickup.has_signal(&"interagiu") and not pickup.is_connected(&"interagiu", _on_breaker_interacted):
		pickup.connect(&"interagiu", _on_breaker_interacted.bind(node))


func _on_flashlight_collected() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_power_dialog_finished", false)):
		return
	state["data_center_flashlight_collected"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_show_power_tasks(true, bool(state.get("data_center_tools_floor_task_completed", false)))
	_save_checkpoint()


func _on_breaker_interacted(breaker: Node) -> void:
	await get_tree().process_frame
	if not _is_current_scene() or not bool(breaker.get("ligado")):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_power_outage", false)) or bool(state.get("data_center_breaker_restored", false)):
		return
	if not player.inventory.get_item_on_inventary(FLASHLIGHT_ITEM_ID):
		return
	state["data_center_breaker_restored"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_restore_remaining_time_once()
	_restore_power_visuals()
	_show_power_tasks(
		true,
		bool(state.get("data_center_tools_floor_task_completed", false)),
		true
	)
	_set_power_outage_music(false)
	_save_checkpoint()


func _restore_remaining_time_once() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_time_restored", false)):
		return
	var timer := get_tree().get_first_node_in_group("temporizador_jogo")
	if timer == null or not timer.has_method("get_tempo_restante"):
		return
	var remaining := float(timer.call("get_tempo_restante"))
	timer.call("carregar_tempo_restante", remaining * 2.0)
	state["data_center_time_restored"] = true
	SaveGame.save_global_state("hall_quest_01", state)


func _restore_power_visuals() -> void:
	_set_regular_lights_visible(true)
	var lighting := get_node_or_null("../Iluminacao")
	if lighting != null:
		_turn_off_emergency_lights(lighting)


func _set_power_outage_music(active: bool) -> void:
	if active:
		MusicController._start_power_outage_audio()
		return
	MusicController._stop_power_outage_audio()


func _show_card_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_data_center_card_task(completed, animate)


func _has_boss_card() -> bool:
	if not player.inventory.get_item_on_inventary("cartao"):
		return false
	var card := player.inventory.get_item_control("cartao")
	return card != null and int(card.get("tipo")) == 3


func _show_flashlight_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_find_flashlight_task(completed, animate)


func _show_breaker_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_restore_breaker_task(completed, animate)


func _show_tools_floor_task(completed: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_go_to_fourth_floor_task(completed, animate)


func _show_power_tasks(
	flashlight_completed: bool,
	fourth_floor_completed: bool,
	breaker_completed: bool = false,
	animate_fourth_floor: bool = false
) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_data_center_power_tasks(
			flashlight_completed,
			fourth_floor_completed,
			breaker_completed,
			animate_fourth_floor
		)


func _save_checkpoint() -> void:
	if is_instance_valid(player) and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _is_current_scene() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(player)
		and get_tree().current_scene == get_parent()
	)
