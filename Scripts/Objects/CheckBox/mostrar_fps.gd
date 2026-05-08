extends CheckBox


func _ready() -> void:
	if Configs.configs.mostrar_fps:
		button_pressed = true
	else:
		button_pressed = false
