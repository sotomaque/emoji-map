import SwiftUI
import MetalKit

/// A view that renders a dynamic background effect using Metal
struct MetalBackgroundView: UIViewRepresentable {
    // MARK: - Properties
    var color1: Color
    var color2: Color
    var intensity: Float
    var speed: Float
    
    // MARK: - Initialization
    init(
        color1: Color = .blue,
        color2: Color = .purple,
        intensity: Float = 1.0,
        speed: Float = 1.0
    ) {
        self.color1 = color1
        self.color2 = color2
        self.intensity = intensity
        self.speed = speed
    }
    
    // MARK: - UIViewRepresentable
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        
        // Configure Metal
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            mtkView.framebufferOnly = false
            mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            // Initialize the Metal renderer
            context.coordinator.setupMetal(device: device, view: mtkView)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update colors and parameters
        let color1Components = UIColor(color1).cgColor.components ?? [0, 0, 0, 1]
        let color2Components = UIColor(color2).cgColor.components ?? [0, 0, 0, 1]
        
        context.coordinator.color1 = SIMD4<Float>(
            Float(color1Components[0]),
            Float(color1Components[1]),
            Float(color1Components[2]),
            Float(color1Components[3])
        )
        
        context.coordinator.color2 = SIMD4<Float>(
            Float(color2Components[0]),
            Float(color2Components[1]),
            Float(color2Components[2]),
            Float(color2Components[3])
        )
        
        context.coordinator.intensity = intensity
        context.coordinator.speed = speed
        
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, MTKViewDelegate {
        // Metal objects
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var pipelineState: MTLRenderPipelineState?
        private var vertexBuffer: MTLBuffer?
        private var timeBuffer: MTLBuffer?
        private var colorBuffer: MTLBuffer?
        private var startTime: CFTimeInterval
        
        // Parameters
        var color1: SIMD4<Float> = SIMD4<Float>(0.0, 0.4, 0.8, 1.0) // Default blue
        var color2: SIMD4<Float> = SIMD4<Float>(0.5, 0.0, 0.5, 1.0) // Default purple
        var intensity: Float = 1.0
        var speed: Float = 1.0
        
        override init() {
            startTime = CACurrentMediaTime()
            super.init()
        }
        
        func setupMetal(device: MTLDevice, view: MTKView) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            
            // Create vertex data for a full-screen quad
            let vertices: [Float] = [
                -1.0, -1.0, 0.0, 0.0,
                 1.0, -1.0, 1.0, 0.0,
                -1.0,  1.0, 0.0, 1.0,
                 1.0,  1.0, 1.0, 1.0
            ]
            
            vertexBuffer = device.makeBuffer(
                bytes: vertices,
                length: vertices.count * MemoryLayout<Float>.size,
                options: .storageModeShared
            )
            
            // Create time buffer
            var initialTime: Float = 0.0
            timeBuffer = device.makeBuffer(
                bytes: &initialTime,
                length: MemoryLayout<Float>.size,
                options: .storageModeShared
            )
            
            // Create color buffer
            var colorData = [color1, color2, SIMD4<Float>(intensity, speed, 0, 0)]
            colorBuffer = device.makeBuffer(
                bytes: &colorData,
                length: colorData.count * MemoryLayout<SIMD4<Float>>.size,
                options: .storageModeShared
            )
            
            // Create shader library and pipeline state
            guard let library = device.makeDefaultLibrary() else { return }
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }
        
        // MARK: - MTKViewDelegate
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize if needed
        }
        
        func draw(in view: MTKView) {
            guard let _ = device,
                  let commandQueue = commandQueue,
                  let pipelineState = pipelineState,
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let vertexBuffer = vertexBuffer,
                  let timeBuffer = timeBuffer,
                  let colorBuffer = colorBuffer else {
                return
            }
            
            // Update time
            var currentTime = Float(CACurrentMediaTime() - startTime) * speed
            memcpy(timeBuffer.contents(), &currentTime, MemoryLayout<Float>.size)
            
            // Update colors and parameters
            var colorData = [color1, color2, SIMD4<Float>(intensity, speed, 0, 0)]
            memcpy(colorBuffer.contents(), &colorData, colorData.count * MemoryLayout<SIMD4<Float>>.size)
            
            // Create command buffer and encoder
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentBuffer(timeBuffer, offset: 0, index: 0)
            renderEncoder.setFragmentBuffer(colorBuffer, offset: 0, index: 1)
            
            // Draw quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Metal Shaders
// Add these to a .metal file in your project
/*
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
*/

// MARK: - Preview
struct MetalBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        MetalBackgroundView()
            .edgesIgnoringSafeArea(.all)
    }
} 
