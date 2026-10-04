extends Node2D

var velocidade: Vector2
var velocidade_angular: float
var tempo_restante: float = 2.2


func lancar(direcao_tiro: Vector2) -> void:
	var lado := direcao_tiro.orthogonal()
	velocidade = lado * randf_range(24.0, 38.0) - direcao_tiro * randf_range(2.0, 8.0)
	velocidade_angular = randf_range(-14.0, 14.0)


func _physics_process(delta: float) -> void:
	position += velocidade * delta
	rotation += velocidade_angular * delta
	velocidade = velocidade.move_toward(Vector2.ZERO, 80.0 * delta)
	velocidade_angular = move_toward(velocidade_angular, 0.0, 25.0 * delta)
	tempo_restante -= delta
	if tempo_restante <= 0.35:
		modulate.a = maxf(0.0, tempo_restante / 0.35)
	if tempo_restante <= 0.0:
		queue_free()
