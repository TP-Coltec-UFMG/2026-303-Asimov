extends CanvasLayer

const SEEN_KEY := "contextual_tutorial_seen"
const SLOW_SCALE := 0.25
const FADE_DURATION := 0.45
const ENTER_DURATION := 0.6
const MUSIC_FADE_DURATION := 0.65
const TUTORIAL_MUSIC_FACTOR := 0.35
const PANEL_WIDTH := 250.0
const WALK_ACTIONS: Array[StringName] = [&"up", &"left", &"down", &"right"]
const GAP_DURATION := 0.8
const UNFOCUSED_OPACITY := 0.15

@onready var panel: Panel = $Panel
@onready var title: Label = $Panel/Content/Title
@onready var explanation: RichTextLabel = $Panel/Content/Explanation

var player: Player
var pending: Array[String] = []
var active_lesson := ""
var elapsed := 0.0
var minimum_reading_time := ENTER_DURATION
var maximum_reading_time := 10.0
var finishing := false
var practiced := false
var starting_position := Vector2.ZERO
var baseline_ammo := 0
var previous_scale := 1.0
var owned_scale := 1.0
var owns_slow_motion := false
var last_tick := 0
var scan_elapsed := 0.0
var available_time := 0.0
var gap := 0.0
var lesson_player_id := 0
var collected_count := 0
var baseline_collected_count := 0
var observed_player_id := 0
var attention_targets: Array[Dictionary] = []
var attention_panel: QuestMissionUI
var attention_tasks_focused := false
var attention_tween: Tween
var attention_amount := 0.0
var attention_active := false
var glow_tween: Tween
var glow_style: StyleBoxFlat
var panel_tween: Tween
var panel_rest_position := Vector2.ZERO
var music_tween: Tween
var music_duck_active := false
var action_was_active := false
var walk_actions_pressed: Array[StringName] = []


func _ready() -> void:
	last_tick = Time.get_ticks_usec()
	glow_style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel.add_theme_stylebox_override("panel", glow_style)
	get_tree().scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	_release_slow_motion()
	_restore_attention(true)
	_stop_glow()
	_set_music_duck(false, true)
	_stop_panel_motion()


func _on_scene_changed() -> void:
	cancel_current()
	_restore_attention(true)
	_set_music_duck(false, true)
	pending.clear()
	player = null
	available_time = 0.0


func start_new_game() -> void:
	_on_scene_changed()
	gap = 0.0
	scan_elapsed = 0.0
	observed_player_id = 0
	Configs.configs[SEEN_KEY] = {}
	SaveLoad._save()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := minf(float(now - last_tick) / 1000000.0, 0.1)
	last_tick = now
	if not _gameplay_available():
		_suspend()
		available_time = 0.0
		return
	available_time += real_delta
	if not active_lesson.is_empty() and lesson_player_id != player.get_instance_id():
		cancel_current()
	if not active_lesson.is_empty():
		_update_lesson(real_delta)
		return
	gap = maxf(0.0, gap - real_delta)
	scan_elapsed += real_delta
	if scan_elapsed < 0.1 or available_time < 0.6:
		return
	scan_elapsed = 0.0
	_discover_lessons()
	if gap <= 0.0:
		_start_next()


func _gameplay_available() -> bool:
	var scene := get_tree().current_scene
	if not scene is BaseScene or get_tree().paused or DialogManager.is_showing_dialog:
		return false
	if not is_instance_valid(player) or not scene.is_ancestor_of(player):
		player = scene.get_scene_player()
	if not is_instance_valid(player):
		return false
	if not player.can_process() or not player.is_physics_processing() or not player.is_processing_input():
		return false
	if not player.is_visible_in_tree() or player.npc_warning_active:
		return false
	if get_tree().get_first_node_in_group(&"opening_gameplay_blur") != null:
		return false
	var camera := get_viewport().get_camera_2d()
	return camera == player.camera_2d


