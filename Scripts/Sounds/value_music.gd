extends Label

func _ready() -> void:
	text = str(Configs.configs.volume_musica * 100) + "%"

func _on_music_slider_value_changed(value: float) -> void:
	text = str(value * 100) + "%"
