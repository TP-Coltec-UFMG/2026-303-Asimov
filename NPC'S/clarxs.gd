class_name PersonagemNPC
extends Node2D

signal npc_saiu
signal caminho_concluido(path: NPCPath)
signal solicitou_interacao(npc: Node2D)


@export_category("NPC")

@export var animacoes: SpriteFrames
@export var pegada_navegacao: Shape2D
@export var textos_dialogo: Array[String] = []
@export var dialogo_habilitado: bool = true
@export var id_dialogo: String = ""
@export var id_sequencia_dialogo: String = ""

@export var interacao_personalizada: bool = false
@export var texto_interacao: String = "ESPAÇO: FALAR"
@export var save_enabled: bool = true

@export var save_id: String = ""

var checkpoint_restored: bool = false


@export_category("NPC Movement")

@export var velocidade_caminhada: float = 30.0
@export var velocidade_corrida: float = 60.0
@export var desvio_multidao_habilitado: bool = false
@export var raio_chegada_saida: float = 24.0
@export var tempo_chegada_saida: float = 0.5



@export_category("Desespero")

@export var raio_desespero: float = 2
@export var distancia_minima_desespero: float = 1.5

@export var espera_minima_desespero: float = 0.05
@export var espera_maxima_desespero: float = 2

@export_range(0.0, 1.0) var chance_corrida_desespero: float = 0.9


var caminho_atual: NPCPath = null

var pontos_caminho: Array[Vector2] = []
var pontos_caminhos_salvos: Dictionary = {}

var ponto_atual: int = -1
var caminho_finalizado: bool = true
var tempo_na_saida: float = 0.0
var navegacao_obstaculos: Node2D
var pontos_navegacao := PackedVector2Array()
var indice_navegacao := 0
var destino_navegacao := Vector2.INF
var revisao_navegacao := -1
var destino_movimento := Vector2.INF


func definir_navegacao_obstaculos(navigator: Node2D) -> void:
	navegacao_obstaculos = navigator
	var body := $CharacterBody2D as CharacterBody2D
	body.collision_mask = 33
	($CharacterBody2D/CollisionShape2D as CollisionShape2D).shape = pegada_navegacao
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is PhysicsBody2D:
			body.add_collision_exception_with(player)


func _destino_sem_obstaculos(target: Vector2) -> Vector2:
	if not is_instance_valid(navegacao_obstaculos):
		return target
	if target != destino_navegacao or revisao_navegacao != navegacao_obstaculos.revision:
		destino_navegacao = target
		pontos_navegacao = navegacao_obstaculos.find_route(global_position, target)
		revisao_navegacao = navegacao_obstaculos.revision
		indice_navegacao = 0
	if pontos_navegacao.is_empty():
		return global_position
	while indice_navegacao < pontos_navegacao.size() - 1 and global_position.distance_to(pontos_navegacao[indice_navegacao]) <= 3.0:
		indice_navegacao += 1
	return pontos_navegacao[indice_navegacao]


var jogador_no_alcance: bool = false
var player_ref: Node2D = null

var last_direction: Vector2 = Vector2.DOWN


var desesperado: bool = false

var origem_desespero: Vector2 = Vector2.ZERO
var destino_desespero: Vector2 = Vector2.ZERO

var tempo_espera_desespero: float = 0.0

var tipo_movimento_desespero: int = NPCPath.MovementType.RUN


var rng := RandomNumberGenerator.new()


@onready var indicador_interacao: Label = $InteractionPrompt
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var agente_desvio: NavigationAgent2D = $CrowdAvoidance


func _ready() -> void:
	if not id_sequencia_dialogo.is_empty():
		textos_dialogo = DialogueCatalog.texts(id_sequencia_dialogo)
	rng.randomize()
	indicador_interacao.visible = false
	if desvio_multidao_habilitado:

		var body := $CharacterBody2D as CharacterBody2D
		body.collision_layer = 2
		body.collision_mask = 0

		agente_desvio.target_position = global_position + Vector2(100000.0, 100000.0)
		agente_desvio.avoidance_enabled = true
	configurar_animacoes()
	configurar_caminhos()
	if save_enabled:
		checkpoint_restored = SaveGame.register_checkpoint_actor(self, save_id)


