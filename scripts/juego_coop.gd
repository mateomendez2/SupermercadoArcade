extends Control
## MODO COOPERATIVO (en armado): PANTALLA DIVIDIDA con dos jugadores
## La pantalla se parte al medio: a la izquierda el jugador 1 y a la derecha el jugador 2.
## Las dos mitades muestran el MISMO nivel (el mismo "mundo"), cada una con su cámara.
##
## Está en el nodo "PantallaDividida" de juego_coop.tscn, que hereda de juego.tscn:
## la interfaz (franja de arriba, cartel "NIVEL X", ticket, reloj, resultados, música)
## es la misma del modo de un jugador, una sola para toda la pantalla.
## El que elige y carga el nivel es gestor_interfaz.gd, y lo pone acá con poner_nivel().
##
## Controles (se arman acá mismo, no hace falta tocar el Mapa de Entrada del proyecto):
##   Jugador 1: su mando (o WASD) + sus botones (o C / V / B)
##   Jugador 2: su mando (o flechas) + sus botones (o J / K / L)
##   (qué mando le toca a cada uno: ver controles_coop.gd)
##
## Arriba, contra el borde de cada mitad (a la altura de la lista), van los carteles "J1" y "J2"
## para que cada uno sepa cuál es su lado.

@export var zoom_camara: float = 2.0 # 2 = igual que en el modo de un jugador
# Lo que tapa la interfaz arriba de cada mitad, en pixeles de pantalla (franja 26 + carteles y ticket).
# Subilo si querés al personaje más abajo; bajalo para más arriba.
@export var tapado_arriba: float = 52.0
const MEDIO_DEL_DIBUJO: float = 9.0 # El medio del dibujo del personaje está 9 pixeles arriba de sus pies
@export var distancia_fila: float = 30.0 # Al entrar, el jugador 2 viene atrás del 1 (en fila), a esta distancia
# --- CARTELES "J1" / "J2" (los mismos de la pantalla de elegir ladrón) ---
@export var margen_carteles: float = 8.0 # Separación con el borde de la pantalla
@export var altura_carteles: float = 40.0 # Altura (arriba del cartel); 40 = a la mitad del ticket de la lista
const CARTEL_J1: Texture2D = preload("res://assets/ui/modo/j1.png")
const CARTEL_J2: Texture2D = preload("res://assets/ui/modo/j2.png")
# Cómo se ve cada ladrón: lo eligen en la pantalla de personajes (GameManager.personajes_coop).
# Si se abre esta escena directo (sin pasar por ahí), se usan estos dos:
@export var animaciones_jugador_1: SpriteFrames = preload("res://assets/ladrones/ladrona.tres") # Ella, pañuelo rojo
@export var animaciones_jugador_2: SpriteFrames = preload("res://assets/ladrones/ladron.tres")  # Él, pañuelo azul

const ESCENA_JUGADOR: String = "res://scenes/characters/jugador.tscn"
const SalidaCoop = preload("res://scripts/salida_coop.gd")
const Guardia = preload("res://scripts/guardia.gd")
# Caritas de cómo está cada uno con el guardia (al lado de J1 y J2)
const ICONOS_GUARDIA: Dictionary = {
	"tranquilo": preload("res://assets/ui/guardia/tranquilo.png"), # Carita verde contenta: no te vio
	"buscando": preload("res://assets/ui/guardia/buscando.png"),   # Carita naranja preocupada: te perdió y te está buscando
	"visto": preload("res://assets/ui/guardia/visto.png"),         # Carita roja enojada: te vio (o te agarró)
}
@export var hay_guardia: bool = true # false = el nivel se juega sin guardia
var iconos_guardia: Dictionary = {} # "p1_" / "p2_" -> su ícono
# Dónde va la salida si el nivel no tiene una: enfrente de la puerta, donde quedan parados al entrar
@export var salida_desde_la_puerta: Vector2 = Vector2(0, 41)
# Capas de dibujo que se ven en una sola mitad (para las bolsas que guían a la salida)
const CAPA_SOLO_J1: int = 1 << 1
const CAPA_SOLO_J2: int = 1 << 2
const ANCHO_DIVISION: int = 2 # La rayita negra entre las dos mitades

var vista_1: SubViewport
var vista_2: SubViewport
var camara_1: Camera2D
var camara_2: Camera2D
var jugador_1: Player
var jugador_2: Player
var mapa: Node2D
var preparada: bool = false

func _ready() -> void:
	_preparar()

# Arma controles y pantallas una sola vez (la interfaz puede pedir el nivel antes de este _ready)
func _preparar() -> void:
	if preparada: return
	preparada = true
	add_to_group("PantallaDividida") # Así la encuentran la salida y las cajas (que en este modo son de adorno)
	_armar_controles()
	_armar_pantallas()
	_armar_carteles()

# =====================================================================
# CONTROLES DE CADA JUGADOR (están en controles_coop.gd, así los usa también la pantalla de personajes)
# =====================================================================
func _armar_controles() -> void:
	preload("res://scripts/controles_coop.gd").armar()

