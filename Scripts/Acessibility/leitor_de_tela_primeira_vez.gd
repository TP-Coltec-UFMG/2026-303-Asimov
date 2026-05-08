extends CheckBox
@onready var velocidade: SpinBox = $Velocidade



func _ready() -> void:
	if Configs.configs.leitor_de_tela:
		button_pressed = true
		velocidade.value = Configs.configs.velocidade_leitor_de_tela
	else:
		button_pressed = false

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Configs._change_leitor_de_tela(true)
		velocidade.visible = true
		velocidade.value = Configs.configs.velocidade_leitor_de_tela
		if Configs.configs.leitor_de_tela and Configs.configs.primeira_vez:
			LeitorDeTela._ler_texto(atr("Leitor de Tela Ativado"))
	else:
		Configs._change_leitor_de_tela(false)
		velocidade.visible = false
		LeitorDeTela._ler_texto(atr("Leitor de Tela Desativado"))


func _on_velocidade_value_changed(value: float) -> void:
	Configs._change_velocidade_leitor_de_tela(value)
		
	if Configs.configs.leitor_de_tela:
		LeitorDeTela._ler_texto(atr(str(value) + "x"))


func _on_velocidade_mouse_entered() -> void:
	if Configs.configs.leitor_de_tela:
			LeitorDeTela._ler_texto(atr("Velocidade de Fala do Leitor de Tela"))
