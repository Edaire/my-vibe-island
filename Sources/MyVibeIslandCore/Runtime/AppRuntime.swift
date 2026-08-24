import Foundation
import MyVibeIslandShared

public final class AppRuntime: @unchecked Sendable {
    private let socketPath: String
    private let localWatcherHomeDirectory: URL
    private let sessionCoordinator: SessionCoordinator
    private let sessionStore: SessionStore?
    private let blockingActionContinuations: PendingActionContinuations?
    private let jumpRunner: TerminalJumpActionRunning?
    private let activeCliTTYs: @Sendable ([AgentSession]) -> Set<String>
    private let activeCodexSessions: @Sendable (SessionStore) -> [SessionState]?
    private let liveCodexSessionIDs: @Sendable () -> Set<String>
    private let jumpInputEnricher: @Sendable (JumpInput) -> JumpInput
    private let lock = NSLock()
    private let sessionPreviewObserverLock = NSLock()
    private let lifecycleLock = NSLock()
    private let publicationScheduleLock = NSLock()
    private let publicationQueue: DispatchQueue
    private var bridgeServer: BridgeServer?
    private var openCodeSyncDiagnostics: OpenCodeSyncDiagnostics?
    private var codexSessionWatcher: CodexSessionWatcher?
    private var openCodeContinuousSessionWatcher: OpenCodeContinuousSessionWatcher?
    private var claudeCoworkWatcher: ClaudeCoworkWatcher?
    private var isPublicationScheduled = false
    private var publicationDirty = false
    private var lastPublishedCoordinatorRevision: UInt64?
    private var sessionPreviewsDidChange: @Sendable ([SessionCardPreview]) -> Void
    private var islandRuntimeDidChange: @Sendable (IslandRuntimeSnapshot) -> Void

    public convenience init(
        socketPath: String = BridgeSocketPath.defaultPath(),
        sessionCoordinator: SessionCoordinator = SessionCoordinator(),
        sessionStore: SessionStore? = nil,
        blockingActionContinuations: PendingActionContinuations? = PendingActionContinuations(timeout: 3_600),
        jumpRunner: TerminalJumpActionRunning? = nil,
        activeCliTTYs: @escaping @Sendable ([AgentSession]) -> Set<String> = { _ in [] },
        activeCodexSessions: @escaping @Sendable (SessionStore) -> [SessionState]? = { _ in nil },
        liveCodexSessionIDs: @escaping @Sendable () -> Set<String> = { [] },
        localWatcherHomeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory(),
        sessionPreviewsDidChange: @escaping @Sendable ([SessionCardPreview]) -> Void = { _ in },
        islandRuntimeDidChange: @escaping @Sendable (IslandRuntimeSnapshot) -> Void = { _ in }
    ) {
        self.init(
            socketPath: socketPath,
            sessionCoordinator: sessionCoordinator,
            sessionStore: sessionStore,
            blockingActionContinuations: blockingActionContinuations,
            jumpRunner: jumpRunner,
            activeCliTTYs: activeCliTTYs,
            activeCodexSessions: activeCodexSessions,
            liveCodexSessionIDs: liveCodexSessionIDs,
            jumpInputEnricher: { $0 },
            localWatcherHomeDirectory: localWatcherHomeDirectory,
            sessionPreviewsDidChange: sessionPreviewsDidChange,
            islandRuntimeDidChange: islandRuntimeDidChange
        )
    }

