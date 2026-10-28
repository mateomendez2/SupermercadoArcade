extends Area2D
class_name Interactable

# Aquí es donde pondremos el archivo "apple.tres"
@export var item_content: ItemData 

# Variable para saber si ya agarramos la manzana
var is_empty: bool = false 

# Esto busca el nodo que tiene el dibujo de la manzana
@onready var item_visual: Sprite2D = $ItemVisual
# BUGFIX: Guardamos la altura original y la animación del "pop" para poder cortarla
@onready var item_pos_y_original: float = item_visual.position.y
var pop_tween: Tween

# --- VARIABLES DEL RELOJ Y CASTIGO ---
@export var tiempo_castigo: float = 8.0 # Segundos totales que durará el bloqueo
var fallos: int = 0
var is_locked: bool = false # Para saber si está bloqueada

@onready var cooldown_clock: Sprite2D = $CooldownClock

# NUEVAS VARIABLES PARA LA ANIMACIÓN
@onready var reloj_pos_y_original: float = cooldown_clock.position.y
var reloj_tween: Tween

var minijuego_guardado: String = "" # Puede ser "barrita", "colores" o ""

# --- TIC-TAC DEL RELOJ ---
# Mientras la góndola está bloqueada, si el jugador está parado en su zona se escucha el reloj
const RUTA_TIC: String = "res://assets/audio/RelojTic.wav"
const RUTA_TAC: String = "res://assets/audio/RelojTac.wav"
var sonido_tic: AudioStream
var sonido_tac: AudioStream
const TIEMPO_TIC: float = 0.5   # Medio segundo entre "tic" y "tac"
const VOLUMEN_TIC: float = -10.0
var sonido_reloj: AudioStreamPlayer

# --- MARCA EN EL PISO (ESQUINITAS) ---
# Cuatro esquinitas del color del producto marcan el cuadrado de adelante, donde hay que pararse para agarrarlo.
# Titilan suave. Solo se ven mientras el producto está disponible (no si ya lo agarraste o si está el reloj)
# y cuando el jugador anda cerca.
@export var color_bruma: Color = Color(0, 0, 0, 0) # Color de las esquinitas. Transparente = automático (sale del dibujo del producto)
const CUADRADO_PISO: float = 16.0 # Los cuadraditos del piso: la marca llega hasta la línea que sigue hacia abajo
const ALCANCE_JUGADOR: float = 12.0 # Mitad del alto del área con la que el jugador detecta (para estirar la zona)
const LARGO_ESQUINA: int = 5   # Largo de cada patita de la esquina (en pixeles)
const GROSOR_ESQUINA: int = 2  # Grosor de la esquina
const MARGEN_MARCA: Vector2 = Vector2(3, 2) # Cuánto se abren las esquinas por fuera de la zona (a los costados y abajo)
const MARGEN_ARRIBA: float = -3.0 # Las de arriba van unos pixeles adentro, para no pisar el mueble
const TITILAR_MIN: float = 0.55 # Opacidad más baja del titileo (1 = no titila)
const TITILAR_TIEMPO: float = 0.5 # Segundos de cada ida o vuelta del titileo
var marca: Node2D
var tween_marca: Tween
var marca_prendida: bool = false
# La marca aparece recién cuando el jugador está cerca (no apenas se ve en pantalla)
const DISTANCIA_BRUMA: float = 80.0 # En pixeles (32 = una baldosa). Más grande = aparece desde más lejos
var jugador_cerca: bool = false
var espera_chequeo: float = 0.0

func _ready() -> void:
	# Nos suscribimos a la señal del GameManager para saber cuándo se le cae algo al jugador
	GameManager.item_dropped.connect(_on_item_devuelto)
	sonido_tic = load(RUTA_TIC)
	sonido_tac = load(RUTA_TAC)
	sonido_reloj = AudioStreamPlayer.new()
	sonido_reloj.volume_db = VOLUMEN_TIC
	add_child(sonido_reloj)
	_crear_marca()

# "quien" = el jugador que tocó el botón (en el modo 2 jugadores, para saber de quién es el minijuego)
func interact(quien: Node = null) -> ItemData:
	# NUEVO: Si está bloqueada, no hacemos nada y rechazamos la interacción
	if is_locked:
		print("Góndola: Espera a que termine el castigo.")
		return null
		
	if not is_empty and item_content != null:
		GameManager.request_qte(self, quien)
	else:
		print("Góndola: Ya te llevaste esto, está vacío.")
		
	return null

