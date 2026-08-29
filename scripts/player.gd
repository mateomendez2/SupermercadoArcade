extends CharacterBody2D
class_name Player

@export var speed: float = 250.0
@export var acceleration: float = 1500.0
@export var friction: float = 1200.0
@onready var default_speed: float = speed
@onready var default_friction: float = friction
@onready var default_acceleration: float = acceleration

var is_frozen: bool = false 

# --- SISTEMA DE INTERACCIÓN ---
# Aquí guardaremos el objeto con el que podemos interactuar actualmente
var current_interactable: Interactable = null 

# Referencia al nodo Area2D que creamos (arrastra el nodo desde el árbol aquí manteniendo CTRL)
@onready var interaction_area: Area2D = $InteractionArea

# Referenciamos el nuevo nodo animado
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D 

func _ready() -> void:
	# Conectamos las señales por código (mucho más seguro y limpio que por interfaz gráfica)
	interaction_area.area_entered.connect(_on_area_entered)
	interaction_area.area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if is_frozen:
		anim_sprite.stop() # Si está congelado, detenemos la animación
		return 
		
	move_state(delta)

func move_state(delta: float) -> void:
	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * speed, acceleration * delta)
		update_animation(direction) # Llamamos a nuestra nueva función
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		anim_sprite.stop() # Si no hay dirección, frenamos la animación (se queda en Idle)
		
	move_and_slide()

# --- MÁQUINA DE ANIMACIONES BÁSICA ---
func update_animation(direction: Vector2) -> void:
	# Como direction es un vector, podemos saber hacia dónde va basado en sus ejes X e Y.
	# Le damos prioridad al movimiento horizontal (izquierda/derecha)
	if direction.x > 0:
		anim_sprite.play("walk_right")
		anim_sprite.flip_h = false # Nos aseguramos de que no esté volteado
	elif direction.x < 0:
		# Si no tienes la animación 'walk_left' aún, usamos 'walk_right' pero lo volteamos horizontalmente:
		anim_sprite.play("walk_right") 
		anim_sprite.flip_h = true
	elif direction.y > 0:
		anim_sprite.play("walk_down")
		pass
	elif direction.y < 0:
		anim_sprite.play("walk_up")
		pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable != null:
		
		# Le pedimos el ítem a la góndola (esto activa el item_visual.hide())
		current_interactable.interact()

# --- FUNCIONES DE SEÑALES ---
# Se dispara automáticamente cuando otra área entra en nuestra InteractionArea
func _on_area_entered(area: Area2D) -> void:
	if area is Interactable:
		current_interactable = area
		print("Objeto en rango. Presiona E para interactuar.")

# Se dispara cuando nos alejamos del objeto
func _on_area_exited(area: Area2D) -> void:
	if area == current_interactable:
		current_interactable = null
		print("Saliste del rango del objeto.")

# El charco llamará a esta función
func set_slippery(is_slippery: bool) -> void:
	if is_slippery:
		# Modo Patinaje torpe: 
		# Fricción baja (resbala), Aceleración baja (le cuesta arrancar)...
		friction = 200.0 
		acceleration = 400.0
		# ¡Y cortamos la velocidad a la mitad!
		speed = default_speed / 2.0
	else:
		# Volvemos a la normalidad instantáneamente
		speed = default_speed
		friction = default_friction
		acceleration = default_acceleration
