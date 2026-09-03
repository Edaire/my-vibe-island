import Foundation
import AppKit
import MyVibeIslandShared

public struct BridgeRequestHandler: Sendable {
    private enum HookIngressResult {
        case response(BridgeResponse)
        case awaitAction(
            request: ActionableRequest,
            timeout: TimeInterval,
            returnTerminalHandoffWhenUnresolved: Bool
        )
    }

    private static let trustedSources: Set<String> = [
        "claude", "qwen", "qoder", "factory", "codebuddy",
        "codex", "cursor", "gemini", "kimi", "opencode", "hermes",
    ]

    private let sessionCoordinator: SessionCoordinator
    private let adapterRegistry: AgentAdapterRegistry
    private let sessionStore: SessionStore?
    private let terminalSessionMapURL: URL?
    private let traceLogURL: URL?
    private let admissionRulesURL: URL
    private let admissionLedgerURL: URL
    private let blockingActionContinuations: PendingActionContinuations?
    private let terminalRoutedCodexApprovalHandoffDelay: TimeInterval
    private let codexApprovalOwnershipPollInterval: TimeInterval
    private let codexApprovalTarget: @Sendable () -> String?
    private let codexApprovalMode: @Sendable () -> String?
    private let codexApprovalTerminalIsFrontmost: @Sendable (HookEvent) -> Bool
    private let sessionsDidChange: @Sendable () -> Void
    private let now: @Sendable () -> Date
    private let hookIngressScheduler: HookIngressScheduler
    private let deferredSideEffectQueue: DispatchQueue

    public init(
        sessionCoordinator: SessionCoordinator,
        adapterRegistry: AgentAdapterRegistry = .default,
        sessionStore: SessionStore? = nil,
        terminalSessionMapURL: URL? = nil,
        traceLogURL: URL? = nil,
        admissionRulesURL: URL = SessionAdmissionConfig.configURL(),
        admissionLedgerURL: URL = SessionAdmissionLedger.defaultURL(),
        blockingActionContinuations: PendingActionContinuations? = nil,
        terminalRoutedCodexApprovalHandoffDelay: TimeInterval = 60,
        codexApprovalOwnershipPollInterval: TimeInterval = 1.5,
        codexApprovalTarget: @escaping @Sendable () -> String? = {
            UserDefaults.standard.string(forKey: "codexApprovalTarget")
        },
        codexApprovalMode: @escaping @Sendable () -> String? = {
            UserDefaults.standard.string(forKey: "codexApprovalMode")
        },
        codexApprovalTerminalIsFrontmost: @escaping @Sendable (HookEvent) -> Bool = {
            Self.isOwningCodexTerminalFrontmost(for: $0)
        },
        sessionsDidChange: @escaping @Sendable () -> Void = {},
        now: @escaping @Sendable () -> Date = Date.init,
        hookIngressScheduler: HookIngressScheduler = HookIngressScheduler(),
        deferredSideEffectQueue: DispatchQueue = DispatchQueue(
            label: "my-vibe-island.bridge.side-effects"
        )
    ) {
        self.sessionCoordinator = sessionCoordinator
        self.adapterRegistry = adapterRegistry
        self.sessionStore = sessionStore
        self.terminalSessionMapURL = terminalSessionMapURL
        self.traceLogURL = traceLogURL
        self.admissionRulesURL = admissionRulesURL
        self.admissionLedgerURL = admissionLedgerURL
        self.blockingActionContinuations = blockingActionContinuations
        self.terminalRoutedCodexApprovalHandoffDelay = terminalRoutedCodexApprovalHandoffDelay
        self.codexApprovalOwnershipPollInterval = codexApprovalOwnershipPollInterval
        self.codexApprovalTarget = codexApprovalTarget
        self.codexApprovalMode = codexApprovalMode
        self.codexApprovalTerminalIsFrontmost = codexApprovalTerminalIsFrontmost
        self.sessionsDidChange = sessionsDidChange
        self.now = now
        self.hookIngressScheduler = hookIngressScheduler
        self.deferredSideEffectQueue = deferredSideEffectQueue
    }

