import SwiftUI

struct TerminalInterface: View {

    var logger: LoggerController
    var terminal: TerminalController
    var mqtt: MQTTController
    var robot: RobotController
    
    @State private var input: String = ""
    @State private var cursor: Int = -1
    
    private var history: [String] {
        logger.messages.filter {
            $0.kind == .input
        }.map {
            $0.text
        }.reversed()
    }

    var body: some View {
        Card(icon: "terminal.fill", title: "CONSOLE", description: "ROBOT MONITORING & CONTROLS") {
            VStack(alignment: .leading, spacing: 25) {

                VStack(alignment: .leading, spacing: 16) {
                    Section(icon: "chevron.left.forwardslash.chevron.right", title: "TERMINAL")

                    VStack(alignment: .leading, spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(logger.messages) { message in
                                        HStack(alignment: .top, spacing: 0) {
                                            if message.kind == .input {
                                                if let receipt = message.receipt {
                                                    Text("nova@\(receipt.prefix(4).lowercased()) ~ ")
                                                        .foregroundStyle(Color(red: 0.33, green: 0.9, blue: 0.55))
                                                }else{
                                                    Text("nova ~ ")
                                                        .foregroundStyle(Color(red: 0.33, green: 0.9, blue: 0.55))
                                                }
                                                Text("% ")
                                                    .foregroundStyle(.white)
                                            }
                                            Text(message.text)
                                                .foregroundStyle(message.color())
                                        }
                                        .font(.system(size: 11, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 1)
                                        .id(message.id)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                            }
                            .frame(height: 400)
                            .onChange(of: logger.messages.count) {
                                if let last = logger.messages.last {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }

                        HStack(spacing: 0) {
                            if let receipt = mqtt.receipt {
                                Text("nova@\(receipt.prefix(4).lowercased())")
                                    .foregroundStyle(Color(red: 0.33, green: 0.9, blue: 0.55))
                            }else{
                                Text("nova")
                                    .foregroundStyle(Color(red: 0.33, green: 0.9, blue: 0.55))
                            }
                            Text(" ~ ")
                                .foregroundStyle(Color(red: 0.33, green: 0.9, blue: 0.55))
                            Text("% ")
                                .foregroundStyle(.white)
                            TextField("", text: $input)
                                .foregroundStyle(.white)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    let command = input.trimmingCharacters(in: .whitespaces)
                                    guard !command.isEmpty else { return }
                                    logger.log(command, kind: .input, receipt: mqtt.receipt)
                                    terminal.handle(command)
                                    input = ""
                                    cursor = -1
                                }
                                .onKeyPress(.upArrow) {
                                    let h = history
                                    guard !h.isEmpty else { return .ignored }
                                    cursor = min(cursor + 1, h.count - 1)
                                    input = h[cursor]
                                    return .handled
                                }
                                .onKeyPress(.downArrow) {
                                    guard cursor > 0 else {
                                        cursor = -1
                                        input = ""
                                        return .handled
                                    }
                                    cursor -= 1
                                    input = history[cursor]
                                    return .handled
                                }
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .background(.white.opacity(0.03), in: .rect(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 16) {
                    Section(icon: "dot.radiowaves.left.and.right", title: "CONNECTION")
                    HStack(spacing: 80) {
                        mqttState(mqtt)
                        robotState(robot)
                    }
                }
            }
        }
    }
    
    private func robotState(_ robot: RobotController) -> some View {
        let state = mqtt.mqttState == .CONNECTED ? robot.state : .OFFLINE
        return statusItem(
            label: state.label(),
            color: state.color(),
            pending: state.pending()
        )
    }
    
    private func mqttState(_ mqtt: MQTTController) -> some View {
        return statusItem(label: mqtt.mqttState.label(), color: mqtt.mqttState.color())
    }

    private func statusItem(label: String, color: Color, pending: Bool = false) -> some View {
        HStack(spacing: 6) {
            SwiftUI.Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .kerning(0.5)
            .foregroundStyle(.white.opacity(0.5))
        }
    }
}
