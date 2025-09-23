shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float angle = 0.0;
uniform float width = 0.35;
uniform float feather = 0.15;
uniform float tail = 0.6;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

float sd_segment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void fragment() {
    vec2 uv = (UV - vec2(0.5));
    float c = cos(angle);
    float s = sin(angle);
    mat2 rot = mat2(vec2(c, -s), vec2(s, c));
    vec2 p = rot * uv * 2.0;
    float len = mix(0.0, 1.2, progress);
    vec2 a = vec2(-tail, 0.0);
    vec2 b = vec2(len, 0.0);
    float d = sd_segment(p, a, b);
    float core = smoothstep(width, width - feather, d);
    COLOR = vec4(tint_color.rgb, tint_color.a * core);
}

