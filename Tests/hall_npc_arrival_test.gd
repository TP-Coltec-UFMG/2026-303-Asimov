extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var npc := preload("res://NPC'S/Clarxs.tscn").instantiate()
	npc.save_enabled = false
	root.add_child(npc)
	npc.set_process(false)
	npc.set_physics_process(false)
	var path := NPCPath.new()
	npc.add_child(path)
	path.delete_npc_at_end = true
	npc.current_path = path
	npc.path_finished = false
	npc.path_points.assign([Vector2(100, 0), Vector2.ZERO])
	npc.current_point = 0
	npc.global_position = Vector2(12, 0)
	_expect(not npc._update_exit_arrival(0.3), "Não deve sair antes de meio segundo.")
	npc.global_position = Vector2(40, 0)
	_expect(not npc._update_exit_arrival(0.3), "Fora do raio, não deve sair.")
	_expect(npc.exit_arrival_elapsed == 0.0, "Sair do raio deve reiniciar a contagem.")
	npc.global_position = Vector2(12, 0)
	path.delete_npc_at_end = false
	_expect(not npc._update_exit_arrival(1.0), "Rotas comuns não devem remover o NPC.")
	path.delete_npc_at_end = true
	_expect(not npc._update_exit_arrival(0.3), "A nova aproximação deve começar do zero.")
	_expect(npc._update_exit_arrival(0.21), "Após meio segundo no raio, deve concluir a saída.")
	_expect(npc.is_queued_for_deletion(), "A saída deve remover o NPC mesmo com o destino bloqueado.")
	await process_frame
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
