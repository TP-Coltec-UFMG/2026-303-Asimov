extends Node2D


# ============================================================
# NPC
# ============================================================

@export_category("NPC")

@export var sprite_sheet: Texture2D
@export var dialog_texts: Array[String] = []


# ============================================================
# NPC MOVEMENT
# ============================================================

@export_category("NPC Movement")

@export var walk_speed: float = 30.0
@export var run_speed: float = 60.0

@export var walk_animation_speed: float = 8.0
@export var run_animation_speed: float = 14.0


# ============================================================
# DESESPERO
# ============================================================

@export_category("Desespero")

# Distância máxima do movimento desesperado.
@export var desperate_radius: float = 2.0

# Distância mínima de cada movimento.
@export var desperate_min_distance: float = 1.0

# Tempo mínimo parado.
@export var desperate_min_wait: float = 0.05

# Tempo máximo parado.
@export var desperate_max_wait: float = 3.0

# Chance de correr.
@export_range(0.0, 1.0) var desperate_run_chance: float = 0.85


# ============================================================
# SPRITE SHEET
# ============================================================

const SHEET_COLUMNS := 24
const SHEET_ROWS := 7


# IDLE
const IDLE_SIDE_FRAME := 1
const IDLE_UP_FRAME := 2
const IDLE_DOWN_FRAME := 4


# WALK / RUN
const SIDE_START_FRAME := 49
const UP_START_FRAME := 55
const DOWN_START_FRAME := 67

const MOVEMENT_FRAME_COUNT := 6


# ============================================================
# CAMINHOS
# ============================================================

# Caminho atualmente sendo seguido.
var current_path: NPCPath = null

# Pontos do caminho atualmente ativo.
var path_points: Array[Vector2] = []

# Cache com os pontos de TODOS os caminhos.
#
# Isso é necessário porque as Line2D são filhas do NPC.
# Guardamos as posições globais antes do NPC começar a andar.
var cached_path_points: Dictionary = {}

var current_point: int = -1
var path_finished := true


# ============================================================
# PLAYER
# ============================================================

var player_in_range := false
var player_ref: Node2D = null

var last_direction := Vector2.DOWN


# ============================================================
# DESESPERO VARIABLES
# ============================================================

var desperate := false

var desperate_origin := Vector2.ZERO
var desperate_target := Vector2.ZERO

var desperate_wait_timer := 0.0

var desperate_movement_type: int = NPCPath.MovementType.RUN

var rng := RandomNumberGenerator.new()


# ============================================================
# NODES
# ============================================================

@onready var interaction_icon = $Clarxs
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	rng.randomize()

	interaction_icon.visible = false

	setup_sprite_sheet()

	setup_paths()


# ============================================================
# CONFIGURAR TODOS OS CAMINHOS
# ============================================================

func setup_paths() -> void:
	cached_path_points.clear()

	var automatic_path: NPCPath = null


	for child in get_children():

		if child is NPCPath:

			var path: NPCPath = child


			# =================================================
			# CONECTAR SIGNAL
			# =================================================

			path.start_requested.connect(
				_on_path_start_requested
			)


			# =================================================
			# SALVAR POSIÇÕES GLOBAIS
			# =================================================

			var points: Array[Vector2] = []


			for point in path.points:

				var global_point := path.to_global(
					point
				)

				points.append(
					global_point
				)


			cached_path_points[path] = points


			# =================================================
			# CAMINHO AUTOMÁTICO
			# =================================================

			if path.start_automatically:

				if automatic_path == null:
					automatic_path = path

				else:
					push_warning(
						"Mais de um NPCPath está marcado como start_automatically. Apenas o primeiro será usado."
					)


	# =========================================================
	# COMEÇAR CAMINHO AUTOMÁTICO
	# =========================================================

	if automatic_path != null:
		start_path(automatic_path)

	else:
		path_finished = true
		play_idle(last_direction)


# ============================================================
# SIGNAL DE UMA LINE2D
# ============================================================

func _on_path_start_requested(path: NPCPath) -> void:
	start_path(path)


