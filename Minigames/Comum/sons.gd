class_name SonsAsimov
extends Node

func tocar(nome: String) -> void:
	if not Progresso.som_ativo:
		return
	var audio := get_node_or_null(NodePath(nome)) as AudioStreamPlayer
	if audio != null:
		audio.play()
