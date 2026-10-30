extends Control
## PANTALLA DE SELECCIÓN DE NIVELES
## Va entre la pantalla de modo y la de elegir personaje. Arma una tarjeta por cada nivel
## (los de GameManager.RUTAS_NIVELES), en dos columnas.
## La usan los dos modos: con "cooperativo" prendido (seleccion_niveles_coop.tscn) muestra los niveles
## del modo 2 JUGADORES (GameManager.RUTAS_NIVELES_COOP), en azul, y después va a elegir los ladrones.
## - Los niveles abiertos se ven en color; los bloqueados, en gris con un candado.
## - Se mueve con el joystick / flechas / WASD y se elige con cualquier botón.
## Los nodos Titulo y Grilla se pueden mover desde el editor.

const RUTA_JUEGO: String = "res://scenes/ui/juego.tscn"
const RUTA_PERSONAJE: String = "res://scenes/ui/seleccion_avatar.tscn" # Después de elegir el nivel, se elige con quién jugar
const RUTA_LADRONES: String = "res://scenes/ui/seleccion_personajes.tscn" # (en el modo 2 jugadores, se eligen los ladrones)
const RUTA_MODO: String = "res://scenes/ui/seleccion_modo.tscn" # El botón "VOLVER" lleva a elegir el modo
const RUTA_MENU: String = "res://scenes/ui/menu_principal.tscn"

@export var cooperativo: bool = false # true = niveles del modo 2 JUGADORES (ROBO)

# --- TAMAÑOS (se pueden cambiar desde el Inspector) ---
@export var tamano_tarjeta: Vector2 = Vector2(168, 64)
@export var separacion_numero: int = 4 # Espacio entre "NIVEL" y el número

# --- COLORES ---
const COLOR_ABIERTO: Color = Color8(247, 122, 18)        # Naranja
const COLOR_ABIERTO_BORDE: Color = Color8(92, 30, 8)
const COLOR_ABIERTO_COOP: Color = Color8(54, 104, 252)   # Azul (modo 2 jugadores, como su tarjeta en la pantalla de modo)
const COLOR_ABIERTO_COOP_BORDE: Color = Color8(16, 30, 92)
const COLOR_BLOQUEADO: Color = Color8(118, 118, 130)     # Gris
const COLOR_BLOQUEADO_BORDE: Color = Color8(44, 44, 52)
const COLOR_SELECCION: Color = Color.WHITE               # Borde de la tarjeta de nivel elegida
const BRILLO_TARJETA: Color = Color(1.12, 1.12, 1.12)    # Cuánto se ilumina la tarjeta elegida

# Las letras de "NIVEL" y los números son dibujitos (misma letra que los carteles "NIVEL X", en chiquito)
const CARPETA_LETRAS: String = "res://assets/ui/seleccion/"
const TituloDibujado = preload("res://scripts/titulo_dibujado.gd") # Títulos con letras dibujadas


# (Se cargan al abrir la pantalla)
var TEX_CANDADO: Texture2D = load("res://assets/ui/candado.png")
var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")
var SONIDO_BLOQUEADO: AudioStream = load("res://assets/audio/VidaPerdida.wav")

@onready var grilla: GridContainer = %Grilla
@onready var fundido: ColorRect = %Fundido

var tarjetas: Array[Panel] = []   # Una por nivel
var seleccion: int = 0
var eligiendo: bool = false        # Cuando ya se eligió, no se puede mover más
var listo_para_tocar: bool = false # Un respiro al entrar, para que el botón del menú no "rebote"
var sonido: AudioStreamPlayer
var musica: AudioStreamPlayer
var tween_bote: Tween

# --- BOTÓN "VOLVER" (debajo de las tarjetas; vuelve a la pantalla de elegir modo) ---
# Mismo estilo que los botones de ganaste/perdiste: amarillo con letra y borde naranja.
# Se llega bajando desde la última fila de tarjetas. Si en la escena hay un nodo "BotonVolver"
# (un Button), se usa ese (así se puede mover desde el editor); si no, se arma solo.
@export var boton_volver_y: float = 330.0 # Altura en la pantalla (si se arma solo)
const VOLVER_ILUMINADO: Color = preload("res://scripts/boton_volver.gd").ILUMINADO
var boton_volver: Button
var en_volver: bool = false # true = está elegido el botón "VOLVER" (no una tarjeta)
var y_volver: float = 0.0

