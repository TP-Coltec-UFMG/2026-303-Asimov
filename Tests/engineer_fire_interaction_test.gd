extends BaseScene

class IntroStub extends Node:
	var cutscene_running := false
	func play_engineer_backup_scan() -> void:
		cutscene_running = true
		await get_tree().create_timer(0.05).timeout
		cutscene_running = false

var checks := 0
var failures := 0

func _enter_tree() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	MusicController.set_process(false)
	ContextualTutorial.set_process(false)
	Progresso.process_mode = Node.PROCESS_MODE_DISABLED
	SaveGame.save_data = {}
	SaveGame.tempo_atual = 300.0
	Configs.configs["job"] = "programador"
	player = preload("res://Player/ManPlayer.tscn").instantiate() as Player
	player.checkpoint_enabled = false
	player.position = Vector2(1500, 1500)
	add_child(player)
	scene_manager.player = player
	var intro := IntroStub.new()
	intro.name = "RestrictedAreaIntro"
	add_child(intro)
	var highlights := Node2D.new()
	highlights.name = "Highlights"
	intro.add_child(highlights)
	for index in range(6):
		var marker := Node2D.new()
		marker.name = ["ServerRowA", "ServerRowB", "ServerRowC", "ServerRowD", "ServerColumn", "ServerRowE"][index]
		marker.position = Vector2(150 + index * 150, 150)
		highlights.add_child(marker)
		var interaction := preload("res://Interaction_components/interectable.tscn").instantiate()
		marker.add_child(interaction)
		interaction.is_interactable = true
		interaction.is_not_object = true
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 15.0
		shape.shape = circle
		interaction.add_child(shape)
	var ui := CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var ending_ui := Control.new()
	ending_ui.name = "ProgrammerEndingUI"
	ui.add_child(ending_ui)
	var balloon := Panel.new()
	balloon.name = "AIVoiceBalloon"
	ending_ui.add_child(balloon)
	var label := Label.new()
	label.name = "Text"
	balloon.add_child(label)
	var fade := ColorRect.new()
	fade.name = "FinalFade"
	ending_ui.add_child(fade)
	var programmer := Node.new()
	programmer.name = "ProgrammerEnding"
	add_child(programmer)
	var audio := Node.new()
	audio.name = "Audio"
	programmer.add_child(audio)
	var tension := AudioStreamPlayer.new()
	tension.name = "FinalTension"
	audio.add_child(tension)
	var controller := preload("res://Scenes/scripts/engineer_ending_controller.gd").new()
	controller.name = "EngineerEnding"
	add_child(controller)
	controller.set_process(false)
	controller.scene = self
	controller.player = player
	controller.initialized = true
	var state := {"engineer_point_order": ["ServerRowA", "ServerRowB", "ServerRowC"], "engineer_backup_order": ["ServerRowD", "ServerRowA", "ServerColumn"]}
	controller._load_points(state)
	_expect(controller.point_order == ["ServerRowA", "ServerRowB", "ServerRowC"] and controller.backup_order.size() == 2 and controller.backup_order[0] == "ServerRowD", "Migrate to two reserves without moving valid saved stages")
	for point in controller.backup_order:
		_expect(not point in controller.point_order, "The two reserve locations must differ from the initial three")
	_expect(controller.backup_order[0] != controller.backup_order[1], "Reserve locations must be distinct")
	var first_order: Array = controller.point_order.duplicate() + controller.backup_order.duplicate()
	controller._load_points(state)
	_expect(first_order == controller.point_order + controller.backup_order and first_order.size() == 5, "Loading preserves all five chosen locations")
	await _frames(3)
	_expect(not controller._can_interact_with_point("ServerRowC"), "Distant battery point must reject interaction")
	controller._on_point_interacted("ServerRowC")
	_expect(not controller.minigame_open, "No spontaneous battery minigame")
	player.position = highlights.get_node("ServerRowC").position
	await _frames(3)
	_expect(controller._can_interact_with_point("ServerRowC"), "Nearby visible point is interactable")
	highlights.get_node("ServerRowC").hide()
	_expect(not controller._can_interact_with_point("ServerRowC"), "Hidden future mission must reject interaction")
	highlights.get_node("ServerRowC").show()
	intro.cutscene_running = true
	_expect(not controller._can_interact_with_point("ServerRowC"), "Cutscene must reject interaction")
	intro.cutscene_running = false
	player.position = Vector2(1500, 1500)
	controller._restore_fires({"engineer_completed_count": 3})
	_expect(controller.fires.size() == 3, "First round restores all three fires")
	controller._restore_fires({"engineer_completed_count": 4})
	_expect(controller.fires.size() == 4, "Reserve round keeps first fires and adds its own")
	var fire: Node2D = controller.fires[0]
	_expect(fire.scene_file_path == "res://Objects/fogo.tscn" and fire.scale == Vector2.ONE, "Original fire scene and size")
	_expect(fire.damage_enabled and fire.save_enabled and fire.particulas.emitting, "Original damage, saving and particles enabled")
	_expect(fire.fire_ambient.playing and fire.fire_ambient.stream != null, "Original positional fire audio plays")
	var health := player.get_vida()
	player.position = fire.global_position + Vector2(0, -8)
	await get_tree().create_timer(0.24).timeout
	_expect(player.get_vida() < health, "Actual fire overlap damages real Player")
	player.position = Vector2(1500, 1500)
	state = SaveGame.office_mission_state(player)
	state["engineer_ending_started"] = true
	state["data_center_forte_intro_seen"] = true
	state["engineer_completed_count"] = 1
	SaveGame.save_global_state("hall_quest_01", state)
	controller._queue_dialogue([{"text": controller.AFTER_LINES[1], "damaged": true}, {"text": controller.AFTER_LINES[2], "damaged": true}])
	await _frames(2)
	_expect(controller.ai_speaking and controller.ai_text.text.contains("Iss0"), "Corrupted reaction is shown")
	var skip := InputEventAction.new()
	skip.action = "pular_pensamento"
	skip.pressed = true
	get_viewport().push_input(skip, true)
	await _frames(1)
	_expect(controller.ai_speaking and controller.ai_text.text.contains("M3us"), "Space advances exactly one queued AI reaction")
	controller._update_targets()
	player.position = highlights.get_node("ServerRowB").position
	await _frames(3)
	controller._on_point_interacted("ServerRowB")
	_expect(controller.minigame_open and controller.active_minigame_stage == 1, "Minigame opens during AI dialogue")
	_expect(not controller.ai_balloon.visible, "AI balloon suspended behind minigame")
	controller.sequence_time_scale = 0.05
	var fire_count_before_completion := controller.fires.size()
	controller._on_minigame_completed(1)
	_expect(not controller.minigame_open and player.is_physics_processing(), "Circuit closes and restores movement immediately")
	_expect(controller.fires.size() == fire_count_before_completion, "Explosion does not occur on the closing frame")
	_expect(controller.task_busy, "Next objective stays locked during the explosion safety delay")
	player.position = Vector2(1500, 1500)
	await get_tree().create_timer(0.09).timeout
	_expect(not controller.task_busy, "Explosion safety delay finishes before enabling the next objective")
	_expect(controller.ai_speaking and controller.ai_balloon.visible, "AI reaction resumes after delayed explosion")
	controller._finish_ai_message()
	state["engineer_completed_count"] = 3
	SaveGame.save_global_state("hall_quest_01", state)
	controller._start_redundancy_dialogue()
	await get_tree().create_timer(0.12).timeout
	_expect(controller.dialogue_busy and controller.task_busy and not controller.reserve_scan_running, "Reserve dialogue runs before revealing backup locations")
	player.position = highlights.get_node(controller.backup_order[0]).position
	await _frames(3)
	controller._on_point_interacted(controller.backup_order[0])
	_expect(not controller.minigame_open, "Backup circuit stays locked until its reveal cutscene")
	for attempt in range(30):
		if not controller.dialogue_busy:
			break
		if controller.ai_speaking:
			controller._finish_ai_message()
		player.balao_de_pensamento.pular_pensamento()
		await _frames(2)
	await get_tree().create_timer(0.12).timeout
	_expect(not controller.dialogue_busy and not controller.reserve_scan_running and not controller.task_busy, "Backup reveal starts only after the complete redundancy exchange")
	controller._on_point_interacted(controller.backup_order[0])
	_expect(controller.minigame_open and controller.active_minigame_stage == 3, "Reserve minigame opens after the reveal cutscene")
	controller._leave_minigame()
	controller._finish_ai_message()
	player.balao_de_pensamento.pular_pensamento()
	state["engineer_completed_count"] = 4
	state["engineer_redundancy_seen"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	controller.sequence_time_scale = 0.05
	controller._update_targets()
	player.position = highlights.get_node(controller.backup_order[1]).position
	await _frames(3)
	controller._on_point_interacted(controller.backup_order[1])
	_expect(controller.minigame_open and controller.active_minigame_stage == 4, "The second reserve is the last circuit minigame")
	controller._on_minigame_completed(4)
	player.position = Vector2(1500, 1500)
	await get_tree().create_timer(0.09).timeout
	_expect(int(SaveGame.office_mission_state(player).get("engineer_completed_count", 0)) == 5, "All objectives finish after three initial circuits and two reserves")
	_expect(controller.escape_active and is_instance_valid(controller.escape_timer_label), "Last component starts 20-second escape")
	_expect(controller.escape_timer_label.text == "00:20", "Escape countdown begins at twenty seconds")
	_expect(is_instance_valid(controller.escape_siren) and controller.escape_siren.playing, "Escape siren begins and can rise")
	controller._on_escape_exit_requested(null)
	await get_tree().create_timer(0.2).timeout
	_expect(controller.destruction_cutscene_running and not player.visible, "Using exit hides player and starts destruction cutscene")
	_expect(is_instance_valid(controller.destruction_camera) and controller.fires.size() > 4, "Cutscene camera shows new persistent explosion fires")
	var report := FileAccess.open("res://.engineer-fire-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures == 0, "failures": failures, "checks": checks}))
	get_tree().quit(0 if failures == 0 else 1)

func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
