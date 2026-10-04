extends Node

var failures: Array[String] = []
var original_save: Dictionary


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	original_save = SaveGame.save_data.duplicate(true)
	SaveGame.save_data = {}
	ContextualTutorial.cancel_current()
	ContextualTutorial.set_process(false)
	_run.call_deferred()


func _run() -> void:
	var world := preload("res://Scenes/andar_hall.tscn").instantiate()
	world.get_node("ManPlayer").checkpoint_enabled = false
	world.get_node("ManPlayer").starting_gun_enabled = false
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await _frames(3)
	var quest := world.get_node("QuestController")
	quest.set_physics_process(false)
	quest.set_process(false)
	var checker := world.get_node("ElevatorRoute")
	var navigation := world.get_node("HallNPCNavigation")
	_expect(world.get_node("HALL_QUEBRADO/Sprite31/NPCObstacle").collision_layer == 32, "Os objetos decorativos devem ter uma camada exclusiva de colisão com NPCs.")
	for name in ["Fogo3", "Fogo5", "Fogo6"]:
		_expect(not world.get_node("Perigos/" + name).has_node("ObjectiveHighlight"), "Os fogos obrigatórios não devem mais receber círculos de destaque.")
	_expect(not world.get_node("Perigos/Fogo2").has_node("ObjectiveHighlight"), "Fogos que não fazem parte da missão não devem ser destacados.")
	var balloon: Node = world.player.balao_de_pensamento
	balloon.load_checkpoint_state({})
	var reminder: String = quest._pensamento_id("fogo_fora_da_saida")
	for fire_name in ["Fogo", "Fogo2", "Fogo4"]:
		var fire := world.get_node("Perigos/" + fire_name)
		fire.iniciar_extincao()
		_expect(balloon.pensamento_atual_id() == reminder, "Tentar apagar um fogo fora da saída deve mostrar o pensamento.")
		_expect(balloon.label.text == "Só preciso apagar os fogos no caminho do elevador.", "O aviso deve usar o balão de pensamento do jogador.")
		fire.iniciar_extincao()
		_expect(balloon._fila.is_empty(), "Manter o jato no fogo não deve acumular mensagens.")
		fire.parar_extincao()
		balloon.pular_pensamento()
		fire.iniciar_extincao()
		_expect(balloon.pensamento_atual_id() == reminder, "Uma nova tentativa deve repetir o pensamento, mesmo após sua conclusão.")
		fire.parar_extincao()
		balloon.pular_pensamento()
	for fire_name in ["Fogo3", "Fogo5", "Fogo6"]:
		var fire := world.get_node("Perigos/" + fire_name)
		fire.iniciar_extincao()
		_expect(not balloon.esta_ocupado(), "Apagar os fogos obrigatórios não deve exibir o aviso.")
		fire.parar_extincao()
	var spent_fire := world.get_node("Perigos/Fogo2")
	spent_fire.apagado = true
	spent_fire.iniciar_extincao()
	_expect(not balloon.esta_ocupado(), "Um fogo já apagado não deve disparar o pensamento.")
	spent_fire.apagado = false
	for npc in world.get_node("NPCs").get_children():
		npc.set_process(false)
		npc.set_physics_process(false)
		npc.get_node("CrowdAvoidance").avoidance_enabled = false
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(6, 6, 20, 20), Color.WHITE)
	var fixture := Sprite2D.new()
	fixture.texture = ImageTexture.create_from_image(image)
	fixture.position = Vector2(500.0, 300.0)
	world.add_child(fixture)
	navigation._add_sprite_collision(fixture)
	var npc := world.get_node("NPCs/NPC1")
	npc.stop_current_path()
	npc.global_position = Vector2(470.0, 300.0)
	world.player.set_physics_process(false)
	world.player.global_position = Vector2(470.0, 305.0)
	await _frames(3)
	_expect(not world.player.test_move(world.player.global_transform, Vector2(40.0, 0.0)), "As novas colisões decorativas não devem bloquear o jogador.")
	for index in range(20):
		npc._on_crowd_velocity_computed(Vector2(120.0, 0.0))
		await _frames(1)
	_expect(npc.global_position.x < 485.5, "Mesmo com velocidade direta, o NPC não deve atravessar a sprite.")
	fixture.queue_free()
	npc.global_position = Vector2(-40.0, 30.0)
	world.player.global_position = Vector2(80.0, 90.0)
	await _frames(3)
	_expect(checker.get_clear_route().is_empty(), "Os entulhos iniciais devem bloquear a passagem.")
	world.get_node("Coletaveis/pedaco3").position.x = 32.0
	await _frames(3)
	_expect(checker.get_clear_route().is_empty(), "Mover apenas a última pedra até a antiga área não deve liberar uma passagem ainda obstruída.")
	quest.f1_acesso = false
	quest.f2_acesso = false
	quest.f3_acesso = false
	quest._update_fire_task()
	_expect(world.get_node("Coletaveis/pedaco3/Sprite2D").has_node("ObjectiveHighlight"), "Depois do fogo, as pedras da passagem devem receber destaque.")
	for object in world.get_node("Coletaveis").get_children():
		if object is ObjetoEmpurravel:
			object.position += Vector2(400.0, 400.0)
	await _frames(3)
	var route: PackedVector2Array = checker.get_clear_route()
	_expect(not route.is_empty(), "Retirar os entulhos da passagem deve liberar o elevador, sem exigir uma posição específica para as pedras.")
	world.player.global_position = Vector2(-26.0, -60.0)
	await _frames(3)
	checker.initialized = false
	_expect(not checker.get_clear_route().is_empty(), "O próprio jogador não deve invalidar a passagem.")
	quest.M1_feito = false
	quest._physics_process(0.3)
	_expect(quest.M2_feito, "O painel deve marcar a tarefa quando a passagem estiver livre.")
	var blocker := ObjetoEmpurravel.new()
	blocker.save_enabled = false
	blocker.position = Vector2(-26.0, -62.0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(84.0, 6.0)
	collision.shape = shape
	blocker.add_child(collision)
	world.get_node("Coletaveis").add_child(blocker)
	await _frames(3)
	_expect(checker.get_clear_route().is_empty(), "Uma barreira completa deve impedir a conclusão.")
	quest._physics_process(0.3)
	_expect(not quest.M2_feito, "Obstruir novamente antes da evacuação deve desmarcar a tarefa.")
	shape.size = Vector2(84.0, 6.0)
	blocker.position.x = 49.0
	await _frames(3)
	_expect(not checker.get_clear_route().is_empty(), "Uma pedra fora do trajeto não deve impedir a passagem.")
	shape.size = Vector2(8.0, 6.0)
	blocker.position.x = -26.0
	await _frames(3)
	route = checker.get_clear_route()
	_expect(not route.is_empty(), "Um obstáculo pequeno deve permitir um desvio quando houver espaço suficiente.")
	if not route.is_empty():
		_expect(route.size() > 2, "O caminho verificado deve contornar o obstáculo, em vez de atravessá-lo.")
	shape.size = Vector2(70.0, 6.0)
	blocker.position.x = -65.0
	var second := ObjetoEmpurravel.new()
	second.save_enabled = false
	second.position = Vector2(23.0, -62.0)
	var second_collision := CollisionShape2D.new()
	var second_shape := RectangleShape2D.new()
	second_shape.size = Vector2(90.0, 6.0)
	second_collision.shape = second_shape
	second.add_child(second_collision)
	world.get_node("Coletaveis").add_child(second)
	await _frames(3)
	_expect(checker.get_clear_route().is_empty(), "Uma fresta de oito pixels, menor que o NPC, não deve contar como passagem livre.")
	second.queue_free()
	blocker.queue_free()
	await _frames(3)
	route = checker.get_clear_route()
	for actor in world.get_node("NPCs").get_children():
		var path := actor.get_node("Line2D2") as NPCPath
		checker.prepare_exit_path(actor, path, route)
		var points: Array[Vector2] = actor.cached_path_points[path]
		_expect(not route.is_empty() and points[-1] == route[-1], "Cada NPC deve usar o trajeto de saída verificado.")
	quest.f1_acesso = false
	quest.f2_acesso = false
	quest.f3_acesso = false
	quest._update_fire_task()
	quest._physics_process(0.3)
	_expect(quest._hide_scheduled, "Com o fogo apagado e o trajeto livre, a evacuação deve começar.")
	for actor in world.get_node("NPCs").get_children():
		actor.set_physics_process(true)
		actor.get_node("CrowdAvoidance").avoidance_enabled = true
	world.player.global_position = Vector2(500.0, 500.0)
	for index in range(1500):
		if world.get_node("NPCs").get_child_count() == 0:
			break
		await _frames(1)
	var remaining: Array = []
	for actor in world.get_node("NPCs").get_children():
		remaining.append({"name": actor.name, "position": actor.global_position, "point": actor.current_point, "target": actor.movement_target, "navigation": actor.navigation_points, "goal": actor.navigation_target, "start_cell": navigation._free_cell(actor.global_position), "goal_cell": navigation._free_cell(actor.navigation_target)})
	_expect(remaining.is_empty(), "Todos os NPCs devem conseguir chegar ao elevador contornando os obstáculos.")
	SaveGame.save_data = original_save
	var report := FileAccess.open("res://.hall-elevator-route-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "remaining": remaining}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
