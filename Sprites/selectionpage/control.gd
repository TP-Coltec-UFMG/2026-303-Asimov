extends Control

var option_selected: String = ""
@onready var transition: AnimatedSprite2D = $"../Transition"


func _ready() -> void:
	await get_tree().process_frame
	$Job/Programador.grab_focus()

func SELECTED():

# --- PROGRAMADOR ---
	if option_selected == "programador":

		Configs.configs["job"] = "programador"
		$Job/Engenheiro.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Job/Programador, "modulate:a", 0.0, 0.1)
			blink.tween_property($Job/Programador, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Job/Engenheiro, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Job/Engenheiro.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		$Job.visible = false
		$Character.visible = true
		$CHOICETEXT.text = "SELECIONE SEU PERSONAGEM"
		transition.play_backwards("default")
		$Character/Character1.grab_focus()
		

# --- ENGENHEIRO ---
	elif option_selected == "engenheiro":
		Configs.configs["job"] = "engenheiro"
		$Job/Programador.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Job/Engenheiro, "modulate:a", 0.0, 0.1)
			blink.tween_property($Job/Engenheiro, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Job/Programador, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Job/Programador.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		$Job.visible = false
		$Character.visible = true
		$CHOICETEXT.text = "SELECIONE SEU PERSONAGEM"
		transition.play_backwards("default")
		$Character/Character1.grab_focus()

# --- CHARACTER 1 ---
	elif option_selected == "character1":
		Configs.configs["character"] = "character1"
		$Character/Character2.disabled = true
		$Character/Character3.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Character/Character1, "modulate:a", 0.0, 0.1)
			blink.tween_property($Character/Character1, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Character/Character2, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Character/Character3, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Character/Character2.visible = false
		$Character/Character3.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		$Character.visible = false
		$Difficulty.visible = true
		$CHOICETEXT.text = "SELECIONE A DIFICULDADE"
		transition.play_backwards("default")
		$Difficulty/Easy.grab_focus()

# --- CHARACTER 2 ---
	elif option_selected == "character2":
		Configs.configs["character"] = "character2"
		$Character/Character1.disabled = true
		$Character/Character3.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Character/Character2, "modulate:a", 0.0, 0.1)
			blink.tween_property($Character/Character2, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Character/Character1, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Character/Character3, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Character/Character1.visible = false
		$Character/Character3.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		$Character.visible = false
		$Difficulty.visible = true
		$CHOICETEXT.text = "SELECIONE A DIFICULDADE"
		transition.play_backwards("default")
		$Difficulty/Easy.grab_focus()

# --- CHARACTER 3 ---
	elif option_selected == "character3":
		Configs.configs["character"] = "character3"
		$Character/Character1.disabled = true
		$Character/Character3.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Character/Character3, "modulate:a", 0.0, 0.1)
			blink.tween_property($Character/Character3, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Character/Character1, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Character/Character2, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Character/Character1.visible = false
		$Character/Character2.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		$Character.visible = false
		$Difficulty.visible = true
		$CHOICETEXT.text = "SELECIONE A DIFICULDADE"
		transition.play_backwards("default")
		$Difficulty/Easy.grab_focus()

# --- EASY ---
	elif option_selected == "easy":
		Configs.configs["difficulty"] = "easy"
		$Difficulty/Normal.disabled = true
		$Difficulty/Hard.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Difficulty/Easy, "modulate:a", 0.0, 0.1)
			blink.tween_property($Difficulty/Easy, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Difficulty/Normal, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Difficulty/Hard, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Difficulty/Normal.visible = false
		$Difficulty/Hard.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		get_tree().change_scene_to_file("res://Scenes/andar_hall.tscn")

# --- NORMAL ---
	elif option_selected == "normal":
		Configs.configs["difficulty"] = "normal"
		$Difficulty/Easy.disabled = true
		$Difficulty/Hard.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Difficulty/Normal, "modulate:a", 0.0, 0.1)
			blink.tween_property($Difficulty/Normal, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Difficulty/Easy, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Difficulty/Hard, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Difficulty/Easy.visible = false
		$Difficulty/Hard.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		get_tree().change_scene_to_file("res://Scenes/andar_hall.tscn")

# --- HARD ---
	elif option_selected == "hard":
		Configs.configs["difficulty"] = "hard"
		$Difficulty/Easy.disabled = true
		$Difficulty/Normal.disabled = true

		var blink = create_tween()
		for i in 5:
			blink.tween_property($Difficulty/Hard, "modulate:a", 0.0, 0.1)
			blink.tween_property($Difficulty/Hard, "modulate:a", 1.0, 0.1)

		var fade = create_tween()
		fade.tween_property($Difficulty/Easy, "modulate:a", 0.0, 0.3)
		fade.parallel().tween_property($Difficulty/Normal, "modulate:a", 0.0, 0.3)
		await fade.finished
		$Difficulty/Easy.visible = false
		$Difficulty/Normal.visible = false

		await blink.finished
		transition.play("default")
		await transition.animation_finished
		get_tree().change_scene_to_file("res://Scenes/andar_hall.tscn")

	SaveLoad.save_data = Configs.configs
	SaveLoad._save()
