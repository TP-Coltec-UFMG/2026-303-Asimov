extends Node
class_name MenuInputRouter

## Alterna automaticamente os menus entre mouse e teclado.
##
## Coloque este nó como filho da raiz de uma cena de menu. O script:
## - detecta o último dispositivo usado;
## - mostra o ícone correspondente no canto superior direito;
## - mantém o foco dentro da tela de menu visível;
## - desenha um contorno no item focado somente no modo teclado;
## - anuncia o foco pelo leitor de tela, quando ele estiver ativado.

enum InputMode {
	MOUSE,
	KEYBOARD,
}

const MOUSE_ICON: Texture2D = preload("res://Sprites/ui/InputMode/mouse.svg")
const KEYBOARD_ICON: Texture2D = preload("res://Sprites/ui/InputMode/keyboard.svg")
const REFRESH_INTERVAL_SECONDS: float = 0.25

@export var show_mode_indicator: bool = false
@export var announce_keyboard_focus: bool = true
@export var focus_color: Color = Color("ffd166")
@export_range(1, 6, 1) var focus_border_width: int = 1

var _input_mode: InputMode = InputMode.MOUSE
var _tracked_controls: Array[Control] = []
var _refresh_timer: float = 0.0
var _active_scope: Node

var _indicator_layer: CanvasLayer
var _indicator_panel: PanelContainer
var _indicator_icon: TextureRect

var _keyboard_focus_style: StyleBoxFlat
var _mouse_focus_style: StyleBoxEmpty

var _back_transition_locked: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_focus_styles()
	_create_mode_indicator()
	_install_wasd_navigation()

	await get_tree().process_frame
	_refresh_controls()
	_apply_input_mode_visuals()


func _process(delta: float) -> void:
	var host_is_visible := _is_host_visible()
	if _indicator_layer != null:
		_indicator_layer.visible = show_mode_indicator and host_is_visible

	if not host_is_visible:
		return
	if _is_waiting_for_remap():
		return

	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = REFRESH_INTERVAL_SECONDS
		_refresh_controls()
		
		_update_all_slider_outlines()

	if not host_is_visible:
		return

func _prepare_slider_outline(slider: Slider) -> void:
	if slider.get_node_or_null("KeyboardFocusOutline") != null:
		return

	var outline := Panel.new()
	outline.name = "KeyboardFocusOutline"
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.focus_mode = Control.FOCUS_NONE
	outline.visible = false
	outline.z_index = 10

	slider.add_child(outline)
	outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Reutiliza o mesmo contorno laranja dos botões.
	outline.add_theme_stylebox_override(
		"panel",
		_keyboard_focus_style
	)

	slider.focus_entered.connect(
		_update_slider_outline.bind(slider)
	)
	slider.focus_exited.connect(
		_update_slider_outline.bind(slider)
	)


func _update_slider_outline(_slider: Slider) -> void:
	call_deferred("_update_all_slider_outlines")

	var new_scope := _find_active_scope()
	_configure_scope_navigation(new_scope)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if new_scope != _active_scope or not _is_control_available(focus_owner, new_scope):
		_active_scope = new_scope
		if _input_mode == InputMode.KEYBOARD:
			_focus_first_available()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion

		if mouse_motion.relative.length_squared() > 0.0:
			_set_input_mode(InputMode.MOUSE)

	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.pressed:
			_set_input_mode(InputMode.MOUSE)

	elif event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		_set_input_mode(InputMode.KEYBOARD)

		# Se existe um popup aberto, ele próprio tratará o Esc.
		if key_event.keycode == KEY_ESCAPE:
			if _has_visible_popup():
				return

			if _go_back_one_menu():
				get_viewport().set_input_as_handled()
				return

		var focus_owner := get_viewport().gui_get_focus_owner()
		var had_menu_focus := _is_control_available(
			focus_owner,
			_find_active_scope()
		)

		if _is_host_visible() and not _is_waiting_for_remap():
			_focus_first_available()

			if not had_menu_focus and _is_navigation_event(key_event):
				get_viewport().set_input_as_handled()

