@tool
extends Control

const TEXTURA := preload("res://Minigames/PuzzleDosCanos/textures/sheet.png")
const POSICAO_BASE := Vector2(66, 1)
const TAMANHO_CARACTERE := Vector2(5, 5)

@export var time: int = 0 # Tempo em segundos

signal finished


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var digitos := [
		floori(time / 600.0) % 10,
		floori(time / 60.0) % 10,
		10,
		floori((time % 60) / 10.0),
		time % 10,
	]

	var indice := 0

	for x in range(0, int(5 * TAMANHO_CARACTERE.x), int(TAMANHO_CARACTERE.x)):
		var retangulo_destino := Rect2(Vector2(x, 0), TAMANHO_CARACTERE)
		var retangulo_origem := Rect2(
			POSICAO_BASE + Vector2(TAMANHO_CARACTERE.x * digitos[indice], 0),
			TAMANHO_CARACTERE
		)

		draw_texture_rect_region(TEXTURA, retangulo_destino, retangulo_origem)

		indice += 1


func start() -> void:
	$tm.start()
	queue_redraw()


func pause() -> void:
	$tm.stop()


func stop() -> void:
	pause()
	finished.emit()


func _on_tm_timeout() -> void:
	time -= 1

	if time <= 0:
		time = 0
		queue_redraw()
		stop()
		return

	queue_redraw()
