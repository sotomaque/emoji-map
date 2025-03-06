import SwiftUI
import MetalKit

/// A view that displays a Metal-based loading animation
struct MetalLoadingView: UIViewRepresentable {
    // MARK: - Properties
    var color: Color
    var message: String
    
    // MARK: - Initialization
    init(color: Color = .blue, message: String = "Loading...") {
        self.color = color
        self.message = message
    }
    
    // MARK: - UIViewRepresentable
    func makeUIView(context: Context) -> UIView {
        // Create a container view
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create the Metal view
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        mtkView.backgroundColor = .clear
        
        // Configure Metal
        if let device = MTLCreateSystemDefaultDevice() {
            mtkView.device = device
            mtkView.framebufferOnly = false
            mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
            
            // Initialize the Metal renderer
            context.coordinator.setupMetal(device: device, view: mtkView)
        }
        
        // Create the label
        let label = UILabel()
        label.text = message
        label.textColor = UIColor(color)
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Add views to container
        containerView.addSubview(mtkView)
        containerView.addSubview(label)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            mtkView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            mtkView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -20),
            mtkView.widthAnchor.constraint(equalToConstant: 120),
            mtkView.heightAnchor.constraint(equalToConstant: 120),
            
            label.topAnchor.constraint(equalTo: mtkView.bottomAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update color
        let colorComponents = UIColor(color).cgColor.components ?? [0, 0, 0, 1]
        context.coordinator.color = SIMD4<Float>(
            Float(colorComponents[0]),
            Float(colorComponents[1]),
            Float(colorComponents[2]),
            Float(colorComponents[3])
        )
        
        // Update message
        if let label = uiView.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = message
            label.textColor = UIColor(color)
        }
        
        // Trigger redraw
        if let mtkView = uiView.subviews.compactMap({ $0 as? MTKView }).first {
            mtkView.setNeedsDisplay()
        }
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
        var color: SIMD4<Float> = SIMD4<Float>(0.0, 0.4, 0.8, 1.0) // Default blue
        
        override init() {
            startTime = CACurrentMediaTime()
            super.init()
        }
        
        func setupMetal(device: MTLDevice, view: MTKView) {
            self.device = device
            commandQueue = device.makeCommandQueue()
            
            // Create vertex data for a circle
            var vertices: [Float] = []
            let segments = 64
            let radius: Float = 0.8
            
            // Center point
            vertices.append(0.0) // x
            vertices.append(0.0) // y
            
            // Circle points
            for i in 0...segments {
                let angle = Float(i) * (2.0 * Float.pi) / Float(segments)
                let x = radius * cos(angle)
                let y = radius * sin(angle)
                vertices.append(x)
                vertices.append(y)
            }
            
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
            var colorData = color
            colorBuffer = device.makeBuffer(
                bytes: &colorData,
                length: MemoryLayout<SIMD4<Float>>.size,
                options: .storageModeShared
            )
            
            // Create shader library and pipeline state
            guard let library = device.makeDefaultLibrary() else { return }
            let vertexFunction = library.makeFunction(name: "loadingVertexShader")
            let fragmentFunction = library.makeFunction(name: "loadingFragmentShader")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
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
            var currentTime = Float(CACurrentMediaTime() - startTime)
            memcpy(timeBuffer.contents(), &currentTime, MemoryLayout<Float>.size)
            
            // Update color
            memcpy(colorBuffer.contents(), &color, MemoryLayout<SIMD4<Float>>.size)
            
            // Create command buffer and encoder
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(timeBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(colorBuffer, offset: 0, index: 0)
            
            // Draw circle as triangle fan
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 66)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Preview
struct MetalLoadingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.opacity(0.1)
                .edgesIgnoringSafeArea(.all)
            
            MetalLoadingView(color: .blue, message: "Loading places...")
        }
    }
} 
