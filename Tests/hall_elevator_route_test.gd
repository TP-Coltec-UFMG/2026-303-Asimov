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
	for npc in world.get_node("NPCs").get_children():
		npc.set_process(false)
		npc.set_physics_process(false)
		npc.get_node("CrowdAvoidance").avoidance_enabled = false
	_expect(checker.get_clear_route().is_empty(), "Os entulhos iniciais devem bloquear a passagem.")
	world.get_node("Coletaveis/pedaco3").position.x = 32.0
	await _frames(3)
	_expect(checker.get_clear_route().is_empty(), "Mover apenas a última pedra até a antiga área não deve liberar uma passagem ainda obstruída.")
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
	for npc in world.get_node("NPCs").get_children():
		var path := npc.get_node("Line2D2") as NPCPath
		checker.prepare_exit_path(npc, path, route)
		var points: Array[Vector2] = npc.cached_path_points[path]
		_expect(not route.is_empty() and points[-1] == route[-1], "Cada NPC deve usar o trajeto de saída verificado.")
	quest.f1_acesso = false
	quest.f2_acesso = false
	quest.f3_acesso = false
	quest._update_fire_task()
	quest._physics_process(0.3)
	_expect(quest._hide_scheduled, "Com o fogo apagado e o trajeto livre, a evacuação deve começar.")
	SaveGame.save_data = original_save
	var report := FileAccess.open("res://.hall-elevator-route-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
