extends Node

# Executar com renderizador real, na cópia isolada do projeto:
# godot --path <copy> res://Tests/color_accessibility_render_test.tscn -- --accessibility-render-test
# Opcional: --reference=<caminho de uma captura do jogo sem auxílio>
const MAP_SHADER = preload("res://shaders/mapa_acessibilidade.gdshader")
const CUE_SHADER = preload("res://shaders/filtro_daltonismo.gdshader")
var failures: Array[String] = []

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--accessibility-render-test"):
		get_tree().quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Este teste precisa de renderização real; remova --headless.")
		get_tree().quit(2)
		return
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		push_error("COLOR_ACCESSIBILITY_RENDER_TEST_TIMEOUT")
		get_tree().quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var source := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [Color.BLACK, Color.WHITE, Color(0.4, 0.4, 0.4), Color(0.40, 0.24, 0.08), Color(0.75, 0.15, 0.15), Color(0.15, 0.65, 0.20), Color(0.12, 0.30, 0.80), Color(0.80, 0.75, 0.12)]
	for index in colors.size():
		source.fill_rect(Rect2i(index * 32, 0, 32, 32), colors[index])
	var results: Array[Image] = []
	for mode in range(4):
		results.append(await _render_map(source, mode))
	_expect(_difference(source, results[0]) <= 0.005, "Desligado deve preservar a imagem.")
	for mode in range(1, 4):
		for index in range(4):
			_expect(_color_difference(results[mode].get_pixel(index * 32 + 16, 16), results[0].get_pixel(index * 32 + 16, 16)) <= 0.005, "Neutros e madeira devem permanecer estáveis no modo %d." % mode)
		_expect(_difference(results[0], results[mode]) <= 0.125, "A assistência deve limitar a mudança por canal.")
		_expect(_difference(results[0], results[mode]) >= 0.02, "O modo %d precisa produzir uma pista visível." % mode)
	_expect(_difference(results[1], results[2]) > 0.01, "Protan e Deutan devem ter respostas distintas.")
	await _check_outline()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--reference="):
			var reference := Image.load_from_file(argument.trim_prefix("--reference="))
			if reference == null:
				_expect(false, "Captura de referência não encontrada.")
				continue
			for mode in range(4):
				var rendered := await _render_map(reference, mode)
				rendered.save_png("user://accessibility_mode_%d.png" % mode)
			print("RENDER_OUTPUT: ", OS.get_user_data_dir())
	if failures.is_empty():
		print("COLOR_ACCESSIBILITY_RENDER_TEST_PASSED")
	else:
		print("COLOR_ACCESSIBILITY_RENDER_TEST_FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	add_child(viewport)
	return viewport

func _render_map(source: Image, mode: int) -> Image:
	var viewport := _viewport(source.get_size())
	var picture := TextureRect.new()
	picture.texture = ImageTexture.create_from_image(source)
	viewport.add_child(picture)
	var overlay := ColorRect.new()
	overlay.size = source.get_size()
	var shader_material := ShaderMaterial.new()
	shader_material.shader = MAP_SHADER
	shader_material.set_shader_parameter("modo", mode)
	overlay.material = shader_material
	viewport.add_child(overlay)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	viewport.queue_free()
	return result

func _check_outline() -> void:
	var viewport := _viewport(Vector2i(16, 16))
	var background := ColorRect.new()
	background.size = Vector2(16, 16)
	background.color = Color(0.4, 0.4, 0.4)
	viewport.add_child(background)
	var source := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	source.fill(Color.TRANSPARENT)
	source.fill_rect(Rect2i(4, 4, 8, 8), Color(0.30, 0.60, 0.20))
	var texture := ImageTexture.create_from_image(source)
	var sprite := TextureRect.new()
	sprite.texture = texture
	viewport.add_child(sprite)
	var outline := TextureRect.new()
	outline.texture = texture
	var shader_material := ShaderMaterial.new()
	shader_material.shader = CUE_SHADER
	shader_material.set_shader_parameter("sprite_texture", texture)
	shader_material.set_shader_parameter("outline_uv", Vector2.ONE / 16.0)
	outline.material = shader_material
	viewport.add_child(outline)
	var darkness := CanvasModulate.new()
	viewport.add_child(darkness)
	for light in [1.0, 0.08]:
		darkness.color = Color(light, light, light)
		shader_material.set_shader_parameter("modo", 0)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var original := viewport.get_texture().get_image()
		shader_material.set_shader_parameter("modo", 1)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var assisted := viewport.get_texture().get_image()
		_expect(_color_difference(original.get_pixel(7, 7), assisted.get_pixel(7, 7)) <= 0.005, "Contorno não deve pintar ou iluminar o interior da sprite.")
		_expect(assisted.get_pixel(3, 7).r > 0.75, "Borda externa deve continuar clara no apagão.")
		_expect(assisted.get_pixel(4, 7).g < original.get_pixel(4, 7).g, "Borda interna deve fornecer contraste escuro.")
	viewport.queue_free()

func _color_difference(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))

func _difference(a: Image, b: Image) -> float:
	var largest := 0.0
	for y in a.get_height():
		for x in a.get_width():
			largest = maxf(largest, _color_difference(a.get_pixel(x, y), b.get_pixel(x, y)))
	return largest

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
