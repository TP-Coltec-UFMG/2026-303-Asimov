extends CanvasLayer

# Ferramenta temporária de teste. Só funciona nas versões de depuração.
const PLAYER_SCENE := "res://Player/ManPlayer.tscn"
const HALL := "res://Scenes/andar_hall.tscn"
const OFFICE := "res://Scenes/andar_escritorio.tscn"
const BOSS_ROOM := "res://Scenes/sala_chefe.tscn"
const DATA_CENTER := "res://Scenes/andar_data_center.tscn"
const TOOLS_FLOOR := "res://Scenes/andar_ferramentas.tscn"
const COOLING := "res://Scenes/data_center_refrigeracao.tscn"
const STRONG_DATA_CENTER := "res://Scenes/data_center_forte.tscn"

const STAGES := [
	{"title": "01 · Hall / início", "scene": HALL, "position": Vector2(-43, 36)},
	{"title": "02 · Escritório / chegada", "scene": OFFICE, "position": Vector2(38, -185)},
	{"title": "03 · Escritório / hackear sala", "scene": OFFICE, "position": Vector2(38, -185)},
	{"title": "04 · Sala do chefe / pegar cartão", "scene": BOSS_ROOM, "position": Vector2(0, 19)},
	{"title": "05 · Data center / entregar cartão", "scene": DATA_CENTER, "position": Vector2(69, -200)},
	{"title": "06 · Data center / queda de energia", "scene": DATA_CENTER, "position": Vector2(69, -200)},
	{"title": "07 · 4º andar / religar disjuntor", "scene": TOOLS_FLOOR, "position": Vector2(71, -190)},
	{"title": "08 · Data center / cartão forte", "scene": DATA_CENTER, "position": Vector2(-120, -121)},
	{"title": "09 · Data center / verificar leitor", "scene": DATA_CENTER, "position": Vector2(-120, -121)},
	{"title": "10 · Data center / consertar cabos", "scene": DATA_CENTER, "position": Vector2(-120, -121)},
	{"title": "11 · Data center / verificar RFID", "scene": DATA_CENTER, "position": Vector2(-120, -121)},
	{"title": "12 · Data center / minigame RFID", "scene": DATA_CENTER, "position": Vector2(-120, -121)},
	{"title": "13 · Refrigeração / tarefa opcional", "scene": COOLING, "position": Vector2(150, -172)},
	{"title": "14 · Final / isolar lançamento", "scene": STRONG_DATA_CENTER, "position": Vector2(-158, -51)},
	{"title": "15 · Final / rede neural", "scene": STRONG_DATA_CENTER, "position": Vector2(-158, -51)},
	{"title": "16 · Final / restaurar leis", "scene": STRONG_DATA_CENTER, "position": Vector2(-158, -51)},
	{"title": "17 · Final / aplicar correção", "scene": STRONG_DATA_CENTER, "position": Vector2(-158, -51)}
]

@onready var menu: Control = $Menu
@onready var indicator: Label = $Indicator
@onready var stage_buttons: VBoxContainer = $Menu/Panel/Margin/VBox/Scroll/StageButtons

var active_stage: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu.hide()
	indicator.hide()
	if not OS.is_debug_build():
		set_process_input(false)
		return
	for index in STAGES.size():
		var button := stage_buttons.get_node("Stage%02d" % (index + 1)) as Button
		button.text = STAGES[index]["title"]
		button.pressed.connect(_jump.bind(index))
	$Menu/Panel/Margin/VBox/Close.pressed.connect(_close_menu)
	$Menu/Panel/Margin/VBox/Restore.pressed.connect(restore_real_save)


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.ctrl_pressed and key.shift_pressed:
		if key.physical_keycode == KEY_D:
			_toggle_menu()
			get_viewport().set_input_as_handled()
			return
		var number := _shortcut_stage(key.physical_keycode)
		if number >= 0:
			_jump(number)
			get_viewport().set_input_as_handled()
			return
	if menu.visible and key.physical_keycode == KEY_ESCAPE:
		_close_menu()
		get_viewport().set_input_as_handled()


