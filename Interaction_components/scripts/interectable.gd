extends Area2D

@export var interact_name: String = ""
@export_range(1, 64) var prompt_font_size: int = 12
@export var is_interactable: bool = true
@export var is_not_object: bool = false

signal interacao_solicitada

var interact: Callable


func interagir() -> void:
	if not is_interactable:
		return
	if interact.is_valid():
		await interact.call()
	else:
		interacao_solicitada.emit()
