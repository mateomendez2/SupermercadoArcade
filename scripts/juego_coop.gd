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
##   Jugador 1: 1er joystick del tablero (o WASD) + sus botones (o E / Z / X / C)
##   Jugador 2: 2do joystick del tablero (o flechas) + sus botones (o J / K / L)

@export var zoom_camara: float = 2.0 # 2 = igual que en el modo de un jugador
@export var distancia_fila: float = 30.0 # Al entrar, el jugador 2 viene atrás del 1 (en fila), a esta distancia
# Cómo se ve cada ladrón: lo eligen en la pantalla de personajes (GameManager.personajes_coop).
# Si se abre esta escena directo (sin pasar por ahí), se usan estos dos:
@export var animaciones_jugador_1: SpriteFrames = preload("res://assets/ladrones/ladrona.tres") # Ella, pañuelo rojo
@export var animaciones_jugador_2: SpriteFrames = preload("res://assets/ladrones/ladron.tres")  # Él, pañuelo azul

const ESCENA_JUGADOR: String = "res://scenes/characters/jugador.tscn"
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
	_armar_controles()
	_armar_pantallas()

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

	# El jugador 2 se puede mover cuando el 1 termina de entrar por la puerta
	var uno: Player = jugador_1
	var dos: Player = jugador_2
	while is_instance_valid(uno) and uno.is_frozen:
		await get_tree().process_frame
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
	if jugador_1: camara_1.global_position = jugador_1.global_position + Vector2(0, 12)
	if jugador_2: camara_2.global_position = jugador_2.global_position + Vector2(0, 12)
