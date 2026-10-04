extends Button

@export_category("Animação")
@export var animar_hover: bool = true
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var duracao_hover: float = 0.1
@export var duracao_saida_hover: float = 0.1

@export_category("Press")
@export var escala_pressionado: Vector2 = Vector2(0.95, 0.95)
@export var duracao_pressao: float = 0.1
@export var duracao_retorno: float = 0.1

var transicao_botao: Tween
var escala_original: Vector2


func _ready() -> void:
	escala_original = scale


	atualizar_pivo()


func atualizar_pivo() -> void:
	pivot_offset = size / 2.0


func _ao_pressionar_botao() -> void:
	if transicao_botao:
		transicao_botao.kill()

	transicao_botao = create_tween().set_trans(Tween.TRANS_SINE)

	transicao_botao.tween_property(
		self,
		"scale",
		escala_original * escala_pressionado,
		duracao_pressao
	)

	transicao_botao.chain().tween_property(
		self,
		"scale",
		escala_original * escala_hover,
		duracao_retorno
	)


func _ao_destacar_botao() -> void:
	if not animar_hover:
		return
	if transicao_botao:
		transicao_botao.kill()

	transicao_botao = create_tween().set_trans(Tween.TRANS_SINE)

	transicao_botao.tween_property(
		self,
		"scale",
		escala_original * escala_hover,
		duracao_hover
	)


func _ao_remover_destaque_botao() -> void:
	if not animar_hover:
		return
	if transicao_botao:
		transicao_botao.kill()

	transicao_botao = create_tween().set_trans(Tween.TRANS_SINE)

	transicao_botao.tween_property(
		self,
		"scale",
		escala_original,
		duracao_saida_hover
	)
