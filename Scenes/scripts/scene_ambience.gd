extends Node2D

@export_enum("Hall", "Data Center", "Refrigeração") var ambience_kind: int = 0

const HALL_AIR: AudioStream = preload("res://Sounds/Generated/hall_air.wav")
const SERVER_HUM: AudioStream = preload("res://Sounds/Generated/server_hum.wav")
const COOLING_AIR: AudioStream = preload("res://Sounds/Generated/cooling_air.wav")
const DRIP: AudioStream = preload("res://Sounds/Generated/hall_drip.wav")
const CREAK: AudioStream = preload("res://Sounds/Generated/hall_metal_creak.wav")

var bed: AudioStreamPlayer
var drip_voice: AudioStreamPlayer2D
var creak_voice: AudioStreamPlayer2D
var drip_timer: Timer
var creak_timer: Timer


func _ready() -> void:
	bed = AudioStreamPlayer.new()
	bed.bus = &"sfx"
	bed.volume_db = -17.0 if ambience_kind == 0 else (-16.0 if ambience_kind == 1 else -18.0)
	var source: AudioStream = HALL_AIR if ambience_kind == 0 else (SERVER_HUM if ambience_kind == 1 else COOLING_AIR)
	var looped := source.duplicate() as AudioStreamWAV
	looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bed.stream = looped
	add_child(bed)
	bed.play()
	if ambience_kind == 0:
		_setup_hall_events()


func _setup_hall_events() -> void:
	drip_voice = _new_spatial_voice(DRIP, Vector2(-80, 45), -13.0)
	creak_voice = _new_spatial_voice(CREAK, Vector2(145, -45), -19.0)
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
	voice.max_distance = 235.0
	voice.attenuation = 2.0
	add_child(voice)
	return voice


func _on_drip() -> void:
	drip_voice.pitch_scale = randf_range(0.9, 1.12)
	drip_voice.play()
	drip_timer.start(randf_range(7.0, 17.0))


func _on_creak() -> void:
	creak_voice.pitch_scale = randf_range(0.87, 1.08)
	creak_voice.play()
	creak_timer.start(randf_range(22.0, 42.0))
