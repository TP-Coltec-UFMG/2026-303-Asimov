extends Node2D

# Recurso próprio do minigame de circuito; não compartilha UID com outros minigames.


@onready var linha: Line2D = $Line2D

@onready var terminal_a: Area2D = $Terminal_A
@onready var terminal_b: Area2D = $Terminal_B

@onready var pos_a: CollisionShape2D = \
	$Terminal_A/CollisionShape2D

@onready var pos_b: CollisionShape2D = \
	$Terminal_B/CollisionShape2D

@onready var colisao_fio: CollisionShape2D = \
	$Area2D/CollisionShape2D


var origem: Node2D = null
var destino: Node2D = null


# ==========================================
# INICIALIZAÇÃO
# ==========================================

func _ready() -> void:

	# Somente o FIO entra no grupo.
	# O Area2D filho não entra.

	add_to_group("fios")


	# ==========================================
	# CRIAR COLISÃO DO FIO
	# ==========================================

	if colisao_fio != null:

		colisao_fio.shape = SegmentShape2D.new()


	# ==========================================
	# INICIALIZAR LINE2D
	# ==========================================

	if linha != null:

		linha.clear_points()

		linha.add_point(
			Vector2.ZERO
		)

		linha.add_point(
			Vector2.ZERO
		)


# ==========================================
# CONECTAR FIO
# ==========================================

func conectar(
	ponto_origem: Node2D,
	ponto_destino: Node2D
) -> void:

	origem = ponto_origem
	destino = ponto_destino

	atualizar_fio()


# ==========================================
# PROCESSO
# ==========================================

func _process(_delta: float) -> void:

	if origem != null:

		if is_instance_valid(origem):

			terminal_a.global_position = \
				origem.global_position


	if destino != null:

		if is_instance_valid(destino):

			terminal_b.global_position = \
				destino.global_position


	atualizar_fio()


# ==========================================
# ATUALIZAR FIO
# ==========================================

func atualizar_fio() -> void:

	if origem == null:
		return


	if destino == null:
		return


	if not is_instance_valid(origem):
		return


	if not is_instance_valid(destino):
		return


	# ==========================================
	# LINE2D
	# ==========================================

	if linha != null:

		var ponto_a := linha.to_local(
			origem.global_position
		)

		var ponto_b := linha.to_local(
			destino.global_position
		)


		if linha.get_point_count() < 2:

			linha.clear_points()

			linha.add_point(
				Vector2.ZERO
			)

			linha.add_point(
				Vector2.ZERO
			)


		linha.set_point_position(
			0,
			ponto_a
		)

		linha.set_point_position(
			1,
			ponto_b
		)


	# ==========================================
	# COLISÃO DO FIO
	# ==========================================

	if colisao_fio == null:
		return


	if colisao_fio.shape == null:
		return


	var segmento := (
		colisao_fio.shape
		as SegmentShape2D
	)


	if segmento == null:
		return


	var colisao_a := colisao_fio.to_local(
		origem.global_position
	)

	var colisao_b := colisao_fio.to_local(
		destino.global_position
	)


	segmento.a = colisao_a
	segmento.b = colisao_b


	colisao_fio.shape = segmento

	colisao_fio.disabled = false
