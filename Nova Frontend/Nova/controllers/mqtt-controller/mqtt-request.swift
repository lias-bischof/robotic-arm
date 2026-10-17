struct MQTTRequest<T: Encodable>: Encodable {
    let id: String
    let payload: T
}
