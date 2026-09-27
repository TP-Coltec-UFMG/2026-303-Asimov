extends Node2D


func _ready() -> void:
	$ImpactSfx.pitch_scale = randf_range(0.94, 1.08)
	$ImpactSfx.play()
	await get_tree().create_timer(1.4).timeout
	var tween := create_tween()
	tween.tween_property($Mark, "modulate:a", 0.0, 0.8)
	await tween.finished
	queue_free()
