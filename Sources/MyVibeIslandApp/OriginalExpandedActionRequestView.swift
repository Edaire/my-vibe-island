import Foundation
import MyVibeIslandCore
import SwiftUI

enum OriginalExpandedActionRequestResolution {
    static func kind(for kind: ActionResolutionKind, request: ActionRequestPreview) -> ActionResolutionKind {
        kind == .approveAlways && !request.supportsPersistentApproval ? .approve : kind
    }
}

struct OriginalExpandedActionRequestState: Equatable {
    enum SubmissionState: Equatable { case ready, timedOut, submissionFailed, submitted }

    struct PersistedSelection: Equatable {
        let answers: [String: [String]]
        let topLevelSelection: [String]

        init(answers: [String: [String]] = [:], topLevelSelection: [String] = []) {
            self.answers = answers
            self.topLevelSelection = topLevelSelection
        }
    }

    let requestID: String
    var questionIDs: [String]
    let timeoutReferenceDate: Date
    var currentQuestionIndex: Int
    var answers: [String: [String]]
    var topLevelSelection: [String]
    var submissionState: SubmissionState

    var canInteract: Bool {
        submissionState == .ready || submissionState == .submissionFailed
    }

    static func transition(
        from currentState: Self?,
        to request: ActionRequestPreview,
        persistedSelection: PersistedSelection,
        observedAt: Date
    ) -> Self {
        let questionIDs = request.questions.map(\.id)
        guard let currentState, currentState.requestID == request.requestId else {
            return Self(
                requestID: request.requestId,
                questionIDs: questionIDs,
                timeoutReferenceDate: request.actionableRequestLifecycleTimestamp ?? observedAt,
                currentQuestionIndex: 0,
                answers: persistedSelection.answers.filter { questionIDs.contains($0.key) },
                topLevelSelection: persistedSelection.topLevelSelection,
                submissionState: .ready
            )
        }

        var next = currentState
        next.currentQuestionIndex = min(currentState.currentQuestionIndex, max(questionIDs.count - 1, 0))
        next.questionIDs = questionIDs
        next.answers = currentState.answers.filter { questionIDs.contains($0.key) }
        for questionID in questionIDs where next.answers[questionID] == nil {
            if let persisted = persistedSelection.answers[questionID] {
                next.answers[questionID] = persisted
            }
        }
        if currentState.topLevelSelection.isEmpty {
            next.topLevelSelection = persistedSelection.topLevelSelection
        }
        return next
    }

    func recording(answer: String, forQuestionID questionID: String) -> Self {
        selectingAnswer(answer, forQuestionID: questionID, allowsMultipleSelection: false)
    }

    func selectingAnswer(
        _ optionID: String,
        forQuestionID questionID: String,
        allowsMultipleSelection: Bool
    ) -> Self {
        guard canInteract else { return self }
        var next = self
        next.answers[questionID] = updatedSelection(
            current: next.answers[questionID] ?? [],
            optionID: optionID,
            allowsMultipleSelection: allowsMultipleSelection
        )
        next.submissionState = .ready
        return next
    }

    func recording(topLevelSelection: String) -> Self {
        selectingTopLevelOption(topLevelSelection, allowsMultipleSelection: false)
    }

    func selectingTopLevelOption(_ optionID: String, allowsMultipleSelection: Bool) -> Self {
        guard canInteract else { return self }
        var next = self
        next.topLevelSelection = updatedSelection(
            current: next.topLevelSelection,
            optionID: optionID,
            allowsMultipleSelection: allowsMultipleSelection
        )
        next.submissionState = .ready
        return next
    }

    private func updatedSelection(current: [String], optionID: String, allowsMultipleSelection: Bool) -> [String] {
        guard allowsMultipleSelection else { return [optionID] }
        return current.contains(optionID)
            ? current.filter { $0 != optionID }
            : current + [optionID]
    }

    func advancing() -> Self {
        guard canInteract else { return self }
        var next = self
        next.currentQuestionIndex = min(currentQuestionIndex + 1, max(questionIDs.count - 1, 0))
        return next
    }

    func retreating() -> Self {
        guard canInteract else { return self }
        var next = self
        next.currentQuestionIndex = max(currentQuestionIndex - 1, 0)
        return next
    }

    func timingOut(now: Date, timeout: TimeInterval) -> Self {
        guard now.timeIntervalSince(timeoutReferenceDate) >= timeout,
              submissionState == .ready
        else { return self }
        return withSubmissionState(.timedOut)
    }

    func withSubmissionState(_ state: SubmissionState) -> Self {
        var next = self
        next.submissionState = state
        return next
    }

    func withSubmissionResult(_ succeeded: Bool) -> Self {
        guard canInteract else { return self }
        return withSubmissionState(succeeded ? .submitted : .submissionFailed)
    }

}

struct OriginalExpandedActionRequestControlDescriptor: Equatable {
    let canInteract: Bool

