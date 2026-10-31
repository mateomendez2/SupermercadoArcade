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
var fin_turno_ms: int = 0 # Cuándo termina el turno actual (para saber cuánto le queda)

# --- LÍMITES DE LA CÁMARA ---
const ALTO_FRANJA_MUNDO: int = 14
@export var cam_limite_arriba: int = -64
@export var cam_limite_abajo: int = 384
@export var cam_limite_izquierdo: int = 0
@export var cam_limite_derecho: int = 640

# --- RELOJ VERDE DE TIEMPO EXTRA (NUEVO) ---
# Cada tanto aparece un cronómetro verde en un lugar al azar del piso: si lo tocás, suma tiempo.
# En el modo de 1 jugador sale recién desde el nivel 5 (GameManager.RELOJES_DESDE_EL_NIVEL);
# en el de 2 jugadores, en todos. Con la casilla de abajo se puede apagar en un nivel.
@export_group("Reloj de tiempo extra")
@export var con_relojes_de_tiempo: bool = true
@export var segundos_por_reloj: int = 25     # Cuánto tiempo suma cada uno
@export var primer_reloj_a_los: float = 60.0 # Segundos de juego hasta que aparece el primero
@export var reloj_cada_min: float = 60.0     # Después de agarrarlo, el próximo tarda entre esto...
@export var reloj_cada_max: float = 60.0     # ...y esto
@export var reloj_dura: float = 0.0          # Cuánto se queda si nadie lo agarra. 0 = se queda hasta que lo agarren
@export_group("")
const RelojesTiempo = preload("res://scripts/relojes_tiempo.gd")

func _ready() -> void:
	# NUEVO: Los relojes verdes de tiempo extra
	if con_relojes_de_tiempo:
		var relojes = RelojesTiempo.new()
		relojes.name = "RelojesDeTiempo"
		relojes.segundos_por_reloj = segundos_por_reloj
		relojes.primer_reloj_a_los = primer_reloj_a_los
		relojes.reloj_cada_min = reloj_cada_min
		relojes.reloj_cada_max = reloj_cada_max
		relojes.reloj_dura = reloj_dura
		add_child(relojes)
	# 0. AJUSTAMOS LA CÁMARA PRIMERO
	var camara = jugador.get_node("Camera2D")
	if camara:
		# NUEVO: La franja de arriba tapa 28 pixeles de pantalla = 14 del mundo (zoom x2).
		# Dejamos subir la cámara 14 más, así lo de arriba del mapa no queda escondido detrás.
		camara.limit_top = cam_limite_arriba - ALTO_FRANJA_MUNDO
		camara.limit_bottom = cam_limite_abajo
		camara.limit_left = cam_limite_izquierdo
		camara.limit_right = cam_limite_derecho
		
	# -------------------------------------------------------------
	# 1. ¡ARRANCA EL JUEGO OFICIAL Y LA LIBRETA GIGANTE!
	# -------------------------------------------------------------
	GameManager.item_collected.connect(_on_item_recolectado)
	GameManager.iniciar_nivel(frutas_del_nivel, tiempo_del_nivel)
	
	# -------------------------------------------------------------
	# 2. SETUP DE OBSTÁCULOS 
	# -------------------------------------------------------------
	var todas_las_cajas = get_tree().get_nodes_in_group("CajasObstaculo")
	for caja in todas_las_cajas:
		if self.is_ancestor_of(caja):
			mis_cajas.append(caja)
			
	var todos_los_charcos = get_tree().get_nodes_in_group("CharcosObstaculo")
	for charco in todos_los_charcos:
		if self.is_ancestor_of(charco):
			mis_charcos.append(charco)
			
	tex_aviso = load(RUTA_AVISO)
	# Al empezar el nivel los obstáculos ya están puestos (sin cartel de aviso)
	_poner_al_empezar()
	
	# -------------------------------------------------------------
	# 3. CINEMÁTICA DE ENTRADA DEL JUGADOR
	# -------------------------------------------------------------
	jugador.is_frozen = true

	# NUEVO: Si la pantalla está en negro con el cartel "NIVEL X", esperamos a que se disuelva.
	# Primero esperamos 1 frame: en el Tutorial, la UI se prepara DESPUÉS que el nivel.
	# (Si probás el nivel solo con F6 no hay UI, así que no espera nada)
	await get_tree().process_frame
	if GameManager.mostrando_cartel:
		await GameManager.cartel_nivel_terminado

	# NUEVO (modo 2 jugadores): si está el jugador 2, entran los dos en fila
	var jugador_2 = get_node_or_null("Player2")
	if jugador_2:
		await _entrada_de_a_dos(jugador_2)
	else:
		jugador.anim_sprite.play("walk_down")

		var intro_tween = create_tween()
		var destino_y = jugador.position.y + 64.0 
		intro_tween.tween_property(jugador, "position:y", destino_y, 1.5)
		
		await intro_tween.finished
	
	jugador.last_direction = Vector2(0, 1)
	jugador.update_animation(false)
	jugador.is_frozen = false

	# BUGFIX: Recién ahora que el jugador se puede mover, arranca el reloj
	GameManager.arrancar_reloj()

	var puerta = get_tree().get_first_node_in_group("PuertaEntrada")
	if puerta and puerta.has_method("sellar_puerta"):
		puerta.sellar_puerta()
	
	# Prendemos el reloj de los obstáculos AL FINAL
	bucle_de_tiempo_aleatorio()
	
