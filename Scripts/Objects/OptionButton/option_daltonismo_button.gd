extends OptionButton

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	selected = clampi(int(Configs.configs.get("filtro_de_daltonismo", 0)), 0, 3)
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)
