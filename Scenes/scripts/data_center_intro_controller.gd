class_name DataCenterIntroController
extends Node

const CARD_DIALOG_ID: String = "data_center:card_delivery"
const POWER_DIALOG_ID: String = "data_center:power_failure"
const ACCESS_PLAN_DIALOG_ID: String = "data_center:access_plan"
const STRONG_CARD_DIALOG_ID: String = "data_center:strong_card_handoff"
const STRONG_DENIED_DIALOG_ID: String = "data_center:strong_card_denied"
const BOSS_DENIED_DIALOG_ID: String = "data_center:boss_card_denied"
const RETURN_DIALOG_ID: String = "data_center:return_after_breaker"
const FLASHLIGHT_ITEM_ID: String = "lanterna"
const CARD_ITEM_ID: String = "cartao"
const STRONG_CARD_TYPE: int = 2
const BOSS_CARD_TYPE: int = 3
const POWER_OFF_COLOR := Color("#020202")
const POWER_FLICKER_COUNT: int = 3
const POWER_FLICKER_OFF_TIME: float = 0.12
const POWER_FLICKER_ON_TIME: float = 0.10
const OUTAGE_AFTER_MIN_DELAY: float = 5.0
const OUTAGE_AFTER_MAX_DELAY: float = 22.0

@export_range(0.1, 30.0, 0.1) var rfid_verification_duration: float = 5.0
@export var rfid_thought_balloon_offset := Vector2(0.0, -17.0)

var player: Player
var recipient: Node2D
var access_trigger: SceneTrigger
var access_path: NPCPath
var access_destination: Marker2D
var strong_story_card: Node2D
var boss_story_card: Node2D
var rfid_verification_ui: Control
var rfid_verification_bar: ProgressBar
var rfid_verification_label: Label
var restricted_area_fade: ColorRect
var regular_lights: Array[PointLight2D] = []
var regular_light_visibility: Dictionary = {}
var normal_canvas_color: Color = Color.WHITE
var power_sequence_running: bool = false
var outage_timer: Timer
var access_sequence_busy: bool = false
var rfid_verification_running: bool = false
var rfid_verification_interrupted: bool = false
var rfid_verification_stage: String = ""
var rfid_progress_tween: Tween
var rfid_active_thought_ids: Array[String] = []
var rfid_player_physics_was_enabled: bool = true
var rfid_balloon_adjusted: bool = false
var rfid_balloon_original_position: Vector2
var rfid_balloon_original_speed: float = 0.0
var rfid_balloon_original_max_time: float = 0.0


func _ready() -> void:
	call_deferred("_initialize")


func _exit_tree() -> void:
	_suspend_dialog_for_return()
	_restore_player_after_rfid_verification()
	DialogManager.input_blocked = false


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
	rfid_verification_ui = get_node_or_null("../SceneTrigger2/RFIDVerification") as Control
	restricted_area_fade = get_node_or_null("../RestrictedAreaTransition/Black") as ColorRect
	if rfid_verification_ui != null:
		rfid_verification_bar = rfid_verification_ui.get_node_or_null("ProgressBar") as ProgressBar
		rfid_verification_label = rfid_verification_ui.get_node_or_null("Label") as Label
		_hide_rfid_verification()
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
	outage_timer = Timer.new()
	outage_timer.one_shot = true
	add_child(outage_timer)
	outage_timer.timeout.connect(_on_outage_timer_timeout)
	_cache_regular_lights()
	_connect_world_objects()
	if not DialogManager.dialog_finished.is_connected(_on_dialog_finished):
		DialogManager.dialog_finished.connect(_on_dialog_finished)
	if not DialogManager.dialog_line_started.is_connected(_on_dialog_line_started):
		DialogManager.dialog_line_started.connect(_on_dialog_line_started)
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
			_set_recipient_interaction(true, "ESPAÇO: FALAR")
			_show_power_talk_task()
		return
	if bool(state.get("data_center_card_delivered", false)):
		_ensure_outage_schedule(state)
		if str(state.get("data_center_outage_phase", "")) == "before" and bool(state.get("data_center_outage_pending", false)):
			_show_card_task(true)
			call_deferred("_begin_power_failure")
			return
		if bool(state.get("data_center_card_dialog_finished", false)):
			_restore_access_progress(state)
		else:
			_show_card_task(true)
			call_deferred("_start_card_dialog")
		_arm_outage_timer(state)
		return
	_show_card_task(false)


