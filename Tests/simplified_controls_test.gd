extends Node

var falhas: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	SaveGame.tempo_atual = 300.0
	ContextualTutorial.set_process(false)
	ContextualTutorial.tutorial_ativo = ""
	Configs.configs["leitor_de_tela"] = false
	for caminho: String in ["res://Scenes/principal.tscn", "res://Scenes/pause_menu.tscn"]:
		var menu := load(caminho).instantiate() as Node
		add_child(menu)
		menu.show()
		menu.get_node("Accessibility").show()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var rolagem := menu.get_node("Accessibility/Rolagem") as ScrollContainer
		var titulo_filtro := rolagem.get_node("VContainer/TituloFiltro") as Label
		var seletor_filtro := rolagem.get_node("VContainer/OptionDaltonismoButton") as OptionButton
		_conferir(rolagem.get_global_rect().encloses(titulo_filtro.get_global_rect()), "O título do filtro deve aparecer inteiro dentro da rolagem.")
		_conferir(titulo_filtro.get_global_rect().end.y <= seletor_filtro.get_global_rect().position.y, "O título do filtro não pode sobrepor o seletor.")
		_conferir(rolagem.follow_focus and rolagem.get_v_scroll_bar().max_value > rolagem.get_v_scroll_bar().page, "As opções de acessibilidade devem ter rolagem e acompanhar o foco.")
		for linha in rolagem.get_node("VContainer").get_children():
			for filho in linha.get_children():
				if filho is Sprite2D and str(filho.name).begins_with("Sprite"):
					var area: Rect2 = filho.global_transform * filho.get_rect()
					_conferir(area.position.x >= rolagem.global_position.x and area.end.x <= rolagem.get_global_rect().end.x, "Ícone fora da rolagem: %s, área %s, rolagem %s." % [filho.get_path(), area, rolagem.get_global_rect()])
		var corrida := rolagem.get_node("VContainer/CorridaAutomatica") as CheckBox
		var equipamento := rolagem.get_node("VContainer/EquiparAutomaticamente") as CheckBox
		corrida.button_pressed = true
		_conferir(bool(Configs.configs["corrida_automatica"]), "A opção de corrida deve atualizar a configuração.")
		equipamento.button_pressed = false
		_conferir(not bool(Configs.configs["equipar_itens_automaticamente"]), "O equipamento automático deve poder ser desativado.")
		corrida.button_pressed = false
		equipamento.button_pressed = true
		menu.queue_free()
		await get_tree().process_frame
	Engine.max_fps = 60
	var mundo := Node2D.new()
	get_tree().root.add_child(mundo)
	get_tree().current_scene = mundo
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	mundo.add_child(jogador)
	scene_manager.player = jogador
	await get_tree().physics_frame
	await get_tree().physics_frame
	Configs.configs["corrida_automatica"] = true
	Input.action_press("right")
	for quadro in range(50):
		await get_tree().physics_frame
	_conferir(not jogador.correndo and is_equal_approx(jogador.move_speed, jogador.VELOCIDADE_NORMAL), "O movimento deve começar andando.")
	for quadro in range(130):
		await get_tree().physics_frame
	_conferir(jogador.correndo and jogador.move_speed > jogador.VELOCIDADE_NORMAL and jogador.move_speed <= jogador.VELOCIDADE_CORRIDA, "Manter uma direção deve iniciar a corrida sem aumentar a velocidade máxima.")
	_conferir(jogador.cansaco > 0.0, "A corrida automática deve consumir estamina.")
	Input.action_release("right")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_conferir(not jogador.correndo and jogador.tempo_corrida_automatica == 0.0, "Soltar a direção deve cancelar a corrida.")
	Configs.configs["corrida_automatica"] = false
	Input.action_press("right")
	for quadro in range(160):
		await get_tree().physics_frame
	_conferir(not jogador.correndo, "Desativar a opção deve manter o movimento manual.")
	Input.action_press("correr")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_conferir(jogador.correndo, "A corrida manual deve continuar funcionando.")
	Input.action_release("right")
	Input.action_release("correr")
	var itens := {"gun": "res://Objects/arma.tscn", "cartao": "res://Objects/cartao_padrao.tscn", "laptop": "res://Objects/laptop.tscn", "cabo": "res://Objects/cabo.tscn", "lanterna": "res://Objects/Lanterna.tscn", "extintor": "res://Objects/extintor.tscn"}
	for id_item: String in itens:
		jogador.inventory.add_item(id_item, load(itens[id_item]))
	Configs.configs["equipar_itens_automaticamente"] = true
	for id_item: String in itens:
		_conferir(jogador.equipar_item_automaticamente(id_item), "Itens disponíveis devem poder ser equipados automaticamente: " + id_item)
		_conferir(jogador.inventory.equipped_item_id == id_item, "O slot equipado deve acompanhar a seleção automática.")
		for guardado: String in itens:
			_conferir(jogador.inventory.get_item_on_inventary(guardado), "Trocar de equipamento não pode descartar outro item.")
	Configs.configs["equipar_itens_automaticamente"] = false
	_conferir(not jogador.equipar_item_automaticamente("cartao") and jogador.usando_extintor, "Desativar a opção deve preservar o equipamento atual.")
	Configs.configs["equipar_itens_automaticamente"] = true
	jogador.set_physics_process(false)
	_conferir(not jogador.equipar_item_automaticamente("cartao"), "Cutscenes e minigames não podem selecionar equipamentos por interações.")
	jogador.set_physics_process(true)
	var interface := Node.new()
	interface.name = "UI"
	mundo.add_child(interface)
	var cronometro := Control.new()
	cronometro.name = "Controle_de_tempo"
	interface.add_child(cronometro)
	var leitor := preload("res://Scenes/scene_trigger.tscn").instantiate() as SceneTrigger
	leitor.cena_destino = "sala_chefe"
	leitor.acesso_controlado = true
	mundo.add_child(leitor)
	leitor.dentro_da_area = true
	leitor.jogador = jogador
	var interagir := InputEventAction.new()
	interagir.action = &"interact"
	interagir.pressed = true
	leitor._unhandled_input(interagir)
	_conferir(jogador.usando_cartao, "Interagir com o leitor deve equipar o cartão sem outra tecla.")
	_conferir(not leitor._tem_cartao_compativel(), "Equipar automaticamente não pode permitir cartão padrão em porta do chefe.")
	jogador.reset_sprite_player()
	jogador.inventory.remove_item("cartao")
	jogador.inventory.add_item("cartao", preload("res://Objects/cartao_chefe.tscn"))
	leitor._unhandled_input(interagir)
	_conferir(jogador.usando_cartao and leitor._tem_cartao_compativel(), "O cartão do chefe deve continuar autorizando a porta correta.")
	jogador.camera_2d.enabled = false
	await get_tree().process_frame
	var fogo := preload("res://Objects/fogo.tscn").instantiate() as Node2D
	fogo.save_enabled = false
	fogo.damage_enabled = false
	mundo.add_child(fogo)
	fogo.global_position = jogador.get_global_mouse_position()
	jogador.global_position = fogo.global_position + Vector2(20, 0)
	var apagar := InputEventAction.new()
	apagar.action = &"usar_extintor"
	apagar.pressed = true
	fogo._unhandled_input(apagar)
	_conferir(jogador.usando_extintor and jogador.inventory.get_item_control("extintor").extintor_ligado, "Tentar apagar um fogo próximo deve equipar o extintor e começar a usá-lo no mesmo comando.")
	jogador.inventory.get_item_control("extintor").definir_fumaca(false)
	jogador.equipar_item("cartao")
	Configs.configs["equipar_itens_automaticamente"] = false
	fogo._unhandled_input(apagar)
	_conferir(jogador.usando_cartao, "Desativar a seleção automática deve preservar a escolha manual diante do fogo.")
	fogo.queue_free()
	var arquivo := FileAccess.open("res://.simplified-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"completed": true, "failures": falhas}))
	arquivo.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
