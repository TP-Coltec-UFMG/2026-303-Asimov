extends Panel

@onready var label: Label = $Label
@onready var button: Button = $Button


func _ready() -> void:
	estilizar()
	ajustar_tamanho()


func _process(_delta: float) -> void:
	ajustar_tamanho()


func estilizar() -> void:

	var estilo_panel = StyleBoxFlat.new()
	estilo_panel.bg_color = Color(0, 0, 0, 0.55)

	estilo_panel.corner_radius_top_left = 12
	estilo_panel.corner_radius_top_right = 12
	estilo_panel.corner_radius_bottom_left = 12
	estilo_panel.corner_radius_bottom_right = 12

	estilo_panel.border_width_left = 2
	estilo_panel.border_width_right = 2
	estilo_panel.border_width_top = 2
	estilo_panel.border_width_bottom = 2
	estilo_panel.border_color = Color(1, 1, 1, 0.25)

	estilo_panel.shadow_color = Color(0, 0, 0, 0.3)
	estilo_panel.shadow_size = 6

	add_theme_stylebox_override("panel", estilo_panel)

	label.add_theme_color_override("font_color", Color(1, 1, 1))

	var estilo_button_normal = StyleBoxFlat.new()
	estilo_button_normal.bg_color = Color(0, 0, 0, 0.4)
	estilo_button_normal.corner_radius_top_left = 8
	estilo_button_normal.corner_radius_top_right = 8
	estilo_button_normal.corner_radius_bottom_left = 8
	estilo_button_normal.corner_radius_bottom_right = 8
	estilo_button_normal.border_width_left = 1
	estilo_button_normal.border_width_right = 1
	estilo_button_normal.border_width_top = 1
	estilo_button_normal.border_width_bottom = 1
	estilo_button_normal.border_color = Color(1, 1, 1, 0.3)
	estilo_button_normal.content_margin_left = 12
	estilo_button_normal.content_margin_right = 12
	estilo_button_normal.content_margin_top = 4
	estilo_button_normal.content_margin_bottom = 4

	var estilo_button_hover = estilo_button_normal.duplicate()
	estilo_button_hover.bg_color = Color(0, 0, 0, 0.55)
	estilo_button_hover.border_color = Color(1, 1, 1, 0.5)

	var estilo_button_pressed = estilo_button_normal.duplicate()
	estilo_button_pressed.bg_color = Color(0, 0, 0, 0.7)
	estilo_button_pressed.border_color = Color(1, 1, 1, 0.6)

	button.add_theme_stylebox_override("normal", estilo_button_normal)
	button.add_theme_stylebox_override("hover", estilo_button_hover)
	button.add_theme_stylebox_override("pressed", estilo_button_pressed)
	button.add_theme_stylebox_override("focus", estilo_button_hover)

	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	button.add_theme_color_override("font_focus_color", Color(1, 1, 1))


func ajustar_tamanho() -> void:

	var tamanho_label = label.get_combined_minimum_size()

	var botao_visivel = button.visible

	var tamanho_button = (
		button.get_combined_minimum_size()
		if botao_visivel
		else Vector2.ZERO
	)

	var margem_horizontal = 20.0
	var margem_vertical = 5.0
	var espacamento = (
		10.0
		if botao_visivel
		else 0.0
	)



	var largura = (
		tamanho_label.x
		+ espacamento
		+ tamanho_button.x
		+ margem_horizontal * 2
	)

	var altura = max(
		tamanho_label.y,
		tamanho_button.y
	) + margem_vertical * 2


	size = Vector2(largura, altura)



	label.size = tamanho_label

	label.position = Vector2(
		margem_horizontal,
		margem_vertical
	)



	if botao_visivel:

		button.size = tamanho_button

		button.position = Vector2(
			margem_horizontal
			+ tamanho_label.x
			+ espacamento,

			margem_vertical
			+ (tamanho_label.y - tamanho_button.y) / 2
		)
