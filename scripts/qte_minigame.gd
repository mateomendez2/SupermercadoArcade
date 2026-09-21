extends Control

signal qte_finished(success: bool)

@export var speed: float = 400.0 
var direction: int = 1
var is_active: bool = false

# Variable para saber cuántos intentos nos quedan en ESTA partida
var intentos_restantes: int = 5

# NUEVO: Casilleros para las imágenes del botón
@export var tex_boton_normal: Texture2D
@export var tex_boton_hundido: Texture2D

@onready var cursor: TextureRect = $FondoCartel/Cursor
@onready var barra_roja: TextureRect = $FondoCartel/BarraRoja
@onready var zona_verde: ColorRect = $FondoCartel/ZonaVerde

# NUEVO: Referencia al botón visual
@onready var boton_visual: TextureRect = $FondoCartel/BotonVisual

func _ready() -> void:
	hide()

func start_qte() -> void:
	if tex_boton_normal: boton_visual.texture = tex_boton_normal
	
	intentos_restantes = 5 # ¡NUEVO! Reseteamos los intentos
	
	show()
	cursor.position.x = barra_roja.position.x 
	direction = 1
	
	# --- LÓGICA ALEATORIA PARA LA ZONA VERDE/NARANJA ---
	# 1. Calculamos los límites matemáticos (Bounding Box) de la barra
	var limite_izquierdo = barra_roja.position.x
	# Le restamos el ancho de la zona verde para que no se salga del borde derecho
	var limite_derecho = barra_roja.position.x + barra_roja.size.x - zona_verde.size.x
	
	# 2. Elegimos una posición X al azar
	var nueva_posicion_x = randf_range(limite_izquierdo, limite_derecho)
	
	# 3. Movemos el cuadradito verde invisible a esa nueva posición
	zona_verde.position.x = nueva_posicion_x
	# ---------------------------------------------------
	
	await get_tree().process_frame 
	is_active = true

func _process(delta: float) -> void:
	if not is_active: return
	
	cursor.position.x += speed * direction * delta
	var centro_aguja = cursor.position.x + (cursor.size.x / 2.0)
	var limite_izquierdo = barra_roja.position.x
	var limite_derecho = barra_roja.position.x + barra_roja.size.x
	
	if centro_aguja > limite_derecho:
		direction = -1
		cursor.position.x = limite_derecho - (cursor.size.x / 2.0) 
	elif centro_aguja < limite_izquierdo:
		direction = 1
		cursor.position.x = limite_izquierdo - (cursor.size.x / 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled() 
		is_active = false
		
		# ¡NUEVO! Cambiamos el dibujo al botón hundido
		if tex_boton_hundido: boton_visual.texture = tex_boton_hundido
		
		# Llamamos a la comprobación de victoria
		check_win()

# --- ACTUALIZADO: Comprobación con Pausa Dramática ---
func check_win() -> void:
	var cursor_center = cursor.position.x + (cursor.size.x / 2)
	var min_x = zona_verde.position.x
	var max_x = zona_verde.position.x + zona_verde.size.x
	var success = (cursor_center >= min_x) and (cursor_center <= max_x)
	
	# La pausa mágica para ver el botón hundido
	await get_tree().create_timer(0.3).timeout
	
	if success:
		# ¡GANÓ! Se cierra y avisa victoria
		hide() 
		qte_finished.emit(true) 
	else:
		# ¡FALLÓ! Restamos una vida
		intentos_restantes -= 1
		print("¡Fallaste! Te quedan: ", intentos_restantes, " intentos.")
		
		if intentos_restantes <= 0:
			# Se acabaron las vidas. Se cierra y avisa derrota.
			hide()
			qte_finished.emit(false)
		else:
			# --- REINICIO DEL MINIJUEGO (NUEVO INTENTO) ---
			
			# 1. Levantamos el botón de nuevo
			if tex_boton_normal: boton_visual.texture = tex_boton_normal
			
			# 2. Devolvemos la aguja al principio y que arranque hacia la derecha
			cursor.position.x = barra_roja.position.x
			direction = 1
			
			# 3. Movemos la zona verde al azar OTRA VEZ (usando tu margen de seguridad)
			var margen_seguridad = 15.0 
			var limite_izquierdo = barra_roja.position.x + margen_seguridad
			var limite_derecho = (barra_roja.position.x + barra_roja.size.x) - zona_verde.size.x - margen_seguridad
			zona_verde.position.x = randf_range(limite_izquierdo, limite_derecho)
			
			# 4. Volvemos a encender el motor
			is_active = true
