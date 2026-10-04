extends Node
class_name MenuInputRouter


enum InputMode {
	MOUSE,
	KEYBOARD,
}

const MOUSE_ICON: Texture2D = preload("res://Sprites/ui/InputMode/mouse.svg")
const KEYBOARD_ICON: Texture2D = preload("res://Sprites/ui/InputMode/keyboard.svg")
const INTERVALO_ATUALIZACAO: float = 0.25

@export var mostrar_indicador_entrada: bool = false
@export var anunciar_foco_teclado: bool = true
@export var cor_foco: Color = Color("ffd166")
@export_range(1, 6, 1) var largura_borda_foco: int = 1

var _modo_entrada: InputMode = InputMode.MOUSE
var _controles_observados: Array[Control] = []
var _botoes_remapeamento: Array[InputRemapButton] = []
var _atualizacao_pendente: bool = true
var _tempo_atualizacao: float = 0.0
var _menu_ativo: Node

@onready var _camada_indicador: CanvasLayer = $InputModeIndicatorLayer
@onready var _painel_indicador: PanelContainer = $InputModeIndicatorLayer/InputModeIndicator
@onready var _icone_indicador: TextureRect = $InputModeIndicatorLayer/InputModeIndicator/Icone

@export var _estilo_foco_teclado: StyleBoxFlat
@export var _estilo_foco_mouse: StyleBoxEmpty

var _retorno_bloqueado: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_preparar_estilos_foco()
	_instalar_navegacao_wasd()
	get_tree().node_added.connect(_ao_mudar_no_arvore)
	get_tree().node_removed.connect(_ao_mudar_no_arvore)

	await get_tree().process_frame
	_atualizar_controles()
	_aplicar_visual_entrada()


func _process(delta: float) -> void:
	var host_is_visible := _menu_visivel()
	if _camada_indicador != null:
		_camada_indicador.visible = mostrar_indicador_entrada and host_is_visible

	if not host_is_visible:
		return
	if _aguardando_remapeamento():
		return

	_tempo_atualizacao -= delta
	if _tempo_atualizacao <= 0.0:
		_tempo_atualizacao = INTERVALO_ATUALIZACAO
		_atualizar_controles()
		
		_atualizar_bordas_sliders()

	if not host_is_visible:
		return

func _preparar_borda_slider(slider: Slider) -> void:
	var outline := slider.get_node_or_null("KeyboardFocusOutline") as Panel
	if outline != null:
		outline.add_theme_stylebox_override("panel", _estilo_foco_teclado)


func _atualizar_borda_slider(_slider: Slider) -> void:
	call_deferred("_atualizar_bordas_sliders")

	var new_scope := _encontrar_menu_ativo()
	_configurar_navegacao_menu(new_scope)
	var focus_owner := get_viewport().gui_get_focus_owner()
	if new_scope != _menu_ativo or not _controle_disponivel(focus_owner, new_scope):
		_menu_ativo = new_scope
		if _modo_entrada == InputMode.KEYBOARD:
			_focar_primeiro_disponivel()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion

		if mouse_motion.relative.length_squared() > 0.0:
			_definir_modo_entrada(InputMode.MOUSE)

	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.pressed:
			_definir_modo_entrada(InputMode.MOUSE)

	elif event is InputEventKey:
		var key_event := event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		_definir_modo_entrada(InputMode.KEYBOARD)

		if key_event.keycode == KEY_ESCAPE:
			if _popup_visivel():
				return

			if _voltar_um_menu():
				get_viewport().set_input_as_handled()
				return

		var focus_owner := get_viewport().gui_get_focus_owner()
		var had_menu_focus := _controle_disponivel(
			focus_owner,
			_encontrar_menu_ativo()
		)

		if _menu_visivel() and not _aguardando_remapeamento():
			_focar_primeiro_disponivel()

			if not had_menu_focus and _evento_navegacao(key_event):
				get_viewport().set_input_as_handled()

