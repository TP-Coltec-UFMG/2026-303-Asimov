extends Node2D

func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func _on_volume_slider_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Volume")) 


func _on_music_slider_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Música"))


func _on_sfx_slider_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Ambiente"))


func _on_ldt_slider_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Leitor de Tela"))


func _on_volume_slider_value_changed(value: float) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value * 100) + "%"))


func _on_music_slider_value_changed(value: float) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value * 100) + "%"))


func _on_sfx_slider_value_changed(value: float) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value * 100) + "%"))


func _on_ldt_slider_value_changed(value: float) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value * 100) + "%"))
