extends BaseScene

var failures: Array[String] = []
var original_save: Dictionary


func _ready() -> void:
	get_tree().set_meta(&"dev_mission_jump_active", true)
	original_save = SaveGame.save_data.duplicate(true)
	SaveGame.save_data = {}
	ContextualTutorial.cancelar_atual()
	ContextualTutorial.set_process(false)
	call_deferred("_run")


func _run() -> void:
	player = preload("res://Player/ManPlayer.tscn").instantiate()
	player.checkpoint_enabled = false
	player.starting_gun_enabled = false
	player.get_node("QUEST_MISSION").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	await _frames(3)
	for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		player.set_physics_process(false)
		player.global_position = Vector2.ZERO
		player.reset_physics_interpolation()
		var distance := 14.0 if side.x != 0.0 else 18.0
		var object := _object(Vector2(0.0, -5.0) + side * distance)
		await _frames(3)
		player.set_physics_process(true)
		player.cardinal_direction = side
		player.tentar_pegar_objeto()
		_expect(player.objeto_manipulado == object, "Deve ser possível segurar um objeto pelo lado %s." % side)
		if player.objeto_manipulado != object:
			object.queue_free()
			await _frames(2)
			continue
		var offset := object.global_position - player.global_position
		var before := object.global_position
		await _move(side, 6)
		_expect((object.global_position - before).dot(side) > 0.5, "Empurrar deve mover o objeto na direção %s." % side)
		_expect((object.global_position - player.global_position).is_equal_approx(offset), "Empurrar deve manter a posição relativa do jogador e do objeto.")
		before = object.global_position
		await _move(-side, 6)
		_expect((object.global_position - before).dot(-side) > 0.5, "Puxar deve funcionar na direção %s." % -side)
		var transverse := Vector2.UP if side.x != 0.0 else Vector2.RIGHT
		before = object.global_position
		await _move(transverse, 6)
		_expect((object.global_position - before).dot(transverse) > 0.5, "Deve ser possível mudar o eixo de movimento sem soltar o objeto.")
		_expect((object.global_position - player.global_position).is_equal_approx(offset), "Mudar o eixo deve manter a distância entre jogador e objeto.")
		var wall := _wall(object.global_position + side * 12.0, side)
		await _frames(2)
		await _move(side, 25)
		before = object.global_position
		var player_before := player.global_position
		await _move(side, 5)
		_expect(object.global_position.is_equal_approx(before) and player.global_position.is_equal_approx(player_before), "Uma parede diante do objeto deve parar os dois na direção %s." % side)
		_expect(not player.drag_sfx.playing, "O som de arrastar deve parar quando o objeto estiver bloqueado.")
		wall.queue_free()
		await _frames(2)
		var player_support := 8.0 if side.x != 0.0 else 12.0
		wall = _wall(player.global_position + Vector2(0.0, -5.0) - side * (player_support + 5.0), side)
		await _frames(2)
		await _move(-side, 25)
		before = object.global_position
		player_before = player.global_position
		await _move(-side, 5)
		_expect(object.global_position.is_equal_approx(before) and player.global_position.is_equal_approx(player_before), "Uma parede atrás do jogador deve impedir que ele puxe o objeto através dela.")
		player.soltar_objeto()
		_expect(not player.get_collision_exceptions().has(object) and not object.get_collision_exceptions().has(player), "Soltar deve restaurar a colisão entre jogador e objeto.")
		wall.queue_free()
		object.queue_free()
		await _frames(3)
	var saved_object := ObjetoEmpurravel.new()
	saved_object.save_id = "push_four_directions_fixture"
	add_child(saved_object)
	saved_object.position = Vector2(31.0, 47.0)
	saved_object._process(0.0)
	var restored_object := ObjetoEmpurravel.new()
	restored_object.save_id = saved_object.save_id
	add_child(restored_object)
	_expect(restored_object.position == saved_object.position, "O save deve restaurar os dois eixos do objeto.")
	SaveGame.save_object_state("push_legacy_fixture", {"position_x": 12.0})
	var legacy_object := ObjetoEmpurravel.new()
	legacy_object.save_id = "push_legacy_fixture"
	legacy_object.position = Vector2(3.0, 19.0)
	add_child(legacy_object)
	_expect(legacy_object.position == Vector2(12.0, 19.0), "Saves antigos com apenas X devem preservar o Y original.")
	SaveGame.save_data = original_save
	var report := FileAccess.open("res://.push-four-directions-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	for failure in failures:
		push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)


func _object(at: Vector2) -> ObjetoEmpurravel:
	var object := ObjetoEmpurravel.new()
	object.position = at
	object.save_enabled = false
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12.0, 12.0)
	collision.shape = shape
	object.add_child(collision)
	add_child(object)
	return object


func _wall(at: Vector2, side: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2.0, 300.0) if side.x != 0.0 else Vector2(300.0, 2.0)
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)
	return wall


func _move(side: Vector2, count: int) -> void:
	var action: StringName = &"left" if side == Vector2.LEFT else &"right" if side == Vector2.RIGHT else &"up" if side == Vector2.UP else &"down"
	Input.action_press(action)
	await _frames(count)
	Input.action_release(action)
	await _frames(2)


func _frames(count: int) -> void:
	for index in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
