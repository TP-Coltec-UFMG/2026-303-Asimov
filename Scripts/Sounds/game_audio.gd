class_name GameAudio
extends RefCounted

const GRAB: AudioStream = preload("res://Sounds/External/sfx100v2_items_01.ogg")
const RELEASE: AudioStream = preload("res://Sounds/External/sfx100v2_items_02.ogg")
const SCRAPES: Array[AudioStream] = [
	preload("res://Sounds/External/scrape-1.ogg"),
	preload("res://Sounds/External/scrape-2.ogg"),
	preload("res://Sounds/External/scrape-3.ogg")
]
const CARD_SWIPE: AudioStream = preload("res://Sounds/External/keyhole-lockbox-insert-01.wav")
const TERMINAL_KEY: AudioStream = preload("res://Sounds/External/sfx100v2_switch_02.ogg")
const BREAKER: AudioStream = preload("res://Sounds/External/sfx100v2_metal_hit_01.ogg")
const ACCESS_GRANTED: AudioStream = preload("res://Sounds/External/sfx100v2_lock_open_01.ogg")
const ACCESS_DENIED: AudioStream = preload("res://Sounds/External/sfx100v2_switch_01.ogg")
const DOOR_LATCH: AudioStream = preload("res://Sounds/External/sfx100v2_door_01.ogg")

const VOICE_GROUP: StringName = &"game_audio_one_shots"
const MAX_VOICES: int = 8


static func play_world(origin: Node2D, sound: AudioStream, volume_db: float = -10.0, distance: float = 260.0) -> void:
	if not _can_play(origin, sound):
		return
	var scene := origin.get_tree().current_scene
	var host: Node = scene if scene != null else origin
	var voice := AudioStreamPlayer2D.new()
	voice.bus = &"sfx"
	voice.stream = sound
	voice.volume_db = volume_db
	voice.max_distance = distance
	voice.attenuation = 2.0
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(voice)
	_register_voice(voice, origin, sound)
	voice.global_position = origin.global_position
	voice.finished.connect(voice.queue_free)
	voice.play()


static func play_ui(origin: Node, sound: AudioStream, volume_db: float = -12.0) -> void:
	play_ui_sequence(origin, [sound], [volume_db])


# A leitura e o resultado usam a mesma voz, em sequência, sem atrasar a tarefa.
static func play_ui_sequence(origin: Node, sounds: Array[AudioStream], volumes: Array[float]) -> void:
	if sounds.is_empty() or not _can_play(origin, sounds[0]):
		return
	var scene := origin.get_tree().current_scene
	var host: Node = scene if scene != null else origin
	var voice := AudioStreamPlayer.new()
	voice.bus = &"sfx"
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	host.add_child(voice)
	_register_voice(voice, origin, sounds[0])
	# Fechar/reiniciar um minigame também cancela seus sons pendentes.
	origin.tree_exiting.connect(voice.queue_free, CONNECT_ONE_SHOT)
	_play_sequence_next(voice, sounds, volumes, 0)


static func _play_sequence_next(voice: AudioStreamPlayer, sounds: Array[AudioStream], volumes: Array[float], index: int) -> void:
	if not is_instance_valid(voice) or voice.is_queued_for_deletion():
		return
	if index >= sounds.size():
		voice.queue_free()
		return
	voice.stream = sounds[index]
	voice.volume_db = volumes[index] if index < volumes.size() else -12.0
	voice.finished.connect(_play_sequence_next.bind(voice, sounds, volumes, index + 1), CONNECT_ONE_SHOT)
	voice.play()


static func _can_play(origin: Node, sound: AudioStream) -> bool:
	if not is_instance_valid(origin) or sound == null or not origin.is_inside_tree():
		return false
	if origin.get_tree().paused:
		return false
	for voice in origin.get_tree().get_nodes_in_group(VOICE_GROUP):
		if voice.is_queued_for_deletion():
			continue
		if voice.get_meta(&"audio_origin") == origin.get_instance_id() and voice.get_meta(&"audio_sound") == sound.get_instance_id():
			return false
	return true


static func _register_voice(voice: Node, origin: Node, sound: AudioStream) -> void:
	var active: Array[Node] = []
	for existing in origin.get_tree().get_nodes_in_group(VOICE_GROUP):
		if not existing.is_queued_for_deletion():
			active.append(existing)
	# Várias interações no mesmo frame não podem somar um volume sem limite.
	while active.size() >= MAX_VOICES:
		var oldest: Node = active.pop_front()
		oldest.stop()
		oldest.queue_free()
	voice.set_meta(&"audio_origin", origin.get_instance_id())
	voice.set_meta(&"audio_sound", sound.get_instance_id())
	voice.add_to_group(VOICE_GROUP)
