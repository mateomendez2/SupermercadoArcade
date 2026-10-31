extends Control
## MINIJUEGO "EMBOLSAR"
## Por la cinta de la caja vienen productos con una etiqueta de color.
## Cuando un producto llega a la zona dorada (al final de la cinta), apretás el color de su etiqueta
## y salta a la bolsa de ese color (las bolsas están arriba de cada botón).
## - Si apretás otro color, rebota en la bolsa equivocada: error.
## - Si no apretás a tiempo, se cae al final de la cinta: error.
## - Si apretás sin nada en la zona: error (como en la caída).
## - Llenás la barra (6 aciertos) y ganás. Con 5 errores se cierra, como los otros minijuegos.

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

const Confites = preload("res://scripts/confites.gd")
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]
const COLOR_ETIQUETA: Dictionary = {
	"azul": Color8(54, 104, 252),
	"rojo": Color8(255, 63, 59),
	"amarillo": Color8(251, 242, 54),
}
const BRILLO_ETIQUETA: Dictionary = {
	"azul": Color8(130, 180, 255),
	"rojo": Color8(255, 150, 140),
	"amarillo": Color8(255, 255, 200),
}
const CARPETA_ARTE: String = "res://assets/ui/qte/"
const HOJA_PRODUCTOS: Texture2D = preload("res://assets/ObjetosLista.png")
const RUTA_SONIDO_BOLSA: String = "res://assets/audio/BolsaPlop.wav"

# --- REGLAS (se pueden cambiar desde el Inspector) ---
@export var aciertos_para_ganar: int = 6
@export var errores_maximos: int = 5
@export var velocidad_cinta: float = 36.0     # Pixeles por segundo
@export var aumento_por_acierto: float = 3.0  # La cinta se apura un poquito con cada acierto
@export var espera_min: float = 0.9           # Tiempo entre un producto y el siguiente
@export var espera_max: float = 1.3
@export var maximo_en_cinta: int = 3

# --- AJUSTES FINOS (en pixeles del cartel) ---
const Y_CINTA: float = 70.0       # Arriba de la cinta (ahí se apoyan los productos)
const X_CINTA_0: float = 61.5
const X_CINTA_1: float = 193.5
const ZONA: Rect2 = Rect2(164.5, 49, 28, 22) # Donde hay que apretar
const MARGEN_ZONA: float = 3.0    # Un poquito de tolerancia a cada lado de la zona
const Y_BOLSA: float = 116.0      # Donde apoyan las bolsas (justo arriba de los botones)
const CENTRO_DIBUJO_BOTON: float = 17.0
const COLOR_ZONA: Color = Color8(250, 196, 60)
const COLOR_ESQUINAS: Color = Color8(235, 150, 20)
const O: Color = Color8(40, 30, 40)
const K: Color = Color8(68, 68, 91)
const D: Color = Color8(94, 97, 118)
const M: Color = Color8(108, 110, 133)

# Botones hundidos (igual que en los otros minijuegos)
@export var tex_azul_hundido: Texture2D
@export var tex_rojo_hundido: Texture2D
@export var tex_amarillo_hundido: Texture2D

@onready var botones: Dictionary = {
	"azul": %BotonAzul,
	"rojo": %BotonRojo,
	"amarillo": %BotonAmarillo,
}
@onready var cartel: TextureRect = $FondoCartel
@onready var fondo_oscuro: ColorRect = $Fondo

var tex_normal: Dictionary = {}
var tex_hundido: Dictionary = {}

var is_active: bool = false
var intentos_restantes: int = 5 # Mismo nombre que en los otros minijuegos
var aciertos: int = 0
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error

var capa: Control
var cinta: Node2D       # Dibuja la cinta y la zona
var bolsas: Dictionary = {}
var productos: Array = [] # Cada uno: {"nodo": Node2D, "color": String}
var espera_proximo: float = 0.0
var velocidad: float = 36.0
var corrimiento: float = 0.0 # Para que las rayitas de la cinta se muevan
var tiempo: float = 0.0
var barra: ProgressBar
var corazones
var sonido_bolsa: AudioStreamPlayer

