extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
# NUEVO: La referencia al cuadrado amarillo que acabamos de hacer
@onready var zona_visual: ColorRect = %ZonaVisual

var mi_caja: Node2D = null
var jugador: Node2D = null

var tiempo: float = 0.0
@export var altura_flote: float = 10.0
@export var velocidad_flote: float = 5.0

func _ready() -> void:
	top_level = true 
	mi_caja = get_parent() 
	
	GameManager.lista_lista_para_pagar.connect(_encender_flecha)
	# NUEVO: Cambiamos "hide" por nuestra propia función para apagar todo
	GameManager.lista_incompleta.connect(_apagar_todo)
	
	# Chequeo inmediato al nacer
	if GameManager.collected_items.size() != GameManager.target_list.size():
		_apagar_todo()

func _encender_flecha() -> void:
	jugador = get_tree().get_first_node_in_group("Player")
	if jugador != null:
		show()
		# OJO: Acá no prendemos la zona, de eso se encarga el _process si está cerca

func _apagar_todo() -> void:
	hide() # Esconde la flecha
	if zona_visual: zona_visual.hide() # Esconde el piso amarillo

func _process(delta: float) -> void:
	if not visible or jugador == null: return
	
	var camara = get_viewport().get_camera_2d()
	if camara == null: return
	
	var centro_camara = camara.global_position
	var margen = Vector2(180, 120) 
	
	var en_pantalla = (
		mi_caja.global_position.x > centro_camara.x - margen.x and
		mi_caja.global_position.x < centro_camara.x + margen.x and
		mi_caja.global_position.y > centro_camara.y - margen.y and
		mi_caja.global_position.y < centro_camara.y + margen.y
	)
	
	if en_pantalla:
		# ¡MI CAJA está a la vista!
		tiempo += delta
		var offset_flote = sin(tiempo * velocidad_flote) * altura_flote
		global_position = mi_caja.global_position + Vector2(0, -50 + offset_flote)
		rotation_degrees = 90 
		
		# ¡NUEVA LÍNEA! Encendemos la alfombra amarilla
		if zona_visual: zona_visual.show()
		
	else:
		# ¡MI CAJA está lejos!
		var direccion = jugador.global_position.direction_to(mi_caja.global_position)
		rotation = direccion.angle()
		global_position = jugador.global_position + (direccion * 65.0)
		
		# ¡NUEVA LÍNEA! Apagamos la alfombra amarilla para que no se vea a lo lejos
		if zona_visual: zona_visual.hide()
