extends CanvasLayer

const CHAVE_TUTORIAIS_VISTOS := "contextual_tutorial_seen"
const ESCALA_CAMERA_LENTA := 0.25
const DURACAO_TRANSICAO := 0.45
const DURACAO_ENTRADA := 0.6
const DURACAO_TRANSICAO_MUSICA := 0.65
const FATOR_MUSICA_TUTORIAL := 0.35
const LARGURA_PAINEL := 250.0
const ACOES_MOVIMENTO: Array[StringName] = [&"up", &"left", &"down", &"right"]
const INTERVALO_TUTORIAIS := 0.8
const OPACIDADE_SEM_DESTAQUE := 0.15

@onready var balao: Panel = $Panel
@onready var titulo: Label = $Panel/Content/Title
@onready var explicacao: RichTextLabel = $Panel/Content/Explanation

var jogador: Player
var pendentes: Array[String] = []
var tutorial_ativo := ""
var tempo_decorrido := 0.0
var tempo_minimo_leitura := DURACAO_ENTRADA
@export_range(5.0, 30.0, 0.5) var tempo_maximo_leitura: float = 10.0
var finalizando := false
var praticou := false
var posicao_inicial := Vector2.ZERO
var municao_inicial := 0
var escala_anterior := 1.0
var escala_aplicada := 1.0
var controla_camera_lenta := false
var ultimo_instante := 0
var tempo_varredura := 0.0
var tempo_disponivel := 0.0
var intervalo := 0.0
var id_jogador_tutorial := 0
var quantidade_coletada := 0
var quantidade_coletada_inicial := 0
var id_jogador_observado := 0
var alvos_destaque: Array[Dictionary] = []
var painel_destacado: QuestMissionUI
var tarefas_destacadas := false
var transicao_destaque: Tween
var intensidade_destaque := 0.0
var destaque_ativo := false
var transicao_brilho: Tween
var estilo_brilho: StyleBoxFlat
var transicao_balao: Tween
var posicao_repouso_balao := Vector2.ZERO
var transicao_musica: Tween
var musica_reduzida := false
var acao_estava_ativa := false
var direcoes_praticadas: Array[StringName] = []


func _ready() -> void:
	ultimo_instante = Time.get_ticks_usec()
	estilo_brilho = balao.get_theme_stylebox("panel") as StyleBoxFlat
	get_tree().scene_changed.connect(_ao_mudar_cena)


func _exit_tree() -> void:
	_restaurar_camera_lenta()
	_restaurar_destaque(true)
	_parar_brilho()
	_reduzir_musica(false, true)
	_parar_movimento_balao()


func _ao_mudar_cena() -> void:
	cancelar_atual()
	_restaurar_destaque(true)
	_reduzir_musica(false, true)
	pendentes.clear()
	jogador = null
	tempo_disponivel = 0.0


func iniciar_novo_jogo() -> void:
	_ao_mudar_cena()
	intervalo = 0.0
	tempo_varredura = 0.0
	id_jogador_observado = 0
	Configs.configs[CHAVE_TUTORIAIS_VISTOS] = {}
	SaveLoad._save()


func _process(_delta: float) -> void:
	var agora := Time.get_ticks_usec()
	var delta_real := minf(float(agora - ultimo_instante) / 1000000.0, 0.1)
	ultimo_instante = agora
	if not _jogo_disponivel():
		_suspender()
		tempo_disponivel = 0.0
		return
	tempo_disponivel += delta_real
	if not tutorial_ativo.is_empty() and id_jogador_tutorial != jogador.get_instance_id():
		cancelar_atual()
	if not tutorial_ativo.is_empty():
		_atualizar_tutorial(delta_real)
		return
	intervalo = maxf(0.0, intervalo - delta_real)
	tempo_varredura += delta_real
	if tempo_varredura < 0.1 or tempo_disponivel < 0.6:
		return
	tempo_varredura = 0.0
	_descobrir_tutoriais()
	if intervalo <= 0.0:
		_iniciar_proximo()


