@tool
extends Node2D
## CÁMARA DE SEGURIDAD (modo 2 jugadores - ROBO)
##
## Un parante con una cámara arriba que vigila 2 o 3 cuadrados del piso, de a uno:
## mira uno durante unos segundos (5 por defecto) y pasa al siguiente.
## Desde la cámara sale una luz hasta el cuadrado que está mirando.
##
## En el medio del cuadrado hay un ojito ("te están mirando").
## Cambio de cuadrado: el último segundo titila solo el ojito, en el cuadrado de ahora y en el lugar del siguiente
## (ahí solo el ojito, sin el amarillo); después el de ahora desaparece y el siguiente se prende entero.
## Si un ladrón TOCA el cuadrado iluminado con los pies (la V de luz no cuenta): la cámara hace "bip-bip" y le avisa al guardia,
## que se pone en amarillo y va a ver a ese lugar (a la velocidad de cuando persigue).
## Si cuando llega no ve a nadie, sigue patrullando normal.
## Mientras el guardia persigue a alguien (o lo está llevando a la puerta), las luces de las cámaras
## se apagan; vuelven cuando todo está tranquilo de nuevo.
##
## CÓMO SE USA (en el editor):
##   1. Arrastrá camara_seguridad.tscn al nivel y ponela donde va el parante (el punto es donde apoya en el piso).
##   2. Adentro tiene "Zona1" y "Zona2": movelas a los lugares del piso que tiene que vigilar.
##      Para una tercera, duplicá una (Ctrl+D) y llamala "Zona3". Se recorren en orden: Zona1, Zona2, Zona3...
##   3. Los cuadrados se acomodan solos a las baldosas (como las cajas y los charcos).
##   En el editor ya se ven los cuadrados (con su número) y la luz hasta la Zona1.

const TEX_PRENDIDA: Texture2D = preload("res://assets/camara/camara_prendida.png")
const TEX_APAGADA: Texture2D = preload("res://assets/camara/camara_apagada.png")
const TEX_OJO: Texture2D = preload("res://assets/camara/ojo.png") # En el medio del cuadrado: "te están mirando"
const RUTA_BIP: String = "res://assets/audio/CamaraBip.wav"

@export var segundos_por_zona: float = 5.0 # Cuánto mira cada cuadrado antes de pasar al siguiente
@export var tamano_zona: Vector2 = Vector2(32, 32) # Lo mismo que ocupan las cajas y los charcos
@export var ajustar_a_baldosas: bool = true # Los cuadrados se acomodan a las baldosas del piso
@export var color_luz: Color = Color(1.0, 0.86, 0.25)
@export var aviso_antes_de_cambiar: float = 1.0 # Antes de cambiar, los ojitos (el de ahora y el del siguiente) titilan este tiempo

const BALDOSA: float = 32.0
const PIES: Vector2 = Vector2(16, 8) # Lo que ocupan los pies de un ladrón en el piso
const COLOR_AVISO: Color = Color(1.0, 0.25, 0.2)
# Dónde va la cámara arriba del parante (mirando a la derecha) y dónde tiene el lente
const CABEZA_DERECHA: Vector2 = Vector2(-8, -51)
const CABEZA_IZQUIERDA: Vector2 = Vector2(-12, -51)
const LENTE_DERECHA: Vector2 = Vector2(18.5, 4.5)
const LENTE_IZQUIERDA: Vector2 = Vector2(1.5, 4.5)

var zonas: Array[Node2D] = []
var actual: int = 0
var centro_luz: Vector2 = Vector2.ZERO # Centro del cuadrado iluminado (en el mundo)
var t_zona: float = 0.0
var t_led: float = 0.0
var t_aviso: float = 0.0 # Después de avisar, espera un poquito antes de volver a avisar
var cabeza: Sprite2D
var haz: Haz
var cuadro: Cuadro
var haz_siguiente: Haz       # Mientras titila: la luz del cuadrado que viene
var cuadro_siguiente: Cuadro
var sonido: AudioStreamPlayer
var iniciada: bool = false

func _ready() -> void:
	cabeza = get_node_or_null("Cabeza")
	_buscar_zonas()
	if Engine.is_editor_hint(): return
	add_to_group("CamarasSeguridad")
	for z in zonas: z.hide()
	# La luz va por encima de todo (es "aire" iluminado) y el cuadrado, en el piso
	haz = Haz.new()
	haz.top_level = true
	haz.z_index = 4
	add_child(haz)
	cuadro = Cuadro.new()
	cuadro.top_level = true
	cuadro.z_index = -1
	cuadro.ojo = TEX_OJO
	add_child(cuadro)
	haz_siguiente = Haz.new()
	haz_siguiente.top_level = true
	haz_siguiente.z_index = 4
	add_child(haz_siguiente)
	cuadro_siguiente = Cuadro.new()
	cuadro_siguiente.top_level = true
	cuadro_siguiente.z_index = -1
	cuadro_siguiente.ojo = TEX_OJO
	add_child(cuadro_siguiente)
	sonido = AudioStreamPlayer.new()
	if ResourceLoader.exists(RUTA_BIP): sonido.stream = load(RUTA_BIP)
	sonido.volume_db = -6.0
	add_child(sonido)

