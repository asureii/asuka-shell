#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    vec4 butterflyColor;
    vec4 glowColor;
    float wingBeatSpeed;
    vec2 uResolution;
};

vec2 rotate2D(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Evaluates an anatomically elegant pure NERV crimson (#cc0000) butterfly
vec4 drawButterfly(vec2 uv, vec2 center, float heading, float flapPhase, float bScale, vec3 primaryRed, vec3 brightHighlight, vec3 auraRed) {
    vec2 p = uv - center;
    p = rotate2D(p, -heading);
    p /= bScale;

    // Wing flap kinematics: cos(flapPhase) scales the horizontal span smoothly
    float flap = sin(flapPhase);
    float flapWidth = max(0.08, abs(cos(flapPhase)));
    float flapPitch = flap * 0.015 * sign(p.x);

    // Coordinate with symmetric folded wing span
    float px = abs(p.x);
    float py = p.y;
    vec2 wingUV = vec2(px / flapWidth, py + flapPitch);

    // 1. Forewing (Upper Wing: swept back, rounded triangular lobe)
    vec2 fwP = wingUV - vec2(0.038, 0.038);
    fwP = rotate2D(fwP, -0.60);
    float fwD = length(fwP / vec2(0.048, 0.032)) - 1.0;

    // 2. Hindwing (Lower Wing: smaller, rounded teardrop)
    vec2 hwP = wingUV - vec2(0.026, -0.022);
    hwP = rotate2D(hwP, 0.40);
    float hwD = length(hwP / vec2(0.032, 0.024)) - 1.0;

    float wingD = min(fwD, hwD);
    float wingMask = smoothstep(0.08, -0.02, wingD);

    // 3. Slender Body & Head
    float bodyD = length(vec2(p.x * 4.2, p.y * 1.35)) - 0.038;
    float bodyMask = smoothstep(0.01, -0.005, bodyD);

    // 4. Antennae
    vec2 antP = vec2(abs(p.x) - 0.012, p.y - 0.045);
    float antCurve = abs(antP.x - antP.y * 0.4) + abs(antP.y * 0.9);
    float antMask = smoothstep(0.006, 0.001, antCurve) * step(0.0, p.y - 0.02) * step(p.y, 0.075);

    // 5. Delicate Wing Veins & Margin Gradient (Pure NERV Crimson)
    float rad = length(wingUV);
    float ang = atan(wingUV.y, wingUV.x);
    float veins = sin(ang * 7.0 + rad * 18.0) * sin(rad * 32.0);
    veins = smoothstep(0.15, 0.75, veins * 0.5 + 0.5);

    float marginRim = smoothstep(-0.25, 0.0, wingD);

    // 6. Bioluminescent Glow Halo
    float auraD = length(p * vec2(1.2, 0.9));
    float aura = exp(-auraD * 16.0) * 0.45 * (0.8 + 0.2 * abs(cos(flapPhase)));

    // Pure NERV Crimson Palette Compositing (#cc0000 base)
    vec3 wCol = mix(primaryRed, brightHighlight, veins * 0.45);
    wCol = mix(wCol, vec3(0.18, 0.0, 0.0), marginRim * 0.70); // Dark obsidian-crimson margin
    vec3 bCol = vec3(0.10, 0.0, 0.0);

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // Add aura
    col += auraRed * aura * 0.85;
    alpha += aura * 0.6;

    // Add wings
    col = mix(col, wCol, wingMask * 0.94);
    alpha = max(alpha, wingMask * 0.94);

    // Add body & antennae
    float solid = max(bodyMask, antMask);
    col = mix(col, bCol, solid);
    alpha = max(alpha, solid);

    return vec4(col, alpha);
}

// Particle ember sparkle
float ember(vec2 uv, vec2 pos, float seed, float t) {
    float d = length(uv - pos);
    float sp = sin(t * 12.0 + seed * 23.0) * 0.5 + 0.5;
    return exp(-d * 85.0) * sp;
}

void main() {
    float aspect = uResolution.x / max(uResolution.y, 1.0);
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);

    float t = uTime;
    float beatSpeed = (wingBeatSpeed > 0.0) ? wingBeatSpeed : 11.5;

    // Exact NERV Crimson (#cc0000) Palette Matching the Rest of the UI
    vec3 nervRed = (butterflyColor.a > 0.0) ? butterflyColor.rgb : vec3(0.80, 0.0, 0.0);
    vec3 nervHighlight = vec3(0.95, 0.12, 0.12);
    vec3 nervAura = (glowColor.a > 0.0) ? glowColor.rgb : vec3(0.80, 0.0, 0.0);

    vec4 accum = vec4(0.0);

    // ==================== 7 NERV CRIMSON BUTTERFLIES FLOCK ====================
    // 1. Hero Butterfly (Large)
    {
        vec2 pos = vec2(sin(t * 0.38) * 0.28 + 0.20, cos(t * 0.30) * 0.18 + sin(t * 0.75) * 0.03 + 0.02);
        vec2 vel = vec2(cos(t * 0.38) * 0.28 * 0.38, -sin(t * 0.30) * 0.18 * 0.30 + cos(t * 0.75) * 0.03 * 0.75);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * beatSpeed, 0.25, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 2. Medium Butterfly (Upper Right)
    {
        vec2 pos = vec2(sin(t * 0.32 + 2.2) * 0.32 + 0.26, sin(t * 0.45 + 1.4) * 0.20 + cos(t * 0.7) * 0.025 + 0.12);
        vec2 vel = vec2(cos(t * 0.32 + 2.2) * 0.32 * 0.32, cos(t * 0.45 + 1.4) * 0.20 * 0.45 - sin(t * 0.7) * 0.025 * 0.7);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 1.12) + 1.5, 0.20, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 3. Medium-Small Butterfly (Lower Right)
    {
        vec2 pos = vec2(cos(t * 0.26 + 0.8) * 0.35 + 0.18, sin(t * 0.36 + 3.0) * 0.18 - 0.12);
        vec2 vel = vec2(-sin(t * 0.26 + 0.8) * 0.35 * 0.26, cos(t * 0.36 + 3.0) * 0.18 * 0.36);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 0.95) + 3.2, 0.17, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 4. Fluttering Small Butterfly (Center Ascending)
    {
        vec2 pos = vec2(sin(t * 0.42 + 4.1) * 0.22 + 0.08, cos(t * 0.34 + 0.5) * 0.22 + 0.06);
        vec2 vel = vec2(cos(t * 0.42 + 4.1) * 0.22 * 0.42, -sin(t * 0.34 + 0.5) * 0.22 * 0.34);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 1.22) + 0.7, 0.15, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 5. Delicate Butterfly (Upper Left-Center)
    {
        vec2 pos = vec2(cos(t * 0.30 + 1.7) * 0.26 + 0.02, sin(t * 0.40 + 2.1) * 0.24 + 0.18);
        vec2 vel = vec2(-sin(t * 0.30 + 1.7) * 0.26 * 0.30, cos(t * 0.40 + 2.1) * 0.24 * 0.40);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 1.05) + 4.5, 0.14, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 6. Tiny Butterfly (Right Wing Horizon)
    {
        vec2 pos = vec2(sin(t * 0.24 + 5.2) * 0.38 + 0.32, sin(t * 0.30 + 4.0) * 0.14 - 0.04);
        vec2 vel = vec2(cos(t * 0.24 + 5.2) * 0.38 * 0.24, cos(t * 0.30 + 4.0) * 0.14 * 0.30);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 1.30) + 2.1, 0.12, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // 7. Tiny Distant Butterfly (Upper Halo)
    {
        vec2 pos = vec2(sin(t * 0.35 + 3.3) * 0.20 + 0.24, cos(t * 0.28 + 1.9) * 0.16 + 0.24);
        vec2 vel = vec2(cos(t * 0.35 + 3.3) * 0.20 * 0.35, -sin(t * 0.28 + 1.9) * 0.16 * 0.28);
        float heading = atan(vel.y, vel.x) - 1.5708;
        vec4 bf = drawButterfly(uv, pos, heading, t * (beatSpeed * 1.18) + 5.0, 0.10, nervRed, nervHighlight, nervAura);
        accum = vec4(accum.rgb + bf.rgb, max(accum.a, bf.a));
    }

    // ==================== CRIMSON EMBER TRAILS ====================
    float embers = 0.0;
    for (int i = 1; i <= 6; i++) {
        float lag = float(i) * 0.10;
        vec2 pastP1 = vec2(sin((t - lag) * 0.38) * 0.28 + 0.20, cos((t - lag) * 0.30) * 0.18 + 0.02);
        pastP1 += vec2(sin(float(i) * 3.5), cos(float(i) * 4.5)) * 0.01;
        embers += ember(uv, pastP1, float(i), t) * (1.0 - float(i) / 7.0);

        vec2 pastP2 = vec2(sin((t - lag) * 0.32 + 2.2) * 0.32 + 0.26, sin((t - lag) * 0.45 + 1.4) * 0.20 + 0.12);
        pastP2 += vec2(cos(float(i) * 2.5), sin(float(i) * 5.0)) * 0.01;
        embers += ember(uv, pastP2, float(i) + 10.0, t) * (1.0 - float(i) / 7.0) * 0.8;
    }

    if (embers > 0.01) {
        accum.rgb += nervAura * embers * 0.75;
        accum.a = max(accum.a, embers * 0.60);
    }

    if (accum.a <= 0.001) {
        fragColor = vec4(0.0);
        return;
    }

    fragColor = clamp(accum, 0.0, 1.0) * qt_Opacity;
}
