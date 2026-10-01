extends Node2D

enum Stage { MOVE, RUN, PUSH, COLLECT, CARD_STANDARD, CARD_STRONG, CARD_BOSS, LIGHT, FIRE, WEAPON, COMPLETE }

const CHARACTER_SELECTION_SCENE := "res://Scenes/slectionpage.tscn"
const MAIN_MENU_SCENE := "res://Scenes/principal.tscn"
const ROOM_BOUNDS: Array[Vector2] = [Vector2(-160, -90), Vector2(160, 90)]
const ROOMS: Array[PackedScene] = [
	preload("res://Tutorial/Rooms/01_movement.tscn"),
	preload("res://Tutorial/Rooms/02_running.tscn"),
	preload("res://Tutorial/Rooms/03_push_pull.tscn"),
	preload("res://Tutorial/Rooms/04_inventory.tscn"),
	preload("res://Tutorial/Rooms/05_standard_card.tscn"),
	preload("res://Tutorial/Rooms/06_restricted_card.tscn"),
	preload("res://Tutorial/Rooms/07_boss_card.tscn"),
	preload("res://Tutorial/Rooms/08_flashlight.tscn"),
	preload("res://Tutorial/Rooms/09_extinguisher.tscn"),
	preload("res://Tutorial/Rooms/10_weapon.tscn")
]
const ITEMS := {
	"laptop": preload("res://Objects/laptop.tscn"),
	"cabo": preload("res://Objects/cabo.tscn"),
	"lanterna": preload("res://Objects/Lanterna.tscn"),
	"extintor": preload("res://Objects/extintor.tscn"),
	"gun": preload("res://Objects/arma.tscn")
}
const CARDS: Array[PackedScene] = [preload("res://Objects/cartao_padrao.tscn"), preload("res://Objects/cartao_forte.tscn"), preload("res://Objects/cartao_chefe.tscn")]
const FIRE := preload("res://Objects/fogo.tscn")
const TARGET := preload("res://Tutorial/training_target.tscn")

@onready var player: Player = $TrainingPlayer
@onready var training_light: CanvasModulate = $TrainingLight
@onready var progress_label: Label = $UI/HUD/ObjectivePanel/Content/Progress
@onready var title_label: Label = $UI/HUD/ObjectivePanel/Content/Title
@onready var objective_label: Label = $UI/HUD/ObjectivePanel/Content/Objective
@onready var hint_label: Label = $UI/HUD/ObjectivePanel/Content/Hint
@onready var feedback_label: Label = $UI/HUD/Feedback
@onready var pause_overlay: Control = $UI/PauseOverlay
@onready var resume_button: Button = $UI/PauseOverlay/Panel/Content/Resume
@onready var completion_overlay: Control = $UI/CompletionOverlay
@onready var completion_continue: Button = $UI/CompletionOverlay/Panel/Content/Actions/Continue
@onready var fade: ColorRect = $UI/RoomFade

var current_stage: Stage = Stage.MOVE
var room: Node2D
var stage_complete := false
var transition_locked := false
var tutorial_paused := false
var push_reached := false
var pull_distance := 0.0
var last_crate_x := 0.0
var was_holding := false
var collected: Dictionary = {}
var notebook_equipped := false
var cable_equipped := false
var flashlight_used := false
var weapon_reloaded := false
var shots_before_reload := 0
var target_hits := 0
var last_gun_ammo := 7
var reload_started := false
var target: StaticBody2D
var training_fire: Node2D
var fire_percent := -1


func _enter_tree() -> void:
	GlobalLevelManager.ChangeTilemapBounds(ROOM_BOUNDS)