func _seen(id: String) -> bool:
	var seen: Variant = Configs.configs.get(SEEN_KEY, {})
	return seen is Dictionary and bool(seen.get(id, false))


func _queue(id: String, urgent: bool = false) -> void:
	if id == active_lesson or id in pending or _seen(id):
		return
	if id == "push" and not _push_lesson_unlocked():
		return
	if urgent:
		pending.push_front(id)
	else:
		pending.append(id)


func _discover_lessons() -> void:
	var inventory := player.inventory
	var count := inventory.get_save_state().size()
	if observed_player_id != player.get_instance_id():
		collected_count = count
		observed_player_id = player.get_instance_id()
	if count > collected_count:
		_queue("collect")
	collected_count = count
	var interaction := player.get_node_or_null("InteractiongComponent")
	if interaction != null:
		for area: Area2D in interaction.current_interactions:
			if is_instance_valid(area) and area.is_interactable and area.get_parent().get_node_or_null("PickupComponent") != null:
				_queue("collect")
				break
	if player.objeto_manipulado != null or player.has_grab_object_nearby():
		_queue("push", true)
	if player.usando_extintor:
		_queue("extinguisher", true)
	elif player.usando_lanterna:
		_queue("flashlight", true)
	elif player.usando_arma:
		var gun := inventory.get_item_control("gun")
		_queue("weapon", true)
		if _seen("weapon") and int(gun.current_ammo) <= 0:
			_queue("reload", true)
		if _seen("weapon") and inventory.get_item_on_inventary("lanterna"):
			_queue("weapon_flashlight")
	var card := inventory.get_item_control("cartao")
	if card != null:
		_queue("card_%d" % int(card.tipo))
	if inventory.get_item_on_inventary("lanterna"):
		_queue("flashlight")
	if not _seen("walk"):
		_queue("walk")
	elif not _seen("run") and player.direction != Vector2.ZERO:
		_queue("run")
	if bool(player.get_node("QUEST_MISSION")._auto_hidden):
		_queue("tasks", true)


func _relevant(id: String) -> bool:
	var inventory := player.inventory
	match id:
		"reload":
			var gun := inventory.get_item_control("gun")
			return player.usando_arma and gun != null and int(gun.current_ammo) <= 0
		"weapon", "weapon_flashlight":
			return player.usando_arma
		"flashlight":
			return inventory.get_item_on_inventary("lanterna")
		"extinguisher":
			return player.usando_extintor
		"tasks":
			return bool(player.get_node("QUEST_MISSION")._auto_hidden)
		"push":
			return _push_lesson_unlocked() and (player.objeto_manipulado != null or player.has_grab_object_nearby())
	if id.begins_with("card_"):
		var card := inventory.get_item_control("cartao")
		return card != null and int(card.tipo) == int(id.trim_prefix("card_"))
	return true


func _push_lesson_unlocked() -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path == "res://Scenes/andar_hall.tscn":
		var quest := scene.get_node_or_null("QuestController")
		return quest != null and bool(quest.M1_feito)
	var hall: Variant = SaveGame.save_data.get("res://Scenes/andar_hall.tscn", {})
	if not hall is Dictionary:
		return false
	var mission: Variant = hall.get("hall_quest_01", {})
	return mission is Dictionary and bool(mission.get("task_fire_done", false))


func _start_next() -> void:
	while not pending.is_empty():
		var id: String = pending.pop_front()
		if not _seen(id) and _relevant(id):
			_begin_lesson(id)
			return


