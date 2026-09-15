extends StaticBody2D

# 1. Casillero para la mega-imagen del supermercado
@export var textura_mueble: Texture2D

# 2. Casilleros para recortar qué mueble queremos mostrar
# (Usamos Rect2 porque es el tipo de variable que pide Godot para las 'Region')
@export var region_de_corte: Rect2

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Si le pasamos una imagen...
	if textura_mueble != null:
		sprite.texture = textura_mueble
		
	# Si le pasamos coordenadas de corte...
	if region_de_corte != Rect2(0, 0, 0, 0):
		sprite.region_enabled = true
		sprite.region_rect = region_de_corte
