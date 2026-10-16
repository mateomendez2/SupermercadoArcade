extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
# NUEVO: La referencia al cuadrado amarillo que acabamos de hacer
@onready var zona_visual: ColorRect = %ZonaVisual
@onready var detector: VisibleOnScreenNotifier2D = %DetectorPantalla

var mi_caja: Node2D = null
var jugador: Node2D = null

var tiempo: float = 0.0
var tween_zona: Tween

# --- AJUSTES DEL INDICADOR (se pueden cambiar desde el Inspector) ---
# Si el jugador está más cerca que esto de la zona, se apaga la flecha y titila el piso.
# Subilo para que el piso se prenda antes; bajalo para que la flecha dure más.
@export var distancia_cerca: float = 70.0
# Cuánto se separa la flecha de los bordes de la pantalla (en píxeles del mundo)
@export var margen_borde: float = 14.0
# Cuando la zona se ve en pantalla, la flecha se queda a esta distancia de ella apuntándola
@export var separacion_zona: float = 26.0
# El "vaivén" de la flecha hacia adelante y atrás para que llame la atención
@export var distancia_vaiven: float = 4.0
@export var velocidad_flote: float = 8.0
# Lo que tapa la franja de arriba (en pixeles del mundo)
@export var alto_franja: float = 14.0
@export var color_flecha_a: Color = Color(0.35, 1.0, 0.45)
@export var color_flecha_b: Color = Color(0.85, 1.0, 0.85)

func _ready() -> void:
	top_level = true
	mi_caja = get_parent()
	z_index = 50 # La flecha siempre se dibuja por encima de todo (góndolas, paredes, NPCs)

	GameManager.lista_lista_para_pagar.connect(_encender_flecha)
	# NUEVO: Cambiamos "hide" por nuestra propia función para apagar todo
	GameManager.lista_incompleta.connect(_apagar_todo)

	# Chequeo inmediato al nacer
	if GameManager.collected_items.size() != GameManager.target_list.size():
		_apagar_todo()
	# La flecha titila entre los dos verdes para siempre
	sprite.modulate = color_flecha_a
	var tween_color = create_tween().set_loops()
	tween_color.tween_property(sprite, "modulate", color_flecha_b, 0.25)
	tween_color.tween_property(sprite, "modulate", color_flecha_a, 0.25)

func _encender_flecha() -> void:
	jugador = get_tree().get_first_node_in_group("Player")
	if jugador != null:
		show()
		# OJO: Acá no prendemos la zona, de eso se encarga el _process si está cerca

func _apagar_todo() -> void:
	hide() # Esconde la flecha
	_apagar_zona()

func _process(delta: float) -> void:
	if not visible or jugador == null: return

	var destino: Vector2 = zona_visual.get_global_rect().get_center()
	var distancia: float = jugador.global_position.distance_to(destino)

	# NUEVO: Ya no alcanza con que la zona se VEA. El jugador también tiene que estar CERCA.
	# Así, en niveles chicos como el Tutorial (donde la caja se ve desde el principio),
	# primero aparece la flecha y recién al acercarse cambia al piso que titila.
	var esta_cerca: bool = detector.is_on_screen() and distancia < distancia_cerca

	if esta_cerca:
		# ¡Llegó! Escondemos la flecha y prendemos el piso
		sprite.hide()
		_encender_zona()
	else:
		# Todavía lejos: mostramos la flecha y apagamos el piso
		sprite.show()
		_apagar_zona()
		_ubicar_flecha(destino, delta)

# --- INDICADOR EN EL BORDE DE LA PANTALLA ---
func _ubicar_flecha(destino: Vector2, delta: float) -> void:
	var camara: Camera2D = get_viewport().get_camera_2d()
	if camara == null: return

	# 1. Calculamos el rectángulo que REALMENTE se ve en pantalla (en coordenadas del mundo).
	#    get_screen_center_position() ya tiene en cuenta los límites de la cámara,
	#    y dividir por el zoom nos da el tamaño real (con zoom x2, se ve la mitad).
	var tam_visible: Vector2 = get_viewport_rect().size / camara.zoom
	var pantalla := Rect2(camara.get_screen_center_position() - tam_visible / 2.0, tam_visible)
	pantalla = pantalla.grow(-margen_borde) # Lo achicamos un poco para que la flecha no quede cortada
	# NUEVO: Arriba está la franja negra, así que la flecha no puede subir hasta ahí
	pantalla.position.y += alto_franja
	pantalla.size.y -= alto_franja

	# 2. ¿Hacia dónde queremos llevar la flecha? A un punto justo ANTES de la zona,
	#    así cuando la zona se ve, la flecha queda al lado apuntándola (y no encima)
	var direccion: Vector2 = jugador.global_position.direction_to(destino)
	var objetivo: Vector2 = destino - direccion * separacion_zona

	# 3. Trazamos una línea desde el jugador hasta ese punto.
	#    Si el punto está dentro de la pantalla, la flecha va ahí.
	#    Si está afuera, la flecha se queda donde la línea toca el borde.
	var desde: Vector2 = jugador.global_position.clamp(pantalla.position, pantalla.end)
	var posicion: Vector2 = _punto_hasta_el_borde(desde, objetivo, pantalla)

	# 4. Vaivén: la flecha "empuja" hacia la zona una y otra vez
	tiempo += delta
	var apunta: Vector2 = posicion.direction_to(destino)
	posicion += apunta * sin(tiempo * velocidad_flote) * distancia_vaiven

	global_position = posicion
	rotation = apunta.angle()

# Devuelve el punto de la línea "desde -> hasta" que queda dentro del rectángulo.
# Si "hasta" ya está adentro, devuelve "hasta". Si no, el punto donde la línea cruza el borde.
func _punto_hasta_el_borde(desde: Vector2, hasta: Vector2, rect: Rect2) -> Vector2:
	var recorrido: Vector2 = hasta - desde
	var t: float = 1.0 # 1.0 = llegar hasta el final de la línea

	if recorrido.x > 0.0:
		t = minf(t, (rect.end.x - desde.x) / recorrido.x)
	elif recorrido.x < 0.0:
		t = minf(t, (rect.position.x - desde.x) / recorrido.x)

	if recorrido.y > 0.0:
		t = minf(t, (rect.end.y - desde.y) / recorrido.y)
	elif recorrido.y < 0.0:
		t = minf(t, (rect.position.y - desde.y) / recorrido.y)

	return desde + recorrido * maxf(t, 0.0)

func _encender_zona() -> void:
	# Si ya está titilando, no hacemos nada (evita crear 60 animaciones por segundo)
	if tween_zona and tween_zona.is_valid():
		return

	zona_visual.show()
	tween_zona = create_tween().set_loops()
	tween_zona.tween_property(zona_visual, "modulate:a", 0.3, 0.5) # se apaga
	tween_zona.tween_property(zona_visual, "modulate:a", 1.0, 0.5) # se prende

func _apagar_zona() -> void:
	if tween_zona:
		tween_zona.kill() # frenamos el titileo
	zona_visual.hide()
