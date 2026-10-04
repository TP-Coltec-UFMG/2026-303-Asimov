extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	set_meta(&"dev_mission_jump_active", true)
	_run.call_deferred()


func _run() -> void:
	var npc: Node2D = load("res://NPC'S/Clarxs.tscn").instantiate()
	npc.save_enabled = false
	root.add_child(npc)
	npc.set_process(false)
	npc.set_physics_process(false)
	var path := NPCPath.new()
	npc.add_child(path)
	path.remover_npc_ao_terminar = true
	npc.caminho_atual = path
	npc.caminho_finalizado = false
	npc.pontos_caminho.assign([Vector2(100, 0), Vector2.ZERO])
	npc.ponto_atual = 0
	npc.global_position = Vector2(12, 0)
	_expect(not npc._atualizar_chegada_saida(0.3), "Não deve sair antes de meio segundo.")
	npc.global_position = Vector2(40, 0)
	_expect(not npc._atualizar_chegada_saida(0.3), "Fora do raio, não deve sair.")
	_expect(npc.tempo_na_saida == 0.0, "Sair do raio deve reiniciar a contagem.")
	npc.global_position = Vector2(12, 0)
	path.remover_npc_ao_terminar = false
	_expect(not npc._atualizar_chegada_saida(1.0), "Rotas comuns não devem remover o NPC.")
	path.remover_npc_ao_terminar = true
	_expect(not npc._atualizar_chegada_saida(0.3), "A nova aproximação deve começar do zero.")
	_expect(npc._atualizar_chegada_saida(0.21), "Após meio segundo no raio, deve concluir a saída.")
	_expect(npc.is_queued_for_deletion(), "A saída deve remover o NPC mesmo com o destino bloqueado.")
	await process_frame
	for failure in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
