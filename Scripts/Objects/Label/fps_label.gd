extends Label

@warning_ignore("unused_parameter")
func _process(delta: float) -> void:
	if Configs.configs.mostrar_fps:
		visible = true
		text = "FPS: %d" % Engine.get_frames_per_second()
	else:
		visible = false
