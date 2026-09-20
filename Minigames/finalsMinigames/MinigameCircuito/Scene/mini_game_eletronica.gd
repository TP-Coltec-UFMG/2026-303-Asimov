extends Node2D

signal minigame_completed
signal minigame_failed


# ============================================================
# MODOS DE OBJETIVO
# ============================================================

enum ModoObjetivo {
	QUEIMAR_RESISTOR,
	QUEIMAR_LED,
	QUEIMAR_BATERIA,
	QUEIMAR_LED_E_RESISTOR
}

@export var modo_objetivo: ModoObjetivo = ModoObjetivo.QUEIMAR_RESISTOR


# ============================================================
# REFERÊNCIAS
# ============================================================

@onready var circuito: Node2D = $Circuito
@onready var bateria = $Circuito/Bateria
@onready var resistor = $Circuito/Resistor
@onready var led = $Circuito/Led
@onready var alicate = $Circuito/Alicate
@onready var interface_jogo = $Circuito/Interface

@onready var juncao01 = $Circuito/Juncao01/Juncao
@onready var juncao02 = $Circuito/Juncao02/Juncao
@onready var juncao03 = $Circuito/Juncao03/Juncao
@onready var juncao04 = $Circuito/Juncao04/Juncao

@onready var resistor_terminal_positivo = $Circuito/Resistor/Terminal_positivo
@onready var resistor_terminal_negativo = $Circuito/Resistor/Terminal_negativo

@onready var led_terminal_positivo = $Circuito/Led/Terminal_positivo
@onready var led_terminal_negativo = $Circuito/Led/Terminal_negativo
@onready var colison_led_terminal_positivo = $Circuito/Led/Terminal_positivo/CollisionShape2D
@onready var colison_led_terminal_negativo = $Circuito/Led/Terminal_negativo/CollisionShape2D

@onready var componente1 = $Circuito/Led/AnimatedSprite2D
@onready var Componente2 = $Circuito/Led/AnimatedSprite2D2

@onready var painel_orientacao: Panel = $Fundo_preto_tutorial
@onready var texto_orientacao: Label = $Fundo_preto_tutorial/Label
@onready var botao_continuar: Button = $Fundo_preto_tutorial/Button


# ============================================================
# ESTADO DO TUTORIAL
# ============================================================

var passo_atual: int = 0
var passo_pronto: bool = false

var _nos_destacados: Array = []

var _proximo_passo_do_botao: int = -1


# ============================================================
# ESTADO DOS AVISOS
# ============================================================

var _aviso_ativo: bool = false
var _passo_antes_do_aviso: int = 0


# ============================================================
# ESTADO DAS CONEXÕES DO TUTORIAL DO LED
# ============================================================

var _corte_j03_resistor_existia: bool = false
var _corte_j04_led_existia: bool = false
var _conexao_j03_led_existia: bool = false


func notificar_vitoria() -> void:
	minigame_completed.emit()


func notificar_derrota() -> void:
	minigame_failed.emit()


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_configurar_componente_led()

	await get_tree().process_frame

	add_to_group("tutorial_objetivo")

	# ========================================================
	# IMPORTANTE:
	# O circuito NÃO deve ser desmontado no modo de queimar
	# a bateria.
	#
	# Ele deve começar normalmente conectado:
	#
	# Bateria (-) -> Juncao01
	# Juncao01 -> Juncao02
	# Juncao02 -> LED (-)
	# LED (+) -> Juncao04
	# Juncao04 -> Resistor (-)
	# Resistor (+) -> Juncao03
	# Juncao03 -> Bateria (+)
	#
	# O jogador irá cortar e reconectar esses fios durante
	# o tutorial para criar o curto circuito.
	# ========================================================

	# Define o objetivo da interface.
	if interface_jogo.has_method("definir_objetivo"):
		interface_jogo.definir_objetivo(_objetivo_da_interface())

	# Conecta o botão Continuar.
	if not botao_continuar.pressed.is_connected(_on_button_pressed):
		botao_continuar.pressed.connect(_on_button_pressed)

	# Começa o tutorial.
	_iniciar_passo(0)


