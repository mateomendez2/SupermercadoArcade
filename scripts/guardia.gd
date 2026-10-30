extends Node2D
## GUARDIA DE SEGURIDAD (modo 2 jugadores - ROBO)
##
## QUÉ HACE:
##   - Arranca en el medio del súper y, cuando empieza el reloj, patrulla: camina a un lugar al azar,
##     se para, mira para los dos lados y elige otro lugar.
##   - En el piso se ve su visión: una V roja. Las góndolas, paredes y muebles la cortan
##     (si estás detrás de una góndola, no te ve).
##   - Arriba de la cabeza tiene una carita: verde (tranquilo), naranja (te está buscando) o roja (te vio).
##   - Si te ve: suena la alerta, se pone la carita roja y te persigue. Su V se agranda un poco.
##     Camina apenitas más lento que vos (68 contra 75), así que se lo puede perder.
##   - Si te deja de ver un ratito, va hasta donde te vio por última vez y te busca mirando
##     para los costados. Si no te encuentra, vuelve a patrullar.
##   - Si una cámara de seguridad te ve, le avisa: se pone en amarillo y va a ese lugar (camara_seguridad.gd).
##   - Mientras te persigue, cada tanto toca el silbato (como diciendo "¡alto!").
##   - Si te agarra (te toca): silbato, se le caen 2 productos de la lista al azar, te lleva caminando hasta la puerta, salís, aparece el reloj
##     arriba de la puerta y después volvés a entrar como al principio del nivel.
##     Al volver, por unos segundos no te puede agarrar (parpadeás).
##   - Mientras lleva a uno, no vigila: el otro puede seguir robando tranquilo.
##
## Al lado de los carteles J1 y J2 se ve cómo está cada uno con el guardia (lo pone juego_coop.gd):
##   carita verde = tranquilo, naranja = te está buscando, roja = te vio (o te agarró).
##
## Si el nivel tiene un nodo con este script (grupo "Guardia"), se usa ese y se puede poner
## en el editor donde arranca. Si no, juego_coop.gd lo pone solo en el medio del súper.

signal estado_jugador(prefijo: String, estado: String) # estado: "tranquilo", "buscando" o "visto"

const Mapa = preload("res://scripts/mapa_caminos.gd")
const ANIMACIONES: SpriteFrames = preload("res://assets/guardia/guardia.tres")
# Su carita arriba de la cabeza (verde = tranquilo, naranja = te está buscando, roja = te vio)
const CARAS: Dictionary = {
	"tranquilo": preload("res://assets/ui/guardia/cabeza_tranquilo.png"),
	"buscando": preload("res://assets/ui/guardia/cabeza_buscando.png"),
	"visto": preload("res://assets/ui/guardia/cabeza_visto.png"),
}
const RELOJ: Texture2D = preload("res://assets/relojdetiempo.png") # El mismo reloj de las góndolas
const RUTA_ALERTA: String = "res://assets/audio/GuardiaAlerta.wav"
const RUTA_SILBATO: String = "res://assets/audio/GuardiaSilbato.wav"
@export var silbato_cada_min: float = 2.8 # Mientras persigue, toca el silbato cada tanto (entre estos segundos)
@export var silbato_cada_max: float = 4.5
const RUTA_TIC: String = "res://assets/audio/RelojTic.wav"
const RUTA_TAC: String = "res://assets/audio/RelojTac.wav"

# --- VELOCIDADES (los ladrones caminan a 75) ---
@export var velocidad_patrulla: float = 40.0
@export var velocidad_persecucion: float = 68.0
@export var velocidad_llevando: float = 50.0 # Cuando te lleva a la puerta

# --- VISIÓN (la V del piso) ---
@export var alcance_vision: float = 80.0      # Hasta dónde ve (en pixeles del mundo)
@export var apertura_vision: float = 60.0     # Qué tan abierta es la V (en grados)
@export var alcance_persiguiendo: float = 104.0 # Cuando te vio, la V se agranda
@export var apertura_persiguiendo: float = 80.0
@export var tiempo_para_perderte: float = 1.0 # Si no te ve durante este tiempo, te perdió
@export var tiempo_buscando: float = 3.0      # Lo que te busca mirando para los costados
@export var distancia_agarre: float = 12.0    # Si te toca, te agarra

