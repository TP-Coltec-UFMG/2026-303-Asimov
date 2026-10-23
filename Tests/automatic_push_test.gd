extends Node

var falhas: Array[String] = []

func _ready() -> void:
	get_tree().set_meta("dev_mission_jump_active", true)
	Engine.max_fps = 60
	_executar.call_deferred()

func _executar() -> void:
	SaveGame.save_data = {}
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	Configs.configs["corrida_automatica"] = true
	var mundo := Node2D.new()
	get_tree().root.add_child(mundo)
	get_tree().current_scene = mundo
	var jogador := preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	mundo.add_child(jogador)
	scene_manager.player = jogador
	await _quadros(3)
	jogador.inventory.add_item("cartao", preload("res://Objects/cartao_padrao.tscn"))
	for lado: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		jogador.position = Vector2.ZERO
		jogador.reset_physics_interpolation()
		jogador.equipar_item("cartao")
		var objeto := ObjetoEmpurravel.new()
		objeto.save_enabled = false
		objeto.position = Vector2(0, -5) + lado * 25.0
		var forma := RectangleShape2D.new()
		forma.size = Vector2(12, 12)
		var colisao := CollisionShape2D.new()
		colisao.shape = forma
		objeto.add_child(colisao)
		mundo.add_child(objeto)
		await _quadros(3)
		var inicio := objeto.position
		var acao: StringName = &"right" if lado == Vector2.RIGHT else &"left" if lado == Vector2.LEFT else &"up" if lado == Vector2.UP else &"down"
		Input.action_press(acao)
		await _quadros(40)
		_conferir(jogador.objeto_manipulado == null and objeto.position.is_equal_approx(inicio), "O contato por menos de um segundo não deve empurrar o objeto.")
		_conferir(jogador.usando_cartao, "O item deve permanecer equipado durante a espera.")
		Input.action_release(acao)
		await _quadros(3)
		Input.action_press(acao)
		await _quadros(40)
		_conferir(jogador.objeto_manipulado == null, "Parar de andar deve reiniciar a espera de um segundo.")
		await _quadros(50)
		_conferir(jogador.objeto_manipulado == objeto and jogador.empurrao_automatico, "Andar contra o objeto deve iniciar o empurrão automático na direção %s." % lado)
		_conferir((objeto.position - inicio).dot(lado) > 1.0, "O objeto deve se deslocar na direção do movimento.")
		_conferir(not jogador.usando_cartao and jogador.inventory.get_item_on_inventary("cartao"), "O item equipado deve ficar guardado durante o empurrão.")
		_conferir(not jogador.correndo, "Não deve haver corrida automática durante o empurrão.")
		Input.action_release(acao)
		await _quadros(3)
		_conferir(jogador.objeto_manipulado == null and not jogador.empurrao_automatico and not jogador.empurrando, "Parar de andar deve soltar o objeto automaticamente.")
		_conferir(not jogador.get_collision_exceptions().has(objeto) and not objeto.get_collision_exceptions().has(jogador), "Soltar deve restaurar as colisões dos dois corpos.")
		var parado := objeto.position
		await _quadros(8)
		_conferir(objeto.position.is_equal_approx(parado), "O objeto não pode continuar se movendo depois de solto.")
		jogador.pegar_objeto(objeto, lado)
		await _quadros(3)
		_conferir(jogador.objeto_manipulado == objeto and not jogador.empurrao_automatico, "O modo manual deve continuar segurando o objeto mesmo parado.")
		jogador.soltar_objeto()
		objeto.queue_free()
		await _quadros(3)
	var arquivo := FileAccess.open("res://.automatic-push-results.json", FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"completed": true, "failures": falhas}))
	arquivo.close()
	get_tree().quit(0 if falhas.is_empty() else 1)

func _quadros(quantidade: int) -> void:
	for quadro in range(quantidade):
		await get_tree().physics_frame

func _conferir(condicao: bool, mensagem: String) -> void:
	if not condicao:
		falhas.append(mensagem)
		push_error(mensagem)