    public func handle(_ envelope: BridgeEnvelope) -> BridgeResponse {
        switch envelope.command {
        case .hello:
            return .ok(message: "bridge reachable")
        case .hookEvent:
            return handleHookEvent(envelope)
        case .watchEvent:
            return handleWatchEvent(envelope)
        case .resolveAction:
            return handleResolveAction(envelope)
        case .updateJumpTarget:
            return handleUpdateJumpTarget(envelope)
        case .healthProbe:
            return handleHealthProbe(envelope)
        }
    }

    /// Handles bridge ingress without blocking a server worker while an
    /// approval or question is waiting for a local action.
    public func handleAsync(
        _ envelope: BridgeEnvelope,
        completion: @escaping @Sendable (BridgeResponse) -> Void
    ) {
        guard envelope.command == .hookEvent else {
            completion(handle(envelope))
            return
        }

        let result = hookIngressScheduler.perform(for: envelope.hookIngressSessionKey) {
            handleHookEventInIngressOrder(envelope, deferSideEffects: true)
        }

        switch result {
        case let .response(response):
            completion(response)
        case let .awaitAction(request, timeout, returnTerminalHandoffWhenUnresolved):
            guard let blockingActionContinuations else {
                completion(.ok(message: "event accepted"))
                return
            }
            blockingActionContinuations.waitForRegisteredAsync(request, timeout: timeout) { directive in
                if let directive {
                    completion(.ok(message: "action resolved locally", sourceDirective: directive))
                } else if returnTerminalHandoffWhenUnresolved {
                    completion(.nativeApprovalHandoff())
                } else {
                    completion(.ok(message: "event accepted"))
                }
            }
        }
    }

    private func handleHookEvent(_ envelope: BridgeEnvelope) -> BridgeResponse {
        let result = hookIngressScheduler.perform(for: envelope.hookIngressSessionKey) {
            handleHookEventInIngressOrder(envelope)
        }

        switch result {
        case let .response(response):
            return response
        case let .awaitAction(request, timeout, returnTerminalHandoffWhenUnresolved):
            if let directive = blockingActionContinuations?.waitForRegistered(request, timeout: timeout) {
                return .ok(message: "action resolved locally", sourceDirective: directive)
            }

            if returnTerminalHandoffWhenUnresolved {
                return .nativeApprovalHandoff()
            }

            return .ok(message: "event accepted")
        }
    }

