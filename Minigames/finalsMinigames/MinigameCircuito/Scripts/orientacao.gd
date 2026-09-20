extends Panel


@onready var label: Label = $Label
@onready var botao: Button = $Button


@export var margem_horizontal: float = 30.0
@export var margem_vertical: float = 30.0
@export var espacamento: float = 15.0


func _ready() -> void:
	_atualizar_tamanho()


func _process(_delta: float) -> void:
	_atualizar_tamanho()


func _atualizar_tamanho() -> void:
	if label == null or botao == null:
		return


	# Tamanho mínimo da Label
	var tamanho_label := label.get_combined_minimum_size()


	# Começa usando apenas a Label
	var largura := tamanho_label.x
	var altura := tamanho_label.y


	# Se o botão estiver visível, adiciona o tamanho dele
	if botao.visible:
		var tamanho_botao := botao.get_combined_minimum_size()

		largura = max(largura, tamanho_botao.x)
		altura += espacamento + tamanho_botao.y


	# Adiciona as margens do Panel
	largura += margem_horizontal
	altura += margem_vertical


	# Aplica o novo tamanho
	size = Vector2(largura, altura)
