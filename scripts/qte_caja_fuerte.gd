extends Control
## MINIJUEGO "LA CAJA FUERTE"
## Un reloj con una aguja que gira sola. Tiene 4 marcas de colores fijas: arriba, a la derecha, abajo y a la izquierda.
## Como son 3 colores, uno está dos veces.
## A la derecha están los 4 toques que pide la cerradura, en orden (el color repetido aparece dos veces).
## Hay que apretar cada color justo cuando la aguja pasa por encima de una marca de ese color.
## - Cada marca se usa una sola vez: si hay dos amarillos y usás uno, el otro queda para cuando lo vuelva a pedir.
## - Muchas veces la aguja pasa por un color que todavía no toca: hay que aguantarse.
## - Hacés los 4 en orden y la caja se abre: ganás (no tiene barra verde).
## - Apretar un color que no toca, o fuera de tiempo, es error (tiemblan las marcas de ese color).
## - Cada vez cambia qué color va en cada lugar, cuál se repite, el orden y para qué lado gira la aguja.

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

const Confites = preload("res://scripts/confites.gd")
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]
const COLOR_MARCA: Dictionary = {
	"azul": Color8(54, 104, 252),
	"rojo": Color8(255, 63, 59),
	"amarillo": Color8(251, 242, 54),
}
const CARPETA_ARTE: String = "res://assets/ui/qte/"
const RUTA_SONIDO_CLIC: String = "res://assets/audio/CajaFuerteClic.wav"

# --- REGLAS (se pueden cambiar desde el Inspector) ---
@export var errores_maximos: int = 3
@export var velocidad_aguja: float = 150.0    # Grados por segundo
@export var aumento_por_acierto: float = 12.0 # La aguja se apura un poquito con cada toque bien hecho
@export var ventana: float = 15.0             # Cuántos grados antes o después de la marca todavía vale
@export var error_si_pasa: bool = false       # true = si la aguja pasa por la marca que toca y no apretás, es error
@export var pausa_inicial: float = 0.6        # La aguja espera un momento al principio, para leer el orden

# --- AJUSTES FINOS (en pixeles del cartel) ---
const CENTRO_RELOJ: Vector2 = Vector2(116.5, 82.0)
const TAM_RELOJ: int = 56           # El dibujo del reloj (cuadrado)
const RADIO_RELOJ: float = 27.0
const LARGO_AGUJA: float = 20.0
const LUGARES: Array[float] = [0.0, 90.0, 180.0, 270.0] # Arriba, derecha, abajo, izquierda
const X_ORDEN: float = 176.5        # La columna de los 4 toques
const Y_ORDEN: float = 58.0
const SEPARACION_ORDEN: float = 17.0
const O: Color = Color8(40, 30, 40)
const BLANCO: Color = Color8(250, 250, 250)
const VERDE: Color = Color8(0, 231, 73)

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
var intentos_restantes: int = 3 # Mismo nombre que en los otros minijuegos
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error

var marcas: Array = []   # Cada una: {"color": String, "angulo": float, "usada": bool, "brillo": float, "temblor": float}
var orden: Array = []    # Los 4 colores que pide, en orden
var paso: int = 0        # Cuál de los 4 toca ahora
var aguja: float = 45.0  # Ángulo de la aguja (0 = arriba, sentido del reloj)
var sentido: float = 1.0 # 1 = como el reloj, -1 = al revés
var velocidad: float = 150.0
var destello_reloj: float = 0.0
var tiempo: float = 0.0
var espera_aguja: float = 0.0

var capa: Control
var reloj: Sprite2D
var img_reloj: Image
var tex_reloj: ImageTexture
var encima: Node2D       # Flechita y tildes de la columna del orden
var circulos_orden: Array[Sprite2D] = []
var corazones
var sonido_clic: AudioStreamPlayer

# "Pling" de cada acierto (el último no suena, porque ahí ya suena la fanfarria de victoria)
const RUTA_SONIDO_ACIERTO: String = "res://assets/audio/QteAcierto.wav"
const VOLUMEN_ACIERTO: float = -8.0
var sonido_acierto: AudioStreamPlayer

func _ready() -> void:
	hide()
	for color in COLORES:
		tex_normal[color] = botones[color].texture
	tex_hundido = {"azul": tex_azul_hundido, "rojo": tex_rojo_hundido, "amarillo": tex_amarillo_hundido}
	color_fondo_normal = fondo_oscuro.color
	_armar()
	corazones = CorazonesQTE.new()
	cartel.add_child(corazones)
	sonido_clic = AudioStreamPlayer.new()
	sonido_clic.volume_db = -9.0
	if ResourceLoader.exists(RUTA_SONIDO_CLIC): sonido_clic.stream = load(RUTA_SONIDO_CLIC)
	add_child(sonido_clic)
	sonido_acierto = AudioStreamPlayer.new()
	sonido_acierto.volume_db = VOLUMEN_ACIERTO
	if ResourceLoader.exists(RUTA_SONIDO_ACIERTO): sonido_acierto.stream = load(RUTA_SONIDO_ACIERTO)
	add_child(sonido_acierto)
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

