extends Control
## MINIJUEGO "¿DÓNDE QUEDÓ?" (el juego de los vasitos, con cajas)
## El producto de la góndola aparece en el piso, debajo de una de las tres cajas.
## Las cajas bajan, lo tapan y se mezclan (una pasa por adelante y la otra por atrás).
## Cuando se quedan quietas, apretás el botón que está abajo de la caja donde quedó.
## - Lo encontrás una vez y ganás (no tiene barra verde).
## - Si le pifiás, perdés un corazón, te muestra dónde estaba y se vuelve a mezclar (un poco más rápido).
## - Las cajas son todas iguales a propósito: si fueran de colores, alcanzaría con acordarse del color.

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

const Confites = preload("res://scripts/confites.gd")
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
const COLORES: Array[String] = ["azul", "rojo", "amarillo"]
const TEX_CAJA: Texture2D = preload("res://assets/caja.png")
const HOJA_PRODUCTOS: Texture2D = preload("res://assets/ObjetosLista.png") # Por si la góndola no tiene producto
const RUTA_SONIDO_MEZCLA: String = "res://assets/audio/CajasMezcla.wav"

# --- REGLAS (se pueden cambiar desde el Inspector) ---
@export var errores_maximos: int = 3
@export var cambios: int = 6                 # Cuántas veces se cambian de lugar en la primera mezcla
@export var duracion_cambio: float = 0.30    # Lo que tarda cada cambio (menos = más rápido)
@export var cambios_extra_por_error: int = 1 # Cada vez que le errás, la mezcla siguiente tiene más cambios...
@export var recorte_por_error: float = 0.03  # ...y es un poco más rápida
@export var duracion_minima: float = 0.18
@export var tiempo_mirando: float = 0.8      # Lo que se ve el producto antes de que bajen las cajas

# --- AJUSTES FINOS (en pixeles del cartel) ---
const Y_PISO: float = 114.0       # Donde apoyan las cajas (justo arriba de los botones)
const Y_CAJA_ABAJO: float = 98.0  # Centro de la caja apoyada
const Y_CAJA_ARRIBA: float = 66.0 # Centro de la caja levantada
const PASA_ADELANTE: float = 4.0  # Cuánto baja la caja que cruza por adelante
const PASA_ATRAS: float = 9.0     # Cuánto sube la que cruza por atrás
const CENTRO_DIBUJO_BOTON: float = 17.0

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
var errores: int = 0
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error
var estado: String = "pausa" # "pausa" (mirando o mezclando) o "eligiendo" (esperando que apriete)

var capa: Control
var sombras: Node2D
var cajas: Array[Sprite2D] = []
var lugar_de: Dictionary = {} # caja -> lugar (0 = azul, 1 = rojo, 2 = amarillo)
var caja_con_producto: Sprite2D
var producto: Sprite2D
var animaciones: Array[Tween] = []
var corazones
var sonido_mezcla: AudioStreamPlayer

func _ready() -> void:
	hide()
	for color in COLORES:
		tex_normal[color] = botones[color].texture
	tex_hundido = {"azul": tex_azul_hundido, "rojo": tex_rojo_hundido, "amarillo": tex_amarillo_hundido}
	color_fondo_normal = fondo_oscuro.color
	_armar()
	corazones = CorazonesQTE.new()
	cartel.add_child(corazones)
	sonido_mezcla = AudioStreamPlayer.new()
	sonido_mezcla.volume_db = -12.0
	if ResourceLoader.exists(RUTA_SONIDO_MEZCLA): sonido_mezcla.stream = load(RUTA_SONIDO_MEZCLA)
	add_child(sonido_mezcla)
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

func _armar() -> void:
	capa = Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartel.add_child(capa)
	# Sombras de las cajas en el piso (van abajo de todo)
	sombras = Node2D.new()
	capa.add_child(sombras)
	sombras.draw.connect(_dibujar_sombras)
	producto = Sprite2D.new()
	capa.add_child(producto)
	for i in COLORES.size():
		var caja := Sprite2D.new()
		caja.texture = TEX_CAJA
		capa.add_child(caja)
		cajas.append(caja)

func _x_lugar(i: int) -> float:
	return botones[COLORES[i]].position.x + CENTRO_DIBUJO_BOTON

