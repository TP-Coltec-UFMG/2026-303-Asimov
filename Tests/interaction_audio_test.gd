extends SceneTree

const AUDIO := preload("res://Scripts/Sounds/game_audio.gd")
const READER_SCRIPT := preload("res://Minigames/Minigame5/Scripts/Componentes_Eletronicos/leitor_cartao.gd")
const NOTEBOOK_SCRIPT := preload("res://Minigames/Minigame5/Scripts/notebook.gd")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := Node.new()
	root.add_child(scene)
	current_scene = scene
	var origin := Node2D.new()
	scene.add_child(origin)
	for i in 12:
		AUDIO.play_ui(origin, AUDIO.TERMINAL_KEY)
	_check(_voices().size() == 1, "Repeated clicks must not stack the same recording.")
	_clear_voices()
	await process_frame

	AUDIO.play_ui_sequence(origin, [AUDIO.CARD_SWIPE, AUDIO.ACCESS_DENIED], [-11.0, -13.0])
	_check(_voices().size() == 1, "RFID must use one audio voice.")
	var sequence := _voices()[0] as AudioStreamPlayer
	_check(sequence.stream == AUDIO.CARD_SWIPE, "RFID must start with its swipe.")
	sequence.finished.emit()
	_check(sequence.stream == AUDIO.ACCESS_DENIED, "The result must follow the swipe.")
	_check(sequence.volume_db == -13.0, "The result must retain its own volume.")
	_clear_voices()
	await process_frame
	AUDIO.play_ui_sequence(origin, [AUDIO.CARD_SWIPE, AUDIO.ACCESS_DENIED], [-11.0, -13.0])
	await create_timer(AUDIO.CARD_SWIPE.get_length() + AUDIO.ACCESS_DENIED.get_length() + 0.3).timeout
	_check(_voices().is_empty(), "The complete recording sequence must finish and release its voice.")

	AUDIO.play_ui_sequence(origin, [AUDIO.CARD_SWIPE, AUDIO.ACCESS_GRANTED], [-11.0, -11.0])
	sequence = _voices()[0] as AudioStreamPlayer
	await create_timer(0.06).timeout
	paused = true
	_check(not sequence.can_process(), "Interaction sounds must pause with gameplay.")
	await create_timer(0.06).timeout
	var paused_position := sequence.get_playback_position()
	await create_timer(0.15).timeout
	_check(absf(sequence.get_playback_position() - paused_position) < 0.03, "Paused recording playback must not advance beyond the mixer buffer.")
	AUDIO.play_ui(origin, AUDIO.GRAB)
	_check(_voices().size() == 1, "Paused gameplay must not spawn another sound.")
	paused = false
	_check(sequence.can_process(), "Interaction sounds must resume with gameplay.")
	origin.queue_free()
	await process_frame
	await process_frame
	_check(_voices().is_empty(), "Closing the minigame must discard pending result audio.")

	for i in 20:
		var separate_origin := Node2D.new()
		scene.add_child(separate_origin)
		AUDIO.play_world(separate_origin, AUDIO.GRAB)
	_check(_voices().size() == AUDIO.MAX_VOICES, "A burst of pickups must have a bounded voice count.")
	current_scene = null
	scene.queue_free()
	await process_frame
	await process_frame
	_check(_voices().is_empty(), "Changing scenes must stop all interaction tails.")
	print("INTERACTION_AUDIO_TEST_PASSED" if failures.is_empty() else "INTERACTION_AUDIO_TEST_FAILED: " + str(failures))
	quit(0 if failures.is_empty() else 1)


func _voices() -> Array[Node]:
	var active: Array[Node] = []
	for voice in get_nodes_in_group(AUDIO.VOICE_GROUP):
		if not voice.is_queued_for_deletion():
			active.append(voice)
	return active


func _clear_voices() -> void:
	for voice in _voices():
		voice.stop()
		voice.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
