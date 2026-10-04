extends Node2D


func _ready() -> void:
	$Animacao.play(&"disparo")
	$Animacao.advance(0.0)


func _ao_terminar_animacao(_nome: StringName) -> void:
	queue_free()
