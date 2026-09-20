extends Node2D


@export var fio_scene: PackedScene

var bateria_queimando: bool = false
var bateria_queimada: bool = false

var led_queimando: bool = false
var led_queimado: bool = false

var resistor_queimando: bool = false
var resistor_queimado: bool = false

var tutorial_ativado: bool = false

# Guarda o estado anterior do tutorial para detectar
# quando ele muda de true -> false.
var _tutorial_anterior: bool = true

# Espelha o resultado da última análise
# true = existe caminho fechado positivo -> negativo.
# O TutorialManager só lê essa variável.
var esta_fechado: bool = false


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	add_to_group("circuito")

	desligar_led()

	print("")
	print("########################################")
	print("#        INICIANDO CIRCUITO             #")
	print("########################################")


	# ==========================================
	# CIRCUITO INICIAL
	# ==========================================

	if not tutorial_ativado:

		print("to aqui conectando")

		conectar_fio(
			$Bateria/Terminal_negativo,
			$Juncao01/Juncao,
			false
		)

		conectar_fio(
			$Bateria/Terminal_positivo,
			$Juncao03/Juncao,
			false
		)

		conectar_fio(
			$Juncao03/Juncao,
			$Resistor/Terminal_positivo,
			false
		)

		conectar_fio(
			$Resistor/Terminal_negativo,
			$Juncao04/Juncao,
			false
		)

		conectar_fio(
			$Juncao04/Juncao,
			$Led/Terminal_positivo,
			false
		)

		conectar_fio(
			$Led/Terminal_negativo,
			$Juncao02/Juncao,
			false
		)

		conectar_fio(
			$Juncao02/Juncao,
			$Juncao01/Juncao,
			false
		)


	await get_tree().process_frame


	print("")
	print("########################################")
	print("#      CONEXÕES REGISTRADAS             #")
	print("########################################")

	debug_todas_conexoes()


	print("")
	print("########################################")
	print("#        FIOS EXISTENTES                #")
	print("########################################")

	debug_todos_os_fios()


	print("")
	print("########################################")
	print("#        INICIANDO ANÁLISE              #")
	print("########################################")

	analisar_circuito()

	_tutorial_anterior = tutorial_ativado


# ==========================================
# DETECTAR DESATIVAÇÃO DO TUTORIAL
# ==========================================

func _process(_delta: float) -> void:

	if _tutorial_anterior and not tutorial_ativado:

		print("")
		print("########################################")
		print("#       TUTORIAL DESATIVADO            #")
		print("#       REINICIANDO CIRCUITO            #")
		print("########################################")

		reiniciar_circuito()

	_tutorial_anterior = tutorial_ativado


# ==========================================
# REINICIAR CIRCUITO
# ==========================================

