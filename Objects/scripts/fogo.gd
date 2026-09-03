extends Node2D

@export var save_id: String = "fogo01"
@export var save_enabled: bool = true
@export var damage_enabled: bool = true

@onready var particulas: GPUParticles2D = $GPUParticles2D
@onready var area_fogo: Area2D = $AreaFogo
@onready var collision_fogo: CollisionShape2D = $AreaFogo/CollisionShape2D
@onready var point_light_2d: PointLight2D = $PointLight2D

var corpo_no_fogo: Player = null
var dar_dano_no_corpo: bool = false
var formas_player_no_fogo: int = 0
var mat_particulas: ParticleProcessMaterial = null
var vida_fogo: float = 100.0
var apagado: bool = false
var extintor_atingindo: bool = false
var gravidade_original: Vector3 = Vector3.ZERO
var escala_particulas_original: Vector2 = Vector2.ONE
var escala_collision_original: Vector2 = Vector2.ONE
var acumulador_visual: float = 0.0
var acumulador_dano: float = 0.0
var ultima_escala_collision: float = 1.0

const VELOCIDADE_APAGAR: float = 25.0
const ALTURA_MINIMA: float = 0.20
const LARGURA_MINIMA: float = 0.45
const TAMANHO_MINIMO_AREA: float = 0.25
const INTERVALO_ATUALIZACAO_VISUAL: float = 0.05
const PASSO_ATUALIZACAO_COLLISION: float = 0.05
const INTERVALO_DANO: float = 0.10
const DANO_POR_TICK: int = 10

signal fogo_apagou

func _ready() -> void:
	if particulas.process_material is ParticleProcessMaterial:
		mat_particulas = particulas.process_material.duplicate()
		particulas.process_material = mat_particulas
		gravidade_original = mat_particulas.gravity

	escala_particulas_original = particulas.scale
	escala_collision_original = collision_fogo.scale
	particulas.amount_ratio = 1.0
	set_process(false)

	# Cenas isoladas como o tutorial usam o fogo real sem tocar na campanha.
	var estado_salvo: Variant = null
	if save_enabled:
		estado_salvo = SaveGame.load_object_state(save_id)

	if estado_salvo != null:
		vida_fogo = estado_salvo.get("vida_fogo", 100.0)

		if estado_salvo.get("apagado", false):
			restaurar_fogo_apagado()
		else:
			atualizar_fogo()


func _process(delta: float) -> void:
	if apagado:
		set_process(false)
		return

	atualizar_dano(delta)
	atualizar_extincao(delta)

	if not extintor_atingindo and not dar_dano_no_corpo:
		set_process(false)


func atualizar_dano(delta: float) -> void:
	if not dar_dano_no_corpo:
		acumulador_dano = 0.0
		return

	if corpo_no_fogo == null:
		acumulador_dano = 0.0
		return

	acumulador_dano += delta

	if acumulador_dano < INTERVALO_DANO:
		return

	var quantidade_ticks: int = int(acumulador_dano / INTERVALO_DANO)
	acumulador_dano -= float(quantidade_ticks) * INTERVALO_DANO
	corpo_no_fogo.tomar_dano(DANO_POR_TICK * quantidade_ticks)


func atualizar_extincao(delta: float) -> void:
	if not extintor_atingindo:
		return

	vida_fogo -= VELOCIDADE_APAGAR * delta

	if vida_fogo < 0:
		vida_fogo = 0

	acumulador_visual += delta

	if acumulador_visual >= INTERVALO_ATUALIZACAO_VISUAL:
		acumulador_visual = 0.0
		atualizar_fogo()

		if save_enabled:
			SaveGame.save_object_state(save_id, {
				"apagado": false,
				"vida_fogo": vida_fogo
			})

	if vida_fogo <= 0:
		atualizar_fogo()
		apagar_fogo()


func iniciar_extincao() -> void:
	if apagado:
		return

	if extintor_atingindo:
		return

	extintor_atingindo = true
	acumulador_visual = INTERVALO_ATUALIZACAO_VISUAL
	set_process(true)


func parar_extincao() -> void:
	if apagado:
		return

	extintor_atingindo = false

	if not dar_dano_no_corpo:
		set_process(false)


func atualizar_fogo() -> void:
	if mat_particulas == null:
		return

	var porcentagem: float = clampf(vida_fogo / 100.0, 0.0, 1.0)
	var escala_largura: float = lerpf(LARGURA_MINIMA, 1.0, porcentagem)
	var escala_altura: float = lerpf(ALTURA_MINIMA, 1.0, porcentagem)
	var escala_area: float = lerpf(TAMANHO_MINIMO_AREA, 1.0, porcentagem)

	point_light_2d.energy = porcentagem
	particulas.amount_ratio = porcentagem

	particulas.scale = Vector2(
		escala_particulas_original.x * escala_largura,
		escala_particulas_original.y * escala_altura
	)

	mat_particulas.gravity = gravidade_original * porcentagem

	if absf(escala_area - ultima_escala_collision) >= PASSO_ATUALIZACAO_COLLISION or vida_fogo <= 0:
		collision_fogo.scale = escala_collision_original * escala_area
		ultima_escala_collision = escala_area


func apagar_fogo() -> void:
	if apagado:
		return

	apagado = true

	if save_enabled:
		SaveGame.save_object_state(save_id, {
			"apagado": true,
			"vida_fogo": vida_fogo
		})

	extintor_atingindo = false
	dar_dano_no_corpo = false
	set_process(false)

	point_light_2d.energy = 0
	particulas.amount_ratio = 0.0
	particulas.emitting = false
	area_fogo.monitorable = false
	area_fogo.monitoring = false
	collision_fogo.set_deferred("disabled", true)

	await get_tree().create_timer(particulas.lifetime).timeout
	
	var player := get_tree().get_first_node_in_group("player") as Player

	if save_enabled and player != null:
		SaveGame.create_checkpoint(player)
	
	fogo_apagou.emit()
	queue_free()
	


func restaurar_fogo_apagado() -> void:
	apagado = true
	extintor_atingindo = false
	dar_dano_no_corpo = false

	point_light_2d.energy = 0
	particulas.amount_ratio = 0.0
	particulas.emitting = false

	area_fogo.monitorable = false
	area_fogo.monitoring = false
	collision_fogo.set_deferred("disabled", true)

	queue_free()


func _on_area_fogo_body_shape_entered(
	_body_rid: RID,
	body: Node2D,
	_body_shape_index: int,
	_local_shape_index: int
) -> void:
	if damage_enabled and body is Player:
		corpo_no_fogo = body
		formas_player_no_fogo += 1
		dar_dano_no_corpo = true
		set_process(true)


func _on_area_fogo_body_shape_exited(
	_body_rid: RID,
	body: Node2D,
	_body_shape_index: int,
	_local_shape_index: int
) -> void:
	if body is Player and body == corpo_no_fogo:
		formas_player_no_fogo = maxi(formas_player_no_fogo - 1, 0)

		if formas_player_no_fogo <= 0:
			corpo_no_fogo = null
			dar_dano_no_corpo = false
			acumulador_dano = 0.0

			if not extintor_atingindo:
				set_process(false)
