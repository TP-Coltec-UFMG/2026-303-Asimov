extends Node

var falhas: Array[String] = []


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_meta(&"dev_mission_jump_active", true)


func _ready() -> void:
	_executar.call_deferred()


func _executar() -> void:
	Engine.max_fps = 60
	Engine.time_scale = 1.0
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	MusicController.set_process(false)
	MusicController.parar_todos_audios()
	await get_tree().process_frame
	await get_tree().process_frame
	var mundo := Node2D.new()
	mundo.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(mundo)
	var disparo := preload("res://Objects/gun_muzzle_effect.tscn").instantiate()
	var impacto := preload("res://Objects/bullet_impact.tscn").instantiate()
	var estojo := preload("res://Objects/gun_casing.tscn").instantiate()
	var efeitos := preload("res://Scenes/Audio/efeitos_finais.tscn").instantiate()
	mundo.add_child(disparo)
	mundo.add_child(impacto)
	mundo.add_child(estojo)
	estojo.lancar(Vector2.RIGHT)
	mundo.add_child(efeitos)
	efeitos.explodir(Vector2(81, 49))
	var explosao := efeitos.get_node("Explosoes/Explosao1")
	_verificar(explosao.global_position == Vector2(81, 49), "A explosão deve surgir no componente escolhido.")
	_verificar(explosao.get_node("Som").playing, "O efeito deve reproduzir o som original da explosão.")
	_verificar(explosao.get_node("Brilho").visible, "A explosão deve mostrar o brilho original.")
	await get_tree().create_timer(0.05).timeout
	_verificar(estojo.position != Vector2.ZERO and estojo.z_index == 2, "O estojo amarelo deve cair e permanecer no nível do chão.")
	_verificar(disparo.scale.x > 1.0 and disparo.modulate.a < 1.0, "O clarão deve crescer e desaparecer suavemente.")
	get_tree().paused = true
	await get_tree().process_frame
	var escala: Vector2 = disparo.scale
	var posicao_animacao: float = explosao.get_node("Animacao").current_animation_position
	await get_tree().create_timer(0.2).timeout
	_verificar(is_instance_valid(disparo) and disparo.scale == escala, "A pausa deve congelar o clarão.")
	_verificar(explosao.get_node("Animacao").current_animation_position == posicao_animacao, "A pausa deve congelar a explosão.")
	get_tree().paused = false
	await get_tree().create_timer(0.45).timeout
	_verificar(not is_instance_valid(disparo), "O clarão deve terminar ao retomar o jogo.")
	_verificar(not explosao.get_node("Brilho").visible, "O brilho deve desaparecer sem apagar o nó reutilizável.")
	_verificar(is_instance_valid(impacto) and impacto.get_node("Mark").modulate.a == 1.0, "A marca deve permanecer antes de começar o fade.")
	await get_tree().create_timer(1.1).timeout
	_verificar(impacto.get_node("Mark").modulate.a > 0.0 and impacto.get_node("Mark").modulate.a < 1.0, "A marca deve desaparecer progressivamente.")
	await get_tree().create_timer(0.85).timeout
	_verificar(not is_instance_valid(impacto), "O impacto deve encerrar ao concluir a animação.")
	for indice in range(70):
		efeitos.explodir(Vector2(indice, 30), true, 0.05)
	_verificar(efeitos.get_node("Explosoes").get_child_count() == 32, "As explosões devem manter uma quantidade fixa de nós.")
	MusicController.som_alarme.play()
	MusicController.reduzir_audio_para_menu(0.06)
	await get_tree().create_timer(0.12).timeout
	_verificar(not MusicController.som_alarme.playing, "O fade de retorno ao menu deve terminar e parar o áudio.")
	MusicController.reduzir_audio_para_menu(0.01)
	await get_tree().create_timer(0.05).timeout
	_verificar(not MusicController.audio_cena_bloqueado, "O fade também deve terminar quando já não há sons tocando.")
	get_tree().quit(0 if falhas.is_empty() else 1)


func _verificar(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
