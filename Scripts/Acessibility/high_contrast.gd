extends Node

const DEFAULT_ACCENT_COLOR: Color = Color.YELLOW
const BLACK: Color = Color.BLACK
const WHITE: Color = Color.WHITE

const CONTRAST_GROUP: StringName = &"alto_contraste"
const META_BACKUP: StringName = &"high_contrast_backup"
const META_LABEL_BACKUP: StringName = &"high_contrast_label_backup"

var enabled: bool = false
var accent_color: Color = DEFAULT_ACCENT_COLOR


func set_accent_color(value: Color) -> void:
	var opaque_color := Color(value.r, value.g, value.b, 1.0)

	if accent_color.is_equal_approx(opaque_color):
		return

	accent_color = opaque_color

	if enabled:
		call_deferred("_apply_current_scene")


func get_accent_color() -> Color:
	return accent_color


func set_enabled(value: bool) -> void:
	enabled = value

	call_deferred("_apply_current_scene")


func _apply_current_scene() -> void:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	apply_to_tree(current_scene)


func apply_to_tree(root: Node) -> void:
	if root == null:
		return

	if not is_instance_valid(root):
		return

	_apply_node(root)

	for child in root.get_children():
		apply_to_tree(child)


func _apply_node(node: Node) -> void:
	if not node.is_in_group(CONTRAST_GROUP):
		return

	if not enabled:
		_remove_node(node)
		return

	if node.name == "ALTO_CONTRASTE":
		if node is CanvasItem:
			var canvas_item := node as CanvasItem
			canvas_item.self_modulate = BLACK
			canvas_item.visible = true

	if node is Button:
		_apply_button(node as Button)

	elif node is Label:
		_apply_label(node as Label)


func _apply_label(label: Label) -> void:
	_save_original_label_theme(label)

	label.add_theme_color_override(
		"font_color",
		accent_color
	)
	label.add_theme_color_override(
		"font_outline_color",
		_get_neutral_background()
	)
	label.add_theme_constant_override(
		"outline_size",
		2
	)


func _apply_button(button: Button) -> void:
	_save_original_button_theme(button)
	var neutral_background := _get_neutral_background()

	# Todos os textos dos botões usam a cor escolhida.
	button.add_theme_color_override(
		"font_color",
		accent_color
	)

	button.add_theme_color_override(
		"font_hover_color",
		accent_color
	)

	button.add_theme_color_override(
		"font_pressed_color",
		accent_color
	)

	button.add_theme_color_override(
		"font_hover_pressed_color",
		accent_color
	)

	button.add_theme_color_override(
		"font_focus_color",
		accent_color
	)

	# Botões flat continuam sem caixa.
	if button.flat:
		button.add_theme_color_override(
			"font_outline_color",
			neutral_background
		)
		button.add_theme_constant_override(
			"outline_size",
			2
		)
		return

	var original_normal: StyleBox = _get_saved_stylebox(
		button,
		"normal"
	)

	var original_hover: StyleBox = _get_saved_stylebox(
		button,
		"hover"
	)

	var original_pressed: StyleBox = _get_saved_stylebox(
		button,
		"pressed"
	)

	var original_focus: StyleBox = _get_saved_stylebox(
		button,
		"focus"
	)
	var neutral_foreground := _get_neutral_foreground()

	# NORMAL
	# Fundo neutro de maior contraste + borda colorida.
	var normal_style: StyleBoxFlat = _make_stylebox(
		neutral_background,
		accent_color,
		2,
		original_normal
	)

	# HOVER
	# Fundo neutro + borda neutra oposta.
	var hover_style: StyleBoxFlat = _make_stylebox(
		neutral_background,
		neutral_foreground,
		2,
		original_hover
	)

	# PRESSIONADO
	# Fundo neutro + borda colorida mais grossa.
	var pressed_style: StyleBoxFlat = _make_stylebox(
		neutral_background,
		accent_color,
		3,
		original_pressed
	)

	# FOCO
	# Fundo neutro + borda neutra oposta.
	var focus_style: StyleBoxFlat = _make_stylebox(
		neutral_background,
		neutral_foreground,
		2,
		original_focus
	)

	button.add_theme_stylebox_override(
		"normal",
		normal_style
	)

	button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)

	button.add_theme_stylebox_override(
		"focus",
		focus_style
	)


