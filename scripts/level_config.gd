extends Node2D

# En lugar de un número, exportamos una lista específica de objetos
@export var frutas_del_nivel: Array[ItemData]
@export var tiempo_del_nivel: float = 90.0

func _ready() -> void:
	# Le pasamos la lista exacta al GameManager
	GameManager.iniciar_nivel(frutas_del_nivel, tiempo_del_nivel)
