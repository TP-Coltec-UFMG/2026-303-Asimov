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
const MISSION_CHECK_INTERVAL: float = 0.25
const ROOM_BOUNDS: Rect2 = Rect2(-205.0, -76.0, 470.0, 274.0)
const DRONE_PROJECTILE := preload("res://Objects/drone_projectile.tscn")

@export var patrol_points: Array[Vector2] = [
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
@export var persistent_mission_state: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_cone: Polygon2D = $VisionCone
@onready var alert_light: PointLight2D = $AlertLight
@onready var alert_sfx: AudioStreamPlayer2D = $AlertSfx
@onready var shot_sfx: AudioStreamPlayer2D = $ShotSfx
@onready var explosion_sfx: AudioStreamPlayer2D = $ExplosionSfx
@onready var hit_sparks: CPUParticles2D = $HitSparks
@onready var shot_warning: Line2D = $ShotWarning
@onready var muzzle_flash: Node2D = $MuzzleFlash
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var explosion_flash: Polygon2D = $ExplosionVisuals/Flash
@onready var explosion_wave: Line2D = $ExplosionVisuals/Shockwave

var drone_state: DroneState = DroneState.DORMANT
var current_player: Player
var patrol_index: int = 0
var patrol_direction: int = 1
var facing_direction: Vector2 = Vector2.RIGHT
var desired_velocity: Vector2 = Vector2.ZERO
var flight_phase: float = 0.0
var state_time: float = 0.0
var lost_sight_time: float = 0.0
var mission_check_time: float = 0.0
var shot_time: float = 0.0
var current_health: float = MAX_HEALTH
var destroyed: bool = false
var death_animation_running: bool = false
var strafe_direction: float = 1.0
var damage_tween: Tween
var shot_charge_remaining: float = 0.0
var muzzle_tween: Tween
var explosion_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	patrol_index = randi_range(0, maxi(0, patrol_points.size() - 1))
	patrol_direction = 1 if randf() >= 0.5 else -1
	strafe_direction = 1.0 if randf() >= 0.5 else -1.0
	flight_phase = randf_range(0.0, TAU)
	_set_dormant()


func _physics_process(delta: float) -> void:
	mission_check_time -= delta
	if mission_check_time <= 0.0:
		mission_check_time = MISSION_CHECK_INTERVAL
		_refresh_mission_state()
	if drone_state == DroneState.DORMANT or drone_state == DroneState.DESTROYED:
		return
	shot_time = maxf(0.0, shot_time - delta)
	if not _player_can_be_chased():
		desired_velocity = Vector2.ZERO
		velocity = velocity.move_toward(Vector2.ZERO, BRAKE_ACCELERATION * delta)
		return
	flight_phase = fmod(flight_phase + delta * 3.1, TAU)
	state_time += delta
	match drone_state:
		DroneState.PATROL:
			_update_patrol(delta)
		DroneState.ALERT:
			_update_alert(delta)
		DroneState.CHASE:
			_update_chase(delta)
		DroneState.COOLDOWN:
			_update_cooldown(delta)
	_apply_flight_acceleration(delta)
	move_and_slide()
	position = Vector2(
		clampf(position.x, ROOM_BOUNDS.position.x, ROOM_BOUNDS.end.x),
		clampf(position.y, ROOM_BOUNDS.position.y, ROOM_BOUNDS.end.y)
	)
	_update_facing(delta)
	_update_flight_visuals(delta)
	_update_health_bar()


func _refresh_mission_state() -> void:
	current_player = _find_player()
	if not is_instance_valid(current_player):
		_set_dormant()
		return
	var mission: Dictionary = SaveGame.office_mission_state(current_player)
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
		if not death_animation_running:
			_set_dormant()
		return
	if persistent_mission_state:
		destroyed = bool(mission.get("security_drone_destroyed", false))
	if destroyed:
		if not death_animation_running and drone_state != DroneState.DESTROYED:
			_show_destroyed_wreck()
		return
	if drone_state == DroneState.DORMANT or drone_state == DroneState.DESTROYED:
		_activate()


func _find_player() -> Player:
	var scene := get_parent() as BaseScene
	if scene != null and is_instance_valid(scene.player):
		return scene.player
	return get_tree().get_first_node_in_group("player") as Player


func _activate() -> void:
	drone_state = DroneState.PATROL
	state_time = 0.0
	lost_sight_time = 0.0
	shot_time = 0.35
	shot_charge_remaining = 0.0
	current_health = MAX_HEALTH
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	collision_layer = 2
	z_index = 30
	rotation = 0.0
	animated_sprite.position = Vector2.ZERO
	animated_sprite.rotation = 0.0
	animated_sprite.scale = Vector2(0.29, 0.29)
	animated_sprite.modulate = Color.WHITE
	visible = true
	animated_sprite.play(&"fly")
	vision_cone.visible = true
	alert_light.visible = false
	shot_warning.hide()
	muzzle_flash.hide()
	health_bar.show()
	_update_health_bar()


func _set_dormant() -> void:
	drone_state = DroneState.DORMANT
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	visible = false
	shot_warning.hide()
	health_bar.hide()
	if is_instance_valid(animated_sprite):
		animated_sprite.stop()


func _player_can_be_chased() -> bool:
	return (
		is_instance_valid(current_player)
		and current_player.is_inside_tree()
		and current_player.is_visible_in_tree()
		and current_player.can_process()
		and current_player.is_physics_processing()
	)


func _update_patrol(_delta: float) -> void:
	vision_cone.color = Color(1.0, 0.74, 0.18, 0.13)
	alert_light.visible = false
	if patrol_points.is_empty():
		desired_velocity = Vector2.ZERO
		return
	var target := patrol_points[patrol_index]
	var offset := target - position
	if offset.length() < 5.0:
		patrol_index = posmod(patrol_index + patrol_direction, patrol_points.size())
		target = patrol_points[patrol_index]
		offset = target - position
	var speed_pulse := 1.0 + sin(flight_phase) * 0.06
	desired_velocity = offset.normalized() * PATROL_SPEED * speed_pulse
	if _can_see_player(DETECTION_RANGE, true):
		_begin_alert()


func _begin_alert() -> void:
	drone_state = DroneState.ALERT
	state_time = 0.0
	desired_velocity = Vector2.ZERO
	vision_cone.color = Color(1.0, 0.08, 0.04, 0.27)
	alert_light.visible = true
	alert_sfx.pitch_scale = 1.0
	alert_sfx.play()


func _update_alert(delta: float) -> void:
	desired_velocity = Vector2.ZERO
	_face_player(delta)
	if state_time >= ALERT_DURATION:
		drone_state = DroneState.CHASE
		state_time = 0.0
		lost_sight_time = 0.0


func _update_chase(delta: float) -> void:
	vision_cone.color = Color(1.0, 0.04, 0.02, 0.31)
	alert_light.visible = true
	var offset := current_player.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized()
	_face_player(delta)
	if shot_charge_remaining > 0.0:
		shot_charge_remaining -= delta
		desired_velocity = Vector2.ZERO
		_update_shot_warning()
		if shot_charge_remaining <= 0.0:
			_fire_at_player(direction)
	elif distance < RETREAT_DISTANCE:
		desired_velocity = -direction * CHASE_SPEED
	elif distance > PREFERRED_DISTANCE + 18.0:
		desired_velocity = direction * CHASE_SPEED
	else:
		desired_velocity = direction.orthogonal() * CHASE_SPEED * 0.55 * strafe_direction
	desired_velocity *= 1.0 + sin(flight_phase * 1.35) * 0.08
	if shot_time <= 0.0 and shot_charge_remaining <= 0.0 and _can_see_player(LOST_RANGE, false):
		_start_shot_telegraph()
	if _can_see_player(LOST_RANGE, false):
		lost_sight_time = 0.0
	else:
		lost_sight_time += delta
	if lost_sight_time >= LOST_SIGHT_DURATION or state_time >= CHASE_LIMIT:
		_begin_cooldown()


func _begin_cooldown() -> void:
	drone_state = DroneState.COOLDOWN
	state_time = 0.0
	desired_velocity = -facing_direction * PATROL_SPEED
	vision_cone.color = Color(0.35, 0.7, 1.0, 0.1)
	alert_light.visible = false
	shot_charge_remaining = 0.0
	shot_warning.hide()


func _update_cooldown(_delta: float) -> void:
	if state_time < 0.55:
		desired_velocity = -facing_direction * PATROL_SPEED
	else:
		desired_velocity = Vector2.ZERO
	if state_time >= COOLDOWN_DURATION:
		drone_state = DroneState.PATROL
		state_time = 0.0
		lost_sight_time = 0.0
		shot_time = 0.25


func _fire_at_player(direction: Vector2) -> void:
	if not is_instance_valid(current_player):
		return
	var projectile := DRONE_PROJECTILE.instantiate() as Node2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 9.0
	projectile.call("setup", direction)
	shot_time = SHOT_INTERVAL
	shot_warning.hide()
	_show_muzzle_flash()
	shot_sfx.pitch_scale = randf_range(0.94, 1.08)
	shot_sfx.play()


func _start_shot_telegraph() -> void:
	shot_charge_remaining = SHOT_TELEGRAPH_DURATION
	shot_warning.show()
	alert_sfx.pitch_scale = 1.35
	alert_sfx.play()
	_update_shot_warning()


func _update_shot_warning() -> void:
	if not is_instance_valid(current_player):
		shot_warning.hide()
		return
	shot_warning.points = PackedVector2Array([
		Vector2.ZERO,
		to_local(current_player.global_position)
	])
	var progress := 1.0 - clampf(shot_charge_remaining / SHOT_TELEGRAPH_DURATION, 0.0, 1.0)
	shot_warning.width = lerpf(0.65, 1.8, progress)
	shot_warning.modulate.a = lerpf(0.25, 1.0, progress)


func _show_muzzle_flash() -> void:
	if muzzle_tween != null and muzzle_tween.is_valid():
		muzzle_tween.kill()
	muzzle_flash.position = facing_direction * 8.0
	muzzle_flash.rotation = facing_direction.angle() - rotation
	muzzle_flash.scale = Vector2.ONE
	muzzle_flash.modulate.a = 1.0
	muzzle_flash.show()
	muzzle_tween = create_tween()
	muzzle_tween.set_parallel(true)
	muzzle_tween.tween_property(muzzle_flash, "scale", Vector2(1.7, 1.7), 0.09)
	muzzle_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
	await muzzle_tween.finished
	if is_instance_valid(muzzle_flash):
		muzzle_flash.hide()


func receive_projectile_damage(amount: float) -> void:
	if destroyed or drone_state == DroneState.DORMANT or amount <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	_update_health_bar()
	_flash_damage()
	if current_health <= 0.0:
		_destroy_drone()
	elif drone_state == DroneState.PATROL:
		_begin_alert()


func _flash_damage() -> void:
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	hit_sparks.restart()
	hit_sparks.emitting = true
	alert_sfx.pitch_scale = randf_range(1.75, 2.05)
	alert_sfx.play()
	animated_sprite.modulate = Color(0.35, 0.95, 1.0, 1.0)
	animated_sprite.position = Vector2.ZERO
	damage_tween = create_tween()
	damage_tween.tween_property(animated_sprite, "position", Vector2(-2, 1), 0.025)
	damage_tween.tween_property(animated_sprite, "position", Vector2(2, -1), 0.025)
	damage_tween.tween_property(animated_sprite, "position", Vector2(-1, -2), 0.025)
	damage_tween.tween_property(animated_sprite, "position", Vector2.ZERO, 0.035)
	damage_tween.parallel().tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)


