extends Node2D

@export var scene_trigger : SceneTrigger

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func escolher_andar(andar: int) -> void:
	visible = false
	get_tree().paused = false
	scene_trigger.usar_elevador(andar)

func _on_andar_1_pressed() -> void:
	#escolher_andar(1)
	pass

func _on_andar_2_pressed() -> void:
	#escolher_andar(2)
	pass

func _on_andar_3_pressed() -> void:
	escolher_andar(3)
	pass

func _on_andar_4_pressed() -> void:
	escolher_andar(4)

func _on_andar_5_pressed() -> void:
	#escolher_andar(5)
	pass

func _on_andar_6_pressed() -> void:
	escolher_andar(6)
	pass
	
func _on_fechar_pressed() -> void:
	visible = false
	get_tree().paused = false
