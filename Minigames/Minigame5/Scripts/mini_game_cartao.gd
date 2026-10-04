extends Node2D


@onready var leitor_cartao: Area2D = $Home/Leitor_cartao
@onready var notebook: Node2D = $Notebook
@onready var home: Node2D = $Home
@onready var cartao: Area2D = $Home/Cartao
@onready var computador: AnimatedSprite2D = $Home/Computador/AnimatedSprite2D
@onready var painel_tarefas: QuestMissionUI = $QUEST_MISSION

var _notebook_aberto: bool = false
var _modo_mouse_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


@onready var painel_tutorial: Panel = $Panel
@onready var label_tutorial: Label = $Panel/Label
@onready var botao_continuar_tutorial: Button = $Panel/Button


var etapa_tutorial: int = 0


var aguardando_tutorial: String = ""


var passou_etapas_iniciais: bool = false

const ETAPA_MINIMA_CABO: int = 3


const MENSAGEM_AINDA_NAO: String = "Ainda não"
const TAREFAS_RFID: Array[String] = [
	"PASSE O CARTÃO NO LEITOR",
	"CONECTE O CABO AO LEITOR",
	"ENTRE NO NOTEBOOK",
	"COPIE O CÓDIGO DO CARTÃO",
	"ABRA O BANCO DE DADOS",
	"INSIRA O CÓDIGO DO CARTÃO",
	"FECHE O NOTEBOOK",
	"TESTE O CARTÃO NOVAMENTE",
	"CARTÃO RFID REPROGRAMADO",
]

var _finalizando: bool = false

@onready var painel_ainda_nao: Panel = $Home/Leitor_cartao/Juncao2/Panel
@onready var label_ainda_nao: Label = $Home/Leitor_cartao/Juncao2/Panel/Label


var etapas_tutorial: Dictionary = {}
@onready var juncoes: Array[Node] = [$Home/Leitor_cartao/Juncao2, $Home/Computador/Juncao]
@onready var tempo_tutorial: Timer = $TempoTutorial
@onready var tempo_aviso: Timer = $TempoAviso
@onready var tempo_sucesso: Timer = $TempoSucesso


func _ready() -> void:
	_modo_mouse_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var falas_tutorial := DialogueCatalog.entries("rfid.minigame.thoughts")
	for index in range(falas_tutorial.size()):
		etapas_tutorial[index + 1] = falas_tutorial[index]
	mostrar_etapa_tutorial(1)
	_mostrar_progresso_tarefas(0)
	_atualizar_estado_conexao()


func pode_interagir_mundo() -> bool:
	return not _notebook_aberto and home.is_visible_in_tree()


func _on_cartao_alterado(presente: bool) -> void:
	if presente and aguardando_tutorial == "cartao":
		aguardando_tutorial = "conexao"
		mostrar_etapa_tutorial(3)
	_atualizar_estado_conexao()


func _on_conexao_alterada(_conectado: bool) -> void:
	_atualizar_estado_conexao()


func _atualizar_estado_conexao() -> void:
	var conectado := _algum_conectado_esta_true()
	computador.play("conectado" if _cartao_esta_no_leitor() and conectado else "normal")
	if conectado and aguardando_tutorial == "conexao":
		aguardando_tutorial = ""
		mostrar_etapa_tutorial(4)


func _on_button_pressed() -> void:
	if not pode_interagir_mundo() or not _pode_trocar_de_cena():
		return

	_notebook_aberto = true
	cartao.cancelar_arraste()
	for juncao in get_tree().get_nodes_in_group("juncoes"):
		if juncao.arrastando:
			juncao.cancelar_fio()
	for fio in get_tree().get_nodes_in_group("fios"):
		fio.cancelar_arraste()

	_modo_mouse_anterior = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	home.hide()
	home.process_mode = Node.PROCESS_MODE_DISABLED
	notebook.abrir()
	_mostrar_progresso_tarefas(3, true)


