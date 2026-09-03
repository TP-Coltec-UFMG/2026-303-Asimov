extends Control

func _mudar_tamanho_preview_legenda(tamanho : int) -> void:
	if tamanho > $PreviewSubtitlles.get_theme_font_size("font_size"):
		$PreviewSubtitlles.add_theme_font_size_override("font_size", tamanho)
	else:
		$PreviewSubtitlles.remove_theme_font_size_override("font_size")
		$PreviewSubtitlles.add_theme_font_size_override("font_size", tamanho)

func _mudar_quantidade_px_legenda(px : int) -> void:
	$Label.text = str(px) + "px"
