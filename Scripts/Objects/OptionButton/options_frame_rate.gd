extends OptionButton

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	var frame_rate = SaveLoad.save_data.frame_rate
	if frame_rate == 0:
		selected = 3
	elif frame_rate == 30:
		selected = 0
	elif frame_rate == 60:
		selected = 1
	else:	
		selected = 2
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)
