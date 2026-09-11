extends Node

const MINIGAME_SCENE := preload("res://Minigames/Minigame1/levels/UnlockSecurity.tscn")


func _ready() -> void:
	var minigame := MINIGAME_SCENE.instantiate()
	add_child(minigame)
	await get_tree().process_frame
	minigame.pausar()
	await get_tree().process_frame

	var continuar := minigame.modal.get_node_or_null("Continuar") as Button
	var reiniciar := minigame.modal.get_node_or_null("Reiniciar") as Button
	var sair := minigame.modal.get_node_or_null("Sair") as Button
	if continuar == null or reiniciar == null or sair == null:
		_fail("O menu de pausa não criou os três botões navegáveis.")
		return
	if minigame.hud.mouse_filter != Control.MOUSE_FILTER_PASS:
		_fail("A HUD ainda está bloqueando o mouse do menu de pausa.")
		return
	if continuar.get_node(continuar.focus_neighbor_right) != reiniciar:
		_fail("O botão Reiniciar não é alcançável pela navegação horizontal.")
		return

	var right_event := InputEventAction.new()
	right_event.action = "ui_right"
	right_event.pressed = true
	get_viewport().push_input(right_event)
	await get_tree().process_frame
	if get_viewport().gui_get_focus_owner() != reiniciar:
		_fail("O teclado não moveu o foco até o botão Reiniciar.")
		return

	var mouse_position := continuar.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = mouse_position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	if get_viewport().gui_get_hovered_control() != continuar:
		_fail("Outro Control está interceptando o mouse antes do botão Continuar.")
		return
	var click := InputEventMouseButton.new()
	click.position = mouse_position
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	get_viewport().push_input(click, true)
	click = click.duplicate()
	click.button_mask = 0
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	if minigame.estado != "jogando" or get_tree().paused:
		_fail("O mouse não acionou o botão Continuar.")
		return
	print("MINIGAME_PAUSE_MENU_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	get_tree().paused = false
	push_error(message)
	get_tree().quit(1)
