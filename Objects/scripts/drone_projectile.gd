class_name DroneProjectile
extends Area2D

const SPEED: float = 145.0
const DAMAGE: float = 18.0

var direcao_movimento: Vector2 = Vector2.RIGHT
var velocidade_movimento: float = SPEED
var dano_impacto: float = DAMAGE


func configurar(direction: Vector2, speed: float = SPEED, damage: float = DAMAGE) -> void:
	direcao_movimento = direction.normalized()
	velocidade_movimento = speed
	dano_impacto = damage
	rotation = direcao_movimento.angle()


func _physics_process(delta: float) -> void:
	global_position += direcao_movimento * velocidade_movimento * delta


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).tomar_dano(dano_impacto)
	queue_free()