func reiniciar_circuito() -> void:

	print("")
	print("========================================")
	print("       REINICIANDO CIRCUITO")
	print("========================================")


	# ==========================================
	# RESETAR ESTADO DOS COMPONENTES
	# ==========================================

	bateria_queimando = false
	bateria_queimada = false

	led_queimando = false
	led_queimado = false

	resistor_queimando = false
	resistor_queimado = false

	esta_fechado = false


	# ==========================================
	# RESETAR COMPONENTES VISUAIS
	# ==========================================

	var bateria = get_node_or_null("Bateria")
	var led = get_node_or_null("Led")
	var resistor = get_node_or_null("Resistor")


	# ==========================================
	# RESETAR TENSÃO DA BATERIA
	# ==========================================

	if bateria != null:

		bateria.voltagem = 9.0


	# ==========================================
	# REMOVER TODOS OS FIOS
	# ==========================================

	var fios = get_tree().get_nodes_in_group("fios")

	for fio in fios:

		if fio == null:
			continue

		if not is_instance_valid(fio):
			continue

		fio.queue_free()


	# ==========================================
	# LIMPAR CONEXÕES DE TODOS OS PONTOS
	# ==========================================

	var pontos = get_tree().get_nodes_in_group(
		"pontos_conexao"
	)

	for ponto in pontos:

		if ponto == null:
			continue

		if not is_instance_valid(ponto):
			continue

		if "conexoes_terminais" in ponto:

			ponto.conexoes_terminais.clear()

		if "conexoes_atuais" in ponto:

			ponto.conexoes_atuais = 0


	# ==========================================
	# RESETAR BATERIA
	# ==========================================

	if bateria != null:

		var sprite_bateria = bateria.get_node_or_null(
			"AnimatedSprite2D"
		)

		if sprite_bateria != null:

			sprite_bateria.play("normal")


	# ==========================================
	# RESETAR LED
	# ==========================================

	if led != null:

		var sprite_led = led.get_node_or_null(
			"AnimatedSprite2D"
		)

		if sprite_led != null:

			sprite_led.play("desligado")


	# ==========================================
	# RESETAR RESISTOR
	# ==========================================

	if resistor != null:

		var sprite_resistor = resistor.get_node_or_null(
			"AnimatedSprite2D"
		)

		if sprite_resistor != null:

			sprite_resistor.play("normal")


	# ==========================================
	# ESPERAR OS FIOS SEREM REMOVIDOS
	# ==========================================

	await get_tree().process_frame


	# ==========================================
	# RECRIAR CIRCUITO INICIAL
	# ==========================================

	print("")
	print("========================================")
	print("       RECRIANDO CONEXÕES")
	print("========================================")


	conectar_fio(
		$Bateria/Terminal_negativo,
		$Juncao01/Juncao,
		false
	)

	conectar_fio(
		$Bateria/Terminal_positivo,
		$Juncao03/Juncao,
		false
	)

	conectar_fio(
		$Juncao03/Juncao,
		$Resistor/Terminal_positivo,
		false
	)

	conectar_fio(
		$Resistor/Terminal_negativo,
		$Juncao04/Juncao,
		false
	)

	conectar_fio(
		$Juncao04/Juncao,
		$Led/Terminal_positivo,
		false
	)

	conectar_fio(
		$Led/Terminal_negativo,
		$Juncao02/Juncao,
		false
	)

	conectar_fio(
		$Juncao02/Juncao,
		$Juncao01/Juncao,
		false
	)


	# ==========================================
	# ESPERAR CONEXÕES
	# ==========================================

	await get_tree().process_frame


	# ==========================================
	# ANALISAR CIRCUITO
	# ==========================================

	analisar_circuito()


	print("")
	print("========================================")
	print("       CIRCUITO RESTAURADO")
	print("       TENSÃO: 9 V")
	print("========================================")


# ==========================================
# DESMONTAR CIRCUITO (SEM RECRIAR)
# ==========================================
#
# Usado pelo modo "queimar bateria": o circuito começa
# vazio para o jogador descobrir sozinho como ligar o
# positivo direto ao negativo (curto-circuito).
# ==========================================

func desmontar_circuito() -> void:

	print("")
	print("========================================")
	print("       DESMONTANDO CIRCUITO")
	print("========================================")


	var fios = get_tree().get_nodes_in_group("fios")

	for fio in fios:

		if fio == null:
			continue

		if not is_instance_valid(fio):
			continue

		fio.queue_free()


	var pontos = get_tree().get_nodes_in_group("pontos_conexao")

	for ponto in pontos:

		if ponto == null:
			continue

		if not is_instance_valid(ponto):
			continue

		if "conexoes_terminais" in ponto:
			ponto.conexoes_terminais.clear()

		if "conexoes_atuais" in ponto:
			ponto.conexoes_atuais = 0


	await get_tree().process_frame

	analisar_circuito()


# ==========================================
# CRIAR FIO
# ==========================================