func _begin_lesson(id: String) -> void:
	active_lesson = id
	lesson_player_id = player.get_instance_id()
	elapsed = 0.0
	finishing = false
	practiced = false
	walk_actions_pressed.clear()
	starting_position = player.global_position
	var gun := player.inventory.get_item_control("gun")
	baseline_ammo = int(gun.current_ammo) if gun != null else 0
	baseline_collected_count = player.inventory.get_save_state().size()
	var content := _content(id)
	title.text = content[0]
	explanation.text = "[center]" + content[1] + "[/center]"
	minimum_reading_time = ENTER_DURATION
	panel.accessibility_name = title.text + ". " + content[1]
	var factor := 1.1 if int(Configs.configs.get("interface_size", 0)) == 2 else 1.0
	title.add_theme_font_size_override("font_size", int(round(12.0 * factor)))
	for font_size_name in ["normal_font_size", "bold_font_size"]:
		explanation.add_theme_font_size_override(font_size_name, int(round(10.0 * factor)))
	action_was_active = _action_practiced()
	_animate_panel(true)
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(panel.accessibility_name)
	_acquire_slow_motion()
	_start_attention()
	_start_glow()
	_set_music_duck(true)


func _update_lesson(real_delta: float) -> void:
	if not owns_slow_motion:
		if available_time < 0.6:
			return
		_acquire_slow_motion()
		if not finishing:
			_animate_panel(true)
			_start_attention()
			_start_glow()
			_set_music_duck(true)
	elapsed += real_delta
	var action_active := _action_practiced()
	practiced = practiced or (action_active and not action_was_active)
	action_was_active = action_active
	if not finishing and elapsed >= minimum_reading_time and (practiced or elapsed >= maximum_reading_time):
		finishing = true
		elapsed = 0.0
		_restore_attention()
		_stop_glow()
		_animate_panel(false)
		_set_music_duck(false)
	if finishing:
		var progress := clampf(elapsed / FADE_DURATION, 0.0, 1.0)
		_set_owned_scale(lerpf(previous_scale * SLOW_SCALE, previous_scale, progress))
		if not owns_slow_motion:
			return
		if progress >= 1.0:
			_complete_lesson()
	else:
		_set_owned_scale(lerpf(previous_scale, previous_scale * SLOW_SCALE, minf(1.0, elapsed / FADE_DURATION)))


func _input(event: InputEvent) -> void:
	if active_lesson.is_empty() or finishing or not owns_slow_motion:
		return
	if not _gameplay_available():
		return
	if event is InputEventKey and event.echo:
		return
	if active_lesson == "walk":
		for action: StringName in WALK_ACTIONS:
			if event.is_action_pressed(action) and action not in walk_actions_pressed:
				walk_actions_pressed.append(action)
		_refresh_walk_text()
		practiced = walk_actions_pressed.size() == WALK_ACTIONS.size()
		return
	var actions: Array[StringName] = []
	match active_lesson:
		"run":
			actions.append(&"correr")
		"push":
			actions.append(&"empurrar")
		"collect":
			actions.append(&"interact")
		"flashlight":
			actions.assign([&"use_lanterna", &"acende_lanterna"])
		"extinguisher":
			actions.append(&"usar_extintor")
		"weapon":
			actions.append(&"fire")
		"reload":
			actions.append(&"reload")
		"weapon_flashlight":
			actions.append(&"use_lanterna")
		"tasks":
			actions.append(&"show_tasks")
	if active_lesson.begins_with("card_"):
		actions.assign([&"use_cartao", &"interact"])
	for action: StringName in actions:
		if event.is_action_pressed(action):
			practiced = true
			return


func _action_practiced() -> bool:
	var inventory := player.inventory
	match active_lesson:
		"walk":
			return walk_actions_pressed.size() == WALK_ACTIONS.size()
		"run":
			return player.correndo
		"push":
			return player.objeto_manipulado != null and player.global_position.distance_to(starting_position) >= 3.0
		"collect":
			return inventory.get_save_state().size() > baseline_collected_count
		"flashlight":
			var lamp := inventory.get_item_control("lanterna")
			return lamp != null and bool(lamp.lanterna_acessa)
		"extinguisher":
			var extinguisher := inventory.get_item_control("extintor")
			return extinguisher != null and bool(extinguisher.extintor_ligado)
		"weapon":
			var gun := inventory.get_item_control("gun")
			return gun != null and int(gun.current_ammo) < baseline_ammo
		"reload":
			var gun := inventory.get_item_control("gun")
			return gun != null and int(gun.current_ammo) > baseline_ammo
		"weapon_flashlight":
			var lamp := inventory.get_item_control("lanterna")
			return player.usando_arma and lamp != null and bool(lamp.lanterna_acessa)
		"tasks":
			return Input.is_action_pressed("show_tasks")
	return active_lesson.begins_with("card_") and player.usando_cartao


