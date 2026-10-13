shader_type canvas_item;
// Full-screen "pixel art" look used in exploration mode.
// strength 1.0 = chunky pixels + posterized palette + vignette. 0.0 = untouched realistic render.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float pixel_size = 3.0;
uniform float levels = 20.0;

void fragment() {
    vec2 res = vec2(textureSize(screen_tex, 0));
    vec2 puv = (floor(SCREEN_UV * res / pixel_size) + 0.5) * pixel_size / res;
    vec3 src = texture(screen_tex, SCREEN_UV).rgb;
    vec3 pix = texture(screen_tex, puv).rgb;
    pix = floor(pix * levels + 0.5) / levels;
    vec2 d = SCREEN_UV - 0.5;
    float vig = clamp(1.0 - dot(d, d) * 0.8, 0.0, 1.0);
    COLOR = vec4(mix(src, pix * vig, strength), 1.0);
}
