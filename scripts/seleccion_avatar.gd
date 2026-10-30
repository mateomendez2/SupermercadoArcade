extends Control
## PANTALLA DE ELEGIR PERSONAJE (modo 1 JUGADOR - COMPRA)
## Aparece después de tocar un nivel en la pantalla de niveles, y antes de jugar.
## Se elige entre la chica y el chico (los dos con la misma ropa).
## Se mueve con el joystick / flechas / WASD y se elige con cualquier botón.
## Los personajes salen de GameManager.AVATARES (ahí se agregan o se cambian).
## Los nodos Titulo, Nivel y Personajes se pueden mover desde el editor.

const RUTA_JUEGO: String = "res://scenes/ui/juego.tscn"
const RUTA_NIVELES: String = "res://scenes/ui/seleccion_niveles.tscn" # El botón "VOLVER" vuelve a elegir nivel
const BotonVolver = preload("res://scripts/boton_volver.gd")
@export var boton_volver_y: float = 316.0 # Altura del botón "VOLVER" (si se arma solo)
var boton_volver: Button
var en_volver: bool = false # true = está elegido "VOLVER" (no un personaje)
var y_volver: float = 0.0
const CARPETA_NUMEROS: String = "res://assets/ui/seleccion/"
const TituloDibujado = preload("res://scripts/titulo_dibujado.gd") # Títulos con letras dibujadas


# --- TAMAÑOS (se pueden cambiar desde el Inspector) ---
@export var tamano_tarjeta: Vector2 = Vector2(150, 172)
@export var escala_personajes: int = 4

# --- COLORES (como las tarjetas de los niveles) ---
const COLOR_TARJETA: Color = Color8(247, 122, 18)
const COLOR_TARJETA_BORDE: Color = Color8(92, 30, 8)
const COLOR_SELECCION: Color = Color.WHITE
const BRILLO_TARJETA: Color = Color(1.12, 1.12, 1.12)
const ALTURA_BOTE: int = 2

var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")

@onready var fila: HBoxContainer = %Personajes
@onready var nivel: Control = %Nivel
@onready var fundido: ColorRect = %Fundido

var tarjetas: Array[Panel] = []
var sprites: Array[AnimatedSprite2D] = []
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
	TituloDibujado.poner($Titulo, "res://assets/ui/titulos/elegi_tu_personaje.png")

	for i in GameManager.AVATARES.size():
		var tarjeta = _crear_tarjeta(i)
		fila.add_child(tarjeta)
		tarjetas.append(tarjeta)

	# Arranca en el que se eligió la última vez
	seleccion = clampi(GameManager.avatar_elegido, 0, tarjetas.size() - 1)
	_armar_boton_volver()
	await get_tree().process_frame # Los contenedores acomodan las tarjetas
	y_volver = boton_volver.position.y
	# (El "NIVEL X" debajo del título ya no se muestra: el nodo Nivel queda vacío)
	_marcar_seleccion(false)

	fundido.color.a = 1.0
	var t = create_tween()
	t.tween_property(fundido, "color:a", 0.0, 0.25)
	await get_tree().create_timer(0.15).timeout
	listo_para_tocar = true

# "NIVEL X" chiquito debajo del título, para acordarse qué nivel se tocó
func _poner_numero_de_nivel() -> void:
	var piezas: Array[String] = ["nivel"]
	for cifra in str(GameManager.nivel_elegido + 1):
		piezas.append("num_" + cifra)
	var x: float = 0.0
	var alto: float = 0.0
	for i in piezas.size():
		var tex: Texture2D = load(CARPETA_NUMEROS + piezas[i] + ".png")
		var pieza = TextureRect.new()
		pieza.texture = tex
		pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pieza.position = Vector2(x, 0)
		nivel.add_child(pieza)
		x += tex.get_width() + (4 if i == 0 else 0)
		alto = maxf(alto, tex.get_height())
	# Centrado dentro del nodo Nivel
	for pieza in nivel.get_children():
		pieza.position.x += round((nivel.size.x - x) / 2.0)
		pieza.position.y += round((nivel.size.y - alto) / 2.0)

# =====================================================================
# ARMADO DE LAS TARJETAS
# =====================================================================
func _crear_tarjeta(indice: int) -> Panel:
	var tarjeta = Panel.new()
	tarjeta.custom_minimum_size = tamano_tarjeta
	tarjeta.mouse_filter = Control.MOUSE_FILTER_STOP
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = COLOR_TARJETA
	estilo.set_border_width_all(2)
	estilo.border_width_bottom = 5
	estilo.border_color = COLOR_TARJETA_BORDE
	estilo.set_corner_radius_all(4)
	estilo.anti_aliasing = false
	tarjeta.add_theme_stylebox_override("panel", estilo)

	var sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _animaciones(indice)
	sprite.scale = Vector2(escala_personajes, escala_personajes)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(round(tamano_tarjeta.x / 2.0), round(tamano_tarjeta.y / 2.0 - 4))
	sprite.play("idle_down")
	sprite.frame = indice
	tarjeta.add_child(sprite)
	sprites.append(sprite)

	tarjeta.gui_input.connect(_tocado_con_mouse.bind(indice))
	tarjeta.mouse_entered.connect(_mouse_encima.bind(indice))
	return tarjeta

