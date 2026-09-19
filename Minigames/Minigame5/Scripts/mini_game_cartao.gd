extends Node2D


# ==========================================
# CONFIGURAÇÃO
# ==========================================

@export var cena_destino: String = "res://caminho_da_cena.tscn"


# ==========================================
# REFERÊNCIA DO LEITOR DE CARTÃO
# ==========================================

@onready var leitor_cartao: Area2D = $Home/Leitor_cartao
@onready var notebook: Node2D = $Notebook
@onready var home: Node2D = $Home
@onready var cartao: Area2D = $Home/Cartao
@onready var computador: AnimatedSprite2D = $Home/Computador/AnimatedSprite2D
@onready var painel_tarefas: QuestMissionUI = $QUEST_MISSION

var _notebook_aberto: bool = false
var _modo_mouse_anterior: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


# ==========================================
# TUTORIAL — CONFIGURAÇÃO GERAL
# ==========================================

@onready var painel_tutorial: Panel = $Panel
@onready var label_tutorial: Label = $Panel/Label
@onready var botao_continuar_tutorial: Button = $Panel/Button


enum GatilhoTutorial {
	CONTINUAR,   # avança com o botão "continuar" do próprio tutorial
	BOTAO_JOGO,  # avança quando o jogador clica num botão do jogo
	TAREFA,      # avança quando o jogador conclui uma tarefa
	FIM,         # última etapa do tutorial
}


var etapa_tutorial: int = 0


# "" | "cartao" | "conexao"
var aguardando_tutorial: String = ""


# ==========================================
# TRAVAS DO TUTORIAL
# ==========================================

# Vira true quando o jogador clica em "continuar" na etapa 2.
# Enquanto for false, o cartão NÃO pode ser colocado no leitor.
var passou_etapas_iniciais: bool = false

# O cabo só pode ser conectado a partir desta etapa
# (etapa 3 = cartão já foi colocado no leitor).
const ETAPA_MINIMA_CABO: int = 3


# ==========================================
# MENSAGEM "AINDA NÃO"
# ==========================================

const MENSAGEM_AINDA_NAO: String = "Ainda não"
const DURACAO_AINDA_NAO: float = 1.5
const DURACAO_MENSAGEM_TUTORIAL: float = 8.0
const ATRASO_SAIDA_SUCESSO: float = 1.25
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

var _id_mensagem_ainda_nao: int = 0
var _id_mensagem_tutorial: int = 0
var _finalizando: bool = false

@onready var painel_ainda_nao: Panel = $Home/Leitor_cartao/Juncao2/Panel
@onready var label_ainda_nao: Label = $Home/Leitor_cartao/Juncao2/Panel/Label


# ------------------------------------------
# Cada etapa mostra o texto e diz como ela avança:
#
#  1  aparece ao iniciar ............ avança: botão "continuar"
#  2  aparece após a etapa 1 ........ avança: botão "continuar"
#  3  aparece ao colocar o cartão no leitor
#  4  aparece ao conectar o cabo .... (notebook.gd / _process)
#  5  aparece ao clicar em COPIAR ... (codigo.gd)
#  6  aparece ao clicar no botão do Banco de Dados (notebook.gd)
#  7  aparece ao colar o ID no campo  (notebook.gd)
#  8  aparece ao fechar a janela .... (notebook.gd)
# ------------------------------------------

var etapas_tutorial: Dictionary = {
	1: {
		"texto": "Os cartões de acesso da empresa precisam funcionar\nmesmo se a internet cair. Então eles não podem\ndepender dela.",
		"gatilho": GatilhoTutorial.CONTINUAR,
	},

	2: {
		"texto": "Se as informações importantes não podem depender da\nrede, provavelmente elas estão no cartão!",
		"gatilho": GatilhoTutorial.CONTINUAR,
	},

	3: {
		"texto": "Beleza, coloquei o cartão no leitor! Mas ele não foi\nreconhecido… Talvez ele ainda tenha seu ID. Talvez eu\nainda consiga tentar reescrevê-lo no banco de dados\ndo leitor!",
		"gatilho": GatilhoTutorial.TAREFA,
	},

	4: {
		"texto": "Ótimo, com o leitor conectado no meu notebook eu\nposso extrair o ID e reescrevê-lo na base de dados\nnovamente.",
		"gatilho": GatilhoTutorial.BOTAO_JOGO,
	},

	5: {
		"texto": "ID copiado! Agora vou para a aba do Banco de Dados\ne procurar o registro desse cartão.",
		"gatilho": GatilhoTutorial.BOTAO_JOGO,
	},

	6: {
		"texto": "Achei, agora é só eu colocar o ID que eu extraí do\ncartão no campo de IDs.",
		"gatilho": GatilhoTutorial.TAREFA,
	},

	7: {
		"texto": "Os dados foram atualizados! Vou fechar a janela e\nvoltar para a tela inicial.",
		"gatilho": GatilhoTutorial.BOTAO_JOGO,
	},

	8: {
		"texto": "Bom, vou tentar colocar o cartão no leitor novamente.\nSe der errado, volto ao notebook e confiro os dados.",
		"gatilho": GatilhoTutorial.FIM,
	},
}

