extends Node

## Run in an isolated copy of the project with:
## godot --headless --path <copy> res://Tests/color_accessibility_test.tscn -- --accessibility-test
## No SaveLoad._save, collection or checkpoint operation is invoked by this test.

const CUE_SCENE := "res://Scenes/Utils/color_accessibility_cue.tscn"
const PLAYER_SCENE := preload("res://Player/ManPlayer.tscn")
const NPC_SCENE := preload("res://NPC'S/Clarxs.tscn")
const ITEM_SCENE := preload("res://Objects/cabo.tscn")

var failures: Array[String] = []
var fixtures: Array[Node] = []
var snapshots: Array[Dictionary] = []
var saved_config: Dictionary
var saved_game: Dictionary
var saved_mode: int


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--accessibility-test"):
		push_error("Execute este teste somente na cópia isolada com --accessibility-test.")
		get_tree().quit(2)
		return
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	saved_config = SaveLoad.save_data.duplicate(true)
	saved_game = SaveGame.save_data.duplicate(true)
	saved_mode = int(FiltroDaltonismo.get("modo"))
	SaveGame.save_data = {}
	HighContrast.set_enabled(false)
	FiltroDaltonismo.aplicar_filtro(0)

	_expect(FiltroDaltonismo.has_node("MapaAcessibilidade"), "O controlador precisa ter o overlay de assistência do mapa.")
	var mapa := FiltroDaltonismo.get_node_or_null("MapaAcessibilidade") as ColorRect
	_expect(mapa != null and mapa.material is ShaderMaterial, "O overlay do mapa precisa usar um ShaderMaterial.")
	_expect(not FiltroDaltonismo.has_node("TelaFiltro"), "O auxílio não pode usar um simulador de tela inteira.")
	_check_settings_scene("res://Scenes/principal.tscn")
	_check_settings_scene("res://Scenes/pause_menu.tscn")

	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.checkpoint_enabled = false
	player.position = Vector2(100, 100)
	add_child(player)
	fixtures.append(player)
	player.set_physics_process(false)
	player.animation_player.stop()

	var npc: Node2D = NPC_SCENE.instantiate() as Node2D
	npc.set("save_enabled", false)
	npc.set("dialog_enabled", false)
	npc.set("sprite_sheet", load("res://NPC'S/NPC/scientist_0.png"))
	npc.position = Vector2(300, 100)
	add_child(npc)
	fixtures.append(npc)
	npc.set_process(false)
	npc.set_physics_process(false)
	var npc_sprite := npc.get_node("AnimatedSprite2D") as AnimatedSprite2D
	npc_sprite.stop()

	var item: Node2D = ITEM_SCENE.instantiate() as Node2D
	item.set("save_id", "color_accessibility_test_item")
	item.position = Vector2(500, 100)
	add_child(item)
	fixtures.append(item)

	await _frames()
	var primary_sprites: Array[CanvasItem] = [
		player.sprite,
		npc_sprite,
		item.get_node("Sprite2D") as Sprite2D,
	]
	var cues: Array[CanvasItem] = []
	for visual: CanvasItem in primary_sprites:
		var found := _find_cues(visual)
		_expect(found.size() == 1, "%s precisa de exatamente um contorno instanciado na cena." % visual.get_path())
		if found.size() == 1:
			cues.append(found[0] as CanvasItem)

	for excluded_path: NodePath in [^"CanvasLayer", ^"Inventory", ^"BalaoDePensamento", ^"QUEST_MISSION"]:
		_expect(_find_cues(player.get_node(excluded_path)).is_empty(), "HUD, inventário e pensamentos não devem receber contornos: %s." % excluded_path)
	_expect(_find_cues(npc.get_node("BalaoDePensamento")).is_empty(), "O balão do NPC não deve receber contorno.")
	_expect(_find_cues(npc.get_node("InteractionPrompt")).is_empty(), "O texto de interação não deve receber contorno.")
	_expect(_find_cues(item.get_node("PointLight2D2")).is_empty(), "A iluminação do objeto não deve receber contorno.")

	FiltroDaltonismo.aplicar_filtro(0)
	HighContrast.set_enabled(true)
	await _frames()
	for cue: CanvasItem in cues:
		_expect(cue.is_visible_in_tree(), "Alto contraste deve ativar o contorno seletivo sem filtro cromático.")
	_expect(not mapa.visible, "Alto contraste não deve ativar o filtro cromático do mapa.")
	HighContrast.set_enabled(false)
	await _frames()
	for cue: CanvasItem in cues:
		_expect(not cue.is_visible_in_tree(), "Desativar alto contraste deve remover o contorno quando o filtro está desligado.")

	for fixture: Node in fixtures:
		_snapshot_visuals(fixture)
	var node_count: int = _fixture_node_count()
	for mode: int in [0, 1, 2, 3, 0]:
		FiltroDaltonismo.aplicar_filtro(mode)
		await _frames()
		_expect(int(FiltroDaltonismo.get("modo")) == mode, "O controlador deve conservar o modo selecionado.")
		for cue: CanvasItem in cues:
			_expect(cue.is_visible_in_tree() == (mode != 0), "O contorno deve acompanhar o modo %d: %s." % [mode, cue.get_path()])
		_expect(_fixture_node_count() == node_count, "Alternar o modo não pode criar ou duplicar nós.")
		_check_original_visuals()

	FiltroDaltonismo.aplicar_filtro(1)
	await _frames()
	await _check_changed_animation(player, npc, npc_sprite)
	item.hide()
	await _frames()
	var item_cues := _find_cues(item)
	for cue: Node in item_cues:
		_expect(not (cue as CanvasItem).is_visible_in_tree(), "O contorno não pode revelar um objeto oculto.")
	item.show()
	item.get_node("Interectable").set("is_interactable", false)
	await _frames()
	for cue: Node in item_cues:
		_expect(not (cue as CanvasItem).is_visible_in_tree(), "Itens indisponíveis não devem receber contorno.")
	item.get_node("Interectable").set("is_interactable", true)
	await _frames()
	await _check_wire_sockets()

	get_tree().paused = true
	FiltroDaltonismo.aplicar_filtro(0)
	await _frames()
	for cue: CanvasItem in cues:
		_expect(not cue.is_visible_in_tree(), "Desativar pelo menu de pausa deve esconder o contorno imediatamente.")
	FiltroDaltonismo.aplicar_filtro(2)
	await _frames()
	for cue: CanvasItem in cues:
		_expect(cue.is_visible_in_tree(), "Ativar pelo menu de pausa deve funcionar com o jogo pausado.")
	get_tree().paused = false

	await _check_inventory_materials(player)
	await _check_saved_mode(cues)
	await _finish()


