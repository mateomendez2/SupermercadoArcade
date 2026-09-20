extends StaticBody2D

# Creamos una lista (Array) en el Inspector para guardar todas las variantes de Nati
@export var variantes_de_caja: Array[Texture2D]

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Verificamos que la lista no esté vacía por seguridad
	if variantes_de_caja.size() > 0:
		# Elegimos una textura al azar de la lista
		var textura_elegida = variantes_de_caja.pick_random()
		
		# Se la aplicamos al dibujo de la caja
		if textura_elegida != null:
			sprite.texture = textura_elegida
