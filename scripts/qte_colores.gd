extends Control

signal qte_finished(success: bool)

@export var tex_azul_hundido: Texture2D
@export var tex_rojo_hundido: Texture2D
@export var tex_amarillo_hundido: Texture2D

var tex_azul_normal: Texture2D
var tex_rojo_normal: Texture2D
var tex_amarillo_normal: Texture2D

# Referencia a la cajita de arriba donde aparecerán las luces
@onready var luces_contrasena: HBoxContainer = %LucesTarget

@onready var botones = {
	"azul": %BotonAzul,
	"rojo": %BotonRojo,
	"amarillo": %BotonAmarillo
}

var secuencia_correcta: Array[String] = [] 
var indice_actual: int = 0 
var is_active: bool = false
var cantidad_de_botones: int = 4 
var estado_juego: String = "MOSTRANDO" 
var intentos_restantes: int = 5

func _ready() -> void:
	hide()
	tex_azul_normal = %BotonAzul.texture
	tex_rojo_normal = %BotonRojo.texture
	tex_amarillo_normal = %BotonAmarillo.texture

func start_qte() -> void:
	show()
	intentos_restantes = 5
	generar_secuencia()
	dibujar_luces() # Fabricamos las luces arriba
	
	indice_actual = 0
	is_active = true
	animar_secuencia()

func generar_secuencia() -> void:
	secuencia_correcta.clear()
	var colores_posibles = ["azul", "rojo", "amarillo"]
	for i in range(cantidad_de_botones):
		secuencia_correcta.append(colores_posibles.pick_random())

# --- DIBUJAR LUCES (ARRIBA) ---
func dibujar_luces() -> void:
	for hijo in luces_contrasena.get_children():
		hijo.queue_free()
		
	for color_pedido in secuencia_correcta:
		var circulo = Panel.new()
		circulo.custom_minimum_size = Vector2(32, 32)
		
		var estilo = StyleBoxFlat.new()
		estilo.corner_radius_top_left = 16
		estilo.corner_radius_top_right = 16
		estilo.corner_radius_bottom_left = 16
		estilo.corner_radius_bottom_right = 16
		estilo.anti_aliasing = false 
		
		match color_pedido:
			"azul": estilo.bg_color = Color.BLUE
			"rojo": estilo.bg_color = Color.RED
			"amarillo": estilo.bg_color = Color.YELLOW
			
		circulo.add_theme_stylebox_override("panel", estilo)
		
		# Nacen Negros (Ocultando el color)
		circulo.modulate = Color.BLACK 
		luces_contrasena.add_child(circulo)

# --- ANIMACIÓN "SIMÓN DICE" (En las luces de arriba) ---
func animar_secuencia() -> void:
	estado_juego = "MOSTRANDO" 
	await get_tree().create_timer(0.5).timeout 
	
	for i in range(secuencia_correcta.size()):
		if not is_active: return
		if i >= luces_contrasena.get_child_count(): return
		
		var luz = luces_contrasena.get_child(i)
		
		if is_instance_valid(luz):
			luz.modulate = Color.WHITE # Muestra el color
		await get_tree().create_timer(0.4).timeout 
		
		if is_instance_valid(luz):
			luz.modulate = Color.BLACK # Vuelve a ocultarlo en negro
		await get_tree().create_timer(0.2).timeout
		
	if is_active:
		estado_juego = "JUGANDO"

# --- LÓGICA DE JUGABILIDAD (En los botones de abajo) ---
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
	animar_hundimiento(color_apretado) # Hunde el botón de Nati abajo
	
	if color_apretado == secuencia_correcta[indice_actual]:
		# ¡ACERTÓ! Revela el color en la luz de arriba
		luces_contrasena.get_child(indice_actual).modulate = Color.WHITE
		indice_actual += 1 
		
		if indice_actual >= secuencia_correcta.size():
			estado_juego = "TERMINADO"
			await get_tree().create_timer(0.4).timeout 
			terminar_juego(true) 
	else:
		intentos_restantes -= 1
		estado_juego = "TERMINADO"
		await get_tree().create_timer(0.4).timeout 
		
		if intentos_restantes <= 0:
			terminar_juego(false)
		else:
			# --- REINICIO DEL MINIJUEGO (NUEVO INTENTO) ---
			is_active = true
			indice_actual = 0
			
			generar_secuencia() # ¡NUEVA LÍNEA! Crea una nueva contraseña
			dibujar_luces()     # ¡NUEVA LÍNEA! Dibuja los círculos otra vez
			
			animar_secuencia()  # Empieza a mostrar la nueva contraseña

# --- EFECTO VISUAL DE HUNDIR BOTONES DE NATI ---
func animar_hundimiento(color: String) -> void:
	var btn = botones[color]
	
	match color:
		"azul": if tex_azul_hundido: btn.texture = tex_azul_hundido
		"rojo": if tex_rojo_hundido: btn.texture = tex_rojo_hundido
		"amarillo": if tex_amarillo_hundido: btn.texture = tex_amarillo_hundido
	
	await get_tree().create_timer(0.15).timeout
	if not is_active: return
	
	match color:
		"azul": btn.texture = tex_azul_normal
		"rojo": btn.texture = tex_rojo_normal
		"amarillo": btn.texture = tex_amarillo_normal

func terminar_juego(victoria: bool) -> void:
	is_active = false
	hide()
	qte_finished.emit(victoria)
