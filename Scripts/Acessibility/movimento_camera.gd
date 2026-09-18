extends CheckBox


func _ready() -> void:
	set_pressed_no_signal(
		bool(Configs.configs.get("movimento_camera", true))
	)


func _on_toggled(toggled_on: bool) -> void:
	Configs._change_movimento_camera(toggled_on)
	SaveLoad._save()
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(
			"Movimento de câmera ativado"
			if toggled_on
			else "Movimento de câmera desativado"
		)


func _on_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto("Movimento de câmera")
