extends Area2D

# Exponemos dos variables vacías para que arrastres las imágenes de Natasha en el Inspector
@export var tex_agua: Texture2D
@export var tex_gaseosa: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Conectamos las señales físicas
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# La Magia Aleatoria: 
	# Armamos una lista con las dos texturas
	var posibles_artes = [tex_agua, tex_gaseosa]
	
	# pick_random() es una función nativa de Godot 4 que elige uno al azar
	var arte_elegido = posibles_artes.pick_random()
	
	# Si cargaste imágenes en el inspector, se la aplicamos al Sprite
	if arte_elegido != null:
		sprite.texture = arte_elegido

# Cuando alguien pisa el charco...
func _on_body_entered(body: Node2D) -> void:
	# Preguntamos si el que pisó es de la clase Player
	if body is Player:
		body.set_slippery(true)

# Cuando alguien sale del charco...
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		body.set_slippery(false)
