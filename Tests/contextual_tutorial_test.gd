extends BaseScene

var failures: Array[String] = []
var guide: CanvasLayer
var original_configs: Dictionary
var original_save: Dictionary


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	original_configs = Configs.configs.duplicate(true)
	original_save = SaveGame.save_data.duplicate(true)
	Configs.configs["contextual_tutorial_seen"] = {}
	SaveGame.save_data = {}
	guide = ContextualTutorial
	guide.set_process(false)
	call_deferred("_run")


func _run() -> void:
	var room := preload("res://Tutorial/Rooms/training_room.tscn").instantiate()
	add_child(room)
	player = preload("res://Player/ManPlayer.tscn").instantiate()
	player.checkpoint_enabled = false
	player.starting_gun_enabled = false
	var quests: Node = player.get_node("QUEST_MISSION")
	quests.modo_isolado = true
	quests.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	player.camera_2d.limit_left = -200
	player.camera_2d.limit_right = 200
	player.camera_2d.limit_top = -112
	player.camera_2d.limit_bottom = 112
	player.camera_2d.zoom = Vector2.ONE * 1.2
	player.camera_2d.position_smoothing_enabled = false
	player.camera_2d.make_current()
	await get_tree().process_frame
	await get_tree().process_frame
	guide.jogador = player
	var heart := player.get_node("CanvasLayer/Control/Vida1") as CanvasItem
	var stamina := player.get_node("CanvasLayer/Control/estamina") as CanvasItem
	heart.modulate.a = 0.8
	var music_bus := AudioServer.get_bus_index(&"Music")
	var original_music_db := AudioServer.get_bus_volume_db(music_bus)
	MusicController.som_alarme.play()
	_expect(guide._jogo_disponivel(), "O ensino deve funcionar durante a campanha.")
	guide._descobrir_tutoriais()
	guide._iniciar_proximo()
	_expect(guide.tutorial_ativo == "walk", "A campanha deve ensinar movimento primeiro.")
	_expect(not "[b]" in guide.explicacao.text, "As teclas de movimento devem começar sem negrito.")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	await _wait_for_attention()
	_expect(is_equal_approx(guide.balao.modulate.a, 1.0) and guide.balao.scale.is_equal_approx(Vector2.ONE), "A entrada deve terminar com o balão visível e sem distorção.")
	_expect(is_equal_approx(MusicController.fator_musica_tutorial, 0.35), "A música deve diminuir suavemente durante o tutorial.")
	for path: NodePath in MusicController.MUSICAS_ELEVADOR:
		_expect(is_equal_approx(MusicController.get_node(path).pitch_scale, 1.0), "O tutorial deve manter o tom e a velocidade normais das músicas.")
	_expect(is_equal_approx(MusicController.som_alarme.pitch_scale, 1.0), "O tutorial deve manter o tom normal do alarme.")
	_expect(is_equal_approx(MusicController.som_alarme.volume_db, MusicController.volume_alarme_sem_atenuacao_db + linear_to_db(0.35)), "O alarme deve ficar mais baixo sem perder seu fade próprio.")
	MusicController.alarme_silenciado_jogador = true
	MusicController._atualizar_saida_alarme()
	_expect(is_equal_approx(MusicController.som_alarme.volume_db, MusicController.VOLUME_SILENCIO_DB), "O tutorial deve manter o alarme silenciado quando o jogador o desligar.")
	MusicController.alarme_silenciado_jogador = false
	MusicController._atualizar_saida_alarme()
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), original_music_db + linear_to_db(0.35)), "O volume do tutorial deve respeitar o volume original da música.")
	guide._atualizar_tutorial(1.0)
	_expect(not guide.finalizando, "Sem tentar a ação, a explicação deve continuar até dez segundos.")
	var movement_attempt := InputEventAction.new()
	movement_attempt.action = &"up"
	movement_attempt.pressed = true
	guide._input(movement_attempt)
	guide._atualizar_tutorial(0.05)
	_expect(not guide.praticou and not guide.finalizando and player.global_position == guide.posicao_inicial, "Uma única direção não deve concluir o tutorial, mesmo se apertada sem deslocamento.")
	_expect("[b]%s[/b]" % guide._tecla("up") in guide.explicacao.text, "A tecla pressionada deve ficar em negrito.")
	guide._input(movement_attempt)
	_expect(guide.direcoes_praticadas.size() == 1, "Apertar a mesma tecla novamente não deve avançar outras direções.")
	for action: StringName in [&"left", &"down", &"right"]:
		movement_attempt.action = action
		guide._input(movement_attempt)
		_expect("[b]%s[/b]" % guide._tecla(action) in guide.explicacao.text, "Cada direção deve ganhar seu próprio negrito.")
	_expect(guide.praticou and guide.direcoes_praticadas.size() == 4, "As quatro direções devem concluir a prática de movimento.")
	_expect(is_equal_approx(heart.modulate.a, 0.12) and is_equal_approx(stamina.modulate.a, 0.15), "Movimento deve reduzir a opacidade da vida e da estamina.")
	_expect(is_equal_approx(player.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_1.modulate.a, 0.15), "O jogador deve continuar visível enquanto o inventário perde destaque.")
	_expect(guide.estilo_brilho.border_width_top == 2 and guide.estilo_brilho.shadow_size >= 7, "O balão deve ter borda completa e brilho.")
	quests._definir_opacidade_painel(0.4)
	_expect(is_equal_approx(quests._obter_opacidade_painel(), 0.4) and is_equal_approx(quests.get_node("ColorRect").modulate.a, 0.06), "O foco não deve substituir o fade próprio das tarefas.")
	_expect(is_equal_approx(Engine.time_scale, 0.25), "A explicação deve reduzir a velocidade sem pausar.")
	var health := player.get_vida()
	player.tomar_dano(30)
	_expect(is_equal_approx(player.get_vida(), health), "O jogador deve estar protegido enquanto aprende.")
	player.global_position.x += 5
	guide._atualizar_tutorial(3.0)
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	await _wait_for_attention()
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), original_music_db), "Concluir deve devolver a música ao volume original.")
	_expect(is_equal_approx(MusicController.musica_cenario.pitch_scale, 1.0), "Concluir deve restaurar o tom normal da música.")
	_expect(is_equal_approx(MusicController.som_alarme.pitch_scale, 1.0) and is_equal_approx(MusicController.som_alarme.volume_db, MusicController.volume_alarme_sem_atenuacao_db), "Concluir deve restaurar o alarme ao estado atual normal.")
	_expect(is_equal_approx(heart.modulate.a, 0.8) and is_equal_approx(player.inventory.slot_1.modulate.a, 1.0), "Concluir deve restaurar as opacidades originais.")
	_expect(is_equal_approx(quests.get_node("ColorRect").modulate.a, 0.4), "Restaurar o foco deve preservar o estado atual das tarefas.")
	_expect(guide._ja_visto("walk") and guide.tutorial_ativo.is_empty(), "Praticar deve concluir e registrar a explicação.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "A velocidade deve voltar ao normal.")
	guide._enfileirar("walk")
	_expect(not "walk" in guide.pendentes, "Uma explicação concluída não deve se repetir.")
	guide._iniciar_tutorial("run")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	await get_tree().create_timer(0.2, true, false, true).timeout
	_expect(is_equal_approx(MusicController.musica_cenario.pitch_scale, 1.0), "O fade de volume não deve modificar o tom da música.")
	await _wait_for_attention()
	var stamina_rect: Rect2 = (stamina as Control).get_global_rect()
	_expect(not guide.balao.get_global_rect().intersects(stamina_rect), "O tutorial de corrida deve ficar à direita sem cobrir a estamina.")
	_expect(guide.balao.position.x > (get_viewport().get_visible_rect().size.x - guide.balao.size.x) * 0.5, "Corrida deve deslocar o balão para a direita.")
	_expect(is_equal_approx(stamina.modulate.a, 1.0) and is_equal_approx(heart.modulate.a, 0.12), "Corrida deve destacar apenas a estamina no HUD.")
	get_tree().paused = true
	_expect(not guide._jogo_disponivel(), "Não deve haver ensino no menu de pausa.")
	guide._suspender()
	await _wait_for_attention()
	_expect(is_equal_approx(MusicController.fator_musica_tutorial, 1.0), "Pausar deve restaurar a música sem depender da câmera lenta.")
	_expect(is_equal_approx(MusicController.som_alarme.pitch_scale, 1.0), "O alarme deve manter seu tom normal ao pausar.")
	_expect(is_equal_approx(heart.modulate.a, 0.8) and is_equal_approx(stamina.modulate.a, 1.0), "Pausar deve restaurar a interface mesmo com a árvore pausada.")
	_expect(is_equal_approx(Engine.time_scale, 1.0) and not guide.balao.visible, "Pausar deve esconder a explicação e restaurar a velocidade.")
	get_tree().paused = false
	guide.tempo_disponivel = 1.0
	guide._atualizar_tutorial(0.1)
	_expect(guide.controla_camera_lenta and guide.balao.visible, "A explicação deve continuar após sair da pausa.")
	player.set_physics_process(false)
	_expect(not guide._jogo_disponivel(), "Cutscenes, elevador e minigames devem suspender o ensino.")
	guide._suspender()
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Abrir um minigame deve remover a câmera lenta.")
	player.set_physics_process(true)
	DialogManager.is_showing_dialog = true
	_expect(not guide._jogo_disponivel(), "Explicações não devem cobrir diálogos com NPCs.")
	DialogManager.is_showing_dialog = false
	var blur := Node.new()
	add_child(blur)
	blur.add_to_group(&"opening_gameplay_blur")
	_expect(not guide._jogo_disponivel(), "A explicação deve aguardar o blur inicial.")
	blur.remove_from_group(&"opening_gameplay_blur")
	blur.queue_free()
	guide.cancelar_atual()
	guide.pendentes.clear()
	var nearby_prop := ObjetoEmpurravel.new()
	nearby_prop.save_enabled = false
	add_child(nearby_prop)
	player.objetos_grab_left.append(nearby_prop)
	SaveGame.save_data["res://Scenes/andar_hall.tscn"] = {"hall_quest_01": {"task_fire_done": false, "fire_1_done": true, "fire_2_done": false, "fire_3_done": false}}
	guide._enfileirar("push", true)
	_expect(not "push" in guide.pendentes and not guide._ainda_relevante("push"), "Estar perto de um objeto não deve ensinar a empurrar antes de apagar os incêndios.")
	SaveGame.save_data["res://Scenes/andar_hall.tscn"]["hall_quest_01"]["task_fire_done"] = true
	guide._enfileirar("push", true)
	_expect("push" in guide.pendentes and guide._ainda_relevante("push"), "Concluir a tarefa de apagar o fogo deve liberar o tutorial de empurrar.")
	SaveGame.save_data["res://Scenes/andar_hall.tscn"]["hall_quest_01"]["task_fire_done"] = false
	guide._iniciar_proximo()
	_expect(guide.tutorial_ativo.is_empty(), "Um tutorial de empurrar na fila deve ser descartado se os incêndios ainda estiverem ativos.")
	SaveGame.save_data["res://Scenes/andar_hall.tscn"]["hall_quest_01"]["task_fire_done"] = true
	player.objetos_grab_left.erase(nearby_prop)
	nearby_prop.queue_free()
	guide._iniciar_tutorial("walk")
	guide._atualizar_tutorial(9.9)
	_expect(not guide.finalizando and guide.direcoes_praticadas.is_empty(), "Sem usar as direções, o tutorial de movimento deve esperar dez segundos.")
	guide._atualizar_tutorial(0.1)
	_expect(guide.finalizando, "O tutorial de movimento deve terminar por tempo mesmo sem as quatro teclas.")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	guide._iniciar_tutorial("collect")
	await _wait_for_attention()
	_expect(is_equal_approx(player.inventory.slot_1.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_6.modulate.a, 1.0), "Coleta deve destacar todo o inventário.")
	guide.cancelar_atual()
	guide._iniciar_tutorial("tasks")
	await _wait_for_attention()
	_expect(is_equal_approx(guide.balao.position.x, 14.0), "Tarefas devem posicionar o balão à esquerda do painel.")
	_expect(is_equal_approx(quests.get_node("ColorRect").modulate.a, 0.4) and is_equal_approx(player.inventory.slot_1.modulate.a, 0.15), "Tarefas devem manter o painel evidente sem modificar seu próprio fade.")
	guide.cancelar_atual()
	await _wait_for_attention()
	_expect(is_equal_approx(quests.get_node("ColorRect").modulate.a, 0.4), "Encerrar o tutorial de tarefas não deve escurecer o painel.")
	for tier in [1, 2, 3]:
		var scene_path: String = ["res://Objects/cartao_padrao.tscn", "res://Objects/cartao_forte.tscn", "res://Objects/cartao_chefe.tscn"][tier - 1]
		player.inventory.add_item("cartao", load(scene_path))
		guide._descobrir_tutoriais()
		_expect("card_%d" % tier in guide.pendentes, "Cada nível de cartão deve ter sua própria explicação.")
		guide._iniciar_tutorial("card_%d" % tier)
		await _wait_for_attention()
		_expect(is_equal_approx(player.inventory.slot_5.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_1.modulate.a, 0.15), "Cartões devem destacar somente o slot correspondente.")
		_equip("use_cartao")
		_expect(guide._acao_praticada(), "Equipar o cartão deve ser reconhecido.")
		guide._concluir_tutorial()
		player.reset_sprite_player()
	guide.pendentes.clear()
	player.inventory.add_item("lanterna", preload("res://Objects/Lanterna.tscn"))
	guide._iniciar_tutorial("flashlight")
	await _wait_for_attention()
	_expect(is_equal_approx(player.inventory.slot_2.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_5.modulate.a, 0.15), "A lanterna deve receber destaque no próprio slot.")
	_equip("use_lanterna")
	_expect(guide._acao_praticada(), "A luz real da lanterna deve concluir a prática.")
	guide._concluir_tutorial()
	player.inventory.add_item("extintor", preload("res://Objects/extintor.tscn"))
	guide.pendentes.clear()
	guide._descobrir_tutoriais()
	_expect(not "extinguisher" in guide.pendentes, "Coletar o extintor não deve iniciar sua explicação.")
	_equip("use_extintor")
	guide._descobrir_tutoriais()
	_expect("extinguisher" in guide.pendentes and guide._ainda_relevante("extinguisher"), "Equipar o extintor deve liberar sua explicação.")
	guide._iniciar_tutorial("extinguisher")
	await _wait_for_attention()
	_expect(is_equal_approx(player.inventory.slot_6.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_2.modulate.a, 0.15), "O extintor deve receber destaque no próprio slot.")
	var extinguisher := player.inventory.get_item_control("extintor")
	extinguisher.definir_fumaca(true)
	_expect(guide._acao_praticada(), "Usar o extintor real deve ser reconhecido.")
	extinguisher.definir_fumaca(false)
	guide._concluir_tutorial()
	guide.pendentes.clear()
	_equip("use_extintor")
	_equip("use_extintor")
	guide._descobrir_tutoriais()
	_expect(not "extinguisher" in guide.pendentes, "Equipar novamente o extintor não deve repetir a explicação.")
	player.inventory.add_item("gun", preload("res://Objects/arma.tscn"))
	_equip("use_arma")
	guide._iniciar_tutorial("weapon")
	var arma := player.inventory.get_item_control("gun")
	arma.municao_atual -= 1
	_expect(guide._acao_praticada(), "Um disparo deve concluir a orientação da arma.")
	guide._concluir_tutorial()
	guide.pendentes.clear()
	guide._descobrir_tutoriais()
	_expect(not "reload" in guide.pendentes, "A recarga não deve ser ensinada após apenas um disparo.")
	arma.municao_atual = 0
	guide._descobrir_tutoriais()
	_expect("reload" in guide.pendentes and guide._ainda_relevante("reload"), "Esvaziar o pente deve liberar a orientação de recarga.")
	guide._iniciar_tutorial("reload")
	arma._iniciar_recarga()
	await get_tree().create_timer(1.3).timeout
	_expect(guide._acao_praticada(), "Uma recarga real deve concluir sua explicação.")
	guide._concluir_tutorial()
	guide.pendentes.clear()
	arma.municao_atual = 0
	guide._descobrir_tutoriais()
	_expect(not "reload" in guide.pendentes, "A orientação de recarga não deve se repetir ao esvaziar outro pente.")
	guide._iniciar_tutorial("weapon_flashlight")
	await _wait_for_attention()
	_expect(is_equal_approx(player.inventory.slot_1.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_2.modulate.a, 1.0), "A combinação deve destacar tanto arma quanto lanterna.")
	_equip("use_lanterna")
	_expect(guide._acao_praticada(), "A combinação de arma e lanterna deve funcionar.")
	guide._concluir_tutorial()
	var original_events := InputMap.action_get_events("empurrar")
	InputMap.action_erase_events("empurrar")
	var remapped := InputEventKey.new()
	remapped.physical_keycode = KEY_G
	InputMap.action_add_event("empurrar", remapped)
	_expect("G" in guide._conteudo("push")[1], "As explicações devem usar as teclas remapeadas.")
	InputMap.action_erase_events("empurrar")
	for evento in original_events:
		InputMap.action_add_event("empurrar", evento)
	guide._iniciar_tutorial("push")
	guide._atualizar_tutorial(9.0)
	_expect(not guide.finalizando, "O tutorial não deve desaparecer antes do limite sem uma tentativa.")
	guide._atualizar_tutorial(1.0)
	_expect(guide.finalizando, "Dez segundos sem ação devem iniciar a saída suave.")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	_expect(guide.tutorial_ativo.is_empty(), "A explicação deve terminar mesmo sem prática, sem prender o jogador.")
	guide._iniciar_tutorial("weapon")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	await _wait_for_attention()
	_expect(is_equal_approx(player.ammo_panel.modulate.a, 1.0) and is_equal_approx(player.inventory.slot_1.modulate.a, 1.0), "Arma deve destacar o slot e o contador de munição.")
	Engine.time_scale = 0.12
	guide.cancelar_atual()
	_expect(is_equal_approx(Engine.time_scale, 0.12), "O tutorial não deve sobrescrever a câmera lenta de outro efeito.")
	Engine.time_scale = 1.0
	guide._iniciar_tutorial("weapon")
	guide._atualizar_tutorial(guide.DURACAO_TRANSICAO)
	await _wait_for_attention()
	AudioServer.set_bus_volume_db(music_bus, linear_to_db(0.2))
	MusicController.definir_fator_musica_tutorial(MusicController.fator_musica_tutorial)
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.2 * 0.35)), "Uma alteração de volume durante o tutorial deve continuar sendo respeitada.")
	if "--capture" in OS.get_cmdline_user_args():
		await _wait_for_attention()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.contextual-preview.png")
	guide._ao_mudar_cena()
	_expect(is_equal_approx(MusicController.som_alarme.pitch_scale, 1.0), "Trocar de cena não deve deixar o alarme grave.")
	for path: NodePath in MusicController.MUSICAS_ELEVADOR:
		_expect(is_equal_approx(MusicController.get_node(path).pitch_scale, 1.0), "Trocar de cena deve restaurar o tom de todas as músicas.")
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.2)), "Trocar de cena deve restaurar o volume mais recente das configurações.")
	AudioServer.set_bus_volume_db(music_bus, original_music_db)
	_expect(is_equal_approx(heart.modulate.a, 0.8) and guide.alvos_destaque.is_empty(), "Trocar de cena deve restaurar o HUD e liberar todas as referências.")
	_expect(is_equal_approx(Engine.time_scale, 1.0) and guide.tutorial_ativo.is_empty(), "Trocar de cena deve limpar a câmera lenta e a explicação.")
	_expect(guide._ja_visto("card_3"), "O aprendizado deve continuar registrado após uma troca de cena.")
	var separate_tutorial_seen: Variant = Configs.configs.get("tutorial_seen", false)
	guide.iniciar_novo_jogo()
	_expect(not guide._ja_visto("walk") and not guide._ja_visto("card_3"), "Novo jogo deve permitir repetir todas as explicações da campanha.")
	_expect(Configs.configs.get("tutorial_seen", false) == separate_tutorial_seen, "Novo jogo não deve alterar o histórico do tutorial separado.")
	Configs.configs["contextual_tutorial_seen"] = {}
	player.reset_sprite_player()
	guide.set_process(true)
	await get_tree().create_timer(1.0, true, false, true).timeout
	_expect(not guide.tutorial_ativo.is_empty(), "O ensino deve iniciar sozinho na campanha.")
	guide.set_process(false)
	guide.cancelar_atual()
	Configs.configs = original_configs
	SaveGame.save_data = original_save
	var report := FileAccess.open("res://.contextual-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _equip(action: StringName) -> void:
	var evento := InputEventAction.new()
	evento.action = action
	evento.pressed = true
	player._input(evento)


func _wait_for_attention() -> void:
	await get_tree().create_timer(0.1, true, false, true).timeout
	_check_panel_size()
	await get_tree().create_timer(0.65, true, false, true).timeout
	_check_panel_size()


func _check_panel_size() -> void:
	if not guide.balao.visible:
		return
	_expect(guide.balao.size.x <= 300.0 and guide.balao.size.y <= 110.0, "O balão deve permanecer compacto durante e após a animação: %s (%s)." % [guide.balao.size, guide.tutorial_ativo])
	var conteudo := guide.balao.get_node("Content") as VBoxContainer
	_expect(conteudo.size.y <= guide.balao.size.y, "O texto deve caber dentro do balão: %s (%s)." % [conteudo.size, guide.tutorial_ativo])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
