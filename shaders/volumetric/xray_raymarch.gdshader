shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

// ============================================================================
//  X-RAY VOLUMETRIC RAYMARCH  —  Fase 9
// ----------------------------------------------------------------------------
//  Inverso della voxelizzazione (Fase 8): invece di costruire il volume lo
//  ATTRAVERSIAMO pixel per pixel. Per ogni frammento del cubo proxy si lancia
//  un raggio dalla camera dentro la Texture3D 128^3 e si avanza a passi fissi.
//
//  Ad ogni passo si campiona il voxel corrente:
//    R = densita' normalizzata     (0..1)
//    G = z_eff normalizzato [1,30] -> [0,1]
//    B = material_id  (0.0 organico / 0.5 misto / 1.0 metallo)
//    A = occupancy    (1.0 occupato / 0.0 vuoto)
//
//  Beer-Lambert discreta: la trasmittanza residua del fascio si moltiplica per
//  exp(-mu * density * step_size) ad ogni passo occupato. Due oggetti
//  sovrapposti SOMMANO le attenuazioni (l'optical depth e' additivo lungo il
//  cammino), quindi l'intersezione e' piu' SCURA di entrambi — non un alpha
//  blend semitrasparente.
//
//  La mappatura cromatica z_eff->colore e' IDENTICA alla Fase 2
//  (xray_colormap.gdshader): si accumulano tre bande di optical depth
//  (organico / misto / metallo) e si ricava luminosita' e tinta esattamente
//  come nel pass 2D.
//
//  Wood-grain artifact: passi discreti su un volume generano bande anulari
//  concentriche. Si sfasa il punto di partenza di ogni raggio di una frazione
//  pseudo-casuale di step_size letta da una texture di blue noise 64x64: il
//  cervello legge il risultato come rumore organico del sensore.
// ============================================================================

// --- Volume e rumore --------------------------------------------------------
uniform sampler3D volume_tex : filter_linear, repeat_disable;
uniform sampler2D blue_noise : filter_nearest, repeat_enable;

// Matrice modello del cubo proxy (object->world). Aggiornata ogni frame da
// VolumetricSetup. La sua inversa porta camera e frammento nello spazio locale
// del volume (cubo unitario [0,1]^3 dopo lo shift di +0.5).
uniform mat4 volume_transform;

// --- Controlli esposti alla UI ----------------------------------------------
uniform float absorption_scale : hint_range(0.0, 20.0) = 6.0;
uniform float beam_intensity   : hint_range(0.0, 2.0) = 1.0;
uniform int   max_steps        : hint_range(16, 512) = 256;
uniform float step_size        : hint_range(0.002, 0.05) = 0.008;
uniform bool  enable_organic_only = false;
uniform bool  enable_metal_only = false;
uniform bool  invert_image = false;

// --- Realismo fisico (Fase 11) ----------------------------------------------
// Scatter Compton: i voxel piu' densi di scatter_threshold disperdono fotoni che
// si rileggono come un alone grigio luminoso (velo) attorno alle strutture dense.
uniform float scatter_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float scatter_threshold : hint_range(0.0, 1.0) = 0.4;
// Rumore quantistico (Poisson): seed aggiornato ogni frame da GDScript
// (Time.get_ticks_msec() * 0.001) per far "respirare" la grana nel tempo.
uniform float noise_seed = 0.0;

// --- Window / Level (Fase 11) -----------------------------------------------
// Equalizzazione stile Hounsfield. window = ampiezza della finestra di contrasto;
// level = quale livello di ATTENUAZIONE finisce al centro (alto -> isola i
// materiali densi/metallici). Ai default (window 1.0, level 0.5) la rimappatura
// e' l'identita': la scena resta bit-identica alla Fase 10.
uniform float window : hint_range(0.01, 1.0) = 1.0;
uniform float level  : hint_range(0.0, 1.0) = 0.5;

// --- Clipping planes / slicing CT (Fase 10) ---------------------------------
// Tre piani anatomici, formato "normale + offset" in spazio texture [0,1]^3:
//   sagittale  vec4(1,0,0, soglia)  divide sinistra/destra;
//   coronale   vec4(0,1,0, soglia)  divide alto/basso;
//   assiale    vec4(0,0,1, soglia)  divide fronte/retro.
// clip_enabled e' la "boolean vector" dei piani attivi (componenti 0/1: Godot
// non espone in modo affidabile un uniform bvec3 da GDScript, quindi usiamo un
// vec3 di flag — semanticamente identico). Il taglio e' netto: un campione nel
// semispazio escluso viene saltato (continue), senza sfumare i bordi.
uniform vec4 clip_sag = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 clip_cor = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 clip_ax  = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec3 clip_enabled = vec3(0.0);

