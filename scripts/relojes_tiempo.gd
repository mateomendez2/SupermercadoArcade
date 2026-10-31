extends Node2D
## APARECEN RELOJES VERDES DE TIEMPO EXTRA
## Cada tanto pone un reloj (reloj_tiempo.gd) en un lugar al azar del piso:
##   - Siempre donde se puede caminar y llegar (usa el mismo mapa de caminos que el guardia).
##   - Nunca pegado al jugador, ni donde aparecen cajas o charcos, ni en la zona de una góndola o de la caja.
##   - Nunca justo atrás de una góndola o un mueble (en la vista 3/4 lo taparía).
##   - Si se puede, a la vista de algún jugador (adentro de lo que muestra su cámara).
## Hay un solo reloj a la vez. Cuando lo agarran, al rato aparece otro.
## En el modo de 1 jugador sale recién desde el nivel 5 (GameManager.RELOJES_DESDE_EL_NIVEL); en el de 2, en todos.
## Lo crea config_nivel.gd al arrancar el nivel; lo que tarda, cuánto dura y cuánto suma se cambia ahí,
## en el grupo "Reloj de tiempo extra" del Inspector del nivel.

const Mapa = preload("res://scripts/mapa_caminos.gd")
const RelojTiempo = preload("res://scripts/reloj_tiempo.gd")

# --- LO PONE config_nivel.gd ---
var segundos_por_reloj: int = 25
var primer_reloj_a_los: float = 12.0
var reloj_cada_min: float = 15.0
var reloj_cada_max: float = 25.0
var reloj_dura: float = 10.0

# --- AJUSTES FINOS ---
const DISTANCIA_MINIMA_JUGADOR: float = 56.0  # Que no aparezca encima tuyo
const DISTANCIA_A_CAJAS_Y_CHARCOS: float = 26.0
const CELDAS_LIBRES_ABAJO: int = 3            # Cuadraditos libres debajo, así ningún mueble lo tapa
const MARGEN_PANTALLA: float = 16.0
const TAPADO_ARRIBA: float = 40.0             # Lo que tapan la franja y el ticket (en pixeles del mundo, aprox.)

var nivel: Node2D
var mapa
var espera: float = 12.0
var reloj_actual: Node2D = null

func _ready() -> void:
	nivel = get_parent()
	espera = primer_reloj_a_los
	if not _toca_en_este_nivel():
		set_process(false) # En este nivel no hay relojes

# Modo 2 jugadores: siempre. Modo 1 jugador: desde el nivel RELOJES_DESDE_EL_NIVEL.
func _toca_en_este_nivel() -> bool:
	var ruta: String = nivel.scene_file_path
	if GameManager.RUTAS_NIVELES_COOP.has(ruta): return true
	var indice: int = GameManager.RUTAS_NIVELES.find(ruta)
	return indice == -1 or indice + 1 >= GameManager.RELOJES_DESDE_EL_NIVEL

func _process(delta: float) -> void:
	if not GameManager.juego_activo: return
	if is_instance_valid(reloj_actual): return
	espera -= delta
	if espera > 0.0: return
	var lugar = _buscar_lugar()
	if lugar == null:
		espera = 1.5 # No hubo lugar (raro): se prueba de nuevo en un rato
		return
	reloj_actual = RelojTiempo.new()
	reloj_actual.segundos = segundos_por_reloj
	reloj_actual.duracion = reloj_dura
	nivel.add_child(reloj_actual)
	reloj_actual.global_position = lugar
	reloj_actual.tree_exited.connect(func(): espera = randf_range(reloj_cada_min, reloj_cada_max))

func _jugadores() -> Array:
	return get_tree().get_nodes_in_group("Player").filter(func(j): return j is Player and nivel.is_ancestor_of(j))

# =====================================================================
# DÓNDE PONERLO
# =====================================================================
func _buscar_lugar():
	var jugadores: Array = _jugadores()
	if jugadores.is_empty(): return null
	if mapa == null:
		# El mapa se arma la primera vez (cuando el jugador ya entró: desde ahí se ve a dónde se llega)
		mapa = Mapa.new()
		mapa.armar(nivel, get_world_2d().direct_space_state, jugadores[0].global_position, jugadores[0].collision_mask)
	mapa.actualizar_cajas()
	var vistas: Array[Rect2] = _lo_que_ven_las_camaras()
	var obstaculos: Array = []
	for grupo in ["CajasObstaculo", "CharcosObstaculo"]:
		for n in get_tree().get_nodes_in_group(grupo):
			if nivel.is_ancestor_of(n): obstaculos.append(n.global_position)
	var candidatos: Array = mapa.alcanzables.duplicate()
	candidatos.shuffle()
	# Si no hay ninguno a la vista, el que quede más cerca de lo que ve alguna cámara
	var de_reserva = null
	var mejor_distancia: float = INF
	for c in candidatos:
		if not _sirve(c, jugadores, obstaculos): continue
		var p: Vector2 = mapa.centro(c)
		for v in vistas:
			if v.has_point(p): return p # A la vista de alguien: este
			var d: float = p.distance_to(p.clamp(v.position, v.end))
			if d < mejor_distancia:
				mejor_distancia = d
				de_reserva = p
		if vistas.is_empty() and de_reserva == null: de_reserva = p
	return de_reserva

func _sirve(c: Vector2i, jugadores: Array, obstaculos: Array) -> bool:
	if mapa.astar.is_point_solid(c): return false
	# Libre para abajo (si hubiera una góndola justo abajo, su dibujo taparía el reloj)
	for k in range(1, CELDAS_LIBRES_ABAJO + 1):
		var abajo: Vector2i = c + Vector2i(0, k)
		if not mapa.astar.is_in_boundsv(abajo) or mapa.astar.is_point_solid(abajo): return false
	var p: Vector2 = mapa.centro(c)
	for j in jugadores:
		if j.global_position.distance_to(p) < DISTANCIA_MINIMA_JUGADOR: return false
	for o in obstaculos:
		if o.distance_to(p) < DISTANCIA_A_CAJAS_Y_CHARCOS: return false
	# Nada de zonas (góndolas, caja registradora, salida, charcos, etc.)
	var q := PhysicsShapeQueryParameters2D.new()
	var forma := CircleShape2D.new()
	forma.radius = 9.0
	q.shape = forma
	q.transform = Transform2D(0.0, p)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	if not get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty(): return false
	return true

# Lo que muestra cada cámara (sin los bordes ni lo que tapa la franja de arriba)
func _lo_que_ven_las_camaras() -> Array[Rect2]:
	var vistas: Array[Rect2] = []
	for cam in get_tree().root.find_children("*", "Camera2D", true, false):
		if not cam.is_current() or not cam.is_inside_tree(): continue
		if cam.get_world_2d() != get_world_2d(): continue
		var tam: Vector2 = cam.get_viewport().get_visible_rect().size / cam.zoom
		var r := Rect2(cam.get_screen_center_position() - tam / 2.0, tam)
		r.position.y += TAPADO_ARRIBA
		r.size.y -= TAPADO_ARRIBA
		vistas.append(r.grow(-MARGEN_PANTALLA))
	return vistas
