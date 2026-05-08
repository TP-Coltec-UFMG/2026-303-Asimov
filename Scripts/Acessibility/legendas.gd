extends CheckBox
@onready var back: Sprite2D = $Back
@onready var preview_tamanho: Label = $PreviewTamanho
@onready var preview_subtitlles: Label = $PreviewSubtitlles
@onready var tamanho: SpinBox = $Tamanho


func _ready() -> void:
	if Configs.configs.legenda_ativa:
		button_pressed = true
		tamanho.value = Configs.configs.tamanho_legenda
		preview_tamanho.text = str(Configs.configs.tamanho_legenda) + "px"
		preview_subtitlles.add_theme_font_size_override("font_size", Configs.configs.tamanho_legenda)
	else:
		button_pressed = false

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Configs._change_legenda_ativa(true)
		tamanho.visible = true
		back.visible = true
		preview_subtitlles.visible = true
		preview_tamanho.visible = true
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Legendas ativada"))
	else:
		Configs._change_legenda_ativa(false)
		tamanho.visible = false
		back.visible = false
		preview_subtitlles.visible = false
		preview_tamanho.visible = false
		if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Legendas desativada"))


func _on_tamanho_value_changed(value: int) -> void:
	Configs._change_tamanho_legenda(value)
	preview_tamanho.text = str(value) + "px"
	
	if value > preview_subtitlles.get_theme_font_size("font_size"):
		preview_subtitlles.add_theme_font_size_override("font_size", value)
	else:
		preview_subtitlles.remove_theme_font_size_override("font_size")
		preview_subtitlles.add_theme_font_size_override("font_size", value)
		
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value)))