func _armar() -> void:
	capa = Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.add_child(capa)
	img_reloj = Image.create(TAM_RELOJ, TAM_RELOJ, false, Image.FORMAT_RGBA8)
	tex_reloj = ImageTexture.create_from_image(img_reloj)
	reloj = Sprite2D.new()
	reloj.texture = tex_reloj
	reloj.position = CENTRO_RELOJ
	capa.add_child(reloj)
	for i in 4:
		var s := Sprite2D.new()
		s.position = Vector2(X_ORDEN, Y_ORDEN + i * SEPARACION_ORDEN)
		capa.add_child(s)
		circulos_orden.append(s)
	encima = Node2D.new()
	encima.z_index = 1
	capa.add_child(encima)
	encima.draw.connect(_dibujar_encima)

# =====================================================================
# ARRANQUE
# =====================================================================
func start_qte() -> void:
	IconosMando.aplicar(self)
	sesion += 1
	intentos_restantes = errores_maximos
	paso = 0
	velocidad = velocidad_aguja
	destello_reloj = 0.0
	espera_aguja = pausa_inicial
	for color in COLORES:
		botones[color].texture = tex_normal[color]
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = color_fondo_normal
	corazones.armar(errores_maximos)
	_sortear()
	_pintar_reloj()

	show()
	await get_tree().process_frame
	is_active = true

# Qué color va en cada lugar (uno repetido), el orden de los 4 toques y para qué lado gira
func _sortear() -> void:
	var colores: Array = COLORES.duplicate()
	colores.append(COLORES.pick_random()) # El repetido
	colores.shuffle()
	marcas.clear()
	for i in 4:
		marcas.append({"color": colores[i], "angulo": LUGARES[i], "usada": false, "brillo": 0.0, "temblor": 0.0})
	# El orden: las 4 marcas mezcladas (así el repetido aparece dos veces)
	var mezcla: Array = marcas.duplicate()
	mezcla.shuffle()
	orden = mezcla.map(func(m): return m["color"])
	for i in 4:
		circulos_orden[i].texture = load(CARPETA_ARTE + "circulo_" + orden[i] + ".png")
		circulos_orden[i].modulate = Color.WHITE
		circulos_orden[i].scale = Vector2.ONE
	sentido = 1.0 if randf() < 0.5 else -1.0
	aguja = [45.0, 135.0, 225.0, 315.0].pick_random() # Siempre arranca entre dos colores

# =====================================================================
# CADA FRAME: gira la aguja y se pinta el reloj
# =====================================================================
func _process(delta: float) -> void:
	if not visible: return
	tiempo += delta
	for m in marcas:
		m["brillo"] = maxf(0.0, m["brillo"] - delta * 3.0)
		m["temblor"] = maxf(0.0, m["temblor"] - delta * 2.5)
	destello_reloj = maxf(0.0, destello_reloj - delta * 2.5)
	espera_aguja -= delta
	if is_active and espera_aguja <= 0.0:
		var antes: float = aguja
		aguja = fposmod(aguja + sentido * velocidad * delta, 360.0)
		if error_si_pasa: _ver_si_paso(antes)
	_pintar_reloj()
	encima.queue_redraw()

# (Opcional) La aguja pasó por la marca que tocaba y no apretaste
func _ver_si_paso(antes: float) -> void:
	for m in marcas:
		if m["usada"] or m["color"] != orden[paso]: continue
		var limite: float = m["angulo"] + sentido * ventana # Cuando la aguja deja atrás la ventana
		var d_antes: float = wrapf(antes - limite, -180.0, 180.0)
		var d_ahora: float = wrapf(aguja - limite, -180.0, 180.0)
		if signf(d_antes) != signf(d_ahora) and absf(d_antes) < 90.0 and signf(d_ahora) == sentido:
			_error("")
			return

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
	# La marca de ese color que todavía no se usó y que tiene la aguja encima
	var cual = null
	for m in marcas:
		if m["color"] == color and not m["usada"] and absf(wrapf(aguja - m["angulo"], -180.0, 180.0)) <= ventana:
			cual = m
	if color == orden[paso] and cual != null:
		_acierto(cual)
	else:
		_error(color)