func _jogo_disponivel() -> bool:
	var cena := get_tree().current_scene
	if not cena is BaseScene or get_tree().paused or DialogManager.is_showing_dialog:
		return false
	if not is_instance_valid(jogador) or not cena.is_ancestor_of(jogador):
		jogador = cena.get_scene_player()
	if not is_instance_valid(jogador):
		return false
	if not jogador.can_process() or not jogador.is_physics_processing() or not jogador.is_processing_input():
		return false
	if not jogador.is_visible_in_tree() or jogador.npc_warning_active:
		return false
	if get_tree().get_first_node_in_group(&"opening_gameplay_blur") != null:
		return false
	var camera := get_viewport().get_camera_2d()
	return camera == jogador.camera_2d


func _ja_visto(id: String) -> bool:
	var vistos: Variant = Configs.configs.get(CHAVE_TUTORIAIS_VISTOS, {})
	return vistos is Dictionary and bool(vistos.get(id, false))


func _enfileirar(id: String, urgente: bool = false) -> void:
	if id == tutorial_ativo or id in pendentes or _ja_visto(id):
		return
	if id == "push" and not _tutorial_empurrar_liberado():
		return
	if urgente:
		pendentes.push_front(id)
	else:
		pendentes.append(id)


func _descobrir_tutoriais() -> void:
	var inventario := jogador.inventory
	var quantidade := inventario.get_save_state().size()
	if id_jogador_observado != jogador.get_instance_id():
		quantidade_coletada = quantidade
		id_jogador_observado = jogador.get_instance_id()
	if quantidade > quantidade_coletada:
		_enfileirar("collect")
	quantidade_coletada = quantidade
	var interacao := jogador.get_node_or_null("InteractiongComponent")
	if interacao != null:
		for area: Area2D in interacao.current_interactions:
			if is_instance_valid(area) and area.is_interactable and area.get_parent().get_node_or_null("PickupComponent") != null:
				_enfileirar("collect")
				break
	if jogador.objeto_manipulado != null or jogador.has_grab_object_nearby():
		_enfileirar("push", true)
	if jogador.usando_extintor:
		_enfileirar("extinguisher", true)
	elif jogador.usando_lanterna:
		_enfileirar("flashlight", true)
	elif jogador.usando_arma:
		var arma := inventario.get_item_control("gun")
		_enfileirar("weapon", true)
		if _ja_visto("weapon") and int(arma.municao_atual) <= 0:
			_enfileirar("reload", true)
		if _ja_visto("weapon") and inventario.get_item_on_inventary("lanterna"):
			_enfileirar("weapon_flashlight")
	var cartao := inventario.get_item_control("cartao")
	if cartao != null:
		_enfileirar("card_%d" % int(cartao.tipo))
	if inventario.get_item_on_inventary("lanterna"):
		_enfileirar("flashlight")
	if not _ja_visto("walk"):
		_enfileirar("walk")
	elif not _ja_visto("run") and jogador.direction != Vector2.ZERO:
		_enfileirar("run")
	if bool(jogador.get_node("QUEST_MISSION")._oculto_automaticamente):
		_enfileirar("tasks", true)


func _ainda_relevante(id: String) -> bool:
	var inventario := jogador.inventory
	match id:
		"reload":
			var arma := inventario.get_item_control("gun")
			return jogador.usando_arma and arma != null and int(arma.municao_atual) <= 0
		"weapon", "weapon_flashlight":
			return jogador.usando_arma
		"flashlight":
			return inventario.get_item_on_inventary("lanterna")
		"extinguisher":
			return jogador.usando_extintor
		"tasks":
			return bool(jogador.get_node("QUEST_MISSION")._oculto_automaticamente)
		"push":
			return _tutorial_empurrar_liberado() and (jogador.objeto_manipulado != null or jogador.has_grab_object_nearby())
	if id.begins_with("card_"):
		var cartao := inventario.get_item_control("cartao")
		return cartao != null and int(cartao.tipo) == int(id.trim_prefix("card_"))
	return true


