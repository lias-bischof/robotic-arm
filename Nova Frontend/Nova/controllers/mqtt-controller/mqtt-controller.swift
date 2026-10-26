import Foundation
import Observation
import MQTTNIO
import NIOCore
import NIOPosix
import NIOTransportServices


@Observable
final class MQTTController: @unchecked Sendable {
    
    var mqttState: MQTTState = .DISCONNECTED
    var robotState: RobotState = .OFFLINE
    var logger: LoggerController? = nil

    private(set) var client: MQTTClient? = nil
    private(set) var host: String
    private(set) var port: Int

    private(set) var receipt: String? = nil
    private let mqttID = UUID()
    private var monitor: Task<Void, Never>? = nil

    private static let connectionListener = "nova@connection-listener"

    init(host: String = "127.0.0.1", port: Int = 1883) {
        self.host = host
        self.port = port
    }

    func disconnect() async {
        monitor?.cancel()
        monitor = nil
        let stale = client
        client = nil
        receipt = nil
        mqttState = .DISCONNECTED
        robotState = .OFFLINE
        guard let stale else {
            return
        }
        try? await stale.disconnect()
        try? await stale.shutdown()
    }

    func connect(host: String? = nil, port: Int? = nil) async throws {
        mqttState = .CONNECTING
        
        let client = MQTTClient(
            host: host ?? self.host,
            port: port ?? self.port,
            identifier: "NOVA@" + mqttID.uuidString,
            eventLoopGroupProvider: .shared(NIOTSEventLoopGroup.singleton)
        )

        let listener = client.createPublishListener()

        do {
            try await client.connect()
            _ = try await client.subscribe(to: [
                MQTTSubscribeInfo(topicFilter: MQTTTopic.state, qos: .atLeastOnce),
                MQTTSubscribeInfo(topicFilter: MQTTTopic.receipt, qos: .atLeastOnce)
            ])
        } catch {
            try? await client.shutdown()
            if self.client == nil {
                mqttState = .DISCONNECTED
                robotState = .OFFLINE
            }
            throw MQTTError.connectionFailed(error)
        }

        self.client = client
        mqttState = .CONNECTED
        robotState = .CONNECTING

        client.addCloseListener(named: Self.connectionListener) { [weak self, weak client] _ in
            guard let self, let client else { return }
            Task { @MainActor in
                self.handleLoss(of: client)
            }
        }

        monitor = Task { [weak self, weak client] in
            for await result in listener {
                guard case .success(let message) = result,
                      message.topicName == MQTTTopic.state else {
                    continue
                }
                guard let self, let client, self.client === client else { return }
                var payload = message.payload
                self.updateState(payload.readString(length: payload.readableBytes))
            }
        }

        do {
            let receipt = try await sendData(
                topic: MQTTTopic.state,
                payload: "",
                timeout: 10
            )
            guard self.client === client else { return }
            updateState(receipt.state)
        } catch {
            guard self.client === client else { return }
            guard robotState == .CONNECTING else { return }
            robotState = .OFFLINE
            logger?.log("error: robot did not respond in time", kind: .error)
        }
    }

    private func handleLoss(of stale: MQTTClient) {
        guard client === stale else {
            return
        }
        stale.removeCloseListener(named: Self.connectionListener)
        monitor?.cancel()
        monitor = nil
        client = nil
        receipt = nil
        mqttState = .DISCONNECTED
        robotState = .OFFLINE
        logger?.log("error: lost connection to broker at \(host):\(port)", kind: .error)
        Task {
            try? await stale.shutdown()
        }
    }

    private func updateState(_ text: String?) {
        switch text {
            case "READY": robotState = .READY
            case "BUSY": robotState = .BUSY
            case "OFFLINE": robotState = .OFFLINE
            default: return
        }
    }
    
    func sendData<T: Encodable>(
        topic: String,
        payload: T
    ) async throws {
        _ = try await sendData(topic: topic, payload: payload, timeout: 120)
    }

    func sendData<T: Encodable>(
        topic: String,
        payload: T,
        timeout seconds: Int
    ) async throws -> MQTTReceipt {
        guard let client else {
            throw MQTTError.offline
        }
        let request = MQTTRequest(id: UUID().uuidString, payload: payload)
        receipt = request.id
        let listener = client.createPublishListener()
        try await publishData(topic: topic, payload: request)
        return try await getReceipt(on: listener, matching: request.id, timeout: seconds)
    }

    private func getReceipt(
        on listener: MQTTPublishListener,
        matching id: String,
        timeout seconds: Int
    ) async throws -> MQTTReceipt {
        try await withThrowingTaskGroup(of: MQTTReceipt.self) { group in
            defer { group.cancelAll() }
            group.addTask {
                for await result in listener {
                    guard case .success(let message) = result,
                          await message.topicName == MQTTTopic.receipt else {
                        continue
                    }
                    var buffer = message.payload
                    guard let bytes = buffer.readBytes(length: buffer.readableBytes),
                          let receipt = try? JSONDecoder().decode(MQTTReceipt.self, from: Data(bytes)),
                          receipt.id == id else {
                        continue
                    }
                    guard receipt.ok else {
                        throw MQTTError.commandRejected(receipt.error ?? "unknown")
                    }
                    return receipt
                }
                try Task.checkCancellation()
                throw MQTTError.offline
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw MQTTError.timedOut
            }
            guard let receipt = try await group.next() else {
                throw MQTTError.offline
            }
            return receipt
        }
    }

    private func publishData<T: Encodable>(topic: String, payload: T) async throws {
        guard let client else {
            throw MQTTError.offline
        }
        let data = try JSONEncoder().encode(payload)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        do {
            try await client.publish(
                to: topic,
                payload: buffer,
                qos: .atLeastOnce
            )
        } catch {
            throw MQTTError.publishFailed(error)
        }
    }
}
