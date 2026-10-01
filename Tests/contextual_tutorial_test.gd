extends BaseScene

var failures: Array[String] = []
var guide: CanvasLayer
var original_configs: Dictionary
var original_save: Dictionary


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	original_configs = Configs.configs.duplicate(true)
	original_save = SaveGame.save_data.duplicate(true)
	Configs.configs["contextual_tutorial_seen"] = {}
	SaveGame.save_data = {}
	guide = ContextualTutorial
	guide.set_process(false)
	call_deferred("_run")


func _run() -> void:
	var room := preload("res://Tutorial/Rooms/training_room.tscn").instantiate()
	add_child(room)
	player = preload("res://Player/ManPlayer.tscn").instantiate()
	player.checkpoint_enabled = false
	player.starting_gun_enabled = false
	var quests: Node = player.get_node("QUEST_MISSION")
	quests.standalone_mode = true
	quests.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.camera_2d.limit_left = -200
	player.camera_2d.limit_right = 200
	player.camera_2d.limit_top = -112
	player.camera_2d.limit_bottom = 112
	player.camera_2d.zoom = Vector2.ONE * 1.2
	player.camera_2d.position_smoothing_enabled = false
	player.camera_2d.make_current()
	guide.player = player
	await get_tree().process_frame
	_expect(guide._gameplay_available(), "O ensino deve funcionar durante a campanha.")
	guide._discover_lessons()
	guide._start_next()
	_expect(guide.active_lesson == "walk", "A campanha deve ensinar movimento primeiro.")
	guide._update_lesson(0.3)
	_expect(is_equal_approx(Engine.time_scale, 0.25), "A explicação deve reduzir a velocidade sem pausar.")
	var health := player.get_vida()
	player.tomar_dano(30)
	_expect(is_equal_approx(player.get_vida(), health), "O jogador deve estar protegido enquanto aprende.")
	player.global_position.x += 5
	guide._update_lesson(3.0)
	guide._update_lesson(0.3)
	_expect(guide._seen("walk") and guide.active_lesson.is_empty(), "Praticar deve concluir e registrar a explicação.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "A velocidade deve voltar ao normal.")
	guide._queue("walk")
	_expect(not "walk" in guide.pending, "Uma explicação concluída não deve se repetir.")
	guide._begin_lesson("run")
	guide._update_lesson(0.3)
	get_tree().paused = true
	_expect(not guide._gameplay_available(), "Não deve haver ensino no menu de pausa.")
	guide._suspend()
	_expect(is_equal_approx(Engine.time_scale, 1.0) and not guide.panel.visible, "Pausar deve esconder a explicação e restaurar a velocidade.")
	get_tree().paused = false
	guide.available_time = 1.0
	guide._update_lesson(0.1)
	_expect(guide.owns_slow_motion and guide.panel.visible, "A explicação deve continuar após sair da pausa.")
	player.set_physics_process(false)
	_expect(not guide._gameplay_available(), "Cutscenes, elevador e minigames devem suspender o ensino.")
	guide._suspend()
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Abrir um minigame deve remover a câmera lenta.")
	player.set_physics_process(true)
	DialogManager.is_showing_dialog = true
	_expect(not guide._gameplay_available(), "Explicações não devem cobrir diálogos com NPCs.")
	DialogManager.is_showing_dialog = false
	var blur := Node.new()
	add_child(blur)
	blur.add_to_group(&"opening_gameplay_blur")
	_expect(not guide._gameplay_available(), "A explicação deve aguardar o blur inicial.")
	blur.remove_from_group(&"opening_gameplay_blur")
	blur.queue_free()
	guide.cancel_current()
	guide.pending.clear()
	for tier in [1, 2, 3]:
		var scene_path: String = ["res://Objects/cartao_padrao.tscn", "res://Objects/cartao_forte.tscn", "res://Objects/cartao_chefe.tscn"][tier - 1]
		player.inventory.add_item("cartao", load(scene_path))
		guide._discover_lessons()
		_expect("card_%d" % tier in guide.pending, "Cada nível de cartão deve ter sua própria explicação.")
		guide._begin_lesson("card_%d" % tier)
		_equip("use_cartao")
		_expect(guide._action_practiced(), "Equipar o cartão deve ser reconhecido.")
		guide._complete_lesson()
		player.reset_sprite_player()
	guide.pending.clear()
	player.inventory.add_item("lanterna", preload("res://Objects/Lanterna.tscn"))
	guide._begin_lesson("flashlight")
	_equip("use_lanterna")
	_expect(guide._action_practiced(), "A luz real da lanterna deve concluir a prática.")
	guide._complete_lesson()
	player.inventory.add_item("extintor", preload("res://Objects/extintor.tscn"))
	guide._begin_lesson("extinguisher")
	_equip("use_extintor")
	var extinguisher := player.inventory.get_item_control("extintor")
	extinguisher.set_fumaca(true)
	_expect(guide._action_practiced(), "Usar o extintor real deve ser reconhecido.")
	extinguisher.set_fumaca(false)
	guide._complete_lesson()
	player.inventory.add_item("gun", preload("res://Objects/arma.tscn"))
	_equip("use_arma")
	guide._begin_lesson("weapon")
	var gun := player.inventory.get_item_control("gun")
	gun.current_ammo -= 1
	_expect(guide._action_practiced(), "Um disparo deve concluir a orientação da arma.")
	guide._complete_lesson()
	guide._begin_lesson("reload")
	gun._start_reload()
	await get_tree().create_timer(1.3).timeout
	_expect(guide._action_practiced(), "Uma recarga real deve concluir sua explicação.")
	guide._complete_lesson()
	guide._begin_lesson("weapon_flashlight")
	_equip("use_lanterna")
	_expect(guide._action_practiced(), "A combinação de arma e lanterna deve funcionar.")
	guide._complete_lesson()
	for item_id in ["laptop", "cabo"]:
		player.inventory.add_item(item_id, load("res://Objects/%s.tscn" % item_id))
		guide._begin_lesson("laptop" if item_id == "laptop" else "cable")
		_equip("use_%s" % item_id)
		_expect(guide._action_practiced(), "O uso do notebook e do cabo deve ser reconhecido.")
		guide._complete_lesson()
	var original_events := InputMap.action_get_events("empurrar")
	InputMap.action_erase_events("empurrar")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_G
	InputMap.action_add_event("empurrar", remapped)
	_expect("G" in guide._content("push")[1], "As explicações devem usar as teclas remapeadas.")
	InputMap.action_erase_events("empurrar")
	for event in original_events:
		InputMap.action_add_event("empurrar", event)
	guide._begin_lesson("push")
	guide._update_lesson(9.0)
	guide._update_lesson(0.3)
	_expect(guide.active_lesson.is_empty(), "A explicação deve terminar mesmo sem prática, sem prender o jogador.")
	guide._begin_lesson("weapon")
	guide._update_lesson(0.3)
	Engine.time_scale = 0.12
	guide.cancel_current()
	_expect(is_equal_approx(Engine.time_scale, 0.12), "O tutorial não deve sobrescrever a câmera lenta de outro efeito.")
	Engine.time_scale = 1.0
	guide._begin_lesson("weapon")
	guide._update_lesson(0.3)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.contextual-preview.png")
	guide._on_scene_changed()
	_expect(is_equal_approx(Engine.time_scale, 1.0) and guide.active_lesson.is_empty(), "Trocar de cena deve limpar a câmera lenta e a explicação.")
	_expect(guide._seen("card_3"), "O aprendizado deve continuar registrado após uma troca de cena.")
	Configs.configs["contextual_tutorial_seen"] = {}
	player.reset_sprite_player()
	guide.set_process(true)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_expect(not guide.active_lesson.is_empty(), "O ensino deve iniciar sozinho na campanha.")
	guide.set_process(false)
	guide.cancel_current()
	Configs.configs = original_configs
	SaveGame.save_data = original_save
	var report := FileAccess.open("res://.contextual-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _equip(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	player._input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