func configurar_caminhos() -> void:
	pontos_caminhos_salvos.clear()

	var automatic_path: NPCPath = null

	for child in get_children():
		if child is NPCPath:
			var path: NPCPath = child

			var points: Array[Vector2] = []

			for point in path.points:
				var global_point: Vector2 = path.to_global(point)

				points.append(global_point)

			pontos_caminhos_salvos[path] = points

			if path.iniciar_automaticamente:
				if automatic_path == null:
					automatic_path = path
				else:
					push_warning("Mais de um caminho está com Start Automatically ativado.")

	if automatic_path != null:
		iniciar_caminho(automatic_path)
	else:
		caminho_finalizado = true
		reproduzir_parado(last_direction)


func _ao_solicitar_inicio_caminho(path: NPCPath) -> void:
	iniciar_caminho(path)


func iniciar_caminho(path: NPCPath) -> void:
	tempo_na_saida = 0.0
	destino_navegacao = Vector2.INF
	if path == null:
		return

	if not pontos_caminhos_salvos.has(path):
		push_warning(
			"O caminho '%s' não pertence a este NPC."
			% path.name
		)

		return

	desesperado = false
	tempo_espera_desespero = 0.0

	caminho_atual = path

	caminho_finalizado = false
	ponto_atual = 0

	pontos_caminho.clear()

	for point in pontos_caminhos_salvos[path]:
		pontos_caminho.append(point)

	if pontos_caminho.is_empty():
		caminho_atual = null

		ponto_atual = -1
		caminho_finalizado = true

		reproduzir_parado(last_direction)


func parar_caminho_atual() -> void:
	tempo_na_saida = 0.0
	caminho_atual = null

	pontos_caminho.clear()

	ponto_atual = -1
	caminho_finalizado = true

	desesperado = false
	tempo_espera_desespero = 0.0

	reproduzir_parado(last_direction)


func configurar_animacoes() -> void:
	if animacoes != null:
		sprite.sprite_frames = animacoes
	sprite.play(&"idle_down")


func _process(delta: float) -> void:
	_atualizar_indicador_interacao()
	if desvio_multidao_habilitado:
		if not desesperado and (caminho_atual == null or caminho_finalizado) and jogador_no_alcance and player_ref:
			atualizar_direcao()
		return

	if desesperado:
		atualizar_movimento_desespero(delta)
		return

	if caminho_atual != null and not caminho_finalizado:
		atualizar_movimento(delta)
		return

	if jogador_no_alcance and player_ref:
		atualizar_direcao()
		return


func _physics_process(delta: float) -> void:
	if not desvio_multidao_habilitado:
		return
	if _atualizar_chegada_saida(delta):
		return
	if desesperado:
		atualizar_movimento_desespero(delta)
	elif caminho_atual != null and not caminho_finalizado:
		atualizar_movimento(delta)
	elif jogador_no_alcance and is_instance_valid(player_ref):
		var away := global_position - player_ref.global_position
		agente_desvio.velocity = away.normalized() * velocidade_corrida if away.length_squared() < 256.0 else Vector2.ZERO
	else:
		agente_desvio.velocity = Vector2.ZERO


