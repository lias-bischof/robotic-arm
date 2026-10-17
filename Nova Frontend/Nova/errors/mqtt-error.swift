enum MQTTError: Error {
    case offline
    case connectionFailed(Error)
    case publishFailed(Error)
    case commandRejected(String)
    case timedOut
}