    private func handleHookEventInIngressOrder(
        _ envelope: BridgeEnvelope,
        deferSideEffects: Bool = false
    ) -> HookIngressResult {
        let terminalRoutedRequestID = Self.terminalRoutedCodexPermissionRequestID(for: envelope)
        let preparedEnvelope = Self.preparedHookEnvelope(
            envelope,
            terminalRoutedRequestID: terminalRoutedRequestID
        )
        let hookEvent: HookEvent
        do {
            hookEvent = try adapterRegistry.hookEvent(from: preparedEnvelope)
        } catch AgentAdapterError.invalidHookPayload {
            if isPermissionRequestPayload(preparedEnvelope.payload) {
                return .response(.failure(message: "stable requestId required"))
            }

            return .response(.failure(message: "invalid hook payload"))
        } catch {
            return .response(.failure(message: "invalid hook payload"))
        }

        let primaryEvent = AgentEvent(hookEvent: hookEvent)
        guard primaryEvent != nil || hookEvent.rawEventName != "PermissionRequest" else {
            return .response(.failure(message: "stable requestId required"))
        }

        var events = rolloutRecoveryEvents(for: hookEvent)
        events.append(contentsOf: hookEvent.agentEvents())
        guard !events.isEmpty else {
            if hookEvent.rawEventName == "PermissionRequest" {
                return .response(.failure(message: "stable requestId required"))
            }

            // V3 accepts Codex SubagentStop ingress, but this hook is not a
            // direct child-card publisher. The rollout watcher reconciles
            // child lifecycle into the parent session separately.
            if hookEvent.rawEventName == "SubagentStop", hookEvent.source.lowercased() == "codex" {
                return .response(.ok(message: "event accepted"))
            }

            return .response(.failure(message: "unsupported command"))
        }
        trace(
            stage: "bridge.received",
            sessionId: hookEvent.sessionId,
            metadata: Self.traceMetadata(
                hookEvent: hookEvent,
                primaryEvent: primaryEvent,
                events: events,
                session: sessionCoordinator.snapshot(sessionId: hookEvent.sessionId)
            )
        )

        let admissionRules = SessionAdmissionConfig.load(from: admissionRulesURL)
        let evidence = admissionEvidence(for: hookEvent)
        if hookEvent.rawEventName == "UserPromptSubmit",
           let rejection = SessionAdmissionEvaluator.rejection(
               for: evidence,
               userBundleRules: admissionRules.deniedAncestorBundles,
               userCwdRules: admissionRules.deniedCwdPatterns
           ) {
            do {
                try SessionAdmissionLedger.record(
                    sessionId: hookEvent.sessionId,
                    evidence: evidence,
                    rejection: rejection,
                    to: admissionLedgerURL,
                    now: now()
                )
                trace(
                    stage: "bridge.admission_rejected",
                    sessionId: hookEvent.sessionId,
                    metadata: [
                        "reason": rejection.description,
                        "cwd": evidence.cwd ?? "-",
                        "bundleIdentifiers": evidence.bundleIdentifiers.joined(separator: ","),
                        "ledger": admissionLedgerURL.path,
                    ]
                )
            } catch {
                trace(
                    stage: "bridge.admission_rejected",
                    sessionId: hookEvent.sessionId,
                    metadata: [
                        "reason": rejection.description,
                        "ledger": admissionLedgerURL.path,
                        "ledgerError": String(describing: error),
                    ]
                )
            }
            return .response(.ok(message: "event accepted"))
        }

        let blockingRequest = blockingActionRequest(in: events)
        let blockingTimeout = blockingRequest.flatMap(adapterRegistry.blockingTimeout(for:))
        let codexIngress = terminalRoutedRequestID == nil
            ? nil
            : CodexApprovalRoutingPolicy.ingress(
                target: codexApprovalTarget(),
                mode: codexApprovalMode()
            )
        if let blockingRequest,
           codexIngress == .silentTerminalHandoff {
            trace(
                stage: "approval.terminal_handoff",
                sessionId: blockingRequest.sessionId,
                metadata: [
                    "source": blockingRequest.source,
                    "requestId": blockingRequest.requestId,
                    "toolName": blockingRequest.toolName,
                    "reason": codexApprovalTarget() == "terminal" ? "legacy-terminal-target" : "user-mode-hide",
                    "destination": "terminal",
                ]
            )
            return .response(.nativeApprovalHandoff())
        }
        if let blockingRequest,
           blockingTimeout != nil,
           codexIngress != .passiveTerminalHandoff {
            blockingActionContinuations?.register(for: blockingRequest)
        }

        let lifecycleTimestamp = now()
        for event in events {
            sessionCoordinator.apply(
                event,
                actionableRequestLifecycleTimestamp: lifecycleTimestamp
            )
        }
        if deferSideEffects {
            deferredSideEffectQueue.async { [self] in
                saveSessionStore(updateTerminalSessionMap: hookEvent.source == "codex")
                sessionsDidChange()
            }
        } else {
            saveSessionStore(updateTerminalSessionMap: hookEvent.source == "codex")
            sessionsDidChange()
        }
        let session = sessionCoordinator.snapshot(sessionId: hookEvent.sessionId)
        trace(
            stage: "bridge.applied",
            sessionId: hookEvent.sessionId,
            metadata: Self.traceMetadata(
                hookEvent: hookEvent,
                primaryEvent: primaryEvent,
                events: events,
                session: session
            ).merging([
                "present": String(session != nil),
                "status": session?.reportedStatus.map { String(describing: $0) } ?? "-",
                "originalStatus": session.map { String(describing: $0.originalStatus) } ?? "-",
                "unread": String(session?.hasUnreadCompletion ?? false),
                "map": terminalSessionMapURL?.path ?? "-",
            ], uniquingKeysWith: { _, new in new })
        )

        if Self.endsSession(hookEvent.rawEventName) {
            blockingActionContinuations?.expire(sessionId: hookEvent.sessionId)
        }

        if terminalRoutedRequestID != nil,
           blockingRequest != nil,
           codexIngress == .passiveTerminalHandoff {
            trace(
                stage: "approval.terminal_handoff",
                sessionId: hookEvent.sessionId,
                metadata: [
                    "source": hookEvent.source,
                    "reason": "user-mode-remind",
                    "destination": "terminal",
                ]
            )
            return .response(.nativeApprovalHandoff())
        }

        if terminalRoutedRequestID != nil, let blockingRequest {
            scheduleTerminalRoutedCodexApprovalHandoff(for: blockingRequest, hookEvent: hookEvent)
        }

        if let blockingRequest, let blockingTimeout {
            // A blocked hook response must not hold the per-session mutation lane:
            // SessionEnd and resolveAction need to publish while the hook waits.
            return .awaitAction(
                request: blockingRequest,
                timeout: blockingTimeout,
                returnTerminalHandoffWhenUnresolved: terminalRoutedRequestID != nil
            )
        }

        if terminalRoutedRequestID != nil, blockingRequest != nil {
            return .response(.nativeApprovalHandoff())
        }

        return .response(.ok(message: "event accepted"))
    }