func _tutorial_empurrar_liberado() -> bool:
	var cena := get_tree().current_scene
	if cena != null and cena.scene_file_path == "res://Scenes/andar_hall.tscn":
		var missao := cena.get_node_or_null("QuestController")
		return missao != null and bool(missao.M1_feito)
	var hall: Variant = SaveGame.save_data.get("res://Scenes/andar_hall.tscn", {})
	if not hall is Dictionary:
		return false
	var mission: Variant = hall.get("hall_quest_01", {})
	return mission is Dictionary and bool(mission.get("task_fire_done", false))


func _iniciar_proximo() -> void:
	while not pendentes.is_empty():
		var id: String = pendentes.pop_front()
		if not _ja_visto(id) and _ainda_relevante(id):
			_iniciar_tutorial(id)
			return


func _iniciar_tutorial(id: String) -> void:
	tutorial_ativo = id
	id_jogador_tutorial = jogador.get_instance_id()
	tempo_decorrido = 0.0
	finalizando = false
	praticou = false
	direcoes_praticadas.clear()
	posicao_inicial = jogador.global_position
	var arma := jogador.inventory.get_item_control("gun")
	municao_inicial = int(arma.municao_atual) if arma != null else 0
	quantidade_coletada_inicial = jogador.inventory.get_save_state().size()
	var conteudo := _conteudo(id)
	titulo.text = conteudo[0]
	explicacao.text = "[center]" + conteudo[1] + "[/center]"
	tempo_minimo_leitura = DURACAO_ENTRADA
	balao.accessibility_name = titulo.text + ". " + conteudo[1]
	var fator := 1.1 if int(Configs.configs.get("interface_size", 0)) == 2 else 1.0
	titulo.add_theme_font_size_override("font_size", int(round(12.0 * fator)))
	for font_size_name in ["normal_font_size", "bold_font_size"]:
		explicacao.add_theme_font_size_override(font_size_name, int(round(10.0 * fator)))
	acao_estava_ativa = _acao_praticada()
	_animar_balao(true)
	if bool(Configs.configs.get("leitor_de_tela", false)):
		LeitorDeTela._ler_texto(balao.accessibility_name)
	_ativar_camera_lenta()
	_iniciar_destaque()
	_iniciar_brilho()
	_reduzir_musica(true)


func _atualizar_tutorial(delta_real: float) -> void:
	if not controla_camera_lenta:
		if tempo_disponivel < 0.6:
			return
		_ativar_camera_lenta()
		if not finalizando:
			_animar_balao(true)
			_iniciar_destaque()
			_iniciar_brilho()
			_reduzir_musica(true)
	tempo_decorrido += delta_real
	var action_active := _acao_praticada()
	praticou = praticou or (action_active and not acao_estava_ativa)
	acao_estava_ativa = action_active
	if not finalizando and tempo_decorrido >= tempo_minimo_leitura and (praticou or tempo_decorrido >= tempo_maximo_leitura):
		finalizando = true
		tempo_decorrido = 0.0
		_restaurar_destaque()
		_parar_brilho()
		_animar_balao(false)
		_reduzir_musica(false)
	if finalizando:
		var progress := clampf(tempo_decorrido / DURACAO_TRANSICAO, 0.0, 1.0)
		_definir_escala_aplicada(lerpf(escala_anterior * ESCALA_CAMERA_LENTA, escala_anterior, progress))
		if not controla_camera_lenta:
			return
		if progress >= 1.0:
			_concluir_tutorial()
	else:
		_definir_escala_aplicada(lerpf(escala_anterior, escala_anterior * ESCALA_CAMERA_LENTA, minf(1.0, tempo_decorrido / DURACAO_TRANSICAO)))


