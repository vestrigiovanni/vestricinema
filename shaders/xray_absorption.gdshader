shader_type canvas_item;
render_mode blend_mix;

// ============================================================================
//  X-RAY ABSORPTION PASS  (Beer-Lambert accumulation)
// ----------------------------------------------------------------------------
//  Questo shader NON produce il colore finale: accumula SOLO l'assorbimento.
//
//  Fisica: la legge di Beer-Lambert dice I = I0 * exp(-mu * x).
//  Se piu' oggetti si sovrappongono, gli assorbimenti (gli esponenti) si
//  SOMMANO:  I = I0 * exp(-(mu1*x1 + mu2*x2 + ...)).
//  Quindi qui lavoriamo nel dominio dell'"optical depth" tau = mu * x e lo
//  accumuliamo additivamente leggendo cio' che e' gia' stato disegnato sotto
//  (screen texture aggiornata da un nodo BackBufferCopy prima di ogni oggetto).
//
//  Encoding: NON salviamo un colore, ma tre "bande" di assorbimento nei canali
//  RGB del framebuffer:
//      R = somma tau della materia organica   (Z basso)
//      G = somma tau della materia mista       (Z medio)
//      B = somma tau della materia metallica   (Z alto)
//  Il falso colore in base a Z_eff viene applicato DOPO, alla fine della
//  catena, dal pass dedicato xray_colormap.gdshader.
// ============================================================================

// Stato gia' disegnato sotto (assorbimento accumulato), via BackBufferCopy.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

// Mappa materiale dell'oggetto: R=organico, G=misto, B=metallico (proporzioni).
uniform sampler2D material_map : filter_linear;

// --- Parametri esposti per la futura UI -------------------------------------
// Scala globale dell'assorbimento (mu globale del fascio).
uniform float absorption_scale : hint_range(0.0, 3.0) = 0.9;
// Densita' del singolo oggetto: piu' densa -> piu' scura (non cambia il colore).
uniform float density : hint_range(0.0, 4.0) = 1.0;

// Coefficienti di attenuazione relativi per banda di materiale.
// Il metallo assorbe molto di piu' dell'organico.
const float MU_ORG   = 0.50;
const float MU_MIX   = 0.75;
const float MU_METAL = 0.95;

void fragment() {
	// Spessore (depth map) e maschera di forma dalla texture dello sprite.
	vec4 depth_sample = texture(TEXTURE, UV);
	float thickness = depth_sample.r; // scala di grigi = spessore x attraversato
	float shape = depth_sample.a;     // alpha = sagoma dell'oggetto

	// Proporzioni di materiale in questo punto.
	vec3 frac = texture(material_map, UV).rgb; // R organico, G misto, B metallo

	// Contributo di optical depth per banda: tau = mu * x (termine di Beer-Lambert).
	vec3 contribution = vec3(
		MU_ORG   * frac.r,
		MU_MIX   * frac.g,
		MU_METAL * frac.b
	);
	contribution *= thickness * absorption_scale * density;

	// Somma a cio' che e' gia' stato disegnato sotto (lettura via screen texture).
	vec3 below = texture(screen_tex, SCREEN_UV).rgb;
	vec3 accumulated = below + contribution;

	// L'alpha (shape) fa si' che fuori dalla sagoma il framebuffer resti intatto.
	COLOR = vec4(accumulated, shape);
}