func _buscar_zonas() -> void:
	zonas.clear()
	for h in get_children():
		if h is Node2D and str(h.name).begins_with("Zona"): zonas.append(h)
	zonas.sort_custom(func(a, b): return str(a.name).naturalnocasecmp_to(str(b.name)) < 0)

# Centro del cuadrado de esa zona (en el mundo), acomodado a las baldosas
func _centro_zona(i: int) -> Vector2:
	if zonas.is_empty(): return global_position
	var p: Vector2 = zonas[clampi(i, 0, zonas.size() - 1)].global_position
	if ajustar_a_baldosas:
		p = (p / BALDOSA).floor() * BALDOSA + Vector2(BALDOSA, BALDOSA) / 2.0
	return p

func _rect_luz() -> Rect2:
	return Rect2(centro_luz - tamano_zona / 2.0, tamano_zona)

# =====================================================================
# CADA CUADRO
# =====================================================================
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_buscar_zonas()
		_mirar_hacia(_centro_zona(0))
		queue_redraw()
		return
	if zonas.is_empty(): return
	if not iniciada: # (en el primer cuadro: así ya está todo en su lugar)
		iniciada = true
		centro_luz = _centro_zona(0)
	var guardia = get_tree().get_first_node_in_group("Guardia")
	var persiguiendo: bool = guardia != null and guardia.has_method("esta_persiguiendo") and guardia.esta_persiguiendo()
	# Las luces se apagan (suavecito) mientras hay persecución
	var alfa: float = 0.0 if persiguiendo else 1.0
	haz.modulate.a = move_toward(haz.modulate.a, alfa, delta * 3.0)
	cuadro.modulate.a = haz.modulate.a
	haz_siguiente.modulate.a = haz.modulate.a
	cuadro_siguiente.modulate.a = haz.modulate.a
	# Cada tantos segundos: se apaga este cuadrado y se prende el siguiente (no se desliza)
	var siguiente: int = (actual + 1) % zonas.size()
	if zonas.size() > 1:
		t_zona += delta
		if t_zona >= segundos_por_zona:
			actual = siguiente
			siguiente = (actual + 1) % zonas.size()
			centro_luz = _centro_zona(actual)
			t_zona = 0.0
	_mirar_hacia(centro_luz)
	# La lucecita roja titila (rápido cuando acaba de ver a alguien)
	t_aviso = maxf(0.0, t_aviso - delta)
	t_led += delta
	var periodo: float = 0.2 if t_aviso > 0.0 else 1.0
	cabeza.texture = TEX_PRENDIDA if fmod(t_led, periodo) < periodo * 0.6 and not persiguiendo else TEX_APAGADA
	# Poco antes de cambiar: el de ahora y el siguiente titilan JUNTOS (se prenden y se apagan a la vez)
	var falta: float = segundos_por_zona - t_zona
	var avisando: bool = zonas.size() > 1 and falta <= aviso_antes_de_cambiar
	var apagado: bool = avisando and fmod(falta, 0.24) < 0.12
	# El de ahora
	var aviso: float = clampf(t_aviso / 1.5, 0.0, 1.0) * (1.0 if fmod(t_led, 0.2) < 0.12 else 0.4)
	haz.lente = _lente()
	haz.rect = _rect_luz()
	haz.color = color_luz
	haz.apagado = false
	cuadro.rect = _rect_luz()
	cuadro.color = color_luz.lerp(COLOR_AVISO, aviso)
	cuadro.ojo_rojo = aviso
	cuadro.apagado = false
	cuadro.ojo_apagado = apagado # Solo titila el ojito (el amarillo queda fijo hasta que cambia)
	# Donde viene el próximo: solo el ojito titilando (sin el amarillo ni la luz, eso aparece cuando cambia)
	haz_siguiente.visible = false
	cuadro_siguiente.visible = avisando
	if avisando:
		var c: Vector2 = _centro_zona(siguiente)
		cuadro_siguiente.rect = Rect2(c - tamano_zona / 2.0, tamano_zona)
		cuadro_siguiente.color = color_luz
		cuadro_siguiente.solo_ojo = true
		cuadro_siguiente.ojo_apagado = apagado
		cuadro_siguiente.queue_redraw()
	haz.queue_redraw()
	cuadro.queue_redraw()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or zonas.is_empty(): return
	if not GameManager.juego_activo or t_aviso > 0.0 or haz.modulate.a < 0.9: return
	var r: Rect2 = _rect_luz()
	for j in get_tree().get_nodes_in_group("Player"):
		if not (j is Player) or j.atrapado: continue
		# Tiene que TOCAR el cuadrado del piso con los pies (la V de luz no cuenta)
		var pies := Rect2(j.global_position - PIES / 2.0, PIES)
		if r.intersects(pies):
			_vio_a(j)
			return

