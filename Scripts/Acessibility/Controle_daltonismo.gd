extends VBoxContainer

func _on_option_daltonismo_button_item_selected(index: int) -> void:
	Configs._change_filtro_de_daltonismo(index)
	FiltroDaltonismo.aplicar_filtro(index, $IntensidadeDaltonismo.value)
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr($OptionDaltonismoButton.get_item_text(index)))
	
func _on_intensidade_value_changed(value: float) -> void:
	Configs._change_intensidade_filtro_daltonismo(value)
	FiltroDaltonismo.aplicar_filtro($OptionDaltonismoButton.selected, value)
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value)))


func _on_option_daltonismo_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Filtro de Daltonismo"))


func _on_legendas_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Legendas"))


func _on_tamanho_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Tamanho legenda"))


func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func _on_intensidade_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Intensidade Filtro de Daltonismo"))
	pass # Replace with function body.


func _on_leitor_de_tela_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Leitor de Tela"))
