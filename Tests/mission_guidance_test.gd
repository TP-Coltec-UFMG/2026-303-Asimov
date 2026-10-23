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
	var mundo := Node2D.new()
	get_tree().root.add_child(mundo)
	get_tree().current_scene = mundo
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	mundo.add_child(jogador)
	jogador.position = Vector2(-100, -100)
	scene_manager.player = jogador
	var cabo := preload("res://Objects/cabo.tscn").instantiate() as ItemColetavel
	var notebook := preload("res://Objects/laptop.tscn").instantiate() as ItemColetavel
	mundo.add_child(cabo)
	mundo.add_child(notebook)
	cabo.position = Vector2(100, 100)
	notebook.position = Vector2(150, 100)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var painel := jogador.get_node("QUEST_MISSION") as QuestMissionUI
	var orientacao := painel.get_node("OrientacaoTarefas")
	orientacao.verificacao.stop()
	for indice in painel.linhas.size():
		painel.definir_tarefa_visivel(indice, indice < 3)
		painel.definir_tarefa_concluida(indice, indice == 0)
	painel.definir_texto_tarefa(1, "ENCONTRE UM CABO")
	painel.definir_texto_tarefa(2, "ENCONTRE UM NOTEBOOK")
	painel.definir_painel_visivel(true)
	var texto := painel.linhas[1].get_node("Label3") as Label
	var estilo := texto.label_settings
	var contorno_cabo := cabo.get_node("Sprite2D/ColorAccessibilityCue")
	var contorno_note := notebook.get_node("Sprite2D/ColorAccessibilityCue")
	for intervalo in range(59):
		orientacao._ao_verificar()
	_conferir(orientacao.texto_destacado == null, "O lembrete deve esperar quinze segundos.")
	_conferir(not contorno_cabo._mission_hint, "Itens não devem brilhar antes do atraso.")
	painel._oculto_automaticamente = true
	painel.hide()
	orientacao._ao_verificar()
	_conferir(painel.visible, "O lembrete deve revelar o painel dinâmico.")
	_conferir(orientacao.texto_destacado == texto, "Somente a primeira tarefa pendente deve pulsar.")
	_conferir(texto.label_settings != estilo and painel.linhas[0].get_node("Label3").label_settings == estilo, "O brilho não pode modificar o estilo compartilhado das outras tarefas.")
	_conferir(contorno_cabo._mission_hint and contorno_note._mission_hint, "Os dois itens procurados devem receber contorno.")
	await get_tree().create_timer(0.6).timeout
	_conferir(texto.label_settings.outline_color.a > 0.3, "A borda deve surgir com fade.")
	painel.definir_tarefa_concluida(1, true)
	orientacao._ao_verificar()
	_conferir(texto.label_settings == estilo and not contorno_cabo._mission_hint, "Concluir a tarefa deve remover o brilho e restaurar o texto.")
	_conferir(orientacao.tempo_sem_progresso < 1.0, "Progresso deve reiniciar a espera.")
	for intervalo in range(59):
		orientacao._ao_verificar()
	_conferir(contorno_note._mission_hint and not contorno_cabo._mission_hint, "O novo lembrete deve destacar apenas o item ainda necessário.")
	contorno_note.set_forced_outline(true)
	painel.oculto_no_elevador = true
	var tempo: float = orientacao.tempo_sem_progresso
	orientacao._ao_verificar()
	_conferir(is_equal_approx(tempo, orientacao.tempo_sem_progresso) and not contorno_note._mission_hint, "Elevadores devem suspender o lembrete e os destaques.")
	_conferir(contorno_note.visible and contorno_note._forced_outline, "Remover uma dica não pode remover outro contorno ativo.")
	contorno_note.set_forced_outline(false)
	painel.oculto_no_elevador = false
	painel.definir_painel_visivel(false)
	mundo.remove_child(jogador)
	_conferir(not contorno_note._mission_hint and orientacao.texto_destacado == null, "Trocar de mapa deve limpar os destaques da cena anterior.")
	mundo.add_child(jogador)
	await get_tree().process_frame
	await get_tree().process_frame
	_conferir(not orientacao.verificacao.is_stopped(), "A orientação deve continuar funcionando ao retornar de outro mapa ou minigame.")
	orientacao.verificacao.stop()
	var cientista := preload("res://NPC'S/Clarxs.tscn").instantiate() as PersonagemNPC
	cientista.save_enabled = false
	cientista.empurravel_pelo_player = true
	mundo.add_child(cientista)
	jogador.position = Vector2(-12, 0)
	await get_tree().create_timer(1.0).timeout
	_conferir(cientista.desvio_multidao_habilitado and cientista.agente_desvio.avoidance_enabled, "O cientista deve usar o desvio nativo do Godot.")
	_conferir(cientista.position.x > 1.0, "O cientista deve ceder espaço ao player.")
	_conferir(cientista.get_node("CharacterBody2D").collision_mask == 1, "O cientista deve respeitar colisões do mapa ao ser empurrado.")
	var arquivo := FileAccess.open("res://.guidance-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"completed": true, "failures": falhas}))
	arquivo.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