# ==========================================
# READY
# ==========================================

func _ready() -> void:
	add_to_group("tutorial_manager")
	botao_continuar_tutorial.pressed.connect(_on_continuar_tutorial_pressed)
	notebook.fechou.connect(_on_notebook_fechou)
	leitor_cartao.cartao_alterado.connect(_on_cartao_alterado)
	leitor_cartao.acesso_liberado.connect(_on_acesso_liberado)
	for juncao in get_tree().get_nodes_in_group("juncao"):
		juncao.conexao_alterada.connect(_on_conexao_alterada)
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

	# Cada saída retira o cartão para que a próxima leitura seja uma reinserção.
	leitor_cartao.retirar_cartao()
	cartao.retirar_do_leitor()
	_atualizar_estado_conexao()


# ==========================================
# VERIFICAR CONDIÇÕES
# ==========================================

func _pode_trocar_de_cena() -> bool:

	if leitor_cartao == null:

		print(
			"[MANAGER][BLOQUEIO] "
			+ "leitor_cartao == null"
		)

		return false


	if not is_instance_valid(leitor_cartao):

		print(
			"[MANAGER][BLOQUEIO] "
			+ "leitor_cartao inválido."
		)

		return false


	if not _cartao_esta_no_leitor():

		print(
			"[MANAGER][BLOQUEIO] "
			+ "Nenhum cartão válido está sobre o leitor."
		)

		return false


	print(
		"[MANAGER] Cartão detectado no leitor."
	)


	if not _algum_conectado_esta_true():

		print(
			"[MANAGER][BLOQUEIO] "
			+ "Nenhum nó conectado está ativo."
		)

		return false


	print(
		"[MANAGER] Existe pelo menos um nó conectado."
	)


	return true


# ==========================================
# VERIFICAR CARTÃO NO LEITOR
# ==========================================

func _cartao_esta_no_leitor() -> bool:

	if leitor_cartao == null:

		return false


	if not is_instance_valid(leitor_cartao):

		return false


	return leitor_cartao.cartao_em_cima and not cartao.voltando


# ==========================================
# VERIFICAR GRUPO "juncao"
# ==========================================

func _algum_conectado_esta_true() -> bool:

	var nos := get_tree().get_nodes_in_group(
		"juncao"
	)


	for n in nos:

		if n == null:

			continue


		if not is_instance_valid(n):

			continue


		if not ("conectado1" in n):

			continue


		if n.conectado1:

			return true


	return false


# ==========================================
# DEBUG COMPLETO
# ==========================================

func _debug_condicoes() -> void:

	print("")
	print("------------------------------------------")
	print("[MANAGER] DIAGNÓSTICO DAS CONDIÇÕES")
	print("------------------------------------------")


	if leitor_cartao == null:

		print("LEITOR: referência nula.")

	elif not is_instance_valid(leitor_cartao):

		print("LEITOR: referência inválida.")

	else:

		print("LEITOR: encontrado.")
		print("Nome: ", leitor_cartao.name)
		print("Tipo: ", leitor_cartao.get_class())


		if "cartao_em_cima" in leitor_cartao:

			print(
				"cartao_em_cima: ",
				leitor_cartao.cartao_em_cima
			)

		else:

			print(
				"Leitor não possui "
				+ "'cartao_em_cima'."
			)


	print("")
	print("GRUPO 'juncao':")


	var nos := get_tree().get_nodes_in_group(
		"juncao"
	)


	if nos.is_empty():

		print(
			"Nenhum nó encontrado no grupo."
		)

	else:

		for n in nos:

			if not is_instance_valid(n):

				print("Nó inválido.")

				continue


			if "conectado1" in n:

				print(
					"  ",
					n.name,
					" → conectado1 = ",
					n.conectado1
				)

			else:

				print(
					"  ",
					n.name,
					" → não possui "
					+ "conectado1"
				)


	print("")
	print("------------------------------------------")


	var cartao_ok := _cartao_esta_no_leitor()
	var conexao_ok := _algum_conectado_esta_true()


	print(
		"[MANAGER] Cartão: ",
		"OK" if cartao_ok else "FALHOU"
	)


	print(
		"[MANAGER] Conexão: ",
		"OK" if conexao_ok else "FALHOU"
	)


	print(
		"[MANAGER] Resultado final: ",
		"PODE TROCAR"
		if cartao_ok and conexao_ok
		else "NÃO PODE TROCAR"
	)


	print("------------------------------------------")
	print("")


