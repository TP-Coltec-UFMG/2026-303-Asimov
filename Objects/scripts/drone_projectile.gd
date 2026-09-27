class_name DroneProjectile
extends Area2D

const SPEED: float = 145.0
const DAMAGE: float = 18.0
const LIFETIME: float = 2.4

var travel_direction: Vector2 = Vector2.RIGHT
var lifetime_remaining: float = LIFETIME


func setup(direction: Vector2) -> void:
	travel_direction = direction.normalized()
	rotation = travel_direction.angle()


func _physics_process(delta: float) -> void:
	global_position += travel_direction * SPEED * delta
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).tomar_dano(DAMAGE)
	queue_free()