# ============================================================
# PROCESS
# ============================================================

func _process(_delta: float) -> void:
	if not passo_pronto:
		return

	if _aviso_ativo:
		return

	_verificar_passo_atual()


# ============================================================
# OBJETIVO DA INTERFACE
# ============================================================

func _configurar_componente_led() -> void:
	match modo_objetivo:

		# Objetivos focados em queimar o LED: usa o Componente2.
		ModoObjetivo.QUEIMAR_LED, ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			componente1.visible = false
			Componente2.visible = true

			colison_led_terminal_positivo.position = Vector2(80, 42)
			colison_led_terminal_negativo.position = Vector2(-50, 42)

		# Demais objetivos: usa o Componente1.
		ModoObjetivo.QUEIMAR_RESISTOR, ModoObjetivo.QUEIMAR_BATERIA:
			componente1.visible = true
			Componente2.visible = false

			colison_led_terminal_positivo.position = Vector2(60, 40)
			colison_led_terminal_negativo.position = Vector2(-40, 40)


func _objetivo_da_interface():
	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			return interface_jogo.Objetivo.RESISTOR

		ModoObjetivo.QUEIMAR_LED:
			return interface_jogo.Objetivo.LED

		ModoObjetivo.QUEIMAR_BATERIA:
			return interface_jogo.Objetivo.BATERIA

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			return interface_jogo.Objetivo.RESISTOR_LED

	return interface_jogo.Objetivo.RESISTOR


# ============================================================
# AVANÇAR PASSO
# ============================================================

func _avancar_passo(proximo: int) -> void:
	passo_pronto = false
	_iniciar_passo(proximo)


# ============================================================
# INICIAR PASSO
# ============================================================

func _iniciar_passo(passo: int) -> void:
	passo_atual = passo
	passo_pronto = false

	_limpar_destaques()

	_proximo_passo_do_botao = -1

	botao_continuar.visible = false

	painel_orientacao.visible = true
	texto_orientacao.visible = true

	painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE

	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			_iniciar_passo_queimar_resistor(passo)

		ModoObjetivo.QUEIMAR_LED:
			_iniciar_passo_queimar_led(passo)

		ModoObjetivo.QUEIMAR_BATERIA:
			_iniciar_passo_queimar_bateria(passo)

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			_iniciar_passo_queimar_led_e_resistor(passo)

	passo_pronto = true


# ============================================================
# VERIFICAR PASSO ATUAL
# ============================================================

func _verificar_passo_atual() -> void:
	match modo_objetivo:

		ModoObjetivo.QUEIMAR_RESISTOR:
			_verificar_passo_queimar_resistor()

		ModoObjetivo.QUEIMAR_LED:
			_verificar_passo_queimar_led()

		ModoObjetivo.QUEIMAR_BATERIA:
			_verificar_passo_queimar_bateria()

		ModoObjetivo.QUEIMAR_LED_E_RESISTOR:
			_verificar_passo_queimar_led_e_resistor()


# ============================================================
# ============================================================
# QUEIMAR RESISTOR
# ============================================================
# ============================================================

func _iniciar_passo_queimar_resistor(passo: int) -> void:

	match passo:

		0:
			texto_orientacao.text = \
				"Num circuito, os componentes aguentam uma certa quantidade de energia passando por eles."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		1:
			texto_orientacao.text = \
				"O resistor é o primeiro componente em contato com a tensão da fonte. Ele diminui a tensão que chega no outro componente."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 2


		2:
			_destacar(bateria)
			_destacar(resistor)

			texto_orientacao.text = \
				"Se eu aumentar essa tensão, consigo queimá-lo!\n\nClique no polo + da bateria até o resistor queimar."

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _verificar_passo_queimar_resistor() -> void:

	if passo_atual != 2:
		return

	if circuito.resistor_queimando or circuito.resistor_queimado:
		_finalizar_orientacao()


