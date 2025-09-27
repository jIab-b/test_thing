shader_type canvas_item;
render_mode unshaded, blend_add;

uniform vec4 tint_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float width = 0.22;
uniform float feather = 0.11;
uniform float start_angle = -1.35;
uniform float end_angle = 0.55;
uniform float start_radius = 0.08;
uniform float end_radius = 1.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float r = length(p);
    float theta = atan(p.y, p.x);

    float head_angle = mix(start_angle, end_angle, progress);
    float sweep = max(head_angle - start_angle, 0.001);
    float tail_angle = head_angle - sweep;
    float normalized = clamp((theta - tail_angle) / sweep, 0.0, 1.0);

    float angle_mask = smoothstep(0.0, 0.12, normalized) * (1.0 - smoothstep(1.0 - 0.12, 1.0, normalized));

    float target_radius = mix(start_radius, end_radius, normalized);
    float inner = smoothstep(target_radius - width, target_radius - width + feather, r);
    float outer = 1.0 - smoothstep(target_radius + width - feather, target_radius + width, r);
    float radius_mask = inner * outer;

    float life = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.85, 1.0, progress));
    float head_highlight = smoothstep(0.6, 1.0, normalized);

    float alpha = clamp(radius_mask * angle_mask, 0.0, 1.0) * life;
    vec3 color_mix = mix(tint_color.rgb * 0.55, tint_color.rgb, head_highlight);
    COLOR = vec4(color_mix, tint_color.a * alpha);
}

