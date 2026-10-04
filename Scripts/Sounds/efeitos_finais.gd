extends Node2D

var proxima_explosao: int = 0
@onready var explosoes: Array[Node] = $Explosoes.get_children()


func explodir(posicao: Vector2, destruicao: bool = false, escala_tempo: float = 1.0) -> void:
	var escolhida: Node = explosoes[proxima_explosao]
	for explosao in explosoes:
		if not explosao.em_uso:
			escolhida = explosao
			break
	escolhida.iniciar(posicao, destruicao, escala_tempo)
	proxima_explosao = (proxima_explosao + 1) % explosoes.size()
