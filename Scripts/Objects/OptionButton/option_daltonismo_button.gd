extends OptionButton

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	selected = SaveLoad.save_data.filtro_de_daltonismo
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)