# ============================================================
# ============================================================
# QUEIMAR LED
# ============================================================
# ============================================================

func _iniciar_passo_queimar_led(passo: int) -> void:

	match passo:

		# --------------------------------------------------------
		# ETAPA 1
		# --------------------------------------------------------

		0:
			texto_orientacao.text = \
				"Para queimar o componente, preciso fazer a energia passar diretamente por ele, sem o resistor."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		# --------------------------------------------------------
		# ETAPA 2
		# Cortar Juncao03 -> Resistor
		# --------------------------------------------------------

		1:
			_destacar(juncao03)
			_destacar(resistor)

			_corte_j03_resistor_existia = \
				_tem_conexao(
					juncao03,
					resistor_terminal_positivo
				)

			texto_orientacao.text = \
				"Vou cortar o fio entre a primeira junção e o resistor. Vou posicionar o alicate no fio e clicar com o botão direito."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		# --------------------------------------------------------
		# ETAPA 3
		# Cortar Juncao04 -> LED
		# --------------------------------------------------------

		2:
			_destacar(juncao04)
			_destacar(led)

			_corte_j04_led_existia = \
				_tem_conexao(
					juncao04,
					led_terminal_positivo
				)

			texto_orientacao.text = \
				"Agora vou cortar o fio entre a junção e o terminal do componente."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		# --------------------------------------------------------
		# ETAPA 4
		# Juncao03 -> LED
		# --------------------------------------------------------

		3:
			_destacar(juncao03)
			_destacar(led)

			_conexao_j03_led_existia = \
				_tem_conexao(
					juncao03,
					led_terminal_positivo
				)

			texto_orientacao.text = \
				"Agora vou ligar a junção em destaque diretamente ao terminal do componente e ver o que acontece."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _verificar_passo_queimar_led() -> void:

	match passo_atual:

		0:
			return

		1:
			if not _corte_j03_resistor_existia:
				return

			if not _tem_conexao(
				juncao03,
				resistor_terminal_positivo
			):
				_avancar_passo(2)

		2:
			if not _corte_j04_led_existia:
				return

			if not _tem_conexao(
				juncao04,
				led_terminal_positivo
			):
				_avancar_passo(3)

		3:
			if circuito.led_queimando or circuito.led_queimado:
				_finalizar_orientacao()


# ============================================================
# ============================================================
# QUEIMAR BATERIA
# ============================================================
# ============================================================

func _iniciar_passo_queimar_bateria(passo: int) -> void:

	match passo:

		# --------------------------------------------------------
		# ETAPA 1
		# O circuito normal já está montado.
		# --------------------------------------------------------

		0:
			_destacar(bateria)

			texto_orientacao.text = \
				"Um curto-circuito acontece quando a energia da bateria volta para ela sem nenhum componente no caminho."

			botao_continuar.visible = true

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

			_proximo_passo_do_botao = 1


		# --------------------------------------------------------
		# ETAPA 2
		# Criar curto circuito.
		# --------------------------------------------------------

		1:
			_destacar(bateria)

			texto_orientacao.text = \
				"Vou cortar os fios e reconectar de um jeito que o polo positivo fique direto no negativo. Isso deve fazer a bateria queimar."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _verificar_passo_queimar_bateria() -> void:

	if passo_atual != 1:
		return

	if circuito.bateria_queimando or circuito.bateria_queimada:
		_finalizar_orientacao()


# ============================================================
# ============================================================
# QUEIMAR LED + RESISTOR
# ============================================================
# ============================================================

