extends Node2D
@onready var bg_music: AudioStreamPlayer2D = $"BG Music"
@onready var bg_ambient: AudioStreamPlayer2D = $"BG Ambient"
@onready var countdown_music: AudioStreamPlayer2D = $COUNTDOWN_MUSIC
@onready var som_alarme: AudioStreamPlayer2D = $SOM_ALARME


func _ready() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.1))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("sfx"), linear_to_db(0))
	bg_ambient.play()
	bg_music.play()
	pass
	
	
func _start_countdown() -> void:
	countdown_music.play()
	
func _stop_countdown() -> void:
	countdown_music.stop()
	
func _start_som_alarme()-> void:
	som_alarme.play()
	
func _stop_som_alarme() -> void:
	som_alarme.stop()