func _input(evento: InputEvent) -> void:
	if tutorial_ativo.is_empty() or finalizando or not controla_camera_lenta:
		return
	if not _jogo_disponivel():
		return
	if evento is InputEventKey and evento.echo:
		return
	if tutorial_ativo == "walk":
		for action: StringName in ACOES_MOVIMENTO:
			if evento.is_action_pressed(action) and action not in direcoes_praticadas:
				direcoes_praticadas.append(action)
		_atualizar_texto_movimento()
		praticou = direcoes_praticadas.size() == ACOES_MOVIMENTO.size()
		return
	var actions: Array[StringName] = []
	match tutorial_ativo:
		"run":
			actions.append(&"correr")
		"push":
			actions.append(&"empurrar")
		"collect":
			actions.append(&"interact")
		"flashlight":
			actions.assign([&"use_lanterna", &"acende_lanterna"])
		"extinguisher":
			actions.append(&"usar_extintor")
		"weapon":
			actions.append(&"fire")
		"reload":
			actions.append(&"reload")
		"weapon_flashlight":
			actions.append(&"use_lanterna")
		"tasks":
			actions.append(&"show_tasks")
	if tutorial_ativo.begins_with("card_"):
		actions.assign([&"use_cartao", &"interact"])
	for action: StringName in actions:
		if evento.is_action_pressed(action):
			praticou = true
			return


func _acao_praticada() -> bool:
	var inventario := jogador.inventory
	match tutorial_ativo:
		"walk":
			return direcoes_praticadas.size() == ACOES_MOVIMENTO.size()
		"run":
			return jogador.correndo
		"push":
			return jogador.objeto_manipulado != null and jogador.global_position.distance_to(posicao_inicial) >= 3.0
		"collect":
			return inventario.get_save_state().size() > quantidade_coletada_inicial
		"flashlight":
			var lamp := inventario.get_item_control("lanterna")
			return lamp != null and bool(lamp.lanterna_acessa)
		"extinguisher":
			var extinguisher := inventario.get_item_control("extintor")
			return extinguisher != null and bool(extinguisher.extintor_ligado)
		"weapon":
			var arma := inventario.get_item_control("gun")
			return arma != null and int(arma.municao_atual) < municao_inicial
		"reload":
			var arma := inventario.get_item_control("gun")
			return arma != null and int(arma.municao_atual) > municao_inicial
		"weapon_flashlight":
			var lamp := inventario.get_item_control("lanterna")
			return jogador.usando_arma and lamp != null and bool(lamp.lanterna_acessa)
		"tasks":
			return Input.is_action_pressed("show_tasks")
	return tutorial_ativo.begins_with("card_") and jogador.usando_cartao


func _atualizar_texto_movimento() -> void:
	var keys: Array[String] = []
	for action: StringName in ACOES_MOVIMENTO:
		var key := _tecla(action).replace("[", "[lb]")
		keys.append("[b]" + key + "[/b]" if action in direcoes_praticadas else key)
	explicacao.text = "[center]Use %s para andar pelo cenário.[/center]" % "/".join(keys)


func _concluir_tutorial() -> void:
	var saved: Variant = Configs.configs.get(CHAVE_TUTORIAIS_VISTOS, {})
	var vistos: Dictionary = saved.duplicate() if saved is Dictionary else {}
	vistos[tutorial_ativo] = true
	Configs.configs[CHAVE_TUTORIAIS_VISTOS] = vistos
	SaveLoad._save()
	cancelar_atual()
	intervalo = INTERVALO_TUTORIAIS


func _ativar_camera_lenta() -> void:
	escala_anterior = Engine.time_scale
	escala_aplicada = escala_anterior
	controla_camera_lenta = true


func _definir_escala_aplicada(value: float) -> void:
	if not is_equal_approx(Engine.time_scale, escala_aplicada):
		cancelar_atual()
		return
	Engine.time_scale = value
	escala_aplicada = value


func _restaurar_camera_lenta() -> void:
	if controla_camera_lenta and is_equal_approx(Engine.time_scale, escala_aplicada):
		Engine.time_scale = escala_anterior
	controla_camera_lenta = false


