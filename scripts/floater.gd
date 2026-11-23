extends Label

var life := 0.45
var vel := Vector2(0, -48)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30


func _process(delta: float) -> void:
	life -= delta
	position += vel * delta
	modulate.a = clampf(life / 0.45, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
