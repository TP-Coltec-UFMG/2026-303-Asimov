extends MarginContainer

signal dialog_finished()
signal line_started(index: int)

var textos: Array[String] = []
var indice_atual: int = 0
@export_range(0.01, 0.2, 0.01) var intervalo_digitacao: float = 0.05
var digitando: bool = false
var fechando: bool = false
var em_uso: bool = false

@onready var texto: Label = $text_container/text_label
@onready var indicador: TextureRect = $indicator
@onready var temporizador_digitacao: Timer = $TemporizadorDigitacao
@onready var animacoes: AnimationPlayer = $Animacoes


func _ready() -> void:
	hide()
	indicador.hide()


func iniciar_exibicao() -> void:
	cancelar_exibicao()
	em_uso = true
	pivot_offset = size / 2.0
	show()
	animacoes.play(&"abrir")
	animacoes.advance(0.0)
	mostrar_texto()


func mostrar_texto() -> void:
	if indice_atual >= textos.size():
		_fechar_dialogo()
		return
	line_started.emit(indice_atual)
	digitando = true
	indicador.hide()
	texto.text = textos[indice_atual]
	texto.visible_characters = 0
	temporizador_digitacao.start(intervalo_digitacao)


func _ao_digitar_caractere() -> void:
	texto.visible_characters += 1
	if texto.visible_characters >= texto.text.length():
		_concluir_digitacao()


func _concluir_digitacao() -> void:
	temporizador_digitacao.stop()
	texto.visible_characters = -1
	digitando = false
	indicador.show()


func _fechar_dialogo() -> void:
	if fechando:
		return
	fechando = true
	digitando = true
	temporizador_digitacao.stop()
	animacoes.play(&"fechar")
	animacoes.advance(0.0)


func _ao_terminar_animacao(nome: StringName) -> void:
	if nome != &"fechar":
		return
	cancelar_exibicao()
	dialog_finished.emit()


func avancar() -> void:
	if fechando:
		return
	if digitando:
		_concluir_digitacao()
	elif indice_atual + 1 < textos.size():
		indice_atual += 1
		mostrar_texto()
	else:
		_fechar_dialogo()


func cancelar_exibicao() -> void:
	temporizador_digitacao.stop()
	animacoes.stop()
	fechando = false
	digitando = false
	em_uso = false
	indicador.hide()
	hide()