# ============================================================
# COMEÇAR UM CAMINHO
# ============================================================

func start_path(path: NPCPath) -> void:

	if path == null:
		return


	if not cached_path_points.has(path):

		push_warning(
			"O caminho solicitado não foi registrado pelo NPC."
		)

		return


	# ========================================================
	# CANCELAR ESTADO ANTERIOR
	# ========================================================

	# Isso automaticamente faz o caminho anterior parar.
	current_path = path

	desperate = false
	desperate_wait_timer = 0.0

	path_finished = false

	current_point = 0


	# ========================================================
	# PEGAR PONTOS DESTE CAMINHO
	# ========================================================

	path_points.clear()


	for point in cached_path_points[path]:
		path_points.append(point)


	# ========================================================
	# CAMINHO VAZIO
	# ========================================================

	if path_points.is_empty():

		push_warning(
			"O NPCPath '%s' não possui pontos."
			% path.name
		)

		path_finished = true
		current_point = -1

		play_idle(last_direction)

		return


# ============================================================
# PARAR CAMINHO ATUAL
# ============================================================

func stop_current_path() -> void:

	current_path = null

	path_points.clear()

	current_point = -1
	path_finished = true

	desperate = false
	desperate_wait_timer = 0.0

	play_idle(last_direction)


# ============================================================
# CRIAR SPRITE FRAMES
# ============================================================

func setup_sprite_sheet() -> void:

	if sprite_sheet == null:

		push_warning(
			"Nenhuma Sprite Sheet foi colocada no NPC."
		)

		return


	var texture_width := sprite_sheet.get_width()
	var texture_height := sprite_sheet.get_height()


	if texture_width % SHEET_COLUMNS != 0:

		push_warning(
			"A largura da Sprite Sheet não é divisível por 24."
		)


	if texture_height % SHEET_ROWS != 0:

		push_warning(
			"A altura da Sprite Sheet não é divisível por 7."
		)


	@warning_ignore("integer_division")
	var frame_width := texture_width / SHEET_COLUMNS


	@warning_ignore("integer_division")
	var frame_height := texture_height / SHEET_ROWS


	var frames := SpriteFrames.new()

	frames.remove_animation("default")


	# ========================================================
	# IDLE
	# ========================================================

	create_animation_from_frames(
		frames,
		"idle_side",
		IDLE_SIDE_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)


	create_animation_from_frames(
		frames,
		"idle_up",
		IDLE_UP_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)


	create_animation_from_frames(
		frames,
		"idle_down",
		IDLE_DOWN_FRAME,
		1,
		frame_width,
		frame_height,
		1.0,
		false
	)


	# ========================================================
	# WALK
	# ========================================================

	create_animation_from_frames(
		frames,
		"walk_side",
		SIDE_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)


	create_animation_from_frames(
		frames,
		"walk_up",
		UP_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)


	create_animation_from_frames(
		frames,
		"walk_down",
		DOWN_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		walk_animation_speed,
		true
	)


	# ========================================================
	# RUN
	# ========================================================

	create_animation_from_frames(
		frames,
		"run_side",
		SIDE_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)


	create_animation_from_frames(
		frames,
		"run_up",
		UP_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)


	create_animation_from_frames(
		frames,
		"run_down",
		DOWN_START_FRAME,
		MOVEMENT_FRAME_COUNT,
		frame_width,
		frame_height,
		run_animation_speed,
		true
	)


	sprite.sprite_frames = frames

	sprite.play("idle_down")


# ============================================================
# CRIAR ANIMAÇÃO
# ============================================================

func create_animation_from_frames(
	frames: SpriteFrames,
	animation_name: StringName,
	start_frame: int,
	frame_count: int,
	frame_width: int,
	frame_height: int,
	fps: float,
	loop: bool
) -> void:

	frames.add_animation(
		animation_name
	)

	frames.set_animation_speed(
		animation_name,
		fps
	)

	frames.set_animation_loop(
		animation_name,
		loop
	)


	for i in range(frame_count):

		var frame_number := start_frame + i

		add_frame_to_animation(
			frames,
			animation_name,
			frame_number,
			frame_width,
			frame_height
		)


