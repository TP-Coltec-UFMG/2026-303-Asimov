extends Node2D


@export var fio_scene: PackedScene

var bateria_queimando: bool = false
var bateria_queimada: bool = false

var led_queimando: bool = false
var led_queimado: bool = false

var resistor_queimando: bool = false
var resistor_queimado: bool = false

var tutorial_ativado: bool = false

var _tutorial_anterior: bool = true

var esta_fechado: bool = false



func _ready() -> void:

	add_to_group("circuito")

	desligar_led()

	pass
	pass
	pass
	pass



	if not tutorial_ativado:

		pass

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


	pass
	pass
	pass
	pass

	debug_todas_conexoes()


	pass
	pass
	pass
	pass

	debug_todos_os_fios()


	pass
	pass
	pass
	pass

	analisar_circuito()

	_tutorial_anterior = tutorial_ativado



func _process(_delta: float) -> void:

	if _tutorial_anterior and not tutorial_ativado:

		pass
		pass
		pass
		pass
		pass

		reiniciar_circuito()

	_tutorial_anterior = tutorial_ativado



func reiniciar_circuito() -> void:

	pass
	pass
	pass
	pass



	bateria_queimando = false
	bateria_queimada = false

	led_queimando = false
	led_queimado = false

	resistor_queimando = false
	resistor_queimado = false

	esta_fechado = false



	var bateria = get_node_or_null("Bateria")
	var led = get_node_or_null("Led")
	var resistor = get_node_or_null("Resistor")



	if bateria != null:

		bateria.voltagem = 9.0



	var fios = get_tree().get_nodes_in_group("fios")

	for fio in fios:

		if fio == null:
			continue

		if not is_instance_valid(fio):
			continue

		fio.queue_free()



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



	if bateria != null:

		var sprite_bateria = bateria.get_node_or_null(
			"AnimatedSprite2D"
		)

		if sprite_bateria != null:

			sprite_bateria.play("normal")



	if led != null:

		var sprite_led := _obter_sprite_led()

		if sprite_led != null:

			sprite_led.play("desligado")



	if resistor != null:

		var sprite_resistor = resistor.get_node_or_null(
			"AnimatedSprite2D"
		)

		if sprite_resistor != null:

			sprite_resistor.play("normal")



	await get_tree().process_frame



	pass
	pass
	pass
	pass


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



	analisar_circuito()


	pass
	pass
	pass
	pass
	pass



func desmontar_circuito() -> void:

	pass
	pass
	pass
	pass


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



func conectar_fio(
	origem: Node2D,
	destino: Node2D,
	analisar_depois: bool = true
) -> Node2D:

	pass
	pass
	pass
	pass

	pass



	pass



	if origem == null or destino == null:
		return null

	if not is_instance_valid(origem):
		return null

	if not is_instance_valid(destino):
		return null

	if fio_scene == null:
		return null



	if conexao_existe(origem, destino):
		return null



	if origem.has_method("esta_disponivel"):

		if not origem.esta_disponivel():
			return null


	if destino.has_method("esta_disponivel"):

		if not destino.esta_disponivel():
			return null



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



	registrar_conexao(
		origem,
		destino
	)

	registrar_conexao(
		destino,
		origem
	)



	if analisar_depois:

		call_deferred(
			"analisar_circuito"
		)


	return fio



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



func obter_ponto_colisao(no: Node2D) -> Node2D:

	if no == null:
		return null

	if not is_instance_valid(no):
		return null

	if no is CollisionShape2D:
		return no

	if "ponto_colisao" in no:
		return no.ponto_colisao


	pass

	return null



func cortar_fio(fio: Node2D) -> void:

	pass
	pass
	pass
	pass


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


	pass

	pass



	remover_conexao_segura(
		origem,
		destino
	)

	remover_conexao_segura(
		destino,
		origem
	)



	fio.queue_free()



	call_deferred(
		"analisar_circuito"
	)