func conectar_fio(
	origem: Node2D,
	destino: Node2D,
	analisar_depois: bool = true
) -> Node2D:

	print("")
	print("╔════════════════════════════════════════╗")
	print("║       INÍCIO DE conectar_fio()         ║")
	print("╚════════════════════════════════════════╝")

	print("[DEBUG 01] Função conectar_fio() iniciou.")


	# ==========================================
	# NOMES
	# ==========================================

	var nome_origem := obter_nome_ponto(origem)
	var nome_destino := obter_nome_ponto(destino)

	print(
		"CONEXÃO: ",
		nome_origem,
		" -> ",
		nome_destino
	)


	# ==========================================
	# VALIDAR
	# ==========================================

	if origem == null or destino == null:
		return null

	if not is_instance_valid(origem):
		return null

	if not is_instance_valid(destino):
		return null

	if fio_scene == null:
		return null


	# ==========================================
	# VERIFICAR CONEXÃO DUPLICADA
	# ==========================================

	if conexao_existe(origem, destino):
		return null


	# ==========================================
	# DISPONIBILIDADE
	# ==========================================

	if origem.has_method("esta_disponivel"):

		if not origem.esta_disponivel():
			return null


	if destino.has_method("esta_disponivel"):

		if not destino.esta_disponivel():
			return null


	# ==========================================
	# CRIAR FIO
	# ==========================================

	var fio: Node2D = fio_scene.instantiate()

	if fio == null:
		return null

	add_child(fio)


	var ponto_origem = obter_ponto_colisao(origem)
	var ponto_destino = obter_ponto_colisao(destino)


	if ponto_origem == null:

		fio.queue_free()
		return null


	if ponto_destino == null:

		fio.queue_free()
		return null


	fio.conectar(
		ponto_origem,
		ponto_destino
	)


	# ==========================================
	# REGISTRAR CONEXÕES
	# ==========================================

	registrar_conexao(
		origem,
		destino
	)

	registrar_conexao(
		destino,
		origem
	)


	# ==========================================
	# ANALISAR
	# ==========================================

	if analisar_depois:

		call_deferred(
			"analisar_circuito"
		)


	return fio


# ==========================================
# REGISTRAR CONEXÃO
# ==========================================

func registrar_conexao(
	origem: Node2D,
	destino: Node2D
) -> void:

	if origem == null or destino == null:
		return

	if not is_instance_valid(origem):
		return

	if not is_instance_valid(destino):
		return

	if not origem.has_method("adicionar_conexao"):
		return


	if "conexoes_terminais" in origem:

		if destino in origem.conexoes_terminais:
			return


	origem.adicionar_conexao(destino)


# ==========================================
# REMOVER CONEXÃO
# ==========================================

func remover_conexao_segura(
	origem: Node2D,
	destino: Node2D
) -> void:

	if origem == null or destino == null:
		return

	if not is_instance_valid(origem):
		return

	if not is_instance_valid(destino):
		return

	if not origem.has_method("remover_conexao"):
		return


	origem.remover_conexao(destino)


# ==========================================
# VERIFICAR CONEXÃO
# ==========================================

func conexao_existe(
	origem: Node2D,
	destino: Node2D
) -> bool:

	if origem == null or destino == null:
		return false

	if not is_instance_valid(origem):
		return false

	if not "conexoes_terminais" in origem:
		return false

	return destino in origem.conexoes_terminais


# ==========================================
# OBTER PONTO DE COLISÃO
# ==========================================

func obter_ponto_colisao(no: Node2D) -> Node2D:

	if no == null:
		return null

	if not is_instance_valid(no):
		return null

	if no is CollisionShape2D:
		return no

	if "ponto_colisao" in no:
		return no.ponto_colisao


	print(
		"ERRO: objeto ",
		no.name,
		" não possui ponto_colisao"
	)

	return null


# ==========================================
# CORTAR FIO
# ==========================================

func cortar_fio(fio: Node2D) -> void:

	print("")
	print("########################################")
	print("#              CORTE                    #")
	print("########################################")


	if fio == null:
		return

	if not is_instance_valid(fio):
		return


	var origem_shape: CollisionShape2D = fio.origem
	var destino_shape: CollisionShape2D = fio.destino


	if origem_shape == null or destino_shape == null:
		return

	if not is_instance_valid(origem_shape):
		return

	if not is_instance_valid(destino_shape):
		return


	var origem: Node2D = origem_shape.get_parent()
	var destino: Node2D = destino_shape.get_parent()


	if origem == null or destino == null:
		return

	if not is_instance_valid(origem):
		return

	if not is_instance_valid(destino):
		return


	print(
		"Origem real: ",
		obter_nome_ponto(origem)
	)

	print(
		"Destino real: ",
		obter_nome_ponto(destino)
	)


	# ==========================================
	# REMOVER CONEXÕES
	# ==========================================

	remover_conexao_segura(
		origem,
		destino
	)

	remover_conexao_segura(
		destino,
		origem
	)


	# ==========================================
	# REMOVER FIO
	# ==========================================

	fio.queue_free()


	# ==========================================
	# REANALISAR
	# ==========================================

	call_deferred(
		"analisar_circuito"
	)