func _check_inventory_materials(player: Player) -> void:
	var slot := player.get_node("Inventory/GridContainer/Slot3")
	for existing_item: bool in [false, true]:
		FiltroDaltonismo.aplicar_filtro(0)
		if existing_item:
			var pickup := ITEM_SCENE.instantiate() as Node2D
			add_child(pickup)
			_expect(bool(slot.call("put_existing_item_on_inventory", pickup)), "Guardar o item existente deve funcionar.")
		else:
			_expect(bool(slot.call("put_item_on_inventory", ITEM_SCENE)), "Restaurar o item no inventário deve funcionar.")
		await _frames()
		var stored: Node = slot.get("item")
		var cue := stored.get_node("Sprite2D/ColorAccessibilityCue") as CanvasItem
		var original_material: Material = cue.material
		_expect(original_material is ShaderMaterial, "O inventário não pode substituir o shader do contorno.")
		for mode: int in [1, 2, 3, 0]:
			FiltroDaltonismo.aplicar_filtro(mode)
			await _frames()
			_expect(cue.material == original_material, "Trocar o modo deve manter o shader do item guardado.")
			_expect(cue.visible == (mode != 0), "O contorno do inventário deve acompanhar o modo.")
		slot.call("clear_item")
		await _frames()


func _check_wire_sockets() -> void:
	var socket: Node2D = load("res://Minigames/Minigame2/Socket.tscn").instantiate() as Node2D
	add_child(socket)
	for socket_id: int in range(7):
		socket.set("socket_id", socket_id)
		await _frames()
		var plug := socket.get_node("Plug") as Sprite2D
		var cue := plug.get_node("ColorAccessibilityCue")
		_expect(cue.get("_texture") == plug.texture, "O contorno deve acompanhar cada um dos sete símbolos dos fios.")
		_expect((cue as CanvasItem).is_visible_in_tree(), "O conector interativo deve receber o auxílio.")
	socket.queue_free()
	await _frames()


