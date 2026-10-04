extends Node

var falhas: Array[String] = []
var verificacoes: int = 0

func _ready() -> void:
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	Progresso.modo_teste = true
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	SaveGame.tempo_atual = 300.0
	for jogo in range(2):
		for fase in range(4):
			var cena: Node = load(Progresso.CAMINHOS[jogo][fase]).instantiate()
			get_tree().root.add_child(cena)
			get_tree().current_scene = cena
			await get_tree().process_frame
			_verificar(cena.jogador.get_node("Forma").shape != null, "Colisão do jogador deve estar na cena.")
			_verificar(cena.objetivo.get_node("Forma").shape != null, "Colisão do objetivo deve estar na cena.")
			_verificar(cena.jogador.is_in_group("jogador"), "Grupo do jogador deve estar na cena.")
			_verificar(cena.sons.get_node("ok").stream != null, "Som de sucesso deve estar na cena.")
			cena.pausar()
			_verificar(get_tree().paused and cena.modal.visible, "Pausa deve mostrar o painel.")
			_verificar(get_viewport().gui_get_focus_owner() == cena.botao_continuar, "Pausa deve aceitar teclado.")
			cena.botao_continuar.pressed.emit()
			_verificar(not get_tree().paused and not cena.modal.visible, "Continuar deve retomar a fase.")
			cena.jogador.capturado.emit()
			_verificar(cena.estado == "falhou" and cena.modal.visible, "Captura deve mostrar a falha.")
			_verificar(cena.get_node("Arena").process_mode == Node.PROCESS_MODE_DISABLED, "Falha deve bloquear a arena.")
			if jogo == 1:
				cena.jogador.historico.append(cena.jogador.position)
				cena.botao_desfazer.pressed.emit()
				_verificar(cena.estado == "jogando" and not cena.modal.visible, "Desfazer deve restaurar a fase de deslizar.")
			if jogo == 0 and fase == 3:
				cena.estado = "jogando"
				Progresso.retorno_da_sala_do_chefe = true
				cena.objetivo.call("_entrou", cena.jogador)
				await get_tree().create_timer(0.55).timeout
				_verificar(cena.estado == "venceu" and cena.botao_sair.visible, "Objetivo deve abrir a conclusão.")
				_verificar(bool(SaveGame.office_mission_state().get("office_boss_room_hacked", false)), "Hack deve liberar a sala do chefe.")
				Progresso.cena_de_retorno = ""
				Progresso.menu()
				_verificar(not Progresso.retorno_da_sala_do_chefe, "Saída deve limpar o retorno do hack.")
			get_tree().current_scene = null
			cena.queue_free()
			await get_tree().process_frame
	var resultado := FileAccess.open("res://.minigames-editor-result.json", FileAccess.WRITE)
	resultado.store_string(JSON.stringify({"completed": true, "checks": verificacoes, "failures": falhas}))
	resultado.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _verificar(condicao: bool, mensagem: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