func debug_todas_conexoes() -> void:

	pass
	pass


	var pontos = get_tree().get_nodes_in_group(
		"pontos_conexao"
	)


	pass


	for ponto in pontos:

		if ponto == null:
			continue

		if not is_instance_valid(ponto):
			continue


		pass
		pass
		pass
		pass
		pass


		var pai = ponto.get_parent()

		if pai != null:
			pass


		if "conexoes_terminais" in ponto:

			pass


			for conexao in ponto.conexoes_terminais:

				if conexao == null:
					continue

				if not is_instance_valid(conexao):
					continue


				pass


	pass
	pass



func debug_todos_os_fios() -> void:

	var fios = get_tree().get_nodes_in_group(
		"fios"
	)


	pass


	for fio in fios:

		if fio == null:
			continue

		if not is_instance_valid(fio):
			continue


		pass
		pass


		if "origem" in fio:

			pass


		if "destino" in fio:

			pass


	pass
	pass



func analisar_circuito() -> void:

	pass
	pass
	pass
	pass


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



	if bateria_queimando or bateria_queimada:

		pass
		pass

		desligar_led()

		return



	if not "conexoes_terminais" in positivo:

		desligar_led()

		return


	if positivo.conexoes_terminais.size() == 0:

		pass
		pass

		desligar_led()

		return



	if not "conexoes_terminais" in negativo:

		desligar_led()

		return


	if negativo.conexoes_terminais.size() == 0:

		pass
		pass

		desligar_led()

		return



	var caminho: Array = []
	var visitados: Array = []


	var encontrou_negativo = percorrer_circuito(
		positivo,
		negativo,
		caminho,
		visitados
	)


	pass
	pass


	esta_fechado = encontrou_negativo



	if encontrou_negativo:

		pass
		pass
		pass
		pass


		for i in range(caminho.size()):

			pass


		analisar_componentes_circuito(
			caminho
		)



	else:

		pass
		pass
		pass
		pass

		desligar_led()



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



	if atual == destino:

		caminho.append(atual)

		return true



	if atual in visitados:
		return false


	visitados.append(atual)


	var caminho_atual: Array = caminho.duplicate()

	caminho_atual.append(atual)



	var eh_terminal := atual.is_in_group(
		"terminais"
	)


	if eh_terminal:


		var pai = atual.get_parent()

		if pai != null:

			if pai.name == "Led":

				if led_queimando or led_queimado:

					pass
					pass

					pass

					return false


			if pai.name == "Resistor":

				if resistor_queimando or resistor_queimado:

					pass
					pass

					pass

					return false


			if pai.name == "Bateria":

				if bateria_queimando or bateria_queimada:

					pass
					pass

					return false



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



func analisar_componentes_circuito(
	caminho: Array
) -> void:

	pass
	pass
	pass
	pass


	var tem_bateria := false
	var tem_led := false
	var tem_resistor := false



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

		pass

		return


	pass



	if tem_bateria and tem_led and tem_resistor:

		pass
		pass


		if tensao > 12.0:

			pass
			pass
			pass


			queimar_resistor()


			if tensao > 15.0:

				queimar_led()


		else:

			pass
			pass

			acender_led()

		return



	if tem_bateria and tem_led and not tem_resistor:

		pass
		pass

		pass
		pass


		queimar_led()

		return



	if tem_bateria and tem_resistor and not tem_led:

		pass
		pass


		if tensao > 15.0:

			pass

			queimar_resistor()

		else:

			pass

		return



	if tem_bateria and not tem_led and not tem_resistor:

		pass
		pass

		pass

		queimar_bateria()

		return



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



	if pai.name == "Bateria":

		return null



	if pai.name == "Led":

		if led_queimando or led_queimado:

			pass

			return null



	if pai.name == "Resistor":

		if resistor_queimando or resistor_queimado:

			pass

			return null



	for filho in pai.get_children():

		if filho == terminal:
			continue

		if filho is Area2D:

			if filho.is_in_group("terminais"):

				return filho


	return null


