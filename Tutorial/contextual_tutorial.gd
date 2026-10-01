extends CanvasLayer

const SEEN_KEY := "contextual_tutorial_seen"
const SLOW_SCALE := 0.25
const FADE_DURATION := 0.3
const GAP_DURATION := 0.8

@onready var panel: PanelContainer = $Panel
@onready var title: Label = $Panel/Content/Title
@onready var explanation: Label = $Panel/Content/Explanation

var player: Player
var pending: Array[String] = []
var active_lesson := ""
var elapsed := 0.0
var minimum_reading_time := 3.0
var maximum_reading_time := 8.0
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


func _ready() -> void:
	last_tick = Time.get_ticks_usec()
	get_tree().scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	_release_slow_motion()


func _on_scene_changed() -> void:
	cancel_current()
	pending.clear()
	player = null
	available_time = 0.0


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
	if player.objeto_manipulado != null or not player.objetos_grab_left.is_empty() or not player.objetos_grab_right.is_empty():
		_queue("push", true)
	if player.usando_extintor:
		_queue("extinguisher", true)
	elif player.usando_lanterna:
		_queue("flashlight", true)
	elif player.usando_arma:
		var gun := inventory.get_item_control("gun")
		_queue("weapon", true)
		if _seen("weapon") and int(gun.current_ammo) < int(gun.MAGAZINE_SIZE):
			_queue("reload", true)
		if _seen("weapon") and inventory.get_item_on_inventary("lanterna"):
			_queue("weapon_flashlight")
	var card := inventory.get_item_control("cartao")
	if card != null:
		_queue("card_%d" % int(card.tipo))
	if inventory.get_item_on_inventary("lanterna"):
		_queue("flashlight")
	if inventory.get_item_on_inventary("extintor"):
		_queue("extinguisher")
	if inventory.get_item_on_inventary("laptop"):
		_queue("laptop")
	if inventory.get_item_on_inventary("cabo"):
		_queue("cable")
	if not _seen("walk"):
		_queue("walk")
	elif not _seen("run") and player.direction != Vector2.ZERO:
		_queue("run")
	elif _seen("run") and bool(player.get_node("QUEST_MISSION")._auto_hidden):
		_queue("tasks")


func _relevant(id: String) -> bool:
	var inventory := player.inventory
	match id:
		"weapon", "reload", "weapon_flashlight":
			return player.usando_arma
		"flashlight":
			return inventory.get_item_on_inventary("lanterna")
		"extinguisher":
			return inventory.get_item_on_inventary("extintor")
		"laptop":
			return inventory.get_item_on_inventary("laptop")
		"cable":
			return inventory.get_item_on_inventary("cabo")
		"push":
			return player.objeto_manipulado != null or not player.objetos_grab_left.is_empty() or not player.objetos_grab_right.is_empty()
	if id.begins_with("card_"):
		var card := inventory.get_item_control("cartao")
		return card != null and int(card.tipo) == int(id.trim_prefix("card_"))
	return true


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
	starting_position = player.global_position
	var gun := player.inventory.get_item_control("gun")
	baseline_ammo = int(gun.current_ammo) if gun != null else 0
	baseline_collected_count = player.inventory.get_save_state().size()
	var content := _content(id)
	title.text = content[0]
	explanation.text = content[1]
	minimum_reading_time = clampf(float(explanation.text.length()) / 45.0, 3.0, 6.5)
	panel.accessibility_name = title.text + ". " + explanation.text
	var factor := 1.1 if int(Configs.configs.get("interface_size", 0)) == 2 else 1.0
	title.add_theme_font_size_override("font_size", int(round(12.0 * factor)))
	explanation.add_theme_font_size_override("font_size", int(round(10.0 * factor)))
	panel.modulate.a = 0.0
	panel.show()
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(panel.accessibility_name)
	_acquire_slow_motion()


