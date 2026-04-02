#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[ stitchable ]] float2 liquidWarp(float2 position, float phase, float amplitude) {
    float waveX = sin((position.y * 0.058f) + (phase * 3.15f)) * amplitude;
    float waveY = cos((position.x * 0.051f) - (phase * 2.35f)) * amplitude * 0.38f;
    return position + float2(waveX, waveY);
}
