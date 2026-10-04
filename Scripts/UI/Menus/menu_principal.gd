extends Node2D

@onready var transicao: AnimatedSprite2D = $Transition
@onready var primeira_vez: Node2D = $PrimeiraVez
@onready var botao_novo_jogo: Button = $"Menu Inicial/VContainer/NewGameButton"
@onready var confirmacao_reiniciar: Control = $"Menu Inicial/Confirmacao_reiniciar"
@onready var tela_retorno_final: ColorRect = $EndingReturnFade/Black
@onready var animacao_retorno_final: AnimationPlayer = $EndingReturnFade/AnimationPlayer


var caminho_proxima_cena: String

const AJUSTE_LABEL_GRANDE: float = 6.0
const GRUPO_INTERFACE: String = "interface_escalavel"
const ENDING_RETURN_META := &"programmer_ending_return"


func _ready() -> void:
	HighContrast.apply_to_tree(self)

	SaveLoad._load()
	SaveGame._load()

	var retornando_final := bool(get_tree().get_meta(ENDING_RETURN_META, false))
	if retornando_final:
		get_tree().remove_meta(ENDING_RETURN_META)
		transicao.hide()
		tela_retorno_final.show()
		animacao_retorno_final.play(&"ending_return_fade_in")
		MusicController.reduzir_audio_para_menu(10.0)
	else:
		MusicController.pausar_todos_audios()
		tela_retorno_final.hide()
		transicao.visible = true
		transicao.frame = 7
		transicao.play_backwards("default")

	if Configs.configs.primeira_vez:
		primeira_vez._iniciar()
		primeira_vez.visible = true
		Configs._change_primeira_vez()
	else:
		primeira_vez.visible = false
	confirmacao_reiniciar.hide()

	atualizar_botao_jogo()

	var indice_interface: int = int(Configs.configs.get("interface_size", 0))
	call_deferred("aplicar_tamanho_interface_por_index", indice_interface)

func obter_fator_interface(index: int) -> float:
	match index:
		0:
			return 1.0 # Padrão
		1:
			return 0.8 # Pequeno
		2:
			return 1.1 # Grande
		_:
			return 1.0

func aplicar_tamanho_interface_por_index(index: int) -> void:
	var fator: float = obter_fator_interface(index)
	aplicar_tamanho_interface(self, fator, index)

func aplicar_tamanho_interface(node: Node, fator: float, indice_interface: int) -> void:
	salvar_valores_originais(node)
	aplicar_escala_node(node, fator, indice_interface)

	for child in node.get_children():
		aplicar_tamanho_interface(child, fator, indice_interface)

func salvar_valores_originais(node: Node) -> void:
	if node.has_meta("valores_salvos"):
		return

	if node is OptionButton:
		var option_button := node as OptionButton

		var font_size: int = option_button.get_theme_font_size("font_size")
		var pos_y: float = option_button.position.y
		var minimum_size: Vector2 = option_button.custom_minimum_size

		option_button.set_meta("base_font_size", font_size)
		option_button.set_meta("base_position_y", pos_y)
		option_button.set_meta("base_minimum_size", minimum_size)

	elif node is CheckBox:
		var check_box := node as CheckBox

		var font_size: int = check_box.get_theme_font_size("font_size")
		var pos_y: float = check_box.position.y

		check_box.set_meta("base_font_size", font_size)
		check_box.set_meta("base_position_y", pos_y)

	elif node is Button:
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

	elif node is Slider:
		var slider := node as Slider

		var pos_y: float = slider.position.y
		var minimum_size: Vector2 = slider.custom_minimum_size
		var scale_base: Vector2 = slider.scale

		slider.set_meta("base_position_y", pos_y)
		slider.set_meta("base_minimum_size", minimum_size)
		slider.set_meta("base_scale", scale_base)

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if not sprite.is_in_group(GRUPO_INTERFACE):
			node.set_meta("valores_salvos", true)
			return

		var scale_base: Vector2 = sprite.scale
		var pos_y: float = sprite.position.y

		sprite.set_meta("base_scale", scale_base)
		sprite.set_meta("base_position_y", pos_y)

	elif node is BoxContainer:
		var box := node as BoxContainer

		var pos_y: float = box.position.y
		var minimum_size: Vector2 = box.custom_minimum_size
		var separation: int = box.get_theme_constant("separation")

		box.set_meta("base_position_y", pos_y)
		box.set_meta("base_minimum_size", minimum_size)
		box.set_meta("base_separation", separation)

	node.set_meta("valores_salvos", true)

