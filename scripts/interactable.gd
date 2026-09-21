extends Area2D
class_name Interactable

# Aquí es donde pondremos el archivo "apple.tres"
@export var item_content: ItemData 

# Variable para saber si ya agarramos la manzana
var is_empty: bool = false 

# Esto busca el nodo que tiene el dibujo de la manzana
@onready var item_visual: Sprite2D = $ItemVisual 

# --- VARIABLES DEL RELOJ Y CASTIGO ---
@export var tiempo_castigo: float = 8.0 # Segundos totales que durará el bloqueo
var fallos: int = 0
var is_locked: bool = false # Para saber si está bloqueada

@onready var cooldown_clock: Sprite2D = $CooldownClock

# NUEVAS VARIABLES PARA LA ANIMACIÓN
@onready var reloj_pos_y_original: float = cooldown_clock.position.y
var reloj_tween: Tween

var minijuego_guardado: String = "" # Puede ser "barrita", "colores" o ""

func interact() -> ItemData:
	# NUEVO: Si está bloqueada, no hacemos nada y rechazamos la interacción
	if is_locked:
		print("Góndola: Espera a que termine el castigo.")
		return null
		
	if not is_empty and item_content != null:
		GameManager.request_qte(self) 
	else:
		print("Góndola: Ya te llevaste esto, está vacío.")
		
	return null

# Esta función SOLO se llama si el GameManager dice que ganaste el QTE
func succesful_interaction() -> void:
	minijuego_guardado = "" 
	is_empty = true 
	
	# --- ¡CAMBIO DE ORDEN! ---
	# Le avisamos al GameManager AL INSTANTE. 
	# Esto dispara la animación del Jugador, el sonido y tacha la libreta.
	print("Góndola: Toma tu ", item_content.item_name)
	GameManager.add_item(item_content)
	# -------------------------
	
	# Y MIENTRAS TANTO, la fruta hace su propio show:
	var pos_original_y = item_visual.position.y
	var pop_tween = create_tween()
	
	pop_tween.set_parallel(true)
	pop_tween.tween_property(item_visual, "position:y", pos_original_y - 30.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(item_visual, "scale", Vector2(1.5, 1.5), 0.3)
	
	pop_tween.chain() 
	pop_tween.tween_interval(0.4) 
	
	pop_tween.set_parallel(true) 
	pop_tween.tween_property(item_visual, "position:y", pos_original_y - 15.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pop_tween.tween_property(item_visual, "modulate:a", 0.0, 0.3)
	
	await pop_tween.finished
	item_visual.hide()

# El GameManager llamará a esta función si pierdes TODO el minijuego
func failed_interaction() -> void:
	# Como el minijuego ya contó los 5 fallos adentro suyo, 
	# si llegamos acá significa que se agotaron las oportunidades.
	# ¡Bloqueamos directamente!
	print("Góndola: Agotaste los intentos. ¡Bloqueando!")
	iniciar_cooldown()

# La rutina que bloquea y anima el reloj
func iniciar_cooldown() -> void:
	is_locked = true
	cooldown_clock.show()
	
	# --- EFECTO VISUAL: SUBIR Y BAJAR (FLOTAR) ---
	reloj_tween = create_tween().set_loops() # Bucle infinito
	
	# Sube 6 píxeles usando una curva matemática suave (SINE)
	reloj_tween.tween_property(cooldown_clock, "position:y", reloj_pos_y_original - 6.0, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Baja a la posición original suavemente
	reloj_tween.tween_property(cooldown_clock, "position:y", reloj_pos_y_original, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# ---------------------------------------------
	
	var tiempo_por_frame = tiempo_castigo / float(cooldown_clock.hframes)
	
	for i in range(cooldown_clock.hframes):
		cooldown_clock.frame = i 
		await get_tree().create_timer(tiempo_por_frame).timeout 
		
	# --- LIMPIEZA AL TERMINAR EL CASTIGO ---
	if reloj_tween:
		reloj_tween.kill() # Destruimos la animación de flotar
		
	cooldown_clock.position.y = reloj_pos_y_original # Lo devolvemos a su lugar exacto por si quedó a la mitad
	cooldown_clock.hide()
	cooldown_clock.frame = 0 
	fallos = 0 
	is_locked = false
	print("Góndola: ¡Desbloqueada!")

# Cuando el jugador se aleja de la góndola
func _on_area_exited(area: Area2D) -> void:
	
	# NUEVO GUARDIA: ¿El dueño de esta área es el Jugador?
	if area.get_parent() is Player:
		
		# Si era el jugador, verificamos si estábamos jugando
		if GameManager.gondola_actual == self:
			print("🏃 Góndola: Cerrando por ALEJAMIENTO DEL JUGADOR.")
			GameManager.cancelar_qte()