func _ready() -> void:
	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	_poner_musica()
	TituloDibujado.poner($Titulo, "res://assets/ui/titulos/elegi_un_nivel.png")
	if cooperativo: preload("res://scripts/controles_coop.gd").armar() # Las teclas de cada jugador (el J1 elige con C/V/B)

	# Una tarjeta por nivel
	for i in _cantidad():
		var tarjeta = _crear_tarjeta(i)
		grilla.add_child(tarjeta)
		tarjetas.append(tarjeta)

	# Arrancamos parados en el último nivel jugado (o el primero)
	seleccion = clampi(_nivel_elegido(), 0, _cantidad() - 1)
	if not _abierto(seleccion):
		seleccion = 0
	_armar_boton_volver()
	await get_tree().process_frame # Los contenedores acomodan las tarjetas
	y_volver = boton_volver.position.y
	_marcar_seleccion(false)

	# Entrada con fundido desde negro
	fundido.color.a = 1.0
	var t = create_tween()
	t.tween_property(fundido, "color:a", 0.0, 0.25)
	await get_tree().create_timer(0.15).timeout
	listo_para_tocar = true

# =====================================================================
# DATOS DE CADA MODO (1 jugador o 2 jugadores)
# =====================================================================
func _cantidad() -> int:
	if cooperativo:
		return maxi(GameManager.LUGARES_NIVELES_COOP, GameManager.RUTAS_NIVELES_COOP.size())
	return GameManager.RUTAS_NIVELES.size()

func _abierto(indice: int) -> bool:
	if cooperativo: return GameManager.esta_desbloqueado_coop(indice)
	return GameManager.esta_desbloqueado(indice)

func _nivel_elegido() -> int:
	return GameManager.nivel_coop_elegido if cooperativo else GameManager.nivel_elegido

# =====================================================================
# ARMADO DE LAS TARJETAS
# =====================================================================
func _crear_tarjeta(indice: int) -> Panel:
	var abierto = _abierto(indice)
	var tarjeta = Panel.new()
	tarjeta.custom_minimum_size = tamano_tarjeta
	tarjeta.mouse_filter = Control.MOUSE_FILTER_STOP
	if abierto and cooperativo:
		_estilo(tarjeta, COLOR_ABIERTO_COOP, COLOR_ABIERTO_COOP_BORDE)
	elif abierto:
		_estilo(tarjeta, COLOR_ABIERTO, COLOR_ABIERTO_BORDE)
	else:
		_estilo(tarjeta, COLOR_BLOQUEADO, COLOR_BLOQUEADO_BORDE)

	# Candado arriba y "NIVEL X" chiquito en gris abajo (bloqueadas),
	# o "NIVEL X" grande y en color en el medio (abiertas)
	if abierto:
		var texto = _armar_texto(indice + 1, "")
		texto.position = ((tamano_tarjeta - texto.size) / 2.0).round() + Vector2(0, -2)
		tarjeta.add_child(texto)
	else:
		var candado = TextureRect.new()
		candado.name = "Candado"
		candado.texture = TEX_CANDADO
		candado.scale = Vector2(2, 2)
		candado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		candado.position = Vector2(round((tamano_tarjeta.x - TEX_CANDADO.get_width() * 2.0) / 2.0), 5)
		candado.set_meta("x", candado.position.x) # Para que el sacudón siempre vuelva al mismo lugar
		tarjeta.add_child(candado)
		var texto = _armar_texto(indice + 1, "_gris")
		texto.position = Vector2(round((tamano_tarjeta.x - texto.size.x) / 2.0), candado.position.y + TEX_CANDADO.get_height() * 2.0 + 2)
		tarjeta.add_child(texto)

	tarjeta.gui_input.connect(_tocado_con_mouse.bind(indice))
	tarjeta.mouse_entered.connect(_mouse_encima.bind(indice))
	return tarjeta

