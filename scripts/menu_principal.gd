extends Control
## PANTALLA DE INICIO
## Dos botones amarillos, uno arriba del otro (mismo estilo que "VOLVER"):
##   JUGAR -> pasa a elegir el modo (1 o 2 jugadores)
##   SALIR -> cierra el juego
## Se elige con la palanca arriba/abajo (o el mouse) y se aprieta con cualquier botón.
## Dónde van y de qué tamaño: en el Inspector de MainMenu, grupo "Botones".

const BotonVolver = preload("res://scripts/boton_volver.gd")

@export_group("Botones")
@export var botones_centro_x: float = 288.0   # Centro en X (288 = mitad de la pantalla)
@export var boton_jugar_y: float = 290.0      # Altura del de JUGAR
@export var separacion: float = 48.0          # Cuánto más abajo va SALIR
@export var tamano_boton: Vector2 = Vector2(150, 40)
@export_group("")

# --- MÚSICA DEL MENÚ ---
var musica: AudioStreamPlayer
# --- SONIDOS Y FUNDIDO A NEGRO (como en las otras pantallas) ---
var SONIDO_MOVER: AudioStream = load("res://assets/audio/MenuMover.wav")
var SONIDO_ELEGIR: AudioStream = load("res://assets/audio/MenuElegir.wav")
const TIEMPO_FUNDIDO: float = 0.3
const ALTURA_BOTE: int = 2 # El botón elegido "salta" apenitas (como el VOLVER)
var empezando: bool = false
var sonido: AudioStreamPlayer
var fundido: ColorRect

var botones: Array[Button] = []
var alturas: Array[float] = []
var seleccion: int = 0 # 0 = JUGAR, 1 = SALIR
var tween_bote: Tween

# Con cualquiera de estos se aprieta el botón elegido (teclado, mando o tablero, de cualquier jugador)
const ACCIONES_ELEGIR: Array[String] = ["ui_accept", "interact", "btn_azul", "btn_rojo", "btn_amarillo",
	"p1_interact", "p1_btn_azul", "p1_btn_rojo", "p1_btn_amarillo",
	"p2_interact", "p2_btn_azul", "p2_btn_rojo", "p2_btn_amarillo"]
const ACCIONES_ARRIBA: Array[String] = ["ui_up", "move_up", "p1_move_up", "p2_move_up"]
const ACCIONES_ABAJO: Array[String] = ["ui_down", "move_down", "p1_move_down", "p2_move_down"]

func _ready() -> void:
	# Música del menú en loop: es una sola para todas las pantallas del menú (vive en GameManager),
	# así sigue de corrido al pasar a las otras pantallas. Se apaga sola cuando arranca un nivel.
	musica = GameManager.musica_menu()

	sonido = AudioStreamPlayer.new()
	add_child(sonido)
	fundido = ColorRect.new()
	fundido.name = "Fundido"
	fundido.color = Color(0, 0, 0, 1) # Arranca en negro y se aclara (como las otras pantallas)
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundido)
	fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Los dos botones (quedan abajo del fundido negro)
	var jugar = BotonVolver.armar(self, fundido, boton_jugar_y, "BotonJugar", "res://assets/ui/titulos/jugar.png", tamano_boton, botones_centro_x)
	var salir = BotonVolver.armar(self, fundido, boton_jugar_y + separacion, "BotonSalir", "res://assets/ui/titulos/salir.png", tamano_boton, botones_centro_x)
	botones = [jugar, salir]
	for i in botones.size():
		alturas.append(botones[i].position.y)
		botones[i].mouse_entered.connect(_mouse_encima.bind(i))
		botones[i].pressed.connect(func():
			if empezando: return
			seleccion = i
			_apretar())
	_marcar_seleccion(false)

	var entrada = create_tween()
	entrada.tween_property(fundido, "color:a", 0.0, 0.25)

# --- PALANCA Y BOTONES ---
func _unhandled_input(event: InputEvent) -> void:
	if empezando: return
	if _alguna(event, ACCIONES_ARRIBA) or _alguna(event, ACCIONES_ABAJO):
		get_viewport().set_input_as_handled()
		var nueva: int = 0 if _alguna(event, ACCIONES_ARRIBA) else 1
		if nueva != seleccion:
			seleccion = nueva
			_marcar_seleccion()
		return
	if _alguna(event, ACCIONES_ELEGIR):
		# Consumimos el botón para que no haga "eco" en la pantalla siguiente
		get_viewport().set_input_as_handled()
		_apretar()

func _alguna(event: InputEvent, acciones: Array[String]) -> bool:
	for a in acciones:
		if InputMap.has_action(a) and event.is_action_pressed(a): return true
	return false

func _mouse_encima(i: int) -> void:
	if empezando or i == seleccion: return
	seleccion = i
	_marcar_seleccion()

# El elegido se ilumina y salta apenitas; el otro queda quieto
func _marcar_seleccion(con_sonido: bool = true) -> void:
	if con_sonido:
		sonido.stream = SONIDO_MOVER
		sonido.play()
	if tween_bote: tween_bote.kill()
	for i in botones.size():
		botones[i].position.y = alturas[i]
		botones[i].modulate = BotonVolver.ILUMINADO if i == seleccion else Color.WHITE
	var boton: Button = botones[seleccion]
	var y0: float = alturas[seleccion]
	tween_bote = create_tween().set_loops()
	tween_bote.tween_method(func(v: float): boton.position.y = y0 - round(v), 0.0, ALTURA_BOTE, 0.35)
	tween_bote.tween_method(func(v: float): boton.position.y = y0 - round(v), float(ALTURA_BOTE), 0.0, 0.35)

func _apretar() -> void:
	if empezando: return
	empezando = true
	sonido.stream = SONIDO_ELEGIR
	sonido.play()
	if tween_bote: tween_bote.kill()
	var boton: Button = botones[seleccion]
	var t = create_tween()
	t.tween_property(boton, "modulate", Color(1.8, 1.8, 1.8), 0.06)
	t.tween_property(boton, "modulate", BotonVolver.ILUMINADO, 0.12)
	t.tween_property(fundido, "color:a", 1.0, TIEMPO_FUNDIDO)
	if seleccion == 1:
		# SALIR: también se apaga la música junto con el fundido, y se cierra el juego
		t.parallel().tween_callback(GameManager.apagar_musica_menu.bind(TIEMPO_FUNDIDO))
		await t.finished
		get_tree().quit()
		return
	# JUGAR: pasamos a la pantalla de elegir modo (1 o 2 jugadores). La música sigue de corrido
	await t.finished
	get_tree().change_scene_to_file("res://scenes/ui/seleccion_modo.tscn")