    public init(
        socketPath: String = BridgeSocketPath.defaultPath(),
        sessionCoordinator: SessionCoordinator = SessionCoordinator(),
        sessionStore: SessionStore? = nil,
        blockingActionContinuations: PendingActionContinuations? = PendingActionContinuations(timeout: 3_600),
        jumpRunner: TerminalJumpActionRunning? = nil,
        activeCliTTYs: @escaping @Sendable ([AgentSession]) -> Set<String> = { _ in [] },
        activeCodexSessions: @escaping @Sendable (SessionStore) -> [SessionState]? = { _ in nil },
        liveCodexSessionIDs: @escaping @Sendable () -> Set<String> = { [] },
        jumpInputEnricher: @escaping @Sendable (JumpInput) -> JumpInput = { $0 },
        localWatcherHomeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory(),
        restorePersistedSessions: Bool = true,
        publicationQueue: DispatchQueue? = nil,
        sessionPreviewsDidChange: @escaping @Sendable ([SessionCardPreview]) -> Void = { _ in },
        islandRuntimeDidChange: @escaping @Sendable (IslandRuntimeSnapshot) -> Void = { _ in }
    ) {
        self.socketPath = socketPath
        self.localWatcherHomeDirectory = localWatcherHomeDirectory
        self.sessionCoordinator = sessionCoordinator
        self.sessionStore = sessionStore
        self.blockingActionContinuations = blockingActionContinuations
        self.jumpRunner = jumpRunner
        self.activeCliTTYs = activeCliTTYs
        self.activeCodexSessions = activeCodexSessions
        self.liveCodexSessionIDs = liveCodexSessionIDs
        self.jumpInputEnricher = jumpInputEnricher
        self.publicationQueue = publicationQueue ?? DispatchQueue(
            label: "my-vibe-island.app-runtime.publication"
        )
        self.sessionPreviewsDidChange = sessionPreviewsDidChange
        self.islandRuntimeDidChange = islandRuntimeDidChange
        if restorePersistedSessions,
           let sessionStore,
           sessionCoordinator.snapshots().isEmpty {
            sessionCoordinator.restore(from: sessionStore)
        }
        _ = sessionCoordinator.addSessionEndCleanupObserver { [weak self] in
            guard let self else { return }
            self.persistSessionState(updateTerminalSessionMap: true)
            self.publishSessionPreviews()
        }
    }

    public convenience init(
        socketPath: String = BridgeSocketPath.defaultPath(),
        sessionCoordinator: SessionCoordinator = SessionCoordinator(),
        sessionStore: SessionStore? = nil,
        blockingActionContinuations: PendingActionContinuations? = PendingActionContinuations(timeout: 3_600),
        jumpRunner: TerminalJumpActionRunning? = nil,
        activeCliTTYs: @escaping @Sendable ([AgentSession]) -> Set<String> = { _ in [] },
        localWatcherHomeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory(),
        sessionPreviewsDidChange: @escaping @Sendable ([SessionCardPreview]) -> Void = { _ in },
        islandRuntimeDidChange: @escaping @Sendable (IslandRuntimeSnapshot) -> Void = { _ in }
    ) {
        self.init(
            socketPath: socketPath,
            sessionCoordinator: sessionCoordinator,
            sessionStore: sessionStore,
            blockingActionContinuations: blockingActionContinuations,
            jumpRunner: jumpRunner,
            activeCliTTYs: activeCliTTYs,
            activeCodexSessions: { _ in nil },
            localWatcherHomeDirectory: localWatcherHomeDirectory,
            sessionPreviewsDidChange: sessionPreviewsDidChange,
            islandRuntimeDidChange: islandRuntimeDidChange
        )
    }

    public static func productionRuntime(
        homeDirectory: URL = VibeIslandStateRoot.runtimeHomeDirectory()
    ) -> AppRuntime {
        let kanbanBrowserJumpTargetEnricher = KanbanBrowserJumpTargetEnricher()
        let liveCodexRolloutDiscovery = CodexLiveRolloutDiscovery()
        return AppRuntime(
            sessionStore: AppRuntimeSessionStore.defaultStore(homeDirectory: homeDirectory),
            jumpRunner: TerminalJumpActionRunner(
                workspaceRunner: WorkspaceJumpRunner(
                    workspaceOpener: SystemWorkspaceOpener(),
                    ideWorkspaceOpener: IDEWorkspaceOpener()
                ),
                cliRunner: CLIActionRunner(),
                socketRunner: SocketActionRunner(),
                urlRunner: URLActionRunner(canOpen: SystemURLSchemeAvailability().canOpen),
                applicationRunner: ApplicationActionRunner(),
                automationRunner: AutomationActionRunner()
            ),
            liveCodexSessionIDs: {
                liveCodexRolloutDiscovery.discoverTopLevelSessionIDs()
            },
            jumpInputEnricher: { input in
                kanbanBrowserJumpTargetEnricher.enrich(input)
            },
            localWatcherHomeDirectory: homeDirectory
        )
    }

    deinit {
        stop()
    }

