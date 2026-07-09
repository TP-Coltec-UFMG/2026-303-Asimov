extends Node2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var interectable: Area2D = $Interectable

signal taked

var player: Player = null


func _ready() -> void:
	interectable.interact = _on_interact

func _on_interact():
	if self.visible:
		self.visible = false
		interectable.is_interactable = false
		emit_signal("taked")

func set_player(novo_player: Player) -> void:
	player = novo_player
