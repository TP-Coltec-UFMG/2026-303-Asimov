class_name QuestMissionUI
extends CanvasLayer

@export var standalone_mode: bool = false
@export var standalone_left_side: bool = false
@export var standalone_white_border: bool = false

const BREAKER_URGENT_THOUGHT_ID := "data_center:breaker_restored_urgent"
const BREAKER_RETURN_THOUGHT_ID := "data_center:breaker_return_plan"
const COOLING_THOUGHT_TIME := "cooling:time_running_out"
const COOLING_THOUGHT_PLAN := "cooling:reduce_capacity"
const COOLING_THOUGHT_ACTION := "cooling:redirect_plan"
const COOLING_THOUGHT_SUCCESS := "cooling:success"
const COOLING_THOUGHT_RESULT := "cooling:extra_time"
const COOLING_THOUGHT_FAILURE := "cooling:failed_attempt"
const COOLING_THOUGHT_FAILURE_ALTERNATIVE := "cooling:other_system_after_failure"
const COOLING_TASK_INDEX := 13
const COOLING_IDLE_DELAY := 3.0
const PANEL_DISPLAY_TIME := 15.0
const PANEL_FADE_IN_TIME := 0.45
const PANEL_FADE_OUT_TIME := 0.8
const PROGRAMMER_ENDING_TASKS: Array[String] = [
	"ISOLE O PROTOCOLO DE\nLANÇAMENTO",
	"RECONSTRUA A REDE NEURAL",
	"RESTAURE AS LEIS DA\nROBÓTICA",
	"USE O CARTÃO DO CHEFE\nPARA APLICAR AS ALTERAÇÕES",
]

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
	$VBoxContainer/HBoxContainer13,
	$VBoxContainer/HBoxContainer14,
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
	$VBoxContainer/HBoxContainer13/AnimatedSprite2D,
	$VBoxContainer/HBoxContainer14/AnimatedSprite2D,
]

var desired_visible: bool = false
var hidden_for_elevator: bool = false
var cooling_idle_time: float = 0.0
var rendering_programmer_tasks: bool = false
var _panel_time_left: float = PANEL_DISPLAY_TIME
var _auto_hidden: bool = false
var _completed_rows: Array[bool] = []
var _panel_fading_out: bool = false
var _panel_fade: Tween


func _enter_tree() -> void:
	if hidden_for_elevator:
		call_deferred("_restore_after_scene_change")


func _ready() -> void:
	for row in rows:
		_completed_rows.append(false)
	if standalone_mode:
		_configure_standalone_appearance()
		_ignore_mouse_input_recursive(self)
		for row in rows:
			row.hide()
		hide()
		return
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
	rows[12].hide()
	rows[COOLING_TASK_INDEX].hide()
	hide()
	call_deferred("_connect_thought_balloon")
	call_deferred("refresh_saved_state")


func _configure_standalone_appearance() -> void:
	var background := $ColorRect as Control
	var border := $StandaloneBorder as Control
	var title := $Label2 as Control
	var task_list := $VBoxContainer as Control
	border.visible = standalone_white_border
	if not standalone_left_side:
		return
	_move_control_to_left(background, 0.0, 106.0)
	_move_control_to_left(border, 0.0, 106.0)
	_move_control_to_left(title, 36.0, 77.0)
	_move_control_to_left(task_list, 16.0, 105.0)


