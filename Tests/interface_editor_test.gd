extends Node

var falhas: Array[String] = []
var verificacoes: int = 0
var configuracoes_originais: Dictionary
var progresso_original: Dictionary


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	configuracoes_originais = Configs.configs.duplicate(true)
	progresso_original = SaveGame.save_data.duplicate(true)
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	SaveGame.save_data = {}
	_executar.call_deferred()


func _executar() -> void:
	for caminho in ["res://Scenes/principal.tscn", "res://Scenes/pause_menu.tscn", "res://Scenes/slectionpage.tscn"]:
		var menu := (load(caminho) as PackedScene).instantiate()
		add_child(menu)
		if menu is CanvasItem:
			(menu as CanvasItem).show()
		await get_tree().process_frame
		await get_tree().process_frame
		var roteador := menu.get_node("MenuInputRouter") as MenuInputRouter
		_verificar(roteador.get_node_or_null("InputModeIndicatorLayer/InputModeIndicator/Icone") != null, "O indicador deve existir antes da execução do menu.")
		var controles := menu.get_node_or_null("Controles")
		if controles != null:
			controles.show()
			var botoes := controles.find_children("Remap_*", "Button", true, false)
			_verificar(botoes.size() == 21, "As 21 ações devem existir na cena de controles.")
			for botao: InputRemapButton in botoes:
				_verificar(botao.is_in_group(&"Botoes_Controles") and botao.is_in_group(&"alto_contraste"), "Os grupos do remapeamento devem estar salvos na cena.")
				_verificar(botao.pressed.is_connected(botao._ao_pressionar), "O sinal do botão deve estar conectado na cena.")
				_verificar(botao.remap_conflict.is_connected(controles._mostrar_aviso_conflito), "O aviso de conflito deve estar conectado na cena.")
				botao.mouse_entered.emit()
				_verificar(botao.has_focus(), "O foco por mouse deve alcançar cada botão de remapeamento.")
			var assistencia := controles.get_node("RemapPanel/Margin/ControlsScroll/Content/AssistenciaMira") as CheckButton
			assistencia.button_pressed = not assistencia.button_pressed
			_verificar(bool(Configs.configs["assistencia_mira"]) == assistencia.button_pressed, "A assistência de mira deve atualizar a configuração.")
			var botao_tiro := controles.find_child("Remap_fire", true, false) as InputRemapButton
			var entrada := InputMap.action_get_events("up")[0].duplicate() as InputEvent
			var entradas_originais := InputMap.action_get_events("fire")
			botao_tiro.remapear(entrada)
			_verificar(controles.painel_aviso.visible and not controles.texto_aviso.text.is_empty(), "Uma tecla duplicada deve exibir o aviso de conflito.")
			InputMap.action_erase_events("fire")
			for evento in entradas_originais:
				InputMap.action_add_event("fire", evento)
			botao_tiro.atualizar_texto()
			roteador._definir_modo_entrada(MenuInputRouter.InputMode.KEYBOARD)
			botoes[0].grab_focus()
			await get_tree().process_frame
			_verificar(botoes[0].has_focus(), "O teclado deve conseguir focar os controles.")
			for controle: Control in menu.find_children("*", "Control", true, false):
				if controle is Slider:
					_verificar(controle.get_node_or_null("KeyboardFocusOutline") != null, "As bordas dos sliders devem existir no editor.")
		menu.queue_free()
		await get_tree().process_frame
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	add_child(jogador)
	await get_tree().process_frame
	await get_tree().process_frame
	var painel := jogador.get_node("QUEST_MISSION") as QuestMissionUI
	Configs.configs["painel_tarefas_dinamico"] = true
	painel.aplicar_configuracao_painel_dinamico()
	painel.temporizador_exibicao.wait_time = 0.12
	painel.duracao_sumir_painel = 0.05
	painel.duracao_aparecer_painel = 0.05
	painel.definir_painel_visivel(false)
	painel.definir_painel_visivel(true)
	await get_tree().create_timer(0.3).timeout
	_verificar(painel._oculto_automaticamente and not painel.visible, "O Timer deve ocultar o painel com uma transição.")
	var tab := InputEventAction.new()
	tab.action = &"show_tasks"
	tab.pressed = true
	painel._unhandled_input(tab)
	await get_tree().create_timer(0.08).timeout
	_verificar(painel.visible and not painel._oculto_automaticamente, "Tab deve revelar o painel novamente.")
	painel.ocultar_durante_elevador()
	await get_tree().create_timer(0.2).timeout
	_verificar(not painel._oculto_automaticamente, "O tempo de exibição deve parar dentro do elevador.")
	painel.restaurar_apos_elevador()
	Configs.configs["painel_tarefas_dinamico"] = false
	painel.aplicar_configuracao_painel_dinamico()
	await get_tree().create_timer(0.3).timeout
	_verificar(painel.visible and not painel._oculto_automaticamente, "O painel deve permanecer visível quando a opção dinâmica estiver desligada.")
	_verificar(jogador.balao_de_pensamento.pensamento_finalizado.is_connected(painel._on_thought_finished), "O balão deve estar conectado ao painel na cena do jogador.")
	_verificar(jogador.get_node_or_null("NonLethalWarning/Root/MessagePanel/Label") != null, "A mensagem de reinício deve manter a hierarquia usada pelo jogador.")
	DialogManager.limpar_dialogos()
	var caixas_originais := DialogManager.get_children()
	_verificar(caixas_originais.size() == 4, "As caixas de diálogo devem existir na cena do gerenciador.")
	for indice in range(6):
		DialogManager.start_dialog(["Primeira fala.", "Segunda fala."], "teste_interface_%d" % indice)
		var caixa: MarginContainer = DialogManager.dialog_box
		_verificar(caixa in caixas_originais and caixa.em_uso, "A conversa deve reutilizar uma caixa preparada no editor.")
		caixa.avancar()
		_verificar(not caixa.digitando and caixa.texto.visible_characters == -1, "Avançar durante a digitação deve revelar a fala inteira.")
		caixa.avancar()
		_verificar(caixa.indice_atual == 1, "A próxima ação deve passar para a segunda fala.")
		caixa._fechar_dialogo()
		await DialogManager.dialog_finished
		_verificar(not caixa.em_uso and not caixa.visible, "Fechar a conversa deve liberar a caixa para reutilização.")
	_verificar(DialogManager.get_children() == caixas_originais, "Conversas sucessivas não devem criar ou excluir nós.")
	Configs.configs = configuracoes_originais
	SaveGame.save_data = progresso_original
	MusicController.parar_todos_audios()
	var arquivo := FileAccess.open("res://.interface-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"passed": falhas.is_empty(), "checks": verificacoes, "failures": falhas}, "\t"))
	for falha in falhas:
		push_error(falha)
	get_tree().quit(0 if falhas.is_empty() else 1)


func _verificar(condicao: bool, mensagem: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas.append(mensagem)