func _ready() -> void:
	player.checkpoint_enabled = false
	player.starting_gun_enabled = false
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.get_node("InteractiongComponent").process_mode = Node.PROCESS_MODE_PAUSABLE
	player.camera_2d.enabled = false
	$TutorialCamera.make_current()
	for node_path in ["CanvasLayer/Control/Inteligencia", "CanvasLayer/Control/Vida1", "CanvasLayer/Control/Vida2", "CanvasLayer/Control/Vida3", "CanvasLayer/Control/FPSLabel"]:
		player.get_node(node_path).hide()
	player.get_node("CanvasLayer/Control/FPSLabel").set_process(false)
	var stamina := player.get_node("CanvasLayer/Control/estamina") as Control
	stamina.pivot_offset = Vector2.ZERO
	stamina.scale = Vector2(0.55, 0.55)
	stamina.global_position = Vector2(16, 228)
	player.inventory.top_level = true
	player.inventory.global_position = Vector2(0, 82)
	player.inventory.scale = Vector2.ONE / 1.2
	var slots := player.inventory.get_node("GridContainer") as Control
	slots.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	slots.pivot_offset = Vector2.ZERO
	slots.scale = Vector2.ONE
	slots.position = Vector2(-69, 0)
	player.ammo_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	player.ammo_panel.position = Vector2(335, 237)
	player.ammo_panel.size = Vector2(130, 22)
	$UI/PauseOverlay/Panel/Content/Title.text = "TREINAMENTO PAUSADO"
	$UI/PauseOverlay/Panel/Content/Description.text = "Continue de onde parou ou volte ao menu."
	resume_button.text = "CONTINUAR"
	$UI/PauseOverlay/Panel/Content/Menu.text = "MENU PRINCIPAL"
	$UI/CompletionOverlay/Panel/Content/Title.text = "TREINAMENTO CONCLUÍDO"
	$UI/CompletionOverlay/Panel/Content/Actions/Replay.text = "REPETIR"
	resume_button.pressed.connect(_resume_tutorial)
	$UI/PauseOverlay/Panel/Content/Restart.pressed.connect(_restart_room)
	$UI/PauseOverlay/Panel/Content/Menu.pressed.connect(_return_to_main_menu)
	completion_continue.pressed.connect(_finish_tutorial)
	$UI/CompletionOverlay/Panel/Content/Actions/Replay.pressed.connect(_replay_tutorial)
	for button in [resume_button, $UI/PauseOverlay/Panel/Content/Restart, $UI/PauseOverlay/Panel/Content/Menu, completion_continue, $UI/CompletionOverlay/Panel/Content/Actions/Replay]:
		button.focus_entered.connect(func(): _speak(button.text))
	var scale_factor: float = [1.0, 0.9, 1.12][clampi(int(Configs.configs.get("interface_size", 0)), 0, 2)]
	_set_font_size_recursive($UI, scale_factor)
	_load_room(Stage.MOVE)
	await get_tree().process_frame
	_announce_objective()


