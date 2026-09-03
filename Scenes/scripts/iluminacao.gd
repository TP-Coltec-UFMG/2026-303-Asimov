extends Node

@onready var luz_entrada: PointLight2D = $"Luz entrada"
@onready var luz_entrada_2: PointLight2D = $"Luz entrada2"
@onready var luz_entrada_3: PointLight2D = $"Luz entrada3"

var lampadas := []

func _ready() -> void:
	randomize()

	lampadas = [
		{
			"luz": luz_entrada,
			"base": luz_entrada.energy,
			"alvo": 0.0,
			"timer": randf_range(0.0, 2.0),
			"acesa": false
		},
		{
			"luz": luz_entrada_2,
			"base": luz_entrada_2.energy,
			"alvo": 0.0,
			"timer": randf_range(0.5, 3.0),
			"acesa": false
		},
		{
			"luz": luz_entrada_3,
			"base": luz_entrada_3.energy,
			"alvo": 0.0,
			"timer": randf_range(1.0, 4.0),
			"acesa": false
		}
	]

	for lampada in lampadas:
		lampada["luz"].energy = 0.0


func _process(delta: float) -> void:
	for lampada in lampadas:
		lampada["timer"] -= delta

		if lampada["timer"] <= 0.0:
			_atualizar_lampada(lampada)

		var luz: PointLight2D = lampada["luz"]
		var alvo: float = lampada["alvo"]

		luz.energy = lerp(luz.energy, alvo, delta * randf_range(12.0, 35.0))


func _atualizar_lampada(lampada: Dictionary) -> void:
	var base: float = lampada["base"]
	var chance := randf()

	if not lampada["acesa"]:
		if chance < 0.75:
			lampada["alvo"] = 0.0
			lampada["timer"] = randf_range(1.5, 6.0)
		else:
			lampada["acesa"] = true
			lampada["alvo"] = randf_range(0.4, 1.2) * base
			lampada["timer"] = randf_range(0.03, 0.35)

	else:
		if chance < 0.45:
			lampada["acesa"] = false
			lampada["alvo"] = 0.0
			lampada["timer"] = randf_range(1.0, 5.0)

		elif chance < 0.75:
			lampada["alvo"] = randf_range(0.02, 0.18) * base
			lampada["timer"] = randf_range(0.02, 0.15)

		elif chance < 0.9:
			lampada["alvo"] = randf_range(0.2, 0.7) * base
			lampada["timer"] = randf_range(0.03, 0.22)

		else:
			lampada["alvo"] = randf_range(1.0, 1.5) * base
			lampada["timer"] = randf_range(0.02, 0.12)
