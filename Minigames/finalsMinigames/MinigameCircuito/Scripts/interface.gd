extends CanvasLayer

# ==========================================
# REFERÊNCIAS DA INTERFACE
# ==========================================

@onready var texto_objetivo: Label = get_tree().get_first_node_in_group("objetivo")

@onready var tela_game_over: Control = $GameOver
@onready var tela_game_win: Control = $GameWin


# ==========================================
# ESTADO DO JOGO
# ==========================================

var comecar_jogo: bool = false
var jogo_iniciado: bool = false


# ==========================================
# OBJETIVOS
# ==========================================

enum Objetivo {
	BATERIA,
	RESISTOR,
	LED,
	BATERIA_LED,
	BATERIA_RESISTOR,
	RESISTOR_LED
}


var objetivo_atual: Objetivo


# ==========================================
# ESTADO DO JOGO
# ==========================================

var objetivo_concluido: bool = false
var jogo_terminado: bool = false
var game_over_ativo: bool = false


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	var circuito = get_parent()

	if circuito == null:
		return


	# ==========================================
	# ESCONDER TELAS DE RESULTADO
	# ==========================================

	tela_game_over.visible = false
	tela_game_win.visible = false


	# ==========================================
	# VERIFICAR SE O TUTORIAL ESTÁ ATIVO
	# ==========================================

	comecar_jogo = circuito.tutorial_ativado


	if comecar_jogo:

		# ==========================================
		# DURANTE O TUTORIAL
		# ==========================================

		texto_objetivo.text = "Objetivo: Terminar o Tutorial"

		print("")
		print("========================================")
		print("             TUTORIAL ATIVO")
		print("========================================")

		return


	# ==========================================
	# TUTORIAL JÁ TERMINOU
	# ==========================================

	iniciar_jogo()


# ==========================================
# PROCESSO
# ==========================================

func _process(_delta: float) -> void:

	var circuito = get_parent()

	if circuito == null:
		return


	# ==========================================
	# ATUALIZAR ESTADO DO TUTORIAL
	# ==========================================

	comecar_jogo = circuito.tutorial_ativado


	# ==========================================
	# TUTORIAL ATIVO
	# ==========================================

	if comecar_jogo:

		# Garante que o objetivo do tutorial
		# continue aparecendo.

		if not jogo_iniciado:
			texto_objetivo.text = "Objetivo: Terminar o Tutorial"

		return


	# ==========================================
	# TUTORIAL TERMINOU
	# ==========================================

	if not jogo_iniciado:

		iniciar_jogo()

		return


	# ==========================================
	# SE O JOGO ACABOU
	# ==========================================

	if jogo_terminado:
		return


	# ==========================================
	# VERIFICAR OBJETIVO
	# ==========================================

	verificar_objetivo()


# ==========================================
# INICIAR JOGO
# ==========================================

func iniciar_jogo() -> void:

	if jogo_iniciado:
		return


	jogo_iniciado = true
	comecar_jogo = false


	# ==========================================
	# RESETAR ESTADOS
	# ==========================================

	objetivo_concluido = false
	jogo_terminado = false
	game_over_ativo = false


	# ==========================================
	# ESCONDER TELAS
	# ==========================================

	tela_game_over.visible = false
	tela_game_win.visible = false


	# ==========================================
	# ESCOLHER OBJETIVO
	# ==========================================

	escolher_objetivo_aleatorio()


	print("")
	print("========================================")
	print("              JOGO INICIADO")
	print("========================================")


# ==========================================
# ESCOLHER OBJETIVO ALEATÓRIO
# ==========================================

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


# ==========================================
# DEFINIR OBJETIVO
# ==========================================

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

			texto_objetivo.text = "Objetivo:\nQueime a bateria e o LED."


		Objetivo.BATERIA_RESISTOR:

			texto_objetivo.text = "Objetivo: Queime a bateria e o resistor."


		Objetivo.RESISTOR_LED:

			texto_objetivo.text = "Objetivo:\nQueimar resistor\n e componente"


# ==========================================
# VERIFICAR OBJETIVO
# ==========================================

func verificar_objetivo() -> void:

	if jogo_terminado:
		return


	# O pai do CanvasLayer é o Circuito.

	var circuito = get_parent()


	if circuito == null:
		return


	# ==========================================
	# BATERIA
	# ==========================================

	if objetivo_atual == Objetivo.BATERIA:

		if circuito.bateria_queimada:

			vitoria()

			return


	# ==========================================
	# RESISTOR
	# ==========================================

	if objetivo_atual == Objetivo.RESISTOR:

		if circuito.resistor_queimado:

			vitoria()

			return


	# ==========================================
	# LED
	# ==========================================

	if objetivo_atual == Objetivo.LED:

		if circuito.led_queimado:

			vitoria()

			return


	# ==========================================
	# BATERIA + LED
	# ==========================================

	if objetivo_atual == Objetivo.BATERIA_LED:

		if circuito.bateria_queimada and circuito.led_queimado:

			vitoria()

			return


	# ==========================================
	# BATERIA + RESISTOR
	# ==========================================

	if objetivo_atual == Objetivo.BATERIA_RESISTOR:

		if circuito.bateria_queimada and circuito.resistor_queimado:

			vitoria()

			return


	# ==========================================
	# RESISTOR + LED
	# ==========================================

	if objetivo_atual == Objetivo.RESISTOR_LED:

		if circuito.resistor_queimado and circuito.led_queimado:

			vitoria()

			return


# ==========================================
# VITÓRIA
# ==========================================

func vitoria() -> void:
	if jogo_terminado:
		return

	jogo_terminado = true

	await get_tree().create_timer(2.0).timeout

	print("chamei vitoria")


	objetivo_concluido = true


	# ==========================================
	# MOSTRAR VITÓRIA
	# ==========================================

	print("")
	print("========================================")
	print("           OBJETIVO CONCLUÍDO!")
	print("========================================")


	tela_game_win.visible = true
	var minigame := get_parent().get_parent()
	if minigame != null and minigame.has_method("notificar_vitoria"):
		minigame.notificar_vitoria()


# ==========================================
# GAME OVER
# ==========================================

func game_over() -> void:

	if game_over_ativo:
		return


	game_over_ativo = true
	jogo_terminado = true


	print("")
	print("========================================")
	print("              GAME OVER")
	print("========================================")


	# ==========================================
	# MOSTRAR GAME OVER
	# ==========================================

	tela_game_over.visible = true
	var minigame := get_parent().get_parent()
	if minigame != null and minigame.has_method("notificar_derrota"):
		minigame.notificar_derrota()
