extends Sprite2D
## Scales this sprite so its texture always fully covers the camera's view,
## at any window size or camera zoom. Attach to a Sprite2D that is a child of
## the Camera2D, positioned at (0, 0).

func _ready() -> void:
	_fit()
	get_viewport().size_changed.connect(_fit)


func _fit() -> void:
	if texture == null:
		return
	var view: Vector2 = get_viewport_rect().size
	var cam := get_parent() as Camera2D
	if cam:
		view /= cam.zoom  # world-space size the camera actually shows
	var tex: Vector2 = texture.get_size()
	# Scale by the larger ratio so both axes are covered, plus a hair of margin.
	var s: float = max(view.x / tex.x, view.y / tex.y) * 1.02
	scale = Vector2(s, s)
