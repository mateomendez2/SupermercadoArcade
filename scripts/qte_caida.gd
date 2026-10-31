extends Control
## MINIJUEGO "CAÍDA"
## Caen círculos de colores, cada uno por el carril de su botón.
## Hay que apretar ese color cuando el círculo entra en el aro de abajo.
## - Si el círculo toca el aro (aunque sea un borde) cuenta como acierto.
## - Al llegar al centro del aro se queda "enganchado" un instante (como un imán)
##   y después sigue bajando mientras se desvanece. Si se desvanece sin apretarlo: error.
## - Llenás la barra (6 aciertos) y ganás. Con 5 errores se cierra, como los otros minijuegos.

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

# Corazones al costado del cartel: uno por vida, se rompen con cada error
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
var corazones

const Confites = preload("res://scripts/confites.gd")
const CARPETA_ARTE: String = "res://assets/ui/qte/"
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]

# --- REGLAS (se pueden cambiar desde el Inspector) ---
@export var aciertos_para_ganar: int = 6
@export var errores_maximos: int = 5
@export var velocidad_caida: float = 55.0 # Pixeles por segundo
@export var espera_min: float = 0.55      # Tiempo entre un círculo y el siguiente
@export var espera_max: float = 0.9

# --- AJUSTES FINOS ---
const TIEMPO_IMAN: float = 0.12        # Cuánto se queda "enganchado" en el aro
const TIEMPO_DESVANECER: float = 0.22  # Cuánto tarda en desaparecer después del aro
const RADIO_CIRCULO: float = 7.0
const RADIO_ARO: float = 9.0
const DISTANCIA_CAIDA: float = 48.0    # Desde qué altura (sobre el aro) aparecen los círculos
const CENTRO_DIBUJO_BOTON: float = 17.0 # El dibujo del botón está centrado 1 px a la derecha de su caja
const ARO_SOBRE_BOTON: float = 14.0     # Cuánto más arriba del botón está el centro del aro


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
@onready var texto_cartel: Label = $Label
@onready var fondo_oscuro: ColorRect = $Fondo

var tex_normal: Dictionary = {}
var tex_hundido: Dictionary = {}

var is_active: bool = false
var intentos_restantes: int = 5 # Mismo nombre que en los otros minijuegos
var aciertos: int = 0
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error

var centro_carril: Dictionary = {} # color -> x del centro de su carril
var y_aro: float = 0.0
var circulos: Array = [] # Cada uno: {"nodo", "color", "y", "estado", "t"}
var espera_proximo: float = 0.0

var capa: Control          # Donde viven los carriles, aros y círculos
var aros: Dictionary = {}  # color -> TextureRect del aro
var barra: ProgressBar

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
	_armar()
	corazones = CorazonesQTE.new()
	cartel.add_child(corazones)

# =====================================================================
# ARMADO (todo se ubica a partir de dónde están los botones)
# =====================================================================
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

func _armar() -> void:
	# La capa va adentro del cartel, así las posiciones son relativas al cartel
	capa = Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.add_child(capa)

	y_aro = botones["azul"].position.y - ARO_SOBRE_BOTON
	for color in COLORES:
		var x = botones[color].position.x + CENTRO_DIBUJO_BOTON
		centro_carril[color] = x

		# Línea punteada del carril (desde donde aparecen los círculos hasta el aro)
		var carril = TextureRect.new()
		carril.texture = load(CARPETA_ARTE + "carril.png")
		carril.stretch_mode = TextureRect.STRETCH_TILE
		carril.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		carril.position = Vector2(x - 1, y_aro - DISTANCIA_CAIDA - RADIO_CIRCULO)
		carril.size = Vector2(2, DISTANCIA_CAIDA + RADIO_CIRCULO - RADIO_ARO)
		carril.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(carril)

		# El aro: el lugar exacto donde hay que apretar
		var aro = TextureRect.new()
		aro.texture = load(CARPETA_ARTE + "aro_" + color + ".png")
		aro.position = Vector2(x - RADIO_ARO, y_aro - RADIO_ARO)
		aro.pivot_offset = Vector2(RADIO_ARO, RADIO_ARO)
		aro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		capa.add_child(aro)
		aros[color] = aro

	_armar_barra()
	color_fondo_normal = fondo_oscuro.color

# Barra vertical arriba del carrito, con el mismo estilo que las otras barras
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

	var marco = Panel.new()
	var estilo_marco = StyleBoxFlat.new()
	estilo_marco.draw_center = false
	estilo_marco.set_border_width_all(2)
	estilo_marco.border_color = Color8(255, 111, 0)
	marco.add_theme_stylebox_override("panel", estilo_marco)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra.add_child(marco)
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	capa.add_child(barra)

# =====================================================================
# ARRANQUE
# =====================================================================
func start_qte() -> void:
	IconosMando.aplicar(self)
	sesion += 1
	for c in circulos:
		c["nodo"].queue_free()
	circulos.clear()
	aciertos = 0
	intentos_restantes = errores_maximos
	corazones.armar(errores_maximos)
	barra.max_value = aciertos_para_ganar
	barra.value = 0
	for color in COLORES:
		botones[color].texture = tex_normal[color]
		aros[color].modulate = Color.WHITE
		aros[color].scale = Vector2.ONE
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = color_fondo_normal
	espera_proximo = 0.5 # Un respiro antes del primer círculo

	show()
	await get_tree().process_frame
	is_active = true

