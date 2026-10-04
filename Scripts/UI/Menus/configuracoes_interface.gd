extends Node2D

@onready var opcoes_taxa_quadros: OptionButton = $OptionsFrameRate
@onready var opcoes_tamanho_interface: OptionButton = $OptionsInterfaceSize


func _on_tela_cheia_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		Configs._change_tela_cheia(true)
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Tela cheia ativada"))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		Configs._change_tela_cheia(false)
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Tela cheia desativada"))


func _on_mostrar_fps_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Configs._change_mostrar_fps(true)
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Mostrar FPS ativado"))
	else:
		Configs._change_mostrar_fps(false)
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Mostrar FPS desativado"))


func _on_options_frame_rate_item_selected(index: int) -> void:
	Engine.max_fps = opcoes_taxa_quadros.get_item_id(index)
	Configs._change_frame_rate(Engine.max_fps)

	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(opcoes_taxa_quadros.get_item_id(index))))


func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func _on_tela_cheia_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Tela Cheia"))


func _on_mostrar_fps_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Mostrar FPS"))


func _on_options_frame_rate_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Limite de FPS"))


func _on_options_frame_rate_item_focused(index: int) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(opcoes_taxa_quadros.get_item_id(index))))


func _ao_escolher_tamanho_interface(index: int) -> void:
	Configs._change_interface_size(index)
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(opcoes_tamanho_interface.get_item_text(index))))
