extends Node2D

@onready var energy: CharacterBody2D = $"../Energy"
@export var next_scene: PackedScene

func _on_area_2d_body_entered(body: Node2D) -> void:
	energy.queue_free()
	$AnimatedSprite2D.play("unlocking")
	
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_packed(next_scene)