func _load_room(stage: Stage) -> void:
	player.reset_sprite_player()
	player.soltar_objeto()
	player.velocity = Vector2.ZERO
	player.direction = Vector2.ZERO
	player.cansaco = 0.0
	var interactions := player.get_node("InteractiongComponent")
	interactions._parar_interacao()
	interactions.current_interactions.clear()
	if is_instance_valid(room):
		remove_child(room)
		room.queue_free()
	for bullet in get_children():
		if bullet is CharacterBody2D and bullet != player:
			bullet.queue_free()
	current_stage = stage
	stage_complete = false
	push_reached = false
	pull_distance = 0.0
	was_holding = false
	collected.clear()
	notebook_equipped = false
	cable_equipped = false
	flashlight_used = false
	weapon_reloaded = false
	shots_before_reload = 0
	target_hits = 0
	reload_started = false
	training_fire = null
	target = null
	room = ROOMS[int(stage)].instantiate()
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	player.global_position = Vector2(-122, 30)
	player.reset_physics_interpolation()
	training_light.color = Color.WHITE
	feedback_label.text = ""
	progress_label.text = "SALA %02d / %02d" % [int(stage) + 1, ROOMS.size()]
	title_label.text = room.lesson_title
	hint_label.text = "%s: pausar. A saída abre ao concluir o treino." % _action_labels(&"esc")
	match stage:
		Stage.MOVE:
			room.get_node("Zones/MoveZone").show()
			objective_label.text = "Use %s para chegar ao piso marcado." % _movement_keys_text()
		Stage.RUN:
			room.get_node("Zones/RunZone").show()
			objective_label.text = "Segure %s enquanto anda. Chegue correndo à marca." % _action_labels(&"correr")
			hint_label.text = "Correr gasta estamina. Ela se recupera quando você descansa."
		Stage.PUSH:
			var crate := room.get_node("Props/TargetCrate")
			crate.show()
			crate.process_mode = Node.PROCESS_MODE_INHERIT
			crate.get_node("CollisionShape2D").disabled = false
			crate.get_node("Interectable/CollisionShape2D").disabled = false
			room.get_node("Zones/PushGoal").show()
			last_crate_x = crate.global_position.x
			objective_label.text = "Ao lado da caixa, pressione %s. Empurre até a marca." % _action_labels(&"empurrar")
			hint_label.text = "Você pode empurrar e puxar. Guarde o equipamento antes."
		Stage.COLLECT:
			player.inventory.remove_item("laptop")
			player.inventory.remove_item("cabo")
			_spawn_pickup("laptop", ITEMS.laptop, Vector2(-35, 20), "Notebook")
			_spawn_pickup("cabo", ITEMS.cabo, Vector2(45, 30), "Cabo")
			objective_label.text = "Aproxime-se e pressione %s para coletar o notebook e o cabo." % _action_labels(&"interact")
			hint_label.text = "Os itens ficam nos slots. A tecla de cada item aparece embaixo dele."
		Stage.CARD_STANDARD, Stage.CARD_STRONG, Stage.CARD_BOSS:
			_prepare_card_room()
		Stage.LIGHT:
			player.inventory.remove_item("lanterna")
			_spawn_pickup("lanterna", ITEMS.lanterna, Vector2(-75, 30), "Lanterna")
			room.get_node("Zones/MoveZone").show()
			room.get_node("Props/DarkZoneLabel").show()
			room.get_node("Props/DarkZoneLabel").text = "ILUMINE O CAMINHO"
			training_light.color = Color(0.055, 0.055, 0.065)
			objective_label.text = "Colete a lanterna (%s), equipe (%s) e ilumine a marca." % [_action_labels(&"interact"), _action_labels(&"use_lanterna")]
			hint_label.text = "%s liga/desliga a luz. Aponte com o mouse e chegue à marca com ela acesa." % _action_labels(&"acende_lanterna")
		Stage.FIRE:
			_prepare_fire_room()
		Stage.WEAPON:
			_prepare_weapon_room()
	HighContrast.apply_to_tree(self)
	$TutorialCamera.reset_smoothing()
	$TutorialCamera.force_update_scroll()
	_update_accessible_names()


func _physics_process(_delta: float) -> void:
	if get_tree().paused or transition_locked or current_stage == Stage.COMPLETE:
		return
	if stage_complete:
		if room.get_node("Zones/ExitZone").overlaps_body(player):
			_change_room()
		return
	match current_stage:
		Stage.MOVE:
			if room.get_node("Zones/MoveZone").overlaps_body(player):
				_complete_stage()
		Stage.RUN:
			if room.get_node("Zones/RunZone").overlaps_body(player) and player.correndo and player.velocity.length() > Player.VELOCIDADE_NORMAL:
				_complete_stage()
		Stage.PUSH:
			_update_push()
		Stage.COLLECT:
			_update_inventory()
		Stage.LIGHT:
			var flashlight := player.inventory.get_item_control("lanterna")
			if flashlight != null and player.usando_lanterna and bool(flashlight.get("lanterna_acessa")):
				flashlight_used = true
				if room.get_node("Zones/MoveZone").overlaps_body(player):
					_complete_stage()
		Stage.FIRE:
			_update_fire()
		Stage.WEAPON:
			_update_weapon()


