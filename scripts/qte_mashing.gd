extends Control

signal qte_finished(success: bool)

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

func _ready() -> void:
	hide()
	# Guardamos cómo se ven los botones normalmente (levantados)
	tex_azul_normal = %BotonAzul.texture
	tex_rojo_normal = %BotonRojo.texture
	tex_amarillo_normal = %BotonAmarillo.texture

func start_qte() -> void:
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
	
	var estilo_lleno = StyleBoxFlat.new()
	match color_actual:
		"azul": estilo_lleno.bg_color = Color.BLUE
		"rojo": estilo_lleno.bg_color = Color.RED
		"amarillo": estilo_lleno.bg_color = Color.YELLOW
	
	barra_progreso.add_theme_stylebox_override("fill", estilo_lleno)

# --- MACHACAR BOTONES ---
func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	var toco_boton = event.is_action_pressed("btn_azul") or event.is_action_pressed("btn_rojo") or event.is_action_pressed("btn_amarillo") or event.is_action_pressed("interact")
	
	if toco_boton:
		get_viewport().set_input_as_handled() 
		
		var apreto = ""
		if event.is_action_pressed("btn_azul"): apreto = "azul"
		elif event.is_action_pressed("btn_rojo"): apreto = "rojo"
		elif event.is_action_pressed("btn_amarillo"): apreto = "amarillo"
		
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
	hide()
	qte_finished.emit(victoria)
