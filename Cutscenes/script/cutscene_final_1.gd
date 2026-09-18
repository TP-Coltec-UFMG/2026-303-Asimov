extends VideoStreamPlayer


func _ready() -> void:
	self.play()


func _on_finished() -> void:
	SaveLoad._save()
	SaveGame.clear_save()
	MusicController.stop_all_audio()
	get_tree().change_scene_to_file("res://Scenes/principal.tscn")
