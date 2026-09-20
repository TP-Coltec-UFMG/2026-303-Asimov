extends Area2D

# ==============================
# CONFIGURAÇÃO
# ==============================
@export var resistencia: float = 220.0
@export var potencia_maxima: float = 0.5             # Watts que o resistor aguenta (ex: resistor de 1/2W)
@export var dano_por_watt_excedente: float = 40.0

# ==============================
# REFERÊNCIAS
# ==============================
@onready var terminal_positivo: Node2D = $Terminal_positivo
@onready var terminal_negativo: Node2D = $Terminal_negativo
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D 
var material_shader: ShaderMaterial

# ==============================
# ESTADO
# ==============================
var saude := 100.0

enum Estado { NORMAL, QUEIMANDO, QUEIMADO }
var estado: Estado = Estado.NORMAL


func _ready() -> void:
	
	add_to_group("resistores")
	material_shader = animation_player.material as ShaderMaterial
	desativar_destaque()


func ativar_destaque() -> void:
	animation_player.material = material_shader


func desativar_destaque() -> void:
	animation_player.material = null


# Chamado pelo CircuitManager a cada avaliação do circuito, com a
# corrente (em Amperes) que está passando pelo resistor nesse instante.
func aplicar_corrente(corrente: float, delta: float) -> void:
	if estado == Estado.QUEIMADO:
		return

	var potencia := corrente * corrente * resistencia   # P = I² * R
	var excesso := potencia - potencia_maxima

	if excesso > 0.0:
		saude -= excesso * dano_por_watt_excedente * delta
		mudar_estado(Estado.QUEIMANDO)
	else:
		mudar_estado(Estado.NORMAL)

	if saude <= 0.0:
		saude = 0.0
		mudar_estado(Estado.QUEIMADO)


func mudar_estado(novo: Estado) -> void:
	if estado == novo:
		return
	estado = novo
	match estado:
		Estado.NORMAL:
			tocar_animacao("normal")
		Estado.QUEIMANDO:
			tocar_animacao("queimando")
		Estado.QUEIMADO:
			tocar_animacao("queimado")
			print("RESISTOR: queimou!")


func tocar_animacao(nome: String) -> void:
	if animation_player != null and animation_player.has_animation(nome):
		animation_player.play(nome)
