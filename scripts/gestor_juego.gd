extends Node

# Señales para comunicar a la Interfaz
signal list_generated(target_items: Array[ItemData]) # Se emite al inicio
signal item_collected(item: ItemData) # Se emite cuando tachamos uno de la lista
signal game_won
signal start_qte_colores 
signal start_qte_mashing
signal start_qte_caida # NUEVO: el minijuego de los círculos que caen
signal start_qte_tinta # NUEVO: el minijuego del truco del color
signal lista_lista_para_pagar # Avisa que ya tenemos todo
signal lista_incompleta       # Avisa que nos robaron algo y ya no tenemos todo

# 1. LA BASE DE DATOS (Nuestra lista maestra)
# preload() carga los archivos a la memoria en cuanto el juego arranca.
# Asegúrate de que las rutas (res://...) coincidan con donde guardaste tus .tres
var database: Array[ItemData] = [
	preload("res://resources/items/manzana.tres"),
	preload("res://resources/items/naranja.tres")
	# Ve agregando los demás preload() separados por coma cuando los crees
]

# 2. LAS LISTAS DE LA PARTIDA ACTUAL
var target_list: Array[ItemData] = [] # Lo que el juego te pide buscar
var collected_items: Array[ItemData] = [] # Lo que ya agarraste de la góndola

# --- VARIABLES DEL RELOJ ---
var tiempo_restante: float = 90.0 # Bastante tiempo para probar tranquilos
var tiempo_total: float = 90.0 # NUEVO: El tiempo con el que arrancó el nivel (para los bloques de la franja)
var juego_activo: bool = false
signal time_updated(tiempo: int)
signal game_over_reached
signal qte_cancelled # NUEVA SEÑAL

signal item_dropped(item: ItemData) # ¡NUEVA! Avisa qué ítem se nos cayó

# --- CARTEL "NIVEL X" ---
# La UI pone esto en true mientras la pantalla está en negro con el cartel.
# El nivel lo consulta para esperar antes de hacer entrar al jugador.
var mostrando_cartel: bool = false
signal cartel_nivel_terminado # La UI avisa cuando la pantalla negra empieza a disolverse

# --- NIVELES Y PROGRESO ---
# La lista de niveles en orden. Para agregar un nivel nuevo, sumalo al final.
# (La usan la pantalla de selección de niveles y el juego)
const RUTAS_NIVELES: Array[String] = [
	"res://scenes/levels/nivel_1.tscn", # 0 -> NIVEL 1
	"res://scenes/levels/nivel_2.tscn", # 1 -> NIVEL 2
	"res://scenes/levels/nivel_3.tscn", # 2 -> NIVEL 3
	"res://scenes/levels/nivel_4.tscn", # 3 -> NIVEL 4
	"res://scenes/levels/nivel_5.tscn", # 4 -> NIVEL 5
	"res://scenes/levels/nivel_6.tscn", # 5 -> NIVEL 6
]
const GUARDAR_PROGRESO: bool = true  # false = cada vez que se abre el juego arranca con el nivel 1 solo
const DESBLOQUEAR_TODO: bool = false # true = todos los niveles abiertos (para probar)
const ARCHIVO_PROGRESO: String = "user://progreso.cfg"

var nivel_elegido: int = 0         # El nivel que se eligió en la pantalla de niveles (0 = NIVEL 1)
var nivel_desbloqueado: int = 0    # Hasta qué nivel se puede jugar (0 = solo el NIVEL 1)
var posicion_musica_menu: float = 0.0 # Para que la música del menú no arranque de cero al pasar de pantalla

func _ready() -> void:
	_cargar_progreso()

func esta_desbloqueado(indice: int) -> bool:
	return DESBLOQUEAR_TODO or indice <= nivel_desbloqueado

# Se llama al ganar un nivel: abre el siguiente (si existe)
func desbloquear_nivel(indice: int) -> void:
	indice = mini(indice, RUTAS_NIVELES.size() - 1)
	if indice <= nivel_desbloqueado: return
	nivel_desbloqueado = indice
	_guardar_progreso()

func _cargar_progreso() -> void:
	if not GUARDAR_PROGRESO: return
	var archivo = ConfigFile.new()
	if archivo.load(ARCHIVO_PROGRESO) == OK:
		nivel_desbloqueado = clampi(archivo.get_value("niveles", "desbloqueado", 0), 0, RUTAS_NIVELES.size() - 1)

func _guardar_progreso() -> void:
	if not GUARDAR_PROGRESO: return
	var archivo = ConfigFile.new()
	archivo.set_value("niveles", "desbloqueado", nivel_desbloqueado)
	archivo.save(ARCHIVO_PROGRESO)

# --- LÓGICA DE GENERACIÓN ---
# Ahora recibimos la lista exacta de frutas y el tiempo
func iniciar_nivel(items_necesarios: Array[ItemData], tiempo_asignado: float) -> void:
	target_list.clear()
	collected_items.clear()
	
	# Usamos EXACTAMENTE la lista que nos pasó el nivel
	# Usamos duplicate() por seguridad para no modificar el archivo original
	target_list = items_necesarios.duplicate()
			
	# Le avisamos a la Interfaz para que escriba los nombres
	list_generated.emit(target_list)
	
	# BUGFIX: Cargamos el tiempo pero el reloj arranca APAGADO.
	# El nivel llama a arrancar_reloj() cuando termina la cinemática de entrada.
	tiempo_restante = tiempo_asignado
	tiempo_total = tiempo_asignado
	juego_activo = false
	time_updated.emit(int(tiempo_restante)) # Para que la UI muestre el tiempo completo desde el principio