func _ready() -> void:
	hide()
	for color in COLORES:
		tex_normal[color] = botones[color].texture
	tex_hundido = {"azul": tex_azul_hundido, "rojo": tex_rojo_hundido, "amarillo": tex_amarillo_hundido}
	color_fondo_normal = fondo_oscuro.color
	_armar()
	_armar_barra()
	corazones = CorazonesQTE.new()
	cartel.add_child(corazones)
	sonido_bolsa = AudioStreamPlayer.new()
	sonido_bolsa.volume_db = -6.0
	if ResourceLoader.exists(RUTA_SONIDO_BOLSA): sonido_bolsa.stream = load(RUTA_SONIDO_BOLSA)
	add_child(sonido_bolsa)
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

func _armar() -> void:
	capa = Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.add_child(capa)
	cinta = Node2D.new()
	capa.add_child(cinta)
	cinta.draw.connect(_dibujar_cinta)
	for color in COLORES:
		var b := Sprite2D.new()
		b.texture = load(CARPETA_ARTE + "bolsa_" + color + ".png")
		b.offset = Vector2(0, -b.texture.get_height() / 2.0) # El punto de la bolsa es su base
		b.position = Vector2(botones[color].position.x + CENTRO_DIBUJO_BOTON, Y_BOLSA)
		capa.add_child(b)
		bolsas[color] = b

# Barra vertical arriba del carrito, igual a la de los otros minijuegos
func _armar_barra() -> void:
	barra = ProgressBar.new()
	barra.show_percentage = false
	barra.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	barra.min_value = 0
	barra.max_value = aciertos_para_ganar
	barra.step = 1
	barra.position = Vector2(44.5, 50) # Dentro del blanco del cartel, arriba del carrito
	barra.size = Vector2(13, 61)
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El relleno no puede salirse de la barra (con 3 de 6 quedaba en medio pixel y asomaba una rayita verde abajo)
	barra.clip_contents = true

	var fondo = StyleBoxFlat.new()
	fondo.bg_color = Color8(60, 32, 16)
	barra.add_theme_stylebox_override("background", fondo)
	var relleno = StyleBoxFlat.new()
	relleno.bg_color = Color8(0, 231, 73)
	barra.add_theme_stylebox_override("fill", relleno)

	# El marco naranja va por encima del relleno, así nunca lo tapa
	var marco = Panel.new()
	var estilo_marco = StyleBoxFlat.new()
	estilo_marco.draw_center = false
	estilo_marco.set_border_width_all(2)
	estilo_marco.border_color = Color8(255, 111, 0)
	marco.add_theme_stylebox_override("panel", estilo_marco)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(marco)
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	cartel.add_child(barra)

# =====================================================================
# ARRANQUE
# =====================================================================
func start_qte() -> void:
	IconosMando.aplicar(self)
	sesion += 1
	for p in productos:
		p["nodo"].queue_free()
	productos.clear()
	aciertos = 0
	intentos_restantes = errores_maximos
	velocidad = velocidad_cinta
	barra.max_value = aciertos_para_ganar
	barra.value = 0
	for color in COLORES:
		botones[color].texture = tex_normal[color]
		bolsas[color].scale = Vector2.ONE
		bolsas[color].modulate = Color.WHITE
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = color_fondo_normal
	corazones.armar(errores_maximos)
	espera_proximo = 0.4 # Un respiro antes del primer producto

	show()
	await get_tree().process_frame
	is_active = true

# =====================================================================
# CADA FRAME: la cinta avanza, salen productos y se caen los que no embolsaste
# =====================================================================
func _process(delta: float) -> void:
	if not visible: return
	tiempo += delta
	cinta.queue_redraw()
	if not is_active: return
	corrimiento = fmod(corrimiento + velocidad * delta, 8.0)

	espera_proximo -= delta
	if espera_proximo <= 0.0 and productos.size() < maximo_en_cinta:
		_soltar_producto()
		espera_proximo = randf_range(espera_min, espera_max)

	for p in productos.duplicate():
		var n: Node2D = p["nodo"]
		n.position.x += velocidad * delta
		if n.position.x > ZONA.end.x + MARGEN_ZONA:
			productos.erase(p)
			_se_cae(n)
			_error()
			if not is_active: return

