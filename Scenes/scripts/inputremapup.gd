extends Button
class_name InputRemapButton


@export var action: String
@export var index: int = 0
@export var action_name: String = "UP"


var esperando_input: bool = false


func _ready() -> void:
	

	atualizar_texto()



func _on_pressed() -> void:
	esperando_input = true
	text = action_name + ": Waiting input"
	release_focus()



func _input(event: InputEvent) -> void:
	if !esperando_input:
		return


	# Cancelar com ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		esperando_input = false
		atualizar_texto()
		get_viewport().set_input_as_handled()
		return


	# Aceita teclado
	if event is InputEventKey and event.pressed:
		remapear(event)
		get_viewport().set_input_as_handled()


	# Aceita mouse
	elif event is InputEventMouseButton and event.pressed:
		remapear(event)
		get_viewport().set_input_as_handled()



func remapear(novo_input: InputEvent) -> void:
	if !InputMap.has_action(action):
		return


	var eventos := InputMap.action_get_events(action)


	# Remove o input antigo
	if index < eventos.size():
		InputMap.action_erase_event(action, eventos[index])


	# Adiciona o novo input
	InputMap.action_add_event(action, novo_input)
	get_tree().call_group(
		&"inventory_binding_slots",
		&"refresh_bind_label"
	)


	esperando_input = false

	atualizar_texto()



func atualizar_texto() -> void:
	if !InputMap.has_action(action):
		text = action_name + ": Sem ação"
		return


	var eventos := InputMap.action_get_events(action)


	if index >= eventos.size():
		text = action_name + ": Não registrado"
		return


	var input := eventos[index]


	var tecla_texto := ""


	if input is InputEventKey:
		if input.physical_keycode != 0:
			tecla_texto = OS.get_keycode_string(input.physical_keycode)
		else:
			tecla_texto = OS.get_keycode_string(input.keycode)


	elif input is InputEventMouseButton:
		tecla_texto = input.as_text()


	else:
		tecla_texto = input.as_text()


	text = action_name + ": " + tecla_texto
