extends Camera2D


func _ready() -> void:
	GlobalLevelManager.TileMapBoundsChanged.connect(UpdateLimits)
	UpdateLimits(GlobalLevelManager.current_tilemap_bounds)
	pass


func UpdateLimits( bounds : Array[Vector2]) -> void:
	
	limit_left = int(bounds[0].x)
	limit_top = int(bounds[0].y)
	limit_right = int(bounds[1].x)
	limit_bottom = int(bounds[1].y)
	