    public func startBridge() throws {
        lock.lock()
        do {
            guard bridgeServer == nil else {
                throw BridgeSocketError.alreadyRunning
            }

            let handler = BridgeRequestHandler(
                sessionCoordinator: sessionCoordinator,
                sessionStore: sessionStore,
                terminalSessionMapURL: AppRuntimeSessionStore.defaultDirectory(homeDirectory: localWatcherHomeDirectory)
                    .appendingPathComponent("session-terminals.json"),
                blockingActionContinuations: blockingActionContinuations,
                sessionsDidChange: { [weak self] in
                    self?.publishSessionPreviews()
                }
            )
            let server = BridgeServer(socketPath: socketPath, handler: handler)
            try server.start()
            bridgeServer = server
            lock.unlock()
        } catch {
            lock.unlock()
            throw error
        }

        publishSessionPreviews()
    }

    public func setSessionPreviewsDidChange(
        _ observer: @escaping @Sendable ([SessionCardPreview]) -> Void
    ) {
        sessionPreviewObserverLock.lock()
        sessionPreviewsDidChange = observer
        sessionPreviewObserverLock.unlock()
    }

    public func setIslandRuntimeDidChange(
        _ observer: @escaping @Sendable (IslandRuntimeSnapshot) -> Void
    ) {
        sessionPreviewObserverLock.lock()
        islandRuntimeDidChange = observer
        sessionPreviewObserverLock.unlock()
    }

    public func sessionCardPreviews() -> [SessionCardPreview] {
        sessionCoordinator.readSnapshot().sessions.map {
            SessionCardPreview(session: $0.agentSession(), snapshot: $0.snapshot())
        }
    }

    public func actionRequestPreviews() -> [ActionRequestPreview] {
        sessionCoordinator.actionableRequests()
            .map { request in
                ActionRequestPreview(
                    request: request,
                    isLocallyOwned: blockingActionContinuations?.owns(request) ?? false
                )
            }
            .sorted {
                ($0.sessionId, $0.requestId) < ($1.sessionId, $1.requestId)
            }
    }

    public func islandRuntimeSnapshot() -> IslandRuntimeSnapshot {
        islandRuntimeSnapshot(from: sessionCoordinator.readSnapshot())
    }

    private func islandRuntimeSnapshot(from read: SessionCoordinatorReadSnapshot) -> IslandRuntimeSnapshot {
        let sessionStates = runtimeSurfaceSessionStates(from: read)
        let liveCodexIDs = liveCodexSessionIDs()
        // IDA: NotchViewModel projects the Store-owned dictionary once, sorts
        // by status rank / lastActivityAt, then applies eligibility. Lifecycle
        // retention belongs to SessionStore cleanup, not a UI-side age, TTY,
        // spotlight, or content heuristic.
        let displaySessions = OriginalSessionDisplayOrder.sort(
            sessionStates
                .map { $0.agentSession() }
                .filter {
                    OriginalSessionDisplayEligibility.isEligible(
                        $0,
                        liveSessionIDs: liveCodexIDs
                    )
                }
        )
        let surfacedIDs = Set(displaySessions.map(\.id))
        let stateByID = Dictionary(uniqueKeysWithValues: sessionStates.map { ($0.sessionId, $0) })
        return IslandRuntimeSnapshot(
            sessions: displaySessions,
            sessionPreviews: displaySessions.map { session in
                SessionCardPreview(session: session, snapshot: stateByID[session.id]?.snapshot())
            },
            actionRequestPreviews: read.actionableRequests
                .map { request in
                    ActionRequestPreview(
                        request: request,
                        isLocallyOwned: blockingActionContinuations?.owns(request) ?? false
                    )
                }
                .filter { surfacedIDs.contains($0.sessionId) }
                .sorted { ($0.sessionId, $0.requestId) < ($1.sessionId, $1.requestId) }
            ,
            v3NotificationMetadata: Dictionary(
                uniqueKeysWithValues: sessionStates.map { state in
                    let runningChildren = state.subagents.filter {
                        $0.hasLifecycleSignal
                            && $0.status != SubagentLifecycleUpdate.Status.completed.rawValue
                    }.count
                    return (
                        state.sessionId,
                        V3SessionNotificationMetadata(
                            childTreeGeneration: Int(clamping: state.childTreeGeneration),
                            childLifecycleRevision: Int(clamping: state.childLifecycleRevision),
                            childTreeHasAuthoritativeChildren: state.childTreeHasAuthoritativeChildren,
                            runningAuthoritativeChildCount: runningChildren,
                            hasSameTreeAttention: state.hasV3SameTreeAttention
                        )
                    )
                }
            )
        )
    }

