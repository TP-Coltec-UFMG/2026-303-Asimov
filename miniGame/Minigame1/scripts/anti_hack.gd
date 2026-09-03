extends Node2D

@export var angle1: float = 90.0
@export var angle2: float = 180.0
@export var wait_time: float = 1.0
@export var speed: float = 1.0

func _ready() -> void:
	rotation = deg_to_rad(angle1)
	observe()

func observe():
	while true:
		await rotate_to(angle2)

		await get_tree().create_timer(wait_time).timeout

		await rotate_to(angle1)

		await get_tree().create_timer(wait_time).timeout

func rotate_to(target_angle: float):
	var current = rotation
	var target = deg_to_rad(target_angle)

	target = current + wrapf(target - current, -PI, PI)

	var tween = create_tween()
	tween.tween_property(self, "rotation", target, speed)

	await tween.finished
