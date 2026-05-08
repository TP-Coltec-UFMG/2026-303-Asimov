extends Label

func _ready() -> void:
	text = str(Configs.configs.volume_sfx * 100) + "%"

func _on_sfx_slider_value_changed(value: float) -> void:
	text = str(value * 100) + "%"
