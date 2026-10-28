@tool
extends Node2D
## EXTERIOR DEL SÚPER (lo de afuera: veredas, pasto, calle, estacionamiento...)
## Se dibuja solo alrededor del local: mide el tamaño del nivel con la capa "Walls"
## y busca la puerta ("AutomaticDoor") para poner la senda peatonal enfrente.
## Si agrandás o achicás el nivel, se acomoda solo.
## Los dibujos (baldosas, árboles, macetas...) están en assets/exterior/ y se pueden retocar.

@export_enum("A: Vereda con cantero y calle", "B: Estacionamiento", "C: Plaza con caminito", "D: Vereda con macetas y calle") var estilo: int = 0:
	set(valor):
		estilo = valor
		queue_redraw()

@export var alcance: float = 480.0 # Hasta dónde se dibuja hacia afuera del local (en pixeles)

const CARPETA: String = "res://assets/exterior/"
const BLANCO: Color = Color8(236, 236, 230)
const AMARILLO: Color = Color8(250, 214, 40)
const CORDON: Color = Color8(196, 196, 200)
const CORDON_OSCURO: Color = Color8(110, 110, 118)

var tex: Dictionary = {}

func _ready() -> void:
	z_index = -2 # Por debajo del piso del local (que está en -1)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for nombre in ["asfalto", "pasto", "baldosa_vainilla", "baldosa_gris", "baldosa_gris_clara", "baldosa_plaza", "arbol", "arbusto", "maceta", "rejilla"]:
		tex[nombre] = load(CARPETA + nombre + ".png")
	queue_redraw()

# =====================================================================
# MEDIDAS DEL LOCAL
# =====================================================================
# Borde de afuera de las paredes (las paredes de los costados son finitas: 8 px)
func _local() -> Rect2:
	var paredes: TileMapLayer = get_parent().get_node_or_null("Walls")
	if paredes == null: return Rect2(0, 0, 320, 320)
	var r: Rect2i = paredes.get_used_rect()
	var t: float = paredes.tile_set.tile_size.x if paredes.tile_set else 32.0
	var izq: float = (r.position.x + 1) * t - 8
	var der: float = (r.end.x - 1) * t + 8
	return Rect2(izq, r.position.y * t, der - izq, r.end.y * t - r.position.y * t)

# Los dos bordes de la puerta (en x)
func _puerta() -> Vector2:
	var puerta = get_parent().get_node_or_null("AutomaticDoor")
	if puerta == null:
		var l = _local()
		return Vector2(l.get_center().x - 32, l.get_center().x + 32)
	return Vector2(puerta.position.x - 32, puerta.position.x + 32)

# =====================================================================
# DIBUJO
# =====================================================================
func _draw() -> void:
	if tex.is_empty(): return
	var L: Rect2 = _local()
	var P: Vector2 = _puerta()
	match estilo:
		0: _estilo_a(L, P)
		1: _estilo_b(L, P)
		2: _estilo_c(L, P)
		3: _estilo_d(L, P)
	_sombra_local(L)

# A: vereda de baldosas + franja de pasto con árboles + cordón + calle
func _estilo_a(L: Rect2, P: Vector2) -> void:
	_baldosas("asfalto", L.grow(alcance))
	_baldosas("pasto", L.grow(74))
	_baldosas("baldosa_vainilla", L.grow(48))
	_borde(L.grow(74), 4, CORDON)
	_borde(L.grow(78), 1, CORDON_OSCURO)
	# Caminito de baldosas que cruza el pasto hasta la puerta, y senda peatonal en la calle
	_baldosas("baldosa_vainilla", _rect(P.x - 16, L.position.y - 74, P.y + 16, L.position.y - 48))
	_senda(P.x - 24, P.y + 24, L.position.y - 114, L.position.y - 78)
	# Líneas de la calle
	var afuera = L.grow(alcance)
	_linea_h(L.position.y - 114, afuera.position.x, afuera.end.x)
	_linea_v(L.position.x - 118, afuera.position.y, afuera.end.y)
	_linea_v(L.end.x + 118, afuera.position.y, afuera.end.y)
	# Árboles en el pasto (no enfrente de la puerta)
	var x: float = L.position.x - 56
	while x < L.end.x + 60:
		if not (P.x - 40 < x and x < P.y + 40):
			_objeto("arbol", Vector2(x, L.position.y - 62))
		x += 96
	var y: float = L.position.y + 40
	while y < L.end.y + 60:
		_objeto("arbol", Vector2(L.position.x - 62, y))
		_objeto("arbol", Vector2(L.end.x + 62, y))
		y += 96
	_objeto("rejilla", Vector2(L.position.x + 40, L.position.y - 82))
	_objeto("rejilla", Vector2(L.end.x - 40, L.position.y - 82))

# B: estacionamiento con cajones pintados
func _estilo_b(L: Rect2, P: Vector2) -> void:
	_baldosas("asfalto", L.grow(alcance))
	_baldosas("baldosa_gris_clara", L.grow(24))
	_borde(L.grow(24), 3, AMARILLO)
	var y: float = L.position.y
	while y < L.end.y + 40:
		_linea(Vector2(L.position.x - 96, y), Vector2(L.position.x - 40, y))
		_linea(Vector2(L.end.x + 40, y), Vector2(L.end.x + 96, y))
		y += 32
	var x: float = L.position.x - 40
	while x < L.end.x + 48:
		_linea(Vector2(x, L.end.y + 40), Vector2(x, L.end.y + 96))
		x += 32
	_senda(P.x - 8, P.y + 8, L.position.y - alcance, L.position.y - 28)
	for punta in [Vector2(L.position.x - 68, L.position.y - 40), Vector2(L.end.x + 68, L.position.y - 40)]:
		draw_colored_polygon(PackedVector2Array([punta + Vector2(-4, 6), punta + Vector2(4, 6), punta + Vector2(0, -6)]), BLANCO)
	for esquina in [Vector2(L.position.x - 40, L.position.y - 48), Vector2(L.end.x + 40, L.position.y - 48), Vector2(L.position.x - 40, L.end.y + 56), Vector2(L.end.x + 40, L.end.y + 56)]:
		_objeto("arbusto", esquina)

