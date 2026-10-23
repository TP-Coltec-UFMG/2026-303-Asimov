extends Node

@export var atraso_lembrete: float = 15.0
@export var intervalo_lembretes: float = 30.0
@onready var painel: QuestMissionUI = get_parent()
@onready var verificacao: Timer = $Verificacao

var tempo_sem_progresso: float = 0.0
var assinatura: String = ""
var tempo_ultimo_lembrete: float = 0.0
var destaques: Array[Node] = []
var animacao: Tween
var texto_destacado: Label
var estilo_original: LabelSettings

func _enter_tree() -> void:
	_retomar_verificacao.call_deferred()

func _retomar_verificacao() -> void:
	if not is_inside_tree():
		return
	if painel.modo_isolado:
		verificacao.stop()
	else:
		verificacao.start()

func _exit_tree() -> void:
	_limpar_destaques()
	_parar_animacao()
	tempo_sem_progresso = 0.0
	assinatura = ""

func _ao_verificar() -> void:
	var jogador := painel.get_parent() as Player
	if jogador == null or painel.modo_isolado:
		return
	var atual := _assinatura_tarefas()
	if assinatura != atual:
		assinatura = atual
		tempo_sem_progresso = 0.0
		tempo_ultimo_lembrete = 0.0
		_limpar_destaques()
		_parar_animacao()
	if not _pode_orientar(jogador):
		_limpar_destaques()
		_parar_animacao()
		return
	var tarefa := _primeira_tarefa_pendente()
	if tarefa == null:
		return
	tempo_sem_progresso += verificacao.wait_time
	if tempo_sem_progresso < atraso_lembrete:
		return
	_atualizar_destaques(jogador)
	if tempo_ultimo_lembrete <= 0.0 or tempo_sem_progresso - tempo_ultimo_lembrete >= intervalo_lembretes:
		tempo_ultimo_lembrete = tempo_sem_progresso
		_destacar_tarefa(tarefa)

func _pode_orientar(jogador: Player) -> bool:
	if not painel.visibilidade_desejada or painel.oculto_no_elevador or get_tree().paused:
		return false
	if not jogador.is_physics_processing() or not jogador.can_process() or not jogador.is_visible_in_tree():
		return false
	if DialogManager.is_showing_dialog or not ContextualTutorial.tutorial_ativo.is_empty() or Engine.time_scale < 0.99:
		return false
	var cena := get_tree().current_scene
	if cena == null or not cena.is_ancestor_of(jogador):
		return false
	var guia := cena.get_node_or_null("CoolingLocationGuide")
	return guia == null or not bool(guia.get("cutscene_running"))

func _assinatura_tarefas() -> String:
	var partes := PackedStringArray()
	for indice in painel.linhas.size():
		if painel.linhas[indice].visible:
			partes.append("%d:%s:%s" % [indice, painel.linhas[indice].get_node("Label3").text, painel._tarefas_concluidas[indice]])
	return "|".join(partes)

func _primeira_tarefa_pendente() -> Label:
	for indice in painel.linhas.size():
		if painel.linhas[indice].visible and not painel._tarefas_concluidas[indice]:
			return painel.linhas[indice].get_node("Label3") as Label
	return null

func _destacar_tarefa(texto: Label) -> void:
	_parar_animacao()
	painel._revelar_painel()
	texto_destacado = texto
	estilo_original = texto.label_settings
	var estilo := estilo_original.duplicate() as LabelSettings
	estilo.outline_size = maxi(estilo.outline_size, 2)
	estilo.outline_color = Color(1.0, 0.95, 0.65, 0.0)
	texto.label_settings = estilo
	animacao = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for repeticao in range(3):
		animacao.tween_property(estilo, "outline_color:a", 0.85, 0.55)
		animacao.tween_property(estilo, "outline_color:a", 0.0, 0.65)
	animacao.tween_callback(_parar_animacao)

func _parar_animacao() -> void:
	if animacao != null and animacao.is_valid():
		animacao.kill()
	animacao = null
	if is_instance_valid(texto_destacado):
		texto_destacado.label_settings = estilo_original
	texto_destacado = null
	estilo_original = null

func _atualizar_destaques(jogador: Player) -> void:
	var procurados := PackedStringArray()
	for indice in painel.linhas.size():
		if not painel.linhas[indice].visible or painel._tarefas_concluidas[indice]:
			continue
		var texto := str(painel.linhas[indice].get_node("Label3").text).to_upper()
		if texto.contains("LANTERNA"):
			procurados.append("lanterna")
		if texto.contains("NOTEBOOK"):
			procurados.append("laptop")
		if texto.contains("CABO") and (texto.contains("ENCONTRE") or texto.contains("PEGUE")):
			procurados.append("cabo")
		if texto.contains("APAGUE O FOGO") or texto.contains("EXTINTOR"):
			procurados.append("extintor")
		if texto.contains("CARTÃO") and (texto.contains("PEGUE") or texto.contains("ENCONTRE")):
			procurados.append("cartao_chefe" if texto.contains("CHEFE") else "cartao")
	var novos: Array[Node] = []
	var cena := get_tree().current_scene
	for contorno in get_tree().get_nodes_in_group("color_accessibility_cue"):
		var objeto := contorno.get_parent().get_parent() as ItemColetavel
		if objeto == null or objeto.no_inventario or objeto.is_queued_for_deletion() or not objeto.is_visible_in_tree() or not cena.is_ancestor_of(objeto):
			continue
		var coleta := objeto.get_node_or_null("PickupComponent") as PickupComponent
		var interacao := objeto.get_node_or_null("Interectable")
		if coleta == null or interacao == null or not bool(interacao.get("is_interactable")) or not objeto.can_process():
			continue
		var chave := "cartao_chefe" if coleta.id_item == "cartao" and objeto.tipo == 3 else coleta.id_item
		if not procurados.has(chave) or jogador.inventory.get_item_on_inventary(coleta.id_item):
			continue
		novos.append(contorno)
		contorno.set_mission_hint(true)
	for contorno in destaques:
		if is_instance_valid(contorno) and not novos.has(contorno):
			contorno.set_mission_hint(false)
	destaques = novos

func _limpar_destaques() -> void:
	for contorno in destaques:
		if is_instance_valid(contorno):
			contorno.set_mission_hint(false)
	destaques.clear()