func _vio_a(j: Player) -> void:
	t_aviso = 1.5
	if sonido.stream: sonido.play()
	var guardia = get_tree().get_first_node_in_group("Guardia")
	if guardia and guardia.has_method("aviso_camara"):
		guardia.aviso_camara(j, centro_luz)

# La cámara mira para el lado del cuadrado que vigila
func _mirar_hacia(punto: Vector2) -> void:
	if cabeza == null: return
	var izquierda: bool = punto.x < global_position.x - 1.0
	cabeza.flip_h = izquierda
	cabeza.position = CABEZA_IZQUIERDA if izquierda else CABEZA_DERECHA

func _lente() -> Vector2:
	if cabeza == null: return global_position + Vector2(0, -46)
	return to_global(cabeza.position + (LENTE_IZQUIERDA if cabeza.flip_h else LENTE_DERECHA))

# Dónde estaría el lente si la cámara mirara hacia ese punto (para la luz del cuadrado que viene)
func _lente_mirando(punto: Vector2) -> Vector2:
	var izquierda: bool = punto.x < global_position.x - 1.0
	var pos_cabeza: Vector2 = CABEZA_IZQUIERDA if izquierda else CABEZA_DERECHA
	return to_global(pos_cabeza + (LENTE_IZQUIERDA if izquierda else LENTE_DERECHA))

# =====================================================================
# DIBUJOS: la luz (de la cámara al cuadrado) y el cuadrado del piso
# =====================================================================
# En el editor: todos los cuadrados con su número y la luz hasta el primero
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	for i in zonas.size():
		var r := Rect2(to_local(_centro_zona(i)) - tamano_zona / 2.0, tamano_zona)
		draw_rect(r, Color(color_luz, 0.25 if i == 0 else 0.12))
		draw_rect(r, Color(color_luz, 0.9), false, 1.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(3, 12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.15, 0.0))
	if not zonas.is_empty():
		var r0 := Rect2(to_local(_centro_zona(0)) - tamano_zona / 2.0, tamano_zona)
		var pts := Haz.casco([to_local(_lente()), r0.position, r0.position + Vector2(r0.size.x, 0), r0.end, r0.position + Vector2(0, r0.size.y)])
		draw_colored_polygon(pts, Color(color_luz, 0.2))

class Haz extends Node2D:
	var lente := Vector2.ZERO
	var rect := Rect2()
	var color := Color.WHITE
	var apagado: bool = false # En este momento del titileo no se ve
	func _draw() -> void:
		if apagado: return
		var pts := casco([lente, rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
		if pts.size() < 3: return
		draw_colored_polygon(pts, Color(color, 0.2))
		# Los dos bordes de la V (desde el lente hasta las puntas del cuadrado)
		var i: int = pts.find(lente)
		if i >= 0:
			draw_line(lente, pts[(i + 1) % pts.size()], Color(color, 0.7), 1.0)
			draw_line(lente, pts[(i - 1 + pts.size()) % pts.size()], Color(color, 0.7), 1.0)
	# El "contorno" de un grupo de puntos (para que la luz sea una V que abarca todo el cuadrado)
	static func casco(puntos: Array) -> PackedVector2Array:
		var p: Array = puntos.duplicate()
		p.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
		var cruz = func(o: Vector2, a: Vector2, b: Vector2) -> float: return (a - o).cross(b - o)
		var abajo: Array = []
		for q in p:
			while abajo.size() >= 2 and cruz.call(abajo[-2], abajo[-1], q) <= 0: abajo.pop_back()
			abajo.append(q)
		var arriba: Array = []
		for k in range(p.size() - 1, -1, -1):
			var q = p[k]
			while arriba.size() >= 2 and cruz.call(arriba[-2], arriba[-1], q) <= 0: arriba.pop_back()
			arriba.append(q)
		abajo.pop_back(); arriba.pop_back()
		return PackedVector2Array(abajo + arriba)

class Cuadro extends Node2D:
	var rect := Rect2()
	var color := Color.WHITE
	var apagado: bool = false  # En este momento del titileo no se ve
	var solo_ojo: bool = false # Sin el amarillo: solo el ojito (el lugar del cuadrado que viene)
	var ojo_apagado: bool = false # El ojito, en este momento del titileo, no se ve
	var ojo_rojo: float = 0.0  # 1 = el ojo se pone rojo (acaba de ver a alguien)
	var ojo: Texture2D
	func _draw() -> void:
		if apagado: return
		var fuerza: float = 1.0
		if not solo_ojo:
			draw_rect(rect, Color(color, 0.32 * fuerza))
			draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE), Color(color, 0.95 * fuerza), false, 1.0)
		if ojo_apagado: return
		# El ojito en el medio: "te están mirando"
		if ojo == null: return
		var tam: Vector2 = ojo.get_size()
		var tinte: Color = Color.WHITE.lerp(Color(1.0, 0.35, 0.3), ojo_rojo)
		draw_texture(ojo, (rect.get_center() - tam / 2.0).round(), Color(tinte, 0.9 * fuerza))
