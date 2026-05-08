extends Node2D

func _iniciar() -> void:
	
	var idioma: String = OS.get_locale_language()
	var new_language
	if idioma == "pt":
		print("dgsahujdgajhsd")
		new_language = "PORTUGUÊS"
	elif idioma == "en":
		new_language = "ENGLISH"
	elif idioma == "es":
		new_language = "ESPAÑOL"
	elif idioma == "fr":
		new_language = "FRANÇAIS"
	else:
		new_language = "ENGLISH"
		
	Configs._change_traducao(new_language)
	TranslationServer.set_locale(new_language)
	SaveLoad._save()
	
	if Configs.configs.primeira_vez:
		LeitorDeTela._ler_texto(atr("Bem Vindo, o leitor de tela pode ser ativado"))
		
	pass 


func _on_back_to_menu_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("VOLTAR"))


func _on_option_language_button_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr("Idioma"))


func _on_leitor_de_tela_mouse_entered() -> void:
	if Configs.configs.primeira_vez:
		LeitorDeTela._ler_texto(atr("Leitor de Tela"))