func _restore_access_progress(state: Dictionary) -> void:
	if _scientist_talk_pending(state):
		if (
			bool(state.get("data_center_access_npc_arrived", false))
			or bool(state.get("data_center_rfid_inspection_task_active", false))
			or bool(state.get("data_center_rfid_wires_task_active", false))
			or bool(state.get("data_center_rfid_wires_repaired", false))
			or bool(state.get("data_center_rfid_reader_rechecked", false))
			or bool(state.get("data_center_rfid_reading_checked", false))
		):
			_place_recipient_at_access()
		_set_access_interactable(false)
		_set_recipient_interaction(true, "ESPAÇO: FALAR")
		_show_power_talk_task()
		return
	# A barra usada após o reparo era uma checagem intermediária. Saves criados
	# antes desta correção não podem considerar a futura tarefa do minigame pronta.
	if (
		bool(state.get("data_center_rfid_reading_checked", false))
		and not bool(state.get("data_center_rfid_minigame_completed", false))
	):
		state["data_center_rfid_reading_checked"] = false
		state["data_center_rfid_reading_task_active"] = true
		state["data_center_rfid_reader_rechecked"] = true
		SaveGame.save_global_state("hall_quest_01", state)
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
	if bool(state.get("data_center_rfid_reading_checked", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		access_trigger.access_override = bool(state.get("data_center_outage_pending", false)) and not bool(state.get("data_center_breaker_restored", false))
		_set_access_prompt("Acessar área restrita")
		_set_access_interactable(true)
		_show_rfid_repair_tasks(true, true)
		if not bool(state.get("data_center_rfid_minigame_checkpointed", false)):
			state["data_center_rfid_minigame_checkpointed"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			call_deferred("_save_checkpoint")
		return
	if bool(state.get("data_center_rfid_reader_rechecked", false)):
		_set_recipient_interaction(false)
		_ensure_story_card(BOSS_CARD_TYPE)
		_set_access_prompt("Reprogramar cartão RFID")
		_set_access_interactable(true)
		_show_rfid_repair_tasks(true, false)
		return
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
	_show_access_intro_tasks(state)
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
			var paused_point := int(state.get("data_center_access_npc_paused_point", -1))
			if paused_point >= 0 and paused_point < (recipient.get("path_points") as Array).size():
				recipient.set("current_point", paused_point)
		state.erase("data_center_access_npc_paused_point")
		SaveGame.save_global_state("hall_quest_01", state)
		return
	if bool(state.get("data_center_access_plan_finished", false)):
		_begin_recipient_walk()
		return
	_set_recipient_interaction(true, "ESPAÇO: FALAR")
	_show_power_talk_task()


func _on_recipient_interaction_requested(_npc: Node2D) -> void:
	if not _is_current_scene() or DialogManager.is_showing_dialog:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not (state.get("data_center_power_dialog_snapshot", {}) as Dictionary).is_empty():
		_set_recipient_interaction(false)
		_resume_interrupted_dialog("data_center_power_dialog_snapshot")
		return
	if _power_is_out(state) and not bool(state.get("data_center_power_dialog_finished", false)):
		_set_recipient_interaction(false)
		_start_power_failure_dialog()
		return
	if power_sequence_running or _power_is_out(state):
		return
	if bool(state.get("data_center_card_delivered", false)):
		var interrupted: Dictionary = state.get("data_center_interrupted_dialog", {})
		if not interrupted.is_empty():
			_set_recipient_interaction(false)
			_resume_interrupted_dialog()
		elif not bool(state.get("data_center_card_dialog_finished", false)):
			_set_recipient_interaction(false)
			_start_card_dialog()
		elif not bool(state.get("data_center_access_plan_finished", false)):
			_start_access_plan_dialog()
		elif bool(state.get("data_center_access_resume_talk_needed", false)):
			_set_recipient_interaction(false)
			_start_return_dialog()
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
	_ensure_outage_schedule(state)
	SaveGame.save_global_state("hall_quest_01", state)
	player.inventory.remove_item(CARD_ITEM_ID)
	player.reset_sprite_player()
	_show_card_task(true, true)
	_save_checkpoint()
	if str(state.get("data_center_outage_phase", "")) == "before":
		_begin_power_failure()
	else:
		_start_card_dialog()
		_arm_outage_timer(state)


func _start_card_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Alex: Encontrei o chefe, mas ele fugiu. A sala estava vazia.",
		"Cientista: Fugiu? Isso explica muita coisa... A IA está quebrando todas as leis de Asimov.",
		"Alex: Então não sobrou ninguém para impedir isso?",
		"Cientista: Estamos tentando conter os sistemas, mas ela está tomando o prédio inteiro."
	], CARD_DIALOG_ID)


func _ensure_outage_schedule(state: Dictionary) -> void:
	if bool(state.get("data_center_power_outage", false)) or bool(state.get("data_center_breaker_restored", false)):
		return
	if bool(state.get("data_center_outage_pending", false)):
		if str(state.get("data_center_outage_phase", "")) == "during":
			if bool(state.get("data_center_access_plan_finished", false)):
				state["data_center_outage_phase"] = "after"
				state["data_center_outage_delay"] = randf_range(OUTAGE_AFTER_MIN_DELAY, OUTAGE_AFTER_MAX_DELAY)
				state["data_center_outage_due_unix"] = 0.0
			elif not state.has("data_center_outage_target_dialog"):
				# Saves da versão anterior tinham um temporizador no lugar da fala sorteada.
				state["data_center_outage_target_dialog"] = ACCESS_PLAN_DIALOG_ID if bool(state.get("data_center_card_dialog_finished", false)) else CARD_DIALOG_ID
				state["data_center_outage_target_line"] = 1
			SaveGame.save_global_state("hall_quest_01", state)
		return
	var phase: String = str(["before", "during", "after"][randi_range(0, 2)])
	state["data_center_outage_pending"] = true
	state["data_center_outage_phase"] = phase
	state["data_center_outage_delay"] = randf_range(OUTAGE_AFTER_MIN_DELAY, OUTAGE_AFTER_MAX_DELAY) if phase == "after" else 0.0
	state["data_center_outage_due_unix"] = 0.0
	if phase == "during":
		var target_dialog := CARD_DIALOG_ID if randi_range(0, 1) == 0 else ACCESS_PLAN_DIALOG_ID
		state["data_center_outage_target_dialog"] = target_dialog
		state["data_center_outage_target_line"] = randi_range(1, 3 if target_dialog == CARD_DIALOG_ID else 2)
	SaveGame.save_global_state("hall_quest_01", state)


func _arm_outage_timer(state: Dictionary) -> void:
	if outage_timer == null or not outage_timer.is_stopped():
		return
	if not bool(state.get("data_center_outage_pending", false)):
		return
	if str(state.get("data_center_outage_phase", "")) != "after" or not bool(state.get("data_center_access_plan_finished", false)):
		return
	var due_unix := float(state.get("data_center_outage_due_unix", 0.0))
	if due_unix <= 0.0:
		due_unix = Time.get_unix_time_from_system() + float(state.get("data_center_outage_delay", 5.0))
		state["data_center_outage_due_unix"] = due_unix
		SaveGame.save_global_state("hall_quest_01", state)
	outage_timer.start(maxf(due_unix - Time.get_unix_time_from_system(), 0.1))


func _on_dialog_line_started(dialog_id: String, index: int) -> void:
	if not _is_current_scene() or power_sequence_running:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not bool(state.get("data_center_outage_pending", false)) or str(state.get("data_center_outage_phase", "")) != "during":
		return
	if dialog_id == str(state.get("data_center_outage_target_dialog", "")) and index == int(state.get("data_center_outage_target_line", -1)):
		_begin_power_failure()


func _on_outage_timer_timeout() -> void:
	if not _is_current_scene():
		return
	var cooling_guide := get_parent().get_node_or_null("CoolingLocationGuide")
	if cooling_guide != null and bool(cooling_guide.get("cutscene_running")):
		outage_timer.start(0.5)
		return
	if rfid_verification_running:
		_interrupt_rfid_verification()
		_begin_power_failure()
		return
	if access_sequence_busy:
		outage_timer.start(0.5)
		return
	_begin_power_failure()


func _start_access_plan_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	_set_recipient_interaction(false)
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_breaker_restored", false)):
		DialogManager.start_dialog([
			"Cientista: A energia estabilizou. Agora precisamos alcançar o núcleo da IA.",
			"Cientista: Ele fica na área restrita deste andar. Venha, vou mostrar a entrada.",
			"Alex: Certo. Depois do que ela fez com a energia, não podemos perder mais tempo."
		], ACCESS_PLAN_DIALOG_ID)
	else:
		DialogManager.start_dialog([
			"Cientista: Precisamos alcançar o núcleo da IA antes que ela termine o plano.",
			"Cientista: A entrada fica na área restrita deste andar. Venha, vou mostrar.",
			"Alex: Certo. Vamos tentar abrir o data center."
		], ACCESS_PLAN_DIALOG_ID)


func _start_return_dialog() -> void:
	if DialogManager.is_showing_dialog or not _is_current_scene():
		return
	DialogManager.start_dialog([
		"Cientista: A energia voltou. Precisamos continuar de onde paramos.",
		"Alex: Certo. Vou continuar de onde parei."
	], RETURN_DIALOG_ID)


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
	var interrupted: Dictionary = state.get("data_center_interrupted_dialog", {})
	if dialog_id != POWER_DIALOG_ID and bool(state.get("data_center_breaker_restored", false)) and bool(state.get("data_center_return_task_completed", false)):
		state["data_center_scientist_followup_done"] = true
		SaveGame.save_global_state("hall_quest_01", state)
	if dialog_id == str(interrupted.get("id", "")):
		state.erase("data_center_interrupted_dialog")
		state["data_center_access_resume_talk_needed"] = false
		SaveGame.save_global_state("hall_quest_01", state)
	match dialog_id:
		CARD_DIALOG_ID:
			state["data_center_card_dialog_finished"] = true
			state["data_center_access_resume_talk_needed"] = false
			SaveGame.save_global_state("hall_quest_01", state)
			_save_checkpoint()
			if not power_sequence_running and not _power_is_out(state):
				_show_access_intro_tasks(state)
				_arm_outage_timer(state)
				call_deferred("_start_access_plan_dialog")
		POWER_DIALOG_ID:
			state.erase("data_center_power_dialog_snapshot")
			state["data_center_power_dialog_finished"] = true
			state["data_center_tools_floor_task_active"] = true
			SaveGame.save_global_state("hall_quest_01", state)
			if bool(state.get("data_center_breaker_restored", false)):
				_restore_access_progress(state)
			else:
				_show_power_tasks(player.inventory.get_item_on_inventary(FLASHLIGHT_ITEM_ID), false)
			_save_checkpoint()
		ACCESS_PLAN_DIALOG_ID:
			state["data_center_access_plan_finished"] = true
			state["data_center_access_resume_talk_needed"] = false
			SaveGame.save_global_state("hall_quest_01", state)
			if not power_sequence_running and not _power_is_out(state):
				_arm_outage_timer(state)
				_show_access_intro_tasks(state)
				if bool(state.get("data_center_access_npc_arrived", false)):
					_resume_access_at_reader(state)
				else:
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
			if not _power_is_out(state):
				_show_rfid_reader_task()
				player.balao_de_pensamento.enfileirar(
					"data_center:inspect_rfid_reader",
					"RFID... preciso descobrir o que aconteceu com esse leitor."
				)
			_save_checkpoint()
		RETURN_DIALOG_ID:
			state["data_center_access_resume_talk_needed"] = false
			SaveGame.save_global_state("hall_quest_01", state)
			_restore_access_progress(state)
			_save_checkpoint()
	if dialog_id != POWER_DIALOG_ID and _power_is_out(state) and not bool(state.get("data_center_power_dialog_finished", false)):
		call_deferred("_start_power_failure_dialog")


func _begin_recipient_walk() -> void:
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if power_sequence_running or _power_is_out(state):
		return
	if bool(state.get("data_center_access_npc_arrived", false)):
		_resume_access_at_reader(state)
		return
	var paused_point := int(state.get("data_center_access_npc_paused_point", -1))
	state.erase("data_center_access_npc_paused_point")
	state["data_center_access_npc_moving"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_recipient_interaction(false)
	recipient.call("start_path", access_path)
	if paused_point >= 0 and paused_point < (recipient.get("path_points") as Array).size():
		recipient.set("current_point", paused_point)
	_save_checkpoint()


func _on_recipient_path_completed(finished_path: NPCPath) -> void:
	if finished_path != access_path or not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_access_npc_moving"] = false
	state["data_center_access_npc_arrived"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_save_checkpoint()
	if not power_sequence_running and not _power_is_out(state) and not bool(state.get("data_center_access_resume_talk_needed", false)):
		_show_access_intro_tasks(state)
		_resume_access_at_reader(state)


func _resume_access_at_reader(state: Dictionary) -> void:
	if (
		bool(state.get("data_center_rfid_inspection_task_active", false))
		or bool(state.get("data_center_rfid_wires_task_active", false))
		or bool(state.get("data_center_rfid_wires_repaired", false))
		or bool(state.get("data_center_rfid_reader_rechecked", false))
		or bool(state.get("data_center_rfid_reading_checked", false))
	):
		_restore_access_progress(state)
	elif bool(state.get("data_center_access_boss_card_failed", false)):
		_start_boss_denied_dialog()
	elif bool(state.get("data_center_access_boss_card_given", false)):
		return
	elif bool(state.get("data_center_access_strong_card_failed", false)):
		_start_strong_denied_dialog()
	elif not bool(state.get("data_center_access_strong_card_given", false)):
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
	if power_sequence_running or _power_is_out(state):
		player.balao_de_pensamento.enfileirar(
			"data_center:access_before_power",
			"Primeiro preciso resolver o problema da energia."
		)
		return
	if bool(state.get("data_center_rfid_reading_checked", false)):
		if bool(state.get("data_center_outage_pending", false)) and not bool(state.get("data_center_breaker_restored", false)):
			_begin_power_failure()
		return
	if bool(state.get("data_center_rfid_reader_rechecked", false)):
		_start_rfid_card_minigame()
		return
	if bool(state.get("data_center_rfid_wires_repaired", false)):
		await _verify_repaired_rfid_reader()
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


func play_restricted_area_fade_out() -> void:
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_forte_intro_seen", false)):
		return
	if restricted_area_fade == null or not is_instance_valid(player):
		return
	access_sequence_busy = true
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	player.set_physics_process(false)
	restricted_area_fade.color = Color(0, 0, 0, 0)
	restricted_area_fade.show()
	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(restricted_area_fade, "color:a", 1.0, 0.75)
	await fade_tween.finished


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
	_set_access_interactable(false)
	var superseded_thoughts: Array[String] = ["data_center:inspect_rfid_reader"]
	player.balao_de_pensamento.descartar(superseded_thoughts)
	var inspection_thoughts: Array[Dictionary] = [
		{
			"id": "data_center:rfid_reader_has_power",
			"text": "O leitor ainda tem energia..."
		},
		{
			"id": "data_center:rfid_burned_wires",
			"text": "Achei o problema. Os cabos estão queimados."
		},
		{
			"id": "data_center:rfid_reconnect_plan",
			"text": "Preciso reconectá-los antes de testar os cartões de novo."
		}
	]
	if not await _run_rfid_verification(inspection_thoughts, -1.0, "inspection"):
		if not power_sequence_running and not _power_is_out(SaveGame.office_mission_state(player)):
			_set_access_interactable(true)
		access_sequence_busy = false
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_rfid_inspection_task_active"] = false
	state["data_center_rfid_wires_task_active"] = true
	state["data_center_rfid_reading_task_active"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_access_prompt("Consertar os fios")
	_set_access_interactable(true)
	_show_rfid_repair_tasks(false)
	_save_checkpoint()
	access_sequence_busy = false


func _verify_repaired_rfid_reader() -> void:
	access_sequence_busy = true
	_set_access_interactable(false)
	if not await _run_rfid_verification([], -1.0, "recheck"):
		if not power_sequence_running and not _power_is_out(SaveGame.office_mission_state(player)):
			_set_access_interactable(true)
		access_sequence_busy = false
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_rfid_wires_task_active"] = false
	state["data_center_rfid_reading_task_active"] = true
	state["data_center_rfid_reading_checked"] = false
	state["data_center_rfid_reader_rechecked"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_set_access_prompt("Leitura RFID pendente")
	_show_rfid_repair_tasks(true, false)
	_save_checkpoint()
	access_sequence_busy = false
	_start_rfid_card_minigame()


func _run_rfid_verification(
	thoughts: Array[Dictionary] = [],
	duration: float = -1.0,
	stage: String = ""
) -> bool:
	if rfid_verification_ui == null or rfid_verification_bar == null or rfid_verification_label == null:
		push_error("A barra RFID precisa existir em SceneTrigger2/RFIDVerification.")
		return true
	var state: Dictionary = SaveGame.office_mission_state(player)
	var start_progress := 0.0
	if str(state.get("data_center_rfid_paused_stage", "")) == stage:
		start_progress = clampf(float(state.get("data_center_rfid_paused_progress", 0.0)), 0.0, 99.0)
	var active_thoughts: Array[Dictionary] = thoughts if start_progress <= 0.0 else []
	rfid_verification_interrupted = false
	rfid_verification_stage = stage
	rfid_active_thought_ids.clear()
	rfid_player_physics_was_enabled = player.is_physics_processing()
	rfid_verification_running = true
	player.direction = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.correndo = false
	player.state = "idle"
	player.UpdateAnimation()
	player.sfx_walking.stop()
	player.set_physics_process(false)
	if not active_thoughts.is_empty():
		_prepare_rfid_thought_balloon()
	_set_rfid_verification_progress(start_progress)
	rfid_verification_ui.show()
	var effective_duration := duration
	if effective_duration <= 0.0:
		effective_duration = (
			_calculate_rfid_thoughts_duration(thoughts)
			if not thoughts.is_empty()
			else rfid_verification_duration
		)
	effective_duration *= (100.0 - start_progress) / 100.0
	rfid_progress_tween = create_tween()
	rfid_progress_tween.tween_method(
		_set_rfid_verification_progress,
		start_progress,
		99.0 if not active_thoughts.is_empty() else 100.0,
		maxf(effective_duration, 0.1)
	).set_trans(Tween.TRANS_LINEAR)
	var last_thought_id := ""
	if not active_thoughts.is_empty():
		for thought in active_thoughts:
			var thought_id := str(thought.get("id", ""))
			rfid_active_thought_ids.append(thought_id)
			player.balao_de_pensamento.enfileirar(
				thought_id,
				str(thought.get("text", ""))
			)
		last_thought_id = str(active_thoughts.back().get("id", ""))
	while not rfid_verification_interrupted and (
		(rfid_progress_tween != null and rfid_progress_tween.is_valid() and rfid_progress_tween.is_running())
		or (not last_thought_id.is_empty() and not player.balao_de_pensamento.foi_concluido(last_thought_id))
	):
		await get_tree().process_frame
	if rfid_verification_interrupted:
		return false
	_set_rfid_verification_progress(100.0)
	if not active_thoughts.is_empty():
		# Exibe os 100% por um quadro exatamente quando o último balão termina.
		await get_tree().process_frame
	state = SaveGame.office_mission_state(player)
	state.erase("data_center_rfid_paused_stage")
	state.erase("data_center_rfid_paused_progress")
	SaveGame.save_global_state("hall_quest_01", state)
	rfid_progress_tween = null
	rfid_active_thought_ids.clear()
	_hide_rfid_verification()
	_restore_rfid_thought_balloon()
	_restore_player_after_rfid_verification()
	return _is_current_scene()


func _interrupt_rfid_verification() -> void:
	if not rfid_verification_running:
		return
	rfid_verification_interrupted = true
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["data_center_rfid_paused_stage"] = rfid_verification_stage
	state["data_center_rfid_paused_progress"] = rfid_verification_bar.value
	SaveGame.save_global_state("hall_quest_01", state)
	if rfid_progress_tween != null and rfid_progress_tween.is_valid():
		rfid_progress_tween.kill()
	rfid_progress_tween = null
	if not rfid_active_thought_ids.is_empty():
		player.balao_de_pensamento.descartar(rfid_active_thought_ids)
	rfid_active_thought_ids.clear()
	_hide_rfid_verification()
	_restore_rfid_thought_balloon()
	_restore_player_after_rfid_verification()
	_save_checkpoint()


func _calculate_rfid_thoughts_duration(thoughts: Array[Dictionary]) -> float:
	var balloon := player.balao_de_pensamento
	var characters_per_second := maxf(float(balloon.get("caracteres_por_segundo")), 0.001)
	var minimum_time := float(balloon.get("tempo_minimo"))
	var maximum_time := float(balloon.get("tempo_maximo"))
	var fade_time := float(balloon.get("tempo_fade_out"))
	var total := 0.0
	for thought in thoughts:
		var text := str(thought.get("text", ""))
		total += clampf(text.length() / characters_per_second, minimum_time, maximum_time)
		total += fade_time
	return maxf(total, 0.1)


func _prepare_rfid_thought_balloon() -> void:
	if rfid_balloon_adjusted or not is_instance_valid(player):
		return
	var balloon := player.balao_de_pensamento
	if balloon == null:
		return
	rfid_balloon_adjusted = true
	rfid_balloon_original_position = balloon.position
	rfid_balloon_original_speed = float(balloon.get("caracteres_por_segundo"))
	rfid_balloon_original_max_time = float(balloon.get("tempo_maximo"))
	balloon.position = rfid_balloon_original_position + rfid_thought_balloon_offset
	balloon.set("caracteres_por_segundo", 10.0)
	balloon.set("tempo_maximo", 5.0)


func _restore_rfid_thought_balloon() -> void:
	if not rfid_balloon_adjusted:
		return
	rfid_balloon_adjusted = false
	if not is_instance_valid(player) or player.balao_de_pensamento == null:
		return
	var balloon := player.balao_de_pensamento
	balloon.position = rfid_balloon_original_position
	balloon.set("caracteres_por_segundo", rfid_balloon_original_speed)
	balloon.set("tempo_maximo", rfid_balloon_original_max_time)


func _set_rfid_verification_progress(value: float) -> void:
	if rfid_verification_bar != null:
		rfid_verification_bar.value = value
	if rfid_verification_label != null:
		rfid_verification_label.text = "VERIFICANDO... %d%%" % roundi(value)


func _hide_rfid_verification() -> void:
	if rfid_verification_ui != null:
		rfid_verification_ui.hide()
	_set_rfid_verification_progress(0.0)


func _restore_player_after_rfid_verification() -> void:
	_restore_rfid_thought_balloon()
	if not rfid_verification_running:
		return
	rfid_verification_running = false
	if is_instance_valid(player):
		player.set_physics_process(rfid_player_physics_was_enabled)


func _set_access_interactable(enabled: bool) -> void:
	if access_trigger == null:
		return
	var interactable := access_trigger.get_node_or_null("Interectable")
	if interactable != null:
		interactable.set("is_interactable", enabled)


func _start_wire_repair_minigame() -> void:
	if access_sequence_busy:
		return
	access_sequence_busy = true
	_save_checkpoint()
	Progresso.iniciar_reparo_leitor_rfid(player)


func _start_rfid_card_minigame() -> void:
	if access_sequence_busy:
		return
	access_sequence_busy = true
	_save_checkpoint()
	Progresso.iniciar_reprogramacao_cartao_rfid(player)


func _begin_power_failure() -> void:
	if power_sequence_running or not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if bool(state.get("data_center_breaker_restored", false)):
		return
	if bool(state.get("data_center_power_outage", false)):
		_apply_power_outage_visuals()
		_start_power_failure_dialog()
		return
	if outage_timer != null:
		outage_timer.stop()
	power_sequence_running = true
	DialogManager.input_blocked = true
	if bool(state.get("data_center_access_npc_moving", false)) and recipient.has_method("stop_current_path"):
		state["data_center_access_npc_paused_point"] = int(recipient.get("current_point"))
		SaveGame.save_global_state("hall_quest_01", state)
		recipient.call("stop_current_path")
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
	state["data_center_outage_pending"] = false
	state["data_center_access_resume_talk_needed"] = true
	state["data_center_scientist_followup_done"] = false
	if bool(state.get("data_center_access_npc_moving", false)):
		state["data_center_access_npc_moving"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	_apply_power_outage_visuals()
	_reduce_remaining_time_once()
	_set_power_outage_music(true)
	_set_recipient_interaction(false)
	power_sequence_running = false
	DialogManager.input_blocked = false
	_save_checkpoint()
	if str(state.get("data_center_outage_phase", "")) == "before":
		_set_recipient_interaction(true, "ESPAÇO: FALAR")
		_show_power_talk_task()
	else:
		_start_power_failure_dialog()


func _start_power_failure_dialog() -> void:
	if not _is_current_scene():
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	if not _power_is_out(state) or bool(state.get("data_center_power_dialog_finished", false)):
		return
	if DialogManager.is_showing_dialog and DialogManager.current_dialog_id == POWER_DIALOG_ID:
		return
	if DialogManager.is_showing_dialog and DialogManager.dialog_box != null and bool(DialogManager.dialog_box.get("is_closing")):
		await get_tree().create_timer(0.1).timeout
		_start_power_failure_dialog()
		return
	if DialogManager.is_showing_dialog and DialogManager.dialog_box != null:
		var interrupted_lines: Array[String] = []
		for line in DialogManager.dialog_box.texts_to_display:
			interrupted_lines.append(str(line))
		state["data_center_interrupted_dialog"] = {
			"id": DialogManager.current_dialog_id,
			"lines": interrupted_lines,
			"index": int(DialogManager.dialog_box.current_index)
		}
		SaveGame.save_global_state("hall_quest_01", state)
		_save_checkpoint()
	var power_lines: Array[String]
	if str(state.get("data_center_outage_phase", "")) == "before":
		power_lines = [
			"Alex: As luzes apagaram. O que aconteceu?",
			"Cientista: A IA está drenando a energia do prédio. O disjuntor desarmou.",
			"Cientista: Você precisa religá-lo no andar das ferramentas, no 4º andar. Pegue uma lanterna antes de ir.",
			"Cientista: Depois volte. Precisamos desligar essa IA antes que seja tarde."
		]
	else:
		power_lines = [
			"Alex: O disjuntor desarmou! A energia está caindo.",
			"Cientista: A IA está drenando a energia do prédio! Precisamos interromper o que estávamos fazendo.",
			"Alex: Eu posso ligar o disjuntor de novo.",
			"Cientista: Ele fica no andar das ferramentas, no 4º andar. Pegue uma lanterna antes de ir.",
			"Cientista: Volte assim que puder. Temos que desligar essa IA."
		]
	DialogManager.interrupt_with_dialog(power_lines, POWER_DIALOG_ID, false)


func _suspend_dialog_for_return() -> void:
	if not is_instance_valid(player) or not DialogManager.is_showing_dialog or DialogManager.dialog_box == null:
		return
	var dialog_id: String = DialogManager.current_dialog_id
	if dialog_id not in [CARD_DIALOG_ID, POWER_DIALOG_ID, ACCESS_PLAN_DIALOG_ID, STRONG_CARD_DIALOG_ID, STRONG_DENIED_DIALOG_ID, BOSS_DENIED_DIALOG_ID, RETURN_DIALOG_ID]:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	var lines: Array[String] = []
	for line in DialogManager.dialog_box.texts_to_display:
		lines.append(str(line))
	var snapshot_key := "data_center_power_dialog_snapshot" if dialog_id == POWER_DIALOG_ID else "data_center_interrupted_dialog"
	state[snapshot_key] = {
		"id": dialog_id,
		"lines": lines,
		"index": int(DialogManager.dialog_box.current_index)
	}
	if dialog_id != POWER_DIALOG_ID:
		state["data_center_access_resume_talk_needed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	DialogManager.suspend_current_dialog(false)


func _scientist_talk_pending(state: Dictionary) -> bool:
	return (
		SaveGame.data_center_scientist_talk_pending(state)
		or not bool(state.get("data_center_card_dialog_finished", false))
		or not bool(state.get("data_center_access_plan_finished", false))
	)


func _resume_interrupted_dialog(snapshot_key: String = "data_center_interrupted_dialog") -> void:
	if not _is_current_scene() or DialogManager.is_showing_dialog:
		return
	var state: Dictionary = SaveGame.office_mission_state(player)
	var interrupted: Dictionary = state.get(snapshot_key, {})
	if interrupted.is_empty():
		return
	if DialogManager.resume_suspended_dialog(str(interrupted.get("id", ""))):
		return
	var lines: Array[String] = []
	for line in interrupted.get("lines", []):
		lines.append(str(line))
	if not lines.is_empty():
		DialogManager.start_dialog(lines, str(interrupted.get("id", "")), int(interrupted.get("index", 0)))


func _power_is_out(state: Dictionary) -> bool:
	return bool(state.get("data_center_power_outage", false)) and not bool(state.get("data_center_breaker_restored", false))


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


func _show_power_talk_task() -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		var state: Dictionary = SaveGame.office_mission_state(player)
		if bool(state.get("data_center_return_task_completed", false)):
			quest_ui.show_return_and_scientist_talk_tasks()
		else:
			quest_ui.show_data_center_power_talk_task()


func _show_access_intro_tasks(state: Dictionary) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_data_center_access_intro_tasks(
			bool(state.get("data_center_card_dialog_finished", false)),
			bool(state.get("data_center_access_plan_finished", false)),
			bool(state.get("data_center_access_npc_arrived", false))
		)


func _has_boss_card() -> bool:
	return _current_card_type() == BOSS_CARD_TYPE


func _show_rfid_reader_task() -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_rfid_reader_task(false)


func _show_rfid_repair_tasks(
	wires_repaired: bool,
	reading_checked: bool = false,
	animate: bool = false
) -> void:
	var quest_ui := player.get_node_or_null("QUEST_MISSION") as QuestMissionUI
	if quest_ui != null:
		quest_ui.show_rfid_repair_tasks(wires_repaired, reading_checked, animate)


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