func aplicar_escala_node(node: Node, fator: float, indice_interface: int) -> void:
	if node is OptionButton:
		var option_button := node as OptionButton

		if option_button.has_meta("base_font_size") and option_button.has_meta("base_position_y"):
			var base_font_size: int = int(option_button.get_meta("base_font_size"))
			var base_position_y: float = float(option_button.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			option_button.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = option_button.position
			nova_posicao.y = base_position_y - diferenca_fonte
			if not _posicao_fixa_tela(option_button):
				option_button.position = nova_posicao

			var popup: PopupMenu = option_button.get_popup()
			if popup != null:
				popup.add_theme_font_size_override("font_size", novo_font_size)

		if option_button.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = option_button.get_meta("base_minimum_size")
			option_button.custom_minimum_size = base_minimum_size * fator

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
			if not _posicao_fixa_tela(check_box):
				check_box.position = nova_posicao

	elif node is Button:
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
			if not _posicao_fixa_tela(button):
				button.position = nova_posicao

		if button.has_meta("base_expand_icon"):
			if indice_interface == 2:
				if node.is_in_group("Botoes_Controles"):
					button.expand_icon = false
				else:
					button.expand_icon = true
			else:
				button.expand_icon = bool(button.get_meta("base_expand_icon"))

	elif node is Label:
		var label := node as Label

		if label.has_meta("base_font_size") and label.has_meta("base_position_y"):
			var base_font_size: int = int(label.get_meta("base_font_size"))
			var base_position_y: float = float(label.get_meta("base_position_y"))

			var novo_font_size: int = int(round(base_font_size * fator))
			var diferenca_fonte: int = novo_font_size - base_font_size

			if indice_interface == 2 and esta_dentro_do_logo(label):
				novo_font_size = base_font_size
				diferenca_fonte = 0

			label.add_theme_font_size_override("font_size", novo_font_size)

			var nova_posicao: Vector2 = label.position
			nova_posicao.y = base_position_y - diferenca_fonte

			if indice_interface == 2 and not esta_dentro_do_logo(label):
				nova_posicao.y -= AJUSTE_LABEL_GRANDE

			if not _posicao_fixa_tela(label):
				label.position = nova_posicao

	elif node is Slider:
		var slider := node as Slider

		if slider.has_meta("base_scale"):
			var base_scale: Vector2 = slider.get_meta("base_scale")
			slider.scale = base_scale * fator

		if slider.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = slider.get_meta("base_minimum_size")
			slider.custom_minimum_size = base_minimum_size * fator

		if slider.has_meta("base_position_y"):
			var base_position_y: float = float(slider.get_meta("base_position_y"))

			var nova_posicao: Vector2 = slider.position
			nova_posicao.y = base_position_y * fator
			if not _posicao_fixa_tela(slider):
				slider.position = nova_posicao

	elif node is Sprite2D:
		var sprite := node as Sprite2D

		if not sprite.is_in_group(GRUPO_INTERFACE):
			return

		if sprite.has_meta("base_scale") and sprite.has_meta("base_position_y"):
			var base_scale: Vector2 = sprite.get_meta("base_scale")
			var base_position_y: float = float(sprite.get_meta("base_position_y"))

			sprite.scale = base_scale * fator

			var nova_posicao: Vector2 = sprite.position
			nova_posicao.y = base_position_y * fator
			if not _posicao_fixa_tela(sprite):
				sprite.position = nova_posicao

	elif node is BoxContainer:
		var box := node as BoxContainer

		if box.has_meta("base_minimum_size"):
			var base_minimum_size: Vector2 = box.get_meta("base_minimum_size")
			box.custom_minimum_size = base_minimum_size * fator

			
		if box.has_meta("base_separation"):
			var base_separation: int = int(box.get_meta("base_separation"))
			var new_separation: int
			if fator == 1.1:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation+((base_separation * -1) * 0.1)
			if fator == 0.8:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation-((base_separation * -1) * 0.2)
			if fator == 1:
				@warning_ignore("narrowing_conversion")
				new_separation = base_separation * fator
			var nova_separation: int = int(round(new_separation))

			box.add_theme_constant_override("separation", nova_separation)

func esta_dentro_do_logo(node: Node) -> bool:
	var atual := node.get_parent()

	while atual != null:
		if atual.name.to_lower() == "logo":
			return true

		atual = atual.get_parent()

	return false

func _posicao_fixa_tela(node: Node) -> bool:
	var atual := node
	while atual != null:
		if atual.name == "Menu Inicial" or atual.name == "Confirmacao_reiniciar":
			return true
		atual = atual.get_parent()
	return false


func atualizar_botao_jogo() -> void:
	var botao_reiniciar := get_node_or_null("Menu Inicial/VContainer/RestartGameButton") as Button
	if botao_reiniciar != null:
		botao_reiniciar.visible = SaveGame.has_checkpoint()
	if SaveGame.has_checkpoint():
		botao_novo_jogo.text = "CONTINUAR"
	else:
		botao_novo_jogo.text = "NOVO JOGO"
	
func _ao_iniciar_jogo() -> void:
	transicao.play("default")
	await transicao.animation_finished

	if SaveGame.has_checkpoint():
		SaveGame.load_last_checkpoint()
	else:
		MusicController.permitir_audio_cena()
		get_tree().change_scene_to_file("res://Scenes/slectionpage.tscn")

func _ao_abrir_tutorial() -> void:
	transicao.play("default")
	await transicao.animation_finished
	MusicController.permitir_audio_cena()
	Configs.tutorial_return_scene = "res://Scenes/principal.tscn"
	get_tree().change_scene_to_file("res://Tutorial/tutorial.tscn")
		
func _ao_abrir_opcoes() -> void:
	transicao.play("default")
	await transicao.animation_finished

	$"Menu Inicial".visible = false
	$Opcoes.visible = true
	$BackgroundMenuInicial.visible = false
	$BackgroundMenuOptions.visible = true

	$Opcoes/VContainer/OptionLanguageButton.grab_focus()

	transicao.play_backwards("default")

func _ao_fechar_jogo() -> void:

	transicao.play("default")
	await transicao.animation_finished
	SaveGame.persist_checkpoint()
	SaveLoad._save()
	get_tree().quit()



func _ao_voltar_menu() -> void:
	SaveLoad.save_data = Configs.configs
	SaveLoad._save()

	transicao.play("default")
	await transicao.animation_finished

	$"Menu Inicial".visible = true
	$Opcoes.visible = false
	$BackgroundMenuInicial.visible = true
	$BackgroundMenuOptions.visible = false

	_focar_menu_inicial()

	transicao.play_backwards("default")

func _focar_menu_inicial() -> void:
	if is_instance_valid(botao_novo_jogo):
		botao_novo_jogo.grab_focus()
		return
	var botao := get_node_or_null("Menu Inicial/VContainer/NewGameButton") as Button
	if botao != null:
		botao.grab_focus()

func _ao_reiniciar_jogo() -> void:
	confirmacao_reiniciar.show()
	confirmacao_reiniciar.get_node("sim").grab_focus()

func _on_sim_pressed() -> void:
	confirmacao_reiniciar.hide()
	SaveGame.reset_progress()

func _on_nao_pressed() -> void:
	confirmacao_reiniciar.hide()
	var restart := get_node_or_null("Menu Inicial/VContainer/RestartGameButton") as Button
	if restart != null:
		restart.grab_focus()

func _on_restart_game_button_mouse_entered() -> void:
	var restart := get_node_or_null("Menu Inicial/VContainer/RestartGameButton") as CanvasItem
	if restart != null:
		restart.modulate.a = 1.0

func _on_nao_mouse_entered() -> void:
	var nao := confirmacao_reiniciar.get_node_or_null("nao") as CanvasItem
	if nao != null:
		nao.modulate.a = 1.0

func _on_sim_mouse_entered() -> void:
	var sim := confirmacao_reiniciar.get_node_or_null("sim") as CanvasItem
	if sim != null:
		sim.modulate.a = 1.0

func _ao_abrir_configuracoes_som() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = false
	$SettingSound.visible = true
	transicao.play_backwards("default")

func _ao_abrir_controles() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = false
	$Controles.visible = true
	transicao.play_backwards("default")

func _ao_abrir_interface() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = false
	$Interface.visible = true
	transicao.play_backwards("default")

func _ao_abrir_acessibilidade() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = false
	$Accessibility.visible = true
	transicao.play_backwards("default")


func _ao_voltar_configuracoes_som() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = true
	$SettingSound.visible = false
	transicao.play_backwards("default")

func _ao_voltar_configuracoes_interface() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = true
	$Interface.visible = false
	transicao.play_backwards("default")

func _ao_escolher_tamanho_interface(index: int) -> void:
	aplicar_tamanho_interface_por_index(index)

func _ao_voltar_acessibilidade() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = true
	$Accessibility.visible = false
	transicao.play_backwards("default")

func _ao_voltar_primeira_vez() -> void:
	$"Menu Inicial".visible = true
	$PrimeiraVez.visible = false

func _ao_voltar_controles() -> void:
	transicao.play("default")
	await transicao.animation_finished
	$Opcoes.visible = true
	$Controles.visible = false
	transicao.play_backwards("default")