// Tetto fisso del loop (i loop spatial non accettano bound da uniform).
const int HARD_MAX = 512;

// Z di riferimento delle tre bande (identici alla Fase 2).
const float Z_ORG   = 7.0;
const float Z_MIX   = 14.0;
const float Z_METAL = 26.0;

// Mappa Z_eff -> falso colore canonico (copia esatta da xray_colormap.gdshader).
vec3 xray_false_color(float zeff) {
	vec3 organic = vec3(0.95, 0.55, 0.15); // < 10   arancione/marrone
	vec3 mixed   = vec3(0.25, 0.75, 0.30); // 10..18 verde
	vec3 metal   = vec3(0.10, 0.45, 0.80); // > 18   blu/turchese
	float t1 = smoothstep(8.0, 11.0, zeff);
	float t2 = smoothstep(16.0, 19.0, zeff);
	vec3 c = mix(organic, mixed, t1);
	c = mix(c, metal, t2);
	return c;
}

// --- Rumore quantistico (Fase 11) -------------------------------------------
// Due campioni decorrelati dal blue noise (repeat_enable -> niente pattern
// geometrico), sfasati ogni frame da noise_seed. La trasformata di Box-Muller li
// converte in una gaussiana a media 0 e varianza 1 — l'approssimazione della
// Poisson valida per molti fotoni.
float gaussian_noise(vec2 frag) {
	vec2 o1 = vec2(noise_seed * 37.0, noise_seed * 17.0);
	vec2 o2 = vec2(noise_seed * 11.0 + 23.0, noise_seed * 29.0 + 7.0);
	float u1 = clamp(texture(blue_noise, (frag + o1) / 64.0).r, 1e-4, 1.0);
	float u2 = texture(blue_noise, (frag + o2) / 64.0).r;
	return sqrt(-2.0 * log(u1)) * cos(6.28318530718 * u2);
}

varying vec3 v_local; // posizione object-space del frammento sul cubo proxy

void vertex() {
	// VERTEX e' la posizione model-space del vertice del BoxMesh size 1 -> [-0.5, 0.5].
	v_local = VERTEX;
}

