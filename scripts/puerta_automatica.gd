extends Area2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
var esta_bloqueada: bool = false # NUEVO CANDADO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	# Si está bloqueada, ignoramos al jugador por completo
	if esta_bloqueada: return 
	
	if body is Player:
		anim_sprite.play("open")

func _on_body_exited(body: Node2D) -> void:
	if esta_bloqueada: return 
	
	if body is Player:
		# Como me dijiste que la animación va y vuelve sola (espejo), 
		# quizás no necesitas reversa, pero por las dudas la detenemos:
		anim_sprite.stop()
		anim_sprite.frame = 0

# NUEVA FUNCIÓN: El nivel llamará a esto para sellar la puerta suavemente
func sellar_puerta() -> void:
	esta_bloqueada = true
	
	# LA OPCIÓN NUCLEAR: Apagamos el radar para que no detecte más al jugador
	set_deferred("monitoring", false)
	
	# Le decimos que reproduzca la animación hacia atrás (se cierra suavemente)
	# Reproducirá desde donde esté abierta hasta llegar al frame 0 solita
	anim_sprite.play_backwards("open")
	
	print("🚨 LA PUERTA HA RECIBIDO LA ORDEN Y SE ESTÁ CERRANDO 🚨")
