extends Area2D

# ==============================
# CONFIGURAÇÃO
# ==============================
@export var voltagem: float = 9
@export var voltagem_maxima: float = 30.0
@export var incremento_tensao: float = 1.0
@export var corrente_maxima: float = 1.0           # acima disso, a bateria sofre (curto-circuito)
@export var corrente_curto_circuito: float = 5.0   # corrente simbólica quando a resistência total do circuito é 0
@export var dano_por_ampere_excedente: float = 30.0

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

enum Estado { NORMAL, QUEIMANDO, QUEIMADA }
var estado: Estado = Estado.NORMAL

func _process(delta: float) -> void:
	$Label.text = "%.1f V" % voltagem
	


func _ready() -> void:
	
	material_shader = animation_player.material as ShaderMaterial
	add_to_group("baterias")
	input_pickable = true
	input_event.connect(_on_input_event)
	$Label.text = "%.1f V" % (voltagem)
	desativar_destaque()
	
func ativar_destaque() -> void:
	
	animation_player.material = material_shader


func desativar_destaque() -> void:
	print("fui chamado a desativar")
	animation_player.material = null


# Roda da roldana do mouse em cima da bateria = aumenta/diminui a tensão
func _on_input_event(_viewport, event, _shape_idx) -> void:
	if estado == Estado.QUEIMADA:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			aumentar_tensao()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			diminuir_tensao()


func aumentar_tensao() -> void:
	voltagem = min(voltagem + incremento_tensao, voltagem_maxima)
	print("BATERIA: tensão = ", voltagem, "V")


func diminuir_tensao() -> void:
	voltagem = max(voltagem - incremento_tensao, 0.0)
	print("BATERIA: tensão = ", voltagem, "V")


# Chamado pelo CircuitManager a cada avaliação do circuito, com a
# corrente (em Amperes) que está passando pela bateria nesse instante.
func aplicar_corrente(corrente: float, delta: float) -> void:
	if estado == Estado.QUEIMADA:
		return

	var excesso := corrente - corrente_maxima

	if excesso > 0.0:
		saude -= excesso * dano_por_ampere_excedente * delta
		mudar_estado(Estado.QUEIMANDO)
	else:
		mudar_estado(Estado.NORMAL)

	if saude <= 0.0:
		saude = 0.0
		mudar_estado(Estado.QUEIMADA)
		voltagem = 0.0


func mudar_estado(novo: Estado) -> void:
	if estado == novo:
		return
	estado = novo
	match estado:
		Estado.NORMAL:
			tocar_animacao("normal")
		Estado.QUEIMANDO:
			tocar_animacao("queimando")
		Estado.QUEIMADA:
			tocar_animacao("queimado")
			print("BATERIA: queimou!")


func tocar_animacao(nome: String) -> void:
	if animation_player != null and animation_player.has_animation(nome):
		animation_player.play(nome)


func _on_diminuir_tensão_pressed() -> void:
	if(voltagem > - 1):
		voltagem =  voltagem  - incremento_tensao
		$Label.text = "%.1f V" % voltagem


func _on_aumentar_tensão_pressed() -> void:
	if( voltagem <31):
		
		voltagem =  voltagem  + incremento_tensao
		print(voltagem)
		$Label.text = "%.1f V" % voltagem
		