# =====================================================================
# CADA FRAME: soltar círculos y moverlos
# =====================================================================
func _process(delta: float) -> void:
	if not is_active: return

	espera_proximo -= delta
	if espera_proximo <= 0.0:
		_soltar_circulo()
		espera_proximo = randf_range(espera_min, espera_max)

	for c in circulos.duplicate():
		match c["estado"]:
			"cayendo":
				c["y"] += velocidad_caida * delta
				if c["y"] >= y_aro:
					# ¡Llegó al aro! El "imán" lo frena un instante
					c["y"] = y_aro
					c["estado"] = "iman"
					c["t"] = TIEMPO_IMAN
			"iman":
				c["t"] -= delta
				if c["t"] <= 0.0:
					c["estado"] = "saliendo"
					c["t"] = TIEMPO_DESVANECER
			"saliendo":
				# Sigue bajando y se desvanece antes de llegar al botón
				c["y"] += velocidad_caida * delta
				c["t"] -= delta
				c["nodo"].modulate.a = clampf(c["t"] / TIEMPO_DESVANECER, 0.0, 1.0)
				if c["t"] <= 0.0:
					# Se escapó sin que lo aprieten
					_quitar(c)
					_error(c["color"])
					if not is_active: return
					continue
		c["nodo"].position.y = c["y"] - RADIO_CIRCULO

func _soltar_circulo() -> void:
	var color: String = COLORES.pick_random()
	var nodo = TextureRect.new()
	nodo.texture = load(CARPETA_ARTE + "circulo_" + color + ".png")
	nodo.pivot_offset = Vector2(RADIO_CIRCULO, RADIO_CIRCULO)
	nodo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var y_inicio = y_aro - DISTANCIA_CAIDA
	nodo.position = Vector2(centro_carril[color] - RADIO_CIRCULO, y_inicio - RADIO_CIRCULO)
	nodo.modulate.a = 0.0
	capa.add_child(nodo)
	create_tween().tween_property(nodo, "modulate:a", 1.0, 0.1) # Aparece suave
	circulos.append({"nodo": nodo, "color": color, "y": y_inicio, "estado": "cayendo", "t": 0.0})

func _quitar(c: Dictionary) -> void:
	circulos.erase(c)
	c["nodo"].queue_free()

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
	# Buscamos el círculo de ese color que esté TOCANDO el aro (aunque sea un borde)
	var mejor = null
	var mejor_distancia = INF
	for c in circulos:
		if c["color"] != color: continue
		var distancia = absf(c["y"] - y_aro)
		if distancia <= RADIO_CIRCULO + RADIO_ARO and distancia < mejor_distancia:
			mejor = c
			mejor_distancia = distancia

	if mejor != null:
		_acierto(mejor)
	else:
		_error(color) # Apretó cuando no había nada en el aro

func _acierto(c: Dictionary) -> void:
	circulos.erase(c)
	# El círculo "explota" un poquito y desaparece
	var nodo: TextureRect = c["nodo"]
	var pop = create_tween().set_parallel(true)
	pop.tween_property(nodo, "scale", Vector2(1.5, 1.5), 0.12)
	pop.tween_property(nodo, "modulate:a", 0.0, 0.12)
	pop.chain().tween_callback(nodo.queue_free)

	_destello_aro(c["color"], Color(1.8, 1.8, 1.8))
	_destello_fondo(FONDO_VERDE)

	aciertos += 1
	barra.value = aciertos
	if aciertos >= aciertos_para_ganar:
		_ganar()
	else:
		_sonar_acierto(aciertos)

func _error(color: String) -> void:
	_destello_aro(color, Color(1.0, 0.3, 0.3))
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
	_desvanecer_circulos()
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
	_desvanecer_circulos()
	var mi_sesion = sesion
	await get_tree().create_timer(0.3).timeout # Para que se vea el último destello rojo
	if mi_sesion == sesion:
		hide()
		qte_finished.emit(false)

# =====================================================================
# EFECTOS
# =====================================================================
# Al terminar, los círculos que quedaban se desvanecen (no se quedan congelados)
func _desvanecer_circulos() -> void:
	for c in circulos:
		var nodo: TextureRect = c["nodo"]
		var t = create_tween()
		t.tween_property(nodo, "modulate:a", 0.0, 0.2)
		t.tween_callback(nodo.queue_free)
	circulos.clear()

func _hundir(color: String) -> void:
	var boton: TextureRect = botones[color]
	if tex_hundido[color]: boton.texture = tex_hundido[color]
	await get_tree().create_timer(0.08).timeout
	boton.texture = tex_normal[color]

func _destello_aro(color: String, tono: Color) -> void:
	var aro: TextureRect = aros[color]
	aro.modulate = tono
	aro.scale = Vector2(1.15, 1.15)
	var t = create_tween().set_parallel(true)
	t.tween_property(aro, "modulate", Color.WHITE, 0.2)
	t.tween_property(aro, "scale", Vector2.ONE, 0.2)

# NUEVO: El fondo oscuro de atrás del cartel se tiñe un instante de verde (acierto) o rojo (error)
# y vuelve solo a su color de siempre. Sigue oscuro, pero se nota el color.
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
