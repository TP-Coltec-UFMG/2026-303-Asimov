extends Node2D

var velocity: Vector2
var angular_speed: float
var lifetime: float = 2.2


func launch(shot_direction: Vector2) -> void:
	var side := shot_direction.orthogonal()
	velocity = side * randf_range(24.0, 38.0) - shot_direction * randf_range(2.0, 8.0)
	angular_speed = randf_range(-14.0, 14.0)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	rotation += angular_speed * delta
	velocity = velocity.move_toward(Vector2.ZERO, 80.0 * delta)
	angular_speed = move_toward(angular_speed, 0.0, 25.0 * delta)
	lifetime -= delta
	if lifetime <= 0.35:
		modulate.a = maxf(0.0, lifetime / 0.35)
	if lifetime <= 0.0:
		queue_free()
