extends Control
## MINIJUEGO "EL TRUCO DEL COLOR"
## En el medio del cartel aparece el nombre de un color (AZUL, ROJO o AMARILLO)
## pintado de OTRO color. Hay que apretar el botón del color de la TINTA, no lo que dice.
## - Arriba de la palabra hay una barrita de tiempo: si se vacía antes de apretar, es error.
## - Cada acierto achica un poco el tiempo de la palabra siguiente.
## - Llenás la barra de la izquierda (6 aciertos) y ganás. Con 5 errores se cierra, como los otros.
## - Con "con_cambio_de_regla" prendido, a veces el cartel pide apretar lo que DICE la palabra.

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

const Confites = preload("res://scripts/confites.gd")
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]
const COLOR_TINTA: Dictionary = {
	"azul": Color8(54, 104, 252),
	"rojo": Color8(255, 63, 59),
	"amarillo": Color8(251, 242, 54),
}

# --- REGLAS (se pueden cambiar desde el Inspector) ---
@export var aciertos_para_ganar: int = 6
@export var errores_maximos: int = 5
@export var tiempo_inicial: float = 2.0       # Segundos para contestar la primera palabra
@export var tiempo_minimo: float = 1.1        # Nunca baja de esto
@export var recorte_por_acierto: float = 0.13 # Cuánto tiempo se saca por cada acierto
@export var chance_misma_tinta: float = 0.2   # A veces la palabra está pintada de su propio color
@export var con_cambio_de_regla: bool = false # Versión difícil: a veces pide lo que DICE
@export var chance_cambio_regla: float = 0.35

# --- TEXTOS DEL CARTEL ---
# El texto normal es el que tenga escrito el Label "Regla" en la escena.
# Este es el de la versión difícil, cuando pide apretar lo que DICE la palabra:
@export_multiline var texto_regla_dice: String = "Apretá el color\nque dice"
var texto_regla_normal: String = ""

# --- AJUSTES FINOS ---
const PAUSA_ACIERTO: float = 0.28 # Respiro entre una palabra y la siguiente
const PAUSA_ERROR: float = 0.65
const TIEMPO_PISTA: float = 0.38  # Cuánto se ilumina el botón correcto cuando le errás
const COLOR_BARRA: Color = Color8(247, 181, 0)
const COLOR_BARRA_APURO: Color = Color8(255, 63, 59)

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
@onready var texto_regla: Label = %Regla
@onready var texto_palabra: Label = %Palabra
@onready var barra_tiempo: ColorRect = %BarraTiempo
@onready var fondo_oscuro: ColorRect = $Fondo

var tex_normal: Dictionary = {}
var tex_hundido: Dictionary = {}

var is_active: bool = false
var intentos_restantes: int = 5 # Mismo nombre que en los otros minijuegos
var aciertos: int = 0
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error

var estado: String = "pausa" # "mostrando" (esperando que apriete) o "pausa" (entre palabras)
var palabra: String = ""
var tinta: String = ""
var regla: String = "tinta"  # "tinta" o "palabra"
var tiempo_limite: float = 2.0
var tiempo_restante: float = 0.0
var ancho_barra: float = 0.0

var barra: ProgressBar
var corazones # Columna de vidas al costado del cartel (corazones_qte.gd)

# "Pling" de cada acierto (el último no suena, porque ahí ya suena la fanfarria de victoria)
const RUTA_SONIDO_ACIERTO: String = "res://assets/audio/QteAcierto.wav"
const VOLUMEN_ACIERTO: float = -8.0
var sonido_acierto: AudioStreamPlayer

func _ready() -> void:
	hide()
	sonido_acierto = AudioStreamPlayer.new()
	sonido_acierto.volume_db = VOLUMEN_ACIERTO
	if ResourceLoader.exists(RUTA_SONIDO_ACIERTO): sonido_acierto.stream = load(RUTA_SONIDO_ACIERTO)
	add_child(sonido_acierto)
	for color in COLORES:
		tex_normal[color] = botones[color].texture
	tex_hundido = {"azul": tex_azul_hundido, "rojo": tex_rojo_hundido, "amarillo": tex_amarillo_hundido}
	ancho_barra = barra_tiempo.size.x
	color_fondo_normal = fondo_oscuro.color
	texto_regla_normal = texto_regla.text
	_armar_barra()
	corazones = CorazonesQTE.new()
	cartel.add_child(corazones)

