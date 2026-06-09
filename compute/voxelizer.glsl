#[compute]
#version 450

// ============================================================================
//  VOXELIZER  —  Fase 8 (upgrade volumetrico CT 3D)
// ----------------------------------------------------------------------------
//  Destruttura il bagaglio corrente in una griglia 128^3 di voxel residente in
//  VRAM. Ogni cella NON contiene un colore ma proprieta' radiologiche:
//    R = densita' normalizzata     (0..1)
//    G = z_eff normalizzato su [1,30] -> [0,1]
//    B = material_id               (0.0 organico / 0.5 misto / 1.0 metallo)
//    A = occupancy                 (1.0 occupato / 0.0 vuoto)
//
//  Il raymarcher della Fase 9 leggera' questa griglia per la Beer-Lambert 3D.
//
//  DESIGN — parallelismo per-voxel:
//    Il dispatch e' organizzato in gruppi local_size(4,4,4): un thread per
//    voxel, 32^3 gruppi = 128^3 thread. Ogni thread possiede UN voxel e itera
//    su TUTTI i proxy. Poiche' nessun voxel e' scritto da piu' di un thread,
//    la "race" tra oggetti sovrapposti e' risolta localmente: il thread tiene
//    il proxy con densita' maggiore (il piu' radiopaco oscura il meno denso,
//    come nella fisica reale) e scrive una sola volta. Nessuna imageAtomicMax
//    serve sull'immagine float: la guardia condizionale e' sufficiente e
//    corretta per costruzione.
//
//  PROXY ANALITICI — nota di progetto:
//    La Fase 8 usa proxy procedurali (cubo / sfera), testati in forma analitica:
//    SAT sui 3 assi locali del box (point-in-OBB) e test distanza-raggio per la
//    sfera. Per questo i proxy sono passati come descrittori compatti (3 vec4)
//    invece che come buffer di vertici/indici: il point-in-mesh su geometria
//    arbitraria (winding number) arrivera' in Fase 10 con i modelli reali.
// ============================================================================

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

// Lato della griglia. Dispatch = GRID / local_size = 128 / 4 = 32 gruppi/asse.
const int GRID = 128;

// Descrittore compatto di un proxy (std430, tutto allineato a vec4 = 16 byte).
struct Proxy {
	vec4 center_type;   // xyz = centro nel volume [0,1]^3 ; w = tipo (0=box, 1=sfera)
	vec4 size_radius;   // box: xyz = semi-estensioni ; sfera: x = raggio
	vec4 props;         // x = densita' ; y = z_eff norm ; z = material_id ; w = rotazione attorno a Y (rad)
};

layout(set = 0, binding = 0, std430) restrict readonly buffer Proxies {
	Proxy proxies[];
};

// Texture3D di output RGBA float 16-bit (DATA_FORMAT_R16G16B16A16_SFLOAT).
layout(set = 0, binding = 1, rgba16f) uniform restrict writeonly image3D volume;

// Contatore atomico dei voxel occupati (letto a CPU per la UI di debug).
layout(set = 0, binding = 2, std430) restrict buffer Counter {
	uint occupied;
};

layout(push_constant, std430) uniform Params {
	int num_proxies;
	int pad0;
	int pad1;
	int pad2;
} pc;

// Point-in-OBB via Separating Axis Theorem sui 3 assi locali del box.
// Si porta il punto nel frame locale del box (rotazione inversa attorno a Y),
// poi basta confrontare |local| con le semi-estensioni: se rientra su tutti e
// tre gli assi, nessun asse separa il punto dal box -> punto interno.
bool inside_box(vec3 p, Proxy pr) {
	vec3 d = p - pr.center_type.xyz;
	float rot = pr.props.w;
	float c = cos(-rot);
	float s = sin(-rot);
	vec3 local = vec3(
		c * d.x - s * d.z,
		d.y,
		s * d.x + c * d.z
	);
	return all(lessThanEqual(abs(local), pr.size_radius.xyz));
}

// Test distanza-raggio per la sfera.
bool inside_sphere(vec3 p, Proxy pr) {
	return distance(p, pr.center_type.xyz) <= pr.size_radius.x;
}

void main() {
	ivec3 voxel = ivec3(gl_GlobalInvocationID);
	// Guardia: i gruppi possono eccedere la griglia se GRID non e' multiplo del
	// local_size (qui non accade, ma resta corretto per griglie future).
	if (voxel.x >= GRID || voxel.y >= GRID || voxel.z >= GRID) {
		return;
	}

	// Centro geometrico del voxel in coordinate normalizzate [0,1]^3.
	vec3 p = (vec3(voxel) + vec3(0.5)) / float(GRID);

	float best_density = -1.0;
	vec4 result = vec4(0.0);

	for (int i = 0; i < pc.num_proxies; i++) {
		Proxy pr = proxies[i];
		bool hit = (pr.center_type.w < 0.5) ? inside_box(p, pr) : inside_sphere(p, pr);
		if (hit && pr.props.x > best_density) {
			// Vince l'oggetto piu' denso (oscura quelli meno radiopachi).
			best_density = pr.props.x;
			result = vec4(pr.props.x, pr.props.y, pr.props.z, 1.0);
		}
	}

	// Scrittura unica per voxel: include i voxel vuoti (result = 0), cosi' la
	// texture e' completamente sovrascritta a ogni dispatch -> nessun residuo
	// dalle voxelizzazioni precedenti.
	imageStore(volume, voxel, result);

	if (best_density >= 0.0) {
		atomicAdd(occupied, 1u);
	}
}
