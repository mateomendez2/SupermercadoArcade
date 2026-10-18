extends Control

signal qte_finished(success: bool)

# Corazones al costado del cartel: uno por vida, se rompen con cada error
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
var corazones

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

var secuencia_correcta: Array[String] = [] 
var indice_actual: int = 0 
var is_active: bool = false
var cantidad_de_secuencias: int = 4 
var estado_juego: String = "MOSTRANDO" 
var intentos_restantes: int = 5

@onready var fondo_oscuro: ColorRect = $Fondo

func _ready() -> void:
	hide()
	color_fondo_normal = fondo_oscuro.color
	corazones = CorazonesQTE.new()
	$FondoCartel.add_child(corazones)
	tex_azul_normal = %BotonAzul.texture
	tex_rojo_normal = %BotonRojo.texture
	tex_amarillo_normal = %BotonAmarillo.texture

func start_qte() -> void:
	sesion += 1
	show()
	intentos_restantes = 5
	corazones.armar(intentos_restantes)
	generar_secuencia()
	apagar_botones()
	
	indice_actual = 0
	is_active = true
	animar_secuencia()

func generar_secuencia() -> void:
	secuencia_correcta.clear()
	var colores_posibles = ["azul", "rojo", "amarillo"]
	for i in range(cantidad_de_secuencias):
		secuencia_correcta.append(colores_posibles.pick_random())

func apagar_botones() -> void:
	# Los ponemos bien oscuros (como luz apagada)
	for color in botones:
		botones[color].modulate = Color(0.2, 0.2, 0.2, 1.0)
		
func restablecer_botones() -> void:
	# Los ponemos en color normal (apagado pero visible)
	for color in botones:
		botones[color].modulate = Color.WHITE

# --- LA ANIMACIÓN "SIMÓN DICE" EN LOS BOTONES DE NATI ---
func animar_secuencia() -> void:
	estado_juego = "MOSTRANDO" 
	await get_tree().create_timer(0.5).timeout 
	
	for color_pedido in secuencia_correcta:
		if not is_active: return
		
		# ¡MAGIA! En lugar de prender una luz, "hundimos" el botón de Nati como si un fantasma lo estuviera tocando
		var btn = botones[color_pedido]
		
		# ENCIENDE
		btn.modulate = Color(1.5, 1.5, 1.5, 1.0) # Brilla mucho
		animar_hundimiento(color_pedido, true) # Lo hundimos (true = por la máquina)
		
		await get_tree().create_timer(0.4).timeout 
		
		# APAGA
		if not is_active: return
		btn.modulate = Color(0.2, 0.2, 0.2, 1.0) # Se vuelve a oscurecer
		animar_hundimiento(color_pedido, false) # Lo levantamos (false)
		
		await get_tree().create_timer(0.2).timeout
		
	if is_active:
		estado_juego = "JUGANDO"
		restablecer_botones() # Cuando te toca a ti, se iluminan a su color normal

# --- LÓGICA DE JUGABILIDAD ---
func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	var toco_boton = event.is_action_pressed("btn_azul") or event.is_action_pressed("btn_rojo") or event.is_action_pressed("btn_amarillo") or event.is_action_pressed("interact")
	
	if toco_boton:
		get_viewport().set_input_as_handled() 
		if estado_juego != "JUGANDO": return
		
		var color_apretado = ""
		if event.is_action_pressed("btn_azul"): color_apretado = "azul"
		elif event.is_action_pressed("btn_rojo"): color_apretado = "rojo"
		elif event.is_action_pressed("btn_amarillo"): color_apretado = "amarillo"
		
		if color_apretado != "":
			comprobar_boton(color_apretado)

func comprobar_boton(color_apretado: String) -> void:
	# El jugador lo hunde con su dedo (Cortito para que no se trabe)
	efecto_dedo_jugador(color_apretado)
	
	if color_apretado == secuencia_correcta[indice_actual]:
		_destello_fondo(FONDO_VERDE) # ¡Bien! Le pegaste a este de la secuencia
		indice_actual += 1 
		
		if indice_actual >= secuencia_correcta.size():
			estado_juego = "TERMINADO"
			await get_tree().create_timer(0.4).timeout 
			terminar_juego(true) 
	else:
		_destello_fondo(FONDO_ROJO) # Le erraste al orden (después se repite la secuencia como siempre)
		intentos_restantes -= 1
		corazones.perder_vida()
		estado_juego = "TERMINADO"
		await get_tree().create_timer(0.4).timeout 
		
		if intentos_restantes <= 0:
			terminar_juego(false)
		else:
			is_active = true
			apagar_botones()
			indice_actual = 0
			animar_secuencia()

# --- CONTROLADOR DE ARTE DE LOS BOTONES ---
func animar_hundimiento(color: String, hundir: bool) -> void:
	var btn = botones[color]
	if hundir:
		match color:
			"azul": if tex_azul_hundido: btn.texture = tex_azul_hundido
			"rojo": if tex_rojo_hundido: btn.texture = tex_rojo_hundido
			"amarillo": if tex_amarillo_hundido: btn.texture = tex_amarillo_hundido
	else:
		match color:
			"azul": btn.texture = tex_azul_normal
			"rojo": btn.texture = tex_rojo_normal
			"amarillo": btn.texture = tex_amarillo_normal

# Efecto ultra-rápido solo para cuando el jugador aprieta
func efecto_dedo_jugador(color: String) -> void:
	var btn = botones[color]
	animar_hundimiento(color, true)
	btn.modulate = Color(1.2, 1.2, 1.2, 1.0) # Ilumina un poquito
	
	await get_tree().create_timer(0.15).timeout
	if not is_active: return
	
	animar_hundimiento(color, false)
	btn.modulate = Color.WHITE

func terminar_juego(victoria: bool) -> void:
	is_active = false
	if victoria:
		# ¡GANÓ! Avisa victoria y festeja con confites antes de cerrarse
		qte_finished.emit(true)
		_festejar()
		return
	hide()
	qte_finished.emit(victoria)

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
