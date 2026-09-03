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
	text = action_name + "  [...]"
	release_focus()



func _input(event: InputEvent) -> void:
	if !esperando_input:
		return


	# Cancelar com ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		esperando_input = false
		atualizar_texto()
		grab_focus()
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

	# Aceita também botões de controle, sem capturar o movimento dos analógicos.
	elif event is InputEventJoypadButton and event.pressed:
		remapear(event)
		get_viewport().set_input_as_handled()



func remapear(novo_input: InputEvent) -> void:
	if !InputMap.has_action(action):
		return


	var eventos := InputMap.action_get_events(action)
	var input_salvo := novo_input.duplicate() as InputEvent

	if input_salvo is InputEventKey:
		(input_salvo as InputEventKey).pressed = false
		(input_salvo as InputEventKey).echo = false
	elif input_salvo is InputEventMouseButton:
		(input_salvo as InputEventMouseButton).pressed = false
		(input_salvo as InputEventMouseButton).button_mask = 0
	elif input_salvo is InputEventJoypadButton:
		(input_salvo as InputEventJoypadButton).pressed = false

	# Substitui o evento na mesma posição. Isso preserva atalhos secundários
	# existentes (por exemplo, teclado + mouse) e mantém o texto sincronizado.
	InputMap.action_erase_events(action)
	var substituiu := false

	for event_index: int in range(eventos.size()):
		if event_index == index:
			InputMap.action_add_event(action, input_salvo)
			substituiu = true
		else:
			InputMap.action_add_event(action, eventos[event_index])

	if not substituiu:
		InputMap.action_add_event(action, input_salvo)

	var save_load := get_node_or_null("/root/SaveLoad")

	if save_load != null and save_load.has_method("save_input_bindings"):
		save_load.call("save_input_bindings")
	get_tree().call_group(
		&"inventory_binding_slots",
		&"refresh_bind_label"
	)


	esperando_input = false
	atualizar_texto()
	grab_focus()



func atualizar_texto() -> void:
	if !InputMap.has_action(action):
		text = action_name + "  [SEM AÇÃO]"
		return


	var eventos := InputMap.action_get_events(action)


	if index >= eventos.size():
		text = action_name + "  [NÃO DEFINIDO]"
		return


	var input := eventos[index]
	var tecla_texto := _get_input_text(input)
	text = action_name + "  [" + tecla_texto + "]"


func _get_input_text(input: InputEvent) -> String:
	if input is InputEventKey:
		var key_input := input as InputEventKey

		if key_input.physical_keycode != 0:
			return OS.get_keycode_string(key_input.physical_keycode)

		return OS.get_keycode_string(key_input.keycode)

	if input is InputEventMouseButton:
		match (input as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "MOUSE 1"
			MOUSE_BUTTON_RIGHT:
				return "MOUSE 2"
			MOUSE_BUTTON_MIDDLE:
				return "MOUSE 3"

	return input.as_text()
