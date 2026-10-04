extends Node2D

var falhas: Array[String] = []
var drone_consultado: SecurityDrone
var jogador_visivel: bool = false

func _physics_process(_delta: float) -> void:
	if is_instance_valid(drone_consultado):
		jogador_visivel = drone_consultado._pode_ver_jogador(125, false)

func _ready() -> void:
	Engine.max_fps = 60
	get_tree().set_meta(&"dev_mission_jump_active", true)
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	_verificar.call_deferred()

func _verificar() -> void:
	var original: Dictionary = SaveGame.save_data.duplicate(true)
	for arquivo in ["andar_hall", "andar_escritorio", "andar_data_center"]:
		var mapa: Node2D = load("res://Scenes/" + arquivo + ".tscn").instantiate()
		for npc in mapa.get_node("NPCs").get_children():
			if not npc is PersonagemNPC:
				continue
			_verificar_condicao(npc.animacoes != null, "NPC sem recurso de animações: " + arquivo)
			_verificar_condicao(npc.get_node("CrowdAvoidance").velocity_computed.is_connected(npc._ao_calcular_velocidade_segura), "Desvio sem sinal na cena.")
			for caminho in npc.get_children():
				if caminho is NPCPath:
					_verificar_condicao(caminho.solicitou_inicio.is_connected(npc._ao_solicitar_inicio_caminho), "Caminho sem conexão salva.")
		if arquivo == "andar_hall":
			for npc in mapa.get_node("NPCs").get_children():
				_verificar_condicao(npc.npc_saiu.is_connected(mapa.get_node("QuestController")._on_npc_saiu), "Evacuação sem conexão salva.")
		else:
			var npc := mapa.get_node("NPCs/NPC1")
			var nome := "OfficeIntroController" if arquivo == "andar_escritorio" else "DataCenterIntroController"
			var metodo := "_on_npc_path_completed" if arquivo == "andar_escritorio" else "_on_recipient_path_completed"
			_verificar_condicao(npc.caminho_concluido.is_connected(Callable(mapa.get_node(nome), metodo)), "Cientista sem conexão salva.")
		mapa.free()
	var npc := preload("res://NPC'S/Clarxs.tscn").instantiate()
	npc.save_enabled = false
	npc.animacoes = preload("res://NPC'S/Animacoes/06_purple_crimson.tres")
	add_child(npc)
	npc.set_process(false)
	npc.set_physics_process(false)
	npc.global_position = Vector2(120, 75)
	var salvo: Dictionary = npc.get_checkpoint_state()
	_verificar_condicao(salvo.has("current_path") and salvo.has("path_finished"), "Chaves do checkpoint alteradas.")
	npc.global_position = Vector2.ZERO
	npc.load_checkpoint_state(salvo)
	_verificar_condicao(npc.global_position == Vector2(120, 75), "Checkpoint do NPC não restaurou a posição.")
	var quadros: SpriteFrames = npc.animacoes
	_verificar_condicao(quadros.get_frame_count(&"walk_side") == 6 and quadros.get_animation_speed(&"run_side") == 14, "Animações modificaram os quadros ou a velocidade.")
	npc.queue_free()
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	add_child(jogador)
	jogador.global_position = Vector2(40, 0)
	var estado: Dictionary = SaveGame.office_mission_state(jogador)
	estado["programmer_ending_started"] = true
	estado["programmer_ending_completed"] = false
	estado["security_drone_destroyed"] = false
	SaveGame.save_global_state("hall_quest_01", estado)
	var drone := preload("res://Objects/security_drone.tscn").instantiate() as SecurityDrone
	add_child(drone)
	drone.position = Vector2.ZERO
	drone.set_physics_process(false)
	drone.get_node("VerificarMissao").stop()
	drone._atualizar_estado_missao()
	drone_consultado = drone
	await get_tree().physics_frame
	_verificar_condicao(drone.is_in_group(&"security_drones"), "Grupo do drone não está na cena.")
	await get_tree().process_frame
	_verificar_condicao(jogador_visivel, "RayCast não detecta o jogador na área livre.")
	var bloqueio := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	var retangulo := RectangleShape2D.new()
	retangulo.size = Vector2(8, 30)
	forma.shape = retangulo
	bloqueio.add_child(forma)
	bloqueio.position = Vector2(20, 0)
	add_child(bloqueio)
	await get_tree().physics_frame
	await get_tree().process_frame
	_verificar_condicao(not jogador_visivel, "Drone enxerga através de uma parede.")
	var bala := preload("res://Objects/bullet.tscn").instantiate()
	add_child(bala)
	bala.global_position = Vector2(-16, 0)
	bala.configurar(Vector2.RIGHT, jogador)
	var vida_anterior := drone.vida_atual
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	_verificar_condicao(drone.vida_atual < vida_anterior, "Projétil não aplica dano ao drone.")
	var tiro := preload("res://Objects/drone_projectile.tscn").instantiate()
	tiro.position = Vector2(200, 200)
	add_child(tiro)
	tiro.set_physics_process(false)
	tiro.get_node("TempoDeVida").start(0.05)
	await get_tree().create_timer(0.1).timeout
	_verificar_condicao(not is_instance_valid(tiro), "Timer não remove o projétil.")
	SaveGame.save_data = original
	for falha in falhas:
		push_error(falha)
	get_tree().quit(0 if falhas.is_empty() else 1)

func _verificar_condicao(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