func _move_control_to_left(control: Control, left: float, right: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.offset_left = left
	control.offset_right = right


func _ignore_mouse_input_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_input_recursive(child)


func _process(delta: float) -> void:
	if not standalone_mode and desired_visible and not _auto_hidden and not _panel_fading_out and visible:
		_panel_time_left -= delta
		if _panel_time_left <= 0.0:
			_fade_out_panel()
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var state := SaveGame.office_mission_state(current_player)
	if bool(state.get("cooling_failure_thought_pending", false)):
		_queue_cooling_failure(current_player, state)
	if bool(state.get("cooling_completion_thought_pending", false)):
		_queue_cooling_completion(current_player, state)
	if bool(state.get("cooling_intro_started", false)) and not bool(state.get("cooling_optional_task_active", false)):
		_restore_cooling_intro(current_player, state)
	if not bool(state.get("cooling_opportunity_pending", false)):
		cooling_idle_time = 0.0
		return
	if not _can_start_cooling_intro(current_player, state):
		cooling_idle_time = 0.0
		return
	cooling_idle_time += delta
	if cooling_idle_time >= COOLING_IDLE_DELAY:
		cooling_idle_time = 0.0
		_start_cooling_intro(current_player, state)


func set_panel_visible(value: bool) -> void:
	if value and not standalone_mode and not rendering_programmer_tasks:
		_sync_optional_cooling_row()
	var was_desired := desired_visible
	desired_visible = value
	if value and not was_desired and not standalone_mode:
		_reveal_panel()
	elif not value and not standalone_mode:
		_stop_panel_fade()
		_auto_hidden = false
		_set_panel_alpha(1.0)
	visible = value and (not _auto_hidden or _panel_fading_out) and not get_tree().paused and not hidden_for_elevator


func _task_changed() -> void:
	if not standalone_mode:
		if desired_visible:
			_reveal_panel()
		else:
			_panel_time_left = PANEL_DISPLAY_TIME
			_auto_hidden = false


func _reveal_panel() -> void:
	var was_visible := visible
	_stop_panel_fade()
	_auto_hidden = false
	_panel_time_left = PANEL_DISPLAY_TIME
	if desired_visible and not hidden_for_elevator and not get_tree().paused:
		if not was_visible:
			_set_panel_alpha(0.0)
		show()
		var from_alpha := _panel_alpha()
		if from_alpha < 1.0:
			_panel_fade = create_tween()
			_panel_fade.tween_method(_set_panel_alpha, from_alpha, 1.0, PANEL_FADE_IN_TIME)


func _fade_out_panel() -> void:
	_panel_fading_out = true
	_stop_panel_fade(false)
	_panel_fade = create_tween()
	_panel_fade.tween_method(_set_panel_alpha, _panel_alpha(), 0.0, PANEL_FADE_OUT_TIME)
	_panel_fade.tween_callback(func() -> void:
		_panel_fading_out = false
		_auto_hidden = true
		hide()
	)


func _stop_panel_fade(reset_fading: bool = true) -> void:
	if _panel_fade != null and _panel_fade.is_valid():
		_panel_fade.kill()
	_panel_fade = null
	if reset_fading:
		_panel_fading_out = false


func _panel_alpha() -> float:
	return ($ColorRect as CanvasItem).modulate.a


func _set_panel_alpha(alpha: float) -> void:
	for part in [$ColorRect, $StandaloneBorder, $Label2, $VBoxContainer]:
		(part as CanvasItem).modulate.a = alpha


func _unhandled_key_input(event: InputEvent) -> void:
	if standalone_mode or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_TAB:
		return
	var current_player := get_parent() as Player
	if not desired_visible or hidden_for_elevator or get_tree().paused:
		return
	if current_player == null or not current_player.is_physics_processing():
		return
	if DialogManager.is_showing_dialog:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var guide := scene.get_node_or_null("CoolingLocationGuide")
	if guide != null and bool(guide.get("cutscene_running")):
		return
	_reveal_panel()
	get_viewport().set_input_as_handled()


func hide_during_elevator() -> void:
	hidden_for_elevator = true
	hide()


func restore_after_elevator() -> void:
	hidden_for_elevator = false
	visible = desired_visible and not _auto_hidden and not get_tree().paused


func hide_all_tasks(preserve_optional: bool = true) -> void:
	for row in rows:
		row.hide()
	if standalone_mode:
		set_panel_visible(false)
		return
	if not preserve_optional:
		desired_visible = false
		hide()
		return
	_sync_optional_cooling_row()
	set_panel_visible(rows[COOLING_TASK_INDEX].visible)


func show_standalone_task(
	text: String,
	completed: bool = false,
	animate: bool = false
) -> void:
	if not standalone_mode:
		return
	for index in range(rows.size()):
		set_task_visible(index, index == 0)
	set_task_text(0, text)
	set_task_completed(0, completed, animate)
	set_panel_visible(true)


func show_standalone_task_sequence(
	tasks: Array[String],
	completed_count: int,
	animate_latest: bool = false
) -> void:
	if not standalone_mode or tasks.is_empty():
		return
	var safe_completed := clampi(completed_count, 0, tasks.size())
	var start_index := 0
	if safe_completed >= tasks.size():
		start_index = maxi(tasks.size() - 3, 0)
	elif safe_completed >= 3:
		start_index = floori(float(safe_completed - 1) / 2.0) * 2
		start_index = mini(start_index, maxi(tasks.size() - 3, 0))
	for row_index in range(rows.size()):
		var task_index := start_index + row_index
		var should_show := row_index < 3 and task_index < tasks.size()
		set_task_visible(row_index, should_show)
		if not should_show:
			continue
		set_task_text(row_index, tasks[task_index])
		var completed := task_index < safe_completed
		set_task_completed(
			row_index,
			completed,
			animate_latest and completed and task_index == safe_completed - 1
		)
	set_panel_visible(true)


func show_programmer_ending_tasks(
	completed_count: int,
	animate_latest: bool = false
) -> void:
	var safe_completed := clampi(
		completed_count,
		0,
		PROGRAMMER_ENDING_TASKS.size()
	)
	# Revela somente a tarefa atual e preserva as anteriores como confirmação.
	# Ao encher o painel, a última concluída sobe para iniciar a próxima janela.
	var start_index := safe_completed - 1 if safe_completed >= 3 else 0
	var visible_end := mini(safe_completed + 1, PROGRAMMER_ENDING_TASKS.size())
	var entries: Array[Dictionary] = []
	for task_index in range(start_index, visible_end):
		entries.append({
			"text": PROGRAMMER_ENDING_TASKS[task_index],
			"completed": task_index < safe_completed,
			"task_index": task_index,
		})
	var state := SaveGame.office_mission_state(get_parent() as Player)
	var cooling_active := (
		bool(state.get("cooling_optional_task_active", false))
		and not bool(state.get("cooling_optional_task_completed", false))
		and not bool(state.get("cooling_optional_task_cancelled", false))
	)
	if cooling_active:
		# A missão opcional ocupa uma das três linhas. Retiramos primeiro a tarefa
		# concluída mais antiga, nunca o objetivo atual.
		while entries.size() >= 3:
			var remove_index := -1
			for index in range(entries.size()):
				if bool(entries[index]["completed"]):
					remove_index = index
					break
			if remove_index < 0:
				remove_index = 0
			entries.remove_at(remove_index)
		entries.append({
			"text": "OPCIONAL: REDIRECIONE A\nREFRIGERAÇÃO DA IA",
			"completed": false,
			"task_index": -1,
		})
	for row_index in range(rows.size()):
		var should_show := row_index < 3 and row_index < entries.size()
		set_task_visible(row_index, should_show)
		if not should_show:
			continue
		var entry := entries[row_index]
		set_task_text(row_index, str(entry["text"]))
		var completed := bool(entry["completed"])
		var task_index := int(entry["task_index"])
		set_task_completed(
			row_index,
			completed,
			animate_latest
			and completed
			and task_index == safe_completed - 1
		)
	rendering_programmer_tasks = true
	set_panel_visible(true)
	rendering_programmer_tasks = false


func _sync_optional_cooling_row() -> void:
	if not is_node_ready():
		return
	var state := SaveGame.office_mission_state(get_parent() as Player)
	if bool(state.get("programmer_ending_started", false)):
		set_task_visible(COOLING_TASK_INDEX, false)
		if not rendering_programmer_tasks:
			show_programmer_ending_tasks(_programmer_completed_count(state))
		return
	var active := bool(state.get("cooling_optional_task_active", false))
	var completed := bool(state.get("cooling_optional_task_completed", false))
	set_task_visible(COOLING_TASK_INDEX, active or completed)
	if active or completed:
		set_task_text(COOLING_TASK_INDEX, "OPCIONAL: REDIRECIONE A\nREFRIGERAÇÃO DA IA")
		set_task_completed(COOLING_TASK_INDEX, completed)


func _programmer_completed_count(state: Dictionary) -> int:
	if bool(state.get("programmer_recalibration_applied", false)):
		return 4
	if bool(state.get("programmer_laws_completed", false)):
		return 3
	if bool(state.get("programmer_neural_completed", false)):
		return 2
	if bool(state.get("programmer_launch_isolated", false)):
		return 1
	return 0


func _can_start_cooling_intro(current_player: Player, state: Dictionary) -> bool:
	if get_tree().paused or DialogManager.is_showing_dialog:
		return false
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var programmer_ending := current_scene.get_node_or_null("ProgrammerEnding")
		if programmer_ending != null and bool(programmer_ending.get("busy")):
			return false
	if not current_player.is_physics_processing():
		return false
	if current_player.balao_de_pensamento.esta_ocupado():
		return false
	return not (
		bool(state.get("data_center_power_outage", false))
		and not bool(state.get("data_center_breaker_restored", false))
	)


func _start_cooling_intro(current_player: Player, state: Dictionary) -> void:
	state["cooling_opportunity_pending"] = false
	state["cooling_intro_started"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	_queue_cooling_intro(current_player)


func _queue_cooling_intro(current_player: Player) -> void:
	current_player.balao_de_pensamento.enfileirar(COOLING_THOUGHT_TIME, "Meu tempo está acabando.")
	current_player.balao_de_pensamento.enfileirar(COOLING_THOUGHT_PLAN, "Preciso reduzir a capacidade dessa IA.")
	current_player.balao_de_pensamento.enfileirar(COOLING_THOUGHT_ACTION, "Se eu redirecionar a refrigeração dela, consigo reduzir sua capacidade.")


func _restore_cooling_intro(current_player: Player, state: Dictionary) -> void:
	_connect_thought_balloon()
	if current_player.balao_de_pensamento.foi_concluido(COOLING_THOUGHT_ACTION):
		_activate_cooling_task(current_player, state)
		return
	_queue_cooling_intro(current_player)


func _activate_cooling_task(current_player: Player, state: Dictionary) -> void:
	if bool(state.get("cooling_optional_task_active", false)):
		return
	state["cooling_intro_started"] = false
	state["cooling_optional_task_active"] = true
	state["cooling_optional_task_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	_sync_optional_cooling_row()
	set_panel_visible(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _queue_cooling_completion(current_player: Player, state: Dictionary) -> void:
	state["cooling_completion_thought_pending"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	current_player.balao_de_pensamento.enfileirar(COOLING_THOUGHT_SUCCESS, "Funcionou.")
	current_player.balao_de_pensamento.enfileirar(COOLING_THOUGHT_RESULT, "Agora tenho mais algum tempo.")
	_sync_optional_cooling_row()
	set_panel_visible(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _queue_cooling_failure(current_player: Player, state: Dictionary) -> void:
	state["cooling_failure_thought_pending"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	current_player.balao_de_pensamento.enfileirar(
		COOLING_THOUGHT_FAILURE,
		"Essa não!!!"
	)
	if bool(state.get("cooling_failure_has_alternative", false)):
		current_player.balao_de_pensamento.enfileirar(
			COOLING_THOUGHT_FAILURE_ALTERNATIVE,
			"Tá, tem outro sistema de refrigeração..."
		)
	_sync_optional_cooling_row()
	set_panel_visible(true)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func _restore_after_scene_change() -> void:
	if is_inside_tree() and hidden_for_elevator:
		restore_after_elevator()


func set_task_visible(index: int, value: bool) -> void:
	if index >= 0 and index < rows.size():
		if rows[index].visible != value:
			_task_changed()
		rows[index].visible = value


func set_task_text(index: int, value: String) -> void:
	if index >= 0 and index < rows.size():
		var label := rows[index].get_node("Label3") as Label
		if label.text != value and rows[index].visible:
			_task_changed()
		label.text = value


func set_task_completed(index: int, completed: bool, animate: bool = false) -> void:
	if index < 0 or index >= markers.size():
		return
	if _completed_rows.size() == rows.size() and _completed_rows[index] != completed:
		_completed_rows[index] = completed
		if rows[index].visible:
			_task_changed()
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


func show_return_to_data_center_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(6, "VOLTE AO DATA CENTER", completed, animate)


func start_breaker_followup() -> void:
	var current_player := get_parent() as Player
	if current_player == null:
		return
	_connect_thought_balloon()
	var state: Dictionary = SaveGame.office_mission_state(current_player)
	if bool(state.get("data_center_return_task_active", false)):
		if not bool(state.get("data_center_return_task_completed", false)):
			show_return_to_data_center_task(false)
		return
	state["data_center_return_task_pending"] = true
	state["data_center_return_task_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	_queue_breaker_followup_thoughts(current_player)


func _connect_thought_balloon() -> void:
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var balloon := current_player.get_node_or_null("BalaoDePensamento")
	if balloon == null:
		return
	if not balloon.pensamento_finalizado.is_connected(_on_thought_finished):
		balloon.pensamento_finalizado.connect(_on_thought_finished)


func _queue_breaker_followup_thoughts(current_player: Player) -> void:
	current_player.balao_de_pensamento.enfileirar(
		BREAKER_URGENT_THOUGHT_ID,
		"Temos que desligar essa IA urgentemente."
	)
	current_player.balao_de_pensamento.enfileirar(
		BREAKER_RETURN_THOUGHT_ID,
		"Vou voltar ao data center."
	)


func _on_thought_finished(thought_id: String) -> void:
	if thought_id == BREAKER_RETURN_THOUGHT_ID:
		_activate_return_to_data_center_task()
	elif thought_id == COOLING_THOUGHT_ACTION:
		var current_player := get_parent() as Player
		if current_player != null:
			_activate_cooling_task(
				current_player,
				SaveGame.office_mission_state(current_player)
			)


func _activate_return_to_data_center_task() -> void:
	var current_player := get_parent() as Player
	if current_player == null:
		return
	var state: Dictionary = SaveGame.office_mission_state(current_player)
	if not bool(state.get("data_center_return_task_pending", false)):
		return
	var already_arrived := bool(state.get("data_center_return_task_completed", false))
	state["data_center_return_task_pending"] = false
	state["data_center_return_task_active"] = not already_arrived
	state["data_center_return_task_completed"] = already_arrived
	SaveGame.save_global_state("hall_quest_01", state)
	if already_arrived and _data_center_scientist_talk_pending(state):
		show_return_and_scientist_talk_tasks()
	else:
		show_return_to_data_center_task(already_arrived, already_arrived)
	if current_player.checkpoint_enabled:
		SaveGame.create_checkpoint(current_player)


func show_data_center_card_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(7, "ENTREGUE O CARTÃO AO CIENTISTA", completed, animate)


func show_data_center_power_talk_task() -> void:
	_show_single_data_center_task(7, "FALE COM O CIENTISTA", false, false)


func _data_center_scientist_talk_pending(state: Dictionary) -> bool:
	return (
		SaveGame.data_center_scientist_talk_pending(state)
		or not bool(state.get("data_center_card_dialog_finished", false))
		or not bool(state.get("data_center_access_plan_finished", false))
	)


func show_return_and_scientist_talk_tasks() -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 6 or index == 7)
	set_task_text(6, "VOLTE AO DATA CENTER")
	set_task_completed(6, true)
	set_task_text(7, "FALE COM O CIENTISTA")
	set_task_completed(7, false)
	set_panel_visible(true)


func show_data_center_access_intro_tasks(
	card_dialog_finished: bool,
	plan_finished: bool,
	npc_arrived: bool
) -> void:
	var access_started := plan_finished
	for index in range(rows.size()):
		set_task_visible(index, index == 7 or (index == 8 and card_dialog_finished) or (index == 9 and access_started))
	if npc_arrived and access_started:
		set_task_text(7, "ESCUTE O CIENTISTA")
		set_task_text(8, "ACOMPANHE O CIENTISTA")
		set_task_text(9, "ABRA A ÁREA RESTRITA")
		set_task_completed(7, true)
		set_task_completed(8, true)
		set_task_completed(9, false)
	else:
		set_task_text(7, "ENTREGUE O CARTÃO AO CIENTISTA")
		set_task_completed(7, true)
		if card_dialog_finished:
			set_task_text(8, "ESCUTE O CIENTISTA")
			set_task_completed(8, access_started)
		if access_started:
			set_task_text(9, "ACOMPANHE O CIENTISTA")
			set_task_completed(9, false)
	set_panel_visible(true)


func show_find_flashlight_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(8, "ENCONTRE UMA LANTERNA", completed, animate)


func show_restore_breaker_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(9, "LIGUE O DISJUNTOR", completed, animate)


func show_go_to_fourth_floor_task(completed: bool = false, animate: bool = false) -> void:
	_show_single_data_center_task(10, "VÁ PARA O QUARTO ANDAR", completed, animate)


func show_rfid_reader_task(
	completed: bool = false,
	animate: bool = false
) -> void:
	_show_single_data_center_task(12, "VERIFIQUE O LEITOR RFID", completed, animate)


func show_rfid_repair_tasks(
	wires_repaired: bool = false,
	reading_checked: bool = false,
	animate_repair: bool = false
) -> void:
	for index in range(rows.size()):
		set_task_visible(index, index == 11 or index == 12)
	set_task_text(11, "RECONECTE OS CABOS")
	set_task_completed(11, wires_repaired, animate_repair)
	set_task_text(12, "VERIFIQUE A LEITURA RFID")
	set_task_completed(12, reading_checked)
	set_panel_visible(true)


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
	var return_task_pending := bool(state.get("data_center_return_task_pending", false))
	var return_task_active := bool(state.get("data_center_return_task_active", false))
	var return_task_completed := bool(state.get("data_center_return_task_completed", false))
	var tools_floor_task_active := bool(state.get("data_center_tools_floor_task_active", false))
	var tools_floor_task_completed := bool(state.get("data_center_tools_floor_task_completed", false))
	var breaker_completed := bool(state.get("data_center_breaker_restored", false))
	var card_delivered := bool(state.get("data_center_card_delivered", false))
	var old_decryption_task_active := bool(state.get("data_center_access_decryption_task_active", false))
	var rfid_inspection_task_active := bool(state.get("data_center_rfid_inspection_task_active", false))
	var rfid_wires_task_active := bool(state.get("data_center_rfid_wires_task_active", false))
	var rfid_wires_repaired := bool(state.get("data_center_rfid_wires_repaired", false))
	var rfid_reading_checked := bool(state.get("data_center_rfid_reading_checked", false))
	var flashlight_completed := bool(state.get("data_center_flashlight_collected", false)) or (
		current_player != null
		and current_player.inventory.get_item_on_inventary("lanterna")
	)
	var hack_ready := bool(state.get("office_hack_boss_room_ready", false)) or (
		laptop_collected and cable_collected
	)
	if bool(state.get("programmer_ending_started", false)):
		var programmer_completed := 0
		if bool(state.get("programmer_recalibration_applied", false)):
			programmer_completed = 4
		elif bool(state.get("programmer_laws_completed", false)):
			programmer_completed = 3
		elif bool(state.get("programmer_neural_completed", false)):
			programmer_completed = 2
		elif bool(state.get("programmer_launch_isolated", false)):
			programmer_completed = 1
		show_programmer_ending_tasks(programmer_completed)
		return
	if return_task_pending and current_player != null:
		_connect_thought_balloon()
		_queue_breaker_followup_thoughts(current_player)
		if current_player.balao_de_pensamento.foi_concluido(BREAKER_RETURN_THOUGHT_ID):
			_activate_return_to_data_center_task()
			return
	if return_task_active and not return_task_completed:
		show_return_to_data_center_task(false)
	elif card_delivered and breaker_completed and _data_center_scientist_talk_pending(state):
		if return_task_completed:
			show_return_and_scientist_talk_tasks()
		else:
			show_data_center_power_talk_task()
	elif bool(state.get("data_center_power_outage", false)) and not breaker_completed:
		if not bool(state.get("data_center_power_dialog_finished", false)) and (
			str(state.get("data_center_outage_phase", "")) == "before"
			or not (state.get("data_center_power_dialog_snapshot", {}) as Dictionary).is_empty()
		):
			show_data_center_power_talk_task()
		else:
			show_data_center_power_tasks(flashlight_completed, tools_floor_task_completed, false)
	elif rfid_wires_task_active or rfid_wires_repaired:
		show_rfid_repair_tasks(rfid_wires_repaired, rfid_reading_checked)
	elif rfid_inspection_task_active or old_decryption_task_active:
		show_rfid_reader_task(false)
	elif card_delivered and (breaker_completed or not bool(state.get("data_center_power_outage", false))):
		show_data_center_access_intro_tasks(
			bool(state.get("data_center_card_dialog_finished", false)),
			bool(state.get("data_center_access_plan_finished", false)),
			bool(state.get("data_center_access_npc_arrived", false))
		)
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
		set_task_visible(12, false)
	_sync_optional_cooling_row()
	if rows[COOLING_TASK_INDEX].visible:
		set_panel_visible(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		hide()
	elif what == NOTIFICATION_UNPAUSED and is_node_ready() and not hidden_for_elevator:
		restore_after_elevator()