# ==========================================
# DEBUG
# ==========================================

func debug_todas_conexoes() -> void:

	print("")
	print("========== TODAS AS CONEXÕES ==========")


	var pontos = get_tree().get_nodes_in_group(
		"pontos_conexao"
	)


	print(
		"Total de pontos de conexão: ",
		pontos.size()
	)


	for ponto in pontos:

		if ponto == null:
			continue

		if not is_instance_valid(ponto):
			continue


		print("")
		print("PONTO:")
		print("  Nome: ", ponto.name)
		print("  Nome definido: ", obter_nome_ponto(ponto))
		print("  Tipo: ", ponto.get_class())


		var pai = ponto.get_parent()

		if pai != null:
			print("  Pai: ", pai.name)


		if "conexoes_terminais" in ponto:

			print(
				"  Lista de conexões: ",
				ponto.conexoes_terminais.size()
			)


			for conexao in ponto.conexoes_terminais:

				if conexao == null:
					continue

				if not is_instance_valid(conexao):
					continue


				print(
					"    -> ",
					obter_nome_ponto(conexao)
				)


	print("")
	print("========================================")


# ==========================================
# DEBUG DOS FIOS
# ==========================================

func debug_todos_os_fios() -> void:

	var fios = get_tree().get_nodes_in_group(
		"fios"
	)


	print(
		"Quantidade de fios: ",
		fios.size()
	)


	for fio in fios:

		if fio == null:
			continue

		if not is_instance_valid(fio):
			continue


		print("")
		print(
			"FIO: ",
			fio.name
		)


		if "origem" in fio:

			print(
				"  origem: ",
				fio.origem
			)


		if "destino" in fio:

			print(
				"  destino: ",
				fio.destino
			)


	print("")
	print("========================================")


# ==========================================
# ANALISAR CIRCUITO
# ==========================================

func analisar_circuito() -> void:

	print("")
	print("========================================")
	print("          ANALISANDO CIRCUITO")
	print("========================================")


	var bateria = $Bateria

	if bateria == null:
		return


	var positivo = bateria.get_node_or_null(
		"Terminal_positivo"
	)

	var negativo = bateria.get_node_or_null(
		"Terminal_negativo"
	)


	if positivo == null or negativo == null:

		desligar_led()

		return


	# ==========================================
	# BATERIA QUEIMADA
	# ==========================================

	if bateria_queimando or bateria_queimada:

		print("BATERIA QUEIMADA/QUEIMANDO.")
		print("Não existe circuito.")

		desligar_led()

		return


	# ==========================================
	# POSITIVO SEM CONEXÃO
	# ==========================================

	if not "conexoes_terminais" in positivo:

		desligar_led()

		return


	if positivo.conexoes_terminais.size() == 0:

		print("POSITIVO SEM CONEXÕES.")
		print("NÃO EXISTE CIRCUITO.")

		desligar_led()

		return


	# ==========================================
	# NEGATIVO SEM CONEXÃO
	# ==========================================

	if not "conexoes_terminais" in negativo:

		desligar_led()

		return


	if negativo.conexoes_terminais.size() == 0:

		print("NEGATIVO SEM CONEXÕES.")
		print("NÃO EXISTE CIRCUITO.")

		desligar_led()

		return


	# ==========================================
	# BUSCAR CIRCUITO
	# ==========================================

	var caminho: Array = []
	var visitados: Array = []


	var encontrou_negativo = percorrer_circuito(
		positivo,
		negativo,
		caminho,
		visitados
	)


	print("")
	print(
		"Encontrou negativo? ",
		encontrou_negativo
	)


	esta_fechado = encontrou_negativo


	# ==========================================
	# CIRCUITO ENCONTRADO
	# ==========================================

	if encontrou_negativo:

		print("")
		print("########################################")
		print("#       CIRCUITO ENCONTRADO!            #")
		print("########################################")


		for i in range(caminho.size()):

			print(
				i + 1,
				" -> ",
				obter_nome_ponto(caminho[i])
			)


		analisar_componentes_circuito(
			caminho
		)


	# ==========================================
	# NÃO ENCONTRADO
	# ==========================================

	else:

		print("")
		print("########################################")
		print("#   NENHUM CIRCUITO FECHADO ENCONTRADO #")
		print("########################################")

		desligar_led()


