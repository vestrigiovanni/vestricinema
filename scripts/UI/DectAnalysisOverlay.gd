extends Node
## DectAnalysisOverlay (Fase 11)
##
## Collegato al ray picking della Fase 10: quando l'operatore clicca un punto del
## volume, oltre alla selezione/drag (gestita da ObjectDragger, che NON tocchiamo)
## esegue l'analisi Dual-Energy CT sul voxel colpito. Campiona la Texture3D nel
## punto, simula due acquisizioni a 80/140 kVp con coefficienti di attenuazione
## diversi per categoria, e dal loro RAPPORTO deduce il materiale — invece di
## leggere z_eff direttamente dalla texture.
##
## Mostra un popup non invasivo (tooltip industriale: sfondo #1a1a1a, testo verde
## terminale) per 3 secondi, poi fade out. Su voxel vuoto non appare nulla.
##
## La matematica DECT e' esposta come funzioni STATIC cosi' PhysicsValidator puo'
## riusarla senza istanziare l'overlay.

# Coefficienti di attenuazione dual-energy (cm^-1 relativi) — letteratura fisica.
# [mu_low @80kVp, mu_high @140kVp]. Il rapporto low/high discrimina il materiale.
const MU := {
	"organic": Vector2(0.20, 0.15),  # ratio 1.333 — fotoelettrico debole, basso Z
	"mixed":   Vector2(0.50, 0.35),  # ratio 1.429
	"metal":   Vector2(2.00, 1.20),  # ratio 1.667 — fotoelettrico forte, alto Z
}

# Curva di calibrazione rapporto-DE -> z_eff: quadratica fittata ESATTAMENTE sui
# tre materiali di riferimento (organico 7.4, misto 14.0, metallo 26.0), come i
# veri scanner calibrano su fantocci noti. z = A*r^2 + B*r + C.
const CAL_A := -56.871
const CAL_B := 226.43
const CAL_C := -193.41

const POPUP_SECONDS := 3.0
const FADE_SECONDS := 0.6

# Colori terminale industriale (coerenti con SlicingPanel / OperatorDashboard).
const C_BG := Color("1a1a1a")
const C_GREEN := Color("00ff41")

var _host                    # VolumetricSetup
var _camera: Camera3D
var _popup: PanelContainer
var _label: RichTextLabel
var _hide_timer: SceneTreeTimer
var _tween: Tween
# FASE 12 — in modalità embedded l'esito non va in un popup floating ma a questa
# callback (il controller v2.0 lo mostra nella sezione DECT del pannello destro).
var _on_result := Callable()


func setup(host, camera: Camera3D, ui_layer: CanvasLayer) -> void:
	_host = host
	_camera = camera
	_build_popup(ui_layer)
	set_process_unhandled_input(true)


## FASE 12 — modalità "solo segnale": nessun popup, l'esito DECT va alla callback.
func setup_signal(host, camera: Camera3D, on_result: Callable) -> void:
	_host = host
	_camera = camera
	_on_result = on_result
	set_process_unhandled_input(true)


# ----------------------------------------------------------------------------
#  Matematica DECT (statica, condivisa con PhysicsValidator)
# ----------------------------------------------------------------------------

## material_id del canale B -> nome categoria.
static func category_for_id(material_id: float) -> String:
	if material_id < 0.25:
		return "organic"
	elif material_id < 0.75:
		return "mixed"
	return "metal"

## Etichetta operatore (maiuscolo italiano) per categoria.
static func category_label(cat: String) -> String:
	match cat:
		"organic": return "ORGANICO"
		"mixed": return "MISTO"
		_: return "METALLO"

## z_eff stimato dal rapporto dual-energy (fisicamente derivato, non letto).
static func dect_zeff(material_id: float) -> float:
	var cat := category_for_id(material_id)
	var mu: Vector2 = MU[cat]
	var ratio := mu.x / mu.y
	return CAL_A * ratio * ratio + CAL_B * ratio + CAL_C

## Decompone un voxel (material_id, densita' normalizzata dal canale R) nei valori
## stimati DECT. La densita' g/cm^3 e' la magnitudine dell'attenuazione (canale R),
## indipendente dal rapporto che invece identifica il materiale.
static func decompose(material_id: float, density_norm: float) -> Dictionary:
	var cat := category_for_id(material_id)
	var mu: Vector2 = MU[cat]
	return {
		"category": cat,
		"label": category_label(cat),
		"ratio": mu.x / mu.y,
		"zeff": dect_zeff(material_id),
		"density": density_norm,   # il canale R conserva la densita' reale [g/cm^3]
	}


# ----------------------------------------------------------------------------
#  Input: click -> analisi DECT
# ----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	# Solo lettura: non consumiamo l'evento, cosi' ObjectDragger continua a
	# gestire selezione/drag senza alcuna interferenza.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_analyze(event.position)


func _analyze(screen_pos: Vector2) -> void:
	var sample: Dictionary = _host.sample_volume_ray(screen_pos)
	if sample.is_empty() or not sample.get("hit", false):
		return  # voxel vuoto: nessun popup
	var d := decompose(float(sample.material_id), float(sample.density))
	if _on_result.is_valid():
		_on_result.call(d)   # embedded: -> pannello v2.0
	else:
		_show_popup(d, screen_pos)


# ----------------------------------------------------------------------------
#  Popup tooltip industriale
# ----------------------------------------------------------------------------
func _build_popup(ui_layer: CanvasLayer) -> void:
	_popup = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.set_border_width_all(1)
	sb.border_color = C_GREEN
	sb.set_content_margin_all(12.0)
	_popup.add_theme_stylebox_override("panel", sb)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.custom_minimum_size = Vector2(240, 0)
	_label.add_theme_color_override("default_color", C_GREEN)
	_popup.add_child(_label)

	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(_popup)


func _show_popup(d: Dictionary, screen_pos: Vector2) -> void:
	_label.text = "[b]ANALISI DUAL-ENERGY CT[/b]\n%s\nz_eff stimato: %.1f\ndensita': %.1f g/cm³\nrapporto μ₈₀/μ₁₄₀: %.3f" % [
		str(d.label), float(d.zeff), float(d.density), float(d.ratio)
	]
	_popup.reset_size()
	# Posiziona vicino al cursore, leggermente in alto a destra.
	_popup.position = screen_pos + Vector2(18, -10)
	_popup.modulate.a = 1.0
	_popup.visible = true

	# Annulla un eventuale fade/timer precedente.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_hide_timer = get_tree().create_timer(POPUP_SECONDS)
	_hide_timer.timeout.connect(_start_fade, CONNECT_ONE_SHOT)


func _start_fade() -> void:
	_tween = create_tween()
	_tween.tween_property(_popup, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func(): _popup.visible = false)
