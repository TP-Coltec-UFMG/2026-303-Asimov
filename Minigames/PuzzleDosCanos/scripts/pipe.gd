extends Node2D

enum PipeType {
	Horizontal,
	Vertical,
	LeftDown,
	RightDown,
	UpLeft,
	UpRight,
}

enum FlowDir {
	Right,
	Up,
	Left,
	Down,
}

var RETANGULOS := {
	# Offset X a partir de (8, 0), espelhamento e rotação.
	# Espelhamento:
	# 0 = nenhum
	# 1 = horizontal
	# 2 = vertical
	# 3 = horizontal e vertical
	#
	# O último valor indica se deve rotacionar 90 graus.
	PipeType.Horizontal: [0, 0, true],
	PipeType.Vertical: [0, 0, false],
	PipeType.LeftDown: [8, 0, false],
	PipeType.RightDown: [8, 1, false],
	PipeType.UpLeft: [8, 2, false],
	PipeType.UpRight: [8, 3, false],
}

# Mantive "type" porque o script principal usa cano.type.
var type = null

@export var anim_frame := 0

var filled := false
var filling := false


func fill(direcao_fluxo: int) -> void:
	match [direcao_fluxo, type]:
		[_, PipeType.Horizontal], [_, PipeType.Vertical]:
			if direcao_fluxo == FlowDir.Right:
				$pipe/fill.flip_v = true

		[FlowDir.Left, _], [FlowDir.Right, _]:
			$pipe/fill.region_rect.position.y = 72

	$pipe/fill.show()
	$tm_next.start()
	$tm_end.start()


func unfill() -> void:
	$pipe/fill.hide()
	$pipe/fill.region_rect.position.x = 96
	$pipe/fill.region_rect.position.y = 56

	filled = false
	filling = false


func flip() -> void:
	match type:
		PipeType.Horizontal:
			set_type(PipeType.Vertical)
		PipeType.Vertical:
			set_type(PipeType.Horizontal)
		PipeType.LeftDown:
			set_type(PipeType.UpLeft)
		PipeType.UpLeft:
			set_type(PipeType.UpRight)
		PipeType.UpRight:
			set_type(PipeType.RightDown)
		PipeType.RightDown:
			set_type(PipeType.LeftDown)


func set_type(novo_tipo: int) -> void:
	type = novo_tipo
	update_rect()

	if not $pipe.visible:
		$placeholder.hide()
		$pipe.show()


func update_rect() -> void:
	var retangulo = RETANGULOS[type]

	$pipe.region_rect.position.x = 8 + retangulo[0]
	$pipe/fill.region_rect.position.y = 56 + retangulo[0]

	$pipe.flip_h = bool(retangulo[1] & 1)
	$pipe.flip_v = bool(retangulo[1] & 2)

	$pipe/fill.flip_h = $pipe.flip_h
	$pipe/fill.flip_v = $pipe.flip_v

	if retangulo[2]:
		$pipe.rotation_degrees = 90
	else:
		$pipe.rotation_degrees = 0


func _on_tm_next_timeout() -> void:
	var x: float = $pipe/fill.region_rect.position.x
	x = minf(x + 8.0, 120.0)
	$pipe/fill.region_rect.position.x = x


func _on_tm_end_timeout() -> void:
	$tm_next.stop()
	filled = true
	filling = false