# =====================================================================
# ENTRADA DE LOS DOS JUGADORES (modo 2 jugadores)
# =====================================================================
# Pasan la puerta en fila (el 2 viene atrás del 1, a la misma velocidad de siempre).
# Al llegar, el 1 se corre un poquito a la izquierda y el 2 un poquito a la derecha,
# y quedan los dos mirando para abajo.
const ENTRADA_BAJADA: float = 64.0    # Cuánto bajan desde la puerta (igual que en el modo de un jugador)
const ENTRADA_TIEMPO: float = 1.5     # En cuánto tiempo baja el jugador 1 esos 64 pixeles
const ENTRADA_COSTADO: float = 14.0   # Cuánto se corre cada uno para su lado al final
const ENTRADA_TIEMPO_COSTADO: float = 0.3

func _entrada_de_a_dos(jugador_2: Node2D) -> void:
	var velocidad: float = ENTRADA_BAJADA / ENTRADA_TIEMPO
	var llegada_y: float = jugador.position.y + ENTRADA_BAJADA
	var tiempo_2: float = (llegada_y - jugador_2.position.y) / velocidad # El 2 viene de más atrás
	_caminar_y_correrse(jugador, llegada_y, ENTRADA_TIEMPO, -ENTRADA_COSTADO)
	await _caminar_y_correrse(jugador_2, llegada_y, tiempo_2, ENTRADA_COSTADO)
	jugador_2.last_direction = Vector2(0, 1)
	jugador_2.update_animation(false)
	jugador_2.is_frozen = false

# Baja hasta llegada_y, después da un pasito al costado (negativo = izquierda) y queda mirando abajo
func _caminar_y_correrse(quien: Node2D, llegada_y: float, tiempo: float, costado: float) -> void:
	quien.is_frozen = true
	quien.anim_sprite.play("walk_down")
	var t = create_tween()
	t.tween_property(quien, "position:y", llegada_y, tiempo)
	t.tween_callback(func(): quien.anim_sprite.play("walk_left" if costado < 0 else "walk_right"))
	t.tween_property(quien, "position:x", quien.position.x + costado, ENTRADA_TIEMPO_COSTADO)
	t.tween_callback(func(): quien.anim_sprite.play("idle_down"))
	await t.finished

# =====================================================================
# OBSTÁCULOS QUE CAMBIAN DE LUGAR (cajas y charcos)
# =====================================================================
# Cómo es cada cambio:
#  1. Aparecen carteles amarillos de aviso donde van a estar los obstáculos NUEVOS.
#     Mientras tanto, los de ahora siguen en su lugar.
#  2. A los TIEMPO_AVISO segundos, en el mismo instante: los viejos se van y aparecen los nuevos.
# Pasa al final de cada turno (cada 15 a 25 segundos) y cuando agarrás un producto.

