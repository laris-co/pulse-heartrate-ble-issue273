import SceneKit
import SwiftUI

/// A real, lit triangle mesh. The rate is visualized, never presented as beat detection.
struct PulseSculpture: View {
    let beatsPerMinute: Int?
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var phaseAtAnchor = 0.0
    @State private var phaseAnchor = Date()
    @State private var anchoredRate = 0.0
    @State private var clockIsRunning = false
    @State private var isVisible = false
    @State private var rotation = CGSize.zero
    @GestureState private var drag = CGSize.zero

    private var motionEnabled: Bool {
        isActive && isVisible && scenePhase == .active && !reduceMotion && (beatsPerMinute ?? 0) > 0
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !motionEnabled)) { timeline in
                let phase = phase(at: timeline.date)
                ZStack {
                    Ellipse()
                        .fill(PulsePalette.ribbonShadow.opacity(colorScheme == .dark ? 0.28 : 0.14))
                        .frame(width: min(geometry.size.width, geometry.size.height) * 0.49,
                               height: min(geometry.size.width, geometry.size.height) * 0.065)
                        .blur(radius: 14)
                        .offset(y: geometry.size.height * 0.33)
                    HeartSceneHost(
                        phase: phase,
                        yaw: Double(rotation.width + drag.width) * 0.006,
                        pitch: Double(rotation.height + drag.height) * 0.004,
                        aspect: max(0.1, geometry.size.width / max(1, geometry.size.height)),
                        isDark: colorScheme == .dark
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 8)
                .updating($drag) { value, state, _ in
                    guard !reduceMotion else { return }
                    state = CGSize(width: min(100, max(-100, value.translation.width)),
                                   height: min(65, max(-65, value.translation.height)))
                }
                .onEnded { value in
                    guard !reduceMotion else { return }
                    rotation = CGSize(width: min(100, max(-100, rotation.width + value.translation.width)),
                                      height: min(65, max(-65, rotation.height + value.translation.height)))
                })
        }
        .onAppear {
            isVisible = true
            synchronizeMotionClock(at: Date())
        }
        .onDisappear {
            synchronizeMotionClock(at: Date(), stop: true)
            isVisible = false
        }
        .onChange(of: beatsPerMinute) { _, _ in synchronizeMotionClock(at: Date()) }
        .onChange(of: motionEnabled) { _, _ in synchronizeMotionClock(at: Date()) }
        .accessibilityHidden(true)
    }

    private func phase(at date: Date) -> Double {
        guard clockIsRunning else { return phaseAtAnchor }
        return phaseAtAnchor + max(0, date.timeIntervalSince(phaseAnchor)) * anchoredRate / 60
    }

    private func synchronizeMotionClock(at date: Date, stop: Bool = false) {
        phaseAtAnchor = phase(at: date).truncatingRemainder(dividingBy: 200)
        phaseAnchor = date
        anchoredRate = Double(beatsPerMinute ?? 0)
        clockIsRunning = motionEnabled && !stop
    }
}

/// Only SwiftUI's main-thread update path writes this scene. No renderer delegate,
/// SCNActions or competing animation clock; unchanged frozen frames do no work.
private struct HeartSceneHost: UIViewRepresentable {
    let phase: Double
    let yaw: Double
    let pitch: Double
    let aspect: Double
    let isDark: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.rendersContinuously = false
        view.isPlaying = false
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let input = Frame(phase: phase, yaw: yaw, pitch: pitch, aspect: aspect, isDark: isDark)
        guard input != context.coordinator.lastFrame else { return }
        context.coordinator.lastFrame = input
        context.coordinator.update(input)
        view.setNeedsDisplay()
    }

    static func dismantleUIView(_ view: SCNView, coordinator: Coordinator) {
        view.isPlaying = false
        view.rendersContinuously = false
        view.scene = nil
    }

    struct Frame: Equatable {
        let phase: Double
        let yaw: Double
        let pitch: Double
        let aspect: Double
        let isDark: Bool
    }

    final class Coordinator {
        let scene = SCNScene()
        let camera = SCNNode()
        private let heart = SCNNode()
        private let material = SCNMaterial()
        var lastFrame: Frame?

        init() {
            let mesh = PulseHeartMesh()
            let positions = mesh.vertices.map { SCNVector3($0.position.x, $0.position.y, $0.position.z) }
            let normals = mesh.vertices.map { SCNVector3($0.normal.x, $0.normal.y, $0.normal.z) }
            let geometry = SCNGeometry(
                sources: [SCNGeometrySource(vertices: positions), SCNGeometrySource(normals: normals)],
                elements: [SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)]
            )
            material.lightingModel = .physicallyBased
            material.roughness.contents = 0.22
            material.metalness.contents = 0.08
            material.specular.contents = UIColor(white: 0.35, alpha: 1)
            material.shininess = 0.8
            geometry.materials = [material]
            heart.geometry = geometry
            scene.rootNode.addChildNode(heart)

            camera.camera = SCNCamera()
            camera.camera?.fieldOfView = 35
            camera.camera?.zNear = 0.1
            camera.camera?.zFar = 30
            scene.rootNode.addChildNode(camera)

            addLight(.omni, position: SCNVector3(-3, 4, 5), color: .white, intensity: 180)
            addLight(.omni, position: SCNVector3(3, 1, -2),
                     color: UIColor(red: 1, green: 0.62, blue: 0.80, alpha: 1), intensity: 130)
            addLight(.omni, position: SCNVector3(-2, -1, 2),
                     color: UIColor(red: 0.65, green: 0.56, blue: 1, alpha: 1), intensity: 35)
            addLight(.ambient, position: SCNVector3Zero, color: .white, intensity: 55)
        }

        private func addLight(_ type: SCNLight.LightType, position: SCNVector3, color: UIColor, intensity: CGFloat) {
            let node = SCNNode()
            node.light = SCNLight()
            node.light?.type = type
            node.light?.color = color
            node.light?.intensity = intensity
            node.position = position
            scene.rootNode.addChildNode(node)
        }

        func update(_ frame: Frame) {
            SCNTransaction.begin()
            SCNTransaction.disableActions = true
            let deformation = PulseHeartBeat.deformation(phase: frame.phase)
            heart.simdScale = deformation
            heart.eulerAngles = SCNVector3(
                -0.08 + min(0.38, max(-0.38, frame.pitch)),
                -0.18 + min(0.85, max(-0.85, frame.yaw)) + sin(frame.phase * .pi * 0.13) * 0.08,
                -0.06
            )
            heart.position.y = Float(sin(frame.phase * .pi * 0.13) * 0.035)
            // Fit the entire heart including its deformation and user rotation.
            camera.position = SCNVector3(0, 0, max(4.1, 4.0 / frame.aspect))
            let traits = UITraitCollection(userInterfaceStyle: frame.isDark ? .dark : .light)
            material.diffuse.contents = (UIColor(named: "PulseHeart") ?? .systemPink).resolvedColor(with: traits)
            SCNTransaction.commit()
        }
    }
}
