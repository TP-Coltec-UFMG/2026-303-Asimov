extends Control

@onready var preview_tamanho: Label = $PreviewTamanho
@onready var preview_subtitlles: Label = $PreviewSubtitlles
@onready var tamanho: SpinBox = $Tamanho


func _ready() -> void:
	aplicar_tamanho_legenda.call_deferred()


func aplicar_tamanho_legenda() -> void:
	if not is_node_ready():
		return
	var fator := Configs.obter_fator_legendas()
	tamanho.set_value_no_signal(roundi(fator * 100.0))
	preview_tamanho.text = "%d%%" % roundi(fator * 100.0)
	if is_equal_approx(fator, 1.0):
		preview_tamanho.text += " (padrão)"
	preview_subtitlles.add_theme_font_size_override("font_size", roundi(10.0 * fator))


func _on_tamanho_value_changed(value: float) -> void:
	Configs._change_tamanho_legenda(roundi(value / 10.0))
	SaveLoad._save()
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto("Tamanho das legendas: %d por cento" % roundi(value))