func _update_lesson(real_delta: float) -> void:
	if not owns_slow_motion:
		if available_time < 0.6:
			return
		_acquire_slow_motion()
		panel.show()
	elapsed += real_delta
	practiced = practiced or _action_practiced()
	if not finishing and elapsed >= minimum_reading_time and (practiced or elapsed >= maximum_reading_time):
		finishing = true
		elapsed = 0.0
	if finishing:
		var progress := clampf(elapsed / FADE_DURATION, 0.0, 1.0)
		panel.modulate.a = 1.0 - progress
		_set_owned_scale(lerpf(previous_scale * SLOW_SCALE, previous_scale, progress))
		if not owns_slow_motion:
			return
		if progress >= 1.0:
			_complete_lesson()
	else:
		panel.modulate.a = minf(1.0, elapsed / FADE_DURATION)
		_set_owned_scale(lerpf(previous_scale, previous_scale * SLOW_SCALE, minf(1.0, elapsed / FADE_DURATION)))


func _action_practiced() -> bool:
	var inventory := player.inventory
	match active_lesson:
		"walk":
			return player.global_position.distance_to(starting_position) >= 3.0
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
		"laptop":
			return player.usando_laptop
		"cable":
			return player.usando_cabo
		"tasks":
			return Input.is_action_pressed("show_tasks")
	return active_lesson.begins_with("card_") and player.usando_cartao


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
	panel.hide()


func cancel_current() -> void:
	_release_slow_motion()
	panel.hide()
	active_lesson = ""
	finishing = false
	practiced = false


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
			return ["EMPURRAR E PUXAR", "Sem item equipado, aperte %s ao lado do objeto. Ande para empurrar ou puxar; aperte novamente para soltar." % _key("empurrar")]
		"collect":
			return ["COLETAR ITENS", "Aproxime-se e aperte %s para coletar. A tecla abaixo de cada item no inventário permite equipá-lo ou guardá-lo." % _key("interact")]
		"card_1":
			return ["CARTÃO COMUM", "Use %s para equipar o cartão e %s junto ao leitor. Este cartão abre acessos comuns, mas não áreas restritas." % [_key("use_cartao"), _key("interact")]]
		"card_2":
			return ["CARTÃO DE ACESSO RESTRITO", "Este cartão substitui o comum e abre acessos de nível maior. Equipe com %s e use %s junto ao leitor." % [_key("use_cartao"), _key("interact")]]
		"card_3":
			return ["CARTÃO DO CHEFE", "Maior nível de acesso. Equipe com %s e use %s no leitor. O programador também precisa dele para aplicar as alterações finais." % [_key("use_cartao"), _key("interact")]]
		"flashlight":
			return ["LANTERNA", "Equipe ou guarde com %s. Aponte com o mouse e use %s para acender ou apagar." % [_key("use_lanterna"), _key("acende_lanterna")]]
		"extinguisher":
			return ["EXTINTOR", "Equipe com %s. Mire no fogo e segure %s para apagá-lo. O extintor tem carga limitada: acompanhe a barra." % [_key("use_extintor"), _key("usar_extintor")]]
		"weapon":
			return ["ARMA", "Mire com o mouse e atire com %s. São 7 balas; recarregue com %s. Atire nos drones: atingir um NPC reinicia o checkpoint." % [_key("fire"), _key("reload")]]
		"reload":
			return ["RECARREGAR", "Aperte %s para recarregar usando a munição da reserva. Espere a recarga terminar antes de atirar." % _key("reload")]
		"weapon_flashlight":
			return ["ARMA E LANTERNA", "Com a arma equipada, use %s para acender a lanterna. Você pode iluminar e atirar ao mesmo tempo." % _key("use_lanterna")]
		"laptop":
			return ["NOTEBOOK", "Equipe com %s e use %s perto do equipamento que precisa acessar ou verificar." % [_key("use_laptop"), _key("interact")]]
		"cable":
			return ["CABO", "Equipe com %s e use %s no ponto indicado pela tarefa para conectar o equipamento." % [_key("use_cabo"), _key("interact")]]
		"tasks":
			return ["SUAS TAREFAS", "Use %s para mostrar o painel de tarefas novamente. Nas configurações, você pode deixá-lo sempre visível." % _key("show_tasks")]
	return ["", ""]