# ============================================================
# PEGAR FRAME DA SPRITE SHEET
# ============================================================

func add_frame_to_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	frame_number: int,
	frame_width: int,
	frame_height: int
) -> void:

	var frame_index := frame_number - 1

	var column := frame_index % SHEET_COLUMNS


	@warning_ignore("integer_division")
	var row := frame_index / SHEET_COLUMNS


	var atlas := AtlasTexture.new()

	atlas.atlas = sprite_sheet


	atlas.region = Rect2(
		column * frame_width,
		row * frame_height,
		frame_width,
		frame_height
	)


	frames.add_frame(
		animation_name,
		atlas
	)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	# ========================================================
	# PLAYER PERTO
	# ========================================================

	if player_in_range and player_ref:

		update_direction()

		return


	# ========================================================
	# DESESPERADO
	# ========================================================

	if desperate:

		update_desperate_movement(
			delta
		)

		return


	# ========================================================
	# CAMINHO NORMAL
	# ========================================================

	update_movement(
		delta
	)


# ============================================================
# MOVIMENTO NORMAL
# ============================================================

func update_movement(delta: float) -> void:

	if current_path == null:
		return


	if path_finished:
		return


	if path_points.is_empty():
		return


	if current_point < 0:
		return


	if current_point >= path_points.size():
		return


	var target := path_points[
		current_point
	]


	# ========================================================
	# VELOCIDADE DO CAMINHO
	# ========================================================

	var speed := walk_speed


	if current_path.movement_type == NPCPath.MovementType.RUN:

		speed = run_speed


	# ========================================================
	# DIREÇÃO
	# ========================================================

	var direction := global_position.direction_to(
		target
	)


	if direction != Vector2.ZERO:
		last_direction = direction


	# ========================================================
	# MOVIMENTO
	# ========================================================

	global_position = global_position.move_toward(
		target,
		speed * delta
	)


	# ========================================================
	# ANIMAÇÃO
	# ========================================================

	update_movement_animation(
		direction,
		current_path.movement_type
	)


	# ========================================================
	# CHEGOU NO PONTO
	# ========================================================

	if global_position.distance_to(
		target
	) < 1.0:

		global_position = target

		go_to_next_path_point()


# ============================================================
# PRÓXIMO PONTO
# ============================================================

func go_to_next_path_point() -> void:

	current_point += 1


	# Ainda existem pontos.
	if current_point < path_points.size():
		return


	# ========================================================
	# TERMINOU O CAMINHO
	# ========================================================

	if current_path == null:
		return


	# ========================================================
	# LOOP
	# ========================================================

	if current_path.loop_path:

		current_point = 0

		return


	# ========================================================
	# DESESPERO
	# ========================================================

	if current_path.desperate_at_end:

		start_desperate_mode()

		return


	# ========================================================
	# PARAR
	# ========================================================

	path_finished = true
	current_point = -1

	play_idle(
		last_direction
	)


# ============================================================
# COMEÇAR DESESPERO
# ============================================================

func start_desperate_mode() -> void:

	path_finished = true
	current_point = -1

	desperate = true


	# O centro é o último ponto
	# do caminho que terminou.
	desperate_origin = global_position


	choose_random_desperate_target()


# ============================================================
# ESCOLHER DESTINO ALEATÓRIO
# ============================================================

func choose_random_desperate_target() -> void:

	var random_angle := rng.randf_range(
		0.0,
		TAU
	)


	var random_distance := rng.randf_range(
		desperate_min_distance,
		desperate_radius
	)


	var offset := Vector2.RIGHT.rotated(
		random_angle
	) * random_distance


	desperate_target = (
		desperate_origin
		+ offset
	)


	# ========================================================
	# CORRER OU ANDAR
	# ========================================================

	if rng.randf() <= desperate_run_chance:

		desperate_movement_type = (
			NPCPath.MovementType.RUN
		)

	else:

		desperate_movement_type = (
			NPCPath.MovementType.WALK
		)


