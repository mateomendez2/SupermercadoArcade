extends Area2D
## SALIDA DEL MODO 2 JUGADORES (ROBO)
## En este modo no se paga en la caja (las cajas quedan de adorno). Cuando tienen todo lo de la lista:
##   - Se marca una zona enfrente de la puerta (las mismas esquinitas que titilan de la caja).
##   - A cada uno le aparece la bolsa del botín, que le marca por dónde ir (cada uno ve la suya).
##   - Cuando están los dos adentro de la zona, se abre la puerta, se escapan y ganan.
## Si a la lista le vuelve a faltar algo, la salida se apaga hasta que la completen de nuevo.
##
## Si el nivel tiene un nodo con este script (grupo "SalidaCoop"), se usa ese y se puede mover desde el editor.
## Si no tiene, juego_coop.gd pone una sola enfrente de la puerta.

const ZonaBorde = preload("res://scripts/zona_borde.gd")
const GuiaSalida = preload("res://scripts/guia_salida.gd")

@export var tamano: Vector2 = Vector2(64, 32) # Lo que ocupa la zona (en pixeles del mundo)
@export var tienen_que_estar_los_dos: bool = true # false = alcanza con que llegue uno
@export var color_zona: Color = Color8(250, 196, 60) # Dorado, como el botín
@export var tiempo_escape: float = 1.2 # Lo que tardan en salir por la puerta

var abierta: bool = false   # true = ya tienen toda la lista
var escapando: bool = false
var adentro: Array[Node] = []
var zona: ColorRect
var guias: Array[Node] = []
var sonido: AudioStreamPlayer # El mismo "¡ding!" de la caja cuando completás la lista
const RUTA_SONIDO: String = "res://assets/audio/SonidoCaja.wav"

func _ready() -> void:
	add_to_group("SalidaCoop")
	var forma = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = tamano
	forma.shape = rect
	add_child(forma)

	zona = ColorRect.new()
	zona.set_script(ZonaBorde)
	zona.color_esquina = color_zona
	zona.position = -tamano / 2.0
	zona.size = tamano
	zona.z_index = -1
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zona.hide()
	add_child(zona)

	sonido = AudioStreamPlayer.new()
	sonido.volume_db = -4.0
	if ResourceLoader.exists(RUTA_SONIDO): sonido.stream = load(RUTA_SONIDO)
	add_child(sonido)

	body_entered.connect(_entro)
	body_exited.connect(_salio)
	GameManager.lista_lista_para_pagar.connect(_abrir)
	GameManager.lista_incompleta.connect(_cerrar)
	GameManager.game_won.connect(_cerrar)

# Por si alguien queda adentro sin moverse (por ejemplo, el que vuelve a entrar después del guardia)
func _physics_process(_delta: float) -> void:
	if abierta and not escapando: _ver_si_se_escapan()

func rect_global() -> Rect2:
	return Rect2(global_position - tamano / 2.0, tamano)

func esta_adentro(jugador: Node) -> bool:
	return adentro.has(jugador)

# =====================================================================
# SE PRENDE / SE APAGA
# =====================================================================
func _abrir() -> void:
	if escapando: return
	abierta = true
	if sonido.stream: sonido.play()
	zona.show()
	if guias.is_empty(): _armar_guias()
	for g in guias: g.show()
	_ver_si_se_escapan()

func _cerrar() -> void:
	abierta = false
	zona.hide()
	for g in guias: g.hide()

# Una bolsa para cada jugador, que se ve solo en su mitad de la pantalla
func _armar_guias() -> void:
	var pd = get_tree().get_first_node_in_group("PantallaDividida")
	if pd == null: return
	var lista = [[pd.jugador_1, pd.camara_1, pd.CAPA_SOLO_J1], [pd.jugador_2, pd.camara_2, pd.CAPA_SOLO_J2]]
	for datos in lista:
		var g = Node2D.new()
		g.set_script(GuiaSalida)
		add_child(g)
		g.preparar(datos[0], datos[1], self, datos[2])
		guias.append(g)

# =====================================================================
# QUIÉN ESTÁ ADENTRO
# =====================================================================
func _entro(body: Node2D) -> void:
	if body is Player and not adentro.has(body):
		adentro.append(body)
		_ver_si_se_escapan()

func _salio(body: Node2D) -> void:
	adentro.erase(body)

func _ver_si_se_escapan() -> void:
	if not abierta or escapando: return
	var jugadores = get_tree().get_nodes_in_group("Player").filter(func(j): return j is Player)
	# Al que el guardia está llevando a la puerta (o está afuera esperando) no se lo cuenta
	var faltan = jugadores.filter(func(j): return not adentro.has(j) or j.atrapado)
	if adentro.filter(func(j): return not j.atrapado).is_empty(): return
	if tienen_que_estar_los_dos and not faltan.is_empty(): return
	_escapar(jugadores)

# =====================================================================
# SE ESCAPAN POR LA PUERTA
# =====================================================================
func _escapar(jugadores: Array) -> void:
	escapando = true
	GameManager.juego_activo = false # Se frena el reloj
	zona.hide()
	for g in guias: g.hide()
	var puerta = get_tree().get_first_node_in_group("PuertaEntrada")
	var x_puerta: float = puerta.global_position.x if puerta else global_position.x
	var y_afuera: float = (puerta.global_position.y if puerta else global_position.y - 64.0) - 28.0
	if puerta and puerta.get("anim_sprite"): puerta.anim_sprite.play("open")

	# El que está más cerca de la puerta sale primero; el otro, atrás (en fila, como cuando entraron)
	jugadores.sort_custom(func(a, b): return a.global_position.distance_to(Vector2(x_puerta, y_afuera)) < b.global_position.distance_to(Vector2(x_puerta, y_afuera)))
	var salidas: Array[Tween] = []
	for i in jugadores.size():
		var j: Player = jugadores[i]
		j.is_frozen = true
		j.velocity = Vector2.ZERO
		var t = j.create_tween()
		t.tween_interval(i * 0.25)
		# 1. Se pone enfrente de la puerta
		var dx: float = x_puerta - j.global_position.x
		if absf(dx) > 1.0:
			t.tween_callback(j.anim_sprite.play.bind("walk_right" if dx > 0 else "walk_left"))
			t.tween_property(j, "global_position:x", x_puerta, clampf(absf(dx) / 80.0, 0.1, 0.5))
		# 2. Sale caminando para arriba y desaparece por la puerta
		t.tween_callback(j.anim_sprite.play.bind("walk_up"))
		var tiempo_subida: float = clampf((j.global_position.y - y_afuera) / 60.0, 0.4, tiempo_escape)
		t.tween_property(j, "global_position:y", y_afuera, tiempo_subida)
		t.parallel().tween_property(j, "modulate:a", 0.0, 0.3).set_delay(maxf(tiempo_subida - 0.3, 0.0))
		salidas.append(t)
	for t in salidas:
		if t.is_valid() and t.is_running(): await t.finished
	if not is_inside_tree(): return
	await get_tree().create_timer(0.2).timeout
	GameManager.intentar_pagar() # Tienen toda la lista: ¡ganan!
