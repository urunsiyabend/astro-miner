// Shared "jelly" shading for a shape given by a signed distance d (negative inside, pixels):
// dark outline, puffy rim lit from the top-left with a gloss streak, a face with an inner shadow
// along the rim, and a soft drop shadow. Bands are blended with screen-space anti-aliasing.

uniform vec4 rim_color : source_color = vec4(0.62, 0.45, 0.88, 1.0);
uniform vec4 face_color : source_color = vec4(0.22, 0.11, 0.42, 1.0);
uniform vec4 face_color_bottom : source_color = vec4(0.27, 0.14, 0.50, 1.0);
uniform vec4 outline_color : source_color = vec4(0.12, 0.04, 0.22, 1.0);
uniform float rim = 14.0;                 // rim width
uniform float outline = 2.5;              // thin dark line around everything
uniform float bevel = 0.55;               // strength of the rim lighting
uniform float gloss = 0.55;               // strength of the top highlight streak
uniform float inner_shadow = 0.55;        // darkening of the face just inside the rim
uniform float drop = 0.35;                // drop shadow opacity
uniform vec2 drop_offset = vec2(0.0, 6.0);

// n: outward normal of the shape; top: 1 on the upper part of the shape (gloss), 0 below
vec4 jelly_shade(float d, vec2 n, float top, vec3 face, float d_drop, float shadow_soft) {
	float aa = max(fwidth(d), 1e-3) * 0.75;
	vec2 light = normalize(vec2(-0.55, -0.85));

	// rim colour across its width: half-pipe profile, darker inner lip, gloss streak
	float t = clamp((-d - outline) / rim, 0.0, 1.0);      // 0 outer edge .. 1 inner edge
	vec2 nn = n * cos(t * 3.14159);
	vec3 rim_col = rim_color.rgb * (1.0 + bevel * 0.6 * dot(-nn, light));
	rim_col = mix(rim_col, rim_color.rgb * 0.62, smoothstep(0.75, 1.0, t) * 0.6);
	float band = smoothstep(0.05, 0.35, t) * (1.0 - smoothstep(0.35, 0.7, t));
	rim_col += vec3(1.0) * gloss * band * top;

	// face: inner shadow along the rim
	float inner = -d - outline - rim;
	float sh = 1.0 - smoothstep(0.0, rim * 1.6, inner);
	vec3 face_col = face * (1.0 - inner_shadow * sh * (0.55 + 0.45 * clamp(-n.y, 0.0, 1.0)));

	// blend the bands with anti-aliased boundaries: outline | rim | face
	float to_rim = smoothstep(-outline + aa, -outline - aa, d);
	float to_face = smoothstep(-(outline + rim) + aa, -(outline + rim) - aa, d);
	vec3 col = mix(outline_color.rgb, rim_col, to_rim);
	col = mix(col, face_col, to_face);

	float a = 1.0 - smoothstep(-aa, aa, d);
	float shadow_a = drop * (1.0 - smoothstep(-2.0, shadow_soft * 0.9, d_drop));
	float out_a = a + shadow_a * (1.0 - a);
	return vec4(col * a / max(out_a, 1e-4), out_a);
}