func _iniciar_passo_queimar_led_e_resistor(passo: int) -> void:

	match passo:

		# --------------------------------------------------------
		# ETAPA 1
		# --------------------------------------------------------

		0:
			_destacar(bateria)
			_destacar(resistor)

			texto_orientacao.text = \
				"Vou queimar o resistor como fiz antes."

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


		# --------------------------------------------------------
		# ETAPA 2
		# --------------------------------------------------------

		1:
			_destacar(alicate)
			_destacar(juncao03)
			_destacar(led)

			texto_orientacao.text = \
				"Agora vou queimar o componente, assim como fiz antes"

			botao_continuar.visible = false

			painel_orientacao.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _verificar_passo_queimar_led_e_resistor() -> void:

	match passo_atual:

		0:
			if circuito.resistor_queimando or circuito.resistor_queimado:
				_avancar_passo(1)

		1:
			if circuito.led_queimando or circuito.led_queimado:
				_finalizar_orientacao()


# ============================================================
# ============================================================
# BOTÃO CONTINUAR
# ============================================================
# ============================================================

func _on_button_pressed() -> void:

	if not passo_pronto:
		return

	# --------------------------------------------------------
	# Aviso de conexão
	# --------------------------------------------------------

	if _aviso_ativo:

		var passo_retorno := _passo_antes_do_aviso

		_aviso_ativo = false

		_iniciar_passo(passo_retorno)

		return

	# --------------------------------------------------------
	# Próximo passo configurado
	# --------------------------------------------------------

	if _proximo_passo_do_botao >= 0:

		_avancar_passo(_proximo_passo_do_botao)

		return

	# --------------------------------------------------------
	# Finalizar
	# --------------------------------------------------------

	_finalizar_orientacao()


# ============================================================
# ============================================================
# MOSTRAR AVISO DE CONEXÃO
# ============================================================
# ============================================================

func mostrar_aviso_conexao(mensagem: String) -> void:

	if _aviso_ativo:
		return

	_passo_antes_do_aviso = passo_atual

	_aviso_ativo = true

	_limpar_destaques()

	painel_orientacao.visible = true
	texto_orientacao.visible = true

	painel_orientacao.mouse_filter = Control.MOUSE_FILTER_STOP

	texto_orientacao.text = mensagem

	_proximo_passo_do_botao = -1

	botao_continuar.visible = true

	passo_pronto = true


# ============================================================
# ============================================================
# VERIFICAR CONEXÃO
# ============================================================
# ============================================================

func _tem_conexao(a, b) -> bool:

	if a == null or b == null:
		return false

	if not is_instance_valid(a):
		return false

	if not is_instance_valid(b):
		return false

	if "conexoes_terminais" in a:

		if b in a.conexoes_terminais:
			return true

	if "conexoes_terminais" in b:

		if a in b.conexoes_terminais:
			return true

	return false


# ============================================================
# ============================================================
# FINALIZAR ORIENTAÇÃO
# ============================================================
# ============================================================

func _finalizar_orientacao() -> void:

	_aviso_ativo = false

	passo_pronto = false

	painel_orientacao.visible = false
	texto_orientacao.visible = false
	botao_continuar.visible = false

	_limpar_destaques()


# ============================================================
# ============================================================
# DESTACAR NÓ
# ============================================================
# ============================================================

func _destacar(no: Node, z_extra: int = 5) -> void:

	if no == null:
		return

	if not is_instance_valid(no):
		return

	if no in _nos_destacados:
		return

	_nos_destacados.append(no)

	no.set_meta(
		"_z_index_original_orientacao",
		no.z_index
	)

	if no.has_method("ativar_destaque"):
		no.ativar_destaque()

	no.z_index += z_extra


# ============================================================
# ============================================================
# LIMPAR DESTAQUES
# ============================================================
# ============================================================

func _limpar_destaques() -> void:

	for no in _nos_destacados:

		if no == null:
			continue

		if not is_instance_valid(no):
			continue

		if no.has_method("desativar_destaque"):
			no.desativar_destaque()

		if no.has_meta("_z_index_original_orientacao"):

			no.z_index = no.get_meta(
				"_z_index_original_orientacao"
			)

	_nos_destacados.clear()
