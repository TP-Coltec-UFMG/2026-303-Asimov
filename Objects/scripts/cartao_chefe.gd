extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var tipo: int = 3
var player: Player = null


func set_player(novo_player: Player) -> void:
	player = novo_player
