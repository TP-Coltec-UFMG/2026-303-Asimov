class_name SecurityDrone
extends CharacterBody2D

enum DroneState {
	DORMANT,
	PATROL,
	ALERT,
	CHASE,
	COOLDOWN,
	DESTROYED
}

const PATROL_SPEED: float = 24.0
const CHASE_SPEED: float = 43.0
const PATROL_ACCELERATION: float = 72.0
const CHASE_ACCELERATION: float = 135.0
const BRAKE_ACCELERATION: float = 170.0
const TURN_RESPONSE: float = 8.0
const MAX_FLIGHT_TILT: float = 0.11
const FLIGHT_TILT_RESPONSE: float = 7.0
const DETECTION_RANGE: float = 125.0
const LOST_RANGE: float = 165.0
const FIELD_OF_VIEW_COSINE: float = 0.57
const ALERT_DURATION: float = 0.55
const LOST_SIGHT_DURATION: float = 1.25
const CHASE_LIMIT: float = 6.0
const COOLDOWN_DURATION: float = 2.4
const PREFERRED_DISTANCE: float = 82.0
const RETREAT_DISTANCE: float = 58.0
const SHOT_INTERVAL: float = 1.05
const SHOT_TELEGRAPH_DURATION: float = 0.32
const MAX_HEALTH: float = 75.0
const ROOM_BOUNDS: Rect2 = Rect2(-205.0, -76.0, 470.0, 274.0)
const DRONE_PROJECTILE := preload("res://Objects/drone_projectile.tscn")
const DIFFICULTY_SETTINGS := preload("res://Scripts/Data/difficulty_settings.gd")

@export var pontos_patrulha: Array[Vector2] = [
	Vector2(-164, -48),
	Vector2(-112, 8),
	Vector2(-15, 10),
	Vector2(78, 35),
	Vector2(181, 62),
	Vector2(220, 105),
	Vector2(122, 146),
	Vector2(18, 177),
	Vector2(-82, 126),
	Vector2(-137, 63)
]
@export var salvar_estado_missao: bool = true

@onready var visao: RayCast2D = $Visao
@onready var sprite_animada: AnimatedSprite2D = $AnimatedSprite2D
@onready var cone_visao: Polygon2D = $VisionCone
@onready var luz_alerta: PointLight2D = $AlertLight
@onready var som_alerta: AudioStreamPlayer2D = $AlertSfx
@onready var som_tiro: AudioStreamPlayer2D = $ShotSfx
@onready var som_explosao: AudioStreamPlayer2D = $ExplosionSfx
@onready var faiscas_dano: CPUParticles2D = $HitSparks
@onready var aviso_tiro: Line2D = $ShotWarning
@onready var clarao_tiro: Node2D = $MuzzleFlash
@onready var barra_vida: Node2D = $HealthBar
@onready var preenchimento_vida: ColorRect = $HealthBar/Fill
@onready var clarao_explosao: Polygon2D = $ExplosionVisuals/Flash
@onready var onda_explosao: Line2D = $ExplosionVisuals/Shockwave

var estado_drone: DroneState = DroneState.DORMANT
var jogador_atual: Player
var indice_patrulha: int = 0
var sentido_patrulha: int = 1
var direcao_visao: Vector2 = Vector2.RIGHT
var velocidade_desejada: Vector2 = Vector2.ZERO
var fase_voo: float = 0.0
var tempo_estado: float = 0.0
var tempo_sem_visao: float = 0.0
var tempo_tiro: float = 0.0
var vida_atual: float = MAX_HEALTH
var destruido: bool = false
var animacao_morte_ativa: bool = false
var sentido_lateral: float = 1.0
var tween_dano: Tween
var tempo_preparo_tiro: float = 0.0
var tween_disparo: Tween
var tween_explosao: Tween
var vida_maxima: float = MAX_HEALTH
var multiplicador_velocidade: float = 1.0
var alcance_deteccao: float = DETECTION_RANGE
var duracao_alerta: float = ALERT_DURATION
var intervalo_tiro: float = SHOT_INTERVAL
var duracao_aviso_tiro: float = SHOT_TELEGRAPH_DURATION
var velocidade_projetil: float = 145.0
var dano_projetil: float = 18.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_aplicar_dificuldade()
	indice_patrulha = randi_range(0, maxi(0, pontos_patrulha.size() - 1))
	sentido_patrulha = 1 if randf() >= 0.5 else -1
	sentido_lateral = 1.0 if randf() >= 0.5 else -1.0
	fase_voo = randf_range(0.0, TAU)
	_desativar()
	_atualizar_estado_missao.call_deferred()


