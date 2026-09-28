class_name DroneProjectile
extends Area2D

const SPEED: float = 145.0
const DAMAGE: float = 18.0
const LIFETIME: float = 2.4

var travel_direction: Vector2 = Vector2.RIGHT
var lifetime_remaining: float = LIFETIME
var travel_speed: float = SPEED
var hit_damage: float = DAMAGE


func setup(direction: Vector2, speed: float = SPEED, damage: float = DAMAGE) -> void:
	travel_direction = direction.normalized()
	travel_speed = speed
	hit_damage = damage
	rotation = travel_direction.angle()


func _physics_process(delta: float) -> void:
	global_position += travel_direction * travel_speed * delta
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).tomar_dano(hit_damage)
	queue_free()