func _voltar_um_menu() -> bool:
	if _retorno_bloqueado:
		return true

	var scope := _encontrar_menu_ativo()
	var host := get_parent()

	if scope == null or host == null:
		return false

	var method_name: StringName

	match scope.name:
		&"SettingSound":
			method_name = &"_ao_voltar_configuracoes_som"

		&"Interface":
			method_name = &"_ao_voltar_configuracoes_interface"

		&"Accessibility":
			method_name = &"_ao_voltar_acessibilidade"

		&"Controles":
			method_name = &"_ao_voltar_controles"

		&"Opcoes":
			method_name = &"_ao_voltar_menu"

		&"PrimeiraVez":
			method_name = &"_ao_voltar_primeira_vez"

		_:

			return false

	if not host.has_method(method_name):
		return false

	_retorno_bloqueado = true
	host.call(method_name)
	_liberar_retorno_menu()

	return true


func _liberar_retorno_menu() -> void:
	await get_tree().create_timer(0.5, true).timeout
	_retorno_bloqueado = false


func _definir_modo_entrada(new_mode: InputMode) -> void:
	if _modo_entrada == new_mode:
		return

	_modo_entrada = new_mode
	_aplicar_visual_entrada()

	if _modo_entrada == InputMode.KEYBOARD and _menu_visivel():
		var focus_owner := get_viewport().gui_get_focus_owner()
		_anunciar_controle_focado(focus_owner)


func _preparar_estilos_foco() -> void:
	_estilo_foco_teclado.bg_color = Color.TRANSPARENT
	_estilo_foco_teclado.border_color = cor_foco
	_estilo_foco_teclado.set_border_width_all(largura_borda_foco)
	_estilo_foco_teclado.set_corner_radius_all(3)

	_estilo_foco_teclado.expand_margin_left = 0.0
	_estilo_foco_teclado.expand_margin_top = 0.0
	_estilo_foco_teclado.expand_margin_right = 0.0
	_estilo_foco_teclado.expand_margin_bottom = 0.0



func _aplicar_visual_entrada() -> void:
	if _icone_indicador != null:
		if _modo_entrada == InputMode.KEYBOARD:
			_icone_indicador.texture = KEYBOARD_ICON
			_painel_indicador.accessibility_name = "Modo teclado"
		else:
			_icone_indicador.texture = MOUSE_ICON
			_painel_indicador.accessibility_name = "Modo mouse"
	@warning_ignore("incompatible_ternary")
	var focus_style: StyleBox = (
		_estilo_foco_teclado if _modo_entrada == InputMode.KEYBOARD else _estilo_foco_mouse
	)
	for control in _controles_observados:
		if is_instance_valid(control):     
			control.add_theme_stylebox_override("focus", focus_style)
	_atualizar_bordas_sliders()

func _atualizar_bordas_sliders() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()

	for control in _controles_observados:
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
			_modo_entrada == InputMode.KEYBOARD
			and slider == focus_owner
			and slider.is_visible_in_tree()
		)

func _ao_mudar_no_arvore(_node: Node) -> void:
	_atualizacao_pendente = true


func _atualizar_controles() -> void:

	if not _atualizacao_pendente:
		return
	_atualizacao_pendente = false
	var host := get_parent()
	if host == null:
		return
		
	@warning_ignore("incompatible_ternary")
	var focus_style: StyleBox = (
		_estilo_foco_teclado if _modo_entrada == InputMode.KEYBOARD else _estilo_foco_mouse
	)
	for node in host.find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control in _controles_observados:
			continue
		if _controle_do_indicador(control):
			continue

		_controles_observados.append(control)
		if control is InputRemapButton:
			_botoes_remapeamento.append(control as InputRemapButton)
		control.add_theme_stylebox_override("focus", focus_style)
		_desativar_escala_botao_voltar(control)
		if control is Slider:       
			_preparar_borda_slider(control as Slider)



func _ao_entrar_mouse_controle(control: Control) -> void:
	if _modo_entrada != InputMode.MOUSE or not _controle_disponivel(control, _encontrar_menu_ativo()):
		return
	var already_focused := control.has_focus()
	control.grab_focus()

	if control.has_method("_announce_selection"):
		if already_focused:
			control.call("_announce_selection")
		return
	if not _possui_evento_mouse_externo(control):
		_anunciar_controle_focado(control)


