#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                             constant float4* vertices [[buffer(0)]]) {
    VertexOut out;
    float4 position = float4(vertices[vertexID].xy, 0, 1);
    out.position = position;
    out.texCoord = vertices[vertexID].zw;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                              constant float& time [[buffer(0)]],
                              constant float4* colors [[buffer(1)]]) {
    float4 color1 = colors[0];
    float4 color2 = colors[1];
    float intensity = colors[2].x;
    
    // Create a flowing gradient effect
    float2 uv = in.texCoord;
    float noise = fract(sin(dot(uv, float2(12.9898, 78.233) * 2.0)) * 43758.5453);
    
    // Create wave effect
    float wave = sin(uv.x * 10 + time) * cos(uv.y * 10 + time * 0.7) * intensity * 0.1;
    
    // Mix colors based on position and time
    float mixFactor = sin(time * 0.5) * 0.5 + 0.5;
    mixFactor = mixFactor * 0.6 + 0.2; // Keep it between 0.2 and 0.8
    
    // Add wave effect to mix factor
    mixFactor += wave;
    
    // Ensure mix factor stays in valid range
    mixFactor = clamp(mixFactor, 0.0, 1.0);
    
    // Mix the colors
    float4 finalColor = mix(color1, color2, mixFactor);
    
    // Add subtle noise
    finalColor.rgb += noise * 0.05 * intensity;
    
    return finalColor;
}

// Loading animation shaders
vertex float4 loadingVertexShader(uint vertexID [[vertex_id]],
                                 constant float2* vertices [[buffer(0)]],
                                 constant float& time [[buffer(1)]]) {
    float2 position = vertices[vertexID];
    
    // Apply rotation based on time
    float angle = time * 2.0;
    float2x2 rotationMatrix = float2x2(cos(angle), -sin(angle),
                                      sin(angle), cos(angle));
    
    // Only rotate if not the center vertex (index 0)
    if (vertexID > 0) {
        position = rotationMatrix * position;
    }
    
    // Add pulsing effect
    float scale = 1.0 + 0.1 * sin(time * 3.0);
    position *= scale;
    
    return float4(position, 0.0, 1.0);
}

fragment float4 loadingFragmentShader(float4 position [[position]],
                                     constant float4& color [[buffer(0)]]) {
    // Calculate distance from center (normalized device coordinates)
    float2 uv = position.xy / float2(position.w);
    float distance = length(uv);
    
    // Create a gradient from center
    float alpha = 1.0 - smoothstep(0.0, 1.0, distance);
    
    // Return color with alpha based on distance
    return float4(color.rgb, color.a * alpha);
} 