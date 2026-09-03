extends ColorPickerButton


enum KeyboardArea {
	TONE_SQUARE,
	HUE_BAR,
}


var _keyboard_area: KeyboardArea = KeyboardArea.TONE_SQUARE

const TONE_STEP: float = 0.025
const HUE_STEP: float = 0.015


func _ready() -> void:
	edit_alpha = false
	color = HighContrast.get_accent_color()

	accessibility_name = "Escolher cor do alto contraste"
	tooltip_text = "Enter para abrir. Setas ajustam a cor. Tab alterna entre tons, cores e o botão voltar."

	color_changed.connect(_on_color_changed)
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_picker_button_pressed)


func _on_picker_button_pressed() -> void:
	call_deferred("_start_keyboard_picker")


func _start_keyboard_picker() -> void:
	if not get_popup().visible:
		return

	_keyboard_area = KeyboardArea.TONE_SQUARE
	_announce_picker_area()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if not get_popup().visible:
		return

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	# Esc fecha apenas o seletor. Outro Esc será tratado pelo menu.
	if key_event.keycode == KEY_ESCAPE:
		_close_picker(false)
		get_viewport().set_input_as_handled()
		return

	# Tab troca de região sem perder o movimento por setas
	# dentro do quadrado de tons.
	if key_event.keycode == KEY_TAB:
		if key_event.shift_pressed:
			_previous_keyboard_area()
		else:
			_next_keyboard_area()

		get_viewport().set_input_as_handled()
		return

	if _keyboard_area == KeyboardArea.TONE_SQUARE:
		if _handle_tone_square(key_event):
			get_viewport().set_input_as_handled()
			return

	if _keyboard_area == KeyboardArea.HUE_BAR:
		if _handle_hue_bar(key_event):
			get_viewport().set_input_as_handled()
			return


func _handle_tone_square(event: InputEventKey) -> bool:
	var saturation := color.s
	var brightness := color.v

	if event.is_action_pressed("ui_left"):
		saturation -= TONE_STEP
	elif event.is_action_pressed("ui_right"):
		saturation += TONE_STEP
	elif event.is_action_pressed("ui_up"):
		brightness += TONE_STEP
	elif event.is_action_pressed("ui_down"):
		brightness -= TONE_STEP
	else:
		return false

	saturation = clampf(saturation, 0.0, 1.0)
	brightness = clampf(brightness, 0.0, 1.0)

	_set_keyboard_color(
		Color.from_hsv(color.h, saturation, brightness, 1.0)
	)

	return true


func _handle_hue_bar(event: InputEventKey) -> bool:
	var direction := 0.0

	if (
		event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_up")
	):
		direction = -1.0
	elif (
		event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_down")
	):
		direction = 1.0
	else:
		return false

	var new_hue := wrapf(
		color.h + direction * HUE_STEP,
		0.0,
		1.0
	)

	_set_keyboard_color(
		Color.from_hsv(new_hue, color.s, color.v, 1.0)
	)

	return true


func _next_keyboard_area() -> void:
	if _keyboard_area == KeyboardArea.TONE_SQUARE:
		_keyboard_area = KeyboardArea.HUE_BAR
		_announce_picker_area()
	else:
		# Depois da barra de cores, fecha o seletor e vai ao X.
		_close_picker(true)


func _previous_keyboard_area() -> void:
	if _keyboard_area == KeyboardArea.HUE_BAR:
		_keyboard_area = KeyboardArea.TONE_SQUARE
		_announce_picker_area()
	else:
		# Shift+Tab volta ao botão que abriu o seletor.
		_close_picker(false)


func _close_picker(focus_back_button: bool) -> void:
	get_popup().hide()

	if focus_back_button:
		var back_button := get_node_or_null(
			"../../../BackToMenuButton"
		) as Control

		if back_button != null:
			back_button.call_deferred("grab_focus")
			return

	call_deferred("grab_focus")


func _set_keyboard_color(new_color: Color) -> void:
	var opaque_color := Color(
		new_color.r,
		new_color.g,
		new_color.b,
		1.0
	)

	color = opaque_color
	get_picker().color = opaque_color
	_on_color_changed(opaque_color)


func _on_color_changed(new_color: Color) -> void:
	var opaque_color := Color(
		new_color.r,
		new_color.g,
		new_color.b,
		1.0
	)

	Configs._change_cor_alto_contraste(opaque_color)
	HighContrast.set_accent_color(opaque_color)
	SaveLoad._save()


func _announce_picker_area() -> void:
	if not bool(Configs.configs.get("leitor_de_tela", false)):
		return

	if _keyboard_area == KeyboardArea.TONE_SQUARE:
		LeitorDeTela._ler_texto(
			"Área de tons. Use as setas para mover dentro do quadrado."
		)
	else:
		LeitorDeTela._ler_texto(
			"Barra de cores. Use as setas para escolher a cor."
		)


func _on_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(
			atr("Escolher cor do alto contraste")
		)
