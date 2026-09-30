extends Node2D

signal conexao_alterada(conectado: bool)

@export var nome: String = "juncao"
@export var conectado1: bool = false


func _get_nome() -> String:
	return nome


func definir_conectado(conectado: bool) -> void:
	if conectado1 == conectado:
		return
	conectado1 = conectado
	conexao_alterada.emit(conectado)
