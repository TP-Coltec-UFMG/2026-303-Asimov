extends Node2D

@onready var transition: AnimatedSprite2D = $Input_transition_acessibility
@onready var options_frame_rate: OptionButton = $Opcoes/OptionsFrameRate
@onready var options_interface_size: OptionButton = $Opcoes/OptionsInterfaceSize


func _ready() -> void:
	HighContrast.apply_to_tree(self)
	transition.visible = true
	transition.frame = 8
	transition.play_backwards("default")

	var interface_index: int = int(Configs.configs.get("size_interface", 0))
	call_deferred("aplicar_tamanho_interface_por_index", interface_index)


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
	Engine.max_fps = options_frame_rate.get_item_id(index)
	Configs._change_frame_rate(Engine.max_fps)

	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(options_frame_rate.get_item_id(index))))


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
		LeitorDeTela._ler_texto(atr(str(options_frame_rate.get_item_id(index))))


func _on_options_interface_size_item_selected(index: int) -> void:
	Configs._change_interface_size(index)
	print(Configs.configs["interface_size"])
	aplicar_tamanho_interface_por_index(index)

	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(options_interface_size.get_item_text(index))))


func obter_fator_interface(index: int) -> float:
	match index:
		0:
			return 1.0 # Padrão
		1:
			return 0.8 # Pequeno
		2:
			return 1.2 # Grande
		_:
			return 1.0


func aplicar_tamanho_interface_por_index(index: int) -> void:
	var fator: float = obter_fator_interface(Configs.configs.interface_size)

	if has_node("Opcoes"):
		aplicar_tamanho_interface($Opcoes, fator)

	if has_node("Logo"):
		aplicar_tamanho_interface($Logo, fator)
	elif has_node("logo"):
		aplicar_tamanho_interface($logo, fator)


func aplicar_tamanho_interface(node: Node, fator: float) -> void:
	salvar_valores_originais(node)
	aplicar_escala_node(node, fator)

	for child in node.get_children():
		aplicar_tamanho_interface(child, fator)


func salvar_valores_originais(node: Node) -> void:
	if node.has_meta("valores_salvos"):
		return

	if node is OptionButton:
		var option_button := node as OptionButton

		var font_size: int = option_button.get_theme_font_size("font_size")

		option_button.set_meta("base_font_size", font_size)

	elif node is CheckBox:
		var check_box := node as CheckBox

		var font_size: int = check_box.get_theme_font_size("font_size")
		var pos_y: float = check_box.position.y

		check_box.set_meta("base_font_size", font_size)
		check_box.set_meta("base_position_y", pos_y)

	elif node is Label:
		var label := node as Label

		var font_size: int = label.get_theme_font_size("font_size")
		var pos_y: float = label.position.y

		label.set_meta("base_font_size", font_size)
		label.set_meta("base_position_y", pos_y)

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		var scale_base: Vector2 = sprite.scale
		var pos_y: float = sprite.position.y

		sprite.set_meta("base_scale", scale_base)
		sprite.set_meta("base_position_y", pos_y)

	elif node is Button:
		var button := node as Button

		var scale_base: Vector2 = button.scale
		var pos_y: float = button.position.y

		button.set_meta("base_scale", scale_base)
		button.set_meta("base_position_y", pos_y)

	node.set_meta("valores_salvos", true)


func aplicar_escala_node(node: Node, fator: float) -> void:
	if node is OptionButton:
		var option_button := node as OptionButton

		if option_button.has_meta("base_font_size"):
			var base_font_size: int = int(option_button.get_meta("base_font_size"))
			var novo_font_size: int = int(round(base_font_size * fator))

			option_button.add_theme_font_size_override("font_size", novo_font_size)

			var popup: PopupMenu = option_button.get_popup()
			if popup != null:
				popup.add_theme_font_size_override("font_size", novo_font_size)

	elif node is CheckBox:
		var check_box := node as CheckBox

		if check_box.has_meta("base_font_size") and check_box.has_meta("base_position_y"):
			var base_font_size: int = int(check_box.get_meta("base_font_size"))
			var base_position_y: float = float(check_box.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			check_box.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = check_box.position
			nova_posicao.y = base_position_y - diferenca_fonte
			check_box.position = nova_posicao

	elif node is Label:
		var label := node as Label

		if label.has_meta("base_font_size") and label.has_meta("base_position_y"):
			var base_font_size: int = int(label.get_meta("base_font_size"))
			var base_position_y: float = float(label.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			label.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = label.position
			nova_posicao.y = base_position_y - diferenca_fonte
			label.position = nova_posicao

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if sprite.has_meta("base_scale") and sprite.has_meta("base_position_y"):
			var base_scale: Vector2 = sprite.get_meta("base_scale")
			var base_position_y: float = float(sprite.get_meta("base_position_y"))

			sprite.scale = base_scale * fator

			var nova_posicao: Vector2 = sprite.position
			nova_posicao.y = base_position_y * fator
			sprite.position = nova_posicao

	elif node is Button:
		var button := node as Button

		if button.has_meta("base_scale") and button.has_meta("base_position_y"):
			var base_scale: Vector2 = button.get_meta("base_scale")
			var base_position_y: float = float(button.get_meta("base_position_y"))

			button.scale = base_scale * fator

			var nova_posicao: Vector2 = button.position
			nova_posicao.y = base_position_y * fator
			button.position = nova_posicao


func _on_options_interface_size_item_focused(index: int) -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Tamanho da Interface"))


func _on_options_interface_size_mouse_entered() -> void:
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Tamanho da Interface"))
