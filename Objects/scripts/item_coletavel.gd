class_name ItemColetavel
extends Node2D

@export var save_id: String = ""
@export var tipo: int = 0

var no_inventario: bool = false
var jogador: Player
@onready var sprite_2d: Sprite2D = $Sprite2D


func _ready() -> void:
	if restaurar_coleta():
		return
	set_process(false)


func restaurar_coleta() -> bool:
	if not no_inventario and SaveGame.is_object_collected(save_id):
		queue_free()
		return true
	return false


func foi_coletado() -> void:
	SaveGame.set_object_collected(save_id)


func marcar_como_item_inventario() -> void:
	no_inventario = true


func definir_jogador(novo_jogador: Player) -> void:
	jogador = novo_jogador
