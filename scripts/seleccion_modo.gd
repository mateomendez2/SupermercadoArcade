extends Control
## PANTALLA DE ELEGIR MODO DE JUEGO
## Va entre el menú principal y la pantalla de niveles.
##   1 JUGADOR  - COMPRA -> pantalla de niveles (la de siempre)
##   2 JUGADORES - ROBO  -> pantalla de niveles del modo 2 jugadores (y de ahí, a elegir los ladrones)
## Se mueve con el joystick / flechas / WASD y se elige con cualquier botón.
## Los nodos Titulo y Opciones se pueden mover desde el editor.

const RUTA_NIVELES: String = "res://scenes/ui/seleccion_niveles.tscn"
const RUTA_NIVELES_COOP: String = "res://scenes/ui/seleccion_niveles_coop.tscn"
const CARPETA_LETRAS: String = "res://assets/ui/modo/"
const TituloDibujado = preload("res://scripts/titulo_dibujado.gd") # Títulos con letras dibujadas


# --- TAMAÑOS (se pueden cambiar desde el Inspector) ---
@export var tamano_tarjeta: Vector2 = Vector2(236, 168)
@export var escala_personajes: int = 3 # Qué tan grandes se ven los muñequitos adentro de la tarjeta
@export var margen_abajo_letras: float = 8.0 # Cuánto separa "COMPRA" / "ROBO" del borde de abajo de la tarjeta

# --- COLORES DE CADA TARJETA ---
const COLOR_COMPRA: Color = Color8(247, 122, 18)        # Naranja (como las de los niveles)
const COLOR_COMPRA_BORDE: Color = Color8(92, 30, 8)
const COLOR_ROBO: Color = Color8(54, 104, 252)          # Azul
const COLOR_ROBO_BORDE: Color = Color8(16, 30, 92)
const COLOR_SELECCION: Color = Color.WHITE
const BRILLO_TARJETA: Color = Color(1.12, 1.12, 1.12)
const ALTURA_BOTE: int = 2

# Qué tiene cada tarjeta: letras de arriba, letras de abajo, a dónde va y quiénes aparecen dibujados
var OPCIONES: Array = [
	{"arriba": "1_jugador", "abajo": "compra", "ruta": RUTA_NIVELES,
	 "relleno": COLOR_COMPRA, "borde": COLOR_COMPRA_BORDE, "personajes": ["protagonista"]},
	{"arriba": "2_jugadores", "abajo": "robo", "ruta": RUTA_NIVELES_COOP,
	 "relleno": COLOR_ROBO, "borde": COLOR_ROBO_BORDE,
	 "personajes": ["res://assets/ladrones/ladrona.tres", "res://assets/ladrones/ladron.tres"]},
]

var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")

@onready var opciones: HBoxContainer = %Opciones
@onready var fundido: ColorRect = %Fundido

var tarjetas: Array[Panel] = []
var muniecos: Array = [] # Por tarjeta, la lista de AnimatedSprite2D que tiene adentro
var seleccion: int = 0
var eligiendo: bool = false
var listo_para_tocar: bool = false
var sonido: AudioStreamPlayer
var musica: AudioStreamPlayer
var tween_bote: Tween
var posiciones_originales: Dictionary = {}

func _ready() -> void:
	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	_poner_musica()
	TituloDibujado.poner($Titulo, "res://assets/ui/titulos/elegi_el_modo.png")

	for i in OPCIONES.size():
		var tarjeta = _crear_tarjeta(i)
		opciones.add_child(tarjeta)
		tarjetas.append(tarjeta)

	await get_tree().process_frame # Los contenedores acomodan las tarjetas
	_marcar_seleccion(false)

	fundido.color.a = 1.0
	var t = create_tween()
	t.tween_property(fundido, "color:a", 0.0, 0.25)
	await get_tree().create_timer(0.15).timeout
	listo_para_tocar = true