# El nivel llama a esta función cuando el jugador recupera el control
func arrancar_reloj() -> void:
	juego_activo = true

# --- LÓGICA DE RECOLECCIÓN ---
func add_item(new_item: ItemData) -> void:
	# 1. Verificamos si el objeto que tocaste está en la lista que te pidieron
	if new_item in target_list:
		
		# 2. Verificamos que no lo hayas agarrado ya por accidente
		if not new_item in collected_items:
			collected_items.append(new_item)
			print("¡BIEN! Tachaste: ", new_item.item_name)
			item_collected.emit(new_item)
			
			check_win_condition()
		else:
			print("Ya habías agarrado ", new_item.item_name, ". Ve a buscar lo demás.")
			
	else:
		# Si agarras algo que no está en la lista, ¿restamos puntos o tiempo?
		# Por ahora solo damos un aviso:
		print("¡ERROR! ", new_item.item_name, " no está en tu lista de compras.")

# Ahora solo avisa que estamos listos para ir a pagar
func check_win_condition() -> void:
	if collected_items.size() == target_list.size():
		print("Lista completa. ¡Ve a la caja registradora a pagar!")
		lista_lista_para_pagar.emit() # ¡NUEVA LÍNEA!

# ¡NUEVA FUNCIÓN! La caja registradora llamará a esta.
func intentar_pagar() -> void:
	if collected_items.size() == target_list.size():
		juego_activo = false # Pausamos el reloj
		print("¡PAGO EXITOSO! VICTORIA.")
		game_won.emit() # Recién ahora lanzamos la pantalla oscura
	else:
		print("Cajero: ¡Eh! Te faltan cosas de la lista.")

# Necesitamos una variable para recordar qué góndola estamos usando
var gondola_actual: Interactable = null
signal start_qte_ui # Le avisa al Main que muestre el minijuego

signal qte_failed # NUEVA SEÑAL: Avisará que perdimos

func request_qte(gondola: Interactable) -> void:
	# NUEVO CANDADO: Si ya estamos jugando un minijuego (gondola_actual tiene algo), 
	# rechazamos cualquier otra petición de inmediato.
	if gondola_actual != null: 
		return 
	
	# Si pasamos el candado, registramos esta góndola
	gondola_actual = gondola
	
	# ¿La góndola ya tiene un minijuego guardado en su memoria?
	if gondola_actual.minijuego_guardado == "":
		
		# Tiramos un dado de 5 caras (del 0 al 4)
		var dado = randi() % 5
		
		if dado == 0:
			gondola_actual.minijuego_guardado = "barrita"
		elif dado == 1:
			gondola_actual.minijuego_guardado = "colores"
		elif dado == 2:
			gondola_actual.minijuego_guardado = "mashing"
		elif dado == 3:
			gondola_actual.minijuego_guardado = "caida"
		else:
			gondola_actual.minijuego_guardado = "tinta"
			
	# Ahora leemos la memoria y abrimos el correcto
	if gondola_actual.minijuego_guardado == "barrita":
		print("Abriendo la Barrita...")
		start_qte_ui.emit() 
	elif gondola_actual.minijuego_guardado == "colores":
		print("Abriendo los Colores...")
		start_qte_colores.emit()
	elif gondola_actual.minijuego_guardado == "mashing":
		print("Abriendo el Machaque...")
		start_qte_mashing.emit()
	elif gondola_actual.minijuego_guardado == "caida":
		print("Abriendo la Caída...")
		start_qte_caida.emit()
	elif gondola_actual.minijuego_guardado == "tinta":
		print("Abriendo el Truco del Color...")
		start_qte_tinta.emit()

func resolve_qte(success: bool) -> void:
	# GUARDIA DE SEGURIDAD (Evita el crash rojo por si acaso)
	if gondola_actual != null:
		if success:
			print("GameManager: ¡QTE Superado!")
			gondola_actual.succesful_interaction()
		else:
			print("GameManager: ¡Fallaste el QTE!")
			gondola_actual.failed_interaction()
			# Gritamos a todo el mundo que fallamos
			qte_failed.emit() 
			
	gondola_actual = null

func _process(delta: float) -> void:
	if juego_activo:
		tiempo_restante -= delta # Restamos milisegundos
		time_updated.emit(int(tiempo_restante)) # Avisamos a la UI
		
		# Si llega a cero, perdemos
		if tiempo_restante <= 0:
			juego_activo = false
			print("¡SE ACABÓ EL TIEMPO!")
			
			# --- ¡LA SOLUCIÓN! ---
			# Abortamos de emergencia cualquier QTE que esté abierto
			cancelar_qte() 
			# ---------------------
			
			game_over_reached.emit()

func cancelar_qte() -> void:
	# Cerramos la UI
	qte_cancelled.emit()
	
	# Le sumamos un fallo a la góndola por huir (opcional, si quieres castigarlo)
	if gondola_actual != null:
		gondola_actual.failed_interaction()
		
	# Limpiamos todo
	gondola_actual = null

# --- SISTEMA DE CASTIGO ---
func perder_ultimo_item() -> ItemData:
	if collected_items.size() == 0: return null
	
	var item_perdido = collected_items.pop_back()
	item_dropped.emit(item_perdido)
	
	# ¡NUEVA LÍNEA! Como perdimos algo, la lista ya no está completa
	lista_incompleta.emit() 
	
	return item_perdido
