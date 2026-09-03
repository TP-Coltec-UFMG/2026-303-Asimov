extends OptionButton

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	var idioma_atual : String = SaveLoad.save_data.traducao
	var index_idioma_atual : int
	if idioma_atual == "PORTUGUÊSE":
		index_idioma_atual = 0
	elif idioma_atual == "ENGLISH":
		index_idioma_atual = 1
	elif idioma_atual == "ESPAÑOL":
		index_idioma_atual = 2
	elif idioma_atual == "FRANÇAIS":
		index_idioma_atual = 3
	
	selected = index_idioma_atual
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)


func _on_item_selected(index: int) -> void:
	var new_language : String = get_item_text(index)
	Configs._change_traducao(new_language)
	TranslationServer.set_locale(new_language)