# =====================================================================
# ARMADO DE LAS TARJETAS
# =====================================================================
func _crear_tarjeta(indice: int) -> Panel:
	var datos: Dictionary = OPCIONES[indice]
	var tarjeta = Panel.new()
	tarjeta.custom_minimum_size = tamano_tarjeta
	tarjeta.mouse_filter = Control.MOUSE_FILTER_STOP
	_estilo(tarjeta, datos["relleno"], datos["borde"])

	# Letras de arriba ("1 JUGADOR") y de abajo ("COMPRA")
	var arriba = _letras(datos["arriba"])
	arriba.position = Vector2(round((tamano_tarjeta.x - arriba.size.x) / 2.0), 10)
	tarjeta.add_child(arriba)
	var abajo = _letras(datos["abajo"])
	abajo.position = Vector2(round((tamano_tarjeta.x - abajo.size.x) / 2.0), tamano_tarjeta.y - abajo.size.y - margen_abajo_letras)
	tarjeta.add_child(abajo)

	# Los muñequitos en el medio
	var lista: Array = []
	var cuantos: int = datos["personajes"].size()
	var ancho_munieco: float = 22.0 * escala_personajes # Lo que ocupa cada uno a lo ancho (el dibujo es de 32, con aire)
	for j in cuantos:
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = _animaciones(datos["personajes"][j])
		sprite.scale = Vector2(escala_personajes, escala_personajes)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var x: float = tamano_tarjeta.x / 2.0 + (j - (cuantos - 1) / 2.0) * ancho_munieco
		sprite.position = Vector2(round(x), round(tamano_tarjeta.y / 2.0 + 2))
		sprite.play("idle_down")
		sprite.frame = j # Que no respiren todos a la vez
		tarjeta.add_child(sprite)
		lista.append(sprite)
	muniecos.append(lista)

	tarjeta.gui_input.connect(_tocado_con_mouse.bind(indice))
	tarjeta.mouse_entered.connect(_mouse_encima.bind(indice))
	return tarjeta

func _letras(nombre: String) -> TextureRect:
	var r = TextureRect.new()
	r.texture = load(CARPETA_LETRAS + nombre + ".png")
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = r.texture.get_size()
	return r

# "protagonista" = la chica del modo de un jugador (sus animaciones están adentro de jugador.tscn)
func _animaciones(cual: String) -> SpriteFrames:
	if cual == "protagonista":
		var jugador = load("res://scenes/characters/jugador.tscn").instantiate()
		var frames: SpriteFrames = jugador.get_node("AnimatedSprite2D").sprite_frames
		jugador.free()
		return frames
	return load(cual)

func _estilo(tarjeta: Panel, relleno: Color, borde: Color) -> void:
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = relleno
	estilo.set_border_width_all(2)
	estilo.border_width_bottom = 5
	estilo.border_color = borde
	estilo.set_corner_radius_all(4)
	estilo.anti_aliasing = false
	tarjeta.add_theme_stylebox_override("panel", estilo)
	tarjeta.set_meta("borde", borde)

# =====================================================================
# MOVERSE Y ELEGIR
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if eligiendo or not listo_para_tocar: return
	var nueva = seleccion
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		nueva = maxi(seleccion - 1, 0)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		nueva = mini(seleccion + 1, tarjetas.size() - 1)
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_elegir()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	if nueva != seleccion:
		seleccion = nueva
		_marcar_seleccion()

func _mouse_encima(indice: int) -> void:
	if eligiendo or indice == seleccion: return
	seleccion = indice
	_marcar_seleccion()

func _tocado_con_mouse(event: InputEvent, indice: int) -> void:
	if eligiendo or not listo_para_tocar: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		seleccion = indice
		_elegir()

func _elegir() -> void:
	eligiendo = true
	_tocar(SONIDO_ELEGIR)
	var tarjeta = tarjetas[seleccion]
	var t = create_tween()
	t.tween_property(tarjeta, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(tarjeta, "modulate", tarjeta.modulate, 0.12)
	t.tween_property(fundido, "color:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file(OPCIONES[seleccion]["ruta"])

# =====================================================================
# EFECTOS
# =====================================================================
# Borde blanco, se ilumina, flota de a un pixel y los muñequitos caminan en el lugar
func _marcar_seleccion(con_sonido: bool = true) -> void:
	if con_sonido: _tocar(SONIDO_MOVER)
	if tween_bote: tween_bote.kill()
	for i in tarjetas.size():
		var tarjeta = tarjetas[i]
		if not posiciones_originales.has(tarjeta):
			posiciones_originales[tarjeta] = tarjeta.position
		tarjeta.position = posiciones_originales[tarjeta]
		var elegida = i == seleccion
		var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
		estilo.border_color = COLOR_SELECCION if elegida else tarjeta.get_meta("borde")
		tarjeta.modulate = BRILLO_TARJETA if elegida else Color.WHITE
		for sprite in muniecos[i]:
			sprite.play("walk_down" if elegida else "idle_down")
	var actual = tarjetas[seleccion]
	var y_original: float = posiciones_originales[actual].y
	tween_bote = create_tween().set_loops()
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), 0.0, ALTURA_BOTE, 0.35)
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), float(ALTURA_BOTE), 0.0, 0.35)

func _tocar(sonido_nuevo: AudioStream) -> void:
	sonido.stream = sonido_nuevo
	sonido.play()

# La música del menú es una sola para todas las pantallas (vive en GameManager), así no se corta ni se atrasa
func _poner_musica() -> void:
	musica = GameManager.musica_menu()
