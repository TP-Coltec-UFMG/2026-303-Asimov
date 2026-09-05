class_name Scene_Maneger
extends Node

var player: Player
var last_scene_name: String
var tipo_sala_atual: int

var scene_dir_path := "res://Scenes/"


func change_scene(player_body: Player, to_scene_name: String) -> void:
	get_tree().paused = false

	# Guarda o tempo antes da troca de andar.
	SaveGame.capturar_tempo_atual()

	var current_scene := get_tree().current_scene
	SaveGame.capture_checkpoint_actors(current_scene)

	if current_scene != null:
		last_scene_name = current_scene.name

	player = player_body

	var camera: Camera2D = player.get_node_or_null(
		"Camera2D"
	) as Camera2D

	if camera != null:
		camera.enabled = false

	if player.get_parent() != null:
		player.get_parent().remove_child(player)

	var full_path := scene_dir_path + to_scene_name + ".tscn"

	get_tree().call_deferred(
		"change_scene_to_file",
		full_path
	)