func _check_changed_animation(player: Player, npc: Node2D, npc_sprite: AnimatedSprite2D) -> void:
	var player_material: Material = player.sprite.material
	var player_modulate: Color = player.sprite.modulate
	var replacement_texture := load("res://Player/Sprites/Alex_16x16_com_cabo.png") as Texture2D
	player.sprite.texture = replacement_texture
	player.sprite.frame = mini(2, player.sprite.hframes * player.sprite.vframes - 1)
	player.sprite.flip_h = true
	player.sprite.offset = Vector2(1, -1)

	var npc_material: Material = npc_sprite.material
	var npc_modulate: Color = npc_sprite.modulate
	npc.set("sprite_sheet", load("res://NPC'S/NPC/scientist_1.png"))
	npc.call("setup_sprite_sheet")
	npc_sprite.stop()
	npc_sprite.animation = &"walk_side"
	npc_sprite.frame = 3
	npc_sprite.flip_h = true
	npc_sprite.flip_v = true
	npc_sprite.offset = Vector2(-1, 1)
	var replacement_frames: SpriteFrames = npc_sprite.sprite_frames
	await _frames()

	for mode: int in [3, 0, 1]:
		FiltroDaltonismo.aplicar_filtro(mode)
		await _frames()
		_expect(player.sprite.texture == replacement_texture, "O auxílio deve preservar a sprite do item equipado.")
		_expect(player.sprite.flip_h and player.sprite.offset == Vector2(1, -1), "O auxílio não pode sobrescrever orientação e posição da sprite do Player.")
		_expect(player.sprite.material == player_material and player.sprite.modulate == player_modulate, "O auxílio não pode substituir o material original do Player.")
		_expect(npc_sprite.sprite_frames == replacement_frames, "O auxílio deve acompanhar a troca da roupa do NPC sem substituir SpriteFrames.")
		_expect(npc_sprite.animation == &"walk_side" and npc_sprite.frame == 3, "Alternar auxílio não pode reiniciar a animação do NPC.")
		_expect(npc_sprite.flip_h and npc_sprite.flip_v and npc_sprite.offset == Vector2(-1, 1), "O auxílio não pode modificar orientação e deslocamento do NPC.")
		_expect(npc_sprite.material == npc_material and npc_sprite.modulate == npc_modulate, "O auxílio não pode sobrescrever material e cores originais do NPC.")
		if mode != 0:
			var player_cue := player.sprite.get_node("ColorAccessibilityCue")
			var npc_cue := npc_sprite.get_node("ColorAccessibilityCue")
			_expect(player_cue.get("_texture") == replacement_texture, "O contorno deve acompanhar a textura equipada.")
			_expect(bool(player_cue.get("_flip_h")), "O contorno do Player deve acompanhar a orientação.")
			var frame_texture := replacement_frames.get_frame_texture(npc_sprite.animation, npc_sprite.frame) as AtlasTexture
			_expect(npc_cue.get("_texture") == frame_texture.atlas, "O contorno do NPC deve acompanhar a roupa atual.")
			_expect(npc_cue.get("_source") == frame_texture.region, "O contorno do NPC deve acompanhar o frame atual.")
			_expect(bool(npc_cue.get("_flip_h")) and bool(npc_cue.get("_flip_v")), "O contorno do NPC deve acompanhar ambas as orientações.")


