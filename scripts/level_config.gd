extends Node2D

@export var frutas_del_nivel: Array[ItemData]
@export var tiempo_del_nivel: float = 90.0
@export var cajas_activas: int = 2 
# NUEVA LÍNEA: Casillero para arrastrar al jugador
@onready var jugador: CharacterBody2D = %Player
@export var charcos_activos: int = 2

# Guardamos la lista a nivel global del script para usarla varias veces
var mis_cajas: Array = []
# NUEVA LÍNEA: Memoria del turno anterior
var cajas_viejas: Array = []

var mis_charcos: Array = []
var charcos_viejos: Array = []

func _ready() -> void:
	GameManager.iniciar_nivel(frutas_del_nivel, tiempo_del_nivel)
	
	# Buscamos nuestras cajas
	var todas_las_cajas = get_tree().get_nodes_in_group("CajasObstaculo")
	for caja in todas_las_cajas:
		if self.is_ancestor_of(caja):
			mis_cajas.append(caja)
			
	# Buscamos nuestros charcos
	var todos_los_charcos = get_tree().get_nodes_in_group("CharcosObstaculo")
	for charco in todos_los_charcos:
		if self.is_ancestor_of(charco):
			mis_charcos.append(charco)
			
	# Mezclamos AMBOS por primera vez al arrancar el nivel
	mezclar_cajas()
	mezclar_charcos()
	
	GameManager.item_collected.connect(_on_item_recolectado)
	bucle_de_tiempo_aleatorio()

# --- LA FUNCIÓN PRINCIPAL QUE MEZCLA LAS CAJAS ---
# --- LA FUNCIÓN PRINCIPAL QUE MEZCLA LAS CAJAS ---
func mezclar_cajas() -> void:
	mis_cajas.shuffle() # Mezclamos la baraja
	
	var cajas_encendidas = 0 
	var nuevas_cajas_viejas: Array = [] # Las que encendamos HOY, serán las viejas de MAÑANA
	
	for caja in mis_cajas:
		var es_seguro_encender = true
		
		# REGLA 1: Distancia al jugador
		if jugador != null:
			var distancia = caja.global_position.distance_to(jugador.global_position)
			if distancia < 60.0:
				es_seguro_encender = false
				
		# REGLA 2 (NUEVA): Anti-Repetición
		# Si esta caja está en la memoria del turno anterior, la prohibimos
		if caja in cajas_viejas:
			es_seguro_encender = false
		
		# Evaluamos si la encendemos o la apagamos
		if cajas_encendidas < cajas_activas and es_seguro_encender:
			# ENCENDER CAJA
			caja.show() 
			caja.process_mode = Node.PROCESS_MODE_INHERIT 
			cajas_encendidas += 1 
			
			# La anotamos en la lista de memoria
			nuevas_cajas_viejas.append(caja)
		else:
			# APAGAR CAJA
			caja.hide() 
			caja.process_mode = Node.PROCESS_MODE_DISABLED

	# Al final de todo el proceso, sobreescribimos la memoria para el PRÓXIMO turno
	cajas_viejas = nuevas_cajas_viejas

# --- LOS GATILLOS (Lo que provoca que se mezclen) ---

# Gatillo 1: Cuando agarramos una fruta
func _on_item_recolectado(_item: ItemData) -> void:
	print("¡Fruta agarrada! Mezclando obstáculos...")
	mezclar_cajas()
	mezclar_charcos() # Ahora también mezcla los charcos al ganar un QTE

# Gatillo 2: El tiempo aleatorio
func bucle_de_tiempo_aleatorio() -> void:
	var tiempo_azar = randf_range(10.0, 15.0) 
	
	await get_tree().create_timer(tiempo_azar).timeout
	
	if GameManager.juego_activo:
		print("¡Evento de Tiempo! Mezclando obstáculos...")
		mezclar_cajas()
		mezclar_charcos() # Ahora el tiempo también mueve los charcos
		
		# Volvemos a llamarnos a nosotros mismos para crear el ciclo infinito
		bucle_de_tiempo_aleatorio()

# --- LA FUNCIÓN QUE MEZCLA LOS CHARCOS ---
func mezclar_charcos() -> void:
	mis_charcos.shuffle() 
	
	var charcos_encendidos = 0 
	var nuevos_charcos_viejos: Array = [] 
	
	for charco in mis_charcos:
		var es_seguro_encender = true
		
		# Anti-Repetición: Si estuvo prendido el turno anterior, lo prohibimos
		if charco in charcos_viejos:
			es_seguro_encender = false
		
		if charcos_encendidos < charcos_activos and es_seguro_encender:
			# ENCENDER CHARCO
			charco.show() 
			charco.process_mode = Node.PROCESS_MODE_INHERIT 
			charcos_encendidos += 1 
			nuevos_charcos_viejos.append(charco)
		else:
			# APAGAR CHARCO
			charco.hide() 
			charco.process_mode = Node.PROCESS_MODE_DISABLED

	charcos_viejos = nuevos_charcos_viejos
