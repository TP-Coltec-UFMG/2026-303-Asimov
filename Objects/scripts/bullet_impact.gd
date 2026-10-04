extends Node2D


func _ready() -> void:
	$ImpactSfx.pitch_scale = randf_range(0.94, 1.08)
	$ImpactSfx.play()
	$Animacao.play(&"impacto")
	$Animacao.advance(0.0)


func _ao_terminar_animacao(_nome: StringName) -> void:
	queue_free()
