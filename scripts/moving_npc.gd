extends Node2D

@export var velocidad: float = 50.0 # Píxeles por segundo (más alto = más rápido)
@export var tiempo_espera: float = 0.2

@onready var hitbox: Area2D = %Hitbox
@onready var ruta: Node2D = %Ruta # Nuestra carpeta de puntos

# NUEVO: Referencia al dibujo animado (que ahora es hijo de la Hitbox)
@onready var anim_sprite: AnimatedSprite2D = %Hitbox.get_node("AnimatedSprite2D")

@onready var posicion_inicial: Vector2 = hitbox.position
var ultima_posicion: Vector2
var last_direction: Vector2 = Vector2(1, 0) # Memoria de hacia dónde mira

func _ready() -> void:
	ultima_posicion = hitbox.position # Anotamos dónde arranca
	iniciar_patrullaje()
	hitbox.body_entered.connect(_on_hitbox_body_entered)

func iniciar_patrullaje() -> void:
	var patrulla_tween = create_tween().set_loops()
	var marcadores = ruta.get_children() 
	
	if marcadores.size() == 0:
		return
		
	# Usamos un puntero para saber dónde está parado y medir la distancia al siguiente punto
	var pos_actual = posicion_inicial
		
	# 1. VIAJE DE IDA 
	for marcador in marcadores:
		# Fórmula: Tiempo = Distancia / Velocidad
		var tiempo_viaje = pos_actual.distance_to(marcador.position) / velocidad
		
		patrulla_tween.tween_property(hitbox, "position", marcador.position, tiempo_viaje)
		patrulla_tween.tween_interval(tiempo_espera)
		pos_actual = marcador.position # Anotamos que ya llegó a este punto
		
	# 2. VIAJE DE VUELTA
	var marcadores_reversa = marcadores.duplicate()
	marcadores_reversa.reverse() 
	marcadores_reversa.pop_front() 
	
	for marcador in marcadores_reversa:
		var tiempo_viaje = pos_actual.distance_to(marcador.position) / velocidad
		
		patrulla_tween.tween_property(hitbox, "position", marcador.position, tiempo_viaje)
		patrulla_tween.tween_interval(tiempo_espera)
		pos_actual = marcador.position
		
	# 3. VOLVER AL INICIO ORIGINAL
	var tiempo_final = pos_actual.distance_to(posicion_inicial) / velocidad
	patrulla_tween.tween_property(hitbox, "position", posicion_inicial, tiempo_final)
	patrulla_tween.tween_interval(tiempo_espera)

# --- NUEVO: CEREBRO DE ANIMACIÓN ---
func _physics_process(delta: float) -> void:
	# Medimos cuánto se movió en este microsegundo
	var movimiento = hitbox.position - ultima_posicion
	ultima_posicion = hitbox.position # Guardamos la posición para el siguiente cálculo
	
	if movimiento.length() > 0.1: # Si se está moviendo
		last_direction = movimiento.normalized()
		update_animation(true)
	else: # Si el Tween está en "tiempo_espera" (quieto)
		update_animation(false)

func update_animation(is_moving: bool) -> void:
	anim_sprite.flip_h = false 
	
	# Comprobamos si se mueve más en horizontal o en vertical
	if abs(last_direction.x) > abs(last_direction.y):
		if last_direction.x > 0:
			anim_sprite.play("walk_right" if is_moving else "idle_right")
		else:
			anim_sprite.play("walk_left" if is_moving else "idle_left")
	else:
		if last_direction.y > 0:
			anim_sprite.play("walk_down" if is_moving else "idle_down")
		else:
			anim_sprite.play("walk_up" if is_moving else "idle_up")

# --- CASTIGO AL JUGADOR ---
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		
		# ¡EL CAMBIO MÁGICO! Le mandamos hitbox.global_position
		body.apply_penalty(5.0, hitbox.global_position)
		
		GameManager.perder_ultimo_item()
