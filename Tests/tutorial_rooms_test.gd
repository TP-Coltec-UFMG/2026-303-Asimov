extends Node

var failures: Array[String] = []
var tutorial: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var saved := SaveGame.save_data.duplicate(true)
	tutorial = preload("res://Tutorial/tutorial.tscn").instantiate()
	add_child(tutorial)
	await get_tree().process_frame
	await get_tree().physics_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-room="):
			tutorial._load_room(int(argument.get_slice("=", 1)))
			await _capture("sala_%02d" % (tutorial.current_stage + 1))
			get_tree().quit()
			return
	await _capture("01_movimento")
	_expect(tutorial.player.inventory.get_item_control("gun") == null, "O treino deve começar sem arma.")
	_expect(not tutorial.stage_complete, "A primeira sala deve exigir movimento.")
	var pause_event := InputEventAction.new()
	pause_event.action = &"esc"
	pause_event.pressed = true
	tutorial._unhandled_input(pause_event)
	_expect(get_tree().paused and not tutorial.player.can_process(), "Pausar deve parar o jogador.")
	tutorial._resume_tutorial()
	tutorial.player.global_position = tutorial.room.get_node("Zones/MoveZone").global_position
	await get_tree().create_timer(0.12).timeout
	_expect(tutorial.stage_complete, "Chegar à marca deve liberar a primeira saída.")
	tutorial._change_room()
	await get_tree().create_timer(0.8).timeout
	_expect(tutorial.current_stage == tutorial.Stage.RUN and not tutorial.transition_locked, "A saída deve levar à sala seguinte e devolver os controles.")
	tutorial.player.global_position = Vector2(65, 30)
	Input.action_press(&"right")
	Input.action_press(&"correr")
	await get_tree().create_timer(0.3).timeout
	Input.action_release(&"right")
	Input.action_release(&"correr")
	_expect(tutorial.stage_complete, "A sala de corrida deve reconhecer a corrida real.")
	tutorial._load_room(tutorial.Stage.PUSH)
	var crate: ObjetoEmpurravel = tutorial.room.get_node("Props/TargetCrate")
	tutorial.player.global_position = crate.global_position - Vector2(18, 0)
	tutorial.player.cardinal_direction = Vector2.RIGHT
	Input.action_press(&"right")
	await get_tree().create_timer(0.1).timeout
	_equip(&"empurrar")
	await get_tree().create_timer(0.05).timeout
	_expect(tutorial.player.objeto_manipulado == crate, "Deve ser possível segurar a caixa com o controle real.")
	Input.action_press(&"right")
	await get_tree().create_timer(1.7).timeout
	Input.action_release(&"right")
	_expect(tutorial.push_reached, "Empurrar até a marca deve iniciar a etapa de puxar.")
	Input.action_press(&"left")
	await get_tree().create_timer(0.4).timeout
	Input.action_release(&"left")
	_equip(&"empurrar")
	await get_tree().create_timer(0.1).timeout
	_expect(tutorial.stage_complete, "Puxar e soltar a caixa deve liberar a saída.")
	for first_item in ["cabo", "laptop"]:
		tutorial._load_room(tutorial.Stage.COLLECT)
		var second_item := "laptop" if first_item == "cabo" else "cabo"
		_collect(first_item)
		_expect(not tutorial.stage_complete, "Coletar só um item não deve concluir a sala.")
		_collect(second_item)
		_equip(&"use_laptop")
		tutorial._update_inventory()
		_equip(&"use_cabo")
		tutorial._update_inventory()
		_expect(tutorial.stage_complete, "Coleta e uso devem funcionar em qualquer ordem.")
	for stage in [tutorial.Stage.CARD_STANDARD, tutorial.Stage.CARD_STRONG, tutorial.Stage.CARD_BOSS]:
		tutorial._load_room(stage)
		await _capture("cartao_%d" % stage)
		tutorial._use_card()
		_expect(not tutorial.stage_complete, "Sem cartão, o leitor deve negar acesso.")
		_collect("cartao")
		tutorial._use_card()
		_expect(not tutorial.stage_complete, "O cartão precisa estar equipado.")
		_equip(&"use_cartao")
		tutorial._use_card()
		_expect(tutorial.stage_complete, "O cartão correto deve liberar a sala.")
	tutorial._load_room(tutorial.Stage.LIGHT)
	_collect("lanterna")
	_equip(&"use_lanterna")
	_expect(tutorial.player.usando_lanterna and tutorial.player.inventory.get_item_control("lanterna").lanterna_acessa, "A lanterna real deve acender ao equipar.")
	tutorial._load_room(tutorial.Stage.FIRE)
	await _capture("09_extintor")
	_collect("extintor")
	_equip(&"use_extintor")
	var fire: Node2D = tutorial.training_fire
	_expect(not fire.damage_enabled and not fire.save_enabled, "O fogo de treino não deve causar dano nem gravar progresso.")
	fire.iniciar_extincao()
	await get_tree().create_timer(4.3).timeout
	_expect(tutorial.stage_complete, "Apagar o fogo real deve liberar a saída.")
	tutorial._load_room(tutorial.Stage.WEAPON)
	await _capture("10_arma")
	_collect("gun")
	_equip(&"use_arma")
	var gun: Node2D = tutorial.player.inventory.get_item_control("gun")
	_expect(gun.municao_atual == 7, "O pente deve ter sete balas.")
	var bullet := preload("res://Objects/bullet.tscn").instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = tutorial.target.global_position - Vector2(30, 0)
	bullet.configurar(Vector2.RIGHT, tutorial.player)
	await get_tree().create_timer(0.15).timeout
	_expect(tutorial.target_hits == 1, "A bala real deve atingir o alvo de treino.")
	gun.municao_atual = 6
	gun._iniciar_recarga()
	tutorial._update_weapon()
	await get_tree().create_timer(1.3).timeout
	_expect(tutorial.weapon_reloaded and gun.municao_atual == 7, "A recarga real deve ser detectada.")
	tutorial.target.receber_dano_projetil(25.0)
	_expect(tutorial.stage_complete, "Acertar após recarregar deve concluir a sala.")
	_expect(SaveGame.save_data == saved, "Treinar não deve alterar o progresso da campanha.")
	tutorial.queue_free()
	await get_tree().process_frame
	for failure in failures:
		push_error(failure)
	if "--report" in OS.get_cmdline_user_args() or "--capture" in OS.get_cmdline_user_args():
		var report := FileAccess.open("res://.tutorial-results.json", FileAccess.WRITE)
		if report != null:
			report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures}, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)


func _collect(item_id: String) -> void:
	var props: Node = tutorial.room.get_node("Props")
	for pickup in props.get_children():
		var component := pickup.get_node_or_null("PickupComponent") as PickupComponent
		if component != null and component.item_id == item_id and not pickup.is_queued_for_deletion():
			tutorial._collect_item(pickup, item_id, load(pickup.scene_file_path))
			return
	_expect(false, "Item de treino não encontrado: " + item_id)


func _equip(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tutorial.player._input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _capture(name: String) -> void:
	var capture_enabled := "--capture" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		capture_enabled = capture_enabled or argument.begins_with("--preview-room=")
	if not capture_enabled:
		return
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.tutorial-preview")
	get_viewport().get_texture().get_image().save_png("res://.tutorial-preview/%s.png" % name)
