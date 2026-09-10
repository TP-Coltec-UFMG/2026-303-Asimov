class_name DataCenterIntroController
extends Node

const CARD_DIALOG_ID: String = "data_center:card_delivery"
const POWER_DIALOG_ID: String = "data_center:power_failure"
const ACCESS_PLAN_DIALOG_ID: String = "data_center:access_plan"
const STRONG_CARD_DIALOG_ID: String = "data_center:strong_card_handoff"
const STRONG_DENIED_DIALOG_ID: String = "data_center:strong_card_denied"
const BOSS_DENIED_DIALOG_ID: String = "data_center:boss_card_denied"
const FLASHLIGHT_ITEM_ID: String = "lanterna"
const CARD_ITEM_ID: String = "cartao"
const STRONG_CARD_TYPE: int = 2
const BOSS_CARD_TYPE: int = 3
const POWER_OFF_COLOR := Color("#020202")
const POWER_FLICKER_COUNT: int = 3
const POWER_FLICKER_OFF_TIME: float = 0.12
const POWER_FLICKER_ON_TIME: float = 0.10

var player: Player
var recipient: Node2D
var access_trigger: SceneTrigger
var access_path: NPCPath
var access_destination: Marker2D
var strong_story_card: Node2D
var boss_story_card: Node2D
var regular_lights: Array[PointLight2D] = []
var regular_light_visibility: Dictionary = {}
var normal_canvas_color: Color = Color.WHITE
var power_sequence_running: bool = false
var access_sequence_busy: bool = false


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	var scene := get_parent() as BaseScene
	if scene == null or not is_instance_valid(scene.player):
		push_error("DataCenterIntroController não encontrou o Player.")
		return
	player = scene.player
	recipient = get_node_or_null("../NPCs/NPC1") as Node2D
	access_trigger = get_node_or_null("../SceneTrigger2") as SceneTrigger
	access_path = get_node_or_null("../NPCs/NPC1/CaminhoAteAcessoForte") as NPCPath
	access_destination = get_node_or_null("../NPCs/AcessoForteNPCDestino") as Marker2D
	strong_story_card = get_node_or_null("../NPCs/NPC1/CartaoForteDaHistoria") as Node2D
	boss_story_card = get_node_or_null("../NPCs/NPC1/CartaoChefeDaHistoria") as Node2D
	if recipient == null:
		push_error("DataCenterIntroController precisa de NPCs/NPC1.")
		return
	if access_trigger == null or access_path == null or access_destination == null:
		push_error("DataCenterIntroController precisa do acesso forte e do caminho do NPC.")
		return
	if strong_story_card == null or boss_story_card == null:
		push_error("Os dois cartões da história precisam existir como filhos do NPC1.")
		return
	_prepare_story_card(strong_story_card)
	_prepare_story_card(boss_story_card)
	_prepare_recipient()
	_cache_regular_lights()
	_connect_world_objects()
	if not DialogManager.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.dialog_finished.connect(_on_dialog_finished)
	if not recipient.is_connected(&"path_completed", _on_recipient_path_completed):
		recipient.connect(&"path_completed", _on_recipient_path_completed)
	if not access_trigger.access_requested.is_connected(_on_access_requested):
		access_trigger.access_requested.connect(_on_access_requested)
	_restore_progress()


func _prepare_story_card(card: Node2D) -> void:
	card.hide()
	var interactable := card.get_node_or_null("Interectable") as Area2D
	if interactable != null:
		interactable.monitoring = false
		interactable.monitorable = false
		interactable.set("is_interactable", false)


func _prepare_recipient() -> void:
	recipient.set("dialog_enabled", false)
	_set_recipient_interaction(true, "ESPAÇO: ENTREGAR CARTÃO")


func _set_recipient_interaction(enabled: bool, prompt: String = "ESPAÇO: FALAR") -> void:
	if recipient.has_method("configure_interaction_override"):
		recipient.call("configure_interaction_override", enabled, prompt)
	else:
		recipient.set("interaction_override", enabled)
		recipient.set("interaction_prompt", prompt)
	if enabled and recipient.has_signal(&"interaction_requested") and not recipient.is_connected(&"interaction_requested", _on_recipient_interaction_requested):
		recipient.connect(&"interaction_requested", _on_recipient_interaction_requested)


