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
const RUTA_MENU: String = "res://scenes/ui/menu_principal.tscn"
const RUTA_MUSICA_MENU: String = "res://assets/audio/MusicaMenu.ogg"
const VOLUMEN_MUSICA_MENU: float = -8.0

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

func _ready() -> void:
	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	_poner_musica()

	# Una tarjeta por nivel
	for i in _cantidad():
		var tarjeta = _crear_tarjeta(i)
		grilla.add_child(tarjeta)
		tarjetas.append(tarjeta)

	# Arrancamos parados en el último nivel jugado (o el primero)
	seleccion = clampi(_nivel_elegido(), 0, _cantidad() - 1)
	if not _abierto(seleccion):
		seleccion = 0
	await get_tree().process_frame # Los contenedores acomodan las tarjetas
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

	if _apreto(event, "move_up", "ui_up"):
		if seleccion >= 2:
			nueva = seleccion - 2
	elif _apreto(event, "move_down", "ui_down"):
		# Baja una fila (si la última fila tiene una sola tarjeta, va a esa)
		if (cantidad - 1) / 2 > seleccion / 2:
			nueva = mini(seleccion + 2, cantidad - 1)
	elif _apreto(event, "move_left", "ui_left"):
		if seleccion % 2 == 1:
			nueva = seleccion - 1
	elif _apreto(event, "move_right", "ui_right"):
		if seleccion % 2 == 0 and seleccion + 1 < cantidad:
			nueva = seleccion + 1
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

func _apreto(event: InputEvent, accion: String, accion_ui: String) -> bool:
	return event.is_action_pressed(accion) or event.is_action_pressed(accion_ui)

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
	var sigue_la_musica: bool = ruta == RUTA_MENU or ruta == RUTA_PERSONAJE or ruta == RUTA_LADRONES
	if sigue_la_musica and musica:
		GameManager.posicion_musica_menu = musica.get_playback_position()
	# Destello de la tarjeta elegida y fundido a negro
	var tarjeta = tarjetas[seleccion]
	var t = create_tween()
	t.tween_property(tarjeta, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(tarjeta, "modulate", tarjeta.modulate, 0.12)
	t.tween_property(fundido, "color:a", 1.0, 0.3)
	if musica and not sigue_la_musica:
		t.parallel().tween_property(musica, "volume_db", -40.0, 0.3)
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
	for i in tarjetas.size():
		var tarjeta = tarjetas[i]
		if not posiciones_originales.has(tarjeta):
			posiciones_originales[tarjeta] = tarjeta.position
		tarjeta.position = posiciones_originales[tarjeta] # Las demás vuelven a su lugar
		var estilo: StyleBoxFlat = tarjeta.get_theme_stylebox("panel")
		var elegida = i == seleccion
		estilo.border_color = COLOR_SELECCION if elegida else tarjeta.get_meta("borde")
		tarjeta.modulate = BRILLO_TARJETA if elegida else Color.WHITE
	var actual = tarjetas[seleccion]
	var y_original: float = posiciones_originales[actual].y
	tween_bote = create_tween().set_loops()
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), 0.0, ALTURA_BOTE, 0.35)
	tween_bote.tween_method(func(v: float): actual.position.y = y_original - round(v), float(ALTURA_BOTE), 0.0, 0.35)

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

# Sigue la música del menú desde donde iba (si venimos del menú) o desde el principio
func _poner_musica() -> void:
	if not ResourceLoader.exists(RUTA_MUSICA_MENU): return
	musica = AudioStreamPlayer.new()
	var cancion: AudioStream = load(RUTA_MUSICA_MENU)
	cancion.loop = true
	musica.stream = cancion
	musica.volume_db = VOLUMEN_MUSICA_MENU
	add_child(musica)
	musica.play(GameManager.posicion_musica_menu)
	GameManager.posicion_musica_menu = 0.0