# =====================================================================
# PANTALLA DIVIDIDA
# =====================================================================
func _armar_pantallas() -> void:
	var fondo = ColorRect.new()
	fondo.color = Color.BLACK # La rayita del medio es el fondo que queda entre las dos mitades
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fila = HBoxContainer.new()
	fila.add_theme_constant_override("separation", ANCHO_DIVISION)
	add_child(fila)
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var resultado_1 = _armar_mitad(fila)
	var resultado_2 = _armar_mitad(fila)
	vista_1 = resultado_1[0]; camara_1 = resultado_1[1]
	vista_2 = resultado_2[0]; camara_2 = resultado_2[1]
	vista_2.world_2d = vista_1.world_2d # Las dos mitades miran el mismo mundo
	# Lo de una sola mitad: la 1 no dibuja lo del J2 y la 2 no dibuja lo del J1
	vista_1.canvas_cull_mask &= ~CAPA_SOLO_J2
	vista_2.canvas_cull_mask &= ~CAPA_SOLO_J1

# La salida (salida_coop.gd): si el nivel no tiene una, va enfrente de la puerta
func _poner_salida() -> void:
	for s in get_tree().get_nodes_in_group("SalidaCoop"):
		if mapa.is_ancestor_of(s): return
	var puerta: Node2D = null
	for p in get_tree().get_nodes_in_group("PuertaEntrada"):
		if mapa.is_ancestor_of(p): puerta = p
	var salida = Area2D.new()
	salida.name = "SalidaCoop"
	salida.set_script(SalidaCoop)
	salida.position = (mapa.to_local(puerta.global_position) if puerta else jugador_1.position) + salida_desde_la_puerta
	mapa.add_child(salida)

# El guardia (guardia.gd): si el nivel no tiene uno, arranca en el medio del súper
func _poner_guardia() -> void:
	if not hay_guardia: return
	var guardia: Node2D = null
	for g in get_tree().get_nodes_in_group("Guardia"):
		if mapa.is_ancestor_of(g) and not g.is_queued_for_deletion(): guardia = g
	if guardia == null:
		guardia = Node2D.new()
		guardia.name = "Guardia"
		guardia.set_script(Guardia)
		var piso: TileMapLayer = mapa.get_node_or_null("Floor")
		if piso:
			var usado: Rect2i = piso.get_used_rect()
			guardia.position = mapa.to_local(piso.to_global(piso.map_to_local(usado.position + usado.size / 2)))
		else:
			guardia.position = jugador_1.position + Vector2(0, 200)
		mapa.add_child(guardia)
	guardia.estado_jugador.connect(_poner_icono_guardia)
	for p in iconos_guardia: _poner_icono_guardia(p, "tranquilo")