func _aplicar_dificuldade() -> void:
	var profile := DIFFICULTY_SETTINGS.drone_profile()
	vida_maxima = float(profile.get("health", MAX_HEALTH))
	multiplicador_velocidade = float(profile.get("speed_multiplier", 1.0))
	alcance_deteccao = float(profile.get("detection_range", DETECTION_RANGE))
	duracao_alerta = float(profile.get("alert_duration", ALERT_DURATION))
	intervalo_tiro = float(profile.get("shot_interval", SHOT_INTERVAL))
	duracao_aviso_tiro = float(profile.get("shot_telegraph", SHOT_TELEGRAPH_DURATION))
	velocidade_projetil = float(profile.get("projectile_speed", 145.0))
	dano_projetil = float(profile.get("projectile_damage", 18.0))
	vida_atual = vida_maxima


func _physics_process(delta: float) -> void:
	if estado_drone == DroneState.DORMANT or estado_drone == DroneState.DESTROYED:
		return
	tempo_tiro = maxf(0.0, tempo_tiro - delta)
	if not _pode_perseguir_jogador():
		velocidade_desejada = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE_ACCELERATION * multiplicador_velocidade * delta)
		return
	fase_voo = fmod(fase_voo + delta * 3.1, TAU)
	tempo_estado += delta
	match estado_drone:
		DroneState.PATROL:
			_atualizar_patrulha(delta)
		DroneState.ALERT:
			_atualizar_alerta(delta)
		DroneState.CHASE:
			_atualizar_perseguicao(delta)
		DroneState.COOLDOWN:
			_atualizar_espera(delta)
	_aplicar_aceleracao_voo(delta)
	move_and_slide()
	position = Vector2(
		clampf(position.x, ROOM_BOUNDS.position.x, ROOM_BOUNDS.end.x),
		clampf(position.y, ROOM_BOUNDS.position.y, ROOM_BOUNDS.end.y)
	)
	_atualizar_direcao_visao(delta)
	_atualizar_visual_voo(delta)
	_atualizar_barra_vida()


func _atualizar_estado_missao() -> void:
	jogador_atual = _encontrar_jogador()
	if not is_instance_valid(jogador_atual):
		_desativar()
		return
	var mission: Dictionary = SaveGame.office_mission_state(jogador_atual)
	var programmer_active := (
		bool(mission.get("programmer_ending_started", false))
		and not bool(mission.get("programmer_ending_completed", false))
	)
	var engineer_active := (
		bool(mission.get("engineer_ending_started", false))
		and not bool(mission.get("engineer_ending_completed", false))
	)
	var final_active := programmer_active or engineer_active
	if not final_active:
		if not animacao_morte_ativa:
			_desativar()
		return
	if salvar_estado_missao:
		destruido = bool(mission.get("security_drone_destroyed", false))
	if destruido:
		if not animacao_morte_ativa and estado_drone != DroneState.DESTROYED:
			_mostrar_destrocado()
		return
	if estado_drone == DroneState.DORMANT or estado_drone == DroneState.DESTROYED:
		_ativar()


func _encontrar_jogador() -> Player:
	var scene := get_parent() as BaseScene
	if scene != null and is_instance_valid(scene.player):
		return scene.player
	return get_tree().get_first_node_in_group("player") as Player