func _check_saved_mode(cues: Array[CanvasItem]) -> void:
	for mode: int in [1, 2, 3, 0]:
		for legacy_intensity: float in [0.0, 1.0]:
			SaveLoad.save_data = saved_config.duplicate(true)
			SaveLoad.save_data["filtro_de_daltonismo"] = mode
			SaveLoad.save_data["intensidade_daltonismo"] = legacy_intensity
			SaveLoad.save_data["intensidade_filtro_daltonismo"] = legacy_intensity
			SaveLoad.save_data["intensidade"] = legacy_intensity
			SaveLoad.save_data["alto_contraste"] = false
			SaveLoad._apply_load()
			await _frames()
			_expect(int(FiltroDaltonismo.get("modo")) == mode, "Carregar as configurações deve restaurar o auxílio selecionado.")
			for cue: CanvasItem in cues:
				_expect(cue.is_visible_in_tree() == (mode != 0), "A intensidade antiga não deve controlar o novo auxílio.")


func _check_settings_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if not _expect(packed != null, "O menu precisa carregar: %s." % scene_path):
		return
	var menu: Node = packed.instantiate()
	_expect(menu.find_children("*IntensidadeDaltonismo*", "", true, false).is_empty(), "Remover o controle de intensidade de %s." % scene_path)
	var options := menu.find_children("OptionDaltonismoButton", "OptionButton", true, false)
	_expect(options.size() == 1, "O menu deve manter a seleção do auxílio de cores: %s." % scene_path)
	if options.size() == 1:
		_expect((options[0] as OptionButton).item_count == 4, "Manter desativado e os três perfis no menu.")
	_expect(_find_cues(menu).is_empty(), "Os elementos decorativos dos menus não devem ganhar contornos.")
	menu.free()


func _find_cues(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node.scene_file_path == CUE_SCENE:
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_find_cues(child))
	return found


func _snapshot_visuals(node: Node) -> void:
	if node.scene_file_path == CUE_SCENE:
		return
	if node is CanvasItem:
		var visual := node as CanvasItem
		var state: Dictionary = {
			"node": visual,
			"material": visual.material,
			"modulate": visual.modulate,
			"self_modulate": visual.self_modulate,
		}
		if visual is Sprite2D:
			state["texture"] = (visual as Sprite2D).texture
		elif visual is AnimatedSprite2D:
			state["sprite_frames"] = (visual as AnimatedSprite2D).sprite_frames
		snapshots.append(state)
	for child: Node in node.get_children():
		_snapshot_visuals(child)


func _check_original_visuals() -> void:
	for state: Dictionary in snapshots:
		var visual: CanvasItem = state["node"]
		_expect(visual.material == state["material"], "Material original preservado: %s." % visual.get_path())
		_expect(visual.modulate == state["modulate"] and visual.self_modulate == state["self_modulate"], "Cores originais preservadas: %s." % visual.get_path())
		if state.has("texture"):
			_expect((visual as Sprite2D).texture == state["texture"], "Textura original preservada: %s." % visual.get_path())
		elif state.has("sprite_frames"):
			_expect((visual as AnimatedSprite2D).sprite_frames == state["sprite_frames"], "Animações originais preservadas: %s." % visual.get_path())


func _fixture_node_count() -> int:
	var count: int = 0
	for fixture: Node in fixtures:
		count += 1 + fixture.find_children("*", "", true, false).size()
	return count


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	for fixture: Node in fixtures:
		fixture.queue_free()
	await _frames()
	# Changing the mode after freeing actors must not leave stale signal targets.
	FiltroDaltonismo.aplicar_filtro(0)
	SaveGame.save_data = saved_game
	SaveLoad.save_data = saved_config
	SaveLoad._apply_load()
	await _frames()
	FiltroDaltonismo.aplicar_filtro(saved_mode)
	if failures.is_empty():
		print("COLOR_ACCESSIBILITY_TEST_PASSED")
		get_tree().quit(0)
	else:
		print("COLOR_ACCESSIBILITY_TEST_FAILED: %d" % failures.size())
		get_tree().quit(1)