func _ao_receber_foco_controle(control: Control) -> void:
	if _modo_entrada == InputMode.KEYBOARD:
		_anunciar_controle_focado(control)


func _focar_primeiro_disponivel() -> void:
	if not _menu_visivel() or _popup_visivel() or _aguardando_remapeamento():
		return

	_menu_ativo = _encontrar_menu_ativo()
	if _menu_ativo == null:
		return
	_configurar_navegacao_menu(_menu_ativo)

	var current_focus := get_viewport().gui_get_focus_owner()
	if _controle_disponivel(current_focus, _menu_ativo):
		return

	for control in _coletar_controles_focaveis(_menu_ativo):
		control.grab_focus()
		return


func _encontrar_menu_ativo() -> Node:
	var host := get_parent()
	if host == null:
		return null

	var active_scope: Node = host
	for child in host.get_children():
		if child == self or not _no_visivel(child):
			continue
		if not _coletar_controles_focaveis(child).is_empty():
			active_scope = child

	return active_scope


func _coletar_controles_focaveis(scope: Node) -> Array[Control]:
	var controls: Array[Control] = []
	if scope is Control:
		var scope_control := scope as Control
		if _pode_receber_foco(scope_control):
			controls.append(scope_control)

	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		if control != null and _pode_receber_foco(control) and not _controle_do_indicador(control):
			controls.append(control)

	return controls


func _pode_receber_foco(control: Control) -> bool:
	if not is_instance_valid(control):
		return false
	if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree():
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true


func _controle_disponivel(control: Control, scope: Node) -> bool:
	if control == null or scope == null or not _pode_receber_foco(control):
		return false
	return control == scope or scope.is_ancestor_of(control)


func _menu_visivel() -> bool:
	var host := get_parent()
	if host is CanvasItem:
		return (host as CanvasItem).is_visible_in_tree()
	return host != null and host.is_inside_tree()


func _no_visivel(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).is_visible_in_tree()
	return node.is_inside_tree()


func _controle_do_indicador(control: Control) -> bool:
	return _painel_indicador != null and (
		control == _painel_indicador or _painel_indicador.is_ancestor_of(control)
	)


func _botao_voltar(control: Control) -> bool:
	var normalized_name := control.name.to_lower().replace("_", "")
	return "backtomenu" in normalized_name or normalized_name == "back"


func _configurar_navegacao_menu(scope: Node) -> void:
	if scope == null:
		return

	var controls := _coletar_controles_focaveis(scope)
	var first_content_control: Control
	var back_buttons: Array[Control] = []
	

	for control in controls:
		if _botao_voltar(control):
			back_buttons.append(control)
			@warning_ignore("unassigned_variable")
		elif first_content_control == null:
			first_content_control = control

	if first_content_control == null:
		return

	for back_button in back_buttons:

		var path_to_content := back_button.get_path_to(first_content_control)
		back_button.focus_neighbor_left = path_to_content
		back_button.focus_neighbor_right = path_to_content
		back_button.focus_neighbor_top = path_to_content
		back_button.focus_neighbor_bottom = path_to_content
		back_button.focus_next = path_to_content
		var path_to_back := first_content_control.get_path_to(back_button)
		first_content_control.focus_neighbor_top = path_to_back
		first_content_control.focus_previous = path_to_back
	_configurar_colunas_controles(scope)
	_configurar_grade_interface(scope)

