extends Node2D

const NPC_OBSTACLE_LAYER := 32

@export var bounds := Rect2(-178.0, -130.0, 384.0, 344.0)
@export var cell_size := 4.0

var grid := AStarGrid2D.new()
var query := PhysicsShapeQueryParameters2D.new()
var revision := 0
var static_cells: Dictionary = {}
var dynamic_cells: Dictionary = {}
var moving_objects: Array[ObjetoEmpurravel] = []
var previous_transforms: Array[Transform2D] = []
var polygon_cache: Dictionary = {}
var initialized := false
var elapsed := 0.0
var components: Dictionary = {}
var components_revision := -1
var initial_positions_checked := false
var warmup_frames := 2


func _ready() -> void:
	var world := get_parent()
	for sprite in world.get_node("HALL_QUEBRADO").get_children():
		if sprite is Sprite2D and sprite.name != &"Sprite07":
			_add_sprite_collision(sprite)
	for sprite in world.get_children():
		if sprite is Sprite2D:
			_add_sprite_collision(sprite)
	for object in world.get_node("Coletaveis").get_children():
		if object is Sprite2D:
			_add_sprite_collision(object)
		elif object is ObjetoEmpurravel:
			moving_objects.append(object)
			var sprite := object.get_node_or_null("Sprite2D") as Sprite2D
			if sprite != null:
				_add_sprite_collision(sprite)
	for npc in world.get_node("NPCs").get_children():
		npc.set_obstacle_navigation(self)
	var shape := CapsuleShape2D.new()
	shape.radius = 5.0
	shape.height = 12.0
	query.shape = shape
	query.collision_mask = 1 | NPC_OBSTACLE_LAYER
	query.margin = 2.0
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(bounds.size.x / cell_size) + 1, ceil(bounds.size.y / cell_size) + 1))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()


func _add_sprite_collision(sprite: Sprite2D) -> void:
	if sprite.texture == null or sprite.has_node("NPCObstacle"):
		return
	var texture := sprite.texture
	if not polygon_cache.has(texture):
		var bitmap := BitMap.new()
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		bitmap.create_from_image_alpha(image, 0.2)
		polygon_cache[texture] = bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), 2.0)
	var body := StaticBody2D.new()
	body.name = "NPCObstacle"
	body.collision_layer = NPC_OBSTACLE_LAYER
	body.collision_mask = 0
	for source: PackedVector2Array in polygon_cache[texture]:
		var points := PackedVector2Array()
		for point in source:
			var local_point := point + sprite.get_rect().position
			if sprite.flip_h:
				local_point.x = -local_point.x
			if sprite.flip_v:
				local_point.y = -local_point.y
			points.append(local_point)
		if points.size() >= 3:
			var collision := CollisionPolygon2D.new()
			collision.polygon = points
			body.add_child(collision)
	sprite.add_child(body)


func _physics_process(delta: float) -> void:
	if warmup_frames > 0:
		warmup_frames -= 1
		return
	elapsed += delta
	if not initialized or elapsed >= 0.25:
		elapsed = 0.0
		refresh()
	if not initial_positions_checked:
		initial_positions_checked = true
		var space := get_world_2d().direct_space_state
		for npc in get_parent().get_node("NPCs").get_children():
			query.transform = Transform2D(0.0, npc.global_position)
			if not space.intersect_shape(query, 1).is_empty():
				var cell := _free_cell(npc.global_position)
				if cell.x >= 0:
					npc.global_position = to_global(grid.get_point_position(cell))
					npc.reset_physics_interpolation()


