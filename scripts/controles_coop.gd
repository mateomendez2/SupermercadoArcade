extends RefCounted
## CONTROLES DE LOS DOS JUGADORES (modo 2 JUGADORES - ROBO)
## Arma las acciones "p1_..." y "p2_..." desde el código (no hace falta tocar el Mapa de Entrada).
## Lo usan las pantallas del modo 2 jugadores y el juego cooperativo:
##     preload("res://scripts/controles_coop.gd").armar()
##
##   Jugador 1 (mitad izquierda): su mando, o con el teclado  WASD  +  C (azul)  V (rojo)  B (amarillo)
##   Jugador 2 (mitad derecha):   su mando, o con el teclado  flechas  +  J (azul)  K (rojo)  L (amarillo)
##   (El teclado anda siempre, aunque ese jugador también tenga mando.)
##
## A QUIÉN LE TOCA CADA MANDO:
##   - El 1er mando conectado es del J1 y el 2do del J2 (en el tablero arcade: el 1er y el 2do joystick).
##   - Si hay un solo mando, es del J1 y el J2 juega con el teclado.
##   - Si se conecta un mando en el medio, es para el que no tenga.
##   - Si un mando se desconecta, el otro jugador NO se lo queda: cuando vuelve, sigue siendo de quien era.

# Las teclas de cada jugador (para cambiarlas, se cambian acá)
const TECLAS: Dictionary = {
	"p1_": {"izquierda": [KEY_A], "derecha": [KEY_D], "arriba": [KEY_W], "abajo": [KEY_S],
			"azul": [KEY_C], "rojo": [KEY_V], "amarillo": [KEY_B]},
	"p2_": {"izquierda": [KEY_LEFT], "derecha": [KEY_RIGHT], "arriba": [KEY_UP], "abajo": [KEY_DOWN],
			"azul": [KEY_J], "rojo": [KEY_K], "amarillo": [KEY_L]},
}
# Los botones del mando (los mismos que en el modo de un jugador)
const BOTON_AZUL: int = JOY_BUTTON_A
const BOTON_ROJO: int = JOY_BUTTON_B
const BOTON_AMARILLO: int = JOY_BUTTON_X
const ZONA_MUERTA: float = 0.5

# El mando de cada jugador (-1 = no tiene). Se acuerda aunque se cambie de pantalla.
static var mandos: Dictionary = {"p1_": -1, "p2_": -1}

static func armar() -> void:
	_repartir_mandos()
	_armar_acciones()
	if not Input.joy_connection_changed.is_connected(_se_conecto_o_desconecto):
		Input.joy_connection_changed.connect(_se_conecto_o_desconecto)

# El mando de ese jugador, si está conectado (-1 = juega con el teclado)
static func mando_de(prefijo: String) -> int:
	actualizar()
	var mando: int = mandos.get(prefijo, -1)
	return mando if mando >= 0 and Input.get_connected_joypads().has(mando) else -1

# Si cambió algún mando, vuelve a repartirlos y a armar las acciones
static func actualizar() -> void:
	if _repartir_mandos():
		_armar_acciones()

static func _se_conecto_o_desconecto(_mando: int, _conectado: bool) -> void:
	actualizar()

# Devuelve true si a alguien le tocó un mando nuevo
# (conectados: la lista de mandos conectados; se puede pasar a mano para probar)
static func _repartir_mandos(conectados: Array = Input.get_connected_joypads()) -> bool:
	conectados = conectados.duplicate()
	conectados.sort()
	var cambio: bool = false
	for p in ["p1_", "p2_"]:
		if conectados.has(mandos[p]): continue # Ya tiene el suyo
		# No tiene mando (o el suyo está desconectado): se lleva el primero que no sea de nadie
		for m in conectados:
			if m != mandos["p1_"] and m != mandos["p2_"]:
				mandos[p] = m
				cambio = true
				break
	return cambio

static func _armar_acciones() -> void:
	for p in ["p1_", "p2_"]:
		var t: Dictionary = TECLAS[p]
		var mando: int = mandos[p]
		_direccion(p + "move_left",  t["izquierda"], mando, JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
		_direccion(p + "move_right", t["derecha"],   mando, JOY_AXIS_LEFT_X,  1.0, JOY_BUTTON_DPAD_RIGHT)
		_direccion(p + "move_up",    t["arriba"],    mando, JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
		_direccion(p + "move_down",  t["abajo"],     mando, JOY_AXIS_LEFT_Y,  1.0, JOY_BUTTON_DPAD_DOWN)
		_boton(p + "btn_azul",     t["azul"],     mando, [BOTON_AZUL])
		_boton(p + "btn_rojo",     t["rojo"],     mando, [BOTON_ROJO])
		_boton(p + "btn_amarillo", t["amarillo"], mando, [BOTON_AMARILLO])
		# Agarrar / pagar / elegir: cualquiera de los tres botones
		_boton(p + "interact", t["azul"] + t["rojo"] + t["amarillo"], mando, [BOTON_AZUL, BOTON_ROJO, BOTON_AMARILLO])

# Una dirección: tecla(s) + palanca + cruceta (si ese jugador tiene mando)
static func _direccion(nombre: String, teclas: Array, mando: int, eje: int, valor: float, cruceta: int) -> void:
	_nueva(nombre, teclas)
	if mando < 0: return
	var palanca = InputEventJoypadMotion.new()
	palanca.device = mando; palanca.axis = eje; palanca.axis_value = valor
	InputMap.action_add_event(nombre, palanca)
	var boton = InputEventJoypadButton.new()
	boton.device = mando; boton.button_index = cruceta
	InputMap.action_add_event(nombre, boton)

static func _boton(nombre: String, teclas: Array, mando: int, botones: Array) -> void:
	_nueva(nombre, teclas)
	if mando < 0: return
	for b in botones:
		var e = InputEventJoypadButton.new(); e.device = mando; e.button_index = b
		InputMap.action_add_event(nombre, e)

static func _nueva(nombre: String, teclas: Array) -> void:
	if InputMap.has_action(nombre): InputMap.erase_action(nombre)
	InputMap.add_action(nombre, ZONA_MUERTA)
	for tecla in teclas:
		var e = InputEventKey.new(); e.physical_keycode = tecla
		InputMap.action_add_event(nombre, e)
