extends Control

signal qte_finished(success: bool)
# Modo 2 jugadores: con los botones de quién se juega ("p1_" o "p2_"). Vacío = los de siempre.
var prefijo: String = ""
const IconosMando = preload("res://scripts/iconos_mando.gd") # Botones del mando, o teclas si no hay mando

@onready var barra_progreso: ProgressBar = $FondoCartel/ProgressBar

# --- IMÁGENES DE BOTONES HUNDIDOS ---
@export var tex_azul_hundido: Texture2D
@export var tex_rojo_hundido: Texture2D
@export var tex_amarillo_hundido: Texture2D

var tex_azul_normal: Texture2D
var tex_rojo_normal: Texture2D
var tex_amarillo_normal: Texture2D

@onready var botones = {
	"azul": %BotonAzul,
	"rojo": %BotonRojo,
	"amarillo": %BotonAmarillo
}

var is_active: bool = false
var color_actual: String = ""

# --- BALANCEO ---
var progreso: float = 20.0
@export var drenaje_por_segundo: float = 10.0 
@export var fuerza_botonazo: float = 10.0 

# --- ESTILO DE LA BARRA ---
# Colores sacados de los dibujos de los botones
const COLOR_AZUL: Color = Color8(54, 104, 252)
const COLOR_ROJO: Color = Color8(255, 63, 59)
const COLOR_AMARILLO: Color = Color8(251, 242, 54)
var estilo_relleno: StyleBoxFlat

func _ready() -> void:
	hide()
	_estilizar_barra()
	# Guardamos cómo se ven los botones normalmente (levantados)
	tex_azul_normal = %BotonAzul.texture
	tex_rojo_normal = %BotonRojo.texture
	tex_amarillo_normal = %BotonAmarillo.texture
	# Botones del mando o teclas (y se cambian solos si se conecta o desconecta el mando)
	IconosMando.aplicar(self)
	Input.joy_connection_changed.connect(_cambio_de_mando)

func start_qte() -> void:
	IconosMando.aplicar(self)
	sesion += 1
	progreso = 20.0 
	barra_progreso.value = progreso
	
	cambiar_color_al_azar()
	show()
	
	await get_tree().process_frame
	is_active = true
	ciclo_cambiar_colores()

func _process(delta: float) -> void:
	if not is_active: return
	
	progreso -= drenaje_por_segundo * delta
	if progreso < 5.0:
		progreso = 5.0
		
	barra_progreso.value = progreso
	
	if progreso >= 100.0:
		terminar_juego(true) 

func ciclo_cambiar_colores() -> void:
	while is_active:
		var tiempo_espera = randf_range(1.0, 2.0)
		await get_tree().create_timer(tiempo_espera).timeout
		
		if is_active:
			cambiar_color_al_azar()

func cambiar_color_al_azar() -> void:
	var colores = ["azul", "rojo", "amarillo"]
	color_actual = colores.pick_random()
	
	# Solo cambiamos el color del relleno (el estilo ya está armado en _estilizar_barra)
	match color_actual:
		"azul": estilo_relleno.bg_color = COLOR_AZUL
		"rojo": estilo_relleno.bg_color = COLOR_ROJO
		"amarillo": estilo_relleno.bg_color = COLOR_AMARILLO

# --- MACHACAR BOTONES ---
func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	var toco_boton = event.is_action_pressed(prefijo + "btn_azul") or event.is_action_pressed(prefijo + "btn_rojo") or event.is_action_pressed(prefijo + "btn_amarillo") or event.is_action_pressed(prefijo + "interact")
	
	if toco_boton:
		get_viewport().set_input_as_handled() 
		
		var apreto = ""
		if event.is_action_pressed(prefijo + "btn_azul"): apreto = "azul"
		elif event.is_action_pressed(prefijo + "btn_rojo"): apreto = "rojo"
		elif event.is_action_pressed(prefijo + "btn_amarillo"): apreto = "amarillo"
		
		if apreto != "":
			# ¡NUEVA LÍNEA! Hundimos el botón en la pantalla
			animar_hundimiento(apreto) 
			
			if apreto == color_actual:
				progreso += fuerza_botonazo

# --- EFECTO VISUAL DE HUNDIR (VERSIÓN SÚPER RÁPIDA) ---
func animar_hundimiento(color: String) -> void:
	var btn = botones[color]
	
	match color:
		"azul": if tex_azul_hundido: btn.texture = tex_azul_hundido
		"rojo": if tex_rojo_hundido: btn.texture = tex_rojo_hundido
		"amarillo": if tex_amarillo_hundido: btn.texture = tex_amarillo_hundido
	
	# Ilumina el botón un poquito
	btn.modulate = Color.WHITE
	
	# Pausa de 0.05 seg (Súper rápida para que puedas machacar sin que se trabe)
	await get_tree().create_timer(0.05).timeout
	if not is_active: return
	
	# Lo vuelve a levantar
	match color:
		"azul": btn.texture = tex_azul_normal
		"rojo": btn.texture = tex_rojo_normal
		"amarillo": btn.texture = tex_amarillo_normal
		
	# Lo vuelve a oscurecer un poquito
	btn.modulate = Color(0.8, 0.8, 0.8, 1.0) 

func terminar_juego(victoria: bool) -> void:
	is_active = false
	if victoria:
		# ¡GANÓ! Avisa victoria y festeja con confites antes de cerrarse
		qte_finished.emit(true)
		_festejar()
		return
	hide()
	qte_finished.emit(victoria)

# NUEVO: La barra con estilo pixel art.
# Antes usaba la barra gris de Godot (con puntas redondeadas) y el relleno cuadrado se salía por las esquinas.
# Ahora: fondo oscuro + relleno de puntas rectas + un MARCO naranja dibujado ENCIMA,
# así el relleno nunca puede asomar por afuera del borde.
func _estilizar_barra() -> void:
	# Fondo oscuro (para que se vea bien incluso el relleno amarillo)
	var fondo = StyleBoxFlat.new()
	fondo.bg_color = Color8(60, 32, 16)
	barra_progreso.add_theme_stylebox_override("background", fondo)
	
	# Relleno de puntas rectas (el color lo cambia cambiar_color_al_azar)
	estilo_relleno = StyleBoxFlat.new()
	estilo_relleno.bg_color = COLOR_AZUL
	barra_progreso.add_theme_stylebox_override("fill", estilo_relleno)
	
	# Marco naranja (el mismo de la barra del otro minijuego), por encima del relleno
	var marco = Panel.new()
	var estilo_marco = StyleBoxFlat.new()
	estilo_marco.draw_center = false # Solo el borde, el medio transparente
	estilo_marco.set_border_width_all(2)
	estilo_marco.border_color = Color8(255, 111, 0)
	marco.add_theme_stylebox_override("panel", estilo_marco)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_progreso.add_child(marco)
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # Mismo tamaño que la barra

# NUEVO: Festejo al ganar. Avisamos el resultado al instante, tiramos confites
# y el cartel se queda un momento antes de cerrarse.
const Confites = preload("res://scripts/confites.gd")
var sesion: int = 0 # Cambia cada vez que arranca, para no cerrar un minijuego nuevo por error

func _festejar() -> void:
	var mi_sesion = sesion
	var confites = Confites.new()
	add_child(confites)
	await confites.festejar(self)
	if mi_sesion == sesion:
		hide()

func _cambio_de_mando(_mando: int, _conectado: bool) -> void:
	IconosMando.aplicar(self)