# --- CUANDO TE AGARRA ---
@export var tiempo_afuera: float = 5.0   # Lo que tarda el reloj antes de que vuelvas a entrar
@export var tiempo_intocable: float = 2.5 # Al volver a entrar, no te puede agarrar por este tiempo
@export var items_que_pierde: int = 2 # Cuántos productos de la lista se le caen al que agarra

const COLOR_V: Color = Color(1.0, 0.12, 0.10, 0.20)
const COLOR_V_BORDE: Color = Color(1.0, 0.22, 0.18, 0.70)
const COLOR_V_PERSIGUE: Color = Color(1.0, 0.10, 0.08, 0.32)
const COLOR_V_PERSIGUE_BORDE: Color = Color(1.0, 0.30, 0.25, 0.95)
const RAYOS_V: int = 20
const DISTANCIA_DETRAS: float = 18.0 # Cuando te lleva, va así de atrás tuyo

enum { QUIETO, PATRULLA, MIRANDO, PERSIGUE, BUSCA, LLEVANDO }
var estado: int = QUIETO

var nivel: Node2D
var mapa: Mapa
var jugadores: Array = []
var npcs_que_caminan: Array = [] # Las "hitbox" de los clientes que caminan (el guardia les da paso)
var puerta: Node2D
var sprite: AnimatedSprite2D
var cono: Cono
var cara: Sprite2D # Su carita arriba de la cabeza
var sonido_alerta: AudioStreamPlayer
var sonido_silbato: AudioStreamPlayer
var t_silbato: float = 0.0

var camino := PackedVector2Array()
var i_camino: int = 0
var mirada: float = PI / 2.0 # Para dónde mira (ángulo; PI/2 = abajo)
var mirada_objetivo: float = PI / 2.0
var mirada_base: float = 0.0
var t_estado: float = 0.0
var t_giro: float = 0.0
var t_cajas: float = 0.0
var t_recalcular: float = 0.0
var t_esperando_npc: float = 0.0
var ya_esquivo: bool = false
var alcance_actual: float = 80.0
var apertura_actual: float = 60.0
var direccion_anim := Vector2.DOWN

var objetivo: Player = null # A quién persigue o busca
var ultimo_visto := Vector2.ZERO
var tiempo_sin_ver: float = 0.0
var buscando_en_el_lugar: bool = false
var por_camara: bool = false # La búsqueda la empezó una cámara
var vistos: Array = []
var estados_avisados: Dictionary = {}
var intocables: Dictionary = {} # jugador -> segundos que le quedan

# Cuando te lleva a la puerta
var llevando: Player = null
var fase_llevar: String = ""
var camino_llevar := PackedVector2Array()
var i_llevar: int = 0
var rastro: Array[Vector2] = []

# =====================================================================
# PREPARACIÓN
# =====================================================================
func _ready() -> void:
	add_to_group("Guardia")
	y_sort_enabled = true
	cono = Cono.new()
	cono.z_index = -1 # En el piso: abajo de los personajes y las góndolas
	add_child(cono)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = ANIMACIONES
	sprite.position = Vector2(0, -9) # Igual que los jugadores
	sprite.play("idle_down")
	add_child(sprite)
	cara = Sprite2D.new()
	cara.position = Vector2(0, -32) # Justo arriba de la gorra
	cara.z_index = 20
	cara.texture = CARAS["tranquilo"]
	add_child(cara)
	sonido_alerta = _sonido(RUTA_ALERTA, -3.0)
	sonido_silbato = _sonido(RUTA_SILBATO, -6.0)
	alcance_actual = alcance_vision
	apertura_actual = apertura_vision
	_preparar.call_deferred()

func _sonido(ruta: String, volumen: float) -> AudioStreamPlayer:
	var s = AudioStreamPlayer.new()
	if ResourceLoader.exists(ruta): s.stream = load(ruta)
	s.volume_db = volumen
	add_child(s)
	return s