func refresh() -> void:
	var transforms: Array[Transform2D] = []
	var excluded: Array[RID] = []
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is CollisionObject2D:
			excluded.append(player.get_rid())
	query.exclude = excluded
	var space := get_world_2d().direct_space_state
	if not initialized:
		var static_excluded := excluded.duplicate()
		for object in moving_objects:
			if not is_instance_valid(object):
				continue
			static_excluded.append(object.get_rid())
			var visual := object.get_node_or_null("Sprite2D/NPCObstacle") as CollisionObject2D
			if visual != null:
				static_excluded.append(visual.get_rid())
		query.exclude = static_excluded
		for y in range(grid.region.size.y):
			for x in range(grid.region.size.x):
				var cell := Vector2i(x, y)
				if _blocked(space, cell):
					static_cells[cell] = true
					grid.set_point_solid(cell)
		query.exclude = excluded
	for object in moving_objects:
		if is_instance_valid(object) and not object.is_queued_for_deletion():
			transforms.append(object.global_transform)
	if initialized and transforms == previous_transforms:
		return
	initialized = true
	previous_transforms = transforms
	for cell: Vector2i in dynamic_cells:
		grid.set_point_solid(cell, static_cells.has(cell))
	dynamic_cells.clear()
	for object in moving_objects:
		if not is_instance_valid(object) or object.is_queued_for_deletion():
			continue
		var sprite := object.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			continue
		var area := sprite_bounds(sprite).grow(16.0)
		var first := _cell(area.position)
		var last := _cell(area.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not static_cells.has(cell) and _blocked(space, cell):
					dynamic_cells[cell] = true
					grid.set_point_solid(cell)
	revision += 1


func _blocked(space: PhysicsDirectSpaceState2D, cell: Vector2i) -> bool:
	query.motion = Vector2.ZERO
	query.transform = Transform2D(0.0, to_global(grid.get_point_position(cell)))
	return not space.intersect_shape(query, 1).is_empty()


func sprite_bounds(sprite: Sprite2D) -> Rect2:
	var rect := sprite.get_rect()
	var result := Rect2(sprite.to_global(rect.position), Vector2.ZERO)
	for corner in [Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		result = result.expand(sprite.to_global(corner))
	return result


func _cell(point: Vector2) -> Vector2i:
	var cell := Vector2i(((to_local(point) - grid.offset) / cell_size).round())
	return cell.clamp(Vector2i.ZERO, grid.region.end - Vector2i.ONE)


func _free_cell(point: Vector2, component: int = -1) -> Vector2i:
	var cell := _cell(point)
	if not grid.is_point_solid(cell) and (component < 0 or components.get(cell, -1) == component):
		return cell
	var best := Vector2i(-1, -1)
	var distance := INF
	for radius in range(1, 9):
		for y in range(cell.y - radius, cell.y + radius + 1):
			for x in range(cell.x - radius, cell.x + radius + 1):
				var candidate := Vector2i(x, y)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
					continue
				if component >= 0 and components.get(candidate, -1) != component:
					continue
				var score := to_global(grid.get_point_position(candidate)).distance_squared_to(point)
				if score < distance:
					distance = score
					best = candidate
		if best.x >= 0:
			return best
	return best


func _update_components() -> void:
	if components_revision == revision:
		return
	components_revision = revision
	components.clear()
	var component := 0
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell := Vector2i(x, y)
			if grid.is_point_solid(cell) or components.has(cell):
				continue
			var pending: Array[Vector2i] = [cell]
			components[cell] = component
			var head := 0
			while head < pending.size():
				var current := pending[head]
				head += 1
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor := current + direction
					if grid.is_in_boundsv(neighbor) and not grid.is_point_solid(neighbor) and not components.has(neighbor):
						components[neighbor] = component
						pending.append(neighbor)
			component += 1


func find_route(from: Vector2, target: Vector2) -> PackedVector2Array:
	if not initialized:
		return PackedVector2Array()
	_update_components()
	var start := _free_cell(from)
	if start.x < 0:
		return PackedVector2Array()
	var goal := _free_cell(target, int(components.get(start, -1)))
	if goal.x < 0:
		return PackedVector2Array()
	var points := grid.get_point_path(start, goal)
	var result := PackedVector2Array()
	if points.is_empty():
		return result
	var space := get_world_2d().direct_space_state
	var anchor := 0
	result.append(to_global(points[0]))
	while anchor < points.size() - 1:
		var next := anchor + 1
		query.transform = Transform2D(0.0, to_global(points[anchor]))
		for candidate in range(next + 1, points.size()):
			query.motion = to_global(points[candidate]) - query.transform.origin
			if space.cast_motion(query)[0] < 1.0:
				break
			next = candidate
		result.append(to_global(points[next]))
		anchor = next
	query.motion = Vector2.ZERO
	return result