const RUTA_AVISO: String = "res://assets/ui/aviso_peligro.png"
const TIEMPO_AVISO: float = 3.0          # Segundos de aviso antes del cambio
const DISTANCIA_LIBRE_CAJA: float = 26.0 # Si estás parado donde va una caja, espera a que te corras
var tex_aviso: Texture2D
var cambio_pendiente: bool = false       # Hay carteles puestos esperando el cambio

# Al empezar el nivel: los obstáculos ya están puestos, sin carteles
func _poner_al_empezar() -> void:
	cajas_viejas = _elegir(mis_cajas, [], cajas_activas, true)
	charcos_viejos = _elegir(mis_charcos, [], charcos_activos, false)
	for caja in mis_cajas:
		_encender_caja(caja, caja in cajas_viejas)
	for charco in mis_charcos:
		_encender_charco(charco, charco in charcos_viejos)

# Elige al azar cuáles se prenden: nunca los mismos que están ahora,
# y las cajas tampoco pegadas al jugador
func _elegir(todos: Array, actuales: Array, cantidad: int, lejos_del_jugador: bool) -> Array:
	var candidatos = todos.duplicate()
	candidatos.shuffle()
	var elegidos: Array = []
	for obstaculo in candidatos:
		if elegidos.size() >= cantidad: break
		if obstaculo in actuales: continue
		if lejos_del_jugador and jugador != null and obstaculo.global_position.distance_to(jugador.global_position) < 60.0:
			continue
		elegidos.append(obstaculo)
	return elegidos

func _encender_caja(caja: Node2D, prender: bool) -> void:
	caja.visible = prender
	caja.process_mode = Node.PROCESS_MODE_INHERIT if prender else Node.PROCESS_MODE_DISABLED

func _encender_charco(charco: Node2D, prender: bool) -> void:
	charco.visible = prender
	charco.process_mode = Node.PROCESS_MODE_INHERIT if prender else Node.PROCESS_MODE_DISABLED
	# Le avisamos al charco cuánto tiempo tiene para animarse (lo que queda hasta el próximo cambio)
	if prender and charco.has_method("animar_ciclo"):
		charco.animar_ciclo(_tiempo_que_queda_del_turno())

# PASO 1: carteles donde van a estar los nuevos (los de ahora siguen ahí)
func preparar_cambio() -> void:
	if cambio_pendiente: return # Ya hay un cambio en camino: no hace falta otro
	cambio_pendiente = true
	var nuevas_cajas = _elegir(mis_cajas, cajas_viejas, cajas_activas, true)
	var nuevos_charcos = _elegir(mis_charcos, charcos_viejos, charcos_activos, false)
	var carteles: Dictionary = {} # obstáculo -> su cartel
	for obstaculo in nuevas_cajas + nuevos_charcos:
		carteles[obstaculo] = _poner_cartel(obstaculo)
	# Los charcos de ahora terminan de secarse justo en el momento del cambio
	for charco in charcos_viejos:
		if charco.visible and charco.has_method("ajustar_vida"):
			charco.ajustar_vida(TIEMPO_AVISO)
	await get_tree().create_timer(TIEMPO_AVISO).timeout
	_hacer_cambio(nuevas_cajas, nuevos_charcos, carteles)

# PASO 2: en el mismo instante se van los viejos y aparecen los nuevos
func _hacer_cambio(nuevas_cajas: Array, nuevos_charcos: Array, carteles: Dictionary) -> void:
	cambio_pendiente = false
	if not GameManager.juego_activo: # Se terminó el nivel mientras tanto: solo sacamos los carteles
		for cartel in carteles.values(): _sacar_cartel(cartel)
		return
	for caja in cajas_viejas: _encender_caja(caja, false)
	for charco in charcos_viejos: _encender_charco(charco, false)
	cajas_viejas = nuevas_cajas
	charcos_viejos = nuevos_charcos
	for charco in nuevos_charcos:
		_sacar_cartel(carteles[charco])
		_encender_charco(charco, true)
	for caja in nuevas_cajas:
		_aparecer_caja_cuando_se_pueda(caja, carteles[caja])

