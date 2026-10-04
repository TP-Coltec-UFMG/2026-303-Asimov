extends Node2D

const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
const DRONE_SCENE := preload("res://Objects/security_drone.tscn")
const BULLET_SCENE := preload("res://Objects/bullet.tscn")
const DRONE_PROJECTILE_SCENE := preload("res://Objects/drone_projectile.tscn")
const NPC_SCENE := preload("res://NPC'S/Clarxs.tscn")
const NPC_TEXTURE := preload("res://NPC'S/NPC/06_purple_crimson.png")
const AMMO_PICKUP_SCENE := preload("res://Objects/ammo_pickup.tscn")


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	var original_save: Dictionary = SaveGame.save_data.duplicate(true)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = Vector2(40, 0)
	var drone := DRONE_SCENE.instantiate() as SecurityDrone
	add_child(drone)
	drone.position = Vector2.ZERO
	var state: Dictionary = SaveGame.office_mission_state(player)
	state["programmer_ending_started"] = true
	state["programmer_ending_completed"] = false
	state["engineer_ending_started"] = false
	state["engineer_ending_completed"] = false
	state["security_drone_destroyed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	drone._refresh_mission_state()
	assert(drone.visible)
	assert(drone.drone_state == SecurityDrone.DroneState.PATROL)
	player.set_physics_process(false)
	drone._physics_process(0.1)
	assert(drone.velocity == Vector2.ZERO)
	player.set_physics_process(true)
	state["programmer_ending_completed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	drone._refresh_mission_state()
	assert(not drone.visible)
	assert(drone.drone_state == SecurityDrone.DroneState.DORMANT)
	state["engineer_ending_started"] = true
	state["engineer_ending_completed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	SaveGame.save_global_state("ammo_pickup_runtime_test", false)
	var ammo_pickup := AMMO_PICKUP_SCENE.instantiate() as AmmoPickup
	ammo_pickup.id_coleta = "runtime_test"
	add_child(ammo_pickup)
	assert(not ammo_pickup.coletada)
	assert(ammo_pickup.visible)
	drone._refresh_mission_state()
	assert(drone.visible)
	assert(drone.drone_state == SecurityDrone.DroneState.PATROL)
	await get_tree().physics_frame
	await get_tree().process_frame
	drone.receive_projectile_damage(25.0)
	assert(drone.current_health == 50.0)
	assert(drone.health_fill.size.x < 24.0)
	drone._start_shot_telegraph()
	assert(drone.shot_warning.visible)
	drone.shot_charge_remaining = 0.0
	drone.shot_warning.hide()
	var starting_gun = player.inventory.get_item_control("gun")
	assert(starting_gun != null)
	starting_gun.definir_jogador(player)
	starting_gun.municao_atual = 2
	starting_gun.municao_reserva = 7
	starting_gun.call("_iniciar_recarga")
	assert(starting_gun.recarregando)
	await get_tree().create_timer(1.25).timeout
	assert(starting_gun.municao_atual == 7)
	assert(starting_gun.municao_reserva == 2)
	assert(starting_gun.adicionar_municao(7) == 7)
	assert(starting_gun.municao_reserva == 9)
	var npc := NPC_SCENE.instantiate()
	npc.save_enabled = false
	npc.sprite_sheet = NPC_TEXTURE
	add_child(npc)
	var npc_bullet := BULLET_SCENE.instantiate()
	add_child(npc_bullet)
	assert(npc_bullet.call("_find_protected_npc", npc.get_node("CharacterBody2D")) == npc)
	drone.receive_projectile_damage(25.0)
	drone.receive_projectile_damage(25.0)
	assert(drone.destroyed)
	assert(bool(SaveGame.office_mission_state(player).get("security_drone_destroyed", false)))
	state["security_drone_destroyed"] = false
	SaveGame.save_global_state("hall_quest_01", state)
	var health_before := player.get_vida()
	var hostile_shot := DRONE_PROJECTILE_SCENE.instantiate()
	add_child(hostile_shot)
	hostile_shot.call("_on_body_entered", player)
	assert(player.get_vida() == health_before - 18.0)
	state["engineer_ending_completed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	await get_tree().create_timer(0.6).timeout
	drone._refresh_mission_state()
	assert(not drone.visible)
	SaveGame.save_data = original_save
	get_tree().quit()
