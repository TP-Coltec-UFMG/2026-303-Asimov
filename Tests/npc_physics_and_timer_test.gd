extends Node

const DIFICULDADE := preload("res://Scripts/Data/difficulty_settings.gd")
var falhas: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	ContextualTutorial.set_process(false)
	for profissao: String in ["programador", "engenheiro_eletrico"]:
		Configs.configs["job"] = profissao
		for dificuldade: String in ["easy", "normal", "hard"]:
			Configs.configs["difficulty"] = dificuldade
			var esperado: float = {"easy": 1200.0, "normal": 900.0, "hard": 600.0}[dificuldade]
			_conferir(is_equal_approx(DIFICULDADE.initial_time_seconds(), esperado), "Tempo incorreto para %s/%s." % [profissao, dificuldade])
			SaveGame.tempo_atual = -1.0
			var cronometro := preload("res://Objects/controle_de_tempo.tscn").instantiate()
			add_child(cronometro)
			_conferir(is_equal_approx(cronometro.get_limite_da_partida(), esperado), "O cronômetro real deve respeitar a dificuldade inclusive no modo dev.")
			_conferir(is_equal_approx(cronometro.get_tempo_restante(), esperado), "Nova partida deve começar com o tempo completo.")
			cronometro.queue_free()
			await get_tree().process_frame
	var cientista := preload("res://NPC'S/Clarxs.tscn").instantiate() as PersonagemNPC
	cientista.save_enabled = false
	cientista.empurravel_pelo_player = true
	cientista.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(cientista)
	await get_tree().physics_frame
	await get_tree().physics_frame
	cientista.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	cientista._ao_calcular_velocidade_segura(Vector2(10, 0))
	_conferir(cientista.position == Vector2.ZERO, "NPC desativado não deve se mover pelo retorno do desvio.")
	cientista.process_mode = Node.PROCESS_MODE_PAUSABLE
	var corpo := cientista.get_node("CharacterBody2D") as CharacterBody2D
	corpo.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().physics_frame
	cientista._ao_calcular_velocidade_segura(Vector2(10, 0))
	_conferir(cientista.position == Vector2.ZERO, "Corpo removido da simulação não deve receber move_and_slide.")
	corpo.process_mode = Node.PROCESS_MODE_INHERIT
	remove_child(cientista)
	cientista._ao_calcular_velocidade_segura(Vector2(10, 0))
	add_child(cientista)
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = true
	cientista._ao_calcular_velocidade_segura(Vector2(10, 0))
	_conferir(cientista.position == Vector2.ZERO, "A pausa deve bloquear retornos pendentes do desvio.")
	get_tree().paused = false
	cientista._ao_calcular_velocidade_segura(Vector2(10, 0))
	_conferir(cientista.position.x > 0.0, "Ao retornar à física o cientista deve continuar podendo se mover.")
	var arquivo := FileAccess.open("res://.physics-timer-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"completed": true, "failures": falhas}))
	arquivo.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