    static func resolve(for state: OriginalExpandedActionRequestState) -> Self {
        Self(canInteract: state.canInteract)
    }
}

extension OriginalExpandedActionRequestResolution {
    static func answer(
        for request: ActionRequestPreview,
        state: OriginalExpandedActionRequestState
    ) -> ActionResolution? {
        guard request.requestId == state.requestID else { return nil }
        let topLevelLabels = request.options
            .filter { state.topLevelSelection.contains($0.id) }
            .map(\.label)
        let answers = request.questions.reduce(into: [String: String]()) { result, question in
            let labels = state.answers[question.id, default: []].compactMap { selectedID in
                question.options.first { $0.id == selectedID }?.label
            }
            if !labels.isEmpty {
                result[question.header] = labels.joined(separator: ", ")
            }
        }
        return ActionResolution(
            requestId: request.requestId,
            sessionId: request.sessionId,
            kind: .answer,
            selection: topLevelLabels.isEmpty ? nil : topLevelLabels.joined(separator: ", "),
            answers: answers.isEmpty ? nil : answers
        )
    }
}

struct OriginalExpandedActionRequestCollectionState: Equatable {
    private(set) var requestIDs: [String]
    private(set) var selectedRequestID: String?

    init(requestIDs: [String]) {
        self.requestIDs = Self.unique(requestIDs)
        selectedRequestID = self.requestIDs.first
    }

    func replacingRequestIDs(_ requestIDs: [String]) -> Self {
        let uniqueIDs = Self.unique(requestIDs)
        var next = Self(requestIDs: uniqueIDs)
        if let selectedRequestID, uniqueIDs.contains(selectedRequestID) {
            next.selectedRequestID = selectedRequestID
        }
        return next
    }

    func selecting(_ requestID: String) -> Self {
        guard requestIDs.contains(requestID) else { return self }
        var next = self
        next.selectedRequestID = requestID
        return next
    }

    private static func unique(_ requestIDs: [String]) -> [String] {
        var seen = Set<String>()
        return requestIDs.filter { seen.insert($0).inserted }
    }
}

