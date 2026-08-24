import Foundation

/// V3 keeps child-rollout bootstrap separate because a child transcript can
/// inherit the parent's prior history. Only post-bootstrap appends represent
/// current child activity.
public enum CodexSubagentBootstrapGate {
    public enum Decision: Equatable, Sendable {
        case consumeInitialHistory
        case skipInheritedHistory
    }

    public static func resolve(initialData: Data) -> Decision {
        for line in initialData.split(separator: UInt8(ascii: "\n")) {
            guard
                let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                object["type"] as? String == "session_meta",
                let payload = object["payload"] as? [String: Any]
            else {
                continue
            }
            return payload["thread_source"] as? String == "subagent"
                ? .skipInheritedHistory
                : .consumeInitialHistory
        }
        return .consumeInitialHistory
    }
}