# ==========================================
# PERCORRER CIRCUITO
# ==========================================

func percorrer_circuito(
	atual: Node2D,
	destino: Node2D,
	caminho: Array,
	visitados: Array
) -> bool:

	if atual == null:
		return false

	if not is_instance_valid(atual):
		return false


	# ==========================================
	# DESTINO
	# ==========================================

	if atual == destino:

		caminho.append(atual)

		return true


	# ==========================================
	# VISITADO
	# ==========================================

	if atual in visitados:
		return false


	visitados.append(atual)


	var caminho_atual: Array = caminho.duplicate()

	caminho_atual.append(atual)


	# ==========================================
	# TERMINAL DE COMPONENTE
	# ==========================================

	var eh_terminal := atual.is_in_group(
		"terminais"
	)


	if eh_terminal:

		# ==========================================
		# COMPONENTE QUEIMANDO / QUEIMADO
		# ==========================================

		var pai = atual.get_parent()

		if pai != null:

			# LED
			if pai.name == "Led":

				if led_queimando or led_queimado:

					print("")
					print(
						"LED ESTÁ QUEIMANDO/QUEIMADO."
					)

					print(
						"Corrente NÃO pode atravessar o LED."
					)

					return false


			# RESISTOR
			if pai.name == "Resistor":

				if resistor_queimando or resistor_queimado:

					print("")
					print(
						"RESISTOR ESTÁ QUEIMANDO/QUEIMADO."
					)

					print(
						"Corrente NÃO pode atravessar o resistor."
					)

					return false


			# BATERIA
			if pai.name == "Bateria":

				if bateria_queimando or bateria_queimada:

					print("")
					print(
						"BATERIA ESTÁ QUEIMANDO/QUEIMADA."
					)

					return false


		# ==========================================
		# OBTER OUTRO TERMINAL
		# ==========================================

		var outro_terminal = obter_outro_terminal(
			atual
		)


		if outro_terminal != null:

			if outro_terminal not in visitados:

				var visitados_componente: Array = \
					visitados.duplicate()

				var caminho_componente: Array = \
					caminho_atual.duplicate()


				var resultado_componente = \
					percorrer_circuito(
						outro_terminal,
						destino,
						caminho_componente,
						visitados_componente
					)


				if resultado_componente:

					caminho.clear()

					caminho.append_array(
						caminho_componente
					)

					return true


	# ==========================================
	# CONEXÕES EXTERNAS
	# ==========================================

	if not atual.has_method("adicionar_conexao"):
		return false


	var conexoes: Array = atual.conexoes_terminais


	if conexoes.size() == 0:
		return false


	for proximo in conexoes:

		if proximo == null:
			continue

		if not is_instance_valid(proximo):
			continue

		if proximo in visitados:
			continue


		var novos_visitados: Array = \
			visitados.duplicate()

		var novo_caminho: Array = \
			caminho_atual.duplicate()


		var resultado = percorrer_circuito(
			proximo,
			destino,
			novo_caminho,
			novos_visitados
		)


		if resultado:

			caminho.clear()

			caminho.append_array(
				novo_caminho
			)

			return true


	return false


# ==========================================
# ANALISAR COMPONENTES
# ==========================================

