extends CanvasLayer



func _ready() -> void:
	$"../UI/Transition".show()
	await get_tree().create_timer(0.5).timeout
	$"../UI/Transition".play_backwards("default")
	await $"../UI/Transition".animation_finished
	$"../UI/Transition".hide()
