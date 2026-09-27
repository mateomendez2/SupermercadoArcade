extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
var mi_caja: Node2D = null
var jugador: Node2D = null

# Configuración del flotar
var tiempo: float = 0.0
@export var altura_flote: float = 10.0
@export var velocidad_flote: float = 5.0

func _ready() -> void:
	top_level = true 
	mi_caja = get_parent() 
	
	GameManager.lista_lista_para_pagar.connect(_encender_flecha)
	GameManager.lista_incompleta.connect(hide)
	
	# La forzamos a nacer apagada SIEMPRE. Sin hacer preguntas.
	hide()

# --- ¡ESTA ERA LA FUNCIÓN QUE SE HABÍA BORRADO! ---
func _encender_flecha() -> void:
	# Blindamos la búsqueda del jugador
	jugador = get_tree().get_first_node_in_group("Player")
	
	if jugador != null:
		show()
		print("🎯 Flecha Encendida. Jugador encontrado en: ", jugador.global_position)
	else:
		print("❌ ERROR DE FLECHA: No encontré al Jugador (El grupo 'Player' falló)")

func _process(delta: float) -> void:
	if not visible or jugador == null: return
	
	var camara = get_viewport().get_camera_2d()
	if camara == null: return
	
	# Usamos un margen seguro estándar
	var margen = Vector2(250, 180) 
	var dist_a_caja = camara.global_position.distance_to(mi_caja.global_position)
	
	# En lugar de usar matemáticas complejas de rectángulos, 
	# usamos una distancia simple para saber si está en pantalla
	if dist_a_caja < 300.0: # Si la caja está cerca de la cámara
		
		# Animación Flotante
		tiempo += delta
		var offset_flote = sin(tiempo * velocidad_flote) * altura_flote
		global_position = mi_caja.global_position + Vector2(0, -50 + offset_flote)
		rotation_degrees = 90
		
	else:
		# ¡Está lejos! Órbita alrededor del jugador
		var direccion = jugador.global_position.direction_to(mi_caja.global_position)
		rotation = direccion.angle()
		
		# Forzamos la posición relativa al jugador
		global_position = jugador.global_position + (direccion * 80.0)