func _acierto(m: Dictionary) -> void:
	m["usada"] = true
	m["brillo"] = 1.0
	circulos_orden[paso].modulate = Color(0.45, 0.45, 0.45)
	paso += 1
	velocidad += aumento_por_acierto
	if paso < orden.size(): # El último no suena: ahí ya suena la fanfarria de victoria
		_sonar_acierto(paso)
		if sonido_clic.stream:
			sonido_clic.pitch_scale = 1.0 + paso * 0.06
			sonido_clic.play()
	_destello_fondo(FONDO_VERDE)
	if paso >= orden.size():
		_ganar()

func _error(color: String) -> void:
	# Tiemblan las marcas de ese color que todavía no se usaron
	for m in marcas:
		if not m["usada"] and (m["color"] == color or color == ""): m["temblor"] = 1.0
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
	# ¡Clic! La aguja da una vuelta rápida y el reloj se pone verde un instante
	destello_reloj = 1.0
	var vuelta = create_tween()
	vuelta.tween_method(func(a: float): aguja = fposmod(a, 360.0), aguja, aguja + sentido * 360.0, 0.35)
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
	var mi_sesion = sesion
	await get_tree().create_timer(0.45).timeout # Para que se vea el último destello rojo
	if mi_sesion == sesion:
		hide()
		qte_finished.emit(false)

# =====================================================================
# DIBUJO
# =====================================================================
# El reloj se pinta pixel por pixel: así el círculo queda redondo y prolijo, sin bordes serruchados
func _pintar_reloj() -> void:
	var c := Vector2(TAM_RELOJ / 2.0, TAM_RELOJ / 2.0)
	var relleno: Color = BLANCO.lerp(VERDE, destello_reloj * 0.6)
	var a := deg_to_rad(aguja)
	var punta: Vector2 = c + Vector2(sin(a), -cos(a)) * LARGO_AGUJA
	# Cada marca: hacia dónde apunta, su color y cuánto tiembla
	var lista: Array = []
	for m in marcas:
		var col: Color = COLOR_MARCA[m["color"]]
		if m["usada"]: col = col.lerp(Color(0.62, 0.62, 0.62), 0.6) # Se apaga solo esa (la repetida sigue prendida)
		if m["brillo"] > 0.0: col = col.lerp(Color.WHITE, m["brillo"])
		var r := deg_to_rad(m["angulo"])
		var corr := Vector2(round(sin(tiempo * 70.0) * 1.5 * m["temblor"]), 0) if m["temblor"] > 0.0 else Vector2.ZERO
		lista.append([Vector2(round(sin(r)), round(-cos(r))), col, corr])
	for y in TAM_RELOJ:
		for x in TAM_RELOJ:
			var p := Vector2(x + 0.5, y + 0.5)
			var d: float = p.distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= RADIO_RELOJ:
				col = O if d > RADIO_RELOJ - 2.0 else relleno
				if d <= RADIO_RELOJ - 2.0:
					for m in lista:
						# Marcas con bordes rectos que terminan en punta (una V suave) hacia el centro
						var q: Vector2 = p - c - m[2]
						var largo: float = q.dot(m[0])
						var ancho: float = absf(q.cross(m[0]))
						var ancho_permitido: float = minf(5.0, 5.0 - (18.0 - largo))
						if largo >= 13.0 and ancho <= ancho_permitido:
							col = O if ancho > ancho_permitido - 1.0 else m[1]
				# Aguja y puntito del medio
				if d <= 3.0 or Geometry2D.get_closest_point_to_segment(p, c, punta).distance_to(p) <= 1.0:
					col = O
			img_reloj.set_pixel(x, y, col)
	tex_reloj.update(img_reloj)

# Flechita al lado del toque que sigue y tildes verdes en los que ya hiciste
func _dibujar_encima() -> void:
	if is_active and paso < circulos_orden.size():
		var y: float = circulos_orden[paso].position.y
		var x: float = round(X_ORDEN - 13.0 + sin(tiempo * 9.0) * 1.5)
		encima.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 4), Vector2(x + 5, y), Vector2(x, y + 4)]), O)
	for i in mini(paso, circulos_orden.size()):
		var p: Vector2 = circulos_orden[i].position
		encima.draw_line(p + Vector2(-3, 0), p + Vector2(-1, 3), VERDE, 2.0)
		encima.draw_line(p + Vector2(-1, 3), p + Vector2(4, -3), VERDE, 2.0)

# =====================================================================
# EFECTOS
# =====================================================================
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

# Cada acierto suena un poquito más agudo que el anterior
func _sonar_acierto(numero: int) -> void:
	if sonido_acierto == null or sonido_acierto.stream == null: return
	sonido_acierto.pitch_scale = 1.0 + maxi(numero - 1, 0) * 0.05
	sonido_acierto.play()

func _cambio_de_mando(_mando: int, _conectado: bool) -> void:
	IconosMando.aplicar(self)