func _preparar() -> void:
	nivel = get_parent()
	# Esperamos a que la física tenga todo el nivel cargado
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree(): return
	for j in get_tree().get_nodes_in_group("Player"):
		if nivel.is_ancestor_of(j): jugadores.append(j)
	for p in get_tree().get_nodes_in_group("PuertaEntrada"):
		if nivel.is_ancestor_of(p): puerta = p
	for n in nivel.find_children("*", "Node2D", true, false):
		if n.get_script() and str(n.get_script().resource_path).ends_with("npc_movil.gd"):
			npcs_que_caminan.append(n.get_node("%Hitbox"))
	var mascara: int = jugadores[0].collision_mask if not jugadores.is_empty() else 1
	mapa = Mapa.new()
	mapa.armar(nivel, get_world_2d().direct_space_state, global_position, mascara)
	global_position = mapa.centro(mapa.libre_cercana(global_position))
	for j in jugadores: _avisar(j, "tranquilo")

# =====================================================================
# CADA CUADRO
# =====================================================================
func _physics_process(delta: float) -> void:
	if mapa == null: return
	t_cajas += delta
	if t_cajas >= 0.5:
		t_cajas = 0.0
		mapa.actualizar_cajas()
	for j in intocables.keys():
		intocables[j] -= delta
		if intocables[j] <= 0.0: intocables.erase(j)

	# El guardia trabaja mientras corre el reloj (no antes de que entren, ni cuando se escapan o se acaba el tiempo:
	# al escaparse, salida_coop.gd frena el reloj)
	if not GameManager.juego_activo:
		if estado != QUIETO and estado != LLEVANDO: _quedarse_quieto()
		_actualizar_cono(delta)
		return

	match estado:
		QUIETO: _empezar_patrulla()
		PATRULLA: _patrullar(delta)
		MIRANDO: _mirar_alrededor(delta)
		PERSIGUE: _perseguir(delta)
		BUSCA: _buscar(delta)
		LLEVANDO: _llevar(delta)
	if estado != LLEVANDO:
		_vigilar(delta)
	_girar_mirada(delta)
	_actualizar_cono(delta)
	for j in jugadores: _avisar(j, _estado_de(j))

func _quedarse_quieto() -> void:
	estado = QUIETO
	objetivo = null
	_poner_cara("tranquilo")
	_animar(Vector2.ZERO)

# =====================================================================
# PATRULLA
# =====================================================================
func _empezar_patrulla() -> void:
	estado = PATRULLA
	objetivo = null
	_poner_cara("tranquilo")
	_ir_a(mapa.lugar_al_azar(global_position, 96.0))

func _patrullar(delta: float) -> void:
	if _caminar(delta, velocidad_patrulla, true):
		estado = MIRANDO
		t_estado = randf_range(0.9, 1.8)
		t_giro = 0.0
		mirada_base = mirada

# Parado: mira para un lado y para el otro
func _mirar_alrededor(delta: float) -> void:
	t_estado -= delta
	t_giro += delta
	mirada_objetivo = mirada_base + sin(t_giro * 2.2) * deg_to_rad(60.0)
	_animar_mirando()
	if t_estado <= 0.0: _empezar_patrulla()

# =====================================================================
# VISIÓN
# =====================================================================
func _vigilar(delta: float) -> void:
	vistos = jugadores.filter(func(j): return _lo_ve(j))
	# ¿Tocó a alguno? Lo agarra
	for j in jugadores:
		if _se_puede_agarrar(j) and global_position.distance_to(j.global_position) < distancia_agarre:
			_agarrar(j)
			return
	if estado == PERSIGUE:
		if vistos.has(objetivo):
			ultimo_visto = objetivo.global_position
			tiempo_sin_ver = 0.0
		else:
			tiempo_sin_ver += delta
			if tiempo_sin_ver >= tiempo_para_perderte:
				# Si está viendo al otro, se va atrás de ese; si no, te busca
				if not vistos.is_empty(): _empezar_persecucion(_el_mas_cerca(vistos))
				else: _empezar_busqueda()
	elif not vistos.is_empty():
		_empezar_persecucion(_el_mas_cerca(vistos))

