extends Node2D

@onready var assistencia_mira: CheckButton = $RemapPanel/Margin/ControlsScroll/Content/AssistenciaMira
@onready var painel_aviso: PanelContainer = $RemapPanel/ConflictWarning
@onready var texto_aviso: Label = $RemapPanel/ConflictWarning/Label

var transicao_aviso: Tween


func _ready() -> void:
	assistencia_mira.set_pressed_no_signal(bool(Configs.configs.get("assistencia_mira", false)))


func _ao_alternar_assistencia_mira(ativada: bool) -> void:
	Configs._change_assistencia_mira(ativada)
	SaveLoad._save()


func _mostrar_aviso_conflito(mensagem: String) -> void:
	if transicao_aviso != null and transicao_aviso.is_valid():
		transicao_aviso.kill()
	texto_aviso.text = mensagem
	painel_aviso.modulate.a = 1.0
	painel_aviso.show()
	transicao_aviso = create_tween()
	transicao_aviso.tween_interval(3.5)
	transicao_aviso.tween_property(painel_aviso, "modulate:a", 0.0, 0.45)
	transicao_aviso.tween_callback(painel_aviso.hide)