# =====================================================================
# ARRANQUE
# =====================================================================
func start_qte() -> void:
	IconosMando.aplicar(self)
	sesion += 1
	_cortar_animaciones()
	errores = 0
	intentos_restantes = errores_maximos
	estado = "pausa"
	for color in COLORES:
		botones[color].texture = tex_normal[color]
		botones[color].modulate = Color.WHITE
	if tween_fondo: tween_fondo.kill()
	fondo_oscuro.color = color_fondo_normal
	corazones.armar(errores_maximos)
	producto.texture = _icono_del_producto()
	producto.hide()
	for i in cajas.size():
		cajas[i].position = Vector2(_x_lugar(i), Y_CAJA_ARRIBA)
		cajas[i].z_index = 0
		cajas[i].modulate = Color.WHITE
		lugar_de[cajas[i]] = i

	show()
	await get_tree().process_frame
	is_active = true
	_ronda(sesion, 0.35)

# El producto que se está por llevar (el de la góndola). Si no hay, uno cualquiera de la hoja.
func _icono_del_producto() -> Texture2D:
	var gondola = GameManager.gondolas_coop.get(prefijo) if prefijo != "" else GameManager.gondola_actual
	if gondola and is_instance_valid(gondola) and gondola.get("item_content") and gondola.item_content.icon:
		return gondola.item_content.icon
	var a := AtlasTexture.new()
	a.atlas = HOJA_PRODUCTOS
	a.region = Rect2(16 * (randi() % 3), 16 * (randi() % 5), 16, 16)
	return a

func _sigue(mi_sesion: int) -> bool:
	return mi_sesion == sesion and is_active

# =====================================================================
# UNA RONDA: se ve el producto -> bajan las cajas -> se mezclan -> elegís
# =====================================================================
func _ronda(mi_sesion: int, respiro: float) -> void:
	await get_tree().create_timer(respiro).timeout
	if not _sigue(mi_sesion): return
	# El producto aparece abajo de una caja al azar
	var lugar: int = randi() % 3
	for c in cajas:
		if lugar_de[c] == lugar: caja_con_producto = c
	producto.position = Vector2(_x_lugar(lugar), Y_PISO - 8)
	producto.modulate.a = 1.0
	producto.scale = Vector2.ZERO
	producto.show()
	var pop = _animar()
	pop.tween_property(producto, "scale", Vector2(1.3, 1.3), 0.1)
	pop.tween_property(producto, "scale", Vector2.ONE, 0.08)
	await get_tree().create_timer(tiempo_mirando).timeout
	if not _sigue(mi_sesion): return

	# Bajan las cajas y lo tapan
	var baja = _animar().set_parallel(true)
	for c in cajas:
		baja.tween_property(c, "position:y", Y_CAJA_ABAJO, 0.18).set_ease(Tween.EASE_IN)
	await baja.finished
	if not _sigue(mi_sesion): return
	producto.hide()
	await get_tree().create_timer(0.3).timeout
	if not _sigue(mi_sesion): return

	# Se mezclan (cada error suma cambios y los hace más rápidos)
	var cantidad: int = cambios + errores * cambios_extra_por_error
	var duracion: float = maxf(duracion_minima, duracion_cambio - errores * recorte_por_error)
	var anterior := Vector2i(-1, -1)
	for k in cantidad:
		var par := Vector2i.ZERO
		for intento in 10: # Que no repita el mismo cambio dos veces seguidas
			par.x = randi() % 3
			par.y = (par.x + 1 + randi() % 2) % 3
			if par != anterior and Vector2i(par.y, par.x) != anterior: break
		anterior = par
		await _cambiar(par.x, par.y, duracion)
		if not _sigue(mi_sesion): return

	estado = "eligiendo"