# C: plaza de pasto con caminito, árboles y arbustos
func _estilo_c(L: Rect2, P: Vector2) -> void:
	_baldosas("pasto", L.grow(alcance))
	_baldosas("baldosa_plaza", L.grow(16))
	_baldosas("baldosa_plaza", _rect(P.x - 8, L.position.y - alcance, P.y + 8, L.position.y))
	for p in [Vector2(L.position.x - 48, L.position.y - 40), Vector2(L.end.x + 48, L.position.y - 40),
			Vector2(L.position.x - 60, L.position.y + 150), Vector2(L.end.x + 60, L.position.y + 150),
			Vector2(L.position.x - 50, L.end.y - 60), Vector2(L.end.x + 50, L.end.y - 60),
			Vector2(L.position.x + 60, L.end.y + 60), Vector2(L.end.x - 60, L.end.y + 60)]:
		_objeto("arbol", p)
	for p in [Vector2(P.x - 28, L.position.y - 40), Vector2(P.y + 28, L.position.y - 40),
			Vector2(P.x - 28, L.position.y - 80), Vector2(P.y + 28, L.position.y - 80)]:
		_objeto("arbusto", p)

# D: vereda ancha con macetas, cordón amarillo y calle con carriles
func _estilo_d(L: Rect2, P: Vector2) -> void:
	_baldosas("pasto", L.grow(alcance))
	_baldosas("asfalto", L.grow(104))
	_baldosas("baldosa_gris", L.grow(40))
	_borde(L.grow(40), 4, AMARILLO)
	_borde(L.grow(101), 3, Color8(200, 200, 204))
	var calle = L.grow(104)
	_linea_h(L.position.y - 72, calle.position.x, calle.end.x)
	_linea_h(L.end.y + 72, calle.position.x, calle.end.x)
	_linea_v(L.position.x - 72, calle.position.y, calle.end.y)
	_linea_v(L.end.x + 72, calle.position.y, calle.end.y)
	_senda(P.x - 16, P.y + 16, L.position.y - 104, L.position.y - 44)
	var x: float = L.position.x + 24
	while x < L.end.x - 8:
		if not (P.x - 30 < x and x < P.y + 30):
			_objeto("maceta", Vector2(x, L.position.y - 14))
		x += 64
	var y: float = L.position.y + 40
	while y < L.end.y:
		_objeto("maceta", Vector2(L.position.x - 14, y))
		_objeto("maceta", Vector2(L.end.x + 14, y))
		y += 80
	_objeto("rejilla", Vector2(L.position.x + 80, L.position.y - 50))
	_objeto("rejilla", Vector2(L.end.x - 80, L.position.y - 50))

# =====================================================================
# AYUDANTES
# =====================================================================
func _rect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	return Rect2(x0, y0, x1 - x0, y1 - y0)

# Rellena un rectángulo repitiendo una baldosa, alineada con la grilla del nivel
func _baldosas(nombre: String, r: Rect2) -> void:
	r = Rect2(r.position.round(), r.size.round())
	draw_texture_rect_region(tex[nombre], r, r)

# Un marco de cierto grosor por FUERA del rectángulo
func _borde(r: Rect2, grosor: float, color: Color) -> void:
	var g = r.grow(grosor)
	draw_rect(_rect(g.position.x, g.position.y, g.end.x, r.position.y), color)
	draw_rect(_rect(g.position.x, r.end.y, g.end.x, g.end.y), color)
	draw_rect(_rect(g.position.x, r.position.y, r.position.x, r.end.y), color)
	draw_rect(_rect(r.end.x, r.position.y, g.end.x, r.end.y), color)

func _linea(a: Vector2, b: Vector2) -> void:
	draw_rect(Rect2(a.min(b) - Vector2(1, 1), (b - a).abs() + Vector2(2, 2)), BLANCO)

# Línea punteada (12 px de raya, 12 de espacio)
func _linea_h(y: float, x0: float, x1: float) -> void:
	var x = x0
	while x < x1:
		draw_rect(Rect2(x, y - 1, 12, 2), BLANCO)
		x += 24

func _linea_v(x: float, y0: float, y1: float) -> void:
	var y = y0
	while y < y1:
		draw_rect(Rect2(x - 1, y, 2, 12), BLANCO)
		y += 24

# Senda peatonal (rayas verticales)
func _senda(x0: float, x1: float, y0: float, y1: float) -> void:
	var x = x0
	while x < x1:
		draw_rect(_rect(x, y0, x + 5, y1), BLANCO)
		x += 8

# Dibujito centrado en el punto (las imágenes son de 48x48 con el centro en el medio)
func _objeto(nombre: String, centro: Vector2) -> void:
	var t: Texture2D = tex[nombre]
	draw_texture(t, (centro - t.get_size() / 2.0).round())

# Sombrita del local sobre el piso de afuera (abajo y a la derecha)
func _sombra_local(L: Rect2) -> void:
	var c = Color(0, 0, 0, 0.2)
	draw_rect(_rect(L.end.x, L.position.y + 6, L.end.x + 5, L.end.y + 5), c)
	draw_rect(_rect(L.position.x + 6, L.end.y, L.end.x, L.end.y + 5), c)