# "" = la chica de siempre (sus animaciones están adentro de jugador.tscn)
func _animaciones(indice: int) -> SpriteFrames:
	var ruta: String = GameManager.AVATARES[indice]
	if ruta == "":
		var jugador = load("res://scenes/characters/jugador.tscn").instantiate()
		var frames: SpriteFrames = jugador.get_node("AnimatedSprite2D").sprite_frames
		jugador.free()
		return frames
	return load(ruta)

# =====================================================================
# MOVERSE Y ELEGIR
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if eligiendo or not listo_para_tocar: return
	# Bajando se llega al botón "VOLVER"; subiendo se vuelve a los personajes
	if event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		if not en_volver:
			en_volver = true
			_marcar_seleccion()
		return
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		if en_volver:
			en_volver = false
			_marcar_seleccion()
		return
	if en_volver:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_volver()
		return
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
	if eligiendo or (indice == seleccion and not en_volver): return
	seleccion = indice
	en_volver = false
	_marcar_seleccion()

func _tocado_con_mouse(event: InputEvent, indice: int) -> void:
	if eligiendo or not listo_para_tocar: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		seleccion = indice
		en_volver = false
		_elegir()

func _elegir() -> void:
	eligiendo = true
	_tocar(SONIDO_ELEGIR)
	GameManager.avatar_elegido = seleccion
	if tween_bote: tween_bote.kill()
	sprites[seleccion].play("pickup_down") # Festeja agarrando algo
	var tarjeta = tarjetas[seleccion]
	var t = create_tween()
	t.tween_property(tarjeta, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(tarjeta, "modulate", tarjeta.modulate, 0.12)
	t.tween_interval(0.3)
	t.tween_property(fundido, "color:a", 1.0, 0.3)
	t.parallel().tween_callback(GameManager.apagar_musica_menu.bind(0.3)) # Se apaga junto con el fundido
	await t.finished
	get_tree().change_scene_to_file(RUTA_JUEGO)

# =====================================================================
# EFECTOS (igual que en la pantalla de modo)
# =====================================================================
func _marcar_seleccion(con_sonido: bool = true) -> void:
	if con_sonido: _tocar(SONIDO_MOVER)
	if tween_bote: tween_bote.kill()
	boton_volver.position.y = y_volver
	boton_volver.modulate = BotonVolver.ILUMINADO if en_volver else Color.WHITE
	for i in tarjetas.size():
		var tarjeta = tarjetas[i]
		if not posiciones_originales.has(tarjeta):
			posiciones_originales[tarjeta] = tarjeta.position
		tarjeta.position = posiciones_originales[tarjeta]
		var elegida = i == seleccion and not en_volver
		var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
		estilo.border_color = COLOR_SELECCION if elegida else COLOR_TARJETA_BORDE
		tarjeta.modulate = BRILLO_TARJETA if elegida else Color.WHITE
		sprites[i].play("walk_down" if elegida else "idle_down")
	var actual: Control = boton_volver if en_volver else tarjetas[seleccion]
	var y_original: float = y_volver if en_volver else posiciones_originales[actual].y
	tween_bote = create_tween().set_loops()
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), 0.0, ALTURA_BOTE, 0.35)
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), float(ALTURA_BOTE), 0.0, 0.35)

# =====================================================================
# BOTÓN "VOLVER" (vuelve a la pantalla de niveles, con la música de corrido)
# =====================================================================
func _armar_boton_volver() -> void:
	boton_volver = BotonVolver.armar(self, fundido, boton_volver_y)
	boton_volver.mouse_entered.connect(func():
		if eligiendo or en_volver: return
		en_volver = true
		_marcar_seleccion())
	boton_volver.pressed.connect(func():
		if eligiendo or not listo_para_tocar: return
		_volver())

func _volver() -> void:
	eligiendo = true
	en_volver = true
	_tocar(SONIDO_ELEGIR)
	if tween_bote: tween_bote.kill()
	var t = create_tween()
	t.tween_property(boton_volver, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(boton_volver, "modulate", BotonVolver.ILUMINADO, 0.12)
	t.tween_property(fundido, "color:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file(RUTA_NIVELES)

func _tocar(sonido_nuevo: AudioStream) -> void:
	sonido.stream = sonido_nuevo
	sonido.play()

# La música del menú es una sola para todas las pantallas (vive en GameManager), así no se corta ni se atrasa
func _poner_musica() -> void:
	musica = GameManager.musica_menu()