func analisar_componentes_circuito(
	caminho: Array
) -> void:

	print("")
	print("########################################")
	print("#       ANÁLISE DOS COMPONENTES         #")
	print("########################################")


	var tem_bateria := false
	var tem_led := false
	var tem_resistor := false


	# ==========================================
	# IDENTIFICAR COMPONENTES
	# ==========================================

	for ponto in caminho:

		if ponto == null:
			continue

		if not is_instance_valid(ponto):
			continue


		var pai = ponto.get_parent()

		if pai == null:
			continue


		if pai.name == "Bateria":

			tem_bateria = true

		elif pai.name == "Led":

			tem_led = true

		elif pai.name == "Resistor":

			tem_resistor = true


	# ==========================================
	# TENSÃO
	# ==========================================

	var bateria = get_node_or_null(
		"Bateria"
	)

	if bateria == null:
		return


	var tensao: float = 0.0


	if bateria.get("voltagem") != null:

		tensao = float(
			bateria.get("voltagem")
		)

	else:

		print(
			"ERRO: Bateria não possui voltagem."
		)

		return


	print(
		"TENSÃO DA BATERIA: ",
		tensao,
		" V"
	)


	# ==========================================
	# BATERIA + LED + RESISTOR
	# ==========================================

	if tem_bateria and tem_led and tem_resistor:

		print("")
		print(
			"BATERIA + RESISTOR + LED"
		)


		if tensao > 12.0:

			print("")
			print("!!! TENSÃO ACIMA DE 12V !!!")
			print("!!! RESISTOR VAI QUEIMAR !!!")


			queimar_resistor()


			if tensao > 15.0:

				queimar_led()


		else:

			print("")
			print("CIRCUITO FUNCIONANDO")

			acender_led()

		return


	# ==========================================
	# BATERIA + LED
	# ==========================================

	if tem_bateria and tem_led and not tem_resistor:

		print("")
		print("LED SEM RESISTOR")

		print("!!! LED VAI QUEIMAR !!!")
		print("!!! BATERIA VAI QUEIMAR !!!")


		queimar_led()

		return


	# ==========================================
	# BATERIA + RESISTOR
	# ==========================================

	if tem_bateria and tem_resistor and not tem_led:

		print("")
		print("RESISTOR NO CIRCUITO")


		if tensao > 15.0:

			print("!!! RESISTOR VAI QUEIMAR !!!")

			queimar_resistor()

		else:

			print("Resistor funcionando normalmente.")

		return


	# ==========================================
	# SOMENTE BATERIA
	# ==========================================

	if tem_bateria and not tem_led and not tem_resistor:

		print("")
		print("CURTO NA BATERIA")

		print("!!! BATERIA VAI QUEIMAR !!!")

		queimar_bateria()

		return


# ==========================================
# OBTER NOME DO PONTO
# ==========================================

func obter_nome_ponto(
	ponto: Node2D
) -> String:

	if ponto == null:
		return "NULL"

	if not is_instance_valid(ponto):
		return "INVALIDO"


	if ponto.is_in_group("terminais"):

		if "nome" in ponto:
			return ponto.nome

		return ponto.name


	if ponto.is_in_group("juncoes"):

		var pai = ponto.get_parent()

		if pai != null:
			return pai.name


	return ponto.name


# ==========================================
# OBTER OUTRO TERMINAL
# ==========================================

func obter_outro_terminal(
	terminal: Node2D
) -> Node2D:

	if terminal == null:
		return null

	if not is_instance_valid(terminal):
		return null

	if not terminal.is_in_group("terminais"):
		return null


	var pai = terminal.get_parent()

	if pai == null:
		return null


	# ==========================================
	# BATERIA
	# ==========================================

	if pai.name == "Bateria":

		return null


	# ==========================================
	# LED QUEIMANDO/QUEIMADO
	# ==========================================

	if pai.name == "Led":

		if led_queimando or led_queimado:

			print(
				"LED QUEIMANDO/QUEIMADO: ",
				"não pode atravessar."
			)

			return null


	# ==========================================
	# RESISTOR QUEIMANDO/QUEIMADO
	# ==========================================

	if pai.name == "Resistor":

		if resistor_queimando or resistor_queimado:

			print(
				"RESISTOR QUEIMANDO/QUEIMADO: ",
				"não pode atravessar."
			)

			return null


	# ==========================================
	# PROCURAR OUTRO TERMINAL
	# ==========================================

	for filho in pai.get_children():

		if filho == terminal:
			continue

		if filho is Area2D:

			if filho.is_in_group("terminais"):

				return filho


	return null


