extends Node

const FILE_PATH: String = "user://SaveFileConfigs.json"


var save_data: Dictionary = {
	"traducao": "PORTUGUÊS",
	"volume_geral": 1.0,
	"volume_musica": 0.1,
	"volume_sfx": 0.0,
	"tela_cheia" : false,
	"filtro_de_daltonismo" : 0,
	"intensidade_filtro_daltonismo" : 1.0,
	"frame_rate" : 0,
	"mostrar_fps" : false,
	"legenda_ativa" : false,
	"tamanho_legenda" : 10,
	"primeira_vez" : true,
	"leitor_de_tela" : false,
	"velocidade_leitor_de_tela" : 1.0,
	"volume_leitor": 1.0,
	"alto_contraste" : false,
	"cor_alto_contraste" : Color.YELLOW,
	"interface_size" : 0,
	"tutorial_seen" : false,
	"tutorial_completed" : false,
	"job": "",
	"character": "",
	"difficulty": ""
}

func _ready() -> void:
	_load()


func _save() -> void:
	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Não foi possível abrir o arquivo de configurações para escrita.")
		return
	file.store_var(save_data)
	file.close()


func _load() -> void:
	if FileAccess.file_exists(FILE_PATH):
		var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)
		if file == null:
			push_warning("Não foi possível abrir o arquivo de configurações para leitura.")
			return
		var data: Dictionary = file.get_var()
		for i in data:
			if save_data.has(i):
				save_data[i] = data[i]
		file.close()
		_apply_load()


func _apply_load() -> void:
	Configs.configs = save_data.duplicate(true)

	TranslationServer.set_locale(save_data.traducao)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(save_data.volume_geral)
	)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(save_data.volume_musica)
	)

	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("sfx"),
		linear_to_db(save_data.volume_sfx)
	)

	if save_data.tela_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	if is_instance_valid(FiltroDaltonismo):
		FiltroDaltonismo.call_deferred(
			"aplicar_filtro",
			save_data.filtro_de_daltonismo,
			save_data.intensidade_filtro_daltonismo
		)

	Engine.max_fps = save_data.frame_rate

	var contrast_color_value: Variant = save_data.get(
		"cor_alto_contraste",
		Color.YELLOW
	)
	var contrast_color: Color = Color.YELLOW

	if contrast_color_value is Color:
		contrast_color = contrast_color_value as Color
	else:
		contrast_color = Color.from_string(
			str(contrast_color_value),
			Color.YELLOW
		)

	contrast_color.a = 1.0
	save_data["cor_alto_contraste"] = contrast_color
	Configs.configs["cor_alto_contraste"] = contrast_color

	HighContrast.set_accent_color(contrast_color)
	HighContrast.set_enabled(save_data.alto_contraste)
