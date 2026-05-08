extends OptionButton

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	var interface_size = SaveLoad.save_data.interface_size
	if interface_size == 0:
		selected = 0
	elif interface_size == 1:
		selected = 1
	elif interface_size == 2:
		selected = 2
	else:	
		selected = 0
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)