func _remove_node(node: Node) -> void:
	if node.name == "ALTO_CONTRASTE":
		if node is CanvasItem:
			(node as CanvasItem).visible = false

	if node is Button:
		var button: Button = node as Button

		_restore_original_button_theme(button)

	elif node is Label:
		var label: Label = node as Label
		_restore_original_label_theme(label)


func _save_original_button_theme(button: Button) -> void:
	if button.has_meta(META_BACKUP):
		return

	var backup: Dictionary = {}

	backup["font_color"] = {
		"has_override": button.has_theme_color_override(
			"font_color"
		),
		"value": button.get_theme_color(
			"font_color"
		)
	}

	backup["font_hover_color"] = {
		"has_override": button.has_theme_color_override(
			"font_hover_color"
		),
		"value": button.get_theme_color(
			"font_hover_color"
		)
	}

	backup["font_pressed_color"] = {
		"has_override": button.has_theme_color_override(
			"font_pressed_color"
		),
		"value": button.get_theme_color(
			"font_pressed_color"
		)
	}

	backup["font_hover_pressed_color"] = {
		"has_override": button.has_theme_color_override(
			"font_hover_pressed_color"
		),
		"value": button.get_theme_color(
			"font_hover_pressed_color"
		)
	}

	backup["font_focus_color"] = {
		"has_override": button.has_theme_color_override(
			"font_focus_color"
		),
		"value": button.get_theme_color(
			"font_focus_color"
		)
	}

	backup["font_outline_color"] = {
		"has_override": button.has_theme_color_override(
			"font_outline_color"
		),
		"value": button.get_theme_color(
			"font_outline_color"
		)
	}

	backup["outline_size"] = {
		"has_override": button.has_theme_constant_override(
			"outline_size"
		),
		"value": button.get_theme_constant(
			"outline_size"
		)
	}

	backup["normal"] = _create_style_backup(
		button,
		"normal"
	)

	backup["hover"] = _create_style_backup(
		button,
		"hover"
	)

	backup["pressed"] = _create_style_backup(
		button,
		"pressed"
	)

	backup["focus"] = _create_style_backup(
		button,
		"focus"
	)

	button.set_meta(
		META_BACKUP,
		backup
	)


func _save_original_label_theme(label: Label) -> void:
	if label.has_meta(META_LABEL_BACKUP):
		return

	var backup: Dictionary = {
		"font_color": {
			"has_override": label.has_theme_color_override("font_color"),
			"value": label.get_theme_color("font_color")
		},
		"font_outline_color": {
			"has_override": label.has_theme_color_override(
				"font_outline_color"
			),
			"value": label.get_theme_color("font_outline_color")
		},
		"outline_size": {
			"has_override": label.has_theme_constant_override("outline_size"),
			"value": label.get_theme_constant("outline_size")
		}
	}

	label.set_meta(META_LABEL_BACKUP, backup)


func _restore_original_label_theme(label: Label) -> void:
	if not label.has_meta(META_LABEL_BACKUP):
		label.remove_theme_color_override("font_color")
		label.remove_theme_color_override("font_outline_color")
		label.remove_theme_constant_override("outline_size")
		return

	var backup: Dictionary = label.get_meta(META_LABEL_BACKUP)
	_restore_color(label, backup, "font_color")
	_restore_color(label, backup, "font_outline_color")
	_restore_constant(label, backup, "outline_size")
	label.remove_meta(META_LABEL_BACKUP)


func _create_style_backup(
	button: Button,
	style_name: StringName
) -> Dictionary:
	var original_style: StyleBox = button.get_theme_stylebox(
		style_name
	)

	var copied_style: StyleBox = null

	if original_style != null:
		copied_style = original_style.duplicate(true) as StyleBox

	return {
		"has_override": button.has_theme_stylebox_override(
			style_name
		),
		"value": copied_style
	}


func _get_saved_stylebox(
	button: Button,
	style_name: StringName
) -> StyleBox:
	if not button.has_meta(META_BACKUP):
		return button.get_theme_stylebox(style_name)

	var backup: Dictionary = button.get_meta(
		META_BACKUP
	)

	if not backup.has(style_name):
		return button.get_theme_stylebox(style_name)

	var style_data: Dictionary = backup[style_name]

	return style_data.get("value") as StyleBox