func _on_notebook_fechou() -> void:
	if not _notebook_aberto:
		return
	_notebook_aberto = false
	home.process_mode = Node.PROCESS_MODE_INHERIT
	home.show()
	Input.mouse_mode = _modo_mouse_anterior

	leitor_cartao.retirar_cartao()
	cartao.retirar_do_leitor()
	_atualizar_estado_conexao()


func _pode_trocar_de_cena() -> bool:
	return _cartao_esta_no_leitor() and _algum_conectado_esta_true()


func _cartao_esta_no_leitor() -> bool:
	return is_instance_valid(leitor_cartao) and leitor_cartao.cartao_em_cima and not cartao.voltando


func _algum_conectado_esta_true() -> bool:
	for juncao in juncoes:
		if juncao.conectado1:
			return true
	return false


func mostrar_etapa_tutorial(
	etapa: int,
	texto_customizado: String = ""
) -> void:

	if not etapas_tutorial.has(etapa):
		return


	etapa_tutorial = etapa


	var dados: Dictionary = etapas_tutorial[etapa]


	var titulo: String = dados.get(
		"titulo",
		""
	)


	var corpo: String = (
		texto_customizado
		if texto_customizado != ""
		else dados.get("texto", "")
	)


	label_tutorial.text = (
		titulo + "\n" + corpo
		if titulo != ""
		else corpo
	)

	painel_tutorial.visible = true


	botao_continuar_tutorial.visible = true

	botao_continuar_tutorial.text = "Continuar"


	_atualizar_tarefa_da_etapa(etapa)
	_agendar_fim_da_mensagem(etapa)


func esconder_tutorial() -> void:
	tempo_tutorial.stop()
	painel_tutorial.hide()


func _on_continuar_tutorial_pressed() -> void:

	match etapa_tutorial:

		1:

			mostrar_etapa_tutorial(2)


		2:


			passou_etapas_iniciais = true

			aguardando_tutorial = "cartao"

			esconder_tutorial()


		_:
			esconder_tutorial()


func _agendar_fim_da_mensagem(_etapa: int) -> void:
	tempo_tutorial.start()


func _ao_terminar_tempo_tutorial() -> void:
	if etapa_tutorial <= 2:
		_on_continuar_tutorial_pressed()
	else:
		esconder_tutorial()


func _atualizar_tarefa_da_etapa(etapa: int) -> void:
	match etapa:
		3:
			_mostrar_progresso_tarefas(1, true)
		4:
			_mostrar_progresso_tarefas(2, true)
		5:
			_mostrar_progresso_tarefas(4, true)
		6:
			_mostrar_progresso_tarefas(5, true)
		7:
			_mostrar_progresso_tarefas(6, true)
		8:
			_mostrar_progresso_tarefas(7, true)


func _mostrar_progresso_tarefas(
	concluidas: int,
	animar_ultima: bool = false
) -> void:
	if is_instance_valid(painel_tarefas):
		painel_tarefas.mostrar_sequencia_tarefas_isoladas(
			TAREFAS_RFID,
			concluidas,
			animar_ultima
		)


func _on_acesso_liberado() -> void:
	if _finalizando:
		return
	_finalizando = true
	esconder_tutorial()
	_mostrar_progresso_tarefas(TAREFAS_RFID.size(), true)
	tempo_sucesso.start()


func _ao_terminar_sucesso() -> void:
	if Progresso.retorno_cartao_rfid:
		Progresso.concluir_reprogramacao_cartao_rfid()


func pode_colocar_cartao() -> bool:

	return passou_etapas_iniciais


func pode_conectar_cabo() -> bool:

	return etapa_tutorial >= ETAPA_MINIMA_CABO


func mostrar_ainda_nao() -> void:
	label_ainda_nao.text = MENSAGEM_AINDA_NAO
	painel_ainda_nao.show()
	tempo_aviso.start()


func _exit_tree() -> void:
	Input.mouse_mode = _modo_mouse_anterior