void fragment() {
	// --- Raggio in spazio locale del volume ---------------------------------
	mat4 inv = inverse(volume_transform);
	vec3 cam_local = (inv * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;

	// Porta tutto nel cubo unitario [0,1]^3 (lo shift +0.5 e' una traslazione,
	// quindi la direzione del raggio non cambia).
	vec3 ray_o = cam_local + vec3(0.5);
	vec3 frag_tex = v_local + vec3(0.5);
	vec3 ray_d = normalize(frag_tex - ray_o);

	// --- Box di campionamento, ridotto dai clipping planes ------------------
	// I tre piani (normali sugli assi positivi, esclude p < offset) si traducono
	// in un alzamento del minimo dell'AABB sull'asse corrispondente: il volume
	// bianco viene cosi' TAGLIATO via (i raggi che mancano il box ridotto fanno
	// discard ed espongono lo sfondo nero), e al taglio affiora la sezione interna.
	vec3 box_min = vec3(0.0);
	if (clip_enabled.x > 0.5) { box_min.x = clip_sag.w; }
	if (clip_enabled.y > 0.5) { box_min.y = clip_cor.w; }
	if (clip_enabled.z > 0.5) { box_min.z = clip_ax.w; }

	// --- Intersezione raggio/AABB [box_min,1]^3 (slab method) ---------------
	vec3 inv_d = 1.0 / ray_d;
	vec3 ta = (box_min - ray_o) * inv_d;
	vec3 tb = (vec3(1.0) - ray_o) * inv_d;
	vec3 tmin3 = min(ta, tb);
	vec3 tmax3 = max(ta, tb);
	float t_enter = max(max(tmin3.x, tmin3.y), tmin3.z);
	float t_exit  = min(min(tmax3.x, tmax3.y), tmax3.z);
	t_enter = max(t_enter, 0.0); // la camera puo' essere dentro al cubo

	// Raggio che manca il box ridotto: e' nella porzione tagliata via -> scarta
	// il frammento cosi' si vede lo sfondo (taglio netto del volume).
	if (t_exit < t_enter) {
		discard;
	}

	// Optical depth accumulato per banda (organico / misto / metallo).
	vec3 band_tau = vec3(0.0);
	float transmittance = 1.0; // fascio residuo, serve solo all'early-exit
	float accumulated_scatter = 0.0; // scatter Compton accumulato (Fase 11)

	if (t_exit >= t_enter) {
		// Sfasa la partenza di una frazione pseudo-casuale di step_size:
		// uccide il wood-grain anulare.
		float jitter = texture(blue_noise, FRAGCOORD.xy / 64.0).r;
		float t = t_enter + jitter * step_size;

		for (int i = 0; i < HARD_MAX; i++) {
			if (i >= max_steps) break;
			if (t > t_exit) break;

			vec3 p = ray_o + ray_d * t;

			// Clipping planes: scarta i campioni nel semispazio escluso PRIMA di
			// campionare. Taglio chirurgico, nessuna sfumatura. Avanza comunque t.
			bool clipped = (clip_enabled.x > 0.5 && dot(p, clip_sag.xyz) < clip_sag.w)
						|| (clip_enabled.y > 0.5 && dot(p, clip_cor.xyz) < clip_cor.w)
						|| (clip_enabled.z > 0.5 && dot(p, clip_ax.xyz) < clip_ax.w);
			if (clipped) {
				t += step_size;
				continue;
			}

			vec4 voxel = texture(volume_tex, p);

			// Solo i voxel occupati contribuiscono.
			if (voxel.a > 0.5) {
				float mid = voxel.b; // material_id

				// I filtri saltano i voxel fuori soglia DURANTE il loop:
				//   ORGANIC ONLY -> tieni solo organico (mid < 0.25);
				//   METAL ONLY   -> tieni solo metallo  (mid > 0.75).
				bool skip = (enable_organic_only && mid >= 0.25)
						 || (enable_metal_only && mid <= 0.75);
				if (!skip) {
					float dtau = absorption_scale * voxel.r * step_size;
					// Smista l'optical depth nella banda del materiale.
					if (mid < 0.25) {
						band_tau.x += dtau;
					} else if (mid < 0.75) {
						band_tau.y += dtau;
					} else {
						band_tau.z += dtau;
					}
					transmittance *= exp(-dtau);

					// Scatter Compton: i voxel densi disperdono fotoni che si
					// rileggono come velo grigio. Il termine e' pesato dalla
					// trasmittanza residua (lo scatter visto in superficie e' quello
					// che riesce ancora a uscire dal volume).
					if (voxel.r > scatter_threshold) {
						accumulated_scatter += voxel.r * scatter_intensity * step_size * transmittance;
					}

					if (transmittance < 0.01) break; // early exit
				}
			}
			t += step_size;
		}
	}

	// --- Falso colore: matematica identica alla Fase 2 ----------------------
	float tau_total = band_tau.x + band_tau.y + band_tau.z;
	float denom = max(tau_total, 1e-4);
	float zeff = (band_tau.x * Z_ORG + band_tau.y * Z_MIX + band_tau.z * Z_METAL) / denom;

	float transmission = exp(-tau_total);
	float color_fac = smoothstep(0.0, 0.12, tau_total);
	vec3 tint = mix(vec3(1.0), xray_false_color(zeff), color_fac);

	// --- Window / Level (Fase 11) -------------------------------------------
	// Rimappa la trasmissione con una finestra di contrasto soft (smoothstep =
	// niente clipping duro ai bordi). level alto -> il centro finestra cade su
	// trasmissioni basse (alta attenuazione): restano visibili solo i metalli.
	float windowed = transmission;
	if (window < 0.999 || abs(level - 0.5) > 0.001) {
		float center = 1.0 - level;           // level alto -> centro su bassa trasmissione
		float lo = center - window * 0.5;
		float hi = center + window * 0.5;
		windowed = smoothstep(lo, hi, transmission);
	}

	// Luminosita': normale = trasmissione (vuoto bianco); invertita = 1 - trasm.
	float luminance = invert_image ? (1.0 - windowed) : windowed;

	// --- Rumore quantistico di Poisson (Fase 11) ----------------------------
	// std del fotone-conteggio ~ 1/sqrt(N) con N ~ beam_intensity * fotoni. A
	// bassa beam_intensity (pochi fotoni) la grana esplode; ad alta intensita'
	// quasi sparisce. La grana e' piu' marcata nelle zone luminose (piu' fotoni
	// passano = ma piu' segnale su cui si vede la fluttuazione).
	float photon_scale = beam_intensity * 400.0 + 1.0;
	float sigma = sqrt(max(luminance, 0.02)) / sqrt(photon_scale);
	luminance = clamp(luminance + gaussian_noise(FRAGCOORD.xy) * sigma, 0.0, 1.0);

	vec3 final_color = beam_intensity * tint * luminance;

	// Velo di scatter Compton: componente grigia additiva (Fase 11).
	final_color += vec3(accumulated_scatter * 0.15);

	ALBEDO = final_color;
}
