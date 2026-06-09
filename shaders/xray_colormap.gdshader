shader_type canvas_item;
render_mode blend_mix;

// ============================================================================
//  X-RAY FALSE-COLOR PASS  (applicato UNA volta, alla fine della catena)
// ----------------------------------------------------------------------------
//  Legge l'assorbimento accumulato dai pass di xray_absorption.gdshader
//  (R/G/B = optical depth di organico / misto / metallo) e produce
//  l'immagine finale a falsi colori da scanner:
//
//   - Luminosita' = legge di Beer-Lambert  exp(-tau_totale):
//       vuoto      -> 1 (bianco brillante, fascio passa tutto)
//       molto denso-> 0 (nero, assorbimento totale)
//     Quindi la DENSITA' (quanto tau) controlla la luminosita'.
//
//   - Tinta (falso colore) = numero atomico efficace Z_eff, calcolato come
//     media degli Z delle bande pesata sul loro assorbimento. La tinta NON
//     dipende dalla densita', solo dal materiale:
//       Z_eff < 10  -> arancione/marrone (organico)
//       10..18      -> verde              (misto)
//       Z_eff > 18  -> blu/turchese       (metallo pesante)
// ============================================================================

// Assorbimento accumulato (via BackBufferCopy prima di questo pass).
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

// Intensita' del fascio I0 (luminosita' del vuoto). Esposta alla UI operatore.
uniform float beam_intensity : hint_range(0.0, 2.0) = 1.0;

// --- Controlli operatore (Fase 4) -------------------------------------------
// Zoom: ingrandisce campionando una regione piu' piccola attorno al centro
// dell'immagine e stirandola sull'intero ColorRect.
uniform float zoom_level : hint_range(1.0, 4.0) = 1.0;
// Filtri materiale, mutuamente esclusivi (gestiti lato UI):
//   organic_only -> nasconde tutto cio' che ha Z_eff > 10 (misto + metallo);
//   metal_only   -> mostra SOLO cio' che ha Z_eff > 18 (metallo).
uniform bool enable_organic_only = false;
uniform bool enable_metal_only = false;
// Inversione B/N: il fondo bianco diventa nero e gli oggetti chiari,
// mantenendo la tinta del falso colore (tipico degli scanner reali).
uniform bool invert_image = false;

// --- Window / Level (Fase 11) -----------------------------------------------
// Equalizzazione stile Hounsfield. window = ampiezza finestra di contrasto;
// level = livello di attenuazione al centro (alto -> isola i metalli). Ai default
// (window 1.0, level 0.5) e' l'identita': l'immagine resta come in Fase 4.
uniform float window : hint_range(0.01, 1.0) = 1.0;
uniform float level  : hint_range(0.0, 1.0) = 0.5;

// Z di riferimento delle tre bande di materiale.
const float Z_ORG   = 7.0;
const float Z_MIX   = 14.0;
const float Z_METAL = 26.0;

// Mappa Z_eff -> falso colore canonico da scanner aeroportuale.
vec3 xray_false_color(float zeff) {
	vec3 organic = vec3(0.95, 0.55, 0.15); // < 10   arancione/marrone
	vec3 mixed   = vec3(0.25, 0.75, 0.30); // 10..18 verde
	vec3 metal   = vec3(0.10, 0.45, 0.80); // > 18   blu/turchese
	float t1 = smoothstep(8.0, 11.0, zeff);  // transizione organico -> misto
	float t2 = smoothstep(16.0, 19.0, zeff); // transizione misto -> metallo
	vec3 c = mix(organic, mixed, t1);
	c = mix(c, metal, t2);
	return c;
}

void fragment() {
	// Zoom: campiona attorno al centro (0.5, 0.5) restringendo l'UV.
	vec2 zoom_uv = (SCREEN_UV - vec2(0.5)) / zoom_level + vec2(0.5);

	// Optical depth accumulato per banda.
	vec3 acc = texture(screen_tex, zoom_uv).rgb;

	float tau_total = acc.r + acc.g + acc.b;

	// Z_eff = media degli Z pesata sull'assorbimento di ciascuna banda.
	float denom = max(tau_total, 1e-4);
	float zeff = (acc.r * Z_ORG + acc.g * Z_MIX + acc.b * Z_METAL) / denom;

	// Filtri materiale: azzerano l'assorbimento dei pixel esclusi, cosi'
	// tornano "vuoto" (sfondo) senza alterare quelli che restano.
	if (enable_organic_only && zeff > 10.0) {
		tau_total = 0.0;
	}
	if (enable_metal_only && zeff <= 18.0) {
		tau_total = 0.0;
	}

	// Beer-Lambert: trasmissione -> luminosita'.
	float transmission = exp(-tau_total);

	// Window / Level (Fase 11): rimappa la trasmissione con finestra soft. level
	// alto -> centro su trasmissioni basse (alta attenuazione) = isola i metalli.
	float windowed = transmission;
	if (window < 0.999 || abs(level - 0.5) > 0.001) {
		float center = 1.0 - level;
		windowed = smoothstep(center - window * 0.5, center + window * 0.5, transmission);
	}

	// Il falso colore emerge appena c'e' assorbimento; il vuoto resta bianco.
	float color_fac = smoothstep(0.0, 0.12, tau_total);
	vec3 tint = mix(vec3(1.0), xray_false_color(zeff), color_fac);

	// Luminosita': normale = trasmissione; invertita = 1 - trasmissione
	// (il vuoto bianco diventa nero, gli oggetti densi diventano chiari).
	float luminance = invert_image ? (1.0 - windowed) : windowed;

	vec3 final_color = beam_intensity * tint * luminance;
	COLOR = vec4(final_color, 1.0);
}
