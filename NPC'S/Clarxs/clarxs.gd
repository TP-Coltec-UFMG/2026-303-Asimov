extends Node2D


@export_category("NPC")

@export var sprite_sheet: Texture2D
@export var dialog_texts: Array[String] = []


@export_category("NPC Movement")

@export var walk_speed: float = 30.0
@export var run_speed: float = 60.0

@export var walk_animation_speed: float = 8.0
@export var run_animation_speed: float = 14.0


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
# NPC
# ============================================================

var movement_points: Array[NPCMovementPoint] = []
var point_positions: Array[Vector2] = []

var player_in_range := false
var player_ref: Node2D = null

var current_point := -1
var waiting := false

var last_direction := Vector2.DOWN


@onready var interaction_icon = $Clarxs
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	interaction_icon.visible = false

	setup_sprite_sheet()

	load_movement_points()

	current_point = get_next_valid_point(0)

	if current_point == -1:
		play_idle(last_direction)


# ============================================================
# CRIAR SPRITE FRAMES
# ============================================================

func setup_sprite_sheet():
	if sprite_sheet == null:
		push_warning("Nenhuma Sprite Sheet foi colocada no NPC.")
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

	# Frames 49 até 54
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

	# Frames 55 até 60
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

	# Frames 67 até 72
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
	# Usa EXATAMENTE os mesmos frames do WALK.
	# A diferença é apenas o FPS.

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
# CRIAR UMA ANIMAÇÃO A PARTIR DO NÚMERO DO FRAME
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
):
	frames.add_animation(animation_name)

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
):
	# Os frames que você informou começam em 1.
	# Internamente precisamos começar em 0.

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
# CARREGAR PONTOS DE MOVIMENTO
# ============================================================

func load_movement_points():
	movement_points.clear()
	point_positions.clear()

	for child in get_children():
		if child is NPCMovementPoint:
			movement_points.append(child)
			point_positions.append(child.global_position)


# ============================================================
# PROCESS
# ============================================================

func _process(delta):
	if player_in_range and player_ref:
		update_direction()
	else:
		update_movement(delta)


# ============================================================
# MOVIMENTO
# ============================================================

func update_movement(delta):
	if waiting:
		return

	if current_point == -1:
		return

	var point = movement_points[current_point]
	var target = point_positions[current_point]

	var speed = walk_speed

	if point.movement_type == NPCMovementPoint.MovementType.RUN:
		speed = run_speed

	var direction = global_position.direction_to(target)

	if direction != Vector2.ZERO:
		last_direction = direction

	global_position = global_position.move_toward(
		target,
		speed * delta
	)

	update_movement_animation(
		direction,
		point.movement_type
	)

	if global_position.distance_to(target) < 1.0:
		global_position = target

		play_idle(last_direction)

		if point.wait_time > 0:
			wait_at_point(point.wait_time)
		else:
			go_to_next_point()


# ============================================================
# PEGAR PRÓXIMO PONTO
# ============================================================

func get_next_valid_point(starting_point: int) -> int:
	if movement_points.is_empty():
		return -1

	for i in range(movement_points.size()):
		var point_index = (
			starting_point + i
		) % movement_points.size()

		if movement_points[point_index].enabled:
			return point_index

	return -1


func go_to_next_point():
	if current_point == -1:
		return

	current_point = get_next_valid_point(
		current_point + 1
	)


# ============================================================
# ESPERAR NO PONTO
# ============================================================

func wait_at_point(time: float):
	waiting = true

	play_idle(last_direction)

	await get_tree().create_timer(time).timeout

	waiting = false

	go_to_next_point()


# ============================================================
# ANIMAÇÃO DE MOVIMENTO
# ============================================================

func update_movement_animation(
	direction: Vector2,
	movement_type: NPCMovementPoint.MovementType
):
	if direction == Vector2.ZERO:
		play_idle(last_direction)
		return

	var animation_prefix := "walk"

	if movement_type == NPCMovementPoint.MovementType.RUN:
		animation_prefix = "run"


	# ========================================================
	# LATERAL
	# ========================================================

	if abs(direction.x) > abs(direction.y):
		sprite.play(animation_prefix + "_side")

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
			sprite.play(animation_prefix + "_down")
		else:
			sprite.play(animation_prefix + "_up")


# ============================================================
# IDLE
# ============================================================

func play_idle(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		sprite.play("idle_side")

		if direction.x > 0:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

	else:
		sprite.flip_h = false

		if direction.y > 0:
			sprite.play("idle_down")
		else:
			sprite.play("idle_up")


# ============================================================
# INPUT / DIÁLOGO
# ============================================================

func _unhandled_input(event):
	if player_in_range \
	and event.is_action_pressed("ui_accept") \
	and not DialogManager.is_showing_dialog:

		print("COMECAR DIALOGO")

		DialogManager.start_dialog(dialog_texts)


# ============================================================
# PLAYER ENTROU NA ÁREA
# ============================================================

func _on_area_2d_body_entered(body):
	if body is Player:
		player_in_range = true
		player_ref = body

		interaction_icon.visible = true


# ============================================================
# PLAYER SAIU DA ÁREA
# ============================================================

func _on_area_2d_body_exited(body):
	if body is Player:
		player_in_range = false
		player_ref = null

		interaction_icon.visible = false


# ============================================================
# OLHAR PARA O PLAYER
# ============================================================

func update_direction():
	var dir = player_ref.global_position - global_position

	if dir == Vector2.ZERO:
		return

	last_direction = dir

	play_idle(dir)