    private func runtimeSurfaceSessionStates(from read: SessionCoordinatorReadSnapshot) -> [SessionState] {
        // IDA shows SessionStore publishes its own session snapshot directly to
        // the view model. Terminal/process observation may enrich a known jump
        // target, but it must never replace or create render-list cards.
        read.sessions
    }

    public func publishSessionPreviews() {
        publishSessionPreviews(force: false)
    }

    private func publishSessionPreviews(force: Bool) {
        publicationScheduleLock.lock()
        publicationDirty = true
        guard !isPublicationScheduled else {
            publicationScheduleLock.unlock()
            return
        }
        isPublicationScheduled = true
        publicationScheduleLock.unlock()

        publicationQueue.async { [weak self] in
            self?.performPublication(force: force)
        }
    }

    private func performPublication(force: Bool = false) {
        publicationScheduleLock.lock()
        isPublicationScheduled = false
        publicationDirty = false
        publicationScheduleLock.unlock()

        let read = sessionCoordinator.readSnapshot()
        if !force,
           let lastPublishedCoordinatorRevision,
           read.revision <= lastPublishedCoordinatorRevision { return }
        lastPublishedCoordinatorRevision = read.revision
        let snapshot = islandRuntimeSnapshot(from: read)
        let allPreviews = read.sessions.map {
            SessionCardPreview(session: $0.agentSession(), snapshot: $0.snapshot())
        }
        sessionPreviewObserverLock.lock()
        let sessionObserver = sessionPreviewsDidChange
        let islandObserver = islandRuntimeDidChange
        sessionPreviewObserverLock.unlock()
        islandObserver(snapshot)
        sessionObserver(allPreviews)

        publicationScheduleLock.lock()
        guard publicationDirty, !isPublicationScheduled else {
            publicationScheduleLock.unlock()
            return
        }
        isPublicationScheduled = true
        publicationScheduleLock.unlock()
        publicationQueue.async { [weak self] in
            self?.performPublication()
        }
    }

    public func stop() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stopLocalSessionWatchersLockedWithoutLifecycleLock()

        lock.lock()
        let server = bridgeServer
        bridgeServer = nil
        lock.unlock()

