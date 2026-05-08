extends Node2D
@onready var bg_music: AudioStreamPlayer2D = $"BG Music"
@onready var bg_ambient: AudioStreamPlayer2D = $"BG Ambient"


func _ready() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(0.1))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("sfx"), linear_to_db(0))
	bg_ambient.play()
	bg_music.play()
	pass
