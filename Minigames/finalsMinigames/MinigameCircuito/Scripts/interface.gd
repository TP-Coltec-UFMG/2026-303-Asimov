extends CanvasLayer


@onready var texto_objetivo: Label = get_node("../../Fundo_preto_tutorial/Panel/Label2")

@onready var tela_game_over: Control = $GameOver
@onready var tela_game_win: Control = $GameWin



var comecar_jogo: bool = false
var jogo_iniciado: bool = false



enum Objetivo {
	BATERIA,
	RESISTOR,
	LED,
	BATERIA_LED,
	BATERIA_RESISTOR,
	RESISTOR_LED
}


var objetivo_atual: Objetivo



var objetivo_concluido: bool = false
var jogo_terminado: bool = false
var game_over_ativo: bool = false



func _ready() -> void:

	var circuito = get_parent()

	if circuito == null:
		return



	tela_game_over.visible = false
	tela_game_win.visible = false



	comecar_jogo = circuito.tutorial_ativado


	if comecar_jogo:


		texto_objetivo.text = "Objetivo: Terminar o Tutorial"

		pass
		pass
		pass
		pass

		return



	iniciar_jogo()



func _process(_delta: float) -> void:

	var circuito = get_parent()

	if circuito == null:
		return



	comecar_jogo = circuito.tutorial_ativado



	if comecar_jogo:


		if not jogo_iniciado:
			texto_objetivo.text = "Objetivo: Terminar o Tutorial"

		return



	if not jogo_iniciado:

		iniciar_jogo()

		return



	if jogo_terminado:
		return



	verificar_objetivo()



func iniciar_jogo() -> void:

	if jogo_iniciado:
		return


	jogo_iniciado = true
	comecar_jogo = false



	objetivo_concluido = false
	jogo_terminado = false
	game_over_ativo = false



	tela_game_over.visible = false
	tela_game_win.visible = false



	escolher_objetivo_aleatorio()


	pass
	pass
	pass
	pass



func escolher_objetivo_aleatorio() -> void:

	var objetivos: Array[Objetivo] = [
		Objetivo.BATERIA,
		Objetivo.RESISTOR,
		Objetivo.LED,
		Objetivo.BATERIA_LED,
		Objetivo.BATERIA_RESISTOR,
		Objetivo.RESISTOR_LED
	]


	var escolhido: Objetivo = objetivos.pick_random()

	definir_objetivo(escolhido)



func definir_objetivo(novo_objetivo: Objetivo) -> void:

	objetivo_atual = novo_objetivo


	match objetivo_atual:

		Objetivo.BATERIA:

			texto_objetivo.text = "Objetivo:\nQueime a bateria."


		Objetivo.RESISTOR:

			texto_objetivo.text = "Objetivo:\nQueime o resistor."


		Objetivo.LED:

			texto_objetivo.text = "Objetivo:\nQueime o componente."


		Objetivo.BATERIA_LED:

			texto_objetivo.text = "Objetivo:\nQueime o componente\ne depois a bateria."


		Objetivo.BATERIA_RESISTOR:

			texto_objetivo.text = "Objetivo:\nQueime o resistor\ne depois a bateria."


		Objetivo.RESISTOR_LED:

			texto_objetivo.text = "Objetivo:\nQueimar resistor\n e componente"



func verificar_objetivo() -> void:

	if jogo_terminado:
		return



	var circuito = get_parent()


	if circuito == null:
		return



	if objetivo_atual == Objetivo.BATERIA:

		if circuito.bateria_queimada:

			vitoria()

			return



	if objetivo_atual == Objetivo.RESISTOR:

		if circuito.resistor_queimado:

			vitoria()

			return



	if objetivo_atual == Objetivo.LED:

		if circuito.led_queimado:

			vitoria()

			return



	if objetivo_atual == Objetivo.BATERIA_LED:

		if circuito.bateria_queimada and circuito.led_queimado:

			vitoria()

			return
		elif circuito.bateria_queimada and not circuito.led_queimando:
			game_over()
			return



	if objetivo_atual == Objetivo.BATERIA_RESISTOR:

		if circuito.bateria_queimada and circuito.resistor_queimado:

			vitoria()

			return
		elif circuito.bateria_queimada and not circuito.resistor_queimando:
			game_over()
			return



	if objetivo_atual == Objetivo.RESISTOR_LED:

		if circuito.resistor_queimado and circuito.led_queimado:

			vitoria()

			return



func vitoria() -> void:
	if jogo_terminado:
		return

	jogo_terminado = true

	var espera_resultado := create_tween()
	espera_resultado.tween_interval(2.0)
	await espera_resultado.finished

	pass


	objetivo_concluido = true



	pass
	pass
	pass
	pass


	tela_game_win.visible = true
	var minigame := get_parent().get_parent()
	if minigame != null and minigame.has_method("notificar_vitoria"):
		minigame.notificar_vitoria()



func game_over() -> void:

	if game_over_ativo:
		return


	game_over_ativo = true
	jogo_terminado = true


	pass
	pass
	pass
	pass



	tela_game_over.visible = true
	var minigame := get_parent().get_parent()
	if minigame != null and minigame.has_method("notificar_derrota"):
		minigame.notificar_derrota()