func _complete_stage() -> void:
	if stage_complete:
		return
	stage_complete = true
	room.get_node("Room/Door").color = Color(0.3, 1.0, 0.55)
	room.get_node("Zones/ExitZone").show()
	feedback_label.text = "CONCLUÍDO"
	objective_label.text = "Treino concluído. Vá até a saída à direita."
	hint_label.text = "A próxima sala ensina uma nova mecânica."
	_update_accessible_names()
	_announce_objective()


func _change_room() -> void:
	if transition_locked:
		return
	transition_locked = true
	player.set_physics_process(false)
	player.set_process_input(false)
	player.reset_sprite_player()
	player.velocity = Vector2.ZERO
	player._stop_movement_sfx()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.3)
	await tween.finished
	if current_stage == Stage.WEAPON:
		_complete_tutorial()
		fade.color.a = 0.0
		return
	_load_room((int(current_stage) + 1) as Stage)
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.4)
	await tween.finished
	player.set_physics_process(true)
	player.set_process_input(true)
	transition_locked = false
	_announce_objective()


func _spawn_pickup(item_id: String, packed: PackedScene, position: Vector2, label: String) -> void:
	var pickup := packed.instantiate() as Node2D
	pickup.set("no_inventario", true)
	room.get_node("Props").add_child(pickup)
	pickup.position = position
	var interaction := pickup.get_node("Interectable") as Area2D
	interaction.interact_name = label
	interaction.prompt_font_size = 8
	interaction.interact = _collect_item.bind(pickup, item_id, packed)


func _collect_item(pickup: Node2D, item_id: String, packed: PackedScene) -> void:
	if stage_complete or transition_locked or not is_instance_valid(pickup):
		return
	if player.usando_algum_item():
		hint_label.text = "Guarde o equipamento com a mesma tecla antes de coletar."
		_speak(hint_label.text)
		return
	if not player.inventory.add_item(item_id, packed):
		return
	collected[item_id] = true
	player.get_node("InteractiongComponent")._parar_interacao()
	pickup.get_node("Interectable").is_interactable = false
	pickup.queue_free()
	feedback_label.text = "ITEM COLETADO"
	if current_stage == Stage.COLLECT and collected.has("laptop") and collected.has("cabo"):
		objective_label.text = "Equipe o notebook (%s) e depois o cabo (%s)." % [_action_labels(&"use_laptop"), _action_labels(&"use_cabo")]
		_announce_objective()
	elif item_id == "cartao":
		hint_label.text = "Equipe o cartão (%s), aproxime-se do leitor e use %s." % [_action_labels(&"use_cartao"), _action_labels(&"interact")]
		_speak(hint_label.text)
	elif item_id == "extintor":
		hint_label.text = "Equipe (%s) e segure %s, apontando para o fogo." % [_action_labels(&"use_extintor"), _action_labels(&"usar_extintor")]
		_speak(hint_label.text)


func _update_inventory() -> void:
	if not collected.has("laptop") or not collected.has("cabo"):
		return
	notebook_equipped = notebook_equipped or player.usando_laptop
	cable_equipped = cable_equipped or player.usando_cabo
	if notebook_equipped and cable_equipped:
		_complete_stage()


func _prepare_card_room() -> void:
	var tier := int(current_stage) - int(Stage.CARD_STANDARD) + 1
	player.inventory.remove_item("cartao")
	_spawn_pickup("cartao", CARDS[tier - 1], Vector2(-20, 30), ["Cartão padrão", "Cartão de acesso restrito", "Cartão do chefe"][tier - 1])
	room.get_node("Room/Console").show()
	room.get_node("Room/Console/Marker").text = "LEITOR · NÍVEL %d" % tier
	room.get_node("Room/Console/Marker").show()
	room.get_node("Room/Console/CollisionShape2D").disabled = false
	var interaction := room.get_node("Zones/ConsoleArea")
	interaction.get_node("CollisionShape2D").disabled = false
	interaction.is_interactable = true
	interaction.is_not_object = true
	interaction.interact_name = "Usar cartão"
	interaction.prompt_font_size = 8
	interaction.interact = _use_card
	objective_label.text = "Colete o cartão (%s) e use-o no leitor desta sala." % _action_labels(&"interact")
	hint_label.text = ["Padrão: acesso às áreas comuns. Equipe com %s.", "Restrito: libera áreas protegidas e também as comuns. Equipe com %s.", "Chefe: maior nível de acesso; autoriza operações finais. Equipe com %s."][tier - 1] % _action_labels(&"use_cartao")


