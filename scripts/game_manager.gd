extends Node

# Señales para comunicar a la Interfaz
signal list_generated(target_items: Array[ItemData]) # Se emite al inicio
signal item_collected(item: ItemData) # Se emite cuando tachamos uno de la lista
signal game_won
signal start_qte_colores 

# 1. LA BASE DE DATOS (Nuestra lista maestra)
# preload() carga los archivos a la memoria en cuanto el juego arranca.
# Asegúrate de que las rutas (res://...) coincidan con donde guardaste tus .tres
var database: Array[ItemData] = [
	preload("res://resources/items/apple.tres"),
	preload("res://resources/items/orange.tres")
	# Ve agregando los demás preload() separados por coma cuando los crees
]

# 2. LAS LISTAS DE LA PARTIDA ACTUAL
var target_list: Array[ItemData] = [] # Lo que el juego te pide buscar
var collected_items: Array[ItemData] = [] # Lo que ya agarraste de la góndola

# --- VARIABLES DEL RELOJ ---
var tiempo_restante: float = 90.0 # Bastante tiempo para probar tranquilos
var juego_activo: bool = false
signal time_updated(tiempo: int)
signal game_over_reached
signal qte_cancelled # NUEVA SEÑAL

func _ready() -> void:
	pass # Ya no generamos la lista aquí automáticamente

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
	
	# Encendemos el reloj
	tiempo_restante = tiempo_asignado
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
		# Tiramos la moneda por PRIMERA VEZ
		var moneda = randf()
		if moneda > 0.5:
			gondola_actual.minijuego_guardado = "barrita"
		else:
			gondola_actual.minijuego_guardado = "colores"
	
	# Ahora simplemente leemos la memoria de la góndola y abrimos el correcto
	if gondola_actual.minijuego_guardado == "barrita":
		print("Abriendo la Barrita...")
		start_qte_ui.emit() 
	elif gondola_actual.minijuego_guardado == "colores":
		print("Abriendo los Colores...")
		start_qte_colores.emit()

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
		time_updated.emit(int(tiempo_restante)) # Avisamos a la UI (sin decimales)
		
		# Si llega a cero, perdemos
		if tiempo_restante <= 0:
			juego_activo = false
			print("¡SE ACABÓ EL TIEMPO!")
			game_over_reached.emit()

func cancelar_qte() -> void:
	# Cerramos la UI
	qte_cancelled.emit()
	
	# Le sumamos un fallo a la góndola por huir (opcional, si quieres castigarlo)
	if gondola_actual != null:
		gondola_actual.failed_interaction()
		
	# Limpiamos todo
	gondola_actual = null