# Dos cajas cambian de lugar: una cruza por adelante y la otra por atrás
func _cambiar(a: int, b: int, duracion: float) -> void:
	var ca: Sprite2D
	var cb: Sprite2D
	for c in cajas:
		if lugar_de[c] == a: ca = c
		if lugar_de[c] == b: cb = c
	ca.z_index = 1
	cb.z_index = 0
	var xa: float = _x_lugar(a)
	var xb: float = _x_lugar(b)
	if sonido_mezcla.stream:
		sonido_mezcla.pitch_scale = randf_range(0.9, 1.15)
		sonido_mezcla.play()
	var t = _animar()
	t.tween_method(func(k: float):
		var s: float = k * k * (3.0 - 2.0 * k) # Arranca y frena suave
		ca.position = Vector2(round(lerpf(xa, xb, s)), round(Y_CAJA_ABAJO + sin(s * PI) * PASA_ADELANTE))
		cb.position = Vector2(round(lerpf(xb, xa, s)), round(Y_CAJA_ABAJO - sin(s * PI) * PASA_ATRAS)), 0.0, 1.0, duracion)
	await t.finished
	lugar_de[ca] = b
	lugar_de[cb] = a
	ca.z_index = 0

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
	if estado != "eligiendo": return # Mientras se mezclan no cuenta
	estado = "pausa"
	_elegir(COLORES.find(color))

func _elegir(lugar: int) -> void:
	var mi_sesion = sesion
	var elegida: Sprite2D
	for c in cajas:
		if lugar_de[c] == lugar: elegida = c
	var donde: int = lugar_de[caja_con_producto]
	producto.position = Vector2(_x_lugar(donde), Y_PISO - 8)
	if elegida == caja_con_producto:
		producto.show()
		await _levantar([elegida])
		if not _sigue(mi_sesion): return
		_ganar()
		return

	# Le pifió: la caja vacía se levanta, perdés un corazón y se muestra dónde estaba
	await _levantar([elegida])
	if not _sigue(mi_sesion): return
	_destello_fondo(FONDO_ROJO)
	errores += 1
	intentos_restantes -= 1
	corazones.perder_vida()
	print("¡Fallaste! Te quedan: ", intentos_restantes, " intentos.")
	await get_tree().create_timer(0.35).timeout
	if not _sigue(mi_sesion): return
	producto.show()
	await _levantar([caja_con_producto])
	if not _sigue(mi_sesion): return
	if intentos_restantes <= 0:
		_perder()
		return
	# Otra vuelta: se levanta la que quedaba, el producto se va y se vuelve a empezar
	await get_tree().create_timer(0.6).timeout
	if not _sigue(mi_sesion): return
	await _levantar(cajas.filter(func(c): return c.position.y > Y_CAJA_ARRIBA + 1.0))
	if not _sigue(mi_sesion): return
	var fuera = _animar()
	fuera.tween_property(producto, "modulate:a", 0.0, 0.15)
	await fuera.finished
	if not _sigue(mi_sesion): return
	producto.hide()
	_ronda(mi_sesion, 0.2)

func _levantar(lista: Array) -> void:
	if lista.is_empty(): return
	var t = _animar().set_parallel(true)
	for c in lista:
		t.tween_property(c, "position:y", Y_CAJA_ARRIBA, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await t.finished

# =====================================================================
# FINALES
# =====================================================================
func _ganar() -> void:
	is_active = false
	_destello_fondo(FONDO_VERDE)
	# El producto pega un saltito de alegría
	var salto = _animar()
	salto.tween_property(producto, "position:y", Y_PISO - 16, 0.12).set_ease(Tween.EASE_OUT)
	salto.tween_property(producto, "position:y", Y_PISO - 8, 0.12).set_ease(Tween.EASE_IN)
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
	await get_tree().create_timer(0.45).timeout # Para que se vea dónde estaba
	if mi_sesion == sesion:
		hide()
		qte_finished.emit(false)

# =====================================================================
# EFECTOS
# =====================================================================
func _animar() -> Tween:
	var t = create_tween()
	animaciones.append(t)
	return t

func _cortar_animaciones() -> void:
	for t in animaciones:
		if t and t.is_valid(): t.kill()
	animaciones.clear()

func _process(_delta: float) -> void:
	if visible: sombras.queue_redraw()

# La sombra se achica y se aclara cuando la caja está levantada
func _dibujar_sombras() -> void:
	for c in cajas:
		var alto: float = clampf((Y_CAJA_ABAJO - c.position.y) / (Y_CAJA_ABAJO - Y_CAJA_ARRIBA), 0.0, 1.0)
		var ancho: float = round(lerpf(28.0, 18.0, alto))
		sombras.draw_rect(Rect2(round(c.position.x - ancho / 2.0), Y_PISO - 2, ancho, 3), Color(0, 0, 0, lerpf(0.28, 0.12, alto)))

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