# Esta función SOLO se llama si el GameManager dice que ganaste el QTE
func succesful_interaction() -> void:
	minijuego_guardado = "" 
	is_empty = true 
	_actualizar_marca()
	
	# --- ¡CAMBIO DE ORDEN! ---
	# Le avisamos al GameManager AL INSTANTE. 
	# Esto dispara la animación del Jugador, el sonido y tacha la libreta.
	print("Góndola: Toma tu ", item_content.item_name)
	GameManager.add_item(item_content)
	# -------------------------
	
	# Y MIENTRAS TANTO, la fruta hace su propio show:
	var pos_original_y = item_pos_y_original
	if pop_tween: pop_tween.kill()
	pop_tween = create_tween()
	
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
	item_visual.position.y = pos_original_y
	# BUGFIX: Acá había un segundo GameManager.add_item() que te devolvía el ítem
	# si un NPC te lo sacaba durante esta animación. Se borró.

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
	_actualizar_marca()
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
	
	_tic_tac() # Arranca el sonido del reloj (solo suena si el jugador está cerca)

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
	_actualizar_marca()
	print("Góndola: ¡Desbloqueada!")

# Cuando el jugador se aleja de la góndola
func _on_area_exited(area: Area2D) -> void:
	
	# NUEVO GUARDIA: ¿El dueño de esta área es el Jugador?
	if area.get_parent() is Player:
		# NUEVO (modo 2 jugadores): si el que se fue estaba jugando el minijuego de esta góndola, se cierra el suyo
		var p: String = area.get_parent().prefijo_acciones
		if p != "":
			if GameManager.gondolas_coop.get(p) == self:
				GameManager.cancelar_qte_jugador(p)
			return
		
		# Si era el jugador, verificamos si estábamos jugando
		if GameManager.gondola_actual == self:
			print("🏃 Góndola: Cerrando por ALEJAMIENTO DEL JUGADOR.")
			GameManager.cancelar_qte()

# Cuando el jugador pierde un ítem por un choque
func _on_item_devuelto(item_perdido: ItemData) -> void:
	# Si esta góndola está vacía, Y su contenido es igual al que el jugador perdió...
	if is_empty and item_content == item_perdido:
		# ¡Magia! Se vuelve a llenar
		is_empty = false

		# BUGFIX: Si la animación del "pop" seguía corriendo, la cortamos
		# (si no, al terminar escondía la fruta y la góndola quedaba "llena pero invisible")
		if pop_tween and pop_tween.is_valid():
			pop_tween.kill()

		item_visual.show()

		# IMPORTANTE: Restauramos el color original por si quedó transparente de la vez que lo agarramos
		item_visual.modulate.a = 1.0
		item_visual.scale = Vector2(1.0, 1.0)
		item_visual.position.y = item_pos_y_original
		_actualizar_marca()
		
		print("Góndola: He recuperado mi ", item_content.item_name)

# Mientras dure el bloqueo, cada medio segundo suena "tic" o "tac" si el jugador está en la zona
func _tic_tac() -> void:
	var agudo := true
	while is_locked:
		if _jugador_cerca():
			sonido_reloj.stream = sonido_tic if agudo else sonido_tac
			sonido_reloj.play()
		agudo = not agudo
		await get_tree().create_timer(TIEMPO_TIC, false).timeout

func _jugador_cerca() -> bool:
	for area in get_overlapping_areas():
		if area.get_parent() is Player:
			return true
	return false

# =====================================================================
# MARCA EN EL PISO (ESQUINITAS)
# =====================================================================
func _crear_marca() -> void:
	var zona: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if zona == null or not zona.shape is RectangleShape2D: return
	var forma: RectangleShape2D = zona.shape
	var arriba: float = zona.position.y - forma.size.y / 2.0
	var abajo: float = zona.position.y + forma.size.y / 2.0
	# La marca baja hasta la línea de cuadraditos del piso que sigue (un cuadradito hacia abajo)
	var arriba_global: float = global_position.y + arriba
	var linea: float = ceilf((arriba_global + CUADRADO_PISO / 2.0) / CUADRADO_PISO) * CUADRADO_PISO
	var abajo_marca: float = linea - global_position.y
	# Estiramos un poco la zona hacia abajo (copia propia, no toca la de las otras góndolas):
	# así, parado en cualquier parte de la marca, el jugador puede agarrar
	var extra: float = maxf(0.0, (abajo_marca - ALCANCE_JUGADOR) - abajo)
	if extra > 0.0:
		var nueva: RectangleShape2D = forma.duplicate()
		nueva.size.y += extra
		zona.shape = nueva
		zona.position.y += extra / 2.0

	# El rectángulo que encierran las esquinas
	var izq: float = round(zona.position.x - forma.size.x / 2.0 - MARGEN_MARCA.x)
	var der: float = round(zona.position.x + forma.size.x / 2.0 + MARGEN_MARCA.x)
	var sup: float = round(arriba - MARGEN_ARRIBA)
	var inf: float = round(abajo_marca + MARGEN_MARCA.y)

	var tono: Color = color_bruma if color_bruma.a > 0.0 else _color_del_producto()
	var textura = _textura_esquina(tono)
	var tam: float = textura.get_width()
	marca = Node2D.new()
	marca.name = "Marca"
	marca.z_index = 0 # Pegada al piso: el jugador pasa por encima
	marca.modulate.a = 0.0
	add_child(marca)
	# Una esquina por cada punta, dada vuelta según corresponda
	for punta in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var esquina = Sprite2D.new()
		esquina.texture = textura
		esquina.centered = false
		esquina.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		esquina.flip_h = punta.x == 1
		esquina.flip_v = punta.y == 1
		esquina.position = Vector2(izq - 1 if punta.x == 0 else der - tam + 1, sup - 1 if punta.y == 0 else inf - tam + 1)
		marca.add_child(esquina)
	_actualizar_marca()