    private func admissionEvidence(for hookEvent: HookEvent) -> SessionAdmissionEvidence {
        let bundleIdentifiers = [hookEvent.environment?.cfBundleIdentifier]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return SessionAdmissionEvidence(
            cwd: hookEvent.cwd,
            bundleIdentifiers: Array(Set(bundleIdentifiers)).sorted()
        )
    }

    private func scheduleTerminalRoutedCodexApprovalHandoff(
        for request: ActionableRequest,
        hookEvent: HookEvent
    ) {
        pollCodexApprovalOwnership(
            for: request,
            hookEvent: hookEvent,
            startedAt: now()
        )
    }

    private func pollCodexApprovalOwnership(
        for request: ActionableRequest,
        hookEvent: HookEvent,
        startedAt: Date
    ) {
        guard sessionCoordinator.actionableRequests().contains(where: {
            $0.sessionId == request.sessionId && $0.requestId == request.requestId
        }) else {
            return
        }

        let deadlineExpired = now().timeIntervalSince(startedAt) >= terminalRoutedCodexApprovalHandoffDelay
        let route = CodexApprovalRoutingPolicy.route(
            target: codexApprovalTarget(),
            owningTerminalIsFrontmost: codexApprovalTerminalIsFrontmost(hookEvent),
            ownershipDeadlineExpired: deadlineExpired
        )
        if route == .handoffToTerminal {
            handoffCodexApprovalToTerminal(
                request,
                reason: deadlineExpired ? "ownership-deadline" : "terminal-ownership"
            )
            return
        }

        let remainingUntilDeadline = max(
            0,
            terminalRoutedCodexApprovalHandoffDelay - now().timeIntervalSince(startedAt)
        )
        let nextPollDelay = min(codexApprovalOwnershipPollInterval, remainingUntilDeadline)
        DispatchQueue.global().asyncAfter(deadline: .now() + nextPollDelay) { [self] in
            pollCodexApprovalOwnership(for: request, hookEvent: hookEvent, startedAt: startedAt)
        }
    }

    private func handoffCodexApprovalToTerminal(
        _ request: ActionableRequest,
        reason: String
    ) {
        // Once Codex has handed the request back to its native terminal UI, the
        // Island no longer owns a resolvable action.  A terminal deny/approve
        // does not reliably produce a second hook event, so retaining this
        // request leaves a stale blocking card forever.
        let cleared = sessionCoordinator.resolveAction(ActionResolution(
            requestId: request.requestId,
            sessionId: request.sessionId,
            kind: .dismiss
        ))
        blockingActionContinuations?.expire(
            sessionId: request.sessionId,
            requestId: request.requestId
        )
        saveSessionStore(updateTerminalSessionMap: true)
        sessionsDidChange()
        trace(
            stage: "approval.terminal_handoff",
            sessionId: request.sessionId,
            metadata: [
                "source": request.source,
                "requestId": request.requestId,
                "toolName": request.toolName,
                "reason": reason,
                "destination": "terminal",
                "delaySeconds": String(terminalRoutedCodexApprovalHandoffDelay),
                "clearedIslandRequest": String(cleared),
            ]
        )
    }

