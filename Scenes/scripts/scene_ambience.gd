extends Node2D

@export_enum("Hall", "Data Center", "Refrigeração", "Escritório", "Ferramentas") var ambience_kind: int = 0

# Gravações CC0, com as fontes em Sounds/External/SOURCES.md.
const VENTILATION: AudioStream = preload("res://Sounds/External/computer-ventilation-0126.mp3")
const ROOM_VOLUMES_DB: Array[float] = [-25.0, -28.0, -17.0, -27.0, -23.0]
const LOOP_CROSSFADE: float = 0.5
const DRIPS: Array[AudioStream] = [
	preload("res://Sounds/External/water-drop-01.wav"),
	preload("res://Sounds/External/water-drop-02.wav"),
	preload("res://Sounds/External/water-drop-03.wav")
]
const CREAK: AudioStream = preload("res://Sounds/External/metal-creak-0303.mp3")

var bed: AudioStreamPlayer
var next_bed: AudioStreamPlayer
var loop_crossfading: bool = false
var loop_fade_elapsed: float = 0.0
var entrance_fade: float = 0.0
var drip_voice: AudioStreamPlayer2D
var creak_voice: AudioStreamPlayer2D
var drip_timer: Timer
var creak_timer: Timer
var elevator_muffled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group("scene_ambience")
	ambience_kind = clampi(ambience_kind, 0, ROOM_VOLUMES_DB.size() - 1)
	bed = _new_bed()
	next_bed = _new_bed()
	bed.play()
	if ambience_kind == 0:
		_setup_hall_events()


func _new_bed() -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.bus = &"sfx"
	voice.volume_linear = 0.0
	var recording := VENTILATION.duplicate() as AudioStreamMP3
	recording.loop = false
	voice.stream = recording
	add_child(voice)
	return voice


func _process(delta: float) -> void:
	if elevator_muffled:
		bed.volume_linear = 0.0
		next_bed.volume_linear = 0.0
		return
	# Reproduz a gravação real com uma pequena sobreposição nas emendas.
	# Não força o loop de uma rajada de ar, que antes pulsava a cada 2 segundos.
	entrance_fade = minf(entrance_fade + delta / 1.0, 1.0)
	var gain := db_to_linear(ROOM_VOLUMES_DB[ambience_kind]) * entrance_fade
	if not loop_crossfading and bed.get_playback_position() >= bed.stream.get_length() - LOOP_CROSSFADE:
		loop_crossfading = true
		loop_fade_elapsed = 0.0
		next_bed.volume_linear = 0.0
		next_bed.play()
	if loop_crossfading:
		loop_fade_elapsed = minf(loop_fade_elapsed + delta, LOOP_CROSSFADE)
		var progress := loop_fade_elapsed / LOOP_CROSSFADE
		bed.volume_linear = gain * (1.0 - progress)
		next_bed.volume_linear = gain * progress
		if progress >= 1.0:
			bed.stop()
			var previous := bed
			bed = next_bed
			next_bed = previous
			loop_crossfading = false
	else:
		bed.volume_linear = gain
		# Também se recupera de uma pausa longa do depurador que ultrapasse a emenda.
		if not bed.playing:
			bed.play()


func _setup_hall_events() -> void:
	drip_voice = _new_spatial_voice(DRIPS[0], Vector2(-80, 45), -14.0)
	creak_voice = _new_spatial_voice(CREAK, Vector2(145, -45), -20.0)
	drip_timer = Timer.new()
	drip_timer.one_shot = true
	add_child(drip_timer)
	drip_timer.timeout.connect(_on_drip)
	creak_timer = Timer.new()
	creak_timer.one_shot = true
	add_child(creak_timer)
	creak_timer.timeout.connect(_on_creak)
	drip_timer.start(randf_range(5.0, 11.0))
	creak_timer.start(randf_range(14.0, 25.0))


func _new_spatial_voice(sound: AudioStream, at: Vector2, volume: float) -> AudioStreamPlayer2D:
	var voice := AudioStreamPlayer2D.new()
	voice.stream = sound
	voice.bus = &"sfx"
	voice.volume_db = volume
	voice.position = at
	voice.max_distance = 550.0
	voice.attenuation = 1.0
	add_child(voice)
	return voice


func _on_drip() -> void:
	if elevator_muffled:
		return
	if creak_voice.playing:
		drip_timer.start(3.0)
		return
	drip_voice.stream = DRIPS.pick_random()
	drip_voice.play()
	drip_timer.start(randf_range(7.0, 17.0))


func _on_creak() -> void:
	if elevator_muffled:
		return
	if drip_voice.playing:
		creak_timer.start(3.0)
		return
	creak_voice.play()
	creak_timer.start(randf_range(22.0, 42.0))


func set_elevator_muffling(active: bool) -> void:
	if elevator_muffled == active:
		return
	elevator_muffled = active
	if active:
		if drip_timer != null:
			drip_timer.stop()
		if creak_timer != null:
			creak_timer.stop()
		if drip_voice != null:
			drip_voice.stop()
		if creak_voice != null:
			creak_voice.stop()
		bed.volume_linear = 0.0
		next_bed.volume_linear = 0.0
	else:
		entrance_fade = 0.0
		if drip_timer != null:
			drip_timer.start(randf_range(5.0, 11.0))
		if creak_timer != null:
			creak_timer.start(randf_range(14.0, 25.0))
