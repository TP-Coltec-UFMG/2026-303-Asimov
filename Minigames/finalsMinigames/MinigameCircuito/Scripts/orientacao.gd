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


	var tamanho_label := label.get_combined_minimum_size()


	var largura := tamanho_label.x
	var altura := tamanho_label.y


	if botao.visible:
		var tamanho_botao := botao.get_combined_minimum_size()

		largura = max(largura, tamanho_botao.x)
		altura += espacamento + tamanho_botao.y


	largura += margem_horizontal
	altura += margem_vertical


	size = Vector2(largura, altura)