func _restore_progress() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_breaker_restored", false)):
		MusicController._stop_power_outage_audio()
		_restore_power_visuals()
		_restore_access_progress(state)
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


func _restore_access_progress(state: Dictionary) -> void:
	var rfid_progress_active := (
		bool(state.get("data_center_rfid_inspection_task_active", false))
		or bool(state.get("data_center_rfid_wires_task_active", false))
		or bool(state.get("data_center_rfid_wires_repaired", false))
	)
	if bool(state.get("data_center_access_decryption_task_active", false)) and not (
		rfid_progress_active
	):
		state.erase("data_center_access_decryption_task_active")
		state["data_center_rfid_inspection_task_active"] = true
		rfid_progress_active = true
		SaveGame.save_global_state("hall_quest_01", state)
	if bool(state.get("data_center_access_npc_arrived", false)) or rfid_progress_active:
		_place_recipient_at_access()
	if bool(state.get("data_center_rfid_wires_repaired", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		_set_access_prompt("Verificar leitura RFID")
		_show_rfid_repair_tasks(true)
		player.balao_de_pensamento.enfileirar(
			"data_center:wires_repaired_return",
			"Fios no lugar. Agora posso verificar a leitura RFID."
		)
		if not bool(state.get("data_center_rfid_repair_checkpointed", false)):
			state["data_center_rfid_repair_checkpointed"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			call_deferred("_save_checkpoint")
		return
	if bool(state.get("data_center_rfid_wires_task_active", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		_set_access_prompt("Consertar os fios")
		_show_rfid_repair_tasks(false)
		return
	if bool(state.get("data_center_rfid_inspection_task_active", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		_set_access_prompt("Verificar leitor RFID")
		_show_rfid_reader_task()
		return
	_show_power_tasks(true, true, true)
	if bool(state.get("data_center_access_boss_card_given", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		_set_access_prompt("Testar cartão do chefe")
		if bool(state.get("data_center_access_boss_card_failed", false)):
			call_deferred("_start_boss_denied_dialog")
		return
	if bool(state.get("data_center_access_strong_card_failed", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(STRONG_CARD_TYPE)
		call_deferred("_start_strong_denied_dialog")
		return
	if bool(state.get("data_center_access_strong_card_given", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(STRONG_CARD_TYPE)
		_set_access_prompt("Testar cartão forte")
		return
	if bool(state.get("data_center_access_npc_arrived", false)):
		_set_recipient_interaction(false)
		call_deferred("_start_strong_card_dialog")
		return
	if bool(state.get("data_center_access_npc_moving", false)):
		_set_recipient_interaction(false)
		var restored_path_active := bool(recipient.get("checkpoint_restored")) and not bool(recipient.get("path_finished"))
		if not restored_path_active:
			recipient.call("start_path", access_path)
		return
	if bool(state.get("data_center_access_plan_finished", false)):
		_begin_recipient_walk()
		return
	_set_recipient_interaction(true, "ESPAÇO: FALAR")
	player.balao_de_pensamento.enfileirar(
		"data_center:return_after_breaker",
		"A energia voltou. Preciso falar com o cientista."
	)


func _on_recipient_interaction_requested(_npc: Node2D) -> void:
	if not _is_current_scene() or DialogManager.is_showing_dialog:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_breaker_restored", false)):
		if not bool(state.get("data_center_access_plan_finished", false)):
			_start_access_plan_dialog()
		return
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
	player.inventory.remove_item(CARD_ITEM_ID)
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


func _start_access_plan_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	_set_recipient_interaction(false)
	DialogManager.start_dialog([
		"Cientista: A energia estabilizou. Agora precisamos alcançar o núcleo da IA.",
		"Cientista: Ele fica na área restrita deste andar. Venha, vou mostrar a entrada.",
		"Alex: Certo. Depois do que ela fez com a energia, não podemos perder mais tempo."
	], ACCESS_PLAN_DIALOG_ID)


func _start_strong_card_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Cientista: Esta é a entrada. O acesso normal exige um cartão forte.",
		"Cientista: Pegue. Passe-o no leitor.",
		"Alex: Vamos ver se ela deixou alguma porta aberta."
	], STRONG_CARD_DIALOG_ID)


func _start_strong_denied_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Alex: Bloqueado. Nem o cartão forte passou.",
		"Cientista: Estranho. Esse cartão abre a ala restrita em condições normais.",
		"Cientista: Ainda tenho o cartão do chefe que você me entregou. Pegue e tente com ele.",
		"Alex: Se este também falhar, a IA alterou as permissões."
	], STRONG_DENIED_DIALOG_ID)


func _start_boss_denied_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Alex: Também foi bloqueado.",
		"Cientista: Isso não faz sentido. Os dois cartões usam leitura RFID.",
		"Cientista: A IA controla a porta, mas não é possível que ela tenha apagado a leitura física dos cartões.",
		"Cientista: Verifique o leitor. Talvez o problema esteja no hardware.",
		"Alex: Certo. Vou abrir o painel e dar uma olhada."
	], BOSS_DENIED_DIALOG_ID)


func _on_dialog_finished(dialog_id: String) -> void:
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	match dialog_id:
		CARD_DIALOG_ID:
			state["data_center_card_dialog_finished"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			_save_checkpoint()
			_begin_power_failure()
		POWER_DIALOG_ID:
			state["data_center_power_dialog_finished"] = true
			state["data_center_tools_floor_task_active"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			_show_power_tasks(player.inventory.get_item_on_inventary(FLASHLIGHT_ITEM_ID), false)
			_save_checkpoint()
		ACCESS_PLAN_DIALOG_ID:
			state["data_center_access_plan_finished"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			_begin_recipient_walk()
		STRONG_CARD_DIALOG_ID:
			_give_strong_card()
		STRONG_DENIED_DIALOG_ID:
			_give_boss_card()
		BOSS_DENIED_DIALOG_ID:
			state["data_center_access_boss_dialog_finished"] = true
			state.erase("data_center_access_decryption_task_active")
			state["data_center_rfid_inspection_task_active"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			_set_access_prompt("Verificar leitor RFID")
			_show_rfid_reader_task()
			player.balao_de_pensamento.enfileirar(
				"data_center:inspect_rfid_reader",
				"RFID... preciso descobrir o que aconteceu com esse leitor."
			)
			_save_checkpoint()


func _begin_recipient_walk() -> void:
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_access_npc_arrived", false)):
		_start_strong_card_dialog()
		return
	state["data_center_access_npc_moving"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_recipient_interaction(false)
	recipient.call("start_path", access_path)
	_save_checkpoint()


func _on_recipient_path_completed(finished_path: NPCPath) -> void:
	if finished_path != access_path or not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_access_npc_moving"] = false
	state["data_center_access_npc_arrived"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_start_strong_card_dialog()


func _place_recipient_at_access() -> void:
	recipient.global_position = access_destination.global_position
	if recipient.has_method("stop_current_path"):
		recipient.call("stop_current_path")


func _give_strong_card() -> void:
	if not _give_story_card(STRONG_CARD_TYPE):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_access_strong_card_given"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_access_prompt("Testar cartão forte")
	player.balao_de_pensamento.enfileirar(
		"data_center:strong_card_received",
		"Cartão forte. Preciso equipá-lo e testar o leitor."
	)
	_save_checkpoint()


func _give_boss_card() -> void:
	player.reset_sprite_player()
	player.inventory.remove_item(CARD_ITEM_ID)
	if not _give_story_card(BOSS_CARD_TYPE):
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_access_strong_dialog_finished"] = true
	state["data_center_access_boss_card_given"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_access_prompt("Testar cartão do chefe")
	player.balao_de_pensamento.enfileirar(
		"data_center:boss_card_received",
		"Agora é a vez do cartão do chefe."
	)
	_save_checkpoint()


func _give_story_card(card_type: int) -> bool:
	var current_card := player.inventory.get_item_control(CARD_ITEM_ID)
	if current_card != null and int(current_card.get("tipo")) == card_type:
		return true
	var story_card := strong_story_card if card_type == STRONG_CARD_TYPE else boss_story_card
	if story_card == null or not is_instance_valid(story_card):
		push_error("Cartão da história indisponível para entrega.")
		return false
	if current_card != null:
		player.reset_sprite_player()
		player.inventory.remove_item(CARD_ITEM_ID)
	if not player.inventory.add_existing_item(CARD_ITEM_ID, story_card, true):
		push_error("Não foi possível transferir o cartão existente para o inventário.")
		return false
	return true


func _ensure_story_card(card_type: int) -> void:
	if _current_card_type() == card_type:
		return
	_give_story_card(card_type)


func _current_card_type() -> int:
	var card := player.inventory.get_item_control(CARD_ITEM_ID)
	return int(card.get("tipo")) if card != null else 0


func _on_access_requested(_trigger: SceneTrigger) -> void:
	if access_sequence_busy or not _is_current_scene() or DialogManager.is_showing_dialog:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_breaker_restored", false)):
		player.balao_de_pensamento.enfileirar(
			"data_center:access_before_power",
			"Primeiro preciso resolver o problema da energia."
		)
		return
	if bool(state.get("data_center_rfid_wires_repaired", false)):
		player.balao_de_pensamento.enfileirar(
			"data_center:check_rfid_after_repair",
			"Os cabos estão prontos. Agora preciso verificar a leitura RFID."
		)
		return
	if bool(state.get("data_center_rfid_wires_task_active", false)):
		_start_wire_repair_minigame()
		return
	if bool(state.get("data_center_rfid_inspection_task_active", false)):
		await _inspect_rfid_reader()
		return
	if bool(state.get("data_center_access_boss_card_given", false)):
		if _current_card_type() != BOSS_CARD_TYPE or not player.usando_cartao:
			player.balao_de_pensamento.enfileirar(
				"data_center:equip_boss_card",
				"Preciso equipar o cartão do chefe."
			)
			return
		await _reject_boss_card()
		return
	if bool(state.get("data_center_access_strong_card_given", false)):
		if _current_card_type() != STRONG_CARD_TYPE or not player.usando_cartao:
			player.balao_de_pensamento.enfileirar(
				"data_center:equip_strong_card",
				"Preciso equipar o cartão forte."
			)
			return
		await _reject_strong_card()
		return
	player.balao_de_pensamento.enfileirar(
		"data_center:access_not_ready",
		"É esta porta. Preciso seguir o plano do cientista."
	)


func _reject_strong_card() -> void:
	access_sequence_busy = true
	await access_trigger.reproduzir_acesso_negado()
	access_sequence_busy = false
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_access_strong_card_failed", false)):
		return
	state["data_center_access_strong_card_failed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_start_strong_denied_dialog()


func _reject_boss_card() -> void:
	access_sequence_busy = true
	await access_trigger.reproduzir_acesso_negado()
	access_sequence_busy = false
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_access_boss_card_failed", false)):
		return
	state["data_center_access_boss_card_failed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	_start_boss_denied_dialog()


func _inspect_rfid_reader() -> void:
	access_sequence_busy = true
	await player.balao_de_pensamento.mostrar_texto(
		"O leitor ainda tem energia...",
		"data_center:rfid_reader_has_power"
	)
	if not _is_current_scene():
		return
	await player.balao_de_pensamento.mostrar_texto(
		"Achei o problema. Os cabos estão queimados.",
		"data_center:rfid_burned_wires"
	)
	if not _is_current_scene():
		return
	await player.balao_de_pensamento.mostrar_texto(
		"Preciso reconectá-los antes de testar os cartões de novo.",
		"data_center:rfid_reconnect_plan"
	)
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_rfid_inspection_task_active"] = false
	state["data_center_rfid_wires_task_active"] = true
	state["data_center_rfid_reading_task_active"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_access_prompt("Consertar os fios")
	_show_rfid_repair_tasks(false)
	_save_checkpoint()
	access_sequence_busy = false


func _start_wire_repair_minigame() -> void:
	if access_sequence_busy:
		return
	access_sequence_busy = true
	_save_checkpoint()
	Progresso.iniciar_reparo_leitor_rfid(player)


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
	_show_power_tasks(true, bool(state.get("data_center_tools_floor_task_completed", false)), true)
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
	return _current_card_type() == BOSS_CARD_TYPE


func _show_rfid_reader_task() -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_rfid_reader_task(false)


func _show_rfid_repair_tasks(wires_repaired: bool, animate: bool = false) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_rfid_repair_tasks(wires_repaired, false, animate)


func _set_access_prompt(text: String) -> void:
	var interactable := access_trigger.get_node_or_null("Interectable")
	if interactable != null:
		interactable.set("interact_name", text)


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