func _go_back_one_menu() -> bool:
	if _back_transition_locked:
		return true

	var scope := _find_active_scope()
	var host := get_parent()

	if scope == null or host == null:
		return false

	var method_name: StringName

	match scope.name:
		&"SettingSound":
			method_name = &"_on_back_to_menu_button_pressed_on_settings_sounds"

		&"Interface":
			method_name = &"_on_back_to_menu_button_pressed_on_interface_menu"

		&"Accessibility":
			method_name = &"_on_back_to_menu_button_pressed_on_acessibility"

		&"Controles":
			method_name = &"_on_back_to_menu_button_pressed_controles"

		&"Opcoes":
			method_name = &"_on_back_to_menu_button_pressed"

		&"PrimeiraVez":
			method_name = &"_on_back_to_menu_button_pressed_on_menu_primeira_vez"

		_:
			# No menu-base de pausa, deixa o pause_menu.gd
			# receber o Esc e continuar o jogo.
			return false

	if not host.has_method(method_name):
		return false

	_back_transition_locked = true
	host.call(method_name)
	_unlock_menu_back()

	return true


func _unlock_menu_back() -> void:
	await get_tree().create_timer(0.5, true).timeout
	_back_transition_locked = false


func _set_input_mode(new_mode: InputMode) -> void:
	if _input_mode == new_mode:
		return

	_input_mode = new_mode
	_apply_input_mode_visuals()

	if _input_mode == InputMode.KEYBOARD and _is_host_visible():
		var focus_owner := get_viewport().gui_get_focus_owner()
		_announce_focused_control(focus_owner)


func _create_focus_styles() -> void:
	_keyboard_focus_style = StyleBoxFlat.new()
	_keyboard_focus_style.bg_color = Color.TRANSPARENT
	_keyboard_focus_style.border_color = focus_color
	_keyboard_focus_style.set_border_width_all(focus_border_width)
	_keyboard_focus_style.set_corner_radius_all(3)
	# Mantém o contorno dentro do controle, inclusive no X do canto direito.
	_keyboard_focus_style.expand_margin_left = 0.0
	_keyboard_focus_style.expand_margin_top = 0.0
	_keyboard_focus_style.expand_margin_right = 0.0
	_keyboard_focus_style.expand_margin_bottom = 0.0

	_mouse_focus_style = StyleBoxEmpty.new()


func _create_mode_indicator() -> void:
	_indicator_layer = CanvasLayer.new()
	_indicator_layer.name = "InputModeIndicatorLayer"
	_indicator_layer.layer = 100
	add_child(_indicator_layer)

	_indicator_panel = PanelContainer.new()
	_indicator_panel.name = "InputModeIndicator"
	_indicator_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_indicator_panel.offset_left = -76.0
	_indicator_panel.offset_top = 6.0
	_indicator_panel.offset_right = -48.0
	_indicator_panel.offset_bottom = 34.0
	_indicator_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_panel.focus_mode = Control.FOCUS_NONE
	_indicator_layer.add_child(_indicator_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.07, 0.065, 0.96)
	panel_style.set_border_width_all(0)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 5.0
	panel_style.content_margin_top = 5.0
	panel_style.content_margin_right = 5.0
	panel_style.content_margin_bottom = 5.0
	_indicator_panel.add_theme_stylebox_override("panel", panel_style)

	_indicator_icon = TextureRect.new()
	_indicator_icon.custom_minimum_size = Vector2(18.0, 18.0)
	_indicator_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_indicator_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_indicator_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_icon.focus_mode = Control.FOCUS_NONE
	_indicator_panel.add_child(_indicator_icon)


func _apply_input_mode_visuals() -> void:
	if _indicator_icon != null:
		if _input_mode == InputMode.KEYBOARD:
			_indicator_icon.texture = KEYBOARD_ICON
			_indicator_panel.accessibility_name = "Modo teclado"
		else:
			_indicator_icon.texture = MOUSE_ICON
			_indicator_panel.accessibility_name = "Modo mouse"
	@warning_ignore("incompatible_ternary")
	var focus_style: StyleBox = (
		_keyboard_focus_style if _input_mode == InputMode.KEYBOARD else _mouse_focus_style
	)
	for control in _tracked_controls:
		if is_instance_valid(control):     
			control.add_theme_stylebox_override("focus", focus_style)
			_update_all_slider_outlines()

