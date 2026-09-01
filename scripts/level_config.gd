extends Node2D

@export var frutas_del_nivel: Array[ItemData]
@export var tiempo_del_nivel: float = 90.0
@export var cajas_activas: int = 2 

# Guardamos la lista a nivel global del script para usarla varias veces
var mis_cajas: Array = []

func _ready() -> void:
	GameManager.iniciar_nivel(frutas_del_nivel, tiempo_del_nivel)
	
	# 1. Buscamos nuestras cajas (¡Esto ya lo sabes hacer!)
	var todas_las_cajas = get_tree().get_nodes_in_group("CajasObstaculo")
	for caja in todas_las_cajas:
		if self.is_ancestor_of(caja):
			mis_cajas.append(caja)
			
	# 2. Mezclamos por primera vez al arrancar el nivel
	mezclar_cajas()
	
	# 3. Le pedimos al GameManager que nos avise cuando se agarre una fruta
	GameManager.item_collected.connect(_on_item_recolectado)
	
	# 4. Arrancamos el ciclo del reloj aleatorio
	bucle_de_tiempo_aleatorio()

# --- LA FUNCIÓN PRINCIPAL QUE MEZCLA LAS CAJAS ---
func mezclar_cajas() -> void:
	mis_cajas.shuffle() # Mezclamos la baraja
	
	# Buscamos al jugador en el mapa
	var jugador = get_tree().get_first_node_in_group("Player")
	var cajas_encendidas = 0 # Llevamos la cuenta de cuántas vamos encendiendo
	
	# NUEVO PRINT CHISMOSO:
	print("Buscando al jugador... Resultado: ", jugador)
	
	for caja in mis_cajas:
		var es_seguro_encender = true
		
		# Si el jugador existe, medimos la distancia matemática
		if jugador != null:
			# global_position nos da la coordenada exacta en el mapa
			var distancia = caja.global_position.distance_to(jugador.global_position)
			
			# Si la caja está a menos de 60 píxeles del jugador (casi tocándolo)
			print("Posición Caja: ", caja.global_position, " | Posición Jugador: ", jugador.global_position)
			if distancia < 120.0:
				es_seguro_encender = false
		
		# Si todavía nos faltan encender cajas Y el lugar es seguro...
		if cajas_encendidas < cajas_activas and es_seguro_encender:
			# ENCENDER CAJA
			caja.show() 
			caja.process_mode = Node.PROCESS_MODE_INHERIT 
			cajas_encendidas += 1 # Contamos que encendimos una
		else:
			# APAGAR CAJA (O porque está muy cerca, o porque ya encendimos suficientes)
			caja.hide() 
			caja.process_mode = Node.PROCESS_MODE_DISABLED

# --- LOS GATILLOS (Lo que provoca que se mezclen) ---

# Gatillo 1: Cuando agarramos una fruta
func _on_item_recolectado(item: ItemData) -> void:
	print("¡Fruta agarrada! Mezclando cajas...")
	mezclar_cajas()

# Gatillo 2: El tiempo aleatorio
func bucle_de_tiempo_aleatorio() -> void:
	# Elegimos un tiempo al azar, por ejemplo entre 5 y 10 segundos
	var tiempo_azar = randf_range(10.0, 15.0) 
	
	# Esperamos ese tiempo sin congelar el juego (Corrutina)
	await get_tree().create_timer(tiempo_azar).timeout
	
	# Comprobamos que el juego no haya terminado
	if GameManager.juego_activo:
		print("¡Evento de Tiempo! Mezclando cajas...")
		mezclar_cajas()
		
		# Volvemos a llamarnos a nosotros mismos para crear un ciclo infinito
		bucle_de_tiempo_aleatorio()
