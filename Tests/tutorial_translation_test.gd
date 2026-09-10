extends SceneTree

const LOCALES := ["PORTUGUÊS", "ENGLISH", "ESPAÑOL", "FRANÇAIS"]
const TUTORIAL_SCRIPT := "res://Tutorial/tutorial.gd"


func _initialize() -> void:
	var file := FileAccess.open(TUTORIAL_SCRIPT, FileAccess.READ)
	if file == null:
		_fail("Não foi possível ler o script do tutorial.")
		return
	var source := file.get_as_text()
	var regex := RegEx.new()
	regex.compile('tr\\("([A-Z0-9_]+)"\\)')
	var keys: Array[String] = []
	for result in regex.search_all(source):
		var key := result.get_string(1)
		if not keys.has(key):
			keys.append(key)
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for key in keys:
			var translated := TranslationServer.translate(key)
			if translated == key or translated.is_empty():
				_fail("Tradução ausente em %s: %s" % [locale, key])
				return
	print("TUTORIAL_TRANSLATIONS_OK: %d chaves x %d idiomas" % [keys.size(), LOCALES.size()])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