func _shortcut_stage(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_1
	if keycode == KEY_0:
		return 13 # Atalho rápido para o começo do final do programador.
	return -1


func _toggle_menu() -> void:
	menu.visible = not menu.visible
	if menu.visible:
		stage_buttons.get_child(0).grab_focus()
	else:
		get_viewport().gui_release_focus()


func _close_menu() -> void:
	menu.hide()
	get_viewport().gui_release_focus()


func _jump(index: int) -> void:
	if index < 0 or index >= STAGES.size():
		return
	var stage: Dictionary = STAGES[index]
	if not ResourceLoader.exists(stage["scene"]):
		push_error("Cena de teste não encontrada: " + stage["scene"])
		return
	_close_menu()
	get_tree().paused = false
	if is_instance_valid(DialogManager.dialog_box):
		DialogManager.dialog_box.queue_free()
	DialogManager.dialog_box = null
	DialogManager.is_showing_dialog = false
	DialogManager.current_dialog_id = ""
	MusicController.stop_all_audio()
	get_tree().set_meta(&"dev_mission_jump_active", true)
	active_stage = index
	indicator.text = "DEV · %02d · Ctrl+Shift+D" % (index + 1)
	indicator.show()

	var state := _mission_state(index)
	var world := _world_state(index, state)
	var job := "programador" if index >= 13 else str(Configs.configs.get("job", "programador"))
	if job.is_empty():
		job = "programador"
	Configs.configs["job"] = job
	if str(Configs.configs.get("character", "")).is_empty():
		Configs.configs["character"] = "Alex"
	if str(Configs.configs.get("difficulty", "")).is_empty():
		Configs.configs["difficulty"] = "normal"

	SaveGame.save_data = world.duplicate(true)
	SaveGame.checkpoint_world_state = world.duplicate(true)
	SaveGame.checkpoint_scene_path = stage["scene"]
	SaveGame.checkpoint_player_scene_path = PLAYER_SCENE
	SaveGame.checkpoint_pos = stage["position"]
	SaveGame.state_player = {"inventario": _inventory(index), "pensamentos": {}}
	SaveGame.checkpoint_progress = {
		"job": Configs.configs["job"],
		"character": Configs.configs["character"],
		"difficulty": Configs.configs["difficulty"]
	}
	SaveGame.checkpoint_audio_state = {}
	SaveGame.tempo_restante = 118.0 if index == 12 else 540.0
	SaveGame.tempo_atual = SaveGame.tempo_restante
	SaveGame.restore_checkpoint_pending = false
	SaveGame.restore_audio_pending = false
	if not SaveGame.load_last_checkpoint():
		push_error("Não foi possível abrir a etapa de teste: " + stage["title"])


func _mission_state(index: int) -> Dictionary:
	var state: Dictionary = {}
	if index >= 1:
		state["elevator_third_floor_unlocked"] = true
		state["arrived_third_floor"] = true
	if index >= 2:
		state["office_npc_arrived"] = true
		state["office_npc_revealed"] = true
		state["office_npc_shout_finished"] = true
		state["office_dialog_finished"] = true
		state["office_question_finished"] = true
		state["office_laptop_collected"] = true
		state["office_cable_collected"] = true
		state["office_first_hacking_item"] = "laptop"
		state["office_hack_boss_room_ready"] = true
	if index >= 3:
		state["office_boss_room_hacked"] = true
		state["office_boss_room_visited"] = true
	if index >= 4:
		state["office_boss_card_collected"] = true
		state["office_npc_left_for_data_center"] = true
		state["office_data_center_task_active"] = true
		state["office_data_center_task_completed"] = true
	if index >= 5:
		state["data_center_card_delivered"] = true
		state["data_center_card_dialog_finished"] = true
		state["data_center_power_outage"] = true
		state["data_center_time_reduced"] = true
		state["data_center_power_dialog_finished"] = true
		state["data_center_tools_floor_task_active"] = true
	if index >= 6:
		state["data_center_flashlight_collected"] = true
		state["data_center_tools_floor_task_completed"] = true
	if index >= 7:
		state["data_center_breaker_restored"] = true
		state["data_center_time_restored"] = true
		state["data_center_return_task_completed"] = true
		state["data_center_access_plan_finished"] = true
		state["data_center_access_npc_arrived"] = true
		state["data_center_access_strong_card_given"] = true
	if index >= 8:
		state["data_center_access_strong_card_failed"] = true
		state["data_center_access_boss_card_given"] = true
		state["data_center_access_boss_card_failed"] = true
		state["data_center_rfid_inspection_task_active"] = true
	if index >= 9:
		state["data_center_rfid_wires_task_active"] = true
	if index >= 10:
		state["data_center_rfid_wires_repaired"] = true
	if index >= 11:
		state["data_center_rfid_reader_rechecked"] = true
		state["data_center_rfid_reading_task_active"] = true
	if index >= 12:
		state["data_center_rfid_minigame_completed"] = true
		state["data_center_rfid_reading_checked"] = true
	if index == 12:
		state["cooling_opportunity_triggered"] = true
		state["cooling_optional_task_active"] = true
	if index >= 13:
		state["data_center_forte_intro_seen"] = true
		state["programmer_ending_started"] = true
		state["programmer_confrontation_started"] = true
		state["programmer_confrontation_seen"] = true
	if index >= 14:
		state["programmer_launch_isolated"] = true
		state["programmer_launch_exchange_seen"] = true
	if index >= 15:
		state["programmer_neural_completed"] = true
		state["programmer_neural_resistance_seen"] = true
	if index >= 16:
		state["programmer_laws_completed"] = true
		state["programmer_validation_completed"] = true
		state["programmer_laws_dialog_seen"] = true
	return state


func _world_state(index: int, mission: Dictionary) -> Dictionary:
	var world := {"__global": {"hall_quest_01": mission}}
	if index >= 2:
		world[OFFICE] = {"laptop_sala_escritorio": true, "cabo_sala_escritorio": true}
	if index >= 4:
		world[BOSS_ROOM] = {"cartao_chefe_sala_chefe": true}
	if index >= 6:
		world[DATA_CENTER] = {"data_center_flashlight": true}
	if index >= 7:
		world[TOOLS_FLOOR] = {"dijuntor_principal": true}
	return world


func _inventory(index: int) -> Dictionary:
	var items: Dictionary = {}
	if index >= 2:
		items["laptop"] = {"scene_path": "res://Objects/laptop.tscn"}
		items["cabo"] = {"scene_path": "res://Objects/cabo.tscn"}
	if index == 4:
		items["cartao"] = {"scene_path": "res://Objects/cartao_chefe.tscn"}
	if index >= 6:
		items["lanterna"] = {"scene_path": "res://Objects/Lanterna.tscn"}
	return items


func restore_real_save() -> void:
	_close_menu()
	get_tree().paused = false
	if get_tree().has_meta(&"dev_mission_jump_active"):
		get_tree().remove_meta(&"dev_mission_jump_active")
	active_stage = -1
	indicator.hide()
	MusicController.stop_all_audio()
	SaveGame.checkpoint_scene_path = ""
	SaveGame._load()
	SaveLoad._load()
	if SaveGame.has_checkpoint():
		SaveGame.load_last_checkpoint()
	else:
		SaveGame.save_data.clear()
		SaveGame.checkpoint_world_state.clear()
		SaveGame.tempo_atual = -1.0
		SaveGame.tempo_restante = -1.0
		scene_manager.player = null
		get_tree().change_scene_to_file(SaveGame.MAIN_MENU_SCENE)
