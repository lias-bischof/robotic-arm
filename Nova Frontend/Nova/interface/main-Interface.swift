import SwiftUI
import RealityKit

struct Interface: View {
    
    @State private var robot: RobotController
    @State private var mqtt: MQTTController
    @State private var path = Path()
    @State private var logger = LoggerController()
    @State private var camera = createCamera()

    init() {
        let mqtt = MQTTController(host: "127.0.0.1")
        _mqtt = State(initialValue: mqtt)
        _robot = State(initialValue: RobotController(mqtt: mqtt))
    }

    private var terminal: TerminalController {
        TerminalController(path: path, robot: robot, mqtt: mqtt, logger: logger)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 25) {
                        HStack(spacing: 16) {
                            Image(systemName: "rotate.3d")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.orange)
                                .frame(width: 54, height: 54)
                                .background(.gray.opacity(0.12))

                            Divider()
                                .frame(height: 54)
                                .overlay(.white.opacity(0.12))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("NOVA")
                                    .font(.system(size: 38, weight: .bold, design: .monospaced))
                                    .kerning(2)
                                    .foregroundStyle(.white.opacity(0.9))

                                Text("ROBOT CONTROLS")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .kerning(1.4)
                                    .foregroundStyle(.gray.opacity(0.8))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        TerminalInterface(logger: logger, terminal: terminal, mqtt: mqtt, robot: robot)
                        PathInterface(path: path, machine: robot.machine)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                .background(Color(.primary))
                .frame(width: geometry.size.width * 0.4, height: geometry.size.height, alignment: .topLeading)

                Color(.primary)
                    .frame(width: 1)

                RealityView { content in
                    content.add(path.scene)
                    content.add(robot.machine.scene)
                    content.add(createGrid())
                    content.add(camera)
                }
                .onAppear {
                    terminal.help()
                }
                .task {
                    mqtt.logger = logger
                    do {
                        try await mqtt.connect()
                    } catch {
                        logger.log("MQTT connection failed: \(error)", kind: .error)
                    }
                }
                .realityViewCameraControls(.orbit)
                .background(Color(.primary))
                .frame(width: geometry.size.width * 0.6)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 8) {
                        cameraItem("TOP", from: SIMD3<Float>(0, 100, 0))
                        cameraItem("ISO", from: SIMD3<Float>(0, 51, 85 * sin(Float.pi / 3)))
                    }
                    .padding(12)
                }
            }
        }
    }
    
    private func cameraItem(_ title: String, from position: SIMD3<Float>) -> some View {
        Button {
            camera.look(at: SIMD3<Float>(0, 0, 0), from: position, relativeTo: nil)
        } label: {
            Text(title)
                .font(.system(size: 12, design: .monospaced))
                .kerning(1)
                .foregroundStyle(.gray)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Color(.primary).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