func _suspender() -> void:
	_restaurar_camera_lenta()
	_parar_movimento_balao()
	balao.hide()
	_restaurar_destaque()
	_parar_brilho()
	_reduzir_musica(false)


func cancelar_atual() -> void:
	_restaurar_camera_lenta()
	_parar_movimento_balao()
	balao.hide()
	_restaurar_destaque()
	_parar_brilho()
	_reduzir_musica(false)
	tutorial_ativo = ""
	finalizando = false
	praticou = false


func _destino_balao() -> Vector2:
	var tamanho_tela := get_viewport().get_visible_rect().size
	var margem := 14.0
	var destino := Vector2((tamanho_tela.x - balao.size.x) * 0.5, margem)
	match tutorial_ativo:
		"run":
			destino.x = tamanho_tela.x - balao.size.x - margem
		"tasks", "weapon", "reload", "weapon_flashlight":
			destino.x = margem
	destino.x = clampf(destino.x, margem, maxf(margem, tamanho_tela.x - balao.size.x - margem))
	return destino


func _animar_balao(entrando: bool) -> void:
	_parar_movimento_balao()
	if entrando:
		var estilo := balao.get_theme_stylebox("panel")
		var largura_conteudo := LARGURA_PAINEL - estilo.get_content_margin(SIDE_LEFT) - estilo.get_content_margin(SIDE_RIGHT)
		titulo.size.x = largura_conteudo
		explicacao.size.x = largura_conteudo
		var tamanho_fonte := explicacao.get_theme_font_size("normal_font_size")
		var texto_simples := explicacao.get_parsed_text()
		var altura_texto := explicacao.get_theme_font("normal_font").get_multiline_string_size(texto_simples, HORIZONTAL_ALIGNMENT_CENTER, largura_conteudo, tamanho_fonte).y
		if tutorial_ativo == "walk":
			altura_texto = maxf(altura_texto, explicacao.get_theme_font("bold_font").get_multiline_string_size(texto_simples, HORIZONTAL_ALIGNMENT_CENTER, largura_conteudo, tamanho_fonte).y)
		var altura_titulo := titulo.get_theme_font("font").get_height(titulo.get_theme_font_size("font_size"))
		var conteudo := balao.get_node("Content") as VBoxContainer
		var altura := altura_titulo + altura_texto + conteudo.get_theme_constant("separation") + estilo.get_content_margin(SIDE_TOP) + estilo.get_content_margin(SIDE_BOTTOM)
		balao.size = Vector2(LARGURA_PAINEL, ceilf(altura))
		posicao_repouso_balao = _destino_balao()
		balao.pivot_offset = balao.size * 0.5
		balao.position = posicao_repouso_balao - Vector2(0.0, 12.0)
		balao.scale = Vector2.ONE * 0.94
		balao.modulate.a = 0.0
		balao.show()
	transicao_balao = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	transicao_balao.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if entrando else Tween.EASE_IN)
	var duracao := DURACAO_ENTRADA if entrando else DURACAO_TRANSICAO
	transicao_balao.tween_property(balao, "position", posicao_repouso_balao if entrando else posicao_repouso_balao - Vector2(0.0, 8.0), duracao)
	transicao_balao.tween_property(balao, "scale", Vector2.ONE if entrando else Vector2.ONE * 0.98, duracao)
	transicao_balao.tween_property(balao, "modulate:a", 1.0 if entrando else 0.0, duracao).set_trans(Tween.TRANS_SINE)


func _parar_movimento_balao() -> void:
	if transicao_balao != null and transicao_balao.is_valid():
		transicao_balao.kill()
	transicao_balao = null