# Una caja no puede aparecer encima tuyo: si estás parado ahí, el cartel sigue hasta que te corras
func _aparecer_caja_cuando_se_pueda(caja: Node2D, cartel: Sprite2D) -> void:
	if not caja in cajas_viejas or not GameManager.juego_activo:
		_sacar_cartel(cartel) # Mientras esperaba ya hubo otro cambio: esta caja no va más
		return
	if _hay_alguien_cerca(caja.global_position):
		var otra_vez = cartel.create_tween()
		otra_vez.tween_interval(0.2)
		otra_vez.tween_callback(_aparecer_caja_cuando_se_pueda.bind(caja, cartel))
		return
	_sacar_cartel(cartel)
	_encender_caja(caja, true)

# ¿Hay algún jugador (o el guardia del modo 2 jugadores) parado donde va la caja?
func _hay_alguien_cerca(lugar: Vector2) -> bool:
	for quien in get_tree().get_nodes_in_group("Player") + get_tree().get_nodes_in_group("Guardia"):
		if is_ancestor_of(quien) and quien.global_position.distance_to(lugar) < DISTANCIA_LIBRE_CAJA:
			return true
	return false

# --- LOS GATILLOS (lo que provoca un cambio) ---

# Gatillo 1: Cuando agarramos un producto
func _on_item_recolectado(_item: ItemData) -> void:
	print("¡Producto agarrado! Preparando cambio de obstáculos...")
	preparar_cambio()

# Gatillo 2: El tiempo. Los carteles salen TIEMPO_AVISO segundos antes de que termine el turno,
# así el cambio pasa justo al final.
func bucle_de_tiempo_aleatorio() -> void:
	# En el PRIMER turno, los charcos que ya están puestos se acomodan para secarse justo
	# cuando termina (aparecieron antes, durante la entrada del jugador)
	if fin_turno_ms == 0:
		for charco in mis_charcos:
			if charco.visible and charco.has_method("ajustar_vida"):
				charco.ajustar_vida(duracion_turno_actual)

	# Anotamos cuándo termina este turno
	fin_turno_ms = Time.get_ticks_msec() + int(duracion_turno_actual * 1000.0)

	# Esperamos hasta un poco antes del final (lo que dura el aviso)
	await get_tree().create_timer(maxf(0.1, duracion_turno_actual - TIEMPO_AVISO)).timeout
	if not GameManager.juego_activo: return

	print("¡Evento de Tiempo! Preparando cambio de obstáculos...")
	# Sorteamos el PRÓXIMO turno antes de preparar el cambio: arranca justo cuando pasa el cambio
	duracion_turno_actual = randf_range(15.0, 25.0)
	fin_turno_ms = Time.get_ticks_msec() + int((TIEMPO_AVISO + duracion_turno_actual) * 1000.0)
	preparar_cambio()

	await get_tree().create_timer(TIEMPO_AVISO).timeout
	if GameManager.juego_activo:
		bucle_de_tiempo_aleatorio()

# Cuánto falta para el próximo cambio. Así los charcos se secan justo antes de que pase.
func _tiempo_que_queda_del_turno() -> float:
	if fin_turno_ms == 0:
		return duracion_turno_actual
	return maxf(3.0, (fin_turno_ms - Time.get_ticks_msec()) / 1000.0)

# --- CARTEL DE AVISO ---
# El cartelito amarillo de peligro, rebotando 1 pixel, en el lugar donde va a aparecer algo
func _poner_cartel(obstaculo: Node2D) -> Sprite2D:
	var cartel = Sprite2D.new()
	cartel.texture = tex_aviso
	cartel.offset = Vector2(0, -7) # La punta de abajo del cartel queda sobre el lugar
	cartel.position = to_local(obstaculo.global_position)
	cartel.scale = Vector2(0.3, 0.3)
	add_child(cartel)
	# Aparece con un saltito
	var entrada = cartel.create_tween()
	entrada.tween_property(cartel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Rebota arriba y abajo, solo 1 pixel
	var rebote = cartel.create_tween().set_loops()
	rebote.tween_interval(0.35)
	rebote.tween_callback(func(): cartel.offset.y = -8)
	rebote.tween_interval(0.35)
	rebote.tween_callback(func(): cartel.offset.y = -7)
	return cartel

func _sacar_cartel(cartel: Sprite2D) -> void:
	if not is_instance_valid(cartel): return
	var salida = cartel.create_tween()
	salida.tween_property(cartel, "scale", Vector2.ZERO, 0.1)
	salida.tween_callback(cartel.queue_free)