func _ao_calcular_velocidade_segura(safe_velocity: Vector2) -> void:
	if is_queued_for_deletion():
		return
	var delta := get_physics_process_delta_time()
	if is_instance_valid(navegacao_obstaculos):
		var body := $CharacterBody2D as CharacterBody2D
		var before := body.global_position
		body.velocity = safe_velocity
		body.move_and_slide()
		global_position += body.global_position - before
		body.position = Vector2.ZERO
	else:
		global_position += safe_velocity * delta
	if safe_velocity.length_squared() > 1.0:
		last_direction = safe_velocity.normalized()
		var kind := tipo_movimento_desespero if desesperado else (caminho_atual.tipo_movimento if caminho_atual != null else NPCPath.MovementType.RUN)
		atualizar_animacao_movimento(last_direction, kind)
	elif not desesperado and (caminho_atual == null or caminho_finalizado):
		reproduzir_parado(last_direction)

	if desesperado:
		var goal := destino_desespero
		if is_instance_valid(navegacao_obstaculos) and not pontos_navegacao.is_empty():
			goal = pontos_navegacao[-1]
		var tolerance := 3.0 if is_instance_valid(navegacao_obstaculos) else 2.0
		if global_position.distance_to(goal) <= tolerance:
			tempo_espera_desespero = rng.randf_range(espera_minima_desespero, espera_maxima_desespero)
			sortear_destino_desespero()
	elif caminho_atual != null and not caminho_finalizado and ponto_atual >= 0 and ponto_atual < pontos_caminho.size():
		var goal := pontos_caminho[ponto_atual]
		if is_instance_valid(navegacao_obstaculos) and not pontos_navegacao.is_empty():
			goal = pontos_navegacao[-1]
		var tolerance := 3.0 if is_instance_valid(navegacao_obstaculos) else 2.0
		if global_position.distance_to(goal) <= tolerance:
			avancar_ponto_caminho()


func _atualizar_chegada_saida(delta: float) -> bool:
	if caminho_atual == null or caminho_finalizado or not caminho_atual.remover_npc_ao_terminar or pontos_caminho.is_empty():
		tempo_na_saida = 0.0
		return false
	if global_position.distance_squared_to(pontos_caminho[-1]) > raio_chegada_saida * raio_chegada_saida:
		tempo_na_saida = 0.0
		return false
	tempo_na_saida += delta
	if tempo_na_saida < tempo_chegada_saida:
		return false
	agente_desvio.velocity = Vector2.ZERO
	ponto_atual = pontos_caminho.size() - 1
	avancar_ponto_caminho()
	return true


func atualizar_movimento(delta: float) -> void:
	if caminho_atual == null:
		return

	if caminho_finalizado:
		return

	if pontos_caminho.is_empty():
		return

	if ponto_atual < 0:
		return

	if ponto_atual >= pontos_caminho.size():
		return

	var target: Vector2 = pontos_caminho[ponto_atual]
	destino_movimento = _destino_sem_obstaculos(target)

	var speed: float = velocidade_caminhada

	if caminho_atual.tipo_movimento == NPCPath.MovementType.RUN:
		speed = velocidade_corrida

	var direction: Vector2 = global_position.direction_to(
		destino_movimento
	)

	if direction != Vector2.ZERO:
		last_direction = direction

	if desvio_multidao_habilitado:
		agente_desvio.velocity = direction * speed
	else:
		global_position = global_position.move_toward(target, speed * delta)

	atualizar_animacao_movimento(
		direction,
		caminho_atual.tipo_movimento
	)

	if not desvio_multidao_habilitado and global_position.distance_to(target) < 1.0:
		global_position = target

		avancar_ponto_caminho()


func avancar_ponto_caminho() -> void:
	ponto_atual += 1

	if ponto_atual < pontos_caminho.size():
		return

	if caminho_atual == null:
		return

	var finished_path: NPCPath = caminho_atual

	if finished_path.remover_npc_ao_terminar:
		caminho_concluido.emit(finished_path)
		if save_enabled:
			SaveGame.mark_checkpoint_actor_removed(self)
		npc_saiu.emit()
		queue_free()
		return

	if finished_path.repetir_caminho:
		ponto_atual = 0
		caminho_concluido.emit(finished_path)
		return

	if finished_path.sortear_ao_terminar:
		iniciar_modo_desespero()
		caminho_concluido.emit(finished_path)
		return

	caminho_finalizado = true
	ponto_atual = -1

	reproduzir_parado(last_direction)
	caminho_concluido.emit(finished_path)


func iniciar_modo_desespero() -> void:
	caminho_finalizado = true
	ponto_atual = -1

	desesperado = true

	origem_desespero = global_position

	tempo_espera_desespero = 0.0

	sortear_destino_desespero()