# Junta los dibujitos: "NIVEL" + cada cifra del número (sirve para el nivel 10, 11...)
func _armar_texto(numero: int, version: String) -> Control:
	var caja = Control.new()
	caja.name = "Texto"
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var piezas: Array[String] = ["nivel"]
	for cifra in str(numero):
		piezas.append("num_" + cifra)
	var x: float = 0.0
	var alto: float = 0.0
	for i in piezas.size():
		var tex: Texture2D = load(CARPETA_LETRAS + piezas[i] + version + ".png")
		var pieza = TextureRect.new()
		pieza.texture = tex
		pieza.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pieza.position = Vector2(x, 0)
		caja.add_child(pieza)
		x += tex.get_width()
		if i == 0:
			x += separacion_numero if version == "" else separacion_numero - 1
		alto = maxf(alto, tex.get_height())
	caja.size = Vector2(x, alto)
	return caja

# Fondo de color, borde oscuro y una "base" abajo para que parezca un botón
func _estilo(tarjeta: Panel, relleno: Color, borde: Color) -> void:
	var estilo = StyleBoxFlat.new()
	estilo.bg_color = relleno
	estilo.set_border_width_all(2)
	estilo.border_width_bottom = 5
	estilo.border_color = borde
	estilo.set_corner_radius_all(4)
	estilo.anti_aliasing = false # Bordes pixelados, como el resto del juego
	tarjeta.add_theme_stylebox_override("panel", estilo)
	tarjeta.set_meta("borde", borde)

# =====================================================================
# MOVERSE Y ELEGIR
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if eligiendo or not listo_para_tocar: return
	var cantidad = tarjetas.size()
	var nueva = seleccion

	# Parado en "VOLVER": para arriba vuelve a las tarjetas; con un botón, vuelve a elegir modo
	if en_volver:
		if _apreto(event, "move_up", "ui_up"):
			get_viewport().set_input_as_handled()
			en_volver = false
			_marcar_seleccion()
		elif _acepto(event):
			get_viewport().set_input_as_handled()
			_volver()
		return

	if _apreto(event, "move_up", "ui_up"):
		if seleccion >= 2:
			nueva = seleccion - 2
	elif _apreto(event, "move_down", "ui_down"):
		# Baja una fila (si la última fila tiene una sola tarjeta, va a esa)
		if (cantidad - 1) / 2 > seleccion / 2:
			nueva = mini(seleccion + 2, cantidad - 1)
		else:
			# Ya está en la última fila: baja al botón "VOLVER"
			get_viewport().set_input_as_handled()
			en_volver = true
			_marcar_seleccion()
			return
	elif _apreto(event, "move_left", "ui_left"):
		if seleccion % 2 == 1:
			nueva = seleccion - 1
	elif _apreto(event, "move_right", "ui_right"):
		if seleccion % 2 == 0 and seleccion + 1 < cantidad:
			nueva = seleccion + 1
	elif _acepto(event):
		get_viewport().set_input_as_handled()
		_elegir()
		return
	else:
		return

	get_viewport().set_input_as_handled()
	if nueva != seleccion:
		seleccion = nueva
		_marcar_seleccion()

func _apreto(event: InputEvent, accion: String, accion_ui: String) -> bool:
	if event.is_action_pressed(accion) or event.is_action_pressed(accion_ui): return true
	# Modo 2 jugadores: también con la palanca de cada uno
	if cooperativo:
		for p in ["p1_", "p2_"]:
			if InputMap.has_action(p + accion) and event.is_action_pressed(p + accion): return true
	return false