func _use_card() -> void:
	if stage_complete or transition_locked:
		return
	var card := player.inventory.get_item_control("cartao")
	var tier := int(current_stage) - int(Stage.CARD_STANDARD) + 1
	if card == null or not player.usando_cartao or int(card.get("tipo")) < tier:
		hint_label.text = "O leitor exige um cartão de nível %d equipado (%s)." % [tier, _action_labels(&"use_cartao")]
		_speak(hint_label.text)
		return
	room.get_node("Room/Console/Screen").color = Color(0.3, 1.0, 0.5)
	_complete_stage()


func _update_push() -> void:
	var crate := room.get_node("Props/TargetCrate") as ObjetoEmpurravel
	var holding := player.objeto_manipulado == crate
	var delta_x := crate.global_position.x - last_crate_x
	last_crate_x = crate.global_position.x
	if holding and not push_reached and room.get_node("Zones/PushGoal").overlaps_body(crate):
		push_reached = true
		objective_label.text = "Agora recue para puxar a caixa um pouco."
		_announce_objective()
	elif holding and push_reached and delta_x * player.lado_objeto_manipulado.x < 0.0:
		pull_distance += absf(delta_x)
		if pull_distance >= 6.0:
			objective_label.text = "Pressione %s novamente para soltar a caixa." % _action_labels(&"empurrar")
	if was_holding and not holding and push_reached and pull_distance >= 6.0:
		_complete_stage()
	was_holding = holding


func _prepare_fire_room() -> void:
	player.inventory.remove_item("extintor")
	_spawn_pickup("extintor", ITEMS.extintor, Vector2(-55, 30), "Extintor")
	training_fire = FIRE.instantiate()
	training_fire.set("save_enabled", false)
	training_fire.set("damage_enabled", false)
	room.get_node("Props").add_child(training_fire)
	training_fire.position = Vector2(70, 30)
	room.get_node("Props/FireLabel").show()
	room.get_node("Props/FireLabel").text = "APAGUE O FOGO"
	fire_percent = -1
	objective_label.text = "Colete o extintor (%s) e apague o fogo." % _action_labels(&"interact")
	hint_label.text = "Equipe com %s. Segure %s e aponte para a base do fogo." % [_action_labels(&"use_extintor"), _action_labels(&"usar_extintor")]


func _update_fire() -> void:
	if bool(training_fire.get("apagado")):
		_complete_stage()
		return
	var extinguisher := player.inventory.get_item_control("extintor")
	if extinguisher != null and bool(extinguisher.get("combustivel_acabou")):
		player.reset_sprite_player()
		extinguisher.set("combustivel", 100.0)
		extinguisher.set("combustivel_acabou", false)
		hint_label.text = "Extintor reabastecido para o treino. Aproxime-se e aponte para o fogo."
	var remaining := int(ceilf(float(training_fire.get("vida_fogo"))))
	if remaining != fire_percent:
		fire_percent = remaining
		feedback_label.text = "FOGO: %d%%" % remaining


func _prepare_weapon_room() -> void:
	player.inventory.remove_item("gun")
	_spawn_pickup("gun", ITEMS.gun, Vector2(-60, 30), "Arma de treino")
	target = TARGET.instantiate()
	room.get_node("Props").add_child(target)
	target.position = Vector2(65, 15)
	target.hit.connect(_on_target_hit)
	last_gun_ammo = 7
	objective_label.text = "Colete a arma (%s), equipe (%s) e acerte o drone-alvo." % [_action_labels(&"interact"), _action_labels(&"use_arma")]
	hint_label.text = "Mire com o mouse e atire (%s). O pente tem 7 balas. Não atire em NPCs." % _action_labels(&"fire")


