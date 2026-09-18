extends Node

const GAMEPLAY := preload("res://Minigames/PuzzleDosCanos/tscn/gameplay.tscn")
const GENERATIONS := 1000

var failures: Array[String] = []


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--pipe-generation-test"):
		get_tree().quit(2)
		return
	_run()


func _run() -> void:
	var game := GAMEPLAY.instantiate()
	game.call("iniciar_grade")
	var rotas_diferentes: Dictionary = {}
	for generation in range(GENERATIONS):
		game.call("configurar_canos")
		_expect(
			bool(game.call("_caminho_gerado_e_valido")),
			"A geração %d não possui rota válida." % generation
		)
		var caminho: Array = game.get("caminho_solucao")
		var solucao: Dictionary = game.get("solucao_tipos")
		var grade: Array = game.get("grade")
		_expect(caminho.size() == 13, "A rota precisa ligar os dois cantos em 13 peças.")
		_expect(caminho.front() == Vector2i(0, 0), "A rota precisa começar na entrada.")
		_expect(caminho.back() == Vector2i(6, 6), "A rota precisa terminar antes da saída.")
		var assinatura := ""
		for posicao: Vector2i in caminho:
			assinatura += "%d,%d;" % [posicao.x, posicao.y]
			var correto := int(solucao[posicao])
			var atual := int(grade[posicao.y][posicao.x].type)
			_expect(
				_mesmo_formato(atual, correto),
				"Uma peça da rota não pode ser girada até a orientação correta."
			)
		rotas_diferentes[assinatura] = true
	game.queue_free()
	_expect(rotas_diferentes.size() > 20, "O gerador deve produzir rotas variadas.")
	if failures.is_empty():
		print("PIPE_PUZZLE_GENERATION_TEST_PASSED: ", GENERATIONS)
		get_tree().quit(0)
	else:
		print("PIPE_PUZZLE_GENERATION_TEST_FAILED: ", failures)
		get_tree().quit(1)


func _mesmo_formato(atual: int, correto: int) -> bool:
	var atual_reto := atual <= 1
	var correto_reto := correto <= 1
	return atual_reto == correto_reto


func _expect(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
		push_error(message)
