extends Node2D

## INDICADOR "ANDÁ A PAGAR"
## Cuando completás la lista aparece un globito con una billetera que apunta a la caja.
## Se para arriba de la zona donde hay que pagar. Si la caja está fuera de la pantalla,
## el globito se queda en el borde (sin taparse con la franja de arriba) y "empuja" hacia ella.
## Si hay dos cajas en el nivel, solo se muestra el de la caja más cercana.
@onready var sprite: Sprite2D = $Sprite2D          # El globito con el piquito (no gira)
@onready var billetera: Sprite2D = $Billetera       # La billetera (siempre derecha)
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
@export var separacion_zona: float = 30.0 # (ya no se usa: el globito va arriba de la zona)
# Radio del globito (para que no se corte en los bordes ni pase por debajo de la franja)
const RADIO_GLOBO: float = 14.0
# En el borde de la pantalla el globito va SIN piquito (si no, parece que te apunta a vos)
const GLOBO_BORDE: Texture2D = preload("res://assets/ui/globo_pagar_borde.png")
var globo_con_piquito: Texture2D
# El "vaivén" de la flecha hacia adelante y atrás para que llame la atención
@export var distancia_vaiven: float = 2.5
@export var velocidad_flote: float = 8.0
# Lo que tapa la franja de arriba (en pixeles del mundo)
@export var alto_franja: float = 14.0
@export var color_flecha_a: Color = Color(0.35, 1.0, 0.45)
@export var color_flecha_b: Color = Color(0.85, 1.0, 0.85)

func _ready() -> void:
	top_level = true
	mi_caja = get_parent()
	z_index = 50 # La flecha siempre se dibuja por encima de todo (góndolas, paredes, NPCs)

	globo_con_piquito = sprite.texture
	GameManager.lista_lista_para_pagar.connect(_encender_flecha)
	# NUEVO: Cambiamos "hide" por nuestra propia función para apagar todo
	GameManager.lista_incompleta.connect(_apagar_todo)
	GameManager.game_won.connect(_apagar_todo) # Ya pagó: apagamos todo

	# Chequeo inmediato al nacer
	if GameManager.collected_items.size() != GameManager.target_list.size():
		_apagar_todo()

func _encender_flecha() -> void:
	jugador = get_tree().get_first_node_in_group("Player")
	if jugador != null:
		show()
		_encender_zona() # La zona de pagar aparece de entrada, junto con el "¡POR ACÁ!"

func _apagar_todo() -> void:
	hide() # Esconde la flecha
	_apagar_zona()

func _process(delta: float) -> void:
	if not visible or jugador == null: return

	var destino: Vector2 = zona_visual.get_global_rect().get_center()

	# Si hay otra caja más cerca del jugador, este globito no se muestra (se muestra el de esa)
	if not _soy_la_caja_mas_cercana():
		sprite.hide(); billetera.hide()
		return
	var distancia: float = jugador.global_position.distance_to(destino)

	# NUEVO: Ya no alcanza con que la zona se VEA. El jugador también tiene que estar CERCA.
	# Así, en niveles chicos como el Tutorial (donde la caja se ve desde el principio),
	# primero aparece la flecha y recién al acercarse cambia al piso que titila.
	var esta_cerca: bool = detector.is_on_screen() and distancia < distancia_cerca

	if esta_cerca:
		# ¡Llegó! Escondemos el globito (la zona ya está prendida desde que completó la lista)
		sprite.hide(); billetera.hide()
	else:
		# Todavía lejos: mostramos el globito
		sprite.show(); billetera.show()
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
	# 2. El lugar donde puede estar el CENTRO del globito: todo el globito tiene que quedar
	#    adentro de la pantalla y por DEBAJO de la franja negra (con el rebote incluido)
	var borde: float = RADIO_GLOBO + distancia_vaiven + 1.0
	pantalla.position.x += borde
	pantalla.size.x -= borde * 2.0
	pantalla.position.y += alto_franja + borde
	pantalla.size.y -= alto_franja + borde * 2.0 + 6.0 # abajo dejamos lugar para el piquito

	# 3. ¿A dónde va? Justo arriba de la zona de pagar, con el piquito apuntándola
	var zona: Rect2 = zona_visual.get_global_rect()
	var objetivo: Vector2 = Vector2(zona.get_center().x, zona.position.y - RADIO_GLOBO - 6.0)

	# 4. Trazamos una línea desde el jugador hasta ese punto.
	#    Si el punto está dentro de la pantalla, el globito va ahí.
	#    Si está afuera, se queda donde la línea toca el borde.
	var desde: Vector2 = jugador.global_position.clamp(pantalla.position, pantalla.end)
	var posicion: Vector2 = _punto_hasta_el_borde(desde, objetivo, pantalla)
	# Piquito solo cuando el globito llegó arriba de la zona (no cuando está trabado en el borde)
	sprite.texture = globo_con_piquito if posicion.distance_to(objetivo) < 1.0 else GLOBO_BORDE

	# 5. Rebote: el globito "empuja" suavecito hacia la caja (sin salirse del lugar permitido)
	tiempo += delta
	var apunta: Vector2 = posicion.direction_to(destino)
	posicion += apunta * sin(tiempo * velocidad_flote) * distancia_vaiven
	posicion = posicion.clamp(pantalla.position - Vector2.ONE * distancia_vaiven, pantalla.end + Vector2.ONE * distancia_vaiven)
	posicion = posicion.round() # Pixeles enteros: así no se ve borroso

	global_position = posicion

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

	zona_visual.modulate.a = 1.0
	zona_visual.show() # Ya no titila: lo que llama la atención es el borde que gira (zona_borde.gd)

func _apagar_zona() -> void:
	if tween_zona:
		tween_zona.kill() # frenamos el titileo
	zona_visual.hide()

# ¿Esta es la caja más cercana al jugador? (para no mostrar dos globitos a la vez)
func _soy_la_caja_mas_cercana() -> bool:
	var mi_distancia: float = jugador.global_position.distance_to(zona_visual.get_global_rect().get_center())
	for caja in get_tree().get_nodes_in_group("CheckoutDesk"):
		if caja == mi_caja or not caja.has_node("%ZonaVisual"): continue
		var otra_zona: Control = caja.get_node("%ZonaVisual")
		if jugador.global_position.distance_to(otra_zona.get_global_rect().get_center()) < mi_distancia:
			return false
	return true
