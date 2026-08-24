import Foundation
import MyVibeIslandCore

@MainActor
public final class MyVibeIslandSessionCompletionNotificationRouter {
    private let createdAt: @MainActor () -> String
    private let childAgentNotificationTiming: V3RootResponseNotificationMode
    private let completionDwellSeconds: Double
    private var v3Producer = V3RootResponseNotificationProducer()
    private var observedPermissionRequestIDs: Set<String>?

    public init(
        childAgentNotificationTiming: V3RootResponseNotificationMode = .rootResponse,
        completionDwellSeconds: Double = 5.0,
        createdAt: @escaping @MainActor () -> String = {
            ISO8601DateFormatter().string(from: Date())
        }
    ) {
        self.childAgentNotificationTiming = childAgentNotificationTiming
        self.completionDwellSeconds = max(0, completionDwellSeconds)
        self.createdAt = createdAt
    }

    public func notifications(for snapshot: IslandRuntimeSnapshot) -> [PeekNotification] {
        let permissionRequests = snapshot.actionRequestPreviews.filter { $0.kind == .permission }
        let permissionNotifications = permissionNotifications(for: permissionRequests, previews: snapshot.sessionPreviews)
        let emissions = v3Producer.ingest(snapshot, mode: childAgentNotificationTiming)
        let previewBySessionID = Dictionary(
            uniqueKeysWithValues: snapshot.sessionPreviews.map { ($0.sessionId, $0) }
        )
        let completionNotifications = emissions.compactMap { emission -> PeekNotification? in
            guard let preview = previewBySessionID[emission.sessionId] else { return nil }
            let session = snapshot.sessions.first(where: { $0.id == emission.sessionId })
            let body = if let session {
                OriginalExpandedVerticalBodyDescriptor.completionBody(for: session)
            } else {
                OriginalExpandedVerticalBodyDescriptor.visibleActivitySummary(preview.activitySummary)
            }
            guard let body else {
                SessionCompletionTraceLog.append(
                    stage: "notification.suppressed",
                    sessionId: emission.sessionId,
                    metadata: [
                        "reason": "missing_visible_completion_body",
                        "effect": emission.effect.rawValue,
                    ]
                )
                return nil
            }
            SessionCompletionTraceLog.append(
                stage: "notification.v3_effect",
                sessionId: emission.sessionId,
                metadata: [
                    "effect": emission.effect.rawValue,
                    "bodySource": session == nil ? "preview.activitySummary" : "session.completionBody",
                    "body": body,
                ]
            )
            let id = "\(preview.sessionId):completion"
            return PeekNotification(
                id: id,
                category: .sessionCompleted,
                sessionId: preview.sessionId,
                agent: preview.sourceBadge,
                title: preview.displayTitle,
                body: body,
                severity: .info,
                primaryAction: preview.jumpAvailable ? .jump : nil,
                createdAt: createdAt(),
                dwellSeconds: completionDwellSeconds,
                dedupeKey: id,
                soundCategory: .completion,
                source: preview.sourceBadge,
                rootResponseEffect: emission.effect
            )
        }
        return completionNotifications + permissionNotifications
    }

    private func permissionNotifications(
        for requests: [ActionRequestPreview],
        previews: [SessionCardPreview]
    ) -> [PeekNotification] {
        let currentIDs = Set(requests.map(\.requestId))
        defer { observedPermissionRequestIDs = currentIDs }
        guard let observedPermissionRequestIDs else { return [] }

        let previewBySessionID = Dictionary(
            uniqueKeysWithValues: previews.map { ($0.sessionId, $0) }
        )
        return requests
            .filter { !observedPermissionRequestIDs.contains($0.requestId) }
            .prefix(1)
            .map { request in
                let preview = previewBySessionID[request.sessionId]
                let id = "\(request.requestId):permission"
                return PeekNotification(
                    id: id,
                    category: .permissionRequested,
                    sessionId: request.sessionId,
                    agent: request.source,
                    title: preview?.displayTitle ?? request.toolName,
                    body: request.prompt ?? "\(request.toolName) approval required",
                    severity: .info,
                    primaryAction: preview?.jumpAvailable == true ? .jump : nil,
                    createdAt: createdAt(),
                    dwellSeconds: 8,
                    dedupeKey: id,
                    soundCategory: .permission,
                    source: request.source
                )
            }
    }
}
