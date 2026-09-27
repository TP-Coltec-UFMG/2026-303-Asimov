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

var current_ammo: int = MAGAZINE_SIZE
var reserve_ammo: int = STARTING_RESERVE
var reloading: bool = false

func _ready() -> void:
	if not no_inventario:
		if (
			SaveGame.is_object_collected(save_id)
			or bool(SaveGame.load_global_state("player_starting_gun"))
		):
			queue_free()
			return
			
	set_process(false)

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
		return
	if Input.is_action_just_pressed("reload") and player.usando_arma:
		_start_reload()
	var mouse_target := player.get_global_mouse_position()
	var weapon_anchor := player.global_position + position_on_player.position
	var anchor_direction := mouse_target - weapon_anchor
	if anchor_direction.length_squared() <= 0.01:
		return
	anchor_direction = anchor_direction.normalized()
	var aim_angle := anchor_direction.angle()
	var shot_origin := weapon_anchor + bullet_spawn.position.rotated(aim_angle)
	var aim_direction := mouse_target - shot_origin
	if aim_direction.length_squared() <= 0.01:
		return
	aim_direction = aim_direction.normalized()
	position_on_player.rotation = aim_direction.angle()
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