func _restore_original_button_theme(button: Button) -> void:
	if not button.has_meta(META_BACKUP):
		_remove_button_overrides(button)
		return

	var backup: Dictionary = button.get_meta(
		META_BACKUP
	)

	_restore_color(
		button,
		backup,
		"font_color"
	)

	_restore_color(
		button,
		backup,
		"font_hover_color"
	)

	_restore_color(
		button,
		backup,
		"font_pressed_color"
	)

	_restore_color(
		button,
		backup,
		"font_hover_pressed_color"
	)

	_restore_color(
		button,
		backup,
		"font_focus_color"
	)

	_restore_color(
		button,
		backup,
		"font_outline_color"
	)

	_restore_constant(
		button,
		backup,
		"outline_size"
	)

	_restore_style(
		button,
		backup,
		"normal"
	)

	_restore_style(
		button,
		backup,
		"hover"
	)

	_restore_style(
		button,
		backup,
		"pressed"
	)

	_restore_style(
		button,
		backup,
		"focus"
	)

	button.remove_meta(META_BACKUP)


func _restore_color(
	control: Control,
	backup: Dictionary,
	color_name: StringName
) -> void:
	control.remove_theme_color_override(
		color_name
	)

	if not backup.has(color_name):
		return

	var color_data: Dictionary = backup[color_name]

	if bool(color_data.get("has_override", false)):
		var original_color: Color = color_data.get(
			"value",
			WHITE
		)

		control.add_theme_color_override(
			color_name,
			original_color
		)


func _restore_constant(
	control: Control,
	backup: Dictionary,
	constant_name: StringName
) -> void:
	control.remove_theme_constant_override(constant_name)

	if not backup.has(constant_name):
		return

	var constant_data: Dictionary = backup[constant_name]

	if bool(constant_data.get("has_override", false)):
		control.add_theme_constant_override(
			constant_name,
			int(constant_data.get("value", 0))
		)


func _restore_style(
	button: Button,
	backup: Dictionary,
	style_name: StringName
) -> void:
	button.remove_theme_stylebox_override(
		style_name
	)

	if not backup.has(style_name):
		return

	var style_data: Dictionary = backup[style_name]

	if bool(style_data.get("has_override", false)):
		var original_style: StyleBox = style_data.get(
			"value"
		) as StyleBox

		if original_style != null:
			button.add_theme_stylebox_override(
				style_name,
				original_style
			)


func _remove_button_overrides(button: Button) -> void:
	button.remove_theme_color_override(
		"font_color"
	)

	button.remove_theme_color_override(
		"font_hover_color"
	)

	button.remove_theme_color_override(
		"font_pressed_color"
	)

	button.remove_theme_color_override(
		"font_hover_pressed_color"
	)

	button.remove_theme_color_override(
		"font_focus_color"
	)

	button.remove_theme_color_override(
		"font_outline_color"
	)

	button.remove_theme_constant_override(
		"outline_size"
	)

	button.remove_theme_stylebox_override(
		"normal"
	)

	button.remove_theme_stylebox_override(
		"hover"
	)

	button.remove_theme_stylebox_override(
		"pressed"
	)

	button.remove_theme_stylebox_override(
		"focus"
	)


func _make_stylebox(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	original_style: StyleBox
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = bg_color
	style.border_color = border_color

	style.set_border_width_all(
		border_width
	)

	# SEM CANTOS ARREDONDADOS.
	style.set_corner_radius_all(
		0
	)

	# Mantém o espaço interno original do botão,
	# evitando mudança de tamanho/deslocamento.
	if original_style != null:
		style.set_content_margin(
			SIDE_LEFT,
			original_style.get_margin(SIDE_LEFT)
		)

		style.set_content_margin(
			SIDE_TOP,
			original_style.get_margin(SIDE_TOP)
		)

		style.set_content_margin(
			SIDE_RIGHT,
			original_style.get_margin(SIDE_RIGHT)
		)

		style.set_content_margin(
			SIDE_BOTTOM,
			original_style.get_margin(SIDE_BOTTOM)
		)

	return style


func _get_neutral_background() -> Color:
	# Escolhe automaticamente o fundo neutro que oferece maior contraste
	# com a cor selecionada pelo jogador.
	return BLACK if accent_color.get_luminance() >= 0.179 else WHITE


func _get_neutral_foreground() -> Color:
	return WHITE if _get_neutral_background() == BLACK else BLACK