    private func handleWatchEvent(_ envelope: BridgeEnvelope) -> BridgeResponse {
        let watchEvent: WatchEventPayload
        do {
            watchEvent = try WatchEventPayload(payload: envelope.payload)
        } catch {
            return .failure(message: "invalid watch payload")
        }

        let events = watchEvent.agentEvents(source: envelope.source)
        guard !events.isEmpty else {
            return .failure(message: "unsupported command")
        }

        for event in events {
            sessionCoordinator.apply(event)
        }

        saveSessionStore(updateTerminalSessionMap: envelope.source == "codex")
        sessionsDidChange()
        return .ok(message: "event accepted")
    }

    private func handleResolveAction(_ envelope: BridgeEnvelope) -> BridgeResponse {
        let payload: ActionResolutionPayload
        do {
            payload = try ActionResolutionPayload(payload: envelope.payload)
        } catch {
            return .failure(message: "invalid resolve action payload")
        }

        let actionableRequest = sessionCoordinator.actionableRequests().first {
            $0.requestId == payload.resolution.requestId && $0.sessionId == payload.resolution.sessionId
        }
        let resolved = sessionCoordinator.resolveAction(payload.resolution)
        guard resolved else {
            return .failure(message: "action request not found")
        }

        saveSessionStore(updateTerminalSessionMap: actionableRequest?.source == "codex")
        sessionsDidChange()
        if let selection = payload.resolution.selection, !selection.isEmpty {
            sessionStore?.setQuestionSelection(selection, forRequestId: payload.resolution.requestId)
        }

        let sourceDirective: BridgeJSONValue?
        if let actionableRequest {
            switch adapterRegistry.directive(for: actionableRequest, resolution: payload.resolution) {
            case .none:
                sourceDirective = nil
            case let .json(value):
                sourceDirective = value
            }
        } else {
            sourceDirective = nil
        }

        if let sourceDirective {
            blockingActionContinuations?.resolve(
                sessionId: payload.resolution.sessionId,
                requestId: payload.resolution.requestId,
                directive: sourceDirective
            )
        } else {
            blockingActionContinuations?.expire(
                sessionId: payload.resolution.sessionId,
                requestId: payload.resolution.requestId
            )
        }

        return .ok(message: "action resolved locally", sourceDirective: sourceDirective)
    }

    private func handleUpdateJumpTarget(_ envelope: BridgeEnvelope) -> BridgeResponse {
        guard envelope.clientRole == "watcher",
              Self.trustedSources.contains(envelope.source),
              let sessionId = envelope.payload.sessionId,
              let session = sessionCoordinator.snapshot(sessionId: sessionId),
              session.source == envelope.source else {
            return .failure(message: "untrusted jump target update")
        }

        let payload: JumpTargetUpdatePayload
        do {
            payload = try JumpTargetUpdatePayload(payload: envelope.payload, requestSource: envelope.source)
        } catch {
            return .failure(message: "invalid jump target payload")
        }

        let resolved = TerminalResolver().resolve(payload.jumpInput, provenance: .processObservation)
        guard sessionCoordinator.updateJumpTarget(
            sessionId: payload.sessionId,
            jumpInput: payload.jumpInput,
            provenance: .processObservation,
            strength: resolved.strength
        ) else {
            return .failure(message: "session not found")
        }

        saveSessionStore(updateTerminalSessionMap: envelope.source == "codex")
        sessionsDidChange()
        return .ok(message: "jump target updated")
    }

    private func handleHealthProbe(_ envelope: BridgeEnvelope) -> BridgeResponse {
        guard envelope.clientRole == "diagnostic" || envelope.clientRole == "setup",
              Self.trustedSources.contains(envelope.source),
              let payload = try? HealthProbePayload(payload: envelope.payload),
              payload.source == envelope.source else {
            return .failure(message: "unsupported command")
        }

        return .ok(
            message: "health probe complete",
            sourceDirective: payload.response()
        )
    }