# ==========================================
# TUTORIAL — MOSTRAR ETAPA
# ==========================================

func mostrar_etapa_tutorial(
	etapa: int,
	texto_customizado: String = ""
) -> void:

	if not etapas_tutorial.has(etapa):

		print(
			"[TUTORIAL][ERRO] Etapa inexistente: ",
			etapa
		)

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


	# ==========================================
	# TEXTO (sem "Etapa XX"; título só se existir)
	# ==========================================

	label_tutorial.text = (
		titulo + "\n" + corpo
		if titulo != ""
		else corpo
	)

	painel_tutorial.visible = true


	# ==========================================
	# BOTÃO CONTINUAR
	# ==========================================

	# O botão permite adiantar qualquer mensagem, mas nenhuma delas bloqueia o
	# jogador indefinidamente enquanto o cronômetro da campanha continua.
	botao_continuar_tutorial.visible = true

	botao_continuar_tutorial.text = "Continuar"


	print(
		"[TUTORIAL] Etapa ",
		etapa,
		" exibida."
	)
	_atualizar_tarefa_da_etapa(etapa)
	_agendar_fim_da_mensagem(etapa)


# ==========================================
# TUTORIAL — ESCONDER
# ==========================================

func esconder_tutorial() -> void:
	_id_mensagem_tutorial += 1
	painel_tutorial.visible = false


# ==========================================
# TUTORIAL — BOTÃO CONTINUAR
# ==========================================

func _on_continuar_tutorial_pressed() -> void:

	match etapa_tutorial:

		1:

			mostrar_etapa_tutorial(2)


		2:

			# Passou pelas 2 primeiras etapas: libera o cartão.
			# A etapa 3 só aparece quando o cartão for colocado
			# no leitor.

			passou_etapas_iniciais = true

			aguardando_tutorial = "cartao"

			esconder_tutorial()


		_:
			esconder_tutorial()


func _agendar_fim_da_mensagem(etapa: int) -> void:
	_id_mensagem_tutorial += 1
	var id_atual := _id_mensagem_tutorial
	await get_tree().create_timer(DURACAO_MENSAGEM_TUTORIAL).timeout
	if (
		id_atual != _id_mensagem_tutorial
		or not painel_tutorial.visible
		or etapa_tutorial != etapa
	):
		return
	if etapa == 1 or etapa == 2:
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
		painel_tarefas.show_standalone_task_sequence(
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
	await get_tree().create_timer(ATRASO_SAIDA_SUCESSO).timeout
	if Progresso.retorno_cartao_rfid:
		Progresso.concluir_reprogramacao_cartao_rfid()


# ==========================================
# TUTORIAL — TRAVAS
# ==========================================
# Consultadas pelo leitor (cartão) e pelos fios (cabo).

func pode_colocar_cartao() -> bool:

	return passou_etapas_iniciais


func pode_conectar_cabo() -> bool:

	return etapa_tutorial >= ETAPA_MINIMA_CABO


# ==========================================
# TUTORIAL — MENSAGEM "AINDA NÃO"
# ==========================================
# Aparece no painel ao lado do leitor (Juncao2/Panel) sempre que
# o jogador tenta colocar o cartão ou conectar o cabo cedo demais.

func mostrar_ainda_nao() -> void:

	label_ainda_nao.text = MENSAGEM_AINDA_NAO

	painel_ainda_nao.visible = true

	_id_mensagem_ainda_nao += 1

	var id_atual: int = _id_mensagem_ainda_nao

	await get_tree().create_timer(DURACAO_AINDA_NAO).timeout

	# Se veio outra mensagem nesse meio tempo, ela cuida de esconder.
	if id_atual == _id_mensagem_ainda_nao:

		painel_ainda_nao.visible = false
