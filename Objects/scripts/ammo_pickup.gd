class_name AmmoPickup
extends Area2D

@export var pickup_id: String = "ammo"
@export var ammo_amount: int = 7

var collected: bool = false
var refresh_time: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	collected = SaveGame.load_global_state("ammo_pickup_" + pickup_id) == true
	if collected:
		queue_free()
		return
	_update_availability()


func _process(delta: float) -> void:
	refresh_time -= delta
	if refresh_time <= 0.0:
		refresh_time = 0.25
		_update_availability()


func _update_availability() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(player):
		visible = false
		monitoring = false
		return
	var state := SaveGame.office_mission_state(player)
	var final_active: bool = (
		state.get("programmer_ending_started", false) == true
		or state.get("engineer_ending_started", false) == true
	)
	visible = final_active
	monitoring = final_active


func _on_body_entered(body: Node2D) -> void:
	if collected or not visible or not (body is Player):
		return
	var player := body as Player
	var gun := player.inventory.get_item_control("gun")
	if gun == null or not gun.has_method("add_ammo"):
		return
	var added := int(gun.call("add_ammo", ammo_amount))
	if added <= 0:
		return
	collected = true
	SaveGame.save_global_state("ammo_pickup_" + pickup_id, true)
	player.show_ammo_pickup(added)
	if player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)
	queue_free()
