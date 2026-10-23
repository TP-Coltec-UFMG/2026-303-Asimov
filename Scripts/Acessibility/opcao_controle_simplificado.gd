extends CheckBox

@export var chave_configuracao: String = "corrida_automatica"
@export var padrao: bool = false

func _ready() -> void:
	set_pressed_no_signal(bool(Configs.configs.get(chave_configuracao, padrao)))

func _on_toggled(ativado: bool) -> void:
	Configs.configs[chave_configuracao] = ativado
	SaveLoad._save()
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(text + (" ativado" if ativado else " desativado"))

func _on_mouse_entered() -> void:
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(text)
