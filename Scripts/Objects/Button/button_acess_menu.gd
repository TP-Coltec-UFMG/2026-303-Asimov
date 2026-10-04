extends "res://Scripts/Objects/Button/animated_button.gd"
class_name AnimatedButton

func _ready() -> void:
	animar_hover = false
	super._ready()

func atualizar_pivo() -> void:
	pivot_offset = size / 2.0

func _ao_pressionar_botao() -> void:
	if transicao_botao:
		transicao_botao.kill()
	transicao_botao = create_tween().set_trans(Tween.TRANS_SINE)
	transicao_botao.tween_property(self, "scale", escala_pressionado, duracao_pressao)
	transicao_botao.chain().tween_property(self, "scale", escala_hover, duracao_retorno)
