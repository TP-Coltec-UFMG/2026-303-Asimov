extends Node2D

var player: Player = null

@export var save_id: String = "arma"
var no_inventario: bool = false

@onready var position_on_player: Sprite2D = $Position_on_player
@onready var bullet_spawn: Marker2D = $Position_on_player/BulletSpawn
@onready var timer: Timer = $Timer
@onready var reticula: Sprite2D = $reticula
@onready var shot_sfx: AudioStreamPlayer = $ShotSfx
@onready var empty_sfx: AudioStreamPlayer = $EmptySfx
@onready var reload_sfx: AudioStreamPlayer = $ReloadSfx

const BULLET = preload("res://Objects/bullet.tscn")
const MUZZLE_EFFECT = preload("res://Objects/gun_muzzle_effect.tscn")
const CASING = preload("res://Objects/gun_casing.tscn")
const MAGAZINE_SIZE: int = 7
const STARTING_RESERVE: int = 7
const MAX_RESERVE: int = 28
const RELOAD_DURATION: float = 1.15
const AIM_ASSIST_RANGE: float = 260.0
const AIM_ASSIST_CONE: float = 0.24

var current_ammo: int = MAGAZINE_SIZE
var reserve_ammo: int = STARTING_RESERVE
var reloading: bool = false
var aim_assist_locked: bool = false
var crosshair_active: bool = false
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	if not no_inventario:
		if (
			SaveGame.is_object_collected(save_id)
			or bool(SaveGame.load_global_state("player_starting_gun"))
		):
			queue_free()
			return
			
	reticula.top_level = true
	reticula.z_index = 100
	reticula.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _exit_tree() -> void:
	_set_crosshair_active(false)

func foi_coletado() -> void:
	SaveGame.set_object_collected(save_id)

func marcar_como_item_inventario() -> void:
	no_inventario = true
	
func set_player(novo_player: Player) -> void:
	player = novo_player
	set_process(true)
	refresh_hud()


func refresh_hud() -> void:
	if is_instance_valid(player):
		player.update_weapon_hud(current_ammo, MAGAZINE_SIZE, reserve_ammo, reloading)


func get_checkpoint_state() -> Dictionary:
	return {
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo
	}


func load_checkpoint_state(state: Dictionary) -> void:
	current_ammo = clampi(int(state.get("current_ammo", MAGAZINE_SIZE)), 0, MAGAZINE_SIZE)
	reserve_ammo = clampi(int(state.get("reserve_ammo", STARTING_RESERVE)), 0, MAX_RESERVE)
	reloading = false
	refresh_hud()


