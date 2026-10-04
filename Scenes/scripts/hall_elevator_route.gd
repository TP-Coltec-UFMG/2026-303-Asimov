extends Node2D

@export var bounds := Rect2(-66.0, -114.0, 84.0, 96.0)
@export var cell_size := 4.0

var grid := AStarGrid2D.new()
var query := PhysicsShapeQueryParameters2D.new()
var obstacle_transforms: Array[Transform2D] = []
var cached_route := PackedVector2Array()
var initialized := false


func _ready() -> void:
	var shape := CapsuleShape2D.new()
	shape.radius = 7.0
	shape.height = 22.0
	query.shape = shape
	query.collision_mask = 33
	query.margin = 2.0
	grid.region = Rect2i(Vector2i.ZERO, Vector2i(ceil(bounds.size.x / cell_size) + 1, ceil(bounds.size.y / cell_size) + 1))
	grid.cell_size = Vector2.ONE * cell_size
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()


func get_clear_route() -> PackedVector2Array:
	var transforms: Array[Transform2D] = []
	for object in get_parent().get_node("Coletaveis").get_children():
		if object is ObjetoEmpurravel and not object.is_queued_for_deletion():
			transforms.append(object.global_transform)
	if initialized and transforms == obstacle_transforms:
		return cached_route
	initialized = true
	obstacle_transforms = transforms
	var excluded: Array[RID] = []
	for player in get_tree().get_nodes_in_group(&"player"):
		if player is CollisionObject2D:
			excluded.append(player.get_rid())
	query.exclude = excluded
	query.motion = Vector2.ZERO
	var space := get_world_2d().direct_space_state
	for y in range(grid.region.size.y):
		for x in range(grid.region.size.x):
			var cell := Vector2i(x, y)
			query.transform = Transform2D(0.0, to_global(grid.get_point_position(cell)))
			grid.set_point_solid(cell, not space.intersect_shape(query, 1).is_empty())
	var entrance := _cell($Entrance.position)
	var exit := _cell($Exit.position)
	cached_route = PackedVector2Array()
	if grid.is_point_solid(entrance) or grid.is_point_solid(exit):
		return cached_route
	var points := grid.get_point_path(entrance, exit)
	if points.is_empty():
		return cached_route
	var anchor := 0
	cached_route.append(to_global(points[anchor]))
	while anchor < points.size() - 1:
		var next := anchor + 1
		query.transform = Transform2D(0.0, to_global(points[anchor]))
		query.motion = to_global(points[next]) - query.transform.origin
		if space.cast_motion(query)[0] < 1.0:
			cached_route.clear()
			return cached_route
		for candidate in range(next + 1, points.size()):
			query.motion = to_global(points[candidate]) - query.transform.origin
			if space.cast_motion(query)[0] < 1.0:
				break
			next = candidate
		cached_route.append(to_global(points[next]))
		anchor = next
	query.motion = Vector2.ZERO
	return cached_route


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(((point - grid.offset) / cell_size).round())


func prepare_exit_path(npc: Node2D, path: NPCPath, route: PackedVector2Array) -> void:
	if route.is_empty():
		return
	var points: Array[Vector2] = []
	for point in route:
		points.append(point)
	npc.cached_path_points[path] = points