func _ativar() -> void:
	estado_drone = DroneState.PATROL
	tempo_estado = 0.0
	tempo_sem_visao = 0.0
	tempo_tiro = 0.35
	tempo_preparo_tiro = 0.0
	vida_atual = vida_maxima
	velocity = Vector2.ZERO
	velocidade_desejada = Vector2.ZERO
	collision_layer = 2
	z_index = 30
	rotation = 0.0
	sprite_animada.position = Vector2.ZERO
	sprite_animada.rotation = 0.0
	sprite_animada.scale = Vector2(0.29, 0.29)
	sprite_animada.modulate = Color.WHITE
	visible = true
	sprite_animada.play(&"fly")
	cone_visao.visible = true
	luz_alerta.visible = false
	aviso_tiro.hide()
	clarao_tiro.hide()
	barra_vida.show()
	_atualizar_barra_vida()


func _desativar() -> void:
	estado_drone = DroneState.DORMANT
	velocity = Vector2.ZERO
	velocidade_desejada = Vector2.ZERO
	visible = false
	aviso_tiro.hide()
	barra_vida.hide()
	if is_instance_valid(sprite_animada):
		sprite_animada.stop()


func _pode_perseguir_jogador() -> bool:
	return (
		is_instance_valid(jogador_atual)
		and jogador_atual.is_inside_tree()
		and jogador_atual.is_visible_in_tree()
		and jogador_atual.can_process()
		and jogador_atual.is_physics_processing()
	)


func _atualizar_patrulha(_delta: float) -> void:
	cone_visao.color = Color(1.0, 0.74, 0.18, 0.13)
	luz_alerta.visible = false
	if pontos_patrulha.is_empty():
		velocidade_desejada = Vector2.ZERO
		return
	var target := pontos_patrulha[indice_patrulha]
	var offset := target - position
	if offset.length() < 5.0:
		indice_patrulha = posmod(indice_patrulha + sentido_patrulha, pontos_patrulha.size())
		target = pontos_patrulha[indice_patrulha]
		offset = target - position
	var speed_pulse := 1.0 + sin(fase_voo) * 0.06
	velocidade_desejada = offset.normalized() * PATROL_SPEED * multiplicador_velocidade * speed_pulse
	if _pode_ver_jogador(alcance_deteccao, true):
		_iniciar_alerta()


func _iniciar_alerta() -> void:
	estado_drone = DroneState.ALERT
	tempo_estado = 0.0
	velocidade_desejada = Vector2.ZERO
	cone_visao.color = Color(1.0, 0.08, 0.04, 0.27)
	luz_alerta.visible = true
	som_alerta.pitch_scale = 1.0
	som_alerta.play()


func _atualizar_alerta(delta: float) -> void:
	velocidade_desejada = Vector2.ZERO
	_virar_para_jogador(delta)
	if tempo_estado >= duracao_alerta:
		estado_drone = DroneState.CHASE
		tempo_estado = 0.0
		tempo_sem_visao = 0.0


func _atualizar_perseguicao(delta: float) -> void:
	cone_visao.color = Color(1.0, 0.04, 0.02, 0.31)
	luz_alerta.visible = true
	var offset := jogador_atual.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized()
	_virar_para_jogador(delta)
	if tempo_preparo_tiro > 0.0:
		tempo_preparo_tiro -= delta
		velocidade_desejada = Vector2.ZERO
		_atualizar_aviso_tiro()
		if tempo_preparo_tiro <= 0.0:
			_atirar_no_jogador(direction)
	elif distance < RETREAT_DISTANCE:
		velocidade_desejada = -direction * CHASE_SPEED * multiplicador_velocidade
	elif distance > PREFERRED_DISTANCE + 18.0:
		velocidade_desejada = direction * CHASE_SPEED * multiplicador_velocidade
	else:
		velocidade_desejada = direction.orthogonal() * CHASE_SPEED * multiplicador_velocidade * 0.55 * sentido_lateral
	velocidade_desejada *= 1.0 + sin(fase_voo * 1.35) * 0.08
	if tempo_tiro <= 0.0 and tempo_preparo_tiro <= 0.0 and _pode_ver_jogador(LOST_RANGE, false):
		_iniciar_aviso_tiro()
	if _pode_ver_jogador(LOST_RANGE, false):
		tempo_sem_visao = 0.0
	else:
		tempo_sem_visao += delta
	if tempo_sem_visao >= LOST_SIGHT_DURATION or tempo_estado >= CHASE_LIMIT:
		_iniciar_espera()


