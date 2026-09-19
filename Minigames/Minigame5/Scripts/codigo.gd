extends Node2D

const IdentidadeCartao = preload("res://Minigames/Minigame5/Scripts/id_cartao.gd")

enum EstadoRevelacao { REVELANDO, COMPLETO }

var senha: String = IdentidadeCartao.formatar(IdentidadeCartao.VALOR)
var indice_senha: int = 0
var estado: EstadoRevelacao = EstadoRevelacao.REVELANDO
var pontos: Array[String] = [".", "..", "..."]
var indice_pontos: int = 0

var timer_senha: Timer
var timer_pontos: Timer

@onready var notebook: Node2D = get_parent()
@onready var label_id: Label = $Label
@onready var label_estado: Label = $Label2
@onready var label_pontos: Label = $Label3
@onready var botao_copiar: Button = $Button
@onready var cartao: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	# O Label contém apenas o trecho já revelado, nunca o ID completo oculto.
	botao_copiar.disabled = true
	label_id.text = ""
	label_estado.text = "Obtendo ID"
	label_pontos.text = "."

	timer_senha = Timer.new()
	timer_senha.wait_time = 1.0
	add_child(timer_senha)
	timer_senha.timeout.connect(_escrever_senha)

	timer_pontos = Timer.new()
	timer_pontos.wait_time = 1.0
	add_child(timer_pontos)
	timer_pontos.timeout.connect(_atualizar_pontos)

	visibility_changed.connect(_sincronizar_visibilidade)


func _pode_revelar() -> bool:
	return (
		is_visible_in_tree()
		and notebook.iniciar
		and notebook.pode_escrever
		and not notebook.acabou
	)


func _escrever_senha() -> void:
	if not _pode_revelar() or estado == EstadoRevelacao.COMPLETO:
		return

	if indice_senha < senha.length():
		label_id.text += senha[indice_senha]
		indice_senha += 1

	# A liberação ocorre na mesma atualização que revela o último caractere.
	if indice_senha == senha.length():
		_hacking_concluido()


func _atualizar_pontos() -> void:
	if not _pode_revelar() or estado == EstadoRevelacao.COMPLETO:
		return

	label_pontos.text = pontos[indice_pontos]
	indice_pontos = (indice_pontos + 1) % pontos.size()


func _hacking_concluido() -> void:
	if not _pode_revelar() or indice_senha != senha.length() or label_id.text != senha:
		return

	estado = EstadoRevelacao.COMPLETO
	timer_senha.stop()
	timer_pontos.stop()
	label_estado.text = "Concluído"
	cartao.play("concluido")
	label_pontos.text = ""
	botao_copiar.disabled = not pode_copiar()


func pode_copiar() -> bool:
	return (
		_pode_revelar()
		and estado == EstadoRevelacao.COMPLETO
		and indice_senha == senha.length()
		and label_id.text == senha
		and label_id.is_visible_in_tree()
		and (label_id.visible_characters < 0 or label_id.visible_characters >= senha.length())
	)


func _on_button_pressed() -> void:
	# Protege também sinais enfileirados e ativações por teclado.
	if not pode_copiar():
		return

	DisplayServer.clipboard_set(label_id.text)

	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if gerente_tutorial != null and gerente_tutorial.etapa_tutorial == 4:
		gerente_tutorial.mostrar_etapa_tutorial(5)


func pausar_escrita() -> void:
	# Pausar preserva o intervalo restante, inclusive ao alternar abas rapidamente.
	botao_copiar.disabled = true
	timer_senha.paused = true
	timer_pontos.paused = true


func retomar_escrita() -> void:
	if not _pode_revelar():
		pausar_escrita()
		return

	botao_copiar.disabled = not pode_copiar()
	if estado == EstadoRevelacao.COMPLETO:
		return

	timer_senha.paused = false
	timer_pontos.paused = false
	if timer_senha.is_stopped():
		timer_senha.start()
	if timer_pontos.is_stopped():
		timer_pontos.start()


func reiniciar_escrita() -> void:
	# Revoga a cópia antes de alterar qualquer parte da revelação.
	botao_copiar.disabled = true
	estado = EstadoRevelacao.REVELANDO
	indice_senha = 0
	indice_pontos = 0
	timer_senha.stop()
	timer_pontos.stop()
	label_id.text = ""
	label_estado.text = "Hackeando"
	label_pontos.text = "."
	cartao.play("default")
	retomar_escrita()


func _sincronizar_visibilidade() -> void:
	retomar_escrita()
