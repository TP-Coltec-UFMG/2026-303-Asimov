extends Panel

@onready var label: Label = $Label

const MARGEM_HORIZONTAL: float = 20.0
const MARGEM_VERTICAL: float = 5.0

func _ready() -> void:
	ajustar_tamanho()

func _process(_delta: float) -> void:
	ajustar_tamanho()

func ajustar_tamanho() -> void:

	var escala: Vector2 = label.scale

	var tamanho_label: Vector2 = label.get_combined_minimum_size() * escala

	var margem := Vector2(
		MARGEM_HORIZONTAL * escala.x,
		MARGEM_VERTICAL * escala.y
	)

	size = tamanho_label + margem * 2.0

	label.position = margem
	
