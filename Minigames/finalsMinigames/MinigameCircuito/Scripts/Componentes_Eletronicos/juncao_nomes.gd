extends Node2D

# Recurso próprio do minigame de circuito; não compartilha UID com outros minigames.


# Called when the node enters the scene tree for the first time.
@export var nome: String =  "juncao"

func _get_nome():
	return nome
