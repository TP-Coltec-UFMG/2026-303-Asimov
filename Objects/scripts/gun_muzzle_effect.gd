extends Node2D


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
