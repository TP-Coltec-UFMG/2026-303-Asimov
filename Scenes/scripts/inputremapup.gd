extends Button
class_name InputRemapButton

signal remap_conflict(message: String)

const CONTEXT_ACTIONS: PackedStringArray = [
	"fire",
	"acende_lanterna",
	"usar_extintor"
]


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


	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		esperando_input = false
		atualizar_texto()
		grab_focus()
		get_viewport().set_input_as_handled()
		return


	if event is InputEventKey and event.pressed:
		remapear(event)
		get_viewport().set_input_as_handled()


	elif event is InputEventMouseButton and event.pressed:
		remapear(event)
		get_viewport().set_input_as_handled()

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

	var unchanged := index < eventos.size() and _events_match(eventos[index], input_salvo)
	if not unchanged:
		var conflicts := _find_conflicts(input_salvo)
		if not conflicts.is_empty():
			remap_conflict.emit(
				"AVISO: %s também usa %s" % [", ".join(conflicts), _get_input_text(input_salvo)]
			)

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


func _find_conflicts(input_event: InputEvent) -> PackedStringArray:
	var conflicts := PackedStringArray()
	for node: Node in get_tree().get_nodes_in_group(&"Botoes_Controles"):
		var other := node as InputRemapButton
		if other == null or other == self or other.action == action:
			continue
		if _is_allowed_context_pair(action, other.action):
			continue
		for existing: InputEvent in InputMap.action_get_events(other.action):
			if _events_match(existing, input_event):
				if not conflicts.has(other.action_name):
					conflicts.append(other.action_name)
				break
	return conflicts


func _is_allowed_context_pair(first: String, second: String) -> bool:
	return CONTEXT_ACTIONS.has(first) and CONTEXT_ACTIONS.has(second)


func _events_match(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventKey and second is InputEventKey:
		var first_key := first as InputEventKey
		var second_key := second as InputEventKey
		var first_code := first_key.physical_keycode if first_key.physical_keycode != 0 else first_key.keycode
		var second_code := second_key.physical_keycode if second_key.physical_keycode != 0 else second_key.keycode
		return (
			first_code == second_code
			and first_key.ctrl_pressed == second_key.ctrl_pressed
			and first_key.shift_pressed == second_key.shift_pressed
			and first_key.alt_pressed == second_key.alt_pressed
			and first_key.meta_pressed == second_key.meta_pressed
		)
	if first is InputEventMouseButton and second is InputEventMouseButton:
		return (first as InputEventMouseButton).button_index == (second as InputEventMouseButton).button_index
	if first is InputEventJoypadButton and second is InputEventJoypadButton:
		var first_button := first as InputEventJoypadButton
		var second_button := second as InputEventJoypadButton
		return first_button.button_index == second_button.button_index and first_button.device == second_button.device
	return false



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