func _iniciar_espera() -> void:
	estado_drone = DroneState.COOLDOWN
	tempo_estado = 0.0
	velocidade_desejada = -direcao_visao * PATROL_SPEED * multiplicador_velocidade
	cone_visao.color = Color(0.35, 0.7, 1.0, 0.1)
	luz_alerta.visible = false
	tempo_preparo_tiro = 0.0
	aviso_tiro.hide()


func _atualizar_espera(_delta: float) -> void:
	if tempo_estado < 0.55:
		velocidade_desejada = -direcao_visao * PATROL_SPEED * multiplicador_velocidade
	else:
		velocidade_desejada = Vector2.ZERO
	if tempo_estado >= COOLDOWN_DURATION:
		estado_drone = DroneState.PATROL
		tempo_estado = 0.0
		tempo_sem_visao = 0.0
		tempo_tiro = 0.25


func _atirar_no_jogador(direction: Vector2) -> void:
	if not is_instance_valid(jogador_atual):
		return
	var projectile := DRONE_PROJECTILE.instantiate() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 9.0
	projectile.call("configurar", direction, velocidade_projetil, dano_projetil)
	tempo_tiro = intervalo_tiro
	aviso_tiro.hide()
	_mostrar_clarao_tiro()
	som_tiro.pitch_scale = randf_range(0.94, 1.08)
	som_tiro.play()


func _iniciar_aviso_tiro() -> void:
	tempo_preparo_tiro = duracao_aviso_tiro
	aviso_tiro.show()
	som_alerta.pitch_scale = 1.35
	som_alerta.play()
	_atualizar_aviso_tiro()


func _atualizar_aviso_tiro() -> void:
	if not is_instance_valid(jogador_atual):
		aviso_tiro.hide()
		return
	aviso_tiro.points = PackedVector2Array([
		Vector2.ZERO,
		to_local(jogador_atual.global_position)
	])
	var progress := 1.0 - clampf(tempo_preparo_tiro / duracao_aviso_tiro, 0.0, 1.0)
	aviso_tiro.width = lerpf(0.65, 1.8, progress)
	aviso_tiro.modulate.a = lerpf(0.25, 1.0, progress)


func _mostrar_clarao_tiro() -> void:
	if tween_disparo != null and tween_disparo.is_valid():
		tween_disparo.kill()
	clarao_tiro.position = direcao_visao * 8.0
	clarao_tiro.rotation = direcao_visao.angle() - rotation
	clarao_tiro.scale = Vector2.ONE
	clarao_tiro.modulate.a = 1.0
	clarao_tiro.show()
	tween_disparo = create_tween()
	tween_disparo.set_parallel(true)
	tween_disparo.tween_property(clarao_tiro, "scale", Vector2(1.7, 1.7), 0.09)
	tween_disparo.tween_property(clarao_tiro, "modulate:a", 0.0, 0.1)
	await tween_disparo.finished
	if is_instance_valid(clarao_tiro):
		clarao_tiro.hide()


func receber_dano_projetil(amount: float) -> void:
	if destruido or estado_drone == DroneState.DORMANT or amount <= 0.0:
		return
	vida_atual = maxf(0.0, vida_atual - amount)
	_atualizar_barra_vida()
	_mostrar_dano()
	if vida_atual <= 0.0:
		_destruir_drone()
	elif estado_drone == DroneState.PATROL:
		_iniciar_alerta()


