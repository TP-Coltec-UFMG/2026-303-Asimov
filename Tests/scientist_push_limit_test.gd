extends Node

var falhas: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	ContextualTutorial.set_process(false)
	ContextualTutorial.tutorial_ativo = ""
	var mundo := Node2D.new()
	get_tree().root.add_child(mundo)
	get_tree().current_scene = mundo
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	mundo.add_child(jogador)
	scene_manager.player = jogador
	jogador.position = Vector2(-18, 5)
	var cientista := preload("res://NPC'S/Clarxs.tscn").instantiate() as PersonagemNPC
	cientista.save_enabled = false
	cientista.empurravel_pelo_player = true
	cientista.animacoes = preload("res://NPC'S/Animacoes/scientist_1.tres")
	cientista.velocidade_corrida = 40.0
	mundo.add_child(cientista)
	var parede := StaticBody2D.new()
	parede.position = Vector2(28, 0)
	var colisao := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(4, 180)
	colisao.shape = forma
	parede.add_child(colisao)
	mundo.add_child(parede)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_press("right")
	var reagiu := false
	var atravessou := false
	for quadro in range(240):
		await get_tree().physics_frame
		reagiu = reagiu or cientista.resistindo_empurrao
		atravessou = atravessou or cientista.position.x > 22.0
	Input.action_release("right")
	_conferir(reagiu, "Insistir no empurrão deve provocar a reação do cientista.")
	_conferir(cientista.get_node("BalaoDePensamento").tem_pensamento("scientist:push_warning"), "O cientista deve falar Para!.")
	_conferir(not atravessou, "Empurrar contra a parede não pode levar o cientista para fora do mapa.")
	jogador.position = Vector2(-100, 5)
	await get_tree().create_timer(2.0).timeout
	_conferir(cientista.position.distance_to(cientista.posicao_antes_empurrao) < 2.0, "O cientista deve recuperar a posição anterior ao empurrão.")
	_conferir(not cientista.resistindo_empurrao, "Ao parar de insistir, a reação deve terminar.")
	cientista.position = Vector2(16, 0)
	cientista.posicao_antes_empurrao = Vector2.ZERO
	cientista.resistindo_empurrao = true
	cientista.tempo_sem_insistencia = 0.0
	jogador.position = Vector2(2, 5)
	await get_tree().create_timer(1.0).timeout
	_conferir(jogador.position.x < -5.0, "Ao voltar ao seu lugar o cientista deve afastar o player que bloqueia a passagem.")
	_conferir(cientista.position.distance_to(Vector2.ZERO) < 1.0, "O cientista deve recuperar seu lugar mesmo com o player na frente.")
	_conferir(cientista.resistindo_empurrao, "O cientista deve manter a posição enquanto o player continua encostado.")
	jogador.position = Vector2(-500, -500)
	for direcao: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		cientista.position = Vector2.ZERO
		cientista._reiniciar_paciencia()
		parede.position = direcao * 28.0
		forma.size = Vector2(4, 180) if direcao.x != 0 else Vector2(180, 4)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for quadro in range(24):
			cientista._ao_calcular_velocidade_segura(direcao * 160.0)
			await get_tree().physics_frame
		_conferir(cientista.position.dot(direcao) <= 22.1, "O corpo deve respeitar paredes em todas as direções.")
	var arquivo := FileAccess.open("res://.scientist-push-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"completed": true, "failures": falhas, "npc_position": str(cientista.position), "player_position": str(jogador.position)}))
	arquivo.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
