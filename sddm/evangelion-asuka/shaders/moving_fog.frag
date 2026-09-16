#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float fogDensity;
    float fogSpeed;
    vec4 fogColor;
    float shimmerIntensity;
    float scanlineAlpha;
};

layout(binding = 1) uniform sampler2D source;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbmFog(vec2 p) {
    float v = 0.0;
    v += 0.55 * noise(p);
    p = p * 2.05 + vec2(1.7, 9.2);
    v += 0.30 * noise(p);
    p = p * 2.02 - vec2(3.1, 4.5);
    v += 0.15 * noise(p);
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = uTime * fogSpeed;
    
    vec2 drift1 = vec2(t * 0.18, -t * 0.12);
    vec2 drift2 = vec2(-t * 0.14, -t * 0.22);
    
    float n1 = fbmFog(uv * 2.8 + drift1);
    float n2 = fbmFog(uv * 4.2 + drift2 + vec2(n1 * 0.5, -n1 * 0.3));
    float combinedFog = smoothstep(0.15, 0.85, n1 * 0.55 + n2 * 0.45);
    
    vec2 disp = vec2(
        sin(uv.y * 20.0 + t * 2.5) * cos(uv.x * 15.0 + t * 1.8),
        cos(uv.x * 20.0 + t * 2.2) * sin(uv.y * 15.0 + t * 1.5)
    ) * shimmerIntensity * (combinedFog - 0.3);
    
    vec4 tex = texture(source, uv + disp);
    
    if (tex.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }
    
    vec3 col = tex.rgb / max(tex.a, 0.001);
    
    vec3 fogRgb = fogColor.rgb;
    vec3 mist = fogRgb * combinedFog * fogDensity;
    col = mix(col, col + mist * 1.5, combinedFog * fogDensity);
    
    if (scanlineAlpha > 0.0) {
        float scanline = sin(uv.y * 400.0) * 0.5 + 0.5;
        col = mix(col, col * (1.0 - scanlineAlpha), scanline);
    }
    
    fragColor = vec4(clamp(col, 0.0, 1.0) * tex.a, tex.a) * qt_Opacity;
}