    @discardableResult
    func clientDisconnected(_ envelope: BridgeEnvelope) -> Bool {
        guard let request = blockingRequest(for: envelope) else {
            return false
        }
        guard blockingActionContinuations?.cancel(
            sessionId: request.sessionId,
            requestId: request.requestId
        ) == true else {
            return false
        }

        _ = sessionCoordinator.resolveAction(ActionResolution(
            requestId: request.requestId,
            sessionId: request.sessionId,
            kind: .dismiss
        ))
        saveSessionStore(updateTerminalSessionMap: request.source == "codex")
        sessionsDidChange()
        trace(
            stage: "approval.client_disconnected",
            sessionId: request.sessionId,
            metadata: [
                "source": request.source,
                "requestId": request.requestId,
                "toolName": request.toolName,
            ]
        )
        return true
    }

    func shutdown() {
        blockingActionContinuations?.cancelAll()
    }

    private func saveSessionStore(updateTerminalSessionMap: Bool = false) {
        if let sessionStore {
            sessionCoordinator.save(to: sessionStore)
        }
        if updateTerminalSessionMap, let terminalSessionMapURL {
            _ = try? CodexTerminalSessionMapWriter().write(
                sessions: sessionCoordinator.snapshots(),
                to: terminalSessionMapURL
            )
        }
    }

    private func rolloutRecoveryEvents(for hookEvent: HookEvent) -> [AgentEvent] {
        guard hookEvent.source.lowercased() == "codex",
              hookEvent.rawEventName == "UserPromptSubmit",
              let session = sessionCoordinator.snapshot(sessionId: hookEvent.sessionId),
              let rolloutPath = hookEvent.codexRolloutPath ?? session.codexRolloutPath,
              let firstUserMessage = CodexAdapter.firstUserMessageFromTranscript(path: rolloutPath)
        else {
            return []
        }

        return [
            .sessionActivityUpdated(
                source: "codex",
                sessionId: hookEvent.sessionId,
                activity: SessionActivityUpdate(
                    status: session.reportedStatus ?? .active,
                    summary: session.activitySummary,
                    firstUserMessage: firstUserMessage,
                    codexRolloutPath: rolloutPath,
                    cwd: session.cwd
                )
            ),
        ]
    }

    private func trace(
        stage: String,
        sessionId: String?,
        metadata: [String: String]
    ) {
        SessionCompletionTraceLog.append(
            stage: stage,
            sessionId: sessionId,
            metadata: metadata,
            fileURL: traceLogURL ?? SessionCompletionTraceLog.defaultFileURL()
        )
    }

    private static func traceMetadata(
        hookEvent: HookEvent,
        primaryEvent: AgentEvent?,
        events: [AgentEvent],
        session: SessionState?
    ) -> [String: String] {
        var metadata: [String: String] = [
            "source": hookEvent.source,
            "event": hookEvent.rawEventName,
            "events": String(events.count),
            "requestId": hookEvent.requestId ?? "-",
            "toolName": hookEvent.toolName ?? "-",
            "message": hookEvent.message ?? "-",
            "prompt": hookEvent.actionRequestDetails?.prompt ?? "-",
            "activeTool": session?.activeTool ?? "-",
            "toolTarget": session?.toolTarget ?? "-",
            "assistantMessage": session?.lastAssistantMessage ?? "-",
            "currentCommandPreview": session?.currentCommandPreview ?? "-",
            "activitySummary": session?.activitySummary ?? "-",
            "firstUserMessage": session?.firstUserMessage ?? "-",
            "lastUserMessage": session?.lastUserMessage ?? "-",
            "primaryEvent": primaryEvent.map { String(describing: $0) } ?? "nil",
        ]
        metadata["cwd"] = hookEvent.cwd
        if let rollup = hookEvent.codexRolloutPath {
            metadata["codexRolloutPath"] = rollup
        }
        if let status = session?.reportedStatus {
            metadata["reportedStatus"] = String(describing: status)
        }
        if let originalStatus = session?.originalStatus {
            metadata["originalStatus"] = String(describing: originalStatus)
        }
        return metadata
    }

    private func isPermissionRequestPayload(_ payload: [String: BridgeJSONValue]) -> Bool {
        if case .string("PermissionRequest") = payload["rawEventName"] {
            return true
        }

        if case .string("PermissionRequest") = payload["hook_event_name"] {
            return true
        }

        return false
    }