func _reduzir_musica(ativo: bool, imediato: bool = false) -> void:
	if not imediato and musica_reduzida == ativo:
		return
	musica_reduzida = ativo
	if transicao_musica != null and transicao_musica.is_valid():
		transicao_musica.kill()
	transicao_musica = null
	if not is_instance_valid(MusicController):
		return
	var fator_alvo := FATOR_MUSICA_TUTORIAL if ativo else 1.0
	if imediato:
		_aplicar_volume_tutorial(fator_alvo)
		return
	transicao_musica = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transicao_musica.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transicao_musica.tween_method(_aplicar_volume_tutorial, MusicController.fator_musica_tutorial, fator_alvo, DURACAO_TRANSICAO_MUSICA)


func _aplicar_volume_tutorial(fator: float) -> void:
	if not is_instance_valid(MusicController):
		return
	MusicController.definir_fator_musica_tutorial(fator)


func _iniciar_destaque() -> void:
	_restaurar_destaque(true)
	var hud := jogador.get_node("CanvasLayer/Control")
	for elemento in hud.get_children():
		if elemento is CanvasItem:
			_adicionar_alvo_destaque(elemento, tutorial_ativo == "run" and elemento.name == &"estamina")
	for item_id: String in jogador.inventory.slots_por_item:
		var destacado := tutorial_ativo == "collect"
		match tutorial_ativo:
			"weapon", "reload":
				destacado = item_id == "gun"
			"weapon_flashlight":
				destacado = item_id in ["gun", "lanterna"]
			"flashlight":
				destacado = item_id == "lanterna"
			"extinguisher":
				destacado = item_id == "extintor"
		if tutorial_ativo.begins_with("card_"):
			destacado = item_id == "cartao"
		_adicionar_alvo_destaque(jogador.inventory.slots_por_item[item_id], destacado)
	_adicionar_alvo_destaque(jogador.get_node("CanvasLayer/AmmoPanel"), tutorial_ativo in ["weapon", "reload", "weapon_flashlight"])
	_adicionar_alvo_destaque(jogador.get_node("CanvasLayer/AlarmTip"), false, ^"self_modulate:a")
	var cena := get_tree().current_scene
	if cena != null:
		_adicionar_alvo_destaque(cena.get_node_or_null("UI/Controle_de_tempo"), false)
	painel_destacado = jogador.get_node("QUEST_MISSION") as QuestMissionUI
	tarefas_destacadas = tutorial_ativo == "tasks"
	destaque_ativo = true
	transicao_destaque = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transicao_destaque.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transicao_destaque.tween_method(_aplicar_destaque, 0.0, 1.0, DURACAO_TRANSICAO)


func _adicionar_alvo_destaque(no: Node, destacado: bool, propriedade: NodePath = ^"modulate:a") -> void:
	if not no is CanvasItem:
		return
	alvos_destaque.append({"node": no, "property": propriedade, "original": no.get_indexed(propriedade), "focused": destacado})


func _aplicar_destaque(intensidade: float) -> void:
	intensidade_destaque = intensidade
	for alvo: Dictionary in alvos_destaque:
		var no: Object = alvo["node"]
		if is_instance_valid(no):
			var original: float = alvo["original"]
			var fator := 1.0 if bool(alvo["focused"]) else OPACIDADE_SEM_DESTAQUE
			no.set_indexed(alvo["property"], original * lerpf(1.0, fator, intensidade))
	if is_instance_valid(painel_destacado):
		var fator := 1.0 if tarefas_destacadas else OPACIDADE_SEM_DESTAQUE
		painel_destacado.definir_opacidade_tutorial(lerpf(1.0, fator, intensidade))


func _restaurar_destaque(imediato: bool = false) -> void:
	if not destaque_ativo and not imediato:
		return
	destaque_ativo = false
	if transicao_destaque != null and transicao_destaque.is_valid():
		transicao_destaque.kill()
	transicao_destaque = null
	if imediato:
		_aplicar_destaque(0.0)
		alvos_destaque.clear()
		painel_destacado = null
		return
	transicao_destaque = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	transicao_destaque.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transicao_destaque.tween_method(_aplicar_destaque, intensidade_destaque, 0.0, DURACAO_TRANSICAO)
	transicao_destaque.tween_callback(func() -> void:
		alvos_destaque.clear()
		painel_destacado = null
	)


