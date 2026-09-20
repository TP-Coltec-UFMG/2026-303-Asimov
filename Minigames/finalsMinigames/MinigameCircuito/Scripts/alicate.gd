
extends Area2D

# Recurso próprio do minigame de circuito; não compartilha UID com outros minigames.


var fio_em_cima: Node2D = null
var segurando: bool = false

# Contador simples de cortes já realizados. O tutorial usa isso
# para saber que o jogador cortou um fio, sem precisar de sinal.
var total_cortes: int = 0

@onready var sprite: Sprite2D = $Sprite2D
var material_shader: ShaderMaterial


func _ready():
	
	input_pickable = true

	material_shader = sprite.material as ShaderMaterial
	desativar_destaque()


func ativar_destaque() -> void:
	sprite.material = material_shader


func desativar_destaque() -> void:
	sprite.material = null


func _process(_delta):

	# ==========================================
	# FAZER O ALICATE SEGUIR O MOUSE
	# SOMENTE ENQUANTO ESTIVER SEGURANDO
	# ==========================================

	if segurando:

		global_position = get_global_mouse_position()


	# ==========================================
	# PROCURAR FIO EMBAIXO DO ALICATE
	# ==========================================

	fio_em_cima = null

	for area in get_overlapping_areas():

		var fio = area.get_parent()

		if fio == null:
			continue

		if not fio.is_in_group("fios"):
			continue

		if not is_instance_valid(fio):
			continue

		fio_em_cima = fio

		break


# ==========================================
# CLIQUE NO ALICATE
# ==========================================

func _input_event(_viewport, event, _shape_idx):

	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT:

			segurando = event.pressed


		# BOTÃO DIREITO = CORTAR
		if event.button_index == MOUSE_BUTTON_RIGHT:

			if event.pressed:

				cortar_fio()


func cortar_fio():

	if fio_em_cima == null:

		print("NAO CORTEI")

		return


	var fio_cortado = fio_em_cima

	total_cortes += 1

	print(
		"CORTEI: ",
		fio_cortado.name
	)


	# ==========================================
	# PROCURA O CIRCUIT
	# ==========================================

	var circuit = self.get_parent(
		
	)


	if circuit != null:

		circuit.cortar_fio(
			fio_cortado
		)


	# ==========================================
	# REMOVE O FIO
	# ==========================================

	fio_cortado.queue_free()

	fio_em_cima = null
