extends Area2D

var player_in_range: bool = false

func _ready() -> void:
	# Nos avisa cuando el jugador está frente a la caja
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		print("Presiona E para pagar.")

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false

func _unhandled_input(event: InputEvent) -> void:
	# Si el jugador aprieta "E" y está frente al mostrador...
	if player_in_range and event.is_action_pressed("interact"):
		# Le decimos al GameManager que evalúe la lista
		GameManager.intentar_pagar()
