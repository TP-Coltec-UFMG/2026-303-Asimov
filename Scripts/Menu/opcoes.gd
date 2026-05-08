class_name menu_opcoes
extends Node2D

@onready var transition: AnimatedSprite2D = $Input_transition


func _ready() -> void:
	HighContrast.apply_to_tree(self)
	transition.visible = true
	transition.frame = 5
	transition.play_backwards("default")

	var interface_index: int = int(Configs.configs.get("interface_size", 0))
	call_deferred("aplicar_tamanho_interface_por_index", interface_index)


func _on_option_language_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Idioma"))


func _on_menu_sounds_settings_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Opções de Volume"))


func _on_menu_controllers_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Opções de Controles"))


func _on_menu_interface_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Opções de Interface"))


func _on_menu_acessibilidadades_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Opções de Acessibilidade"))


func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func obter_fator_interface(index: int) -> float:
	match index:
		0:
			return 1.0 # Padrão
		1:
			return 0.8 # Pequeno
		2:
			return 1.25 # Grande
		_:
			return 1.0


func aplicar_tamanho_interface_por_index(index: int) -> void:
	var fator: float = obter_fator_interface(index)
	aplicar_tamanho_interface(self, fator, index)


func aplicar_tamanho_interface(node: Node, fator: float, interface_index: int) -> void:
	salvar_valores_originais(node)
	aplicar_escala_node(node, fator, interface_index)

	for child in node.get_children():
		aplicar_tamanho_interface(child, fator, interface_index)


func salvar_valores_originais(node: Node) -> void:
	if node.has_meta("valores_salvos"):
		return

	if node is Button:
		var button := node as Button

		var font_size: int = button.get_theme_font_size("font_size")
		var scale_base: Vector2 = button.scale
		var pos_y: float = button.position.y

		button.set_meta("base_font_size", font_size)
		button.set_meta("base_expand_icon", button.expand_icon)
		button.set_meta("base_scale", scale_base)
		button.set_meta("base_position_y", pos_y)

	elif node is Label:
		var label := node as Label

		var font_size: int = label.get_theme_font_size("font_size")
		var pos_y: float = label.position.y

		label.set_meta("base_font_size", font_size)
		label.set_meta("base_position_y", pos_y)

	node.set_meta("valores_salvos", true)


func aplicar_escala_node(node: Node, fator: float, interface_index: int) -> void:
	if node is Button:
		var button := node as Button

		if button.has_meta("base_font_size"):
			var base_font_size: int = int(button.get_meta("base_font_size"))
			var novo_font_size: int = int(round(base_font_size * fator))

			button.add_theme_font_size_override("font_size", novo_font_size)

		if button.has_meta("base_scale"):
			var base_scale: Vector2 = button.get_meta("base_scale")
			button.scale = base_scale * fator

		if button.has_meta("base_position_y"):
			var base_position_y: float = float(button.get_meta("base_position_y"))

			var nova_posicao: Vector2 = button.position
			nova_posicao.y = base_position_y * fator
			button.position = nova_posicao

		if button.has_meta("base_expand_icon"):
			if interface_index == 2:
				button.expand_icon = true
			else:
				button.expand_icon = bool(button.get_meta("base_expand_icon"))

	elif node is Label:
		var label := node as Label

		if label.has_meta("base_font_size") and label.has_meta("base_position_y"):
			var base_font_size: int = int(label.get_meta("base_font_size"))
			var base_position_y: float = float(label.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))

			label.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = label.position

			if interface_index == 2:
				nova_posicao.y = base_position_y - 6.0
			else:
				nova_posicao.y = base_position_y

			label.position = nova_posicao