func _mostrar_dano() -> void:
	if tween_dano != null and tween_dano.is_valid():
		tween_dano.kill()
	faiscas_dano.restart()
	faiscas_dano.emitting = true
	som_alerta.pitch_scale = randf_range(1.75, 2.05)
	som_alerta.play()
	sprite_animada.modulate = Color(0.35, 0.95, 1.0, 1.0)
	sprite_animada.position = Vector2.ZERO
	tween_dano = create_tween()
	tween_dano.tween_property(sprite_animada, "position", Vector2(-2, 1), 0.025)
	tween_dano.tween_property(sprite_animada, "position", Vector2(2, -1), 0.025)
	tween_dano.tween_property(sprite_animada, "position", Vector2(-1, -2), 0.025)
	tween_dano.tween_property(sprite_animada, "position", Vector2.ZERO, 0.035)
	tween_dano.parallel().tween_property(sprite_animada, "modulate", Color.WHITE, 0.12)


func _destruir_drone() -> void:
	destruido = true
	animacao_morte_ativa = true
	estado_drone = DroneState.DESTROYED
	velocity = Vector2.ZERO
	velocidade_desejada = Vector2.ZERO
	collision_layer = 0
	cone_visao.visible = false
	aviso_tiro.hide()
	barra_vida.hide()
	som_tiro.stop()
	som_explosao.play()
	faiscas_dano.emitting = false
	_reproduzir_explosao()
	luz_alerta.visible = true
	luz_alerta.color = Color(1.0, 0.35, 0.04, 1.0)
	luz_alerta.energy = 1.8
	sprite_animada.stop()
	if tween_dano != null and tween_dano.is_valid():
		tween_dano.kill()
	sprite_animada.position = Vector2.ZERO
	if salvar_estado_missao:
		var mission: Dictionary = SaveGame.office_mission_state(jogador_atual)
		mission["security_drone_destroyed"] = true
		SaveGame.save_global_state("hall_quest_01", mission)
	var fall_side := 1.0 if randf() >= 0.5 else -1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_animada, "position", Vector2(5.0 * fall_side, 10.0), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite_animada, "rotation", 1.15 * fall_side, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite_animada, "scale", Vector2(0.29, 0.12), 0.48)
	tween.tween_property(sprite_animada, "modulate", Color(0.34, 0.38, 0.4, 1.0), 0.48)
	tween.tween_property(luz_alerta, "energy", 0.0, 0.22)
	await tween.finished
	luz_alerta.visible = false
	z_index = 3
	animacao_morte_ativa = false