func _soltar_producto() -> void:
	var color: String = COLORES.pick_random()
	var n := Node2D.new()
	n.position = Vector2(X_CINTA_0 + 6.0, Y_CINTA - 9.0)
	var s := Sprite2D.new()
	var a := AtlasTexture.new()
	a.atlas = HOJA_PRODUCTOS
	a.region = Rect2(16 * (randi() % 3), 16 * (randi() % 5), 16, 16)
	s.texture = a
	n.add_child(s)
	# La etiqueta de color, adelante del producto
	var etiqueta := Node2D.new()
	n.add_child(etiqueta)
	etiqueta.draw.connect(func():
		etiqueta.draw_rect(Rect2(-6, 2, 12, 7), O)
		etiqueta.draw_rect(Rect2(-5, 3, 10, 5), COLOR_ETIQUETA[color])
		etiqueta.draw_rect(Rect2(-5, 3, 10, 1), BRILLO_ETIQUETA[color]))
	n.modulate.a = 0.0
	capa.add_child(n)
	create_tween().tween_property(n, "modulate:a", 1.0, 0.15)
	productos.append({"nodo": n, "color": color})

# =====================================================================
# BOTONES
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return

	var color = ""
	if event.is_action_pressed(prefijo + "btn_azul"): color = "azul"
	elif event.is_action_pressed(prefijo + "btn_rojo"): color = "rojo"
	elif event.is_action_pressed(prefijo + "btn_amarillo"): color = "amarillo"

	if color == "" and not event.is_action_pressed(prefijo + "interact"):
		return
	get_viewport().set_input_as_handled() # Que el botón no "haga eco" en el juego
	if color == "": return

	_hundir(color)
	_apretar(color)

func _apretar(color: String) -> void:
	# El producto que está en la zona (si hay dos, el que está más adelante)
	var elegido = null
	for p in productos:
		var x: float = p["nodo"].position.x
		if x >= ZONA.position.x - MARGEN_ZONA and x <= ZONA.end.x + MARGEN_ZONA:
			if elegido == null or x > elegido["nodo"].position.x: elegido = p
	if elegido == null:
		_error() # Apretó cuando no había nada en la zona
		return
	productos.erase(elegido)
	if elegido["color"] == color:
		_a_la_bolsa(elegido["nodo"], color)
		_acierto()
	else:
		_bolsa_equivocada(elegido["nodo"], color)
		_error()

func _acierto() -> void:
	_destello_fondo(FONDO_VERDE)
	aciertos += 1
	barra.value = aciertos
	velocidad += aumento_por_acierto
	if aciertos >= aciertos_para_ganar:
		_ganar()

func _error() -> void:
	_destello_fondo(FONDO_ROJO)
	intentos_restantes -= 1
	corazones.perder_vida()
	print("¡Fallaste! Te quedan: ", intentos_restantes, " intentos.")
	if intentos_restantes <= 0:
		_perder()

# =====================================================================
# FINALES
# =====================================================================
func _ganar() -> void:
	is_active = false
	_desvanecer_productos()
	qte_finished.emit(true) # El juego te da el producto al instante
	# Festejo con confites; el cartel se queda un momento y después se cierra
	var mi_sesion = sesion
	var confites = Confites.new()
	add_child(confites)
	await confites.festejar(self)
	if mi_sesion == sesion:
		hide()

func _perder() -> void:
	is_active = false
	_desvanecer_productos()
	var mi_sesion = sesion
	await get_tree().create_timer(0.45).timeout # Para que se vea el último destello rojo
	if mi_sesion == sesion:
		hide()
		qte_finished.emit(false)

# =====================================================================
# EFECTOS
# =====================================================================
# Sale volando en arco hasta la bolsa y se mete adentro
func _a_la_bolsa(n: Node2D, color: String) -> void:
	var b: Sprite2D = bolsas[color]
	var t = _arco(n, n.position, Vector2(b.position.x, b.position.y - 22.0), 18.0, 0.3)
	t.tween_property(n, "position:y", b.position.y - 12.0, 0.08)
	t.parallel().tween_property(n, "modulate:a", 0.0, 0.08)
	t.tween_callback(func():
		n.queue_free()
		if sonido_bolsa.stream and visible and aciertos < aciertos_para_ganar: sonido_bolsa.play() # El último no (suena la fanfarria)
		b.scale = Vector2(1.25, 0.8)
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK))

