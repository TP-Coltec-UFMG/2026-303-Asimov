extends VBoxContainer

func _on_option_daltonismo_button_item_selected(index: int) -> void:
	Configs._change_filtro_de_daltonismo(index)
	FiltroDaltonismo.aplicar_filtro(index)
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr($OptionDaltonismoButton.get_item_text(index)))


func _on_option_daltonismo_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Auxílio de cores"))


func _on_legendas_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Legendas"))


func _on_tamanho_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Tamanho legenda"))


func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func _on_leitor_de_tela_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Leitor de Tela"))