func _reproduzir_explosao() -> void:
	clarao_explosao.scale = Vector2(0.25, 0.25)
	clarao_explosao.modulate.a = 1.0
	clarao_explosao.show()
	onda_explosao.scale = Vector2(0.3, 0.3)
	onda_explosao.modulate.a = 1.0
	onda_explosao.show()
	if tween_explosao != null and tween_explosao.is_valid():
		tween_explosao.kill()
	tween_explosao = create_tween()
	tween_explosao.set_parallel(true)
	tween_explosao.tween_property(clarao_explosao, "scale", Vector2(2.4, 2.4), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_explosao.tween_property(clarao_explosao, "modulate:a", 0.0, 0.42)
	tween_explosao.tween_property(onda_explosao, "scale", Vector2(3.2, 3.2), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_explosao.tween_property(onda_explosao, "modulate:a", 0.0, 0.5)
	await tween_explosao.finished
	if is_instance_valid(clarao_explosao):
		clarao_explosao.hide()
	if is_instance_valid(onda_explosao):
		onda_explosao.hide()


func _mostrar_destrocado() -> void:
	destruido = true
	estado_drone = DroneState.DESTROYED
	velocity = Vector2.ZERO
	velocidade_desejada = Vector2.ZERO
	collision_layer = 0
	z_index = 3
	visible = true
	cone_visao.visible = false
	luz_alerta.visible = false
	aviso_tiro.hide()
	barra_vida.hide()
	sprite_animada.stop()
	sprite_animada.position = Vector2(4, 10)
	sprite_animada.rotation = 1.15
	sprite_animada.scale = Vector2(0.29, 0.12)
	sprite_animada.modulate = Color(0.34, 0.38, 0.4, 1.0)


func _pode_ver_jogador(max_range: float, require_fov: bool) -> bool:
	if not _pode_perseguir_jogador():
		return false
	var offset := jogador_atual.global_position - global_position
	var distance := offset.length()
	if distance <= 0.001 or distance > max_range:
		return false
	var direction := offset / distance
	if require_fov and direcao_visao.dot(direction) < FIELD_OF_VIEW_COSINE:
		return false
	visao.target_position = visao.to_local(jogador_atual.global_position)
	visao.force_raycast_update()
	return not visao.is_colliding() or visao.get_collider() == jogador_atual


func _virar_para_jogador(delta: float) -> void:
	if not is_instance_valid(jogador_atual):
		return
	var offset := jogador_atual.global_position - global_position
	if offset.length_squared() > 0.01:
		_virar_para(offset.normalized(), delta)


func _atualizar_direcao_visao(delta: float) -> void:
	if estado_drone == DroneState.CHASE or estado_drone == DroneState.ALERT:
		cone_visao.rotation = direcao_visao.angle()
		return
	if velocity.length_squared() > 0.01:
		_virar_para(velocity.normalized(), delta)
	cone_visao.rotation = direcao_visao.angle()


func _virar_para(direction: Vector2, delta: float) -> void:
	var weight := 1.0 - exp(-TURN_RESPONSE * delta)
	var angle := lerp_angle(direcao_visao.angle(), direction.angle(), weight)
	direcao_visao = Vector2.RIGHT.rotated(angle)


func _aplicar_aceleracao_voo(delta: float) -> void:
	var acceleration := PATROL_ACCELERATION
	if estado_drone == DroneState.CHASE:
		acceleration = CHASE_ACCELERATION
	elif velocidade_desejada.length_squared() < 0.01:
		acceleration = BRAKE_ACCELERATION
	velocity = velocity.move_toward(velocidade_desejada, acceleration * multiplicador_velocidade * delta)


func _atualizar_visual_voo(delta: float) -> void:
	rotation = 0.0
	if tween_dano != null and tween_dano.is_running():
		return
	var lateral_ratio := clampf(velocity.x / (CHASE_SPEED * multiplicador_velocidade), -1.0, 1.0)
	var target_tilt := lateral_ratio * MAX_FLIGHT_TILT
	var tilt_weight := 1.0 - exp(-FLIGHT_TILT_RESPONSE * delta)
	sprite_animada.rotation = lerp_angle(sprite_animada.rotation, target_tilt, tilt_weight)
	sprite_animada.position.y = sin(fase_voo * 1.7) * 0.65


func _atualizar_barra_vida() -> void:
	if not is_instance_valid(barra_vida):
		return
	barra_vida.rotation = -rotation
	var ratio := clampf(vida_atual / vida_maxima, 0.0, 1.0)
	preenchimento_vida.size.x = 24.0 * ratio
	if ratio > 0.5:
		preenchimento_vida.color = Color(0.2, 0.92, 0.46, 1.0)
	elif ratio > 0.25:
		preenchimento_vida.color = Color(1.0, 0.66, 0.12, 1.0)
	else:
		preenchimento_vida.color = Color(1.0, 0.16, 0.1, 1.0)
	barra_vida.visible = (
		estado_drone != DroneState.DORMANT
		and estado_drone != DroneState.DESTROYED
		and (estado_drone == DroneState.ALERT or estado_drone == DroneState.CHASE or vida_atual < vida_maxima)
	)