final class OriginalExpandedActionSelectionStore {
    private var values: [String: Data] = [:]
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
    }

    func topLevelSelections(forRequestID requestID: String) -> [String] {
        value(forKey: Self.topLevelKey(requestID))
    }

    func questionAnswers(forRequestID requestID: String, questionID: String) -> [String] {
        value(forKey: Self.questionKey(requestID, questionID))
    }

    func recordingTopLevelSelection(_ selection: [String], requestID: String) -> Self {
        record(selection, forKey: Self.topLevelKey(requestID))
        return self
    }

    func recordingQuestionAnswers(_ answers: [String], requestID: String, questionID: String) -> Self {
        record(answers, forKey: Self.questionKey(requestID, questionID))
        return self
    }

    static func topLevelKey(_ requestID: String) -> String {
        "expanded.action.v2.topLevel.\(encodedComponent(requestID))"
    }

    static func questionKey(_ requestID: String, _ questionID: String) -> String {
        "expanded.action.v2.question.\(encodedComponent(requestID)).\(encodedComponent(questionID))"
    }

    private func value(forKey key: String) -> [String] {
        let data = values[key] ?? defaults?.data(forKey: key)
        if let data, let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        if let legacyV2Value = defaults?.string(forKey: key) {
            return [legacyV2Value]
        }
        return []
    }

    private func record(_ value: [String], forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        values[key] = data
        defaults?.set(data, forKey: key)
    }

    private static func encodedComponent(_ value: String) -> String {
        Data(value.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct OriginalExpandedActionRequestIdentity: Equatable {
    let requestID: String
    let questionIDs: [String]
}

struct OriginalExpandedActionRequestView: View {
    let request: ActionRequestPreview
    let onSubmit: (ActionResolution) -> Bool
    let timeout: TimeInterval
    private let selectionStore: OriginalExpandedActionSelectionStore
    @State private var state: OriginalExpandedActionRequestState

    init(
        request: ActionRequestPreview,
        onSubmit: @escaping (ActionResolution) -> Bool,
        timeout: TimeInterval = 3_600,
        selectionStore: OriginalExpandedActionSelectionStore = OriginalExpandedActionSelectionStore(defaults: .standard)
    ) {
        self.request = request
        self.onSubmit = onSubmit
        self.timeout = timeout
        self.selectionStore = selectionStore
        _state = State(initialValue: Self.initialState(for: request, selectionStore: selectionStore))
    }

    var body: some View {
        let controlDescriptor = OriginalExpandedActionRequestControlDescriptor.resolve(for: state)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: request.kind == .permission ? "hand.raised.fill" : "questionmark.circle.fill")
                Text(request.toolName).font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
                Button { submit(.dismiss) } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .disabled(!controlDescriptor.canInteract)
                    .help("Dismiss request")
            }
            if let prompt = request.prompt {
                Text(prompt).font(.system(size: 11)).foregroundStyle(Color.white.opacity(0.78)).lineLimit(3)
            }
            if request.kind == .permission { permissionControls }
            else if request.questions.isEmpty { optionControls }
            else { questionControls }
            if let statusMessage {
                Text(statusMessage).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.orange.opacity(0.9))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: requestIdentity, initial: true) { _, identity in
            state = OriginalExpandedActionRequestState.transition(
                from: state,
                to: request,
                persistedSelection: .init(
                    answers: Self.persistedAnswers(for: request, selectionStore: selectionStore),
                    topLevelSelection: selectionStore.topLevelSelections(forRequestID: identity.requestID)
                ),
                observedAt: Date()
            )
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            state = state.timingOut(now: now, timeout: timeout)
        }
    }

    private var permissionControls: some View {
        HStack(spacing: 8) {
            actionButton("Approve", kind: .approve)
            if request.supportsPersistentApproval { actionButton("Update Rules", kind: .approveAlways) }
            actionButton("Deny", kind: .deny)
        }
    }

    private var optionControls: some View {
        HStack(spacing: 6) {
            ForEach(request.options, id: \.id) { option in
                Button(option.label) {
                    state = state.selectingTopLevelOption(
                        option.id,
                        allowsMultipleSelection: request.allowsMultipleSelection
                    )
                    _ = selectionStore.recordingTopLevelSelection(
                        state.topLevelSelection,
                        requestID: request.requestId
                    )
                }
                    .buttonStyle(.plain)
                    .disabled(!state.canInteract)
                    .opacity(state.topLevelSelection.contains(option.id) ? 1 : 0.78)
            }
            Button("Submit") { submit(.answer) }
                .buttonStyle(.plain)
                .disabled(!state.canInteract || state.topLevelSelection.isEmpty)
        }
    }

    private var questionControls: some View {
        guard let question = currentQuestion else { return AnyView(EmptyView()) }
        return AnyView(OriginalExpandedQuestionView(
            question: question,
            selectedAnswers: state.answers[question.id] ?? [],
            questionIndex: state.currentQuestionIndex,
            questionCount: request.questions.count,
            canInteract: state.canInteract,
            onSelect: { answer in
                state = state.selectingAnswer(
                    answer,
                    forQuestionID: question.id,
                    allowsMultipleSelection: question.allowsMultipleSelection
                )
                _ = selectionStore.recordingQuestionAnswers(
                    state.answers[question.id] ?? [],
                    requestID: request.requestId,
                    questionID: question.id
                )
            },
            onPrevious: { state = state.retreating() },
            onNext: {
                if state.currentQuestionIndex + 1 < request.questions.count {
                    state = state.advancing()
                } else {
                    submit(.answer)
                }
            }
        ))
    }

    private var currentQuestion: ActionRequestQuestion? {
        guard !request.questions.isEmpty else { return nil }
        let index = min(state.currentQuestionIndex, request.questions.count - 1)
        return request.questions[index]
    }

    private var requestIdentity: OriginalExpandedActionRequestIdentity {
        OriginalExpandedActionRequestIdentity(
            requestID: request.requestId,
            questionIDs: request.questions.map(\.id)
        )
    }

    private func actionButton(_ title: String, kind: ActionResolutionKind) -> some View {
        Button(title) { submit(kind) }
            .buttonStyle(.plain)
            .disabled(!state.canInteract)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }

    private func submit(_ kind: ActionResolutionKind) {
        guard state.canInteract else { return }
        let resolution = kind == .answer
            ? OriginalExpandedActionRequestResolution.answer(for: request, state: state)
            : ActionResolution(
                requestId: request.requestId,
                sessionId: request.sessionId,
                kind: OriginalExpandedActionRequestResolution.kind(for: kind, request: request)
            )
        guard let resolution else { return }
        state = state.withSubmissionResult(onSubmit(resolution))
    }

    private var statusMessage: String? {
        switch state.submissionState {
        case .ready, .submitted: return nil
        case .timedOut: return "Request timed out"
        case .submissionFailed: return "Could not submit request"
        }
    }

    private static func initialState(
        for request: ActionRequestPreview,
        selectionStore: OriginalExpandedActionSelectionStore
    ) -> OriginalExpandedActionRequestState {
        OriginalExpandedActionRequestState.transition(
            from: nil,
            to: request,
            persistedSelection: .init(
                answers: persistedAnswers(for: request, selectionStore: selectionStore),
                topLevelSelection: selectionStore.topLevelSelections(forRequestID: request.requestId)
            ),
            observedAt: Date()
        )
    }

    private static func persistedAnswers(
        for request: ActionRequestPreview,
        selectionStore: OriginalExpandedActionSelectionStore
    ) -> [String: [String]] {
        request.questions.reduce(into: [String: [String]]()) { answers, question in
            let values = selectionStore.questionAnswers(
                forRequestID: request.requestId,
                questionID: question.id
            )
            if !values.isEmpty { answers[question.id] = values }
        }
    }

}
