extends SceneTree

const AUDIO := preload("res://Scripts/Sounds/game_audio.gd")
var failures: Array[String] = []


func _initialize() -> void:
	set_meta(&"dev_mission_jump_active", true)
	_run.call_deferred()


func _run() -> void:
	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	_check(root.get_node("EfeitosSonoros/Vozes").get_child_count() == AUDIO.MAXIMO_VOZES, "Voices must already exist in the scene.")
	var origin := Node2D.new()
	scene.add_child(origin)
	for i in 12:
		AUDIO.tocar_interface(origin, AUDIO.TECLA_TERMINAL)
	_check(_voices().size() == 1, "Repeated clicks must not stack the same recording.")
	_clear_voices()
	await process_frame

	AUDIO.tocar_sequencia_interface(origin, [AUDIO.PASSAR_CARTAO, AUDIO.ACESSO_NEGADO], [-11.0, -13.0])
	_check(_voices().size() == 1, "RFID must use one audio voice.")
	var sequence := _voices()[0] as AudioStreamPlayer
	_check(sequence.stream == AUDIO.PASSAR_CARTAO, "RFID must start with its swipe.")
	sequence.finished.emit()
	_check(sequence.stream == AUDIO.ACESSO_NEGADO, "The result must follow the swipe.")
	_check(sequence.volume_db == -13.0, "The result must retain its own volume.")
	_clear_voices()
	await process_frame
	AUDIO.tocar_sequencia_interface(origin, [AUDIO.PASSAR_CARTAO, AUDIO.ACESSO_NEGADO], [-11.0, -13.0])
	await create_timer(AUDIO.PASSAR_CARTAO.get_length() + AUDIO.ACESSO_NEGADO.get_length() + 0.3).timeout
	_check(_voices().is_empty(), "The complete recording sequence must finish and release its voice.")

	AUDIO.tocar_sequencia_interface(origin, [AUDIO.PASSAR_CARTAO, AUDIO.ACESSO_PERMITIDO], [-11.0, -11.0])
	sequence = _voices()[0] as AudioStreamPlayer
	await create_timer(0.06).timeout
	paused = true
	_check(not sequence.can_process(), "Interaction sounds must pause with gameplay.")
	await create_timer(0.06).timeout
	var paused_position := sequence.get_playback_position()
	await create_timer(0.15).timeout
	_check(absf(sequence.get_playback_position() - paused_position) < 0.03, "Paused recording playback must not advance beyond the mixer buffer.")
	AUDIO.tocar_interface(origin, AUDIO.TECLA_TERMINAL)
	_check(_voices().size() == 1, "Paused gameplay must not spawn another sound.")
	paused = false
	_check(sequence.can_process(), "Interaction sounds must resume with gameplay.")
	paused = true
	origin.queue_free()
	await process_frame
	await process_frame
	_check(_voices().is_empty(), "Closing the minigame must discard pending result audio, including while paused.")
	paused = false

	for i in 20:
		var separate_origin := Node2D.new()
		scene.add_child(separate_origin)
		separate_origin.position = Vector2(20 + i, 40)
		AUDIO.tocar_no_mundo(separate_origin, AUDIO.TECLA_TERMINAL)
		_check(_voices().any(func(voice: Node) -> bool: return voice.global_position == separate_origin.global_position), "World sounds must start at the emitter location.")
	_check(_voices().size() == AUDIO.MAXIMO_VOZES, "A burst of world sounds must have a bounded voice count.")
	current_scene = null
	scene.queue_free()
	await process_frame
	await process_frame
	_check(_voices().is_empty(), "Changing scenes must stop all interaction tails.")
	_check(root.get_node("EfeitosSonoros/Vozes").get_child_count() == AUDIO.MAXIMO_VOZES, "Reusing effects must preserve the fixed pool.")
	pass
	quit(0 if failures.is_empty() else 1)


func _voices() -> Array[Node]:
	return root.get_node("EfeitosSonoros").obter_vozes_ativas()


func _clear_voices() -> void:
	root.get_node("EfeitosSonoros").parar_todos()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