func _iniciar_brilho() -> void:
	_parar_brilho()
	transicao_brilho = create_tween().set_ignore_time_scale(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	transicao_brilho.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transicao_brilho.tween_property(estilo_brilho, "shadow_color:a", 0.85, 0.9)
	transicao_brilho.tween_property(estilo_brilho, "shadow_color:a", 0.45, 0.9)


func _parar_brilho() -> void:
	if transicao_brilho != null and transicao_brilho.is_valid():
		transicao_brilho.kill()
	transicao_brilho = null


func protege_jogador(candidato: Player) -> bool:
	return candidato == jogador and controla_camera_lenta and not tutorial_ativo.is_empty()


func _tecla(action: StringName) -> String:
	var entradas := InputMap.action_get_events(action)
	if entradas.is_empty():
		return "tecla não definida"
	var evento: InputEvent = entradas[0]
	if evento is InputEventKey:
		return OS.get_keycode_string(evento.physical_keycode if evento.physical_keycode != KEY_NONE else evento.keycode)
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_LEFT:
			return "clique esquerdo"
		if evento.button_index == MOUSE_BUTTON_RIGHT:
			return "clique direito"
	return evento.as_text()


func _conteudo(id: String) -> Array[String]:
	match id:
		"walk":
			return ["MOVIMENTO", "Use %s/%s/%s/%s para andar pelo cenário." % [_tecla("up"), _tecla("left"), _tecla("down"), _tecla("right")]]
		"run":
			return ["CORRIDA", "Segure %s enquanto anda. Correr gasta estamina; caminhar permite recuperá-la." % _tecla("correr")]
		"push":
			return ["EMPURRAR E PUXAR", "Sem item equipado, aperte %s junto do objeto. Mova-o nas quatro direções; aperte novamente para soltar." % _tecla("empurrar")]
		"collect":
			return ["COLETAR ITENS", "Aproxime-se e aperte %s para coletar. A tecla abaixo de cada item no inventário permite equipá-lo ou guardá-lo." % _tecla("interact")]
		"card_1":
			return ["CARTÃO COMUM", "Abre acessos comuns. Equipe com %s e aperte %s junto ao leitor." % [_tecla("use_cartao"), _tecla("interact")]]
		"card_2":
			return ["CARTÃO DE ACESSO RESTRITO", "Abre áreas restritas. Equipe com %s e aperte %s junto ao leitor." % [_tecla("use_cartao"), _tecla("interact")]]
		"card_3":
			return ["CARTÃO DO CHEFE", "Tem o maior nível de acesso. Equipe com %s e aperte %s junto ao leitor." % [_tecla("use_cartao"), _tecla("interact")]]
		"flashlight":
			return ["LANTERNA", "Equipe ou guarde com %s. Aponte com o mouse e use %s para acender ou apagar." % [_tecla("use_lanterna"), _tecla("acende_lanterna")]]
		"extinguisher":
			return ["EXTINTOR", "Mire no fogo e segure %s para apagá-lo. A barra mostra a carga restante. Aperte %s para guardar o extintor." % [_tecla("usar_extintor"), _tecla("use_extintor")]]
		"weapon":
			return ["ARMA", "Equipe com %s, mire com o mouse e atire com %s. Não atire em NPCs." % [_tecla("use_arma"), _tecla("fire")]]
		"reload":
			return ["RECARREGAR", "Aperte %s para recarregar. É preciso ter munição na reserva." % _tecla("reload")]
		"weapon_flashlight":
			return ["ARMA E LANTERNA", "Com a arma equipada, use %s para acender a lanterna. Você pode iluminar e atirar ao mesmo tempo." % _tecla("use_lanterna")]
		"tasks":
			return ["SUAS TAREFAS", "O painel ficou oculto. Aperte %s para mostrá-lo novamente e conferir sua próxima tarefa." % _tecla("show_tasks")]
	return ["", ""]
