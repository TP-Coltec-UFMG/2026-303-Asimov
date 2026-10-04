extends Node2D

signal fechou
signal dados_atualizados(dados: Dictionary)

const IdentidadeCartao = preload("res://Minigames/Minigame5/Scripts/id_cartao.gd")

const DIR_SPRITES := "res://Minigames/Minigame5/Sprites/"
const SPRITE_ABA_BANCO_PT := DIR_SPRITES + "aba_banco_de_dados.png"
const SPRITE_ABA_BANCO_EN := DIR_SPRITES + "aba_banco_de_dados_en.png"
const SPRITE_ABA_CODIGO_PT := DIR_SPRITES + "aba_codigo_do_cartao.png"
const SPRITE_ABA_CODIGO_EN := DIR_SPRITES + "aba_codigo_do_cartao_en.png"
const SPRITE_TABELA_PT := DIR_SPRITES + "tabela_banco_dados.png"
const SPRITE_TABELA_EN := DIR_SPRITES + "tabela_banco_dados_en.png"

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
	_aplicar_traducao()
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
	_aplicar_traducao()
	GameAudio.tocar_interface(self, GameAudio.TECLA_TERMINAL, -13.0)

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


func _em_ingles() -> bool:
	return Configs.configs.get("traducao") == "ENGLISH"


func _aplicar_traducao() -> void:
	var ingles := _em_ingles()
	var icone_banco: Texture2D = load(SPRITE_ABA_BANCO_EN if ingles else SPRITE_ABA_BANCO_PT)
	var icone_codigo: Texture2D = load(SPRITE_ABA_CODIGO_EN if ingles else SPRITE_ABA_CODIGO_PT)
	var textura_tabela: Texture2D = load(SPRITE_TABELA_EN if ingles else SPRITE_TABELA_PT)

	# Abas "Banco de Dados" (Button2) e "Código do Cartão" (Button4) nas duas telas
	$Codigo/Button2.icon = icone_banco
	$Codigo/Button4.icon = icone_codigo
	$Banco_de_Dados/Button2.icon = icone_banco
	$Banco_de_Dados/Button4.icon = icone_codigo

	# Tabela do banco de dados ("Nível de Acesso")
	$Banco_de_Dados/Sprite2D.texture = textura_tabela


func _esta_aberto() -> bool:
	return iniciar and not acabou and is_visible_in_tree()


func _on_button_2_pressed() -> void:
	if not _esta_aberto():
		return
	GameAudio.tocar_interface(self, GameAudio.TECLA_TERMINAL, -16.0)

	_liberar_foco()
	codigo.pausar_escrita()
	codigo.hide()
	banco_de_dados.show()

	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if gerente_tutorial != null and gerente_tutorial.etapa_tutorial == 5:
		gerente_tutorial.mostrar_etapa_tutorial(6)

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

	fechar(true)


func _liberar_foco() -> void:
	var controle := get_viewport().gui_get_focus_owner()
	if controle != null and is_ancestor_of(controle):
		controle.release_focus()


func _avancar_tutorial_ao_fechar_janela() -> void:
	var gerente_tutorial := get_tree().get_first_node_in_group("tutorial_manager")
	if gerente_tutorial != null and gerente_tutorial.etapa_tutorial == 7:
		gerente_tutorial.mostrar_etapa_tutorial(8)