# Prendida solo si el producto se puede agarrar y el jugador está cerca
func _actualizar_marca() -> void:
	if marca == null: return
	var prender: bool = jugador_cerca and not is_empty and not is_locked and item_content != null
	if prender == marca_prendida: return
	marca_prendida = prender
	if tween_marca: tween_marca.kill()
	tween_marca = create_tween()
	if prender:
		# Aparece y queda titilando suave
		tween_marca.tween_property(marca, "modulate:a", 1.0, 0.15)
		tween_marca.tween_callback(_titilar)
	else:
		tween_marca.tween_property(marca, "modulate:a", 0.0, 0.15)

func _titilar() -> void:
	if tween_marca: tween_marca.kill()
	tween_marca = create_tween().set_loops()
	tween_marca.tween_property(marca, "modulate:a", TITILAR_MIN, TITILAR_TIEMPO).set_trans(Tween.TRANS_SINE)
	tween_marca.tween_property(marca, "modulate:a", 1.0, TITILAR_TIEMPO).set_trans(Tween.TRANS_SINE)

# Cada un ratito nos fijamos si el jugador se acercó o se alejó
func _process(delta: float) -> void:
	if marca == null: return
	espera_chequeo -= delta
	if espera_chequeo > 0.0: return
	espera_chequeo = 0.15
	# Se prende si CUALQUIER jugador anda cerca (en el modo 2 jugadores son dos)
	var centro: Vector2 = marca.global_position + _centro_marca()
	var cerca: bool = false
	for jugador in get_tree().get_nodes_in_group("Player"):
		if jugador.global_position.distance_to(centro) < DISTANCIA_BRUMA:
			cerca = true
			break
	if cerca != jugador_cerca:
		jugador_cerca = cerca
		_actualizar_marca()

func _centro_marca() -> Vector2:
	var zona: CollisionShape2D = get_node_or_null("CollisionShape2D")
	return zona.position if zona else Vector2.ZERO

# El color sale del dibujo del producto: el promedio de sus colores más vivos, aclarado
func _color_del_producto() -> Color:
	var defecto = Color(0.75, 0.9, 1.0)
	if item_content == null or item_content.icon == null: return defecto
	var img: Image = item_content.icon.get_image()
	if img == null: return defecto
	if img.is_compressed(): img.decompress()
	var suma = Vector3.ZERO
	var peso_total = 0.0
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5: continue
			var peso = c.s * c.v + 0.02 # Pesan más los colores vivos (no el borde negro ni lo gris)
			suma += Vector3(c.r, c.g, c.b) * peso
			peso_total += peso
	if peso_total <= 0.0: return defecto
	var promedio = Color(suma.x / peso_total, suma.y / peso_total, suma.z / peso_total)
	# Bien vivo y clarito, para que se vea sobre el piso
	return Color.from_hsv(promedio.h, clampf(promedio.s, 0.45, 0.75), 1.0)

# Dibuja una esquina (forma de L) del color pedido, con un borde oscuro alrededor.
# Es la de arriba a la izquierda; las otras tres se dan vuelta.
func _textura_esquina(tono: Color) -> ImageTexture:
	var tam: int = LARGO_ESQUINA + 2
	var img = Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var borde: Color = tono.darkened(0.7)
	var dentro = func(x: int, y: int) -> bool:
		x -= 1; y -= 1
		if x < 0 or y < 0 or x >= LARGO_ESQUINA or y >= LARGO_ESQUINA: return false
		return x < GROSOR_ESQUINA or y < GROSOR_ESQUINA
	for y in tam:
		for x in tam:
			if dentro.call(x, y):
				img.set_pixel(x, y, tono)
			else:
				for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
					if dentro.call(x + v.x, y + v.y):
						img.set_pixel(x, y, borde)
						break
	return ImageTexture.create_from_image(img)