# Barra vertical arriba del carrito, igual a la del minijuego de la caída
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

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
	aciertos = 0
	intentos_restantes = errores_maximos
	barra.max_value = aciertos_para_ganar
	barra.value = 0
	for color in COLORES:
		botones[color].texture = tex_normal[color]
		botones[color].modulate = Color.WHITE
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = color_fondo_normal
	regla = "tinta"
	texto_regla.text = texto_regla_normal
	texto_palabra.text = ""
	corazones.armar(errores_maximos)
	_dibujar_barra_tiempo(1.0)
	estado = "pausa"

	show()
	await get_tree().process_frame
	is_active = true
	_esperar_y_mostrar(0.5) # Un respiro antes de la primera palabra

# =====================================================================
# RONDAS
# =====================================================================
func _esperar_y_mostrar(segundos: float) -> void:
	var mi_sesion = sesion
	await get_tree().create_timer(segundos).timeout
	if mi_sesion == sesion and is_active:
		_nueva_palabra()

func _nueva_palabra() -> void:
	palabra = COLORES.pick_random()
	if randf() < chance_misma_tinta:
		tinta = palabra
	else:
		var otros = COLORES.filter(func(c): return c != palabra)
		tinta = otros.pick_random()

	# En la versión difícil, a veces la regla se da vuelta (nunca en la primera palabra)
	if con_cambio_de_regla and aciertos > 0 and randf() < chance_cambio_regla:
		regla = "palabra"
	else:
		regla = "tinta"
	texto_regla.text = texto_regla_normal if regla == "tinta" else texto_regla_dice

	texto_palabra.text = palabra.to_upper()
	texto_palabra.add_theme_color_override("font_color", COLOR_TINTA[tinta])

	tiempo_limite = maxf(tiempo_minimo, tiempo_inicial - aciertos * recorte_por_acierto)
	tiempo_restante = tiempo_limite
	_dibujar_barra_tiempo(1.0)
	estado = "mostrando"

func _process(delta: float) -> void:
	if not is_active or estado != "mostrando": return
	tiempo_restante -= delta
	_dibujar_barra_tiempo(tiempo_restante / tiempo_limite)
	if tiempo_restante <= 0.0:
		_error() # Se le acabó el tiempo sin apretar

func _dibujar_barra_tiempo(fraccion: float) -> void:
	fraccion = clampf(fraccion, 0.0, 1.0)
	barra_tiempo.size.x = round(ancho_barra * fraccion)
	barra_tiempo.color = COLOR_BARRA_APURO if fraccion < 0.3 else COLOR_BARRA

func _color_correcto() -> String:
	return tinta if regla == "tinta" else palabra

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
	if estado != "mostrando": return # Entre palabra y palabra no cuenta
	if color == _color_correcto():
		_acierto()
	else:
		_error()

func _acierto() -> void:
	estado = "pausa"
	texto_palabra.text = ""
	_destello_fondo(FONDO_VERDE)
	aciertos += 1
	barra.value = aciertos
	if aciertos >= aciertos_para_ganar:
		_ganar()
	else:
		_sonar_acierto(aciertos)
		_esperar_y_mostrar(PAUSA_ACIERTO)

func _error() -> void:
	estado = "pausa"
	_destello_fondo(FONDO_ROJO)
	_mostrar_pista(_color_correcto())
	intentos_restantes -= 1
	corazones.perder_vida()
	print("¡Fallaste! Te quedan: ", intentos_restantes, " intentos.")
	if intentos_restantes <= 0:
		_perder()
	else:
		_esperar_y_mostrar(PAUSA_ERROR)

# =====================================================================
# FINALES
# =====================================================================
func _ganar() -> void:
	is_active = false
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
	await get_tree().create_timer(0.45).timeout # Para que se vea el último destello y la pista
	if mi_sesion == sesion:
		hide()
		qte_finished.emit(false)

# =====================================================================
# EFECTOS
# =====================================================================
func _hundir(color: String) -> void:
	var boton: TextureRect = botones[color]
	if tex_hundido[color]: boton.texture = tex_hundido[color]
	await get_tree().create_timer(0.08).timeout
	boton.texture = tex_normal[color]

# Cuando le errás, el botón correcto se ilumina un instante y la palabra se va
func _mostrar_pista(color: String) -> void:
	var boton: TextureRect = botones[color]
	boton.modulate = Color(1.7, 1.7, 1.7)
	var t = create_tween()
	t.tween_interval(TIEMPO_PISTA)
	t.tween_callback(func():
		boton.modulate = Color.WHITE
		if estado == "pausa": texto_palabra.text = "")

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
