extends Control
## CORAZONES DE LOS MINIJUEGOS
## Fila de corazones arriba del cartel del minijuego (al doble de tamaño, para que se noten).
## Cada error apaga un corazón (se pone gris), empezando por el de arriba.
## Se puede usar en cualquier QTE:
##   var corazones = CorazonesQTE.new()
##   cartel.add_child(corazones)
##   corazones.armar(5)        -> al empezar el minijuego
##   corazones.perder_vida()   -> en cada error

const TEX_LLENO = preload("res://assets/ui/qte/corazon.png")
const TEX_VACIO = preload("res://assets/ui/qte/corazon_gris.png")
const RUTA_SONIDO_VIDA_PERDIDA: String = "res://assets/audio/VidaPerdida.wav" # El "bup-buuu" de error
const VOLUMEN_VIDA_PERDIDA: float = -5.0
const ESCALA: float = 2.0          # Tamaño de los corazones (2 = el doble del dibujo)
const SEPARACION: float = 2.0      # Espacio entre corazón y corazón (en pixeles del dibujo)
const DISTANCIA_CARTEL: float = 4.0 # Cuánto se separa del borde de arriba del cartel

var corazones: Array[TextureRect] = []
var vidas: int = 0
var sonido: AudioStreamPlayer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sonido = AudioStreamPlayer.new()
	sonido.stream = load(RUTA_SONIDO_VIDA_PERDIDA)
	sonido.volume_db = VOLUMEN_VIDA_PERDIDA
	add_child(sonido)

# Crea los corazones (todos llenos) y los centra al costado del cartel
func armar(cantidad: int) -> void:
	for c in corazones:
		c.queue_free()
	corazones.clear()
	vidas = cantidad

	var cartel = get_parent() as Control
	var ancho_corazon: float = TEX_LLENO.get_width()
	var alto_corazon: float = TEX_LLENO.get_height()
	var ancho_total: float = (cantidad * ancho_corazon + (cantidad - 1) * SEPARACION) * ESCALA
	# Centrados arriba del cartel
	scale = Vector2(ESCALA, ESCALA)
	position = Vector2(round((cartel.size.x - ancho_total) / 2.0), -alto_corazon * ESCALA - DISTANCIA_CARTEL)

	for i in cantidad:
		var c = TextureRect.new()
		c.texture = TEX_LLENO
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.position = Vector2(i * (ancho_corazon + SEPARACION), 0)
		c.pivot_offset = TEX_LLENO.get_size() / 2.0
		add_child(c)
		corazones.append(c)

# Apaga el primer corazón lleno (de izquierda a derecha), con un saltito
func perder_vida() -> void:
	if vidas <= 0: return
	var c: TextureRect = corazones[corazones.size() - vidas]
	vidas -= 1
	sonido.play()
	c.texture = TEX_VACIO
	c.modulate = Color(2.0, 2.0, 2.0) # Destello blanco
	c.scale = Vector2(1.4, 1.4)
	var t = create_tween().set_parallel(true)
	t.tween_property(c, "modulate", Color.WHITE, 0.25)
	t.tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sacudir()

# =====================================================================
# SACUDÓN AL EQUIVOCARSE
# Tiembla el cartel del minijuego (con todo lo que tiene adentro) y también la cámara del juego
# =====================================================================
const FUERZA_SACUDON: float = 4.0   # Cuántos pixeles se mueve como máximo
const TIEMPO_SACUDON: float = 0.28  # Cuánto dura
const PASOS_SACUDON: int = 8        # Cuántos "golpecitos" hace en ese tiempo
var tween_sacudon: Tween
var posiciones_base: Dictionary = {}  # Dónde estaba cada cosa antes de sacudirse
var camara_sacudida: Camera2D
var offset_camara_base: Vector2

func _sacudir() -> void:
	_frenar_sacudon()
	var cartel = get_parent() as Control
	if cartel == null: return
	var minijuego = cartel.get_parent() as Control
	# Lo que se sacude: todo el minijuego menos el fondo oscuro que tapa la pantalla
	var partes: Array = []
	if minijuego:
		for hijo in minijuego.get_children():
			if hijo is Control and not (hijo is ColorRect and hijo.size.x >= minijuego.size.x * 0.9 and hijo.size.y >= minijuego.size.y * 0.9):
				partes.append(hijo)
	else:
		partes.append(cartel)
	for p in partes:
		posiciones_base[p] = p.position
	camara_sacudida = get_viewport().get_camera_2d()
	# Modo 2 jugadores: el minijuego dice qué cámara sacudir (la de la mitad de ese jugador)
	if minijuego and minijuego.has_meta("camara_sacudir"):
		camara_sacudida = minijuego.get_meta("camara_sacudir")
	if camara_sacudida:
		offset_camara_base = camara_sacudida.offset

	tween_sacudon = create_tween()
	for i in PASOS_SACUDON:
		var fuerza: float = FUERZA_SACUDON * (1.0 - float(i) / PASOS_SACUDON) # Va perdiendo fuerza
		var desvio := Vector2(fuerza if i % 2 == 0 else -fuerza, randf_range(-fuerza, fuerza) * 0.5).round()
		tween_sacudon.tween_callback(_mover_todo.bind(desvio))
		tween_sacudon.tween_interval(TIEMPO_SACUDON / PASOS_SACUDON)
	tween_sacudon.tween_callback(_frenar_sacudon)

func _mover_todo(desvio: Vector2) -> void:
	for p in posiciones_base:
		if is_instance_valid(p): p.position = posiciones_base[p] + desvio
	if is_instance_valid(camara_sacudida):
		camara_sacudida.offset = offset_camara_base + desvio

# Devuelve todo a su lugar exacto
func _frenar_sacudon() -> void:
	if tween_sacudon and tween_sacudon.is_valid(): tween_sacudon.kill()
	for p in posiciones_base:
		if is_instance_valid(p): p.position = posiciones_base[p]
	posiciones_base.clear()
	if is_instance_valid(camara_sacudida):
		camara_sacudida.offset = offset_camara_base
	camara_sacudida = null
