shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float width = 0.18;
uniform vec4 base_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform vec4 tip_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 uv = UV;
    float from_base = clamp(1.0 - uv.y, 0.0, 1.0);
    float lateral = abs(uv.x - 0.5);

    float len = mix(0.05, 1.0, progress);
    float length_mask = 1.0 - smoothstep(len, len + 0.06, from_base);

    float taper = clamp(mix(width, width * 0.4, from_base), 0.02, 0.5);
    float blade = 1.0 - smoothstep(taper, taper + 0.08, lateral);

    float tip = smoothstep(max(len - 0.12, 0.0), len, from_base);
    float flicker = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.85, 1.0, progress));

    float alpha = blade * length_mask * flicker;
    vec3 color = mix(base_color.rgb, tip_color.rgb, tip);
    float glow = 0.85 + tip * 0.4;

    COLOR = vec4(color * glow, base_color.a * alpha);
}
