extends Area2D

# ==============================
# CONFIGURAÇÃO
# ==============================
@export var resistencia_interna: float = 100.0   # simplificação de jogo, não é física real de diodo
@export var corrente_maxima: float = 0.02        # 20 mA, típico de um LED comum
@export var dano_por_ampere_excedente: float = 4000.0

# ==============================
# REFERÊNCIAS
# ==============================
@onready var terminal_positivo: Node2D = $Terminal_positivo
@onready var terminal_negativo: Node2D = $Terminal_negativo
@onready var animation_player: AnimatedSprite2D = $AnimatedSprite2D 
@onready var animation_player2: AnimatedSprite2D = $AnimatedSprite2D2
var material_shader: ShaderMaterial

# ==============================
# ESTADO
# ==============================
var saude := 100.0
var aceso := false

enum Estado { NORMAL, QUEIMANDO, QUEIMADO }
var estado: Estado = Estado.NORMAL


func _ready() -> void:
	
	add_to_group("leds")
	material_shader = animation_player.material as ShaderMaterial
	desativar_destaque()


func ativar_destaque() -> void:
	animation_player.material = material_shader
	animation_player2.material = material_shader


func desativar_destaque() -> void:
	animation_player.material = null
	animation_player2.material = null


# Chamado pelo CircuitManager a cada avaliação, dizendo se o LED está
# sendo alimentado na polaridade certa (positivo -> negativo) nesse instante.
func definir_aceso(valor: bool) -> void:
	if estado == Estado.QUEIMADO:
		return
	if aceso == valor:
		return
	aceso = valor
	tocar_animacao("aceso" if aceso else "apagado")


# Chamado pelo CircuitManager com a corrente (em Amperes) passando pelo LED.
func aplicar_corrente(corrente: float, delta: float) -> void:
	if estado == Estado.QUEIMADO:
		return

	var excesso := corrente - corrente_maxima

	if excesso > 0.0:
		saude -= excesso * dano_por_ampere_excedente * delta
		mudar_estado(Estado.QUEIMANDO)
	elif estado == Estado.QUEIMANDO:
		mudar_estado(Estado.NORMAL)

	if saude <= 0.0:
		saude = 0.0
		mudar_estado(Estado.QUEIMADO)
		aceso = false


func mudar_estado(novo: Estado) -> void:
	if estado == novo:
		return
	estado = novo
	match estado:
		Estado.NORMAL:
			pass  # a animação aceso/apagado é controlada por definir_aceso()
		Estado.QUEIMANDO:
			tocar_animacao("queimando")
		Estado.QUEIMADO:
			tocar_animacao("queimado")
			print("LED: queimou!")


func tocar_animacao(nome: String) -> void:
	if animation_player != null and animation_player.has_animation(nome):
		animation_player.play(nome)
		
