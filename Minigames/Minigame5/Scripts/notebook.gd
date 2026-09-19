extends Node2D

signal fechou
signal dados_atualizados(dados: Dictionary)

const IdentidadeCartao = preload("res://Minigames/Minigame5/Scripts/id_cartao.gd")

@onready var codigo: Node2D = $Codigo
@onready var banco_de_dados: Node2D = $Banco_de_Dados
@onready var id: LineEdit = $Banco_de_Dados/id

@export var iniciar: bool = false
var acabou: bool = false
var pode_escrever: bool = false
var id_foi_alterado: bool = false

var dados_alterados: Dictionary = {
	"id": "",
	"acesso": "FORTE"
}


func _ready() -> void:
	codigo.show()
	banco_de_dados.hide()
	dados_alterados["id"] = id.text
	dados_alterados["acesso"] = "FORTE"
	id_foi_alterado = not id.text.is_empty()
	if not id.text_changed.is_connected(_id_alterado):
		id.text_changed.connect(_id_alterado)


func abrir() -> void:
	if iniciar and is_visible_in_tree():
		return

	acabou = false
	iniciar = true
	pode_escrever = true
	show()
	codigo.retomar_escrita()
	if banco_de_dados.visible:
		_verificar_id_alterado()


func fechar(reiniciar: bool = false) -> void:
	if not iniciar:
		return

	# O estado deixa de aceitar interações antes de ocultar a janela.
	iniciar = false
	pode_escrever = false
	acabou = true
	codigo.pausar_escrita()
	_liberar_foco()
	hide()

	if reiniciar:
		codigo.reiniciar_escrita()
		banco_de_dados.hide()
		codigo.show()

	_avancar_tutorial_ao_fechar_janela()
	fechou.emit()


func _esta_aberto() -> bool:
	return iniciar and not acabou and is_visible_in_tree()


func _on_button_2_pressed() -> void:
	if not _esta_aberto():
		return

	_liberar_foco()
	codigo.pausar_escrita()
	codigo.hide()
	banco_de_dados.show()

	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if gerente_tutorial != null and gerente_tutorial.etapa_tutorial == 5:
		gerente_tutorial.mostrar_etapa_tutorial(6)

	# Também cobre um campo já preenchido antes de entrar nesta etapa.
	_verificar_id_alterado()


func _id_alterado(novo_texto: String) -> void:
	if not _esta_aberto() or not banco_de_dados.visible:
		return

	dados_alterados["id"] = novo_texto
	id_foi_alterado = not novo_texto.is_empty()
	dados_atualizados.emit(dados_alterados.duplicate())
	_verificar_id_alterado()


func _verificar_id_alterado() -> void:
	if not _esta_aberto() or not banco_de_dados.visible or not id_foi_alterado:
		return

	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if (
		gerente_tutorial != null
		and gerente_tutorial.etapa_tutorial == 6
		and IdentidadeCartao.interpretar(str(dados_alterados["id"])) == IdentidadeCartao.VALOR
	):
		gerente_tutorial.mostrar_etapa_tutorial(7)


func _on_button_3_pressed() -> void:
	fechar()


func _on_button_4_pressed() -> void:
	if not _esta_aberto():
		return

	_liberar_foco()
	banco_de_dados.hide()
	codigo.show()
	codigo.retomar_escrita()


func _on_button_5_pressed() -> void:
	# O X reinicia apenas a extração; o banco conserva os dados digitados.
	fechar(true)


func _liberar_foco() -> void:
	var controle := get_viewport().gui_get_focus_owner()
	if controle != null and is_ancestor_of(controle):
		controle.release_focus()


func _avancar_tutorial_ao_fechar_janela() -> void:
	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if gerente_tutorial != null and gerente_tutorial.etapa_tutorial == 7:
		gerente_tutorial.mostrar_etapa_tutorial(8)
