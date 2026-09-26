extends Node2D

const CIRCUIT_SCENE := preload("res://Minigames/finalsMinigames/MinigameCircuito/Scene/mini_game_eletronica.tscn")
const BURN_SEQUENCES := [["resistor"], ["led"], ["bateria"], ["resistor", "led"], ["led", "bateria"], ["resistor", "bateria"]]
const INTERFACE_OBJECTIVES := [1, 2, 0, 5, 3, 4]

var completed := false
var failed := false

func _ready() -> void:
	Engine.time_scale = 8.0
	var layer := CanvasLayer.new()
	add_child(layer)
	for mode in range(BURN_SEQUENCES.size()):
		completed = false
		failed = false
		var game := CIRCUIT_SCENE.instantiate()
		game.modo_objetivo = mode
		layer.add_child(game)
		await get_tree().process_frame
		await get_tree().process_frame
		var board: Node2D = game.get_node("Circuito")
		var led: AnimatedSprite2D = board._obter_sprite_led()
		if not led.visible or game.interface_jogo.objetivo_atual != INTERFACE_OBJECTIVES[mode]:
			_fail("Wrong visible sprite/objective, mode %d" % mode)
			return
		game._destacar(game.led)
		if led.material == null:
			_fail("Visible LED has no highlight, mode %d" % mode)
			return
		game.minigame_completed.connect(func(): completed = true)
		game.minigame_failed.connect(func(): failed = true)
		while game.botao_continuar.visible:
			game._on_button_pressed()
		var sequence: Array = BURN_SEQUENCES[mode]
		for step in range(sequence.size()):
			var component: String = sequence[step]
			if not await _burn_through_circuit(game, component):
				return
			var sprite: AnimatedSprite2D = led if component == "led" else board.get_node(component.capitalize() + "/AnimatedSprite2D")
			if sprite.animation != &"queimando":
				_fail("Wiring/voltage did not ignite %s, mode %d" % [component, mode])
				return
			await get_tree().create_timer(0.2).timeout
			if completed:
				_fail("Completion precedes burn cycle, mode %d" % mode)
				return
			# Pausing the embedded minigame must suspend all component animations.
			game.process_mode = Node.PROCESS_MODE_DISABLED
			var frame_before: int = sprite.frame
			await get_tree().create_timer(2.0).timeout
			if completed or sprite.frame != frame_before:
				_fail("Burn progresses while paused, mode %d" % mode)
				return
			game.process_mode = Node.PROCESS_MODE_INHERIT
			await get_tree().create_timer(5.0).timeout
			if failed:
				_fail("Valid sequence failed, mode %d" % mode)
				return
			if step < sequence.size() - 1 and (completed or game.passo_atual != 1):
				_fail("Combined objective did not wait for its second component, mode %d" % mode)
				return
		if not completed:
			_fail("Objective did not complete, mode %d" % mode)
			return
		if board.led_queimando or board.resistor_queimando or board.bateria_queimando:
			_fail("Completion with unfinished burn cycle, mode %d" % mode)
			return
		print("PASS: circuit mode ", mode, " wiring, voltage, highlight, sequential burns, pause and completion")
		game.queue_free()
		await get_tree().process_frame
	# Burning the power source first cannot leave a combined objective stuck forever.
	for mode in [4, 5]:
		completed = false
		failed = false
		var game := CIRCUIT_SCENE.instantiate()
		game.modo_objetivo = mode
		layer.add_child(game)
		await get_tree().process_frame
		await get_tree().process_frame
		game.minigame_completed.connect(func(): completed = true)
		game.minigame_failed.connect(func(): failed = true)
		if not await _burn_through_circuit(game, "bateria"):
			return
		await get_tree().create_timer(5.0).timeout
		if not failed or completed:
			_fail("Battery-first sequence did not offer retry, mode %d" % mode)
			return
		print("PASS: combined mode ", mode, " rejects battery-first order")
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _burn_through_circuit(game: Node2D, component: String) -> bool:
	var board: Node2D = game.get_node("Circuito")
	if component == "resistor":
		game.bateria.voltagem = 13.0
		board.analisar_circuito()
	elif component == "led":
		_cut_between(board, game.juncao03, game.resistor_terminal_positivo)
		await get_tree().process_frame
		_cut_between(board, game.juncao04, game.led_terminal_positivo)
		await get_tree().process_frame
		if not game.juncao03.conexao_permitida(game.led_terminal_positivo) or board.conectar_fio(game.juncao03, game.led_terminal_positivo, false) == null:
			_fail("Cannot reconnect the component without its resistor")
			return false
		board.analisar_circuito()
	else:
		# Retain the battery leads; route around the source via the lower-left junction.
		for wire in get_tree().get_nodes_in_group("fios"):
			if not board.is_ancestor_of(wire) or wire.is_queued_for_deletion():
				continue
			if wire.origem.get_parent().get_parent() != game.bateria and wire.destino.get_parent().get_parent() != game.bateria:
				board.cortar_fio(wire)
		await get_tree().process_frame
		if not game.juncao03.conexao_permitida(game.juncao02) or board.conectar_fio(game.juncao03, game.juncao02, false) == null:
			_fail("Cannot form a short circuit after burning another component")
			return false
		if not game.juncao02.conexao_permitida(game.juncao01) or board.conectar_fio(game.juncao02, game.juncao01, false) == null:
			_fail("Cannot form a short circuit after burning another component")
			return false
		board.analisar_circuito()
	return true


func _cut_between(board: Node2D, from: Node2D, to: Node2D) -> void:
	for wire in get_tree().get_nodes_in_group("fios"):
		if not board.is_ancestor_of(wire) or wire.is_queued_for_deletion():
			continue
		var source: Node2D = wire.origem.get_parent()
		var target: Node2D = wire.destino.get_parent()
		if (source == from and target == to) or (source == to and target == from):
			board.cortar_fio(wire)
			return


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