    /// IDA records the original bridge's `terminalRoutedCodexApprovals` state.
    /// Codex sends these terminal-routed approvals without a stable request id,
    /// but its turn id is stable for the single pending terminal prompt.
    private static func terminalRoutedCodexPermissionRequestID(
        for envelope: BridgeEnvelope
    ) -> String? {
        guard envelope.source == "codex",
              envelope.command == .hookEvent,
              envelope.requestId == nil,
              stringValue("hook_event_name", in: envelope.payload) == "PermissionRequest",
              stableRequestID(in: envelope.payload) == nil,
              let sessionID = stringValue("session_id", in: envelope.payload),
              let turnID = stringValue("turn_id", in: envelope.payload) else {
            return nil
        }
        return "codex-terminal:\(sessionID):\(turnID)"
    }

    private static func preparedHookEnvelope(
        _ envelope: BridgeEnvelope,
        terminalRoutedRequestID: String?
    ) -> BridgeEnvelope {
        guard let terminalRoutedRequestID else {
            return envelope
        }
        return BridgeEnvelope(
            schemaVersion: envelope.schemaVersion,
            clientRole: envelope.clientRole,
            source: envelope.source,
            requestId: terminalRoutedRequestID,
            command: envelope.command,
            payload: envelope.payload,
            sentAt: envelope.sentAt,
            environment: envelope.environment
        )
    }

    private static func stableRequestID(in payload: [String: BridgeJSONValue]) -> String? {
        ["tool_use_id", "request_id", "requestId"]
            .compactMap { stringValue($0, in: payload) }
            .first
    }

    private static func stringValue(_ key: String, in payload: [String: BridgeJSONValue]) -> String? {
        guard case let .string(value) = payload[key], !value.isEmpty else {
            return nil
        }
        return value
    }

    /// The original route trace includes both the event's terminal bundle id
    /// and TTY. Matching both prevents an unrelated terminal window from
    /// taking ownership of this pending approval.
    public static func isOwningCodexTerminalFrontmost(for hookEvent: HookEvent) -> Bool {
        guard
            let environment = hookEvent.environment,
            let bundleIdentifier = environment.cfBundleIdentifier,
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleIdentifier
        else {
            return false
        }

        guard let tty = normalizedTTY(environment.tty) else {
            return false
        }
        return ActiveCliTTYProvider().activeTTYs().contains(tty)
    }

    private static func normalizedTTY(_ tty: String?) -> String? {
        guard let tty else {
            return nil
        }
        let value = tty.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != "?", value != "??" else {
            return nil
        }
        return value.hasPrefix("/dev/") ? String(value.dropFirst(5)) : value
    }

    private func blockingActionRequest(in events: [AgentEvent]) -> ActionableRequest? {
        for event in events {
            switch event {
            case let .permissionRequested(source, sessionId, requestId, toolName, details):
                return ActionableRequest(
                    requestId: requestId,
                    sessionId: sessionId,
                    source: source,
                    kind: .permission,
                    toolName: toolName,
                    details: details
                )
            case let .questionAsked(source, sessionId, requestId, toolName, details):
                return ActionableRequest(
                    requestId: requestId,
                    sessionId: sessionId,
                    source: source,
                    kind: .question,
                    toolName: toolName,
                    details: details
                )
            default:
                continue
            }
        }

        return nil
    }

    private func blockingRequest(for envelope: BridgeEnvelope) -> ActionableRequest? {
        let terminalRoutedRequestID = Self.terminalRoutedCodexPermissionRequestID(for: envelope)
        let preparedEnvelope = Self.preparedHookEnvelope(
            envelope,
            terminalRoutedRequestID: terminalRoutedRequestID
        )
        guard preparedEnvelope.command == .hookEvent,
              let hookEvent = try? adapterRegistry.hookEvent(from: preparedEnvelope) else {
            return nil
        }
        return blockingActionRequest(in: hookEvent.agentEvents())
    }

    private static func endsSession(_ eventName: String) -> Bool {
        eventName == "Stop" || eventName == "StopFailure" || eventName == "SessionEnd"
    }
}

private extension Dictionary where Key == String, Value == BridgeJSONValue {
    var sessionId: String? {
        guard case let .string(value) = self["sessionId"], !value.isEmpty else {
            return nil
        }
        return value
    }
}
