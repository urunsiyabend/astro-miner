shader_type canvas_item;

// A glossy "jelly" rounded-rectangle frame, drawn entirely from a signed distance field:
// a puffy rim (rounded profile, lit from the top-left), a gloss streak along its top, a dark
// inset face with an inner shadow, and a soft drop shadow. Used for HUD panels and buttons.
// All lengths are in the node's pixels; edges are anti-aliased in screen pixels (fwidth), so
// they stay smooth whatever the canvas scale.

#include "res://scripts/ui/jelly_common.gdshaderinc"

uniform vec2 size = vec2(200.0, 100.0);   // the node's size
uniform float pad = 12.0;                 // room around the shape for the drop shadow
uniform float radius = 28.0;              // outer corner radius

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float sdf(vec2 p) {
	vec2 half_size = size * 0.5 - vec2(pad);
	return sd_round_box(p, half_size, min(radius, min(half_size.x, half_size.y)));
}

void fragment() {
	vec2 p = UV * size - size * 0.5;
	float d = sdf(p);
	vec2 e = vec2(0.75, 0.0);
	// on a medial line (e.g. the middle row of a wide plate) the gradient is zero; a tiny
	// epsilon underflows at mediump and normalize() gives NaN (a black line), so fall back
	vec2 g = vec2(sdf(p + e.xy) - sdf(p - e.xy), sdf(p + e.yx) - sdf(p - e.yx));
	vec2 n = dot(g, g) > 1e-4 ? g * inversesqrt(dot(g, g)) : vec2(0.0, -1.0);
	float top = smoothstep(0.15, -0.65, p.y / (size.y * 0.5 - pad));
	vec3 face = mix(face_color.rgb, face_color_bottom.rgb, clamp(UV.y, 0.0, 1.0));
	COLOR = jelly_shade(d, n, top, face, sdf(p - drop_offset), pad);
}
