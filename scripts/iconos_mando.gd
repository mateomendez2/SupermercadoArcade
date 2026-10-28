extends RefCounted
## BOTONES O TECLAS EN LOS MINIJUEGOS
## Los dibujos de los botones (azul, rojo, amarillo) cambian según con qué se esté jugando:
##   - Sin mando: teclas del teclado del mismo color (ver abajo qué letras).
##   - Mando de Xbox: los botones de colores con A (azul), B (rojo) y X (amarillo).
##   - Mando de PlayStation: los botones de colores con la cruz (azul), el círculo (rojo) y el cuadrado (amarillo).
##   - Tablero arcade u otro mando: los botones de colores lisos (los de siempre).
## Si se conecta o se desconecta un mando, cambian solos.
##   Modo de un jugador:       J (azul)  K (rojo)  L (amarillo)
##   Modo 2 jugadores, el J1:  Z (azul)  X (rojo)  C (amarillo)   (su mando es el 1er joystick del tablero)
##   Modo 2 jugadores, el J2:  J (azul)  K (rojo)  L (amarillo)   (su mando es el 2do joystick del tablero)
## Lo usan los minijuegos:  preload("res://scripts/iconos_mando.gd").aplicar(self)
## Los dibujos están en assets/ (TeclaJ.png..., BotonAzul_xbox.png, BotonAzul_ps.png...), con el mismo
## formato que los botones: a la izquierda normal y a la derecha hundido.

const BOTONES: Dictionary = {
	"res://assets/BotonAzul.png": "azul",
	"res://assets/BotonRojoAnim.png": "rojo",
	"res://assets/BotonAmarillo.png": "amarillo",
}
const TECLAS: Dictionary = {
	"": {"azul": "res://assets/TeclaJ.png", "rojo": "res://assets/TeclaK.png", "amarillo": "res://assets/TeclaL.png"},
	"p1_": {"azul": "res://assets/TeclaZ.png", "rojo": "res://assets/TeclaX.png", "amarillo": "res://assets/TeclaC.png"},
	"p2_": {"azul": "res://assets/TeclaJ.png", "rojo": "res://assets/TeclaK.png", "amarillo": "res://assets/TeclaL.png"},
}

# Botones de colores con el dibujo de cada marca de mando
const MANDOS: Dictionary = {
	"xbox": {"azul": "res://assets/BotonAzul_xbox.png", "rojo": "res://assets/BotonRojo_xbox.png", "amarillo": "res://assets/BotonAmarillo_xbox.png"},
	"ps": {"azul": "res://assets/BotonAzul_ps.png", "rojo": "res://assets/BotonRojo_ps.png", "amarillo": "res://assets/BotonAmarillo_ps.png"},
}

# El mando de ese jugador (-1 = no tiene mando conectado).
# Modo de un jugador: el primero que esté conectado. Modo 2 jugadores: el 1er joystick es del J1 y el 2do del J2.
static func mando_de(prefijo: String = "") -> int:
	var mandos: Array[int] = Input.get_connected_joypads()
	if prefijo == "p1_": return 0 if mandos.has(0) else -1
	if prefijo == "p2_": return 1 if mandos.has(1) else -1
	return mandos[0] if mandos.size() > 0 else -1

static func hay_mando(prefijo: String = "") -> bool:
	return mando_de(prefijo) >= 0

# Qué mando es: "xbox", "ps" (PlayStation) o "generico" (tablero arcade u otro)
static func tipo_de_mando(mando: int) -> String:
	var nombre: String = Input.get_joy_name(mando).to_lower()
	var fabricante: int = int(Input.get_joy_info(mando).get("vendor_id", -1))
	if fabricante == 1356: return "ps"   # Sony
	if fabricante == 1118: return "xbox" # Microsoft
	for pista in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if pista in nombre: return "ps"
	for pista in ["xbox", "xinput", "microsoft"]:
		if pista in nombre: return "xbox"
	return "generico"

# Pone botones o teclas en todos los dibujos de un minijuego (y en sus texturas "hundidas")
static func aplicar(minijuego: Node) -> void:
	var prefijo: String = minijuego.get("prefijo") if minijuego.get("prefijo") != null else ""
	var mando: int = mando_de(prefijo)
	var tipo: String = "teclado" if mando < 0 else tipo_de_mando(mando)
	# La primera vez, el minijuego se queda con copias propias de los dibujos de los botones:
	# así, en el modo 2 jugadores, cada uno puede ver sus teclas sin cambiarle las del otro
	if not minijuego.has_meta("dibujos_propios"):
		_hacer_propios(minijuego)
	for t in minijuego.get_meta("dibujos_propios"):
		_cambiar(t, tipo, prefijo)

static func _es_boton(t) -> bool:
	return t is AtlasTexture and t.atlas != null and (t.has_meta("boton_original") or BOTONES.has(t.atlas.resource_path))

# Reemplaza cada dibujo de botón por una copia, en todos lados donde se usa (nodos y variables del minijuego)
static func _hacer_propios(minijuego: Node) -> void:
	var copias: Dictionary = {} # dibujo compartido -> su copia
	var propia = func(t: AtlasTexture) -> AtlasTexture:
		if not copias.has(t):
			var c: AtlasTexture = t.duplicate()
			c.set_meta("boton_original", t.get_meta("boton_original") if t.has_meta("boton_original") else t.atlas.resource_path)
			copias[t] = c
		return copias[t]
	for nodo in [minijuego] + minijuego.find_children("*", "", true, false):
		var t = nodo.get("texture")
		if _es_boton(t): nodo.set("texture", propia.call(t))
	for propiedad in minijuego.get_property_list():
		if not (propiedad.usage & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var valor = minijuego.get(propiedad.name)
		if _es_boton(valor):
			minijuego.set(propiedad.name, propia.call(valor))
		elif valor is Dictionary:
			for clave in valor.keys():
				if _es_boton(valor[clave]): valor[clave] = propia.call(valor[clave])
	minijuego.set_meta("dibujos_propios", copias.values())

static func _cambiar(t: AtlasTexture, tipo: String, prefijo: String) -> void:
	if t.atlas == null: return
	# La primera vez se anota de qué botón era (después el dibujo puede ser una tecla)
	if not t.has_meta("boton_original"):
		if not BOTONES.has(t.atlas.resource_path): return
		t.set_meta("boton_original", t.atlas.resource_path)
	var original: String = t.get_meta("boton_original")
	var color: String = BOTONES[original]
	var destino: String = original # Tablero arcade u otro mando: el botón liso de siempre
	if tipo == "teclado":
		destino = TECLAS.get(prefijo, TECLAS[""])[color]
	elif MANDOS.has(tipo):
		destino = MANDOS[tipo][color]
	if t.atlas.resource_path != destino:
		t.atlas = load(destino)
