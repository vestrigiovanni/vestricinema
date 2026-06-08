shader_type canvas_item;
render_mode blend_mix;

// ============================================================================
//  CRT POLISH PASS  (scanlines + vignette)
// ----------------------------------------------------------------------------
//  Overlay puramente additivo di scurimento: non legge l'immagine sotto, emette
//  solo nero semi-trasparente. Applicato a un ColorRect sopra l'area X-Ray per
//  simulare un monitor CRT industriale anni '90.
//
//   - Scanlines: una riga scura ogni `line_spacing` px (in coordinate schermo).
//   - Vignette : gradiente radiale che scurisce i bordi dell'area.
// ============================================================================

// Distanza in px tra una scanline e l'altra.
uniform float line_spacing : hint_range(2.0, 8.0) = 4.0;
// Opacita' della singola scanline (8-12% tipico).
uniform float line_opacity : hint_range(0.0, 0.3) = 0.10;
// Intensita' massima dello scurimento ai bordi.
uniform float vignette_strength : hint_range(0.0, 0.6) = 0.20;

void fragment() {
	// Scanline: riga scura di 1px ogni line_spacing px.
	float band = mod(FRAGCOORD.y, line_spacing);
	float scan = band < 1.0 ? line_opacity : 0.0;

	// Vignette: 0 al centro del rettangolo, cresce verso i bordi.
	vec2 d = UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.85, length(d) * 1.4) * vignette_strength;

	float a = clamp(scan + vig, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
