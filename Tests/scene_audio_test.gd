extends Node

const FLOORS: Array[String] = [
	"andar_hall", "andar_escritorio", "andar_ferramentas",
	"andar_data_center", "data_center_refrigeracao", "data_center_forte"
]
var failures: Array[String] = []
var capture: AudioEffectCapture


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta(&"dev_mission_jump_active", true)


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--scene-audio-test"):
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	SaveGame.save_data = {}
	SaveGame.restore_checkpoint_pending = false
	SaveGame.tempo_atual = 500.0
	Progresso.process_mode = Node.PROCESS_MODE_DISABLED
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	# Reproducible mix; does not save or alter the user's audio preferences.
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("sfx"), linear_to_db(0.75))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.1))
	var previous: Node
	for floor_name in FLOORS:
		if is_instance_valid(scene_manager.player):
			var persistent_player: Player = scene_manager.player
			persistent_player.get_parent().remove_child(persistent_player)
			add_child(persistent_player)
		if is_instance_valid(previous):
			previous.queue_free()
			await get_tree().process_frame
		var floor_scene := load("res://Scenes/" + floor_name + ".tscn") as PackedScene
		var floor := floor_scene.instantiate()
		get_tree().root.add_child(floor)
		get_tree().current_scene = floor
		previous = floor
		await get_tree().process_frame
		_expect(is_instance_valid(scene_manager.player), floor_name + ": player loads")
		var player: Player = scene_manager.player
		player.checkpoint_enabled = false
		player.set_physics_process(false)
		# O menu de pausa carrega as preferências ao entrar na árvore.
		AudioServer.set_bus_volume_db(0, 0.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("sfx"), linear_to_db(0.75))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.1))
		var ambience := floor.get_node("SceneAmbience")
		await get_tree().create_timer(1.2).timeout
		_expect(ambience.bed.playing, floor_name + ": ambience starts")
		capture.clear_buffer()
		await get_tree().create_timer(0.5).timeout
		_report_mix(floor_name)
		# Jump to the loop seam and verify crossfade continuity at runtime.
		ambience.bed.seek(ambience.bed.stream.get_length() - 0.35)
		await get_tree().create_timer(0.8).timeout
		_expect(ambience.bed.playing, floor_name + ": ambience survives the loop seam")
		_expect(not ambience.next_bed.playing, floor_name + ": only one voice after crossfade")
		get_tree().paused = true
		await get_tree().create_timer(0.1).timeout
		_expect(ambience.bed.stream_paused, floor_name + ": ambience pauses")
		var position_before: float = ambience.bed.get_playback_position()
		await get_tree().create_timer(0.12).timeout
		_expect(absf(ambience.bed.get_playback_position() - position_before) < 0.03, floor_name + ": paused audio does not advance")
		get_tree().paused = false
		if floor_name == "andar_hall":
			ambience._on_drip()
			_expect(ambience.drip_voice.playing, "Hall: dripping plays")
			await get_tree().create_timer(0.7).timeout
			ambience._on_creak()
			_expect(ambience.creak_voice.playing, "Hall: metal creak plays")
			await get_tree().create_timer(2.0).timeout
	get_tree().current_scene = self
	previous.queue_free()
	scene_manager.player = null
	await get_tree().process_frame
	await get_tree().process_frame
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	print("SCENE_AUDIO_TEST: ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)


func _report_mix(label: String) -> void:
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var energy := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		energy += sample.length_squared() / 2.0
	_expect(not samples.is_empty() and peak > 0.0001, label + ": mixer outputs actual audio samples")
	_expect(peak < 1.0, label + ": mix must not clip")
	print("MIX ", label, " peak=", snappedf(linear_to_db(peak), 0.1), " dB RMS=", snappedf(linear_to_db(sqrt(energy / maxi(1, samples.size()))), 0.1), " dB")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