func _refresh_walk_text() -> void:
	var keys: Array[String] = []
	for action: StringName in WALK_ACTIONS:
		var key := _key(action).replace("[", "[lb]")
		keys.append("[b]" + key + "[/b]" if action in walk_actions_pressed else key)
	explanation.text = "[center]Use %s para andar pelo cenário.[/center]" % "/".join(keys)


func _complete_lesson() -> void:
	var saved: Variant = Configs.configs.get(SEEN_KEY, {})
	var seen: Dictionary = saved.duplicate() if saved is Dictionary else {}
	seen[active_lesson] = true
	Configs.configs[SEEN_KEY] = seen
	SaveLoad._save()
	cancel_current()
	gap = GAP_DURATION


func _acquire_slow_motion() -> void:
	previous_scale = Engine.time_scale
	owned_scale = previous_scale
	owns_slow_motion = true


func _set_owned_scale(value: float) -> void:
	if not is_equal_approx(Engine.time_scale, owned_scale):
		cancel_current()
		return
	Engine.time_scale = value
	owned_scale = value


func _release_slow_motion() -> void:
	if owns_slow_motion and is_equal_approx(Engine.time_scale, owned_scale):
		Engine.time_scale = previous_scale
	owns_slow_motion = false


func _suspend() -> void:
	_release_slow_motion()
	_stop_panel_motion()
	panel.hide()
	_restore_attention()
	_stop_glow()
	_set_music_duck(false)


func cancel_current() -> void:
	_release_slow_motion()
	_stop_panel_motion()
	panel.hide()
	_restore_attention()
	_stop_glow()
	_set_music_duck(false)
	active_lesson = ""
	finishing = false
	practiced = false


func _panel_destination() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var margin := 14.0
	var destination := Vector2((viewport_size.x - panel.size.x) * 0.5, margin)
	match active_lesson:
		"run":
			destination.x = viewport_size.x - panel.size.x - margin
		"tasks", "weapon", "reload", "weapon_flashlight":
			destination.x = margin
	destination.x = clampf(destination.x, margin, maxf(margin, viewport_size.x - panel.size.x - margin))
	return destination


func _animate_panel(entering: bool) -> void:
	_stop_panel_motion()
	if entering:
		var style := panel.get_theme_stylebox("panel")
		var content_width := PANEL_WIDTH - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
		title.size.x = content_width
		explanation.size.x = content_width
		var font_size := explanation.get_theme_font_size("normal_font_size")
		var plain_text := explanation.get_parsed_text()
		var body_height := explanation.get_theme_font("normal_font").get_multiline_string_size(plain_text, HORIZONTAL_ALIGNMENT_CENTER, content_width, font_size).y
		if active_lesson == "walk":
			body_height = maxf(body_height, explanation.get_theme_font("bold_font").get_multiline_string_size(plain_text, HORIZONTAL_ALIGNMENT_CENTER, content_width, font_size).y)
		var title_height := title.get_theme_font("font").get_height(title.get_theme_font_size("font_size"))
		var content := panel.get_node("Content") as VBoxContainer
		var height := title_height + body_height + content.get_theme_constant("separation") + style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
		panel.size = Vector2(PANEL_WIDTH, ceilf(height))
		panel_rest_position = _panel_destination()
		panel.pivot_offset = panel.size * 0.5
		panel.position = panel_rest_position - Vector2(0.0, 12.0)
		panel.scale = Vector2.ONE * 0.94
		panel.modulate.a = 0.0
		panel.show()
	panel_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if entering else Tween.EASE_IN)
	var duration := ENTER_DURATION if entering else FADE_DURATION
	panel_tween.tween_property(panel, "position", panel_rest_position if entering else panel_rest_position - Vector2(0.0, 8.0), duration)
	panel_tween.tween_property(panel, "scale", Vector2.ONE if entering else Vector2.ONE * 0.98, duration)
	panel_tween.tween_property(panel, "modulate:a", 1.0 if entering else 0.0, duration).set_trans(Tween.TRANS_SINE)


