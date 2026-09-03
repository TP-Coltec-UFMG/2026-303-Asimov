extends Node2D

var on = true

@export var angle = 0.0
@export var timeon = 1.0
@export var timeoff = 1.0

func _ready() -> void:
	rotation = deg_to_rad(angle)
	observe()

func observe():
	while true:
		if on:
			blink()
			await get_tree().create_timer(timeoff).timeout
			on = false
		else:
			blink()
			await get_tree().create_timer(timeon).timeout
			on = true

func blink():
	if on:
		$view.visible = false
		$eyeball.play("blink")
		await $eyeball.animation_finished
		$eyeball.play("off")
	else:
		$eyeball.play_backwards("blink")
		await $eyeball.animation_finished
		$view.visible = true
		$eyeball.play("on")