func _update_all_slider_outlines() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()

	for control in _tracked_controls:
		if not is_instance_valid(control):
			continue

		if not (control is Slider):
			continue

		var slider := control as Slider
		var outline := slider.get_node_or_null(
			"KeyboardFocusOutline"
		) as Panel

		if outline == null:
			continue

		outline.visible = (
			_input_mode == InputMode.KEYBOARD
			and slider == focus_owner
			and slider.is_visible_in_tree()
		)

func _refresh_controls() -> void:
	var host := get_parent()
	if host == null:
		return
		
	@warning_ignore("incompatible_ternary")
	var focus_style: StyleBox = (
		_keyboard_focus_style if _input_mode == InputMode.KEYBOARD else _mouse_focus_style
	)
	for node in host.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control in _tracked_controls:
			continue
		if _is_indicator_control(control):
			continue

		_tracked_controls.append(control)
		control.add_theme_stylebox_override("focus", focus_style)
		_disable_back_button_scale(control)
		if control is Slider:       
			_prepare_slider_outline(control as Slider)

		if control.focus_mode != Control.FOCUS_NONE:
			control.focus_entered.connect(_on_control_focus_entered.bind(control))
			control.mouse_entered.connect(_on_control_mouse_entered.bind(control))


func _on_control_mouse_entered(control: Control) -> void:
	if _input_mode != InputMode.MOUSE or not _is_control_available(control, _find_active_scope()):
		return
	var already_focused := control.has_focus()
	control.grab_focus()

	if control.has_method("_announce_selection"):
		if already_focused:
			control.call("_announce_selection")
		return
	if not _has_external_mouse_handler(control):
		_announce_focused_control(control)


func _on_control_focus_entered(control: Control) -> void:
	if _input_mode == InputMode.KEYBOARD:
		_announce_focused_control(control)


func _focus_first_available() -> void:
	if not _is_host_visible() or _has_visible_popup() or _is_waiting_for_remap():
		return

	_active_scope = _find_active_scope()
	if _active_scope == null:
		return
	_configure_scope_navigation(_active_scope)

	var current_focus := get_viewport().gui_get_focus_owner()
	if _is_control_available(current_focus, _active_scope):
		return

	for control in _collect_focusable_controls(_active_scope):
		control.grab_focus()
		return


func _find_active_scope() -> Node:
	var host := get_parent()
	if host == null:
		return null

	var active_scope: Node = host
	for child in host.get_children():
		if child == self or not _is_node_visible(child):
			continue
		if not _collect_focusable_controls(child).is_empty():
			active_scope = child

	return active_scope


func _collect_focusable_controls(scope: Node) -> Array[Control]:
	var controls: Array[Control] = []
	if scope is Control:
		var scope_control := scope as Control
		if _is_focusable(scope_control):
			controls.append(scope_control)

	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and _is_focusable(control) and not _is_indicator_control(control):
			controls.append(control)

	return controls


func _is_focusable(control: Control) -> bool:
	if not is_instance_valid(control):
		return false
	if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func _is_control_available(control: Control, scope: Node) -> bool:
	if control == null or scope == null or not _is_focusable(control):
		return false
	return control == scope or scope.is_ancestor_of(control)


func _is_host_visible() -> bool:
	var host := get_parent()
	if host is CanvasItem:
		return (host as CanvasItem).is_visible_in_tree()
	return host != null and host.is_inside_tree()


