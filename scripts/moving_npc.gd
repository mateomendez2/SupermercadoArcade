extends Node2D

@export var tiempo_caminando: float = 2.0 # Segundos que tarda en ir de un punto a otro
@export var tiempo_espera: float = 1.0 # Segundos que se queda quieto en los extremos

@onready var hitbox: Area2D = $Hitbox
@onready var punto_final: Marker2D = $PuntoFinal

# Guardamos dónde empieza
@onready var posicion_inicial: Vector2 = hitbox.position

func _ready() -> void:
	iniciar_patrullaje()

func iniciar_patrullaje() -> void:
	# Creamos una animación por código que se repita infinitamente
	var patrulla_tween = create_tween().set_loops()
	
	# 1. Caminar hacia el Punto Final
	patrulla_tween.tween_property(hitbox, "position", punto_final.position, tiempo_caminando)
	
	# 2. Esperar
	patrulla_tween.tween_interval(tiempo_espera)
	
	# 3. Volver a la Posición Inicial
	patrulla_tween.tween_property(hitbox, "position", posicion_inicial, tiempo_caminando)
	
	# 4. Esperar antes de volver a arrancar
	patrulla_tween.tween_interval(tiempo_espera)
