extends OptionButton

const IDIOMAS: PackedStringArray = ["PORTUGUÊS", "ENGLISH", "ESPAÑOL", "FRANÇAIS"]

@export var pixel_font: FontFile
@export var pixel_font_size: int = 48


func _ready() -> void:
	_sincronizar_idioma()
	add_theme_font_override("font", pixel_font)
	add_theme_font_size_override("font_size", pixel_font_size)

	var popup: PopupMenu = get_popup()
	popup.add_theme_font_override("font", pixel_font)
	popup.add_theme_font_size_override("font_size", pixel_font_size)


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= IDIOMAS.size():
		return
	Configs._change_traducao(IDIOMAS[index])
	SaveLoad._save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sincronizar_idioma()


func _sincronizar_idioma() -> void:
	var idioma_atual := str(Configs.configs.get("traducao", "PORTUGUÊS"))
	select(maxi(IDIOMAS.find(idioma_atual), 0))