func _is_node_visible(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	return node.is_inside_tree()


func _is_indicator_control(control: Control) -> bool:
	return _indicator_panel != null and (
		control == _indicator_panel or _indicator_panel.is_ancestor_of(control)
	)


func _is_back_button(control: Control) -> bool:
	var normalized_name := control.name.to_lower().replace("_", "")
	return "backtomenu" in normalized_name or normalized_name == "back"


func _configure_scope_navigation(scope: Node) -> void:
	if scope == null:
		return

	var controls := _collect_focusable_controls(scope)
	var first_content_control: Control
	var back_buttons: Array[Control] = []
	

	for control in controls:
		if _is_back_button(control):
			back_buttons.append(control)
			@warning_ignore("unassigned_variable")
		elif first_content_control == null:
			first_content_control = control

	if first_content_control == null:
		return

	for back_button in back_buttons:
		# Qualquer direção usada no X devolve o foco ao primeiro item da tela.
		var path_to_content := back_button.get_path_to(first_content_control)
		back_button.focus_neighbor_left = path_to_content
		back_button.focus_neighbor_right = path_to_content
		back_button.focus_neighbor_top = path_to_content
		back_button.focus_neighbor_bottom = path_to_content
		back_button.focus_next = path_to_content
		var path_to_back := first_content_control.get_path_to(back_button)
		first_content_control.focus_neighbor_top = path_to_back
		first_content_control.focus_previous = path_to_back
	_configure_controls_columns(scope)
	_configure_interface_grid(scope)

func _set_focus_neighbor(
	source: Control,
	target: Control,
	direction: StringName
) -> void:
	if source == null or target == null:
		return

	var target_path := source.get_path_to(target)

	match direction:
		&"left":
			source.focus_neighbor_left = target_path
		&"right":
			source.focus_neighbor_right = target_path
		&"up":
			source.focus_neighbor_top = target_path
		&"down":
			source.focus_neighbor_bottom = target_path

func _disable_back_button_scale(control: Control) -> void:
	if not _is_back_button(control):
		return

	# O botão animado não aumenta quando recebe foco.
	for property in control.get_property_list():
		var property_name: StringName = property.get("name", &"")

		if property_name == &"hover_scale":
			control.set("hover_scale", Vector2.ONE)

		if property_name == &"press_scale":
			control.set("press_scale", Vector2(0.95, 0.95))

	control.scale = Vector2.ONE

	# Aguarda o Godot calcular o tamanho e a posição final.
	call_deferred("_keep_back_button_inside_viewport", control)


func _keep_back_button_inside_viewport(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := control.get_global_rect()

	# Deixa seis pixels livres entre o X e a borda direita.
	var right_limit := viewport_rect.end.x - 6.0

	if button_rect.end.x > right_limit:
		var correction := button_rect.end.x - right_limit
		control.global_position.x -= correction

func _configure_controls_columns(scope: Node) -> void:
	if scope.name != &"Controles":
		return

	var columns_root := scope.get_node_or_null(
		"RemapPanel/Margin/Content/Columns"
	)

	if columns_root == null:
		return

	var control_columns: Array = []

	for group_panel: Node in columns_root.get_children():
		var column_controls: Array[Control] = []

		for control: Control in _collect_focusable_controls(group_panel):
			if control is InputRemapButton:
				column_controls.append(control)

		if not column_controls.is_empty():
			control_columns.append(column_controls)

	if control_columns.is_empty():
		return

	for column_index: int in range(control_columns.size()):
		var column_controls: Array = control_columns[column_index]

		for row_index: int in range(column_controls.size()):
			var control := column_controls[row_index] as Control

			if row_index > 0:
				_set_focus_neighbor(
					control,
					column_controls[row_index - 1] as Control,
					&"up"
				)

			if row_index < column_controls.size() - 1:
				_set_focus_neighbor(
					control,
					column_controls[row_index + 1] as Control,
					&"down"
				)

			if column_index > 0:
				var left_column: Array = control_columns[column_index - 1]
				var left_row: int = mini(
					row_index,
					left_column.size() - 1
				)
				_set_focus_neighbor(
					control,
					left_column[left_row] as Control,
					&"left"
				)

			if column_index < control_columns.size() - 1:
				var right_column: Array = control_columns[column_index + 1]
				var right_row: int = mini(
					row_index,
					right_column.size() - 1
				)
				_set_focus_neighbor(
					control,
					right_column[right_row] as Control,
					&"right"
				)

	# O primeiro controle de cada coluna pode subir até o X.
	var back_button := scope.get_node_or_null(
		"BackToMenuButton"
	) as Control

	if back_button != null:
		for column_value: Variant in control_columns:
			var column_controls: Array = column_value

			if column_controls.is_empty():
				continue

			_set_focus_neighbor(
				column_controls[0] as Control,
				back_button,
				&"up"
			)

func _configure_interface_grid(scope: Node) -> void:
	if scope.name != &"Interface":
		return

	var full_screen := scope.get_node_or_null(
		"TelaCheia"
	) as Control

	var show_fps := scope.get_node_or_null(
		"MostrarFps"
	) as Control

	var interface_size := scope.get_node_or_null(
		"OptionsInterfaceSize"
	) as Control

	var frame_rate := scope.get_node_or_null(
		"OptionsFrameRate"
	) as Control

	var back_button := scope.get_node_or_null(
		"BackToMenuButton"
	) as Control

	# Linha superior.
	_set_focus_neighbor(
		full_screen,
		interface_size,
		&"right"
	)
	_set_focus_neighbor(
		interface_size,
		full_screen,
		&"left"
	)

	# Linha inferior.
	_set_focus_neighbor(
		show_fps,
		frame_rate,
		&"right"
	)
	_set_focus_neighbor(
		frame_rate,
		show_fps,
		&"left"
	)

	# Coluna esquerda.
	_set_focus_neighbor(
		full_screen,
		show_fps,
		&"down"
	)
	_set_focus_neighbor(
		show_fps,
		full_screen,
		&"up"
	)

	# Coluna direita.
	_set_focus_neighbor(
		interface_size,
		frame_rate,
		&"down"
	)
	_set_focus_neighbor(
		frame_rate,
		interface_size,
		&"up"
	)

	# Parte superior para o X.
	if back_button != null:
		_set_focus_neighbor(
			full_screen,
			back_button,
			&"up"
		)
		_set_focus_neighbor(
			interface_size,
			back_button,
			&"up"
		)

func _has_visible_popup() -> bool:
	for control in _tracked_controls:
		if not is_instance_valid(control):
			continue

		if control is OptionButton:
			var option_popup := (control as OptionButton).get_popup()

			if option_popup != null and option_popup.visible:
				return true

		if control is ColorPickerButton:
			var color_popup := (control as ColorPickerButton).get_popup()

			if color_popup != null and color_popup.visible:
				return true

	return false


func _is_waiting_for_remap() -> bool:
	for control in _tracked_controls:
		if is_instance_valid(control) and control is InputRemapButton:
			if (control as InputRemapButton).esperando_input:
				return true
	return false


func _has_external_mouse_handler(control: Control) -> bool:
	for connection in control.mouse_entered.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		var receiver := callback.get_object()
		if receiver == null or receiver == self:
			continue
		# Este método do AnimatedButton cuida apenas da escala visual.
		if receiver == control and callback.get_method() == &"_button_hover":
			continue
		return true
	return false


func _announce_focused_control(control: Control) -> void:
	if not announce_keyboard_focus or control == null:
		return
	if not bool(Configs.configs.get("leitor_de_tela", false)):
		return
	# A tela de seleção já possui uma locução específica no próprio botão.
	if control.has_method("_announce_selection"):
		return

	var spoken_text := control.accessibility_name.strip_edges()
	if spoken_text.is_empty() and control is Button:
		spoken_text = (control as Button).text.strip_edges()
	if spoken_text.is_empty():
		var child_label := control.find_child("Label", true, false) as Label
		if child_label != null:
			spoken_text = child_label.text.strip_edges()
	if spoken_text.is_empty() and "back" in control.name.to_lower():
		spoken_text = "VOLTAR"
	if spoken_text.is_empty():
		spoken_text = control.name.replace("_", " ").capitalize()

	LeitorDeTela._ler_texto(tr(spoken_text))


func _install_wasd_navigation() -> void:
	_add_key_to_action("ui_up", KEY_W)
	_add_key_to_action("ui_down", KEY_S)
	_add_key_to_action("ui_left", KEY_A)
	_add_key_to_action("ui_right", KEY_D)


func _is_navigation_event(event: InputEventKey) -> bool:
	return (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_accept")
	)


func _add_key_to_action(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	if not InputMap.action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)