# ==========================================
# QUEIMAR BATERIA
# ==========================================

func queimar_bateria() -> void:

	if bateria_queimando or bateria_queimada:
		return


	var bateria = get_node_or_null(
		"Bateria"
	)

	if bateria == null:
		return


	var sprite = bateria.get_node_or_null(
		"AnimatedSprite2D"
	)

	if sprite == null:
		return


	print("")
	print("========================================")
	print("        BATERIA COMEÇOU A QUEIMAR")
	print("========================================")


	# ==========================================
	# MARCAR COMO QUEIMANDO
	# ==========================================

	bateria_queimando = true


	sprite.play(
		"queimando"
	)


	await sprite.animation_finished


	if not is_instance_valid(sprite):
		return


	sprite.play(
		"queimado"
	)

	await sprite.animation_finished


	bateria_queimando = false
	bateria_queimada = true


	analisar_circuito()


	print("")
	print("========================================")
	print("        BATERIA ESTÁ QUEIMADA")
	print("========================================")


# ==========================================
# ACENDER LED
# ==========================================

func acender_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return


	var sprite = led.get_node_or_null(
		"AnimatedSprite2D"
	)

	if sprite == null:
		return


	print("")
	print("========================================")
	print("              LED ACESO")
	print("========================================")


	sprite.play(
		"aceso"
	)


# ==========================================
# DESLIGAR LED
# ==========================================

func desligar_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return


	var sprite = led.get_node_or_null(
		"AnimatedSprite2D"
	)

	if sprite == null:
		return


	sprite.play(
		"desligado"
	)


# ==========================================
# QUEIMAR LED
# ==========================================

func queimar_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return
	var sprite: AnimatedSprite2D = \
			led.get_node_or_null(
				"AnimatedSprite2D"
			)
	if(get_parent().modo_objetivo==2 or get_parent().modo_objetivo==3):
		sprite = \
		led.get_node_or_null(
			"AnimatedSprite2D2"
		)
	


	


	print("")
	print("========================================")
	print("          LED COMEÇOU A QUEIMAR")
	print("========================================")


	# ==========================================
	# INTERROMPE O CIRCUITO IMEDIATAMENTE
	# ==========================================

	led_queimando = true


	sprite.play(
		"queimando"
	)


	var frames = sprite.sprite_frames.get_frame_count(
		"queimando"
	)

	var velocidade = sprite.sprite_frames.get_animation_speed(
		"queimando"
	)


	if frames > 0 and velocidade > 0:

		var duracao = float(frames) / velocidade

		await get_tree().create_timer(
			duracao
		).timeout

	else:

		print(
			"ERRO: Animação 'queimando' inválida."
		)

		led_queimando = false

		return


	if not is_instance_valid(sprite):
		return


	sprite.play(
		"queimado"
	)

	led_queimado = true

	await sprite.animation_finished


	led_queimando = false


	analisar_circuito()


	print("")
	print("========================================")
	print("             LED QUEIMADO")
	print("========================================")


# ==========================================
# QUEIMAR RESISTOR
# ==========================================

func queimar_resistor() -> void:

	if resistor_queimando or resistor_queimado:
		return


	var resistor = get_node_or_null(
		"Resistor"
	)

	if resistor == null:
		return


	var sprite: AnimatedSprite2D = \
		resistor.get_node_or_null(
			"AnimatedSprite2D"
		)


	if sprite == null:
		return


	print("")
	print("========================================")
	print("       RESISTOR COMEÇOU A QUEIMAR")
	print("========================================")


	# ==========================================
	# INTERROMPE O CIRCUITO IMEDIATAMENTE
	# ==========================================

	resistor_queimando = true


	sprite.play(
		"queimando"
	)


	var frames = sprite.sprite_frames.get_frame_count(
		"queimando"
	)

	var velocidade = sprite.sprite_frames.get_animation_speed(
		"queimando"
	)


	if frames > 0 and velocidade > 0:

		var duracao = float(frames) / velocidade

		await get_tree().create_timer(
			duracao
		).timeout

	else:

		print(
			"ERRO: Animação 'queimando' inválida."
		)

		resistor_queimando = false

		return


	if not is_instance_valid(sprite):
		return


	sprite.play(
		"queimado"
	)

	resistor_queimado = true

	await sprite.animation_finished


	resistor_queimando = false


	analisar_circuito()


	print("")
	print("========================================")
	print("          RESISTOR QUEIMADO")
	print("========================================")


