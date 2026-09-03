extends Node2D

@onready var hack: CharacterBody2D = $"../Hack"
@export var next_scene: PackedScene

var hacked = false

func _on_area_2d_body_entered(body: Node2D) -> void:
	hack.queue_free()

	await get_tree().create_timer(0.1).timeout
	$systemarea.play("hacked")

	await $systemarea.animation_finished
	hacked = true

	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_packed(next_scene)

func _process(delta: float) -> void:
	if not hacked:
		$engrenagem.rotation += 2.0 * delta
		$engrenagem2.rotation -= 2.0 * delta
