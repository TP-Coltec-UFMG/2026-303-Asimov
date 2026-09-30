extends Panel



@onready var label: Label = $Label

const MARGEM_HORIZONTAL: float = 20.0
const MARGEM_VERTICAL: float = 5.0


func _ready() -> void:
	estilizar()
	ajustar_tamanho()


func _process(_delta: float) -> void:
	ajustar_tamanho()


func estilizar() -> void:

	var estilo_panel := StyleBoxFlat.new()
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


func ajustar_tamanho() -> void:

	var escala: Vector2 = label.scale

	var tamanho_label: Vector2 = label.get_combined_minimum_size() * escala

	var margem := Vector2(
		MARGEM_HORIZONTAL * escala.x,
		MARGEM_VERTICAL * escala.y
	)

	size = tamanho_label + margem * 2.0

	label.position = margem
	