func _obter_sprite_led() -> AnimatedSprite2D:
	var jogo := get_parent()
	var alternativo: bool = jogo.modo_objetivo in [
		jogo.ModoObjetivo.QUEIMAR_LED,
		jogo.ModoObjetivo.QUEIMAR_LED_E_RESISTOR,
		jogo.ModoObjetivo.QUEIMAR_LED_E_BATERIA,
	]
	return get_node("Led/AnimatedSprite2D2" if alternativo else "Led/AnimatedSprite2D") as AnimatedSprite2D


func _tocar_ciclo_animacao(sprite: AnimatedSprite2D, animacao: StringName) -> void:
	sprite.play(animacao)
	if sprite.sprite_frames.get_animation_loop(animacao):
		await sprite.animation_looped
	else:
		await sprite.animation_finished



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


	pass
	pass
	pass
	pass



	bateria_queimando = true


	await _tocar_ciclo_animacao(sprite, &"queimando")
	await _tocar_ciclo_animacao(sprite, &"queimado")

	bateria_queimando = false
	bateria_queimada = true


	analisar_circuito()


	pass
	pass
	pass
	pass



func acender_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return


	var sprite := _obter_sprite_led()

	if sprite == null:
		return


	pass
	pass
	pass
	pass


	sprite.play(&"aceso" if sprite.sprite_frames.has_animation(&"aceso") else &"normal")



func desligar_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return


	var sprite := _obter_sprite_led()

	if sprite == null:
		return


	sprite.play(
		"desligado"
	)



func queimar_led() -> void:

	if led_queimando or led_queimado:
		return


	var led = get_node_or_null(
		"Led"
	)

	if led == null:
		return
	var sprite := _obter_sprite_led()
	if sprite == null:
		return


	pass
	pass
	pass
	pass



	led_queimando = true


	await _tocar_ciclo_animacao(sprite, &"queimando")
	await _tocar_ciclo_animacao(sprite, &"queimado")

	led_queimando = false
	led_queimado = true


	analisar_circuito()


	pass
	pass
	pass
	pass



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


	pass
	pass
	pass
	pass



	resistor_queimando = true


	await _tocar_ciclo_animacao(sprite, &"queimando")
	await _tocar_ciclo_animacao(sprite, &"queimado")

	resistor_queimando = false
	resistor_queimado = true


	analisar_circuito()


	pass
	pass
	pass
	pass



func registrar_fio_existente(
	origem: Node2D,
	destino: Node2D,
	fio: Node2D
) -> bool:

	pass
	pass
	pass
	pass



	if origem == null or destino == null or fio == null:

		pass

		return false


	if not is_instance_valid(origem):

		pass

		return false


	if not is_instance_valid(destino):

		pass

		return false


	if not is_instance_valid(fio):

		pass

		return false


	pass



	if origem == destino:

		pass

		return false



	if conexao_existe(origem, destino):

		pass

		return false



	if origem.has_method("esta_disponivel"):

		if not origem.esta_disponivel():

			pass

			return false


	if destino.has_method("esta_disponivel"):

		if not destino.esta_disponivel():

			pass

			return false



	var ponto_origem = obter_ponto_colisao(origem)
	var ponto_destino = obter_ponto_colisao(destino)


	if ponto_origem == null:

		pass

		return false


	if ponto_destino == null:

		pass

		return false



	if not fio.has_method("conectar"):

		pass

		return false


	fio.conectar(
		ponto_origem,
		ponto_destino
	)


	pass



	registrar_conexao(
		origem,
		destino
	)

	registrar_conexao(
		destino,
		origem
	)



	call_deferred(
		"analisar_circuito"
	)


	pass
	pass


	return true



func _on_aumentar_tensão_pressed() -> void:

	analisar_circuito()


func _on_diminuir_tensão_pressed() -> void:

	analisar_circuito()
