extends CheckBox


func _ready() -> void:
	if Configs.configs.tela_cheia:
		button_pressed = true
	else:
		button_pressed = false