func _stop_panel_motion() -> void:
	if panel_tween != null and panel_tween.is_valid():
		panel_tween.kill()
	panel_tween = null


func _set_music_duck(active: bool, immediate: bool = false) -> void:
	if not immediate and music_duck_active == active:
		return
	music_duck_active = active
	if music_tween != null and music_tween.is_valid():
		music_tween.kill()
	music_tween = null
	if not is_instance_valid(MusicController):
		return
	var target_factor := TUTORIAL_MUSIC_FACTOR if active else 1.0
	if immediate:
		_apply_tutorial_music(target_factor)
		return
	music_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	music_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	music_tween.tween_method(_apply_tutorial_music, MusicController.tutorial_music_factor, target_factor, MUSIC_FADE_DURATION)


func _apply_tutorial_music(factor: float) -> void:
	if not is_instance_valid(MusicController):
		return
	MusicController.set_tutorial_music_factor(factor)


func _start_attention() -> void:
	_restore_attention(true)
	var hud := player.get_node("CanvasLayer/Control")
	for element in hud.get_children():
		if element is CanvasItem:
			_add_attention_target(element, active_lesson == "run" and element.name == &"estamina")
	for item_id: String in player.inventory.slots_por_item:
		var focused := active_lesson == "collect"
		match active_lesson:
			"weapon", "reload":
				focused = item_id == "gun"
			"weapon_flashlight":
				focused = item_id in ["gun", "lanterna"]
			"flashlight":
				focused = item_id == "lanterna"
			"extinguisher":
				focused = item_id == "extintor"
		if active_lesson.begins_with("card_"):
			focused = item_id == "cartao"
		_add_attention_target(player.inventory.slots_por_item[item_id], focused)
	_add_attention_target(player.get_node("CanvasLayer/AmmoPanel"), active_lesson in ["weapon", "reload", "weapon_flashlight"])
	_add_attention_target(player.get_node("CanvasLayer/AlarmTip"), false, ^"self_modulate:a")
	var scene := get_tree().current_scene
	if scene != null:
		_add_attention_target(scene.get_node_or_null("UI/Controle_de_tempo"), false)
	attention_panel = player.get_node("QUEST_MISSION") as QuestMissionUI
	attention_tasks_focused = active_lesson == "tasks"
	attention_active = true
	attention_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attention_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	attention_tween.tween_method(_apply_attention, 0.0, 1.0, FADE_DURATION)


func _add_attention_target(node: Node, focused: bool, property: NodePath = ^"modulate:a") -> void:
	if not node is CanvasItem:
		return
	attention_targets.append({"node": node, "property": property, "original": node.get_indexed(property), "focused": focused})


func _apply_attention(amount: float) -> void:
	attention_amount = amount
	for target: Dictionary in attention_targets:
		var node: Object = target["node"]
		if is_instance_valid(node):
			var original: float = target["original"]
			var factor := 1.0 if bool(target["focused"]) else UNFOCUSED_OPACITY
			node.set_indexed(target["property"], original * lerpf(1.0, factor, amount))
	if is_instance_valid(attention_panel):
		var factor := 1.0 if attention_tasks_focused else UNFOCUSED_OPACITY
		attention_panel.set_tutorial_opacity(lerpf(1.0, factor, amount))


