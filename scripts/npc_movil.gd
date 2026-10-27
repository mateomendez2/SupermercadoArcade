@tool
extends Node2D

# --- QUÉ EMPLEADO ES (se elige en el Inspector y se ve en el editor) ---
const RUTAS_VARIANTES: Array[String] = [
	"res://assets/empleados/empleado_1.tres", # Variante 1: rubio
	"res://assets/empleados/empleado_2.tres", # Variante 2: castaño
]
@export_enum("Variante 1 (rubio)", "Variante 2 (castaño)") var variante: int = 0:
	set(valor):
		variante = valor
		if is_node_ready(): _aplicar_variante()

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
	_aplicar_variante()
	if Engine.is_editor_hint(): return # En el editor solo mostramos el dibujo, no camina
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
	if Engine.is_editor_hint(): return
	# Medimos cuánto se movió en este microsegundo
	var movimiento = hitbox.position - ultima_posicion
	ultima_posicion = hitbox.position # Guardamos la posición para el siguiente cálculo
	
	if movimiento.length() > 0.1: # Si se está moviendo
		last_direction = movimiento.normalized()
		update_animation(true)
	else: # Si el Tween está en "tiempo_espera" (quieto)
		update_animation(false)

func update_animation(is_moving: bool) -> void:
	# Comprobamos si se mueve más en horizontal o en vertical
	var nombre: String
	if abs(last_direction.x) > abs(last_direction.y):
		nombre = "right" if last_direction.x > 0 else "left"
	else:
		nombre = "down" if last_direction.y > 0 else "up"
	anim_sprite.play(("walk_" if is_moving else "idle_") + nombre)

# Pone el dibujo del empleado elegido
func _aplicar_variante() -> void:
	var sprite = get_node_or_null("%Hitbox/AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null: return
	var ruta = RUTAS_VARIANTES[clampi(variante, 0, RUTAS_VARIANTES.size() - 1)]
	if not ResourceLoader.exists(ruta): return
	sprite.sprite_frames = load(ruta)
	sprite.play("idle_down")

# --- CASTIGO AL JUGADOR ---
func _on_hitbox_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint(): return
	if body is Player:
		# BUGFIX: Si el jugador todavía está parpadeando (castigado), es invulnerable.
		# Antes igual le sacábamos otro ítem en cada choque.
		if body.is_penalized:
			return

		# ¡EL CAMBIO MÁGICO! Le mandamos hitbox.global_position
		body.apply_penalty(5.0, hitbox.global_position)
		
		GameManager.perder_ultimo_item()
