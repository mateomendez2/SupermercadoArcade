extends Node2D
## BOLSA DEL BOTÍN QUE TE GUÍA A LA SALIDA (modo 2 jugadores)
## Cada jugador tiene la suya y la ve solo en su mitad de la pantalla.
## Si la salida no se ve, la bolsa se queda en el borde de la pantalla y "empuja" hacia ella;
## si se ve, flota arriba de la zona. Cuando el jugador llega cerca (o ya está adentro), se esconde.
## La arma salida_coop.gd (no hace falta ponerla a mano).

const ICONO: Texture2D = preload("res://assets/ui/bolsa_botin.png")

# --- AJUSTES (iguales a los de la billetera de la caja) ---
var distancia_cerca: float = 70.0 # Más cerca que esto (y con la salida a la vista), la bolsa se esconde
var distancia_vaiven: float = 2.5 # El vaivén hacia la salida, para que llame la atención
var velocidad_flote: float = 8.0
# Lo que tapan arriba la franja negra y el ticket de la lista (en pixeles de la pantalla: 26 + 48 del ticket + aire)
var alto_tapado: float = 80.0
const RADIO: float = 10.0          # Medio tamaño de la bolsa (para que no se corte en los bordes)

var jugador: Node2D
var camara: Camera2D
var salida: Node2D # La zona de salida (salida_coop.gd)
var sprite: Sprite2D
var tiempo: float = 0.0

# capa: la capa de dibujo que solo se ve en la mitad de ese jugador
func preparar(quien: Node2D, su_camara: Camera2D, la_salida: Node2D, capa: int) -> void:
	jugador = quien
	camara = su_camara
	salida = la_salida
	top_level = true
	z_index = 50 # Por encima de todo (góndolas, paredes, personajes)
	visibility_layer = capa
	sprite = Sprite2D.new()
	sprite.texture = ICONO
	sprite.visibility_layer = capa
	add_child(sprite)
	hide()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(jugador) or camara == null: return
	var zona: Rect2 = salida.rect_global()
	var pantalla: Rect2 = _lo_que_se_ve()
	# Lo de arriba lo tapan la franja y el ticket: la bolsa nunca va ahí (y la salida ahí abajo "no se ve")
	var tapado: float = alto_tapado / camara.zoom.y
	pantalla.position.y += tapado
	pantalla.size.y -= tapado
	var cerca: bool = pantalla.intersects(zona) and jugador.global_position.distance_to(zona.get_center()) < distancia_cerca
	if cerca or salida.esta_adentro(jugador):
		sprite.hide()
		return
	sprite.show()

	# Lugar permitido para el centro de la bolsa: adentro de la pantalla y abajo de la franja
	var borde: float = RADIO + distancia_vaiven + 1.0
	pantalla.position.x += borde
	pantalla.size.x -= borde * 2.0
	pantalla.position.y += borde
	pantalla.size.y -= borde * 2.0
	# Va justo arriba de la zona; si eso no se ve, queda en el borde, en la línea que va del jugador a la salida
	var objetivo := Vector2(zona.get_center().x, zona.position.y - RADIO - 4.0)
	var desde: Vector2 = jugador.global_position.clamp(pantalla.position, pantalla.end)
	var posicion: Vector2 = _punto_hasta_el_borde(desde, objetivo, pantalla)
	# Vaivén hacia la salida
	tiempo += delta
	posicion += posicion.direction_to(zona.get_center()) * sin(tiempo * velocidad_flote) * distancia_vaiven
	global_position = posicion.round() # Pixeles enteros: así no se ve borroso

# El rectángulo del mundo que se ve en la mitad de este jugador
func _lo_que_se_ve() -> Rect2:
	var tam: Vector2 = camara.get_viewport().get_visible_rect().size / camara.zoom
	return Rect2(camara.get_screen_center_position() - tam / 2.0, tam)

# El punto de la línea "desde -> hasta" que queda dentro del rectángulo
func _punto_hasta_el_borde(desde: Vector2, hasta: Vector2, rect: Rect2) -> Vector2:
	var recorrido: Vector2 = hasta - desde
	var t: float = 1.0
	if recorrido.x > 0.0: t = minf(t, (rect.end.x - desde.x) / recorrido.x)
	elif recorrido.x < 0.0: t = minf(t, (rect.position.x - desde.x) / recorrido.x)
	if recorrido.y > 0.0: t = minf(t, (rect.end.y - desde.y) / recorrido.y)
	elif recorrido.y < 0.0: t = minf(t, (rect.position.y - desde.y) / recorrido.y)
	return desde + recorrido * maxf(t, 0.0)