# Elegir: los botones de siempre y, en el modo 2 jugadores, también los de cada jugador (C/V/B, J/K/L o su mando)
func _acepto(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"): return true
	if cooperativo:
		for p in ["p1_", "p2_"]:
			if InputMap.has_action(p + "interact") and event.is_action_pressed(p + "interact"): return true
	return false

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
	# Nivel bloqueado: sacudón y sonido de "no"
	if not _abierto(seleccion):
		_tocar(SONIDO_BLOQUEADO)
		_sacudir(tarjetas[seleccion])
		return
	# ¡A jugar!
	_tocar(SONIDO_ELEGIR)
	if cooperativo:
		GameManager.nivel_coop_elegido = seleccion
		_irse_a(RUTA_LADRONES)
	else:
		GameManager.nivel_elegido = seleccion
		_irse_a(RUTA_PERSONAJE)

func _irse_a(ruta: String) -> void:
	eligiendo = true
	var sigue_la_musica: bool = ruta in [RUTA_MENU, RUTA_PERSONAJE, RUTA_LADRONES, RUTA_MODO]
	# Destello de la tarjeta (o del botón) elegido y fundido a negro
	var tarjeta: Control = boton_volver if en_volver else tarjetas[seleccion]
	var t = create_tween()
	t.tween_property(tarjeta, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(tarjeta, "modulate", tarjeta.modulate, 0.12)
	t.tween_property(fundido, "color:a", 1.0, 0.3)
	if not sigue_la_musica:
		GameManager.apagar_musica_menu(0.3)
	await t.finished
	get_tree().change_scene_to_file(ruta)

# =====================================================================
# EFECTOS
# =====================================================================
# Pinta el borde blanco en la elegida y la hace flotar de a un pixel (sin agrandarla, así no se deforma el pixel art)
const ALTURA_BOTE: int = 2
var posiciones_originales: Dictionary = {}

func _marcar_seleccion(con_sonido: bool = true) -> void:
	if con_sonido: _tocar(SONIDO_MOVER)
	if tween_bote: tween_bote.kill()
	# El botón "VOLVER": se ilumina y flota cuando está elegido
	boton_volver.position.y = y_volver
	boton_volver.modulate = VOLVER_ILUMINADO if en_volver else Color.WHITE
	for i in tarjetas.size():
		var tarjeta = tarjetas[i]
		if not posiciones_originales.has(tarjeta):
			posiciones_originales[tarjeta] = tarjeta.position
		tarjeta.position = posiciones_originales[tarjeta] # Las demás vuelven a su lugar
		var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
		var elegida = i == seleccion and not en_volver
		estilo.border_color = COLOR_SELECCION if elegida else tarjeta.get_meta("borde")
		tarjeta.modulate = BRILLO_TARJETA if elegida else Color.WHITE
	var actual: Control = boton_volver if en_volver else tarjetas[seleccion]
	var y_original: float = y_volver if en_volver else posiciones_originales[actual].y
	tween_bote = create_tween().set_loops()
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), 0.0, ALTURA_BOTE, 0.35)
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), float(ALTURA_BOTE), 0.0, 0.35)

# =====================================================================
# BOTÓN "VOLVER"
# =====================================================================
func _armar_boton_volver() -> void:
	boton_volver = preload("res://scripts/boton_volver.gd").armar(self, fundido, boton_volver_y)
	boton_volver.mouse_entered.connect(func():
		if eligiendo or en_volver: return
		en_volver = true
		_marcar_seleccion())
	boton_volver.pressed.connect(func():
		if eligiendo or not listo_para_tocar: return
		en_volver = true
		_volver())

func _volver() -> void:
	_tocar(SONIDO_ELEGIR)
	_irse_a(RUTA_MODO)

func _sacudir(tarjeta: Control) -> void:
	var candado = tarjeta.get_node_or_null("Candado")
	if candado == null: return
	var x: float = candado.get_meta("x")
	var t = create_tween()
	for dx in [-3, 3, -2, 2, 0]:
		t.tween_property(candado, "position:x", x + dx, 0.04)

func _tocar(sonido_nuevo: AudioStream) -> void:
	sonido.stream = sonido_nuevo
	sonido.play()

# La música del menú es una sola para todas las pantallas (vive en GameManager), así no se corta ni se atrasa
func _poner_musica() -> void:
	musica = GameManager.musica_menu()