func _on_target_hit() -> void:
	if current_stage != Stage.WEAPON or stage_complete:
		return
	target_hits += 1
	if weapon_reloaded:
		_complete_stage()
	else:
		objective_label.text = "Você acertou! Recarregue (%s) e acerte o alvo novamente." % _action_labels(&"reload")
		_announce_objective()


func _update_weapon() -> void:
	var gun := player.inventory.get_item_control("gun")
	if gun == null:
		return
	var ammo := int(gun.get("current_ammo"))
	if ammo < last_gun_ammo:
		shots_before_reload += last_gun_ammo - ammo
	if bool(gun.get("reloading")):
		reload_started = true
	elif reload_started and ammo > last_gun_ammo:
		weapon_reloaded = true
		reload_started = false
		objective_label.text = "Arma recarregada. Acerte o drone-alvo novamente."
		_announce_objective()
	if int(gun.get("reserve_ammo")) <= 0:
		gun.set("reserve_ammo", 14)
		gun.call("refresh_hud")
	last_gun_ammo = ammo


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"esc") and not transition_locked and current_stage != Stage.COMPLETE:
		if tutorial_paused:
			_resume_tutorial()
		else:
			tutorial_paused = true
			pause_overlay.show()
			get_tree().paused = true
			resume_button.grab_focus()
			_speak("Treinamento pausado")
		get_viewport().set_input_as_handled()


func _resume_tutorial() -> void:
	tutorial_paused = false
	pause_overlay.hide()
	get_tree().paused = false
	_announce_objective()


func _restart_room() -> void:
	_resume_tutorial()
	_load_room(current_stage)
	_announce_objective()


func _complete_tutorial() -> void:
	current_stage = Stage.COMPLETE
	completion_continue.text = "MENU PRINCIPAL" if Configs.tutorial_return_scene == MAIN_MENU_SCENE else "ESCOLHER PERSONAGEM"
	completion_overlay.show()
	get_tree().paused = true
	completion_continue.grab_focus()
	_speak("Treinamento concluído. Você praticou todas as mecânicas básicas.")


func _finish_tutorial() -> void:
	get_tree().paused = false
	Configs.configs["tutorial_seen"] = true
	Configs.configs["tutorial_completed"] = true
	SaveLoad._save()
	var destination := Configs.tutorial_return_scene
	if destination.is_empty() or not ResourceLoader.exists(destination):
		destination = CHARACTER_SELECTION_SCENE
	get_tree().change_scene_to_file(destination)


func _replay_tutorial() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	Configs.tutorial_return_scene = MAIN_MENU_SCENE
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _exit_tree() -> void:
	if tutorial_paused or current_stage == Stage.COMPLETE:
		get_tree().paused = false


func _update_accessible_names() -> void:
	for label in [progress_label, title_label, objective_label, hint_label]:
		label.accessibility_name = label.text


func _announce_objective() -> void:
	_speak("%s. %s. %s" % [title_label.text, objective_label.text, hint_label.text])


func _speak(text: String) -> void:
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(text)


func _set_font_size_recursive(node: Node, factor: float) -> void:
	if node is Control:
		var base_size := (node as Control).get_theme_font_size(&"font_size")
		if base_size > 0:
			(node as Control).add_theme_font_size_override(&"font_size", maxi(8, int(round(base_size * factor))))
	for child in node.get_children():
		_set_font_size_recursive(child, factor)


func _movement_keys_text() -> String:
	return "%s/%s/%s/%s" % [_action_labels(&"up"), _action_labels(&"left"), _action_labels(&"down"), _action_labels(&"right")]


func _action_labels(action: StringName) -> String:
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		var label: String = event.as_text()
		if event is InputEventKey:
			label = OS.get_keycode_string(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		elif event is InputEventMouseButton:
			label = "botão esquerdo do mouse" if event.button_index == MOUSE_BUTTON_LEFT else event.as_text()
		if not labels.has(label):
			labels.append(label)
	return "/".join(labels)
