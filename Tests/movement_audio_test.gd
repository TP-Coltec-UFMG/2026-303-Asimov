extends Node2D

# Run as a scene with -- --movement-audio-test. Exercises the real Player and
# physics rather than starting audio players directly. No campaign is saved.
const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
var failures: Array[String] = []
var checks: int = 0
var player: Player


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta(&"dev_mission_jump_active", true)


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--movement-audio-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	# Prevent story and global music from affecting the movement-only fixture.
	MusicController.set_process(false)
	for child: Node in MusicController.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
	Progresso.process_mode = Node.PROCESS_MODE_DISABLED
	SaveGame.save_data = {}
	SaveGame.tempo_atual = 300.0
	DialogManager.is_showing_dialog = false

	player = PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	scene_manager.player = player
	await _frames(3)
	_expect(player.sfx_walking.stream.resource_path == "res://Sounds/Effects/passo_player.MP3", "Preserve the original footstep recording.")
	_expect(not player.sfx_walking.playing, "Standing still must be silent.")

	var previous_position := player.position
	Input.action_press("right")
	await _frames(8)
	_expect(player.position.x > previous_position.x, "The fixture must physically move.")
	_expect(player.sfx_walking.playing, "Actual walking must start footsteps.")
	Input.action_release("right")
	await _frames(3)
	_expect(not player.sfx_walking.playing, "Releasing movement must stop footsteps.")

	var wall := _wall(player.position + Vector2(14.0, -5.0))
	Input.action_press("right")
	await _frames(35)
	previous_position = player.position
	await _frames(4)
	_expect(player.position.distance_to(previous_position) < 0.001, "The wall must physically block the player.")
	_expect(not player.sfx_walking.playing, "Holding movement against a wall must remain silent.")
	Input.action_release("right")
	wall.queue_free()
	await _frames(3)

	Input.action_press("right")
	await _frames(5)
	_expect(player.sfx_walking.playing, "Walking must restart after leaving a wall.")
	player.set_physics_process(false)
	previous_position = player.position
	await _frames(4)
	_expect(player.position == previous_position, "Cutscene/minigame movement lock must hold the player still.")
	_expect(not player.sfx_walking.playing, "A physics-disabled player must not leave footsteps playing.")
	player.set_physics_process(true)
	await _frames(5)
	_expect(player.sfx_walking.playing, "Footsteps must resume when movement is enabled again.")

	get_tree().paused = true
	await _frames(4)
	_expect(not player.sfx_walking.playing or player.sfx_walking.stream_paused, "Pausing must silence footsteps.")
	get_tree().paused = false
	await _frames(5)
	_expect(player.sfx_walking.playing and not player.sfx_walking.stream_paused, "Unpausing must allow footsteps again.")

	player.hide()
	await _frames(4)
	_expect(not player.sfx_walking.playing, "A player hidden for an overlay must not emit footsteps.")
	player.show()
	await _frames(5)
	_expect(player.sfx_walking.playing, "Returning from an overlay must restore walking audio.")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(4)
	_expect(not player.sfx_walking.playing or player.sfx_walking.stream_paused, "Disabling a player must silence movement audio.")
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	await _frames(5)

	# Reproduce the persistent Player being removed before an elevator scene swap.
	Input.action_release("right")
	remove_child(player)
	_expect(not player.sfx_walking.playing, "Removing a player for a scene transition must stop the old footsteps.")
	add_child(player)
	await _frames(4)
	_expect(not player.sfx_walking.playing, "Entering another floor while idle must remain silent.")

	var object := ObjetoEmpurravel.new()
	object.save_enabled = false
	var object_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12.0, 12.0)
	object_shape.shape = rectangle
	object.add_child(object_shape)
	object.position = player.position + Vector2(24.0, -5.0)
	add_child(object)
	await _frames(3)
	player.pegar_objeto(object, Vector2.RIGHT)
	Input.action_press("right")
	previous_position = object.position
	await _frames(8)
	_expect(object.position.x > previous_position.x, "The fixture must physically move the held object.")
	_expect(player.drag_sfx.playing, "Moving a held object must produce the scraping sound.")
	Input.action_release("right")
	await _frames(4)
	_expect(not player.drag_sfx.playing, "A stationary held object must not keep scraping.")

	Input.action_press("right")
	await _frames(5)
	player.set_physics_process(false)
	await _frames(4)
	_expect(not player.drag_sfx.playing, "A cutscene/minigame must also stop dragging audio.")
	player.set_physics_process(true)
	await _frames(5)
	wall = _wall(object.position + Vector2(14.0, 0.0))
	await _frames(35)
	previous_position = object.position
	await _frames(4)
	_expect(object.position.distance_to(previous_position) < 0.001, "The held object must be blocked by the fixture wall.")
	_expect(not player.drag_sfx.playing, "A blocked held object must not keep scraping.")
	_expect(not player.sfx_walking.playing, "Blocked pushing must not produce footsteps either.")
	wall.queue_free()
	await _frames(5)
	_expect(player.drag_sfx.playing, "Dragging must resume once the obstruction is gone.")
	player.soltar_objeto()
	_expect(not player.drag_sfx.playing, "Releasing the object must stop its scraping immediately.")
	Input.action_release("right")
	await _frames(3)
	object.queue_free()
	player.queue_free()
	scene_manager.player = null
	await _frames(2)
	print("MOVEMENT_AUDIO_TEST: ", checks, " checks; ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)


func _wall(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4.0, 80.0)
	collider.shape = rectangle
	body.add_child(collider)
	body.position = at
	add_child(body)
	return body


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
