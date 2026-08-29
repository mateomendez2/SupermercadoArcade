extends Control

signal qte_finished(success: bool) # Avisará si ganamos o perdimos

@export var speed: float = 400.0 # Velocidad de la aguja
var direction: int = 1
var is_active: bool = false

@onready var cursor: TextureRect = $Cursor
@onready var barra_roja: TextureRect = $BarraRoja
@onready var zona_verde: ColorRect = $ZonaVerde

func _ready() -> void:
	hide() # Lo ocultamos al iniciar el juego

# Función que llama el GameManager para arrancar el minijuego
func start_qte() -> void:
	show()
	cursor.position.x = barra_roja.position.x # Reiniciamos la aguja a la izquierda
	direction = 1
	
	# TRUCO DE SENIOR: Esperamos un frame antes de activarlo. 
	# Si no hacemos esto, la misma tecla "E" que usaste para abrir la góndola 
	# cerrará el QTE en el mismo milisegundo.
	await get_tree().process_frame 
	is_active = true

func _process(delta: float) -> void:
	if not is_active: return
	
	# 1. Movemos la aguja
	cursor.position.x += speed * direction * delta
	
	# 2. Hacemos que rebote en los bordes de la barra roja
	if cursor.position.x > barra_roja.position.x + barra_roja.size.x - cursor.size.x:
		direction = -1
	elif cursor.position.x < barra_roja.position.x:
		direction = 1

func _unhandled_input(event: InputEvent) -> void:
	if not is_active: return
	
	# Cuando el jugador toca la "E" para frenar la aguja
	if event.is_action_pressed("interact"):
		is_active = false
		check_win()

func check_win() -> void:
	# Calculamos el centro de la aguja amarilla
	var cursor_center = cursor.position.x + (cursor.size.x / 2)
	
	# Calculamos dónde empieza y termina la zona verde
	var min_x = zona_verde.position.x
	var max_x = zona_verde.position.x + zona_verde.size.x
	
	# ¿Adivinamos?
	var success = (cursor_center >= min_x) and (cursor_center <= max_x)
	
	hide() # Ocultamos el QTE
	qte_finished.emit(success) # Gritamos el resultado