func add_ammo(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous := reserve_ammo
	reserve_ammo = mini(MAX_RESERVE, reserve_ammo + amount)
	refresh_hud()
	return reserve_ammo - previous


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		_set_crosshair_active(false)
		return
	var weapon_active: bool = (
		bool(player.usando_arma)
		and bool(player.is_physics_processing())
		and not bool(get_tree().paused)
		and not bool(DialogManager.is_showing_dialog)
	)
	_set_crosshair_active(weapon_active)
	if not weapon_active:
		return
	if Input.is_action_just_pressed("reload") and player.usando_arma:
		_start_reload()
	var mouse_target := player.get_global_mouse_position()
	var weapon_anchor := player.global_position + position_on_player.position
	var assisted_target := _aim_assist_target(weapon_anchor, mouse_target)
	reticula.global_position = assisted_target
	reticula.self_modulate = Color(0.45, 1.0, 0.55, 1.0) if aim_assist_locked else Color.WHITE
	reticula.scale = Vector2.ONE * (0.21 if aim_assist_locked else 0.18)
	var anchor_direction := assisted_target - weapon_anchor
	if anchor_direction.length_squared() <= 0.01:
		return
	anchor_direction = anchor_direction.normalized()
	var aim_angle := anchor_direction.angle()
	var shot_origin := weapon_anchor + bullet_spawn.position.rotated(aim_angle)
	var aim_direction := assisted_target - shot_origin
	if aim_direction.length_squared() <= 0.01:
		return
	aim_direction = aim_direction.normalized()
	position_on_player.rotation = aim_direction.angle()
	shot_origin = weapon_anchor + bullet_spawn.position.rotated(position_on_player.rotation)
	if (
		Input.is_action_just_pressed("fire")
		and player.usando_arma
		and timer.is_stopped()
		and not reloading
	):
		if current_ammo <= 0:
			empty_sfx.play()
			refresh_hud()
			return
		current_ammo -= 1
		var bullet_instance = BULLET.instantiate()
		get_tree().current_scene.add_child(bullet_instance)
		bullet_instance.global_position = shot_origin
		bullet_instance.setup(aim_direction, player)
		bullet_instance.show()
		_spawn_shot_effects(aim_direction, shot_origin)
		_play_world_shot()
		timer.start()
		refresh_hud()


func _aim_assist_target(origin: Vector2, mouse_target: Vector2) -> Vector2:
	aim_assist_locked = false
	if not bool(Configs.configs.get("assistencia_mira", false)):
		return mouse_target
	var mouse_direction := mouse_target - origin
	if mouse_direction.length_squared() <= 0.01:
		return mouse_target
	mouse_direction = mouse_direction.normalized()
	var best_target := mouse_target
	var best_score := INF
	for candidate: Node in get_tree().get_nodes_in_group(&"security_drones"):
		var drone := candidate as Node2D
		if drone == null or not drone.is_visible_in_tree() or bool(drone.get("destroyed")):
			continue
		var screen_position := get_viewport().get_canvas_transform() * drone.global_position
		if not get_viewport_rect().grow(8.0).has_point(screen_position):
			continue
		var to_drone := drone.global_position - origin
		var distance := to_drone.length()
		if distance <= 0.01 or distance > AIM_ASSIST_RANGE:
			continue
		var angle := absf(mouse_direction.angle_to(to_drone / distance))
		if angle > AIM_ASSIST_CONE:
			continue
		var score := angle * 4.0 + distance / AIM_ASSIST_RANGE
		if score < best_score:
			best_score = score
			best_target = drone.global_position
	aim_assist_locked = best_score < INF
	return best_target


func _set_crosshair_active(active: bool) -> void:
	if active:
		if not crosshair_active:
			previous_mouse_mode = Input.mouse_mode
		crosshair_active = true
		reticula.show()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	if not crosshair_active:
		reticula.hide()
		return
	crosshair_active = false
	reticula.hide()
	Input.mouse_mode = previous_mouse_mode


func _start_reload() -> void:
	if reloading or current_ammo >= MAGAZINE_SIZE or reserve_ammo <= 0:
		if current_ammo <= 0 and reserve_ammo <= 0:
			empty_sfx.play()
		return
	reloading = true
	reload_sfx.play()
	refresh_hud()
	await get_tree().create_timer(RELOAD_DURATION, false).timeout
	if not is_inside_tree():
		return
	var needed := MAGAZINE_SIZE - current_ammo
	var loaded := mini(needed, reserve_ammo)
	current_ammo += loaded
	reserve_ammo -= loaded
	reloading = false
	refresh_hud()


func _spawn_shot_effects(direction: Vector2, shot_origin: Vector2) -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(player):
		return
	var muzzle := MUZZLE_EFFECT.instantiate() as Node2D
	scene.add_child(muzzle)
	muzzle.global_position = shot_origin
	muzzle.rotation = direction.angle()
	var casing := CASING.instantiate() as Node2D
	scene.add_child(casing)
	casing.global_position = shot_origin - direction * 3.0
	casing.call("launch", direction)


func _play_world_shot() -> void:
	var scene := get_tree().current_scene
	if scene == null or not is_instance_valid(player) or shot_sfx.stream == null:
		return
	var voice := AudioStreamPlayer2D.new()
	voice.stream = shot_sfx.stream
	voice.bus = &"sfx"
	voice.volume_db = -9.0
	voice.pitch_scale = randf_range(0.97, 1.03)
	voice.max_distance = 340.0
	voice.attenuation = 1.8
	scene.add_child(voice)
	voice.global_position = player.global_position
	voice.finished.connect(voice.queue_free)
	voice.play()
