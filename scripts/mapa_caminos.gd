extends RefCounted
## MAPA DE CAMINOS DEL GUARDIA (modo 2 jugadores)
## Parte el piso del súper en cuadraditos de 16 x 16 y se fija cuáles están libres: donde no hay paredes,
## góndolas, muebles, heladeras, clientes quietos ni cajas. Con eso el guardia sabe por dónde caminar
## (busca el camino más corto con A*, solo en las 4 direcciones, como los personajes).
## Las cajas que cambian de lugar se vuelven a revisar cada medio segundo.
## Lo usa guardia.gd (no hace falta ponerlo en ningún nivel).

const CELDA: int = 16
const PIES: Vector2 = Vector2(14, 10) # Lo que ocupan los pies del guardia (un poco menos que el jugador)

var astar := AStarGrid2D.new()
var espacio: PhysicsDirectSpaceState2D
var piso: TileMapLayer
var mascara: int = 1
var forma := RectangleShape2D.new()
var alcanzables: Array[Vector2i] = [] # Los cuadraditos libres a los que se puede llegar desde el medio
var es_alcanzable: Dictionary = {}
var cajas: Array[Node] = []

# nivel: el nivel cargado. desde: un punto adentro del súper (de ahí se ve a qué lugares se puede llegar)
func armar(nivel: Node2D, espacio_fisico: PhysicsDirectSpaceState2D, desde: Vector2, mascara_fisica: int) -> void:
	espacio = espacio_fisico
	mascara = mascara_fisica
	forma.size = PIES
	piso = nivel.get_node_or_null("Floor") as TileMapLayer
	var zona: Rect2
	if piso:
		var usado: Rect2i = piso.get_used_rect()
		var baldosa: Vector2 = Vector2(piso.tile_set.tile_size)
		var esquina: Vector2 = piso.to_global(piso.map_to_local(usado.position) - baldosa / 2.0)
		zona = Rect2(esquina, Vector2(usado.size) * baldosa)
	else:
		zona = Rect2(desde - Vector2(400, 300), Vector2(800, 600))
	# Los centros de los cuadraditos caen en el medio de cada baldosa y en sus bordes
	var tam := Vector2i(ceili(zona.size.x / CELDA) + 1, ceili(zona.size.y / CELDA) + 1)
	astar.region = Rect2i(Vector2i.ZERO, tam)
	astar.cell_size = Vector2(CELDA, CELDA)
	astar.offset = zona.position
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	# Cajas que aparecen y desaparecen (las revisamos de vuelta cada tanto)
	for caja in nivel.get_tree().get_nodes_in_group("CajasObstaculo"):
		if nivel.is_ancestor_of(caja): cajas.append(caja)
	# Primero sin las cajas (esas se mueven): así se sabe a qué lugares se llega caminando desde el medio
	for x in tam.x:
		for y in tam.y:
			astar.set_point_solid(Vector2i(x, y), _ocupada(Vector2i(x, y), true))
	_buscar_alcanzables(celda_de(desde))
	actualizar_cajas()

# ¿Hay algo en ese cuadradito? (o no hay piso)
func _ocupada(c: Vector2i, sin_cajas: bool = false) -> bool:
	var p: Vector2 = centro(c)
	if piso and piso.get_cell_source_id(piso.local_to_map(piso.to_local(p))) == -1:
		return true
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = forma
	q.transform = Transform2D(0.0, p)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	q.collision_mask = mascara
	for r in espacio.intersect_shape(q, 8):
		if r.collider is CharacterBody2D: continue # (los jugadores no cuentan)
		if sin_cajas and cajas.has(r.collider): continue
		return true
	return false

func _buscar_alcanzables(inicio: Vector2i) -> void:
	inicio = libre_cercana(centro(inicio), false)
	alcanzables.clear(); es_alcanzable.clear()
	var cola: Array[Vector2i] = [inicio]
	es_alcanzable[inicio] = true
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		alcanzables.append(c)
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if astar.is_in_boundsv(n) and not astar.is_point_solid(n) and not es_alcanzable.has(n):
				es_alcanzable[n] = true
				cola.append(n)
	# Lo que no se puede alcanzar queda tapado (así nunca elige ir ahí)
	for x in astar.region.size.x:
		for y in astar.region.size.y:
			if not es_alcanzable.has(Vector2i(x, y)): astar.set_point_solid(Vector2i(x, y), true)

# Revisa los cuadraditos alrededor de cada caja (si está prendida, tapa; si no, destapa)
func actualizar_cajas() -> void:
	for caja in cajas:
		if not is_instance_valid(caja): continue
		var c: Vector2i = celda_de(caja.global_position)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var n: Vector2i = c + Vector2i(dx, dy)
				if es_alcanzable.has(n): astar.set_point_solid(n, _ocupada(n))

# =====================================================================
# PARA EL GUARDIA
# =====================================================================
func centro(c: Vector2i) -> Vector2:
	return astar.offset + Vector2(c) * CELDA

func celda_de(p: Vector2) -> Vector2i:
	return Vector2i(((p - astar.offset) / CELDA).round())

func esta_libre(p: Vector2) -> bool:
	var c: Vector2i = celda_de(p)
	return astar.is_in_boundsv(c) and not astar.is_point_solid(c)

# El cuadradito libre más cercano a ese punto
func libre_cercana(p: Vector2, solo_alcanzables: bool = true) -> Vector2i:
	var c: Vector2i = celda_de(p)
	var mejor: Vector2i = c
	var mejor_d: float = INF
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var n: Vector2i = c + Vector2i(dx, dy)
				if not astar.is_in_boundsv(n) or astar.is_point_solid(n): continue
				if solo_alcanzables and not es_alcanzable.has(n): continue
				var d: float = centro(n).distance_squared_to(p)
				if d < mejor_d: mejor_d = d; mejor = n
		if mejor_d < INF: return mejor
	return c

# Camino de un punto a otro (lista de puntos del mundo, sin el primero si ya está ahí)
func camino(desde: Vector2, hasta: Vector2) -> PackedVector2Array:
	var a: Vector2i = libre_cercana(desde)
	var b: Vector2i = libre_cercana(hasta)
	var puntos: PackedVector2Array = astar.get_point_path(a, b, true)
	# Sacamos los puntos del medio de las rectas (así camina derecho y dobla solo en las esquinas)
	var limpio := PackedVector2Array()
	for i in puntos.size():
		if i > 0 and i < puntos.size() - 1:
			var antes: Vector2 = puntos[i] - puntos[i - 1]
			var despues: Vector2 = puntos[i + 1] - puntos[i]
			if antes.normalized().is_equal_approx(despues.normalized()): continue
		limpio.append(puntos[i])
	return limpio

# Un lugar libre al azar, lejos de "lejos_de" (para patrullar)
func lugar_al_azar(lejos_de: Vector2, distancia_minima: float) -> Vector2:
	for intento in 40:
		var c: Vector2i = alcanzables.pick_random()
		if astar.is_point_solid(c): continue
		if centro(c).distance_to(lejos_de) >= distancia_minima: return centro(c)
	return centro(alcanzables.pick_random())
