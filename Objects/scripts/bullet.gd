extends CharacterBody2D

const SPEED: int = 1000
const DAMAGE: float = 25.0
const IMPACT_EFFECT := preload("res://Objects/bullet_impact.tscn")

var direcao_movimento: Vector2 = Vector2.RIGHT
var atirador: CollisionObject2D


func configurar(direction: Vector2, source: CollisionObject2D = null) -> void:
	direcao_movimento = direction.normalized()
	atirador = source
	rotation = direcao_movimento.angle()
	if is_instance_valid(atirador):
		add_collision_exception_with(atirador)


func _physics_process(delta: float) -> void:
	var collision := move_and_collide(direcao_movimento * SPEED * delta)
	if collision != null:
		var collider: Object = collision.get_collider()
		var protected_npc := _encontrar_npc_protegido(collider as Node)
		if protected_npc != null:
			if is_instance_valid(atirador) and atirador.has_method("show_protected_npc_warning"):
				atirador.call("show_protected_npc_warning")
		elif collider != null and collider.has_method("receber_dano_projetil"):
			collider.call("receber_dano_projetil", DAMAGE)
		else:
			_criar_impacto(collision.get_position(), collision.get_normal())
		queue_free()
		return


func _criar_impacto(point: Vector2, normal: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var impact := IMPACT_EFFECT.instantiate() as Node2D
	scene.add_child(impact)
	impact.global_position = point + normal
	impact.rotation = normal.angle()


func _encontrar_npc_protegido(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(&"protected_npc"):
			return current
		current = current.get_parent()
	return null


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
