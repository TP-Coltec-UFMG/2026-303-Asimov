extends CheckBox


func _ready() -> void:
	button_pressed = Configs.configs.alto_contraste


func _on_toggled(value: bool) -> void:
	Configs._change_alto_contraste(value)
	HighContrast.set_enabled(value)
	if value:
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Alto Contraste Ligado"))
	else:
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Alto Contraste Desligado"))


func _on_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Alto Contraste"))
