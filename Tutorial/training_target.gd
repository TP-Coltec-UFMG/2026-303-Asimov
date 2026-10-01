extends StaticBody2D

signal hit

var destroyed: bool = false
var hits: int = 0


func receive_projectile_damage(_damage: float) -> void:
	hits += 1
	$Sprite2D.modulate = Color(1.0, 0.35, 0.2)
	var tween := create_tween()
	tween.tween_property($Sprite2D, "modulate", Color.WHITE, 0.18)
	hit.emit()
