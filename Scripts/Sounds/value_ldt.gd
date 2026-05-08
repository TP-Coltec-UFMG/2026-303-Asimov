extends Label


func _ready() -> void:
	text = str(Configs.configs.volume_leitor * 100) + "%"
	
func _on_ldt_slider_value_changed(value: float) -> void:
	text = str(value * 100) + "%"
	Configs._change_volume_leitor_de_tela(value)
