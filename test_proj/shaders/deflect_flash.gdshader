shader_type canvas_item;

uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 silver = vec3(0.90, 0.94, 1.00);
    float flash = clamp(active, 0.0, 1.0);
    vec3 col = mix(base.rgb, silver, flash * 0.7);
    COLOR = vec4(col, base.a);
}

