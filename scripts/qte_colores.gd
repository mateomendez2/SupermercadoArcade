extends Control

signal qte_finished(success: bool)

@onready var secuencia_visual: HBoxContainer = $SecuenciaVisual

var secuencia_correcta: Array[String] = [] 
var indice_actual: int = 0 
var is_active: bool = false
var cantidad_de_botones: int = 4 

# NUEVA VARIABLE DE ESTADO: Para saber si está "enseñando" o si es tu "turno"
var estado_juego: String = "MOSTRANDO" 

func _ready() -> void:
	hide()

func start_qte() -> void:
	show()
	generar_secuencia()
	dibujar_secuencia()
	indice_actual = 0
	is_active = true
	
	# Apenas arranca, llamamos a la animación de las luces
	animar_secuencia()

func generar_secuencia() -> void:
	secuencia_correcta.clear()
	var colores_posibles = ["azul", "rojo", "amarillo"]
	for i in range(cantidad_de_botones):
		secuencia_correcta.append(colores_posibles.pick_random())

# --- DIBUJAR CÍRCULOS (En lugar de cuadrados) ---
func dibujar_secuencia() -> void:
	for hijo in secuencia_visual.get_children():
		hijo.queue_free()
		
	for color_pedido in secuencia_correcta:
		# Usamos Panel en lugar de ColorRect para poder redondearlo
		var circulo = Panel.new()
		circulo.custom_minimum_size = Vector2(32, 32)
		
		# Creamos un estilo de caja y le redondeamos las esquinas al máximo (16px es la mitad de 32)
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
		
		# Arrancan todos apagados/oscuros (Alpha al 30%)
		circulo.modulate = Color.BLACK 
		secuencia_visual.add_child(circulo)

# --- LA ANIMACIÓN "SIMÓN DICE" ---
func animar_secuencia() -> void:
	estado_juego = "MOSTRANDO" 
	
	await get_tree().create_timer(0.5).timeout 
	
	# Recorremos cada círculo y lo encendemos y apagamos
	for i in range(secuencia_correcta.size()):
		
		# GUARDIA 1: Si el jugador se fue corriendo y el juego se desactivó, matamos la animación
		if not is_active: return
		
		# GUARDIA 2: Si por alguna razón no hay suficientes hijos, cortamos
		if i >= secuencia_visual.get_child_count(): return
		
		var circulo = secuencia_visual.get_child(i)
		
		# ENCIENDE (Solo si el círculo sigue existiendo)
		if is_instance_valid(circulo):
			circulo.modulate = Color.WHITE 
			
		await get_tree().create_timer(0.4).timeout 
		
		# APAGA (Verificamos OTRA VEZ porque hubo otro 'await' donde el jugador pudo huir)
		if is_instance_valid(circulo):
			circulo.modulate = Color.BLACK
			
		await get_tree().create_timer(0.2).timeout
		
	# Si llegamos hasta acá y el jugador NO se fue, le damos el turno
	if is_active:
		estado_juego = "JUGANDO"
		print("¡TU TURNO!")

# --- LÓGICA DE JUGABILIDAD ---
func _unhandled_input(event: InputEvent) -> void:
	# Si la pantalla está apagada, no hacemos nada
	if not is_active: return
	
	# Verificamos si tocaste ALGUNO de los botones físicos
	var toco_boton = event.is_action_pressed("btn_azul") or event.is_action_pressed("btn_rojo") or event.is_action_pressed("btn_amarillo") or event.is_action_pressed("interact")
	
	if toco_boton:
		# 1. ¡DEVORAMOS EL BOTÓN! (Nadie más en el juego lo escuchará)
		get_viewport().set_input_as_handled()
		
		# 2. Si todavía te estoy mostrando las luces, te ignoro (pero el botón ya fue devorado)
		if estado_juego != "JUGANDO":
			return
			
		# 3. Solo si es tu turno, procesamos el color
		var color_apretado = ""
		if event.is_action_pressed("btn_azul"): color_apretado = "azul"
		elif event.is_action_pressed("btn_rojo"): color_apretado = "rojo"
		elif event.is_action_pressed("btn_amarillo"): color_apretado = "amarillo"
		
		if color_apretado != "":
			comprobar_boton(color_apretado)

func comprobar_boton(color_apretado: String) -> void:
	if color_apretado == secuencia_correcta[indice_actual]:
		
		# ¡ACERTÓ! Encendemos ese botón revelando su color
		secuencia_visual.get_child(indice_actual).modulate = Color.WHITE
		indice_actual += 1 
		
		if indice_actual >= secuencia_correcta.size():
			# Pausita para que el jugador vea que prendió el último antes de cerrar
			estado_juego = "TERMINADO"
			await get_tree().create_timer(0.3).timeout 
			terminar_juego(true) 
			
	else:
		estado_juego = "TERMINADO"
		terminar_juego(false) 

func terminar_juego(victoria: bool) -> void:
	print("🚨 Simón Dice cerrado. ¿Victoria? ", victoria) # CHISMOSO
	is_active = false
	hide()
	qte_finished.emit(victoria)