func _destroy_drone() -> void:
	destroyed = true
	death_animation_running = true
	drone_state = DroneState.DESTROYED
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	collision_layer = 0
	vision_cone.visible = false
	shot_warning.hide()
	health_bar.hide()
	shot_sfx.stop()
	explosion_sfx.play()
	hit_sparks.emitting = false
	_play_explosion_visuals()
	alert_light.visible = true
	alert_light.color = Color(1.0, 0.35, 0.04, 1.0)
	alert_light.energy = 1.8
	animated_sprite.stop()
	if damage_tween != null and damage_tween.is_valid():
		damage_tween.kill()
	animated_sprite.position = Vector2.ZERO
	if persistent_mission_state:
		var mission: Dictionary = SaveGame.office_mission_state(current_player)
		mission["security_drone_destroyed"] = true
		SaveGame.save_global_state("hall_quest_01", mission)
	var fall_side := 1.0 if randf() >= 0.5 else -1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(animated_sprite, "position", Vector2(5.0 * fall_side, 10.0), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(animated_sprite, "rotation", 1.15 * fall_side, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(animated_sprite, "scale", Vector2(0.29, 0.12), 0.48)
	tween.tween_property(animated_sprite, "modulate", Color(0.34, 0.38, 0.4, 1.0), 0.48)
	tween.tween_property(alert_light, "energy", 0.0, 0.22)
	await tween.finished
	alert_light.visible = false
	z_index = 3
	death_animation_running = false


func _play_explosion_visuals() -> void:
	explosion_flash.scale = Vector2(0.25, 0.25)
	explosion_flash.modulate.a = 1.0
	explosion_flash.show()
	explosion_wave.scale = Vector2(0.3, 0.3)
	explosion_wave.modulate.a = 1.0
	explosion_wave.show()
	if explosion_tween != null and explosion_tween.is_valid():
		explosion_tween.kill()
	explosion_tween = create_tween()
	explosion_tween.set_parallel(true)
	explosion_tween.tween_property(explosion_flash, "scale", Vector2(2.4, 2.4), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	explosion_tween.tween_property(explosion_flash, "modulate:a", 0.0, 0.42)
	explosion_tween.tween_property(explosion_wave, "scale", Vector2(3.2, 3.2), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	explosion_tween.tween_property(explosion_wave, "modulate:a", 0.0, 0.5)
	await explosion_tween.finished
	if is_instance_valid(explosion_flash):
		explosion_flash.hide()
	if is_instance_valid(explosion_wave):
		explosion_wave.hide()


func _show_destroyed_wreck() -> void:
	destroyed = true
	drone_state = DroneState.DESTROYED
	velocity = Vector2.ZERO
	desired_velocity = Vector2.ZERO
	collision_layer = 0
	z_index = 3
	visible = true
	vision_cone.visible = false
	alert_light.visible = false
	shot_warning.hide()
	health_bar.hide()
	animated_sprite.stop()
	animated_sprite.position = Vector2(4, 10)
	animated_sprite.rotation = 1.15
	animated_sprite.scale = Vector2(0.29, 0.12)
	animated_sprite.modulate = Color(0.34, 0.38, 0.4, 1.0)


func _can_see_player(max_range: float, require_fov: bool) -> bool:
	if not _player_can_be_chased():
		return false
	var offset := current_player.global_position - global_position
	var distance := offset.length()
	if distance <= 0.001 or distance > max_range:
		return false
	var direction := offset / distance
	if require_fov and facing_direction.dot(direction) < FIELD_OF_VIEW_COSINE:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		current_player.global_position,
		9,
		[get_rid()]
	)
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == current_player


func _face_player(delta: float) -> void:
	if not is_instance_valid(current_player):
		return
	var offset := current_player.global_position - global_position
	if offset.length_squared() > 0.01:
		_turn_toward(offset.normalized(), delta)


func _update_facing(delta: float) -> void:
	if drone_state == DroneState.CHASE or drone_state == DroneState.ALERT:
		vision_cone.rotation = facing_direction.angle()
		return
	if velocity.length_squared() > 0.01:
		_turn_toward(velocity.normalized(), delta)
	vision_cone.rotation = facing_direction.angle()


func _turn_toward(direction: Vector2, delta: float) -> void:
	var weight := 1.0 - exp(-TURN_RESPONSE * delta)
	var angle := lerp_angle(facing_direction.angle(), direction.angle(), weight)
	facing_direction = Vector2.RIGHT.rotated(angle)


func _apply_flight_acceleration(delta: float) -> void:
	var acceleration := PATROL_ACCELERATION
	if drone_state == DroneState.CHASE:
		acceleration = CHASE_ACCELERATION
	elif desired_velocity.length_squared() < 0.01:
		acceleration = BRAKE_ACCELERATION
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func _update_flight_visuals(delta: float) -> void:
	rotation = 0.0
	if damage_tween != null and damage_tween.is_running():
		return
	var lateral_ratio := clampf(velocity.x / CHASE_SPEED, -1.0, 1.0)
	var target_tilt := lateral_ratio * MAX_FLIGHT_TILT
	var tilt_weight := 1.0 - exp(-FLIGHT_TILT_RESPONSE * delta)
	animated_sprite.rotation = lerp_angle(animated_sprite.rotation, target_tilt, tilt_weight)
	animated_sprite.position.y = sin(flight_phase * 1.7) * 0.65


func _update_health_bar() -> void:
	if not is_instance_valid(health_bar):
		return
	health_bar.rotation = -rotation
	var ratio := clampf(current_health / MAX_HEALTH, 0.0, 1.0)
	health_fill.size.x = 24.0 * ratio
	if ratio > 0.5:
		health_fill.color = Color(0.2, 0.92, 0.46, 1.0)
	elif ratio > 0.25:
		health_fill.color = Color(1.0, 0.66, 0.12, 1.0)
	else:
		health_fill.color = Color(1.0, 0.16, 0.1, 1.0)
	health_bar.visible = (
		drone_state != DroneState.DORMANT
		and drone_state != DroneState.DESTROYED
		and (drone_state == DroneState.ALERT or drone_state == DroneState.CHASE or current_health < MAX_HEALTH)
	)