func _restore_attention(immediate: bool = false) -> void:
	if not attention_active and not immediate:
		return
	attention_active = false
	if attention_tween != null and attention_tween.is_valid():
		attention_tween.kill()
	attention_tween = null
	if immediate:
		_apply_attention(0.0)
		attention_targets.clear()
		attention_panel = null
		return
	attention_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	attention_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	attention_tween.tween_method(_apply_attention, attention_amount, 0.0, FADE_DURATION)
	attention_tween.tween_callback(func() -> void:
		attention_targets.clear()
		attention_panel = null
	)


func _start_glow() -> void:
	_stop_glow()
	glow_tween = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_property(glow_style, "shadow_color:a", 0.85, 0.9)
	glow_tween.tween_property(glow_style, "shadow_color:a", 0.45, 0.9)


func _stop_glow() -> void:
	if glow_tween != null and glow_tween.is_valid():
		glow_tween.kill()
	glow_tween = null


func protects_player(candidate: Player) -> bool:
	return candidate == player and owns_slow_motion and not active_lesson.is_empty()


func _key(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "tecla não definida"
	var event: InputEvent = events[0]
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return "clique esquerdo"
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return "clique direito"
	return event.as_text()


func _content(id: String) -> Array[String]:
	match id:
		"walk":
			return ["MOVIMENTO", "Use %s/%s/%s/%s para andar pelo cenário." % [_key("up"), _key("left"), _key("down"), _key("right")]]
		"run":
			return ["CORRIDA", "Segure %s enquanto anda. Correr gasta estamina; caminhar permite recuperá-la." % _key("correr")]
		"push":
			return ["EMPURRAR E PUXAR", "Sem item equipado, aperte %s junto do objeto. Mova-o nas quatro direções; aperte novamente para soltar." % _key("empurrar")]
		"collect":
			return ["COLETAR ITENS", "Aproxime-se e aperte %s para coletar. A tecla abaixo de cada item no inventário permite equipá-lo ou guardá-lo." % _key("interact")]
		"card_1":
			return ["CARTÃO COMUM", "Abre acessos comuns. Equipe com %s e aperte %s junto ao leitor." % [_key("use_cartao"), _key("interact")]]
		"card_2":
			return ["CARTÃO DE ACESSO RESTRITO", "Abre áreas restritas. Equipe com %s e aperte %s junto ao leitor." % [_key("use_cartao"), _key("interact")]]
		"card_3":
			return ["CARTÃO DO CHEFE", "Tem o maior nível de acesso. Equipe com %s e aperte %s junto ao leitor." % [_key("use_cartao"), _key("interact")]]
		"flashlight":
			return ["LANTERNA", "Equipe ou guarde com %s. Aponte com o mouse e use %s para acender ou apagar." % [_key("use_lanterna"), _key("acende_lanterna")]]
		"extinguisher":
			return ["EXTINTOR", "Mire no fogo e segure %s para apagá-lo. A barra mostra a carga restante. Aperte %s para guardar o extintor." % [_key("usar_extintor"), _key("use_extintor")]]
		"weapon":
			return ["ARMA", "Equipe com %s, mire com o mouse e atire com %s. Não atire em NPCs." % [_key("use_arma"), _key("fire")]]
		"reload":
			return ["RECARREGAR", "Aperte %s para recarregar. É preciso ter munição na reserva." % _key("reload")]
		"weapon_flashlight":
			return ["ARMA E LANTERNA", "Com a arma equipada, use %s para acender a lanterna. Você pode iluminar e atirar ao mesmo tempo." % _key("use_lanterna")]
		"tasks":
			return ["SUAS TAREFAS", "O painel ficou oculto. Aperte %s para mostrá-lo novamente e conferir sua próxima tarefa." % _key("show_tasks")]
	return ["", ""]
