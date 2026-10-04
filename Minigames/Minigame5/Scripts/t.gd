extends Panel

@onready var label: Label = $Label
@onready var button: Button = $Button

func _ready() -> void:
	ajustar_tamanho()

func _process(_delta: float) -> void:
	ajustar_tamanho()

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