func _poner_icono_guardia(prefijo: String, estado: String) -> void:
	var icono: TextureRect = iconos_guardia.get(prefijo)
	if icono == null: return
	var nuevo: Texture2D = ICONOS_GUARDIA.get(estado)
	if icono.texture == nuevo: return
	icono.texture = nuevo
	icono.size = nuevo.get_size()
	# Contra el cartel J1 (a su derecha) o J2 (a su izquierda), centrado en su altura
	var cartel: TextureRect = get_node_or_null("CartelJ1" if prefijo == "p1_" else "CartelJ2")
	if cartel:
		icono.position.y = round(cartel.position.y + (cartel.size.y - icono.size.y) / 2.0)
		icono.position.x = cartel.position.x + cartel.size.x + 3 if prefijo == "p1_" else cartel.position.x - 3 - icono.size.x
	icono.pivot_offset = icono.size / 2.0
	icono.scale = Vector2(0.4, 0.4)
	var t = icono.create_tween()
	t.tween_property(icono, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# "J1" contra el borde izquierdo y "J2" contra el derecho (quedan abajo de la interfaz y de los minijuegos)
func _armar_carteles() -> void:
	var ancho: float = get_viewport_rect().size.x
	for cartel in [[CARTEL_J1, "CartelJ1", margen_carteles],
				   [CARTEL_J2, "CartelJ2", ancho - margen_carteles - CARTEL_J2.get_width()]]:
		var r = TextureRect.new()
		r.name = cartel[1]
		r.texture = cartel[0]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.position = Vector2(round(cartel[2]), altura_carteles)
		r.size = cartel[0].get_size()
		add_child(r)
	# Al lado de cada cartel, el ícono de cómo está con el guardia
	if hay_guardia:
		for p in ["p1_", "p2_"]:
			var icono = TextureRect.new()
			icono.name = "IconoGuardia" + p.to_upper().trim_suffix("_")
			icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(icono)
			iconos_guardia[p] = icono
			_poner_icono_guardia(p, "tranquilo")

func _armar_mitad(fila: HBoxContainer) -> Array:
	var contenedor = SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contenedor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fila.add_child(contenedor)
	var vista = SubViewport.new()
	vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vista.snap_2d_transforms_to_pixel = true
	vista.handle_input_locally = false
	contenedor.add_child(vista)
	var camara = Camera2D.new()
	camara.zoom = Vector2(zoom_camara, zoom_camara)
	vista.add_child(camara)
	camara.make_current()
	return [vista, camara]

# =====================================================================
# NIVEL Y JUGADORES
# =====================================================================
# La cámara de la mitad de cada jugador ("p1_" o "p2_"): la usan los minijuegos para sacudirla
func camara_de(prefijo: String) -> Camera2D:
	_preparar()
	return camara_2 if prefijo == "p2_" else camara_1

# La interfaz (gestor_interfaz.gd) nos pasa el nivel ya cargado. Saca el anterior (al reintentar o pasar de nivel).
func poner_nivel(nuevo: Node2D, misma_posicion: bool = false) -> void:
	_preparar()
	if mapa and is_instance_valid(mapa):
		if misma_posicion: nuevo.position = mapa.position
		mapa.queue_free()
	mapa = nuevo
	vista_1.add_child(mapa) # El nivel vive en la mitad 1; la 2 lo ve porque comparten el mundo
	# BUGFIX: esperamos a que el nivel termine de armarse (ahí pone los límites de la cámara)
	if not mapa.is_node_ready():
		await mapa.ready
	jugador_1 = mapa.get_node("%Player")
	jugador_1.prefijo_acciones = "p1_"

	jugador_2 = load(ESCENA_JUGADOR).instantiate()
	jugador_2.name = "Player2"
	jugador_2.prefijo_acciones = "p2_"
	# Arranca afuera, atrás del jugador 1: entran en fila (la entrada la hace config_nivel.gd)
	jugador_2.position = jugador_1.position + Vector2(0, -distancia_fila)
	jugador_2.is_frozen = true
	mapa.add_child(jugador_2)

	# Cada uno con su ropa de ladrón
	_vestir(jugador_1, _animaciones_elegidas(0, animaciones_jugador_1))
	_vestir(jugador_2, _animaciones_elegidas(1, animaciones_jugador_2))

	# Las cámaras de los personajes no se usan (cada mitad tiene la suya), pero copiamos sus límites
	for j in [jugador_1, jugador_2]:
		var c: Camera2D = j.get_node_or_null("Camera2D")
		if c: c.enabled = false
	var limites: Camera2D = jugador_1.get_node("Camera2D")
	for camara in [camara_1, camara_2]:
		camara.limit_left = limites.limit_left
		camara.limit_right = limites.limit_right
		camara.limit_top = limites.limit_top
		camara.limit_bottom = limites.limit_bottom
	_seguir_jugadores()
	camara_1.reset_smoothing(); camara_2.reset_smoothing()
	_poner_salida()
	_poner_guardia()

	# El jugador 2 se puede mover cuando el 1 termina de entrar por la puerta
	var uno: Player = jugador_1
	var dos: Player = jugador_2
	while is_inside_tree() and is_instance_valid(uno) and uno.is_frozen:
		await get_tree().process_frame
	if not is_inside_tree(): return # Se cambió de pantalla mientras entraban
	if is_instance_valid(dos): dos.is_frozen = false

# El personaje que eligió cada jugador (0 = jugador 1, 1 = jugador 2)
func _animaciones_elegidas(jugador: int, por_defecto: SpriteFrames) -> SpriteFrames:
	var elegidos: Array = GameManager.personajes_coop
	if jugador < elegidos.size():
		var i: int = elegidos[jugador]
		if i >= 0 and i < GameManager.PERSONAJES_COOP.size():
			return load(GameManager.PERSONAJES_COOP[i])
	return por_defecto

func _vestir(jugador: Player, animaciones: SpriteFrames) -> void:
	if animaciones == null: return
	var sprite: AnimatedSprite2D = jugador.get_node("AnimatedSprite2D")
	var anterior: StringName = sprite.animation
	sprite.sprite_frames = animaciones
	if animaciones.has_animation(anterior): sprite.play(anterior)

func _process(_delta: float) -> void:
	_seguir_jugadores()

func _seguir_jugadores() -> void:
	if not is_instance_valid(jugador_1) or not is_instance_valid(jugador_2): return
	if jugador_1: camara_1.global_position = jugador_1.global_position + _corrimiento_camara()
	if jugador_2: camara_2.global_position = jugador_2.global_position + _corrimiento_camara()

# Cada jugador queda en el MEDIO de lo que se ve de su mitad: arriba tapan la franja negra, el ticket
# de la lista y los carteles J1/J2, así que la cámara se corre un poco para arriba (y el personaje
# queda más abajo en la pantalla, con lo mismo para ver arriba que abajo).
func _corrimiento_camara() -> Vector2:
	var alto: float = vista_1.size.y if vista_1 else 432.0
	var centro_visible: float = (tapado_arriba + alto) / 2.0      # El medio de lo que se ve (en pixeles de pantalla)
	var bajar: float = (centro_visible - alto / 2.0) / zoom_camara  # Cuánto más abajo tiene que quedar (en el mundo)
	return Vector2(0, -MEDIO_DEL_DIBUJO - bajar)