        server?.stop()
    }

    public func stopLocalSessionWatchers() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        stopLocalSessionWatchersLockedWithoutLifecycleLock()
    }

    public var areLocalSessionWatchersRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return codexSessionWatcher != nil
            || openCodeContinuousSessionWatcher != nil
            || claudeCoworkWatcher != nil
    }

    private func stopLocalSessionWatchersLockedWithoutLifecycleLock() {
        lock.lock()
        let codexWatcher = codexSessionWatcher
        let openCodeWatcher = openCodeContinuousSessionWatcher
        let claudeCoworkWatcher = claudeCoworkWatcher
        codexSessionWatcher = nil
        openCodeContinuousSessionWatcher = nil
        self.claudeCoworkWatcher = nil
        lock.unlock()
        codexWatcher?.stop()
        openCodeWatcher?.stop()
        claudeCoworkWatcher?.stop()
    }

    public func start(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        lock.lock()
        guard codexSessionWatcher == nil,
              openCodeContinuousSessionWatcher == nil,
              claudeCoworkWatcher == nil else {
            lock.unlock()
            return
        }
        let handler: @Sendable (AgentEvent) -> Void = { [weak self] event in
            guard let self else { return }
            self.sessionCoordinator.apply(event)
            // The Codex watcher and bridge share this coordinator. Rewrite the
            // map after every watcher event so rollout recovery cannot leave a
            // hook-time first-message snapshot behind.
            self.persistSessionState(updateTerminalSessionMap: true)
            self.publishSessionPreviews()
        }
        let codexWriterInfoResolver = CodexWriterInfoResolver()
        let liveCodexRolloutDiscovery = CodexLiveRolloutDiscovery()
        let codexRolloutRoots = [homeDirectory.appendingPathComponent(".codex/sessions", isDirectory: true)]
        let codexDiscovery = CodexSessionDiscovery(roots: codexRolloutRoots, maximumFiles: 15)
        let codex = CodexSessionWatcher(
            discovery: codexDiscovery,
            liveDiscovery: { liveCodexRolloutDiscovery.discover() },
            requiresLiveWriterForNewSession: true,
            writerInfoResolver: { file, completion in
                DispatchQueue.global(qos: .utility).async {
                    completion(codexWriterInfoResolver.resolve(rolloutPath: file.url.path))
                }
            },
            writerTrace: { trace in
                SessionCompletionTraceLog.append(
                    stage: trace.stage.rawValue,
                    sessionId: trace.sessionId,
                    metadata: [
                        "rolloutPath": trace.rolloutPath,
                        "inode": trace.inode.map(String.init) ?? "-",
                        "pid": trace.writerInfo?.pid.map(String.init) ?? "-",
                        "tty": trace.writerInfo?.tty ?? "-",
                        "outcome": trace.writerInfo?.outcome.rawValue ?? "-",
                        "terminalBundleId": trace.writerInfo?.terminalBundleId ?? "-",
                        "deniedAncestorBundleId": trace.writerInfo?.admissionDeniedAncestorBundleId ?? "-",
                        "publishedEventCount": trace.publishedEventCount.map(String.init) ?? "-",
                    ]
                )
            },
            eventHandler: handler
        )
        let openCode = OpenCodeContinuousSessionWatcher(homeDirectory: homeDirectory, eventHandler: handler)
        let claudeCowork = ClaudeCoworkWatcher(
            discovery: ClaudeCoworkSessionDiscovery(homeDirectory: homeDirectory),
            eventHandler: handler
        )
        codexSessionWatcher = codex
        openCodeContinuousSessionWatcher = openCode
        claudeCoworkWatcher = claudeCowork
        lock.unlock()

        codex.start()
        openCode.start()
        claudeCowork.start()
    }

    public func startLocalSessionWatchers(homeDirectory: URL? = nil) {
        start(homeDirectory: homeDirectory ?? localWatcherHomeDirectory)
    }

    private func persistSessionState(updateTerminalSessionMap: Bool) {
        if let sessionStore {
            sessionCoordinator.save(to: sessionStore)
        }
        guard updateTerminalSessionMap else { return }

        let mapURL = AppRuntimeSessionStore.defaultDirectory(homeDirectory: localWatcherHomeDirectory)
            .appendingPathComponent("session-terminals.json")
        _ = try? CodexTerminalSessionMapWriter().write(
            sessions: sessionCoordinator.snapshots(),
            to: mapURL
        )
    }

    public func status() -> AppRuntimeStatus {
        lock.lock()
        let isBridgeRunning = bridgeServer != nil
        let openCodeSyncDiagnostics = openCodeSyncDiagnostics
        lock.unlock()

        return AppRuntimeStatus(
            socketPath: socketPath,
            isBridgeRunning: isBridgeRunning,
            sessionCount: sessionCoordinator.snapshots().count,
            sessionStoreDiagnostics: (sessionStore as? SessionStoreDiagnosticsProviding)?.diagnostics(),
            openCodeSyncDiagnostics: openCodeSyncDiagnostics
        )
    }

    public func sessionSnapshot(sessionId: String) -> SessionState? {
        sessionCoordinator.snapshot(sessionId: sessionId)
    }

    public func runtimeSessionSnapshots() -> [RuntimeSessionSnapshot] {
        let activeSessionId = sessionStoreIndexes().activeSessionId
        return sessionCoordinator.sessionSnapshots().map { snapshot in
            RuntimeSessionSnapshot(
                snapshot: snapshot,
                isActive: snapshot.sessionId == activeSessionId
            )
        }
    }

    public func activeRuntimeSessionSnapshot() -> RuntimeSessionSnapshot? {
        runtimeSessionSnapshots().first(where: \.isActive)
    }

    public func actionableRequests() -> [RuntimeActionableRequest] {
        let selections = sessionStoreIndexes().questionSelections
        return sessionCoordinator.actionableRequests().map { request in
            RuntimeActionableRequest(
                request: request,
                storedSelection: selections[request.requestId]
            )
        }
    }

    public func actionableRequest(requestId: String) -> RuntimeActionableRequest? {
        actionableRequests().first { $0.request.requestId == requestId }
    }

    public func jumpToSession(sessionId: String) -> JumpActionPlan {
        let router = ActionRouter(sessionCoordinator: sessionCoordinator)
        if let sessionStore,
           let liveCodexSession = activeCodexSessions(sessionStore)?.first(where: { $0.sessionId == sessionId }) {
            let enriched = liveCodexSession.jumpInput.map(jumpInputEnricher) ?? liveCodexSession.jumpInput
            let target = enriched.map { liveCodexSession.replacingJumpInput($0) } ?? liveCodexSession
            return router.jumpToSession(state: target)
        }

        // Stored/coordinator sessions must use the same click-time target
        // enrichment as the live Codex path. Otherwise a Kanban tmux session
        // falls back to stale tmux automation instead of its current ttyd URL.
        if let state = sessionCoordinator.snapshot(sessionId: sessionId),
           let jumpInput = state.jumpInput {
            let enriched = jumpInputEnricher(jumpInput)
            return router.jumpToSession(state: state.replacingJumpInput(enriched))
        }

        return router.jumpToSession(sessionId: sessionId)
    }

    public func executeJumpToSession(
        sessionId: String,
        mode: TerminalJumpExecutionMode = .dryRun
    ) -> TerminalJumpExecutionResult {
        TerminalJumpExecutor(runner: jumpRunner).execute(plan: jumpToSession(sessionId: sessionId), mode: mode)
    }

    @discardableResult
    public func syncOpenCodeDiskSessions(rootURL: URL) -> [OpenCodeDiskSessionScanResult] {
        let results = OpenCodeDiskSessionWatcher(rootURL: rootURL).scan()
        let events = results.flatMap { result in
            result.snapshot?.agentEvents() ?? []
        }
        events.forEach { sessionCoordinator.apply($0) }
        if !events.isEmpty, let sessionStore {
            sessionCoordinator.save(to: sessionStore)
        }
        if !events.isEmpty {
            publishSessionPreviews()
        }
        let diagnostics = OpenCodeSyncDiagnostics(
            rootPath: rootURL.path,
            attemptedFileCount: results.count,
            successfulSnapshotCount: results.filter { $0.snapshot != nil }.count,
            failedSnapshotCount: results.filter { $0.snapshot == nil }.count,
            emittedEventCount: events.count,
            rootMissing: !FileManager.default.fileExists(atPath: rootURL.path)
        )
        lock.lock()
        openCodeSyncDiagnostics = diagnostics
        lock.unlock()
        return results
    }

    @discardableResult
    public func resolveAction(_ resolution: ActionResolution) -> Bool {
        let actionableRequest = sessionCoordinator.actionableRequests().first {
            $0.requestId == resolution.requestId && $0.sessionId == resolution.sessionId
        }
        let resolved = sessionCoordinator.resolveAction(resolution)
        guard resolved else {
            return false
        }

        if let sessionStore {
            sessionCoordinator.save(to: sessionStore)
        }
        if let selection = resolution.selection, !selection.isEmpty {
            sessionStore?.setQuestionSelection(selection, forRequestId: resolution.requestId)
        }
        publishSessionPreviews()

        if let actionableRequest {
            switch AgentAdapterRegistry.default.directive(for: actionableRequest, resolution: resolution) {
            case .none:
                blockingActionContinuations?.expire(
                    sessionId: resolution.sessionId,
                    requestId: resolution.requestId
                )
            case let .json(directive):
                blockingActionContinuations?.resolve(
                    sessionId: resolution.sessionId,
                    requestId: resolution.requestId,
                    directive: directive
                )
            }
        }

        return true
    }

    public func sessionStoreIndexes() -> SessionStoreIndexes {
        guard let sessionStore else {
            return SessionStoreIndexes()
        }

        return SessionStoreIndexes(snapshot: sessionStore.loadSnapshot())
    }

    public func setActiveSessionId(_ sessionId: String?) {
        sessionStore?.setActiveSessionId(sessionId)
    }

    public func markSessionSummarized(sessionId: String) {
        sessionStore?.markSummarized(sessionId: sessionId)
    }

    public func setQuestionSelection(_ selection: String, forRequestId requestId: String) {
        sessionStore?.setQuestionSelection(selection, forRequestId: requestId)
    }

    public func questionSelection(forRequestId requestId: String) -> String? {
        sessionStoreIndexes().questionSelections[requestId]
    }
}