func sortear_destino_desespero() -> void:
	var random_angle: float = rng.randf_range(
		0.0,
		TAU
	)

	var min_distance: float = min(
		distancia_minima_desespero,
		raio_desespero
	)

	var max_distance: float = max(
		distancia_minima_desespero,
		raio_desespero
	)

	var random_distance: float = rng.randf_range(
		min_distance,
		max_distance
	)

	var offset: Vector2 = Vector2.RIGHT.rotated(
		random_angle
	) * random_distance

	destino_desespero = origem_desespero + offset

	if rng.randf() <= chance_corrida_desespero:
		tipo_movimento_desespero = NPCPath.MovementType.RUN
	else:
		tipo_movimento_desespero = NPCPath.MovementType.WALK


func atualizar_movimento_desespero(
	delta: float
) -> void:
	if tempo_espera_desespero > 0.0:
		tempo_espera_desespero -= delta
		if desvio_multidao_habilitado:
			agente_desvio.velocity = Vector2.ZERO

		reproduzir_parado(last_direction)

		return

	var direction: Vector2 = global_position.direction_to(_destino_sem_obstaculos(destino_desespero))

	if direction != Vector2.ZERO:
		last_direction = direction

	var speed: float = velocidade_caminhada

	if tipo_movimento_desespero == NPCPath.MovementType.RUN:
		speed = velocidade_corrida

	if desvio_multidao_habilitado:
		agente_desvio.velocity = direction * speed
	else:
		global_position = global_position.move_toward(destino_desespero, speed * delta)

	atualizar_animacao_movimento(
		direction,
		tipo_movimento_desespero
	)

	if not desvio_multidao_habilitado and global_position.distance_to(
		destino_desespero
	) < 0.2:
		global_position = destino_desespero

		tempo_espera_desespero = rng.randf_range(
			espera_minima_desespero,
			espera_maxima_desespero
		)

		sortear_destino_desespero()


func atualizar_animacao_movimento(
	direction: Vector2,
	movement_kind: int
) -> void:
	if direction == Vector2.ZERO:
		reproduzir_parado(last_direction)
		return

	var animation_prefix := "walk"

	if movement_kind == NPCPath.MovementType.RUN:
		animation_prefix = "run"

	if abs(direction.x) > abs(direction.y):
		sprite.play(
			animation_prefix + "_side"
		)

		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	else:
		sprite.flip_h = false

		if direction.y > 0:
			sprite.play(
				animation_prefix + "_down"
			)

		else:
			sprite.play(
				animation_prefix + "_up"
			)


