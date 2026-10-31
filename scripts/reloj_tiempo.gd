extends Node2D
## RELOJ VERDE DE TIEMPO EXTRA
## Un cronómetro verde fluo que flota sobre el piso. Si un jugador lo toca, suma tiempo al reloj del nivel
## y aparece un cartelito "+25s" que sube y se desvanece.
## Se queda hasta que alguien lo agarre (o, si el nivel le pone duración, titila y se va).
## Lo pone relojes_tiempo.gd (no hace falta ponerlo a mano en el nivel).

const TEX_CRONOMETRO: Texture2D = preload("res://assets/ui/tiempo_extra/cronometro.png")
const CARPETA_NUMEROS: String = "res://assets/ui/tiempo_extra/"
const RUTA_SONIDO_AGARRAR: String = "res://assets/audio/TiempoExtra.wav"
const RUTA_SONIDO_APARECE: String = "res://assets/audio/RelojAparece.wav"

# --- LO PONE relojes_tiempo.gd (sale de la configuración del nivel) ---
var segundos: int = 25          # Cuánto tiempo suma
var duracion: float = 0.0       # Cuánto se queda en el piso si nadie lo agarra (0 = hasta que lo agarren)

# --- AJUSTES FINOS ---
const DISTANCIA_AGARRE: float = 11.0 # Qué tan cerca tienen que pasar los pies del jugador
const AVISO_ANTES_DE_IRSE: float = 3.0 # Los últimos segundos titila
const ALTURA_FLOTE: float = 12.0     # A qué altura del piso flota
const VAIVEN: float = 2.0            # Cuánto sube y baja
const COLOR_HALO: Color = Color(0.45, 1.0, 0.45)

var sprite: Sprite2D
var halo: Node2D
var vida: float = 0.0
var tiempo: float = 0.0
var agarrado: bool = false

func _ready() -> void:
	add_to_group("RelojTiempo")
	vida = duracion
	# Sombra y brillo (abajo del cronómetro)
	halo = Node2D.new()
	add_child(halo)
	halo.draw.connect(_dibujar_halo)
	sprite = Sprite2D.new()
	sprite.texture = TEX_CRONOMETRO
	sprite.position = Vector2(0, -ALTURA_FLOTE)
	add_child(sprite)
	# Aparece con un saltito
	sprite.scale = Vector2.ZERO
	var t = create_tween()
	t.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.12)
	t.tween_property(sprite, "scale", Vector2.ONE, 0.1)
	_sonar(RUTA_SONIDO_APARECE, -12.0)
	GameManager.game_won.connect(queue_free)
	GameManager.game_over_reached.connect(queue_free)

func _process(delta: float) -> void:
	if agarrado: return
	tiempo += delta
	# Flota subiendo y bajando, y brilla como un cartel fluo
	sprite.position.y = round(-ALTURA_FLOTE - sin(tiempo * 4.0) * VAIVEN)
	var brillo: float = 1.0 + 0.25 * (0.5 + 0.5 * sin(tiempo * 7.0))
	sprite.modulate = Color(brillo, brillo, brillo)
	halo.queue_redraw()
	if not GameManager.juego_activo: return
	# ¿Lo tocó algún jugador?
	for j in get_tree().get_nodes_in_group("Player"):
		if not j is Player or j.get("atrapado"): continue
		if j.global_position.distance_to(global_position) <= DISTANCIA_AGARRE:
			_agarrar(j)
			return
	# Se le acaba el tiempo: titila y se va (si tiene duración; con 0 se queda hasta que lo agarren)
	if duracion <= 0.0: return
	vida -= delta
	if vida <= AVISO_ANTES_DE_IRSE:
		sprite.visible = fmod(vida, 0.3) > 0.12
	if vida <= 0.0:
		_irse()

func _dibujar_halo() -> void:
	# Sombra en el piso (se achica cuando el cronómetro sube)
	var alto: float = 0.5 + 0.5 * sin(tiempo * 4.0)
	var ancho: float = round(lerpf(12.0, 9.0, alto))
	halo.draw_rect(Rect2(-ancho / 2.0, -2, ancho, 3), Color(0, 0, 0, 0.28))
	if not sprite.visible: return
	# Resplandor verde alrededor del cronómetro (late despacito)
	var r: float = 10.0 + sin(tiempo * 7.0) * 1.0
	halo.draw_circle(sprite.position + Vector2(0, 1), r, Color(COLOR_HALO, 0.22), true, -1.0, false)
	halo.draw_circle(sprite.position + Vector2(0, 1), r - 3.0, Color(COLOR_HALO, 0.18), true, -1.0, false)

func _agarrar(_jugador: Node2D) -> void:
	agarrado = true
	GameManager.sumar_tiempo(segundos)
	_sonar(RUTA_SONIDO_AGARRAR, -4.0)
	_cartelito()
	# El cronómetro pega un saltito y desaparece
	sprite.visible = true
	halo.hide()
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.15)
	t.tween_property(sprite, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)

func _irse() -> void:
	agarrado = true
	sprite.visible = true
	var t = create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", Vector2.ZERO, 0.15)
	t.tween_property(halo, "modulate:a", 0.0, 0.15)
	t.chain().tween_callback(queue_free)

# El cartelito "+25s" con los números verdes (los mismos del reloj de arriba): sube y se desvanece
func _cartelito() -> void:
	var cartel := Node2D.new()
	cartel.z_index = 60 # Por encima de todo
	var texto: String = "+" + str(segundos) + "s"
	var x: float = 0.0
	for letra in texto:
		var nombre: String = "mas" if letra == "+" else ("s" if letra == "s" else "num_" + letra)
		var s := Sprite2D.new()
		s.texture = load(CARPETA_NUMEROS + nombre + ".png")
		s.centered = false
		s.position = Vector2(x, 0)
		cartel.add_child(s)
		x += 12.0 # Mismo paso que los números de la franja
	var ancho: float = x + 2.0
	for s in cartel.get_children():
		s.position.x -= round(ancho / 2.0)
		s.position.y -= 9.0
	get_parent().add_child(cartel)
	cartel.global_position = (global_position + Vector2(0, -ALTURA_FLOTE - 14.0)).round()
	cartel.scale = Vector2(0.4, 0.4)
	var t = cartel.create_tween()
	t.tween_property(cartel, "scale", Vector2(1.15, 1.15), 0.1)
	t.tween_property(cartel, "scale", Vector2.ONE, 0.08)
	t.tween_property(cartel, "position:y", cartel.position.y - 18.0, 0.8).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(cartel, "modulate:a", 0.0, 0.35).set_delay(0.5)
	t.tween_callback(cartel.queue_free)

# Sonido que sigue sonando aunque el reloj desaparezca
func _sonar(ruta: String, volumen: float) -> void:
	if not ResourceLoader.exists(ruta) or get_parent() == null: return
	var sonido := AudioStreamPlayer.new()
	sonido.stream = load(ruta)
	sonido.volume_db = volumen
	get_parent().add_child.call_deferred(sonido)
	sonido.ready.connect(sonido.play)
	sonido.finished.connect(sonido.queue_free)
