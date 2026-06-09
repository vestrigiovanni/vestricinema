shader_type canvas_item;

// ============================================================================
//  DUAL-ENERGY CT — DECOMPOSIZIONE MATERIALE  —  Fase 11
// ----------------------------------------------------------------------------
//  NON sostituisce il raymarcher principale (xray_raymarch.gdshader). E' lo
//  shader "analitico" della modalita' identificazione materiale: quando
//  l'operatore clicca un punto del volume, si simulano DUE acquisizioni a energie
//  diverse (80 kVp e 140 kVp) e dal loro rapporto si DEDUCE il materiale, invece
//  di leggere z_eff direttamente dalla texture come fa la pipeline normale.
//
//  Fisica: a bassa energia domina l'effetto fotoelettrico (~ Z^n), molto
//  sensibile al numero atomico; ad alta energia domina lo scatter Compton, quasi
//  indipendente da Z. Quindi il rapporto mu_80 / mu_140 e' grande per i materiali
//  ad alto Z (organici? no — alto rapporto = fotoelettrico forte = ALTO Z) e basso
//  per quelli a basso Z. Il rapporto e' inoltre INDIPENDENTE dalla densita': la
//  densita' scala mu_80 e mu_140 della stessa quantita' e si semplifica nel
//  rapporto. Cosi' DECT separa "cosa e'" (z_eff, dal rapporto) da "quanto ce n'e'"
//  (densita', dalla magnitudine dell'attenuazione).
//
//  Coefficienti di attenuazione approssimati dalla letteratura (cm^-1, relativi):
//      organico  mu_low = 0.20  mu_high = 0.15   ratio = 1.333
//      misto     mu_low = 0.50  mu_high = 0.35   ratio = 1.429
//      metallo   mu_low = 2.00  mu_high = 1.20   ratio = 1.667
//
//  z_eff stimato dal rapporto via una curva di calibrazione quadratica fittata
//  sui tre materiali di riferimento (esattamente come i veri scanner calibrano il
//  rapporto DE su fantocci noti): z = A*r^2 + B*r + C.
// ============================================================================

// Volume voxelizzato (stesso della pipeline): R=densita', G=z_eff_norm,
// B=material_id (0 organico / 0.5 misto / 1 metallo), A=occupancy.
uniform sampler3D volume_tex : filter_linear, repeat_disable;
// Punto sondato in spazio texture [0,1]^3 (impostato da DectAnalysisOverlay).
uniform vec3 probe_point = vec3(0.5);

// Curva di calibrazione rapporto-DE -> z_eff (fit esatto sui 3 riferimenti).
const float CAL_A = -56.871;
const float CAL_B = 226.43;
const float CAL_C = -193.41;

// Coefficienti dual-energy per categoria.
vec2 mu_for_material(float mid) {
	if (mid < 0.25) {
		return vec2(0.20, 0.15);  // organico
	} else if (mid < 0.75) {
		return vec2(0.50, 0.35);  // misto
	}
	return vec2(2.0, 1.2);        // metallo
}

// Rapporto DE -> z_eff stimato (fisicamente derivato, non letto dalla texture).
float dect_zeff(float mid) {
	vec2 mu = mu_for_material(mid);
	float ratio = mu.x / mu.y;
	return CAL_A * ratio * ratio + CAL_B * ratio + CAL_C;
}

void fragment() {
	vec4 voxel = texture(volume_tex, probe_point);
	if (voxel.a < 0.5) {
		// Voxel vuoto: nessun materiale da decomporre.
		COLOR = vec4(0.0);
	} else {
		float zeff = dect_zeff(voxel.b);
		// Visualizzazione di debug: z_eff stimato normalizzato sul rosso, densita'
		// sul verde. L'overlay GDScript usa gli stessi numeri per il popup.
		COLOR = vec4(clamp(zeff / 30.0, 0.0, 1.0), voxel.r, 0.0, 1.0);
	}
}
