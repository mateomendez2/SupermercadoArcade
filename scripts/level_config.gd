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

var duracion_turno_actual: float = 15.0

func _ready() -> void:
	# -------------------------------------------------------------
	# 1. SETUP DE OBSTÁCULOS SILENCIOSO (¡Antes de la peli!)
	# -------------------------------------------------------------
	var todas_las_cajas = get_tree().get_nodes_in_group("CajasObstaculo")
	for caja in todas_las_cajas:
		if self.is_ancestor_of(caja):
			mis_cajas.append(caja)
			
	var todos_los_charcos = get_tree().get_nodes_in_group("CharcosObstaculo")
	for charco in todos_los_charcos:
		if self.is_ancestor_of(charco):
			mis_charcos.append(charco)
			
	# Mezclamos y apagamos lo que sobra instantáneamente
	mezclar_cajas()
	mezclar_charcos()
	
	# -------------------------------------------------------------
	# 2. CINEMÁTICA DE ENTRADA
	# -------------------------------------------------------------
	jugador.is_frozen = true
	jugador.anim_sprite.play("walk_down")
	
	var intro_tween = create_tween()
	var destino_y = jugador.position.y + 64.0 
	intro_tween.tween_property(jugador, "position:y", destino_y, 1.5)
	
	await intro_tween.finished
	
	jugador.last_direction = Vector2(0, 1)
	jugador.update_animation(false)
	jugador.is_frozen = false
	
	var puerta = get_tree().get_first_node_in_group("PuertaEntrada")
	if puerta and puerta.has_method("sellar_puerta"):
		puerta.sellar_puerta()
	
	# -------------------------------------------------------------
	# 3. AHORA SÍ, ¡ARRANCA EL JUEGO OFICIAL! 
	# -------------------------------------------------------------
	GameManager.iniciar_nivel(frutas_del_nivel, tiempo_del_nivel)
	GameManager.item_collected.connect(_on_item_recolectado)
	
	# Prendemos el reloj para que empiecen a cambiar de lugar
	bucle_de_tiempo_aleatorio()
	
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
	# 1. Calculamos y GUARDAMOS el tiempo para este turno (ej: 20 segundos)
	duracion_turno_actual = randf_range(15.0, 25.0) 
	
	# 2. Esperamos ESE tiempo exacto (Corrutina)
	await get_tree().create_timer(duracion_turno_actual).timeout
	
	# 3. Cuando termina la espera, verificamos si el juego sigue vivo
	if GameManager.juego_activo:
		print("¡Evento de Tiempo! Mezclando obstáculos...")
		mezclar_cajas()
		mezclar_charcos() 
		
		# 4. Volvemos a llamarnos a nosotros mismos para el SIGUIENTE turno
		bucle_de_tiempo_aleatorio()

# --- LA FUNCIÓN QUE MEZCLA LOS CHARCOS ---
func mezclar_charcos() -> void:
	mis_charcos.shuffle() 
	
	var charcos_encendidos = 0 
	var nuevos_charcos_viejos: Array = [] 
	
	for charco in mis_charcos:
		var es_seguro_encender = true
		
		# Anti-Repetición
		if charco in charcos_viejos:
			es_seguro_encender = false
		
		if charcos_encendidos < charcos_activos and es_seguro_encender:
			charco.show() 
			charco.process_mode = Node.PROCESS_MODE_INHERIT 
			
			# ¡NUEVA LÍNEA! Le avisamos al charco cuánto tiempo tiene para animarse
			if charco.has_method("animar_ciclo"):
				charco.animar_ciclo(duracion_turno_actual)
				
			charcos_encendidos += 1 
			nuevos_charcos_viejos.append(charco)
		else:
			charco.hide() 
			charco.process_mode = Node.PROCESS_MODE_DISABLED

	charcos_viejos = nuevos_charcos_viejos
