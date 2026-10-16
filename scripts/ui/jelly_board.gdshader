shader_type canvas_item;

// The board frame with the same jelly look as the HUD (jelly_common). The board's shape is ONE
// closed outline (or a few, around holes), built on the CPU from the union of the playfield's
// cells: grown outward by the frame width, every corner rounded (convex corners outward,
// concave corners with an inner "C" fillet) and flattened to line segments. The signed distance
// to that outline is exact (nearest segment for the distance, even-odd crossings for the sign),
// so there are no seams, steps or notches anywhere. The face is the board earth, lit softly
// from the upper middle.

#include "res://scripts/ui/jelly_common.gdshaderinc"

uniform vec2 size = vec2(800.0, 900.0);   // the node's size (pixels)
uniform int seg_count = 0;
uniform vec4 segs[256];                   // (a.x, a.y, b.x, b.y), closed loops
uniform vec4 earth_hi : source_color = vec4(0.54, 0.27, 0.21, 1.0);
uniform vec4 earth : source_color = vec4(0.36, 0.17, 0.13, 1.0);
uniform vec2 light_center = vec2(400.0, 300.0);
uniform float light_reach = 700.0;

float sdf(vec2 p) {
	float d = 1e12;
	float s = 1.0;
	for (int i = 0; i < seg_count; i++) {
		vec2 a = segs[i].xy;
		vec2 b = segs[i].zw;
		vec2 e = b - a;
		vec2 w = p - a;
		vec2 q = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
		d = min(d, dot(q, q));
		bool c1 = p.y >= a.y;
		bool c2 = p.y < b.y;
		bool c3 = e.x * w.y > e.y * w.x;
		if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) {
			s = -s;
		}
	}
	return s * sqrt(d);
}

void fragment() {
	vec2 p = UV * size;
	float d = sdf(p);
	if (d > 40.0) {
		discard;
	}
	vec2 e = vec2(0.75, 0.0);
	// on a medial line (e.g. the middle row of a wide plate) the gradient is zero; a tiny
	// epsilon underflows at mediump and normalize() gives NaN (a black line), so fall back
	vec2 g = vec2(sdf(p + e.xy) - sdf(p - e.xy), sdf(p + e.yx) - sdf(p - e.yx));
	vec2 n = dot(g, g) > 1e-4 ? g * inversesqrt(dot(g, g)) : vec2(0.0, -1.0);
	float top = smoothstep(0.1, -0.6, n.y);   // gloss on the upper-facing parts of the rim
	float k = clamp(length(p - light_center) / light_reach, 0.0, 1.0);
	vec3 face = mix(earth_hi.rgb, earth.rgb, k);
	COLOR = jelly_shade(d, n, top, face, sdf(p - drop_offset), 14.0);
}
