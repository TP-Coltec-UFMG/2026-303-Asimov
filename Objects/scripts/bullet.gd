extends CharacterBody2D

const SPEED: int = 1000
const DAMAGE: float = 25.0
const IMPACT_EFFECT := preload("res://Objects/bullet_impact.tscn")

var travel_direction: Vector2 = Vector2.RIGHT
var shooter: CollisionObject2D


func setup(direction: Vector2, source: CollisionObject2D = null) -> void:
	travel_direction = direction.normalized()
	shooter = source
	rotation = travel_direction.angle()
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)


func _physics_process(delta: float) -> void:
	var collision := move_and_collide(travel_direction * SPEED * delta)
	if collision != null:
		var collider: Object = collision.get_collider()
		var protected_npc := _find_protected_npc(collider as Node)
		if protected_npc != null:
			if is_instance_valid(shooter) and shooter.has_method("show_protected_npc_warning"):
				shooter.call("show_protected_npc_warning")
		elif collider != null and collider.has_method("receive_projectile_damage"):
			collider.call("receive_projectile_damage", DAMAGE)
		else:
			_spawn_impact(collision.get_position(), collision.get_normal())
		queue_free()
		return


func _spawn_impact(point: Vector2, normal: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var impact := IMPACT_EFFECT.instantiate() as Node2D
	scene.add_child(impact)
	impact.global_position = point + normal
	impact.rotation = normal.angle()


func _find_protected_npc(node: Node) -> Node:
	var current := node
	while current != null:
		if current.is_in_group(&"protected_npc"):
			return current
		current = current.get_parent()
	return null


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
