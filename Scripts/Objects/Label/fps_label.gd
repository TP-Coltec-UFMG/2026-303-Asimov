extends Label

var ultimo_fps: int = -1

func _process(_delta: float) -> void:
	visible = Configs.configs.mostrar_fps
	if not is_visible_in_tree():
		return

	var fps: int = Engine.get_frames_per_second()
	if fps != ultimo_fps:
		ultimo_fps = fps
		text = "FPS: %d" % fps
