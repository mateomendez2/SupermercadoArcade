extends Control

signal qte_finished(success: bool)

# Corazones al costado del cartel: uno por vida, se rompen con cada error
const CorazonesQTE = preload("res://scripts/corazones_qte.gd")
var corazones

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
	_estilizar_barra()
	corazones = CorazonesQTE.new()
	$FondoCartel.add_child(corazones)

func start_qte() -> void:
	sesion += 1
	if tex_boton_normal: boton_visual.texture = tex_boton_normal
	
	intentos_restantes = 5 # ¡NUEVO! Reseteamos los intentos
	corazones.armar(intentos_restantes)
	
	show()
	cursor.position.x = barra_roja.position.x 
	direction = 1
	
	# --- LÓGICA ALEATORIA PARA LA ZONA VERDE/NARANJA ---
	# 1. Calculamos los límites matemáticos (Bounding Box) de la barra
	# (BORDE: la zona verde no puede pisar el marco naranja)
	var limite_izquierdo = barra_roja.position.x + BORDE
	# Le restamos el ancho de la zona verde para que no se salga del borde derecho
	var limite_derecho = barra_roja.position.x + barra_roja.size.x - zona_verde.size.x - BORDE
	
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
	var mi_sesion = sesion
	await get_tree().create_timer(0.3).timeout
	# BUGFIX: si te alejaste de la góndola en esa pausa, el minijuego ya se cerró:
	# no hay que darte el producto ni volver a "prenderlo" escondido (se tragaba los botones)
	if mi_sesion != sesion or not visible:
		return
	
	if success:
		# ¡GANÓ! Avisa victoria y festeja con confites antes de cerrarse
		qte_finished.emit(true)
		_festejar()
	else:
		# ¡FALLÓ! Restamos una vida
		intentos_restantes -= 1
		corazones.perder_vida()
		print("¡Fallaste! Te quedan: ", intentos_restantes, " intentos.")
		
		if intentos_restantes <= 0:
			# Se acabaron las vidas. Esperamos un instante para que se vea
			# romperse el último corazón, y se cierra avisando derrota.
			await get_tree().create_timer(0.35).timeout
			if mi_sesion != sesion: return
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

# NUEVO: La barra con el MISMO estilo que la de "presiona rápido":
# fondo oscuro + marco naranja de 2 pixeles, sin puntas redondeadas.
const BORDE: int = 2

func _estilizar_barra() -> void:
	# Sacamos el dibujo viejo de la barra y ponemos un fondo oscuro adentro
	barra_roja.texture = null
	var fondo = ColorRect.new()
	fondo.color = Color8(60, 32, 16)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_roja.add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# El marco naranja va ENCIMA de la zona verde (y debajo del cursor),
	# así la zona verde nunca tapa el borde
	var marco = Panel.new()
	var estilo_marco = StyleBoxFlat.new()
	estilo_marco.draw_center = false # Solo el borde, el medio transparente
	estilo_marco.set_border_width_all(BORDE)
	estilo_marco.border_color = Color8(255, 111, 0)
	marco.add_theme_stylebox_override("panel", estilo_marco)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var padre = barra_roja.get_parent()
	padre.add_child(marco)
	padre.move_child(marco, zona_verde.get_index() + 1)
	# Mismo lugar y tamaño que la barra
	marco.anchor_left = barra_roja.anchor_left
	marco.anchor_top = barra_roja.anchor_top
	marco.anchor_right = barra_roja.anchor_right
	marco.anchor_bottom = barra_roja.anchor_bottom
	marco.offset_left = barra_roja.offset_left
	marco.offset_top = barra_roja.offset_top
	marco.offset_right = barra_roja.offset_right
	marco.offset_bottom = barra_roja.offset_bottom

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
