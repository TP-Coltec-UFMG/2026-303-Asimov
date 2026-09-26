extends Node2D

# Reproduz o circuito dentro do HUD, com câmera e uma interface do mapa atrás.
# Os eventos entram pela viewport: não chama iniciar_fio/finalizar_fio diretamente.
func _ready() -> void:
	var camera := Camera2D.new()
	camera.position = Vector2(1000, 800)
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	var map_ui := Control.new()
	layer.add_child(map_ui)
	map_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var game := preload("res://Minigames/finalsMinigames/MinigameCircuito/Scene/mini_game_eletronica.tscn").instantiate()
	game.modo_objetivo = 1
	overlay.add_child(game)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var board: Node2D = game.get_node("Circuito")
	for from_terminal in [true, false]:
		var original: Node2D = null
		for wire in get_tree().get_nodes_in_group("fios"):
			if not board.is_ancestor_of(wire) or wire.is_queued_for_deletion():
				continue
			if is_instance_valid(wire.origem) and is_instance_valid(wire.destino):
				if wire.origem.get_parent().is_in_group("terminais") == from_terminal:
					original = wire
					break
		if original == null:
			_fail("Fio inicial não encontrado.")
			return
		var source: Area2D = original.origem.get_parent()
		var target: Area2D = original.destino.get_parent()
		board.cortar_fio(original)
		await get_tree().process_frame
		var start: Vector2 = source.ponto_colisao.get_global_transform_with_canvas().origin
		var destination: Vector2 = target.ponto_colisao.get_global_transform_with_canvas().origin
		_pointer_button(start, true)
		await get_tree().physics_frame
		await get_tree().process_frame
		if not source.arrastando:
			_fail("Clique não iniciou arrasto: " + str(source.get_path()))
			return
		var motion := InputEventMouseMotion.new()
		motion.position = destination
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		_pointer_button(destination, false)
		await get_tree().process_frame
		if not board.conexao_existe(source, target):
			_fail("Soltar o mouse não conectou o fio.")
			return
		print("PASS: clique/arrasto/soltura de ", "terminal" if from_terminal else "junção")
	get_tree().quit(0)


func _pointer_button(position_in_viewport: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position_in_viewport
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_viewport().push_input(event, true)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