# ==========================================
# REGISTRAR FIO EXISTENTE
# (vindo da Junção)
# ==========================================

func registrar_fio_existente(
	origem: Node2D,
	destino: Node2D,
	fio: Node2D
) -> bool:

	print("")
	print("╔════════════════════════════════════════╗")
	print("║   INÍCIO DE registrar_fio_existente()  ║")
	print("╚════════════════════════════════════════╝")


	# ==========================================
	# VALIDAR ARGUMENTOS
	# ==========================================

	if origem == null or destino == null or fio == null:

		print(
			"[CIRCUITO] Argumento nulo recebido."
		)

		return false


	if not is_instance_valid(origem):

		print(
			"[CIRCUITO] Origem inválida."
		)

		return false


	if not is_instance_valid(destino):

		print(
			"[CIRCUITO] Destino inválido."
		)

		return false


	if not is_instance_valid(fio):

		print(
			"[CIRCUITO] Fio inválido."
		)

		return false


	var nome_origem := obter_nome_ponto(origem)
	var nome_destino := obter_nome_ponto(destino)


	print(
		"[CIRCUITO] Registrando: ",
		nome_origem,
		" -> ",
		nome_destino
	)


	# ==========================================
	# NÃO CONECTAR CONSIGO MESMO
	# ==========================================

	if origem == destino:

		print(
			"[CIRCUITO] Origem e destino são o mesmo ponto."
		)

		return false


	# ==========================================
	# VERIFICAR CONEXÃO DUPLICADA
	# ==========================================

	if conexao_existe(origem, destino):

		print(
			"[CIRCUITO] Conexão já existe."
		)

		return false


	# ==========================================
	# DISPONIBILIDADE
	# ==========================================

	if origem.has_method("esta_disponivel"):

		if not origem.esta_disponivel():

			print(
				"[CIRCUITO] Origem ",
				nome_origem,
				" sem conexões disponíveis."
			)

			return false


	if destino.has_method("esta_disponivel"):

		if not destino.esta_disponivel():

			print(
				"[CIRCUITO] Destino ",
				nome_destino,
				" sem conexões disponíveis."
			)

			return false


	# ==========================================
	# OBTER PONTOS DE COLISÃO REAIS
	# ==========================================

	var ponto_origem = obter_ponto_colisao(origem)
	var ponto_destino = obter_ponto_colisao(destino)


	if ponto_origem == null:

		print(
			"[CIRCUITO] Ponto de colisão da origem é nulo."
		)

		return false


	if ponto_destino == null:

		print(
			"[CIRCUITO] Ponto de colisão do destino é nulo."
		)

		return false


	# ==========================================
	# REANCORAR O FIO NO DESTINO REAL
	# ==========================================

	if not fio.has_method("conectar"):

		print(
			"[CIRCUITO] Fio não possui método conectar()."
		)

		return false


	fio.conectar(
		ponto_origem,
		ponto_destino
	)


	print(
		"[CIRCUITO] Fio reancorado com sucesso."
	)


	# ==========================================
	# REGISTRAR CONEXÕES LÓGICAS
	# ==========================================

	registrar_conexao(
		origem,
		destino
	)

	registrar_conexao(
		destino,
		origem
	)


	# ==========================================
	# REANALISAR CIRCUITO
	# ==========================================

	call_deferred(
		"analisar_circuito"
	)


	print("")
	print(
		"[CIRCUITO] registrar_fio_existente() concluído com sucesso."
	)


	return true


# ==========================================
# BOTÕES DE TENSÃO
# ==========================================

func _on_aumentar_tensão_pressed() -> void:

	analisar_circuito()


func _on_diminuir_tensão_pressed() -> void:

	analisar_circuito()