func _lo_ve(j: Node2D) -> bool:
	if not _se_puede_agarrar(j): return false
	var hacia: Vector2 = j.global_position - global_position
	if hacia.length() > alcance_actual: return false
	if absf(angle_difference(mirada, hacia.angle())) > deg_to_rad(apertura_actual / 2.0): return false
	return _hay_vista(global_position, j.global_position)

# ¿Hay algo en el medio? (paredes, góndolas, muebles, cajas... los jugadores no tapan)
func _hay_vista(desde: Vector2, hasta: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(desde, hasta, _mascara(), _rids_jugadores())
	q.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _mascara() -> int:
	return jugadores[0].collision_mask if not jugadores.is_empty() else 1

func _rids_jugadores() -> Array[RID]:
	var r: Array[RID] = []
	for j in jugadores: r.append(j.get_rid())
	return r

func _se_puede_agarrar(j: Node2D) -> bool:
	return is_instance_valid(j) and not j.get("atrapado") and not intocables.has(j) and j.is_inside_tree()

func _el_mas_cerca(lista: Array) -> Player:
	var mejor: Player = lista[0]
	for j in lista:
		if global_position.distance_to(j.global_position) < global_position.distance_to(mejor.global_position): mejor = j
	return mejor

# =====================================================================
# PERSECUCIÓN Y BÚSQUEDA
# =====================================================================
func _empezar_persecucion(j: Player) -> void:
	var recien: bool = estado != PERSIGUE or objetivo != j
	estado = PERSIGUE
	objetivo = j
	ultimo_visto = j.global_position
	tiempo_sin_ver = 0.0
	t_recalcular = 0.0
	if recien:
		if sonido_alerta.stream: sonido_alerta.play()
		t_silbato = randf_range(1.6, 2.6) # El primer silbato, un ratito después de la alerta
		_poner_cara("visto")

func _perseguir(delta: float) -> void:
	var te_ve: bool = tiempo_sin_ver == 0.0
	t_silbato -= delta
	if t_silbato <= 0.0 and te_ve:
		if sonido_silbato.stream: sonido_silbato.play()
		t_silbato = randf_range(silbato_cada_min, silbato_cada_max)
	var destino: Vector2 = objetivo.global_position if te_ve else ultimo_visto
	if te_ve: mirada_objetivo = (objetivo.global_position - global_position).angle()
	# Muy cerca y sin nada en el medio: va derecho a agarrarte
	if te_ve and global_position.distance_to(destino) < 20.0:
		var paso: Vector2 = (destino - global_position).limit_length(velocidad_persecucion * delta)
		global_position += paso
		_animar(paso / delta)
		return
	t_recalcular -= delta
	if t_recalcular <= 0.0:
		t_recalcular = 0.25
		_ir_a(destino)
	_caminar(delta, velocidad_persecucion, false, not te_ve)

func _empezar_busqueda() -> void:
	estado = BUSCA
	por_camara = false
	buscando_en_el_lugar = false
	_poner_cara("buscando")
	_ir_a(ultimo_visto)

func _buscar(delta: float) -> void:
	if not buscando_en_el_lugar:
		# Si lo mandó una cámara, va a la velocidad de cuando persigue
		if _caminar(delta, velocidad_persecucion if por_camara else velocidad_persecucion * 0.85, false):
			buscando_en_el_lugar = true
			t_estado = tiempo_buscando
			t_giro = 0.0
			mirada_base = mirada
		return
	t_estado -= delta
	t_giro += delta
	mirada_objetivo = mirada_base + sin(t_giro * 3.0) * deg_to_rad(80.0)
	_animar_mirando()
	if t_estado <= 0.0: _empezar_patrulla()

# =====================================================================
# CÁMARAS DE SEGURIDAD (camara_seguridad.gd)
# =====================================================================
# Una cámara vio a un ladrón en su cuadrado: el guardia se pone en amarillo y va a ver qué pasa
# (a la velocidad de cuando persigue). Si en el camino ve a alguien, lo persigue; si no, busca y sigue.
func aviso_camara(j: Player, lugar: Vector2) -> void:
	if not GameManager.juego_activo or mapa == null: return
	if estado == PERSIGUE or estado == LLEVANDO: return
	if not _se_puede_agarrar(j): return
	objetivo = j
	ultimo_visto = lugar
	estado = BUSCA
	por_camara = true
	buscando_en_el_lugar = false
	_poner_cara("buscando")
	_ir_a(lugar)

# Las cámaras apagan sus luces mientras el guardia persigue a alguien (o lo lleva a la puerta)
func esta_persiguiendo() -> bool:
	return estado == PERSIGUE or estado == LLEVANDO

# =====================================================================
# CAMINAR
# =====================================================================
func _ir_a(destino: Vector2) -> void:
	camino = mapa.camino(global_position, destino)
	i_camino = 0
	# Si el primer punto queda atrás (ya lo pasó), lo salteamos: así no vuelve para atrás al recalcular
	if camino.size() > 1:
		var a: Vector2 = camino[0]; var b: Vector2 = camino[1]
		if global_position.distance_to(b) <= a.distance_to(b): i_camino = 1

# Camina por el camino. Devuelve true cuando llegó al final.
func _caminar(delta: float, velocidad: float, dar_paso_a_npcs: bool, mirar_adelante: bool = true) -> bool:
	var resto: float = velocidad * delta
	var movido := Vector2.ZERO
	while resto > 0.0 and i_camino < camino.size():
		# ¿Apareció una caja en el camino? Busca otro (o, si tapó justo el final, elige otro lugar)
		if mapa.astar.is_point_solid(mapa.celda_de(camino[i_camino])):
			var fin: Vector2 = camino[camino.size() - 1]
			if not mapa.esta_libre(fin):
				camino = PackedVector2Array(); i_camino = 0
				_animar(Vector2.ZERO)
				return true
			_ir_a(fin)
			if i_camino >= camino.size(): return true
		var hacia: Vector2 = camino[i_camino] - global_position
		if dar_paso_a_npcs and _npc_adelante(hacia):
			t_esperando_npc += delta
			# Le da paso al empleado; si tarda, busca otro camino esquivándolo; si no hay, sigue igual
			if t_esperando_npc >= 0.6 and not ya_esquivo:
				ya_esquivo = true
				_esquivar_npcs()
				return false
			if t_esperando_npc < 1.5: break
		else:
			t_esperando_npc = 0.0
			ya_esquivo = false
		if hacia.length() <= resto:
			global_position = camino[i_camino]
			movido += hacia
			resto -= hacia.length()
			i_camino += 1
		else:
			var paso: Vector2 = hacia.normalized() * resto
			global_position += paso
			movido += paso
			resto = 0.0
	if movido.length() > 0.01:
		_animar(movido / delta)
		if mirar_adelante or estado != PERSIGUE: mirada_objetivo = movido.angle()
	else:
		_animar(Vector2.ZERO)
	return i_camino >= camino.size()

# Recalcula el camino como si los cuadraditos de los empleados que caminan estuvieran tapados
func _esquivar_npcs() -> void:
	if camino.is_empty(): return
	var destino: Vector2 = camino[camino.size() - 1]
	var tapados: Array[Vector2i] = []
	for hb in npcs_que_caminan:
		if not is_instance_valid(hb) or hb.global_position.distance_to(global_position) > 48.0: continue
		var c: Vector2i = mapa.celda_de(hb.global_position)
		for d in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if mapa.astar.is_in_boundsv(n) and not mapa.astar.is_point_solid(n) and mapa.celda_de(global_position) != n:
				mapa.astar.set_point_solid(n, true)
				tapados.append(n)
	_ir_a(destino)
	for n in tapados: mapa.astar.set_point_solid(n, false)

func _npc_adelante(hacia: Vector2) -> bool:
	if hacia.length() < 0.01: return false
	for hb in npcs_que_caminan:
		if not is_instance_valid(hb): continue
		var rel: Vector2 = hb.global_position - global_position
		if rel.length() < 20.0 and rel.normalized().dot(hacia.normalized()) > 0.3: return true
	return false

func _girar_mirada(delta: float) -> void:
	var rapidez: float = 9.0 if estado == PERSIGUE else 5.0
	mirada = lerp_angle(mirada, mirada_objetivo, minf(1.0, rapidez * delta))

# Animación de caminar (o quieto) según para dónde va
func _animar(velocidad: Vector2) -> void:
	if velocidad.length() > 1.0: direccion_anim = velocidad
	sprite.play(("walk_" if velocidad.length() > 1.0 else "idle_") + _nombre_dir(direccion_anim))

# Quieto, mirando para donde apunta la V
func _animar_mirando() -> void:
	direccion_anim = Vector2.from_angle(mirada)
	sprite.play("idle_" + _nombre_dir(direccion_anim))

func _nombre_dir(v: Vector2) -> String:
	if absf(v.x) > absf(v.y): return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"

# =====================================================================
# LA V DEL PISO
# =====================================================================
func _actualizar_cono(delta: float) -> void:
	var persigue: bool = estado == PERSIGUE
	var alcance_obj: float = alcance_persiguiendo if persigue else alcance_vision
	var apertura_obj: float = apertura_persiguiendo if persigue else apertura_vision
	alcance_actual = move_toward(alcance_actual, alcance_obj, 80.0 * delta)
	apertura_actual = move_toward(apertura_actual, apertura_obj, 60.0 * delta)
	cono.visible = estado != LLEVANDO # Mientras te lleva a la puerta no vigila
	if not cono.visible: return
	var espacio := get_world_2d().direct_space_state
	var excluir := _rids_jugadores()
	var puntos := PackedVector2Array([Vector2.ZERO])
	var mitad: float = deg_to_rad(apertura_actual / 2.0)
	for i in RAYOS_V + 1:
		var ang: float = mirada - mitad + (mitad * 2.0) * i / RAYOS_V
		var hasta: Vector2 = global_position + Vector2.from_angle(ang) * alcance_actual
		var q := PhysicsRayQueryParameters2D.create(global_position, hasta, _mascara(), excluir)
		q.collide_with_areas = false
		var choque: Dictionary = espacio.intersect_ray(q)
		var fin: Vector2 = choque.position if not choque.is_empty() else hasta
		puntos.append((fin - global_position).round())
	cono.puntos = puntos
	cono.relleno = COLOR_V_PERSIGUE if persigue else COLOR_V
	cono.borde = COLOR_V_PERSIGUE_BORDE if persigue else COLOR_V_BORDE
	cono.queue_redraw()

class Cono extends Node2D:
	var puntos := PackedVector2Array()
	var relleno: Color
	var borde: Color
	func _draw() -> void:
		if puntos.size() < 3: return
		draw_colored_polygon(puntos, relleno)
		var linea := puntos.duplicate()
		linea.append(puntos[0])
		draw_polyline(linea, borde, 1.0)

# =====================================================================
# LA CARITA ARRIBA DE LA CABEZA Y LAS DE J1 / J2
# =====================================================================
# Cambia la carita (con un saltito cuando cambia)
func _poner_cara(estado_cara: String) -> void:
	var nueva: Texture2D = CARAS[estado_cara]
	if cara.texture == nueva: return
	cara.texture = nueva
	cara.scale = Vector2(0.3, 0.3)
	var t = cara.create_tween()
	t.tween_property(cara, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _estado_de(j: Node2D) -> String:
	if j == llevando: return "visto"
	if j.get("atrapado"): return "visto" # Está afuera, esperando el reloj
	if vistos.has(j): return "visto"
	if j == objetivo and estado == PERSIGUE: return "visto"
	if j == objetivo and estado == BUSCA: return "buscando"
	return "tranquilo"

func _avisar(j: Node2D, e: String) -> void:
	if estados_avisados.get(j) == e: return
	estados_avisados[j] = e
	estado_jugador.emit(str(j.get("prefijo_acciones")), e)

# =====================================================================
# TE AGARRÓ: TE LLEVA A LA PUERTA
# =====================================================================
func _agarrar(j: Player) -> void:
	estado = LLEVANDO
	llevando = j
	objetivo = null
	vistos = []
	j.atrapado = true
	j.velocity = Vector2.ZERO
	# Si estaba con un minijuego, se le cierra (sin bloquear la góndola)
	var p: String = j.prefijo_acciones
	if GameManager.gondolas_coop.has(p):
		GameManager.gondolas_coop.erase(p)
		GameManager.qte_cancelado_jugador.emit(p)
	if sonido_silbato.stream: sonido_silbato.play()
	# Se le caen productos al azar (saltan y caen, como cuando chocás con un empleado)
	GameManager.perder_items_al_azar(items_que_pierde, p)
	_poner_cara("visto")
	# Se miran un ratito y después caminan
	fase_llevar = "agarrado"
	t_estado = 1.0 # Lo que tardan en caer los productos (después lo lleva a la puerta)
	j.last_direction = (global_position - j.global_position).normalized()
	j.update_animation(false)
	_animar_hacia(j.global_position - global_position)
	var frente: Vector2 = _frente_de_la_puerta()
	camino_llevar = mapa.camino(j.global_position, frente)
	camino_llevar.append(frente)
	i_llevar = 0
	rastro = [j.global_position]

func _frente_de_la_puerta() -> Vector2:
	var salida = get_tree().get_first_node_in_group("SalidaCoop")
	if salida: return salida.global_position
	return (puerta.global_position + Vector2(0, 41)) if puerta else global_position

func _llevar(delta: float) -> void:
	if not is_instance_valid(llevando):
		llevando = null
		_empezar_patrulla()
		return
	match fase_llevar:
		"agarrado":
			t_estado -= delta
			if t_estado <= 0.0: fase_llevar = "caminando"
		"caminando":
			# El ladrón va adelante por el camino; el guardia atrás, pisando sus pasos
			var resto: float = velocidad_llevando * delta
			var movido := Vector2.ZERO
			while resto > 0.0 and i_llevar < camino_llevar.size():
				var hacia: Vector2 = camino_llevar[i_llevar] - llevando.global_position
				if hacia.length() <= resto:
					llevando.global_position = camino_llevar[i_llevar]
					movido += hacia; resto -= hacia.length(); i_llevar += 1
				else:
					var paso: Vector2 = hacia.normalized() * resto
					llevando.global_position += paso; movido += paso; resto = 0.0
			if movido.length() > 0.01:
				llevando.last_direction = movido.normalized()
				llevando.update_animation(true)
				rastro.append(llevando.global_position)
			_seguir_rastro(delta)
			if i_llevar >= camino_llevar.size():
				fase_llevar = "saliendo"
				_sacarlo_por_la_puerta(llevando)
		"saliendo":
			_seguir_rastro(delta)

func _seguir_rastro(delta: float) -> void:
	if global_position.distance_to(llevando.global_position) <= DISTANCIA_DETRAS or rastro.is_empty():
		_animar_hacia(llevando.global_position - global_position)
		return
	var resto: float = velocidad_llevando * 1.15 * delta
	var movido := Vector2.ZERO
	while resto > 0.0 and not rastro.is_empty():
		var hacia: Vector2 = rastro[0] - global_position
		if hacia.length() <= resto:
			global_position = rastro[0]; movido += hacia; resto -= hacia.length(); rastro.pop_front()
		else:
			var paso: Vector2 = hacia.normalized() * resto
			global_position += paso; movido += paso; resto = 0.0
		if global_position.distance_to(llevando.global_position) <= DISTANCIA_DETRAS: break
	if movido.length() > 0.01: _animar(movido / delta)
	else: _animar_hacia(llevando.global_position - global_position)

func _animar_hacia(v: Vector2) -> void:
	if v.length() > 0.01: direccion_anim = v
	sprite.play("idle_" + _nombre_dir(direccion_anim))
	mirada_objetivo = direccion_anim.angle()

# Sale por la puerta (como cuando entra, pero para arriba), aparece el reloj y después vuelve a entrar
func _sacarlo_por_la_puerta(j: Player) -> void:
	var x_puerta: float = puerta.global_position.x if puerta else j.global_position.x
	var y_puerta: float = puerta.global_position.y if puerta else j.global_position.y - 41.0
	var afuera := Vector2(x_puerta, y_puerta - 7.0) # Donde arrancan al principio del nivel
	_abrir_puerta()
	var t = j.create_tween()
	if absf(j.global_position.x - x_puerta) > 1.0:
		t.tween_callback(func(): j.last_direction = Vector2(signf(x_puerta - j.global_position.x), 0); j.update_animation(true))
		t.tween_property(j, "global_position:x", x_puerta, absf(j.global_position.x - x_puerta) / velocidad_llevando)
	t.tween_callback(func(): j.last_direction = Vector2.UP; j.update_animation(true))
	var subida: float = maxf(0.3, (j.global_position.y - afuera.y) / velocidad_llevando)
	t.tween_property(j, "global_position:y", afuera.y, subida)
	t.parallel().tween_property(j, "modulate:a", 0.0, 0.3).set_delay(maxf(0.0, subida - 0.3))
	await t.finished
	if not is_inside_tree(): return
	_cerrar_puerta()
	# El guardia se queda un momento mirando la puerta y vuelve a patrullar
	llevando = null
	estado = MIRANDO
	mirada_base = -PI / 2.0
	mirada_objetivo = mirada_base
	t_estado = 0.8
	t_giro = 0.0
	_poner_cara("tranquilo")
	_castigo(j, afuera)

func _castigo(j: Player, afuera: Vector2) -> void:
	# El reloj arriba de la puerta (el mismo de las góndolas: da la vuelta y suena tic-tac)
	var reloj := Sprite2D.new()
	reloj.texture = RELOJ
	reloj.hframes = 8
	reloj.z_index = 20
	nivel.add_child(reloj)
	reloj.global_position = afuera + Vector2(0, -6)
	var y0: float = reloj.position.y
	var flote = reloj.create_tween().set_loops()
	flote.tween_property(reloj, "position:y", y0 - 6.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flote.tween_property(reloj, "position:y", y0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tic := _sonido(RUTA_TIC, -10.0)
	var tac := _sonido(RUTA_TAC, -10.0)
	var pasos: int = 8
	for i in pasos:
		reloj.frame = i
		(tic if i % 2 == 0 else tac).play()
		await get_tree().create_timer(tiempo_afuera / pasos, false).timeout
		if not is_inside_tree() or not is_instance_valid(j): return
	flote.kill()
	reloj.queue_free()
	tic.queue_free(); tac.queue_free()
	# Vuelve a entrar como al principio del nivel
	j.global_position = afuera
	j.modulate.a = 1.0
	_abrir_puerta()
	j.last_direction = Vector2.DOWN
	j.update_animation(true)
	var t = j.create_tween()
	t.tween_property(j, "global_position:y", afuera.y + 64.0, 1.5)
	await t.finished
	if not is_inside_tree() or not is_instance_valid(j): return
	j.update_animation(false)
	_cerrar_puerta()
	j.atrapado = false
	# Unos segundos sin que lo puedan agarrar (parpadea)
	intocables[j] = tiempo_intocable
	var parpadeo = j.create_tween().set_loops(int(tiempo_intocable / 0.3))
	parpadeo.tween_property(j.anim_sprite, "modulate:a", 0.3, 0.15)
	parpadeo.tween_property(j.anim_sprite, "modulate:a", 1.0, 0.15)
	parpadeo.finished.connect(func(): if is_instance_valid(j): j.anim_sprite.modulate.a = 1.0)

func _abrir_puerta() -> void:
	if puerta and puerta.get("anim_sprite"): puerta.anim_sprite.play("open")

func _cerrar_puerta() -> void:
	if puerta and puerta.get("anim_sprite"): puerta.anim_sprite.play_backwards("open")
