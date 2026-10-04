class_name AmmoPickup
extends Area2D

@export var id_coleta: String = "ammo"
@export var quantidade_municao: int = 7

var coletada: bool = false


func _ready() -> void:
	coletada = SaveGame.load_global_state("ammo_pickup_" + id_coleta) == true
	if coletada:
		queue_free()
		return
	_atualizar_disponibilidade()


func _atualizar_disponibilidade() -> void:
	var jogador := get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(jogador):
		visible = false
		monitoring = false
		return
	var estado := SaveGame.office_mission_state(jogador)
	var final_ativo: bool = (
		estado.get("programmer_ending_started", false) == true
		or estado.get("engineer_ending_started", false) == true
	)
	visible = final_ativo
	monitoring = final_ativo


func _ao_entrar_corpo(corpo: Node2D) -> void:
	if coletada or not visible or not (corpo is Player):
		return
	var jogador := corpo as Player
	var arma := jogador.inventory.get_item_control("gun")
	if arma == null or not arma.has_method("adicionar_municao"):
		return
	var adicionadas := int(arma.call("adicionar_municao", quantidade_municao))
	if adicionadas <= 0:
		return
	coletada = true
	SaveGame.save_global_state("ammo_pickup_" + id_coleta, true)
	jogador.show_ammo_pickup(adicionadas)
	if jogador.checkpoint_enabled:
		SaveGame.create_checkpoint(jogador)
	queue_free()
