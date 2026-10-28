extends RefCounted
## CONTROLES DE LOS DOS JUGADORES (modo 2 JUGADORES - ROBO)
## Arma las acciones "p1_..." y "p2_..." desde el código (no hace falta tocar el Mapa de Entrada).
## Lo usan la pantalla de elegir personaje y el juego cooperativo:
##     preload("res://scripts/controles_coop.gd").armar()
##
##   Jugador 1: 1er joystick del tablero (o WASD) + sus botones (o E / Z / X / C)
##   Jugador 2: 2do joystick del tablero (o flechas) + sus botones (o J / K / L)

static func armar() -> void:
	# Jugador 1: control 0 del tablero + teclado izquierdo
	_accion("p1_move_left",  0, [KEY_A], JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
	_accion("p1_move_right", 0, [KEY_D], JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
	_accion("p1_move_up",    0, [KEY_W], JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
	_accion("p1_move_down",  0, [KEY_S], JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
	_boton("p1_btn_azul",     0, [KEY_Z], [JOY_BUTTON_A])
	_boton("p1_btn_rojo",     0, [KEY_X], [JOY_BUTTON_B])
	_boton("p1_btn_amarillo", 0, [KEY_C], [JOY_BUTTON_X])
	_boton("p1_interact",     0, [KEY_E, KEY_Z, KEY_X, KEY_C], [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X])
	# Jugador 2: control 1 del tablero + flechas y J/K/L
	_accion("p2_move_left",  1, [KEY_LEFT], JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
	_accion("p2_move_right", 1, [KEY_RIGHT], JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
	_accion("p2_move_up",    1, [KEY_UP], JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
	_accion("p2_move_down",  1, [KEY_DOWN], JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
	_boton("p2_btn_azul",     1, [KEY_J], [JOY_BUTTON_A])
	_boton("p2_btn_rojo",     1, [KEY_K], [JOY_BUTTON_B])
	_boton("p2_btn_amarillo", 1, [KEY_L], [JOY_BUTTON_X])
	_boton("p2_interact",     1, [KEY_J, KEY_K, KEY_L], [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X])

# Una dirección: tecla(s) + palanca + cruceta del control indicado
static func _accion(nombre: String, control: int, teclas: Array, eje: int, valor: float, cruceta: int) -> void:
	_nueva(nombre, 0.5)
	for tecla in teclas:
		var e = InputEventKey.new(); e.physical_keycode = tecla
		InputMap.action_add_event(nombre, e)
	var palanca = InputEventJoypadMotion.new()
	palanca.device = control; palanca.axis = eje; palanca.axis_value = valor
	InputMap.action_add_event(nombre, palanca)
	var boton = InputEventJoypadButton.new()
	boton.device = control; boton.button_index = cruceta
	InputMap.action_add_event(nombre, boton)

static func _boton(nombre: String, control: int, teclas: Array, botones: Array) -> void:
	_nueva(nombre, 0.5)
	for tecla in teclas:
		var e = InputEventKey.new(); e.physical_keycode = tecla
		InputMap.action_add_event(nombre, e)
	for b in botones:
		var e = InputEventJoypadButton.new(); e.device = control; e.button_index = b
		InputMap.action_add_event(nombre, e)

static func _nueva(nombre: String, zona_muerta: float) -> void:
	if InputMap.has_action(nombre): InputMap.erase_action(nombre)
	InputMap.add_action(nombre, zona_muerta)