func _definir_vizinho_foco(
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

func _desativar_escala_botao_voltar(control: Control) -> void:
	if not _botao_voltar(control):
		return

	for property in control.get_property_list():
		var property_name: StringName = property.get("name", &"")

		if property_name == &"escala_hover":
			control.set("escala_hover", Vector2.ONE)

		if property_name == &"escala_pressionado":
			control.set("escala_pressionado", Vector2(0.95, 0.95))

	control.scale = Vector2.ONE

	call_deferred("_manter_botao_voltar_na_tela", control)


func _manter_botao_voltar_na_tela(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return

	var viewport_rect := get_viewport().get_visible_rect()
	var button_rect := control.get_global_rect()

	var right_limit := viewport_rect.end.x - 6.0

	if button_rect.end.x > right_limit:
		var correction := button_rect.end.x - right_limit
		control.global_position.x -= correction

func _configurar_colunas_controles(scope: Node) -> void:
	if scope.name != &"Controles":
		return

	var columns_root := scope.get_node_or_null(
		"RemapPanel/Margin/ControlsScroll/Content/Columns"
	)

	if columns_root == null:
		return

	var control_columns: Array = []

	for group_panel: Node in columns_root.get_children():
		var column_controls: Array[Control] = []

		for control: Control in _coletar_controles_focaveis(group_panel):
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
				_definir_vizinho_foco(
					control,
					column_controls[row_index - 1] as Control,
					&"up"
				)

			if row_index < column_controls.size() - 1:
				_definir_vizinho_foco(
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
				_definir_vizinho_foco(
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
				_definir_vizinho_foco(
					control,
					right_column[right_row] as Control,
					&"right"
				)

	var back_button := scope.get_node_or_null(
		"BackToMenuButton"
	) as Control

	if back_button != null:
		for column_value: Variant in control_columns:
			var column_controls: Array = column_value

			if column_controls.is_empty():
				continue

			_definir_vizinho_foco(
				column_controls[0] as Control,
				back_button,
				&"up"
			)

func _configurar_grade_interface(scope: Node) -> void:
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

	_definir_vizinho_foco(
		full_screen,
		interface_size,
		&"right"
	)
	_definir_vizinho_foco(
		interface_size,
		full_screen,
		&"left"
	)

	_definir_vizinho_foco(
		show_fps,
		frame_rate,
		&"right"
	)
	_definir_vizinho_foco(
		frame_rate,
		show_fps,
		&"left"
	)

	_definir_vizinho_foco(
		full_screen,
		show_fps,
		&"down"
	)
	_definir_vizinho_foco(
		show_fps,
		full_screen,
		&"up"
	)

	_definir_vizinho_foco(
		interface_size,
		frame_rate,
		&"down"
	)
	_definir_vizinho_foco(
		frame_rate,
		interface_size,
		&"up"
	)

	if back_button != null:
		_definir_vizinho_foco(
			full_screen,
			back_button,
			&"up"
		)
		_definir_vizinho_foco(
			interface_size,
			back_button,
			&"up"
		)

func _popup_visivel() -> bool:
	for control in _controles_observados:
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


func _aguardando_remapeamento() -> bool:
	for control in _botoes_remapeamento:
		if is_instance_valid(control) and control is InputRemapButton:
			if (control as InputRemapButton).esperando_input:
				return true
	return false


func _possui_evento_mouse_externo(control: Control) -> bool:
	for connection in control.mouse_entered.get_connections():
		var callback: Callable = connection.get("callable", Callable())
		var receiver := callback.get_object()
		if receiver == null or receiver == self:
			continue

		if receiver == control and callback.get_method() == &"_ao_destacar_botao":
			continue
		return true
	return false


func _anunciar_controle_focado(control: Control) -> void:
	if not anunciar_foco_teclado or control == null:
		return
	if not bool(Configs.configs.get("leitor_de_tela", false)):
		return

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


func _instalar_navegacao_wasd() -> void:
	_adicionar_tecla_acao("ui_up", KEY_W)
	_adicionar_tecla_acao("ui_down", KEY_S)
	_adicionar_tecla_acao("ui_left", KEY_A)
	_adicionar_tecla_acao("ui_right", KEY_D)


func _evento_navegacao(event: InputEventKey) -> bool:
	return (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_left")
		or event.is_action_pressed("ui_right")
		or event.is_action_pressed("ui_accept")
	)


func _adicionar_tecla_acao(action: StringName, physical_keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = physical_keycode
	if not InputMap.action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)


func _ao_receber_foco(caminho: NodePath) -> void:
	var controle := get_parent().get_node_or_null(caminho) as Control
	if controle != null:
		_ao_receber_foco_controle(controle)
	_atualizar_borda_slider(null)


func _ao_entrar_mouse(caminho: NodePath) -> void:
	var controle := get_parent().get_node_or_null(caminho) as Control
	if controle != null:
		_ao_entrar_mouse_controle(controle)


func _ao_perder_foco() -> void:
	_atualizar_borda_slider(null)
