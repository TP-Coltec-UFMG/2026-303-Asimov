extends Node
	
func _ler_texto(text : String, pinch : float = 1.0) -> void:
	var idioma = Configs.configs.traducao
	var voices
	
	if idioma == "PORTUGUÊS":
		voices = DisplayServer.tts_get_voices_for_language("pt")
	elif idioma == "ENGLISH":
		voices = DisplayServer.tts_get_voices_for_language("en")
	elif idioma == "ESPAÑOL":
		voices = DisplayServer.tts_get_voices_for_language("es")
	elif idioma == "FRANÇAIS":
		voices = DisplayServer.tts_get_voices_for_language("fr")
	
	if voices == null or voices.is_empty():
		return

	var voz = voices[0]

	if voz == null:
		return

	DisplayServer.tts_stop()
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voz,int(Configs.configs.volume_leitor * 100), pinch, Configs.configs.velocidade_leitor_de_tela)
