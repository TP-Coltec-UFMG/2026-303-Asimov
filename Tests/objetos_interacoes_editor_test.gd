extends Node2D

var falhas: Array[String] = []
var verificacoes: int = 0
var progresso_original: Dictionary
var configuracoes_originais: Dictionary
var jogador: Player


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	progresso_original = SaveGame.save_data.duplicate(true)
	configuracoes_originais = Configs.configs.duplicate(true)
	SaveGame.save_data = {}
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	_executar.call_deferred()


func _executar() -> void:
	jogador = preload("res://Player/ManPlayer.tscn").instantiate() as Player
	jogador.checkpoint_enabled = false
	jogador.starting_gun_enabled = false
	jogador.get_node("QUEST_MISSION").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(jogador)
	jogador.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var inventario := jogador.inventory
	for indice in range(1, 7):
		var slot := inventario.get_node("GridContainer/Slot%d" % indice) as Panel
		_verificar(slot.is_in_group(&"inventory_binding_slots"), "O slot deve ter seu grupo salvo na cena.")
		_verificar(slot.get_node_or_null("BindLabel") != null and slot.get_node_or_null("EquippedHighlight") != null, "O texto da tecla e o destaque devem existir na cena do slot.")
		_verificar(slot.resized.is_connected(Callable(slot, "_atualizar_posicao_item")), "O sinal de tamanho do slot deve estar salvo na cena.")
		var texto := slot.get_node("BindLabel") as Label
		_verificar(texto.text != "" and texto.text != "—", "Cada slot deve exibir sua tecla de equipar.")
	var porta := $Porta as SceneTrigger
	porta.jogador = jogador
	jogador.usando_cartao = true
	var destinos := ["data_center_refrigeracao", "data_center_forte", "sala_chefe"]
	var cartoes := ["cartao_padrao", "cartao_forte", "cartao_chefe"]
	for indice in range(3):
		var caminho := "res://Objects/%s.tscn" % cartoes[indice]
		var cartao := (load(caminho) as PackedScene).instantiate() as ItemColetavel
		cartao.position = Vector2(500, 500)
		add_child(cartao)
		_verificar(cartao.tipo == indice + 1 and cartao.save_id == cartoes[indice], "Os cartões devem manter seus níveis e IDs de save.")
		var interacao := cartao.get_node("Interectable") as Area2D
		var coleta := cartao.get_node("PickupComponent")
		_verificar(interacao.is_connected("interacao_solicitada", Callable(coleta, "coletar")), "A coleta deve ter conexão salva no editor.")
		await interacao.interagir()
		await get_tree().process_frame
		var guardado := inventario.get_item_control("cartao") as ItemColetavel
		_verificar(guardado != null and guardado.tipo == indice + 1 and guardado.no_inventario, "A coleta deve guardar o cartão no inventário e substituir apenas pelo superior.")
		_verificar(SaveGame.is_object_collected(cartoes[indice]), "A coleta deve registrar o objeto no save.")
		for nivel in range(3):
			porta.cena_destino = destinos[nivel]
			_verificar(porta._tem_cartao_compativel() == (indice >= nivel), "A porta deve respeitar o nível do cartão.")
		inventario.set_equipped_item("cartao")
		_verificar(inventario.get_node("GridContainer/Slot5/EquippedHighlight").visible, "Equipar deve manter o destaque vermelho do inventário.")
	_verificar(not inventario.add_item("cartao", preload("res://Objects/cartao_padrao.tscn")), "Um cartão inferior não pode substituir o cartão do chefe.")
	jogador.usando_cartao = false
	_verificar(not porta._tem_cartao_compativel(), "A porta deve exigir que o cartão esteja equipado.")
	for nome in ["cabo", "laptop", "lanterna", "extintor", "gun"]:
		var arquivo: String = "arma" if nome == "gun" else ("Lanterna" if nome == "lanterna" else nome)
		_verificar(inventario.add_item(nome, load("res://Objects/%s.tscn" % arquivo) as PackedScene), "Deve ser possível adicionar cada equipamento ao seu slot.")
		var item := inventario.get_item_control(nome) as ItemColetavel
		_verificar(item != null and item.no_inventario, "Os equipamentos devem compartilhar a lógica de item coletável.")
	var snapshot := inventario.get_save_state()
	var restaurado := preload("res://Player/inventory.tscn").instantiate() as Inventory
	add_child(restaurado)
	restaurado.load_save_state(snapshot)
	_verificar(restaurado.get_save_state() == snapshot, "Restaurar o inventário deve preservar o formato do checkpoint.")
	var arma = inventario.get_item_control("gun")
	arma.definir_jogador(jogador)
	arma.municao_atual = 2
	arma.municao_reserva = 7
	arma._iniciar_recarga()
	_verificar(arma.recarregando, "A recarga deve começar no temporizador da cena.")
	await get_tree().create_timer(0.15).timeout
	get_tree().paused = true
	var restante: float = arma.temporizador_recarga.time_left
	await get_tree().create_timer(0.2).timeout
	_verificar(is_equal_approx(restante, arma.temporizador_recarga.time_left), "Pausar deve parar o temporizador de recarga.")
	get_tree().paused = false
	await get_tree().create_timer(1.25).timeout
	_verificar(not arma.recarregando and arma.municao_atual == 7 and arma.municao_reserva == 2, "A recarga deve preencher o pente sem criar munição.")
	var filhos_antes: int = arma.get_child_count()
	arma._reproduzir_tiro()
	_verificar(arma.som_tiro.playing and arma.get_child_count() == filhos_antes, "O tiro deve usar o áudio existente na cena.")
	_verificar(arma.get_checkpoint_state() == {"current_ammo": 7, "reserve_ammo": 2}, "A arma deve preservar as chaves dos saves antigos.")
	var extintor = inventario.get_item_control("extintor")
	var extintor_restaurado = restaurado.get_item_control("extintor")
	_verificar(extintor.fumaca.process_material != extintor_restaurado.fumaca.process_material, "Cada extintor deve ter seu próprio material de partículas.")
	extintor._iniciar_indicador()
	extintor._liberar_indicador()
	_verificar(is_instance_valid(extintor.indicador) and not extintor.indicador.visible, "Encerrar o indicador deve ocultar os nós existentes.")
	var lampada = inventario.get_item_control("lanterna")
	lampada.definir_jogador(jogador)
	jogador.usando_arma = true
	lampada.definir_luz(true)
	_verificar(lampada.lanterna_acessa and lampada.luz.visible, "A arma e a lanterna devem continuar funcionando juntas.")
	lampada.definir_luz(false)
	var indicador = porta.get_node("DoorAccessIndicator")
	indicador.mostrar_estado(false)
	_verificar(indicador.cor_estado == indicador.cor_negado and indicador.sinal_negado.visible, "Negar acesso deve mostrar vermelho e um X.")
	indicador.mostrar_estado(true)
	_verificar(indicador.cor_estado == indicador.cor_liberado and indicador.sinal_liberado.visible, "Liberar acesso deve mostrar verde e a confirmação.")
	porta.eh_elevador = true
	indicador.hide()
	indicador.mostrar_estado(true)
	_verificar(not indicador.visible, "O elevador não deve mostrar o indicador de porta restrita.")
	var municao := preload("res://Objects/ammo_pickup.tscn").instantiate() as AmmoPickup
	municao.id_coleta = "teste_editor"
	municao.position = Vector2(800, 800)
	add_child(municao)
	_verificar(not municao.visible, "A munição deve continuar restrita à missão final.")
	SaveGame.save_global_state("hall_quest_01", {"programmer_ending_started": true})
	await get_tree().create_timer(0.35).timeout
	_verificar(municao.visible, "O temporizador deve liberar a munição durante a missão final.")
	municao.body_entered.emit(jogador)
	_verificar(municao.coletada and arma.municao_reserva == 9, "A conexão do editor deve coletar as sete balas ao tocar na caixa.")
	SaveGame.save_data = progresso_original
	Configs.configs = configuracoes_originais
	var arquivo_resultado := FileAccess.open("res://.objetos-resultados.json", FileAccess.WRITE)
	arquivo_resultado.store_string(JSON.stringify({"passed": falhas.is_empty(), "verificacoes": verificacoes, "falhas": falhas}, "\t"))
	for falha in falhas:
		push_error(falha)
	get_tree().quit(0 if falhas.is_empty() else 1)


func _verificar(condicao: bool, mensagem: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas.append(mensagem)