# ============================================================
# MOVIMENTO DE DESESPERO
# ============================================================

func update_desperate_movement(
	delta: float
) -> void:

	# ========================================================
	# ESPERANDO
	# ========================================================

	if desperate_wait_timer > 0.0:

		desperate_wait_timer -= delta

		play_idle(
			last_direction
		)

		return


	# ========================================================
	# DIREÇÃO
	# ========================================================

	var direction := global_position.direction_to(
		desperate_target
	)


	if direction != Vector2.ZERO:
		last_direction = direction


	# ========================================================
	# VELOCIDADE
	# ========================================================

	var speed := walk_speed


	if desperate_movement_type == NPCPath.MovementType.RUN:

		speed = run_speed


	# ========================================================
	# MOVIMENTO
	# ========================================================

	global_position = global_position.move_toward(
		desperate_target,
		speed * delta
	)


	# ========================================================
	# ANIMAÇÃO
	# ========================================================

	update_movement_animation(
		direction,
		desperate_movement_type
	)


	# ========================================================
	# CHEGOU
	# ========================================================

	if global_position.distance_to(
		desperate_target
	) < 1.0:

		global_position = desperate_target


		desperate_wait_timer = rng.randf_range(
			desperate_min_wait,
			desperate_max_wait
		)


		choose_random_desperate_target()


# ============================================================
# ANIMAÇÃO DE MOVIMENTO
# ============================================================

func update_movement_animation(
	direction: Vector2,
	type: int
) -> void:

	if direction == Vector2.ZERO:

		play_idle(
			last_direction
		)

		return


	var animation_prefix := "walk"


	if type == NPCPath.MovementType.RUN:

		animation_prefix = "run"


	# ========================================================
	# LATERAL
	# ========================================================

	if abs(direction.x) > abs(direction.y):

		sprite.play(
			animation_prefix + "_side"
		)


		if direction.x > 0:

			sprite.flip_h = false

		else:

			sprite.flip_h = true


	# ========================================================
	# CIMA / BAIXO
	# ========================================================

	else:

		sprite.flip_h = false


		if direction.y > 0:

			sprite.play(
				animation_prefix + "_down"
			)

		else:

			sprite.play(
				animation_prefix + "_up"
			)


# ============================================================
# IDLE
# ============================================================

func play_idle(
	direction: Vector2
) -> void:

	if abs(direction.x) > abs(direction.y):

		sprite.play(
			"idle_side"
		)


		if direction.x > 0:

			sprite.flip_h = false

		else:

			sprite.flip_h = true


	else:

		sprite.flip_h = false


		if direction.y > 0:

			sprite.play(
				"idle_down"
			)

		else:

			sprite.play(
				"idle_up"
			)


# ============================================================
# INPUT / DIÁLOGO
# ============================================================

func _unhandled_input(
	event: InputEvent
) -> void:

	if (
		player_in_range
		and event.is_action_pressed("ui_accept")
		and not DialogManager.is_showing_dialog
	):

		print(
			"COMECAR DIALOGO"
		)

		DialogManager.start_dialog(
			dialog_texts
		)


# ============================================================
# PLAYER ENTROU NA ÁREA
# ============================================================

func _on_area_2d_body_entered(
	body
) -> void:

	if body is Player:

		player_in_range = true

		player_ref = body

		interaction_icon.visible = true


# ============================================================
# PLAYER SAIU DA ÁREA
# ============================================================

func _on_area_2d_body_exited(
	body
) -> void:

	if body is Player:

		player_in_range = false

		player_ref = null

		interaction_icon.visible = false


# ============================================================
# OLHAR PARA PLAYER
# ============================================================

func update_direction() -> void:

	if player_ref == null:
		return


	var dir := (
		player_ref.global_position
		- global_position
	)


	if dir == Vector2.ZERO:
		return


	last_direction = dir

	play_idle(
		dir
	)
