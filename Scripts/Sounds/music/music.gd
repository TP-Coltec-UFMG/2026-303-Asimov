extends Node2D

@onready var bg_music: AudioStreamPlayer2D = $"BG Music"
@onready var bg_ambient: AudioStreamPlayer2D = $"BG Ambient"
@onready var countdown_music: AudioStreamPlayer2D = $COUNTDOWN_MUSIC
@onready var som_alarme: AudioStreamPlayer2D = $SOM_ALARME
@onready var som_de_fundo: AudioStreamPlayer2D = $SOM_DE_FUNDO


func _ready() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.1))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("sfx"), linear_to_db(0))
	
	bg_ambient.play()
	bg_music.play()


# BG MUSIC
func _start_bg_music() -> void:
	bg_music.play()

func _stop_bg_music() -> void:
	bg_music.stop()


# BG AMBIENT
func _start_bg_ambient() -> void:
	bg_ambient.play()

func _stop_bg_ambient() -> void:
	bg_ambient.stop()


# COUNTDOWN
func _start_countdown() -> void:
	countdown_music.play()

func _stop_countdown() -> void:
	countdown_music.stop()


# ALARME
func _start_som_alarme() -> void:
	som_alarme.play()

func _stop_som_alarme() -> void:
	som_alarme.stop()


# SOM DE FUNDO
func _start_som_de_fundo() -> void:
	som_de_fundo.play()

func _stop_som_de_fundo() -> void:
	som_de_fundo.stop()
	

func _set_volume_som_de_fundo(volume: float) -> void:
	som_de_fundo.volume_db = linear_to_db(volume)


func _set_volume_som_alarme(volume: float) -> void:
	som_alarme.volume_db = linear_to_db(volume)


func _set_volume_countdown(volume: float) -> void:
	countdown_music.volume_db = linear_to_db(volume)
