#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tintColor;
    vec4 bgColor;
    float contrast;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 tex = texture(source, qt_TexCoord0);
    if (tex.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    vec3 c = tex.rgb / max(tex.a, 0.001);
    float lum = dot(c, vec3(0.299, 0.587, 0.114));

    // Enhance contrast of luminance to give crisp edges
    lum = clamp((lum - 0.5) * contrast + 0.5, 0.0, 1.0);

    // Map: 0.0 (tinted black) -> bgColor (White #ffffff)
    //      1.0 (shape / highlight) -> tintColor (Crimson #cc0000)
    vec3 mapped = mix(bgColor.rgb, tintColor.rgb, lum);

    fragColor = vec4(mapped * tex.a, tex.a) * qt_Opacity;
}