# Va a la bolsa que no es, rebota y se cae
func _bolsa_equivocada(n: Node2D, color: String) -> void:
	var b: Sprite2D = bolsas[color]
	var t = _arco(n, n.position, Vector2(b.position.x, b.position.y - 22.0), 18.0, 0.3)
	t.tween_callback(func():
		b.modulate = Color(1.6, 0.5, 0.5)
		create_tween().tween_property(b, "modulate", Color.WHITE, 0.3))
	t.tween_method(func(k: float):
		var desde := Vector2(b.position.x, b.position.y - 22.0)
		n.position = desde + Vector2(14.0 * k, 16.0 * k - sin(k * PI) * 14.0)
		n.modulate.a = 1.0 - k, 0.0, 1.0, 0.3)
	t.tween_callback(n.queue_free)

# Se cae por el final de la cinta, girando
func _se_cae(n: Node2D) -> void:
	var t = create_tween().set_parallel(true)
	t.tween_property(n, "position", n.position + Vector2(8, 26), 0.35).set_ease(Tween.EASE_IN)
	t.tween_property(n, "rotation", 1.6, 0.35)
	t.tween_property(n, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(n.queue_free)

func _arco(n: Node2D, desde: Vector2, hasta: Vector2, altura: float, duracion: float) -> Tween:
	var t = create_tween()
	t.tween_method(func(k: float): n.position = desde.lerp(hasta, k) + Vector2(0, -sin(k * PI) * altura), 0.0, 1.0, duracion)
	return t

# Al terminar, los productos que quedaban en la cinta se desvanecen
func _desvanecer_productos() -> void:
	for p in productos:
		var n: Node2D = p["nodo"]
		var t = create_tween()
		t.tween_property(n, "modulate:a", 0.0, 0.2)
		t.tween_callback(n.queue_free)
	productos.clear()

func _dibujar_cinta() -> void:
	var largo: float = X_CINTA_1 - X_CINTA_0
	cinta.draw_rect(Rect2(X_CINTA_0, Y_CINTA - 1, largo, 9), O)
	cinta.draw_rect(Rect2(X_CINTA_0 + 1, Y_CINTA, largo - 2, 7), K)
	cinta.draw_rect(Rect2(X_CINTA_0 + 1, Y_CINTA, largo - 2, 1), M)
	var x: float = X_CINTA_0 + 3.0 + corrimiento
	while x < X_CINTA_1 - 2.0:
		cinta.draw_rect(Rect2(floor(x), Y_CINTA + 2, 1, 4), D)
		x += 8.0
	# Patas
	cinta.draw_rect(Rect2(X_CINTA_0 + 4, Y_CINTA + 8, 3, 6), O)
	cinta.draw_rect(Rect2(X_CINTA_1 - 7, Y_CINTA + 8, 3, 6), O)
	# Zona donde hay que apretar (titila suave)
	var a: float = 0.6 + 0.4 * sin(tiempo * 8.0)
	cinta.draw_rect(ZONA, Color(COLOR_ZONA, 0.22 * a))
	var l := 5.0
	var zx: float = ZONA.position.x
	var zy: float = ZONA.position.y
	var ex: float = ZONA.end.x
	var ey: float = ZONA.end.y
	for r in [Rect2(zx, zy, l, 2), Rect2(zx, zy, 2, l), Rect2(ex - l, zy, l, 2), Rect2(ex - 2, zy, 2, l),
			Rect2(zx, ey - 2, l, 2), Rect2(zx, ey - l, 2, l), Rect2(ex - l, ey - 2, l, 2), Rect2(ex - 2, ey - l, 2, l)]:
		cinta.draw_rect(r, Color(COLOR_ESQUINAS, a))

func _hundir(color: String) -> void:
	var boton: TextureRect = botones[color]
	if tex_hundido[color]: boton.texture = tex_hundido[color]
	await get_tree().create_timer(0.08).timeout
	boton.texture = tex_normal[color]

# El fondo oscuro de atrás del cartel se tiñe un instante de verde (acierto) o rojo (error)
const FONDO_VERDE: Color = Color(0.0, 0.32, 0.08, 0.6)
const FONDO_ROJO: Color = Color(0.38, 0.0, 0.0, 0.6)
var color_fondo_normal: Color
var tween_fondo: Tween

func _destello_fondo(tono: Color) -> void:
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = tono
	tween_fondo = create_tween()
	tween_fondo.tween_property(fondo_oscuro, "color", color_fondo_normal, 0.35)

func _cambio_de_mando(_mando: int, _conectado: bool) -> void:
	IconosMando.aplicar(self)
