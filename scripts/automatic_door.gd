extends Area2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Nos conectamos a nuestro propio sensor
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# Cuando el jugador entra al área del sensor...
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# Reproducimos la animación normalmente (se abre)
		anim_sprite.play("open")

# Cuando el jugador sale del área del sensor...
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		# ¡TU IDEA BRILLANTE! Reproducimos la misma animación, pero en reversa (se cierra)
		anim_sprite.play_backwards("open")
