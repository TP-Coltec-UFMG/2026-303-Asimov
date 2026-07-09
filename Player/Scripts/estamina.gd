extends TextureProgressBar

@export var man_player: Player

func _process(_delta: float) -> void:
	value = 1 - man_player.cansaco
