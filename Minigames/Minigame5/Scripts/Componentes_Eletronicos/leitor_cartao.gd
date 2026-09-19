extends Area2D

signal cartao_alterado(presente: bool)
signal acesso_liberado

const ID_CARTAO = preload("res://Minigames/Minigame5/Scripts/id_cartao.gd")
const MSG_SEM_REGISTRO: String = "Cartão sem registro"
const MSG_ID_INCORRETO: String = "ID incorreto"
const MSG_ACESSO_INSUFICIENTE: String = "Acesso insuficiente"
const MSG_ACESSO_LIBERADO: String = "Acesso liberado"

var senha: int = ID_CARTAO.VALOR
var cartao_em_cima: bool = false
var verificando_cartao: bool = false
var porta_aberta: bool = false
var _cartao_atual: Area2D
var _gerente: Node

@onready var painel_mensagem: Panel = $Panel
@onready var label_mensagem: Label = $Panel/Label
@onready var porta: AnimatedSprite2D = get_tree().get_first_node_in_group("porta")


func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_limpar_mensagem()
	call_deferred("_obter_gerente")


func _obter_gerente() -> void:
	_gerente = get_tree().get_first_node_in_group("tutorial_manager")


func _on_area_entered(area: Area2D) -> void:
	if not can_process() or not is_visible_in_tree() or not area.is_in_group("cartao"):
		return
	if area.voltando:
		return
	if not _tutorial_permite_cartao():
		_recusar_cartao(area)
		return
	_cartao_atual = area
	_definir_presenca(true)
	if not verificando_cartao:
		verificar_cartao(area)


func _on_area_exited(area: Area2D) -> void:
	if area == _cartao_atual:
		retirar_cartao()


func _definir_presenca(presente: bool) -> void:
	if cartao_em_cima == presente:
		return
	cartao_em_cima = presente
	cartao_alterado.emit(presente)


func retirar_cartao() -> void:
	_cartao_atual = null
	_definir_presenca(false)
	_limpar_mensagem()


func _mostrar_mensagem(texto: String) -> void:
	label_mensagem.text = texto
	painel_mensagem.show()


func _limpar_mensagem() -> void:
	label_mensagem.text = ""
	painel_mensagem.hide()


func _tutorial_permite_cartao() -> bool:
	return _gerente == null or _gerente.pode_colocar_cartao()


func _recusar_cartao(cartao: Area2D) -> void:
	cartao.voltar_para_posicao_inicial()
	if _gerente != null:
		_gerente.mostrar_ainda_nao()


func verificar_cartao(cartao: Area2D) -> void:
	if verificando_cartao or not is_instance_valid(cartao) or not is_visible_in_tree():
		return
	verificando_cartao = true
	if cartao.id != senha:
		_mostrar_mensagem(MSG_SEM_REGISTRO if cartao.id == 0 else MSG_ID_INCORRETO)
		verificando_cartao = false
		return
	if cartao.acesso != "FORTE":
		_mostrar_mensagem(MSG_ACESSO_INSUFICIENTE)
		verificando_cartao = false
		return

	_mostrar_mensagem(MSG_ACESSO_LIBERADO)
	await get_tree().physics_frame
	if not is_instance_valid(cartao) or _cartao_atual != cartao or not overlaps_area(cartao) or not is_visible_in_tree():
		verificando_cartao = false
		return

	# Reinserções após o sucesso não reiniciam a animação da porta.
	if is_instance_valid(porta) and not porta_aberta:
		porta_aberta = true
		porta.play("abrir")
		await porta.animation_finished
		porta.play("aberta")
	verificando_cartao = false
	acesso_liberado.emit()