func reproduzir_parado(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		sprite.play("idle_side")

		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	else:
		sprite.flip_h = false

		if direction.y > 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")


func _unhandled_input(
	event: InputEvent
) -> void:
	if (
		tem_dialogo()
		and jogador_no_alcance
		and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"))
		and not DialogManager.is_showing_dialog
	):
		if interacao_personalizada:
			solicitou_interacao.emit(self)
			get_viewport().set_input_as_handled()
			return
		if not id_sequencia_dialogo.is_empty():
			DialogManager.start_catalog_dialog(id_sequencia_dialogo, id_dialogo)
		else:
			DialogManager.start_dialog(textos_dialogo, id_dialogo)
		get_viewport().set_input_as_handled()


func _on_area_2d_body_entered(body) -> void:
	if body is Player:
		jogador_no_alcance = true

		player_ref = body

		indicador_interacao.visible = tem_dialogo()


func _on_area_2d_body_exited(body) -> void:
	if body is Player:
		jogador_no_alcance = false

		player_ref = null

		indicador_interacao.visible = false


func definir_dialogo_habilitado(value: bool) -> void:
	dialogo_habilitado = value
	indicador_interacao.visible = tem_dialogo() and jogador_no_alcance


func configurar_interacao_personalizada(value: bool, prompt: String = "ESPAÇO: FALAR") -> void:
	interacao_personalizada = value
	texto_interacao = prompt
	_atualizar_indicador_interacao()


func tem_dialogo() -> bool:
	return interacao_personalizada or (
		dialogo_habilitado and not textos_dialogo.is_empty()
	)


func _atualizar_indicador_interacao() -> void:
	indicador_interacao.text = texto_interacao
	indicador_interacao.visible = (
		tem_dialogo()
		and jogador_no_alcance
		and not DialogManager.is_showing_dialog
	)


func atualizar_direcao() -> void:
	if player_ref == null:
		return

	var dir: Vector2 = (
		player_ref.global_position
		- global_position
	)

	if dir == Vector2.ZERO:
		return

	last_direction = dir

	reproduzir_parado(dir)


func get_checkpoint_state() -> Dictionary:
	var paths: Dictionary = {}
	for path: NPCPath in pontos_caminhos_salvos:
		paths[str(get_path_to(path))] = PackedVector2Array(pontos_caminhos_salvos[path])
	return {
		"version": 1,
		"position": global_position,
		"current_path": str(get_path_to(caminho_atual)) if caminho_atual != null else "",
		"current_point": ponto_atual,
		"path_finished": caminho_finalizado,
		"path_points": PackedVector2Array(pontos_caminho),
		"cached_paths": paths,
		"last_direction": last_direction,
		"desperate": desesperado,
		"desperate_origin": origem_desespero,
		"desperate_target": destino_desespero,
		"desperate_wait_timer": tempo_espera_desespero,
		"desperate_movement_type": tipo_movimento_desespero,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"animation": sprite.animation,
		"frame": sprite.frame,
		"frame_progress": sprite.frame_progress,
		"animation_playing": sprite.is_playing(),
		"animation_speed": sprite.speed_scale,
		"flip_h": sprite.flip_h
	}


func load_checkpoint_state(saved: Dictionary) -> void:
	tempo_na_saida = 0.0
	if saved.get("version", 0) != 1 or not saved.get("position") is Vector2:
		push_warning("Estado de NPC incompatível: " + str(name))
		return
	global_position = saved["position"]
	last_direction = saved.get("last_direction", Vector2.DOWN)

	var paths: Variant = saved.get("cached_paths", {})
	if paths is Dictionary:
		for path_id in paths:
			var path := get_node_or_null(NodePath(str(path_id))) as NPCPath
			if path != null and pontos_caminhos_salvos.has(path) and paths[path_id] is PackedVector2Array:
				var points: Array[Vector2] = []
				points.assign(paths[path_id])
				pontos_caminhos_salvos[path] = points
	caminho_atual = null
	pontos_caminho.clear()
	var active_path: String = str(saved.get("current_path", ""))
	if not active_path.is_empty():
		caminho_atual = get_node_or_null(NodePath(active_path)) as NPCPath
		if not pontos_caminhos_salvos.has(caminho_atual):
			caminho_atual = null
	if caminho_atual != null:
		var points: Variant = saved.get("path_points")
		if points is PackedVector2Array:
			pontos_caminho.assign(points)
		else:
			pontos_caminho.assign(pontos_caminhos_salvos[caminho_atual])
	ponto_atual = int(saved.get("current_point", -1))
	caminho_finalizado = bool(saved.get("path_finished", true))
	desesperado = bool(saved.get("desperate", false))
	origem_desespero = saved.get("desperate_origin", global_position)
	destino_desespero = saved.get("desperate_target", global_position)
	tempo_espera_desespero = float(saved.get("desperate_wait_timer", 0.0))
	tipo_movimento_desespero = int(saved.get("desperate_movement_type", NPCPath.MovementType.RUN))
	if not desesperado and not caminho_finalizado and (caminho_atual == null or ponto_atual < 0 or ponto_atual >= pontos_caminho.size()):

		push_warning("Rota salva indisponível; NPC permanece na posição salva: " + str(name))
		parar_caminho_atual()
	if saved.has("rng_seed"):
		rng.seed = int(saved["rng_seed"])
	if saved.has("rng_state"):
		rng.state = int(saved["rng_state"])

	jogador_no_alcance = false
	player_ref = null
	indicador_interacao.hide()
	var animation: StringName = saved.get("animation", &"idle_down")
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)
		sprite.speed_scale = float(saved.get("animation_speed", 1.0))
		sprite.set_frame_and_progress(int(saved.get("frame", 0)), float(saved.get("frame_progress", 0.0)))
		sprite.flip_h = bool(saved.get("flip_h", false))
		if not saved.get("animation_playing", true):
			sprite.pause()
