import AppKit
import MyVibeIslandCore

@MainActor
public struct MyVibeIslandAppKitIslandSurfaceViewFactory {
    private let performAction: @MainActor (ActionResolution) -> Void

    public init(
        performAction: @escaping @MainActor (ActionResolution) -> Void = { _ in }
    ) {
        self.performAction = performAction
    }

    public func makeView(
        from descriptor: MyVibeIslandAppKitIslandSurfaceDescriptor
    ) -> NSView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.surface")
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.clear.cgColor
        stack.setAccessibilityElement(descriptor.isVisible)
        stack.setAccessibilityRole(.group)
        stack.setAccessibilityLabel("My Vibe Island surface")
        stack.setAccessibilityValue(surfaceAccessibilityValue(for: descriptor))
        pinIntrinsicSizePriorities(for: stack)
        stack.frame = NSRect(
            x: 0,
            y: 0,
            width: descriptor.contentSize.width,
            height: descriptor.contentSize.height
        )
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: descriptor.contentSize.width),
            stack.heightAnchor.constraint(equalToConstant: descriptor.contentSize.height)
        ])
        stack.isHidden = !descriptor.isVisible

        for item in descriptor.items {
            stack.addArrangedSubview(makeSectionView(for: item))
        }

        return stack
    }

    private func makeSectionView(
        for item: MyVibeIslandAppKitIslandSurfaceItemDescriptor
    ) -> NSStackView {
        let section = NSStackView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.orientation = sectionOrientation(for: item.section)
        section.alignment = sectionAlignment(for: item.section)
        let metrics = sectionLayoutMetrics(for: item.style)
        section.spacing = metrics.spacing
        section.edgeInsets = metrics.edgeInsets
        pinIntrinsicSizePriorities(for: section)
        let sectionIdentifierToken = sectionIdentifierToken(for: item)
        section.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.surface.section.\(sectionIdentifierToken)")
        section.setAccessibilityElement(true)
        section.setAccessibilityRole(.group)
        section.setAccessibilityLabel(item.accessibilityLabel)
        section.setAccessibilityValue(accessibilityValue(for: item))
        let interactionHelp = toolTip(for: item.interactionHint)
        section.setAccessibilityHelp(interactionHelp)
        section.setAccessibilityEnabled(item.isInteractive)
        section.toolTip = interactionHelp
        section.wantsLayer = true
        section.layer?.cornerRadius = metrics.cornerRadius
        section.layer?.cornerCurve = .continuous
        section.layer?.borderWidth = 1
        section.layer?.backgroundColor = sectionBackgroundColor(for: item.style).cgColor
        section.layer?.borderColor = sectionBorderColor(for: item.style).cgColor
        let shadow = sectionShadowMetrics(for: item.style)
        section.layer?.shadowOpacity = shadow.opacity
        section.layer?.shadowRadius = shadow.radius
        section.layer?.shadowOffset = shadow.offset
        section.layer?.shadowColor = shadow.color

        let title = makeLabel(
            item.accessibilityLabel,
            identifier: "my-vibe-island.surface.section.\(sectionIdentifierToken).title",
            isEnabled: item.isInteractive,
            font: .boldSystemFont(ofSize: NSFont.systemFontSize),
            textColor: titleTextColor(for: item.style)
        )
        section.addArrangedSubview(title)

        if let secondaryLabel = item.secondaryLabel {
            let sessions = makeLabel(
                secondaryLabel,
                identifier: "my-vibe-island.surface.section.\(sectionIdentifierToken).sessions",
                isEnabled: item.isInteractive,
                font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                textColor: supplementaryTextColor(for: item.style)
            )
            section.addArrangedSubview(sessions)
        }

        if let detailLabel = item.detailLabel {
            let detail = makeLabel(
                detailLabel,
                identifier: "my-vibe-island.surface.section.\(sectionIdentifierToken).detail",
                isEnabled: item.isInteractive,
                font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                textColor: supplementaryTextColor(for: item.style)
            )
            section.addArrangedSubview(detail)
        }

        if !item.sessionBadges.isEmpty {
            section.addArrangedSubview(makeBadgeStack(for: item))
        }

        if !item.actionRequestPreviews.isEmpty {
            section.addArrangedSubview(makeActionRequestStack(item.actionRequestPreviews))
        }

        return section
    }

    private func makeActionRequestStack(
        _ requests: [ActionRequestPreview]
    ) -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.action-requests")

        let localPermissions = requests.filter {
            $0.kind == .permission && $0.canResolveLocally
        }
        if localPermissions.count > 1 {
            stack.addArrangedSubview(makePermissionQueueControls(localPermissions))
        }

        for request in requests {
            stack.addArrangedSubview(makeActionRequestCard(request))
        }
        return stack
    }

    private func makePermissionQueueControls(
        _ requests: [ActionRequestPreview]
    ) -> NSStackView {
        let controls = NSStackView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6
        controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
            title: "Allow All",
            identifier: "my-vibe-island.action-requests.allow-all"
        ) {
            for request in requests {
                performAction(ActionResolution(
                    requestId: request.requestId,
                    sessionId: request.sessionId,
                    kind: .approve
                ))
            }
        })
        controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
            title: "Deny All",
            identifier: "my-vibe-island.action-requests.deny-all"
        ) {
            for request in requests {
                performAction(ActionResolution(
                    requestId: request.requestId,
                    sessionId: request.sessionId,
                    kind: .deny
                ))
            }
        })
        return controls
    }

    private func makeActionRequestCard(_ request: ActionRequestPreview) -> NSStackView {
        let requestToken = Self.identifierToken(for: request.requestId)
        let card = NSStackView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.orientation = .vertical
        card.alignment = .leading
        card.spacing = 4
        card.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.action.\(requestToken)")

        let title = request.toolName.isEmpty
            ? (request.kind == .permission ? "Permission request" : "Question")
            : request.toolName
        card.addArrangedSubview(makeLabel(
            title,
            identifier: "my-vibe-island.action.\(requestToken).title",
            isEnabled: true,
            font: .boldSystemFont(ofSize: NSFont.systemFontSize)
        ))
        if let prompt = request.prompt {
            card.addArrangedSubview(makeLabel(
                prompt,
                identifier: "my-vibe-island.action.\(requestToken).prompt",
                isEnabled: true
            ))
        }

        if !request.canResolveLocally {
            let fallback = request.kind == .permission
                ? "Please approve in the terminal"
                : "Please answer in the terminal"
            card.addArrangedSubview(makeLabel(
                fallback,
                identifier: "my-vibe-island.action.\(requestToken).answer-in-terminal",
                isEnabled: false,
                textColor: .secondaryLabelColor
            ))
        } else if request.kind == .permission {
            card.addArrangedSubview(makePermissionControls(request, requestToken: requestToken))
        } else if !request.questions.isEmpty {
            card.addArrangedSubview(MyVibeIslandAppKitQuestionWizardView(
                request: request,
                requestToken: requestToken,
                performAction: performAction
            ))
        } else {
            card.addArrangedSubview(makeQuestionControls(request, requestToken: requestToken))
        }
        return card
    }

    private func makePermissionControls(
        _ request: ActionRequestPreview,
        requestToken: String
    ) -> NSStackView {
        let controls = NSStackView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 6
        controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
            title: "Allow once",
            identifier: "my-vibe-island.action.\(requestToken).allow-once"
        ) {
            performAction(ActionResolution(
                requestId: request.requestId,
                sessionId: request.sessionId,
                kind: .approve
            ))
        })
        if request.supportsPersistentApproval {
            controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
                title: "Always allow",
                identifier: "my-vibe-island.action.\(requestToken).always-allow"
            ) {
                performAction(ActionResolution(
                    requestId: request.requestId,
                    sessionId: request.sessionId,
                    kind: .approveAlways
                ))
            })
        }
        controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
            title: "Deny",
            identifier: "my-vibe-island.action.\(requestToken).deny"
        ) {
            performAction(ActionResolution(
                requestId: request.requestId,
                sessionId: request.sessionId,
                kind: .deny
            ))
        })
        return controls
    }

    private func makeQuestionControls(
        _ request: ActionRequestPreview,
        requestToken: String
    ) -> NSStackView {
        let controls = NSStackView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 4

        var optionButtons: [NSButton] = []
        for option in request.options {
            let optionToken = Self.identifierToken(for: option.id)
            let button = MyVibeIslandAppKitActionButton(
                title: option.label,
                identifier: "my-vibe-island.action.\(requestToken).option.\(optionToken)",
                buttonType: request.allowsMultipleSelection ? .switch : .radio
            ) {}
            button.toolTip = option.detail ?? option.label
            optionButtons.append(button)
            controls.addArrangedSubview(button)
        }

        controls.addArrangedSubview(MyVibeIslandAppKitActionButton(
            title: "Submit",
            identifier: "my-vibe-island.action.\(requestToken).submit"
        ) {
            let selections = zip(request.options, optionButtons)
                .filter { $0.1.state == .on }
                .map { $0.0.label }
            guard !selections.isEmpty else {
                return
            }
            performAction(ActionResolution(
                requestId: request.requestId,
                sessionId: request.sessionId,
                kind: .answer,
                selection: selections.joined(separator: ", ")
            ))
        })
        return controls
    }

    private func sectionOrientation(for section: IslandSurfaceSection) -> NSUserInterfaceLayoutOrientation {
        isPillSection(section) ? .horizontal : .vertical
    }

    private func sectionAlignment(for section: IslandSurfaceSection) -> NSLayoutConstraint.Attribute {
        isPillSection(section) ? .centerY : .leading
    }

    private func isPillSection(_ section: IslandSurfaceSection) -> Bool {
        section == .compactPill || section == .updatePill
    }

    private func makeBadgeStack(
        for item: MyVibeIslandAppKitIslandSurfaceItemDescriptor
    ) -> NSStackView {
        let sectionIdentifierToken = sectionIdentifierToken(for: item)
        let badges = NSStackView()
        badges.translatesAutoresizingMaskIntoConstraints = false
        badges.orientation = .horizontal
        badges.alignment = .centerY
        badges.spacing = 3
        pinIntrinsicSizePriorities(for: badges)
        badges.identifier = NSUserInterfaceItemIdentifier("my-vibe-island.surface.section.\(sectionIdentifierToken).badges")
        badges.setAccessibilityElement(true)
        badges.setAccessibilityRole(.group)
        badges.setAccessibilityLabel("\(item.accessibilityLabel) session badges")
        let badgeList = item.sessionBadges.joined(separator: ", ")
        badges.setAccessibilityValue(badgeList)
        badges.setAccessibilityHelp("\(item.accessibilityLabel) session badges: \(badgeList)")
        badges.toolTip = badgeList

        for badge in item.sessionBadges {
            let label = makeLabel(
                badge,
                identifier: "my-vibe-island.surface.section.\(sectionIdentifierToken).badge.\(Self.identifierToken(for: badge))",
                isEnabled: item.isInteractive,
                font: .systemFont(ofSize: NSFont.smallSystemFontSize),
                textColor: supplementaryTextColor(for: item.style)
            )
            label.wantsLayer = true
            label.layer?.cornerRadius = 6
            label.layer?.cornerCurve = .continuous
            label.layer?.borderWidth = 1
            label.layer?.backgroundColor = badgeBackgroundColor(for: item.style).cgColor
            label.layer?.borderColor = badgeBorderColor(for: item.style).cgColor
            badges.addArrangedSubview(label)
        }

        return badges
    }

    private func makeLabel(
        _ value: String,
        identifier: String,
        isEnabled: Bool,
        font: NSFont? = nil,
        textColor: NSColor? = nil
    ) -> NSTextField {
        let label = NSTextField(labelWithString: value)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.identifier = NSUserInterfaceItemIdentifier(identifier)
        label.isEnabled = isEnabled
        label.font = font
        label.textColor = textColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.toolTip = value
        pinIntrinsicSizePriorities(for: label)
        return label
    }

    private func sectionIdentifierToken(
        for item: MyVibeIslandAppKitIslandSurfaceItemDescriptor
    ) -> String {
        item.style.rawValue
    }

    private func sectionLayoutMetrics(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> (spacing: CGFloat, edgeInsets: NSEdgeInsets, cornerRadius: CGFloat) {
        switch style {
        case .compactPill, .updatePill:
            return (
                spacing: 4,
                edgeInsets: NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10),
                cornerRadius: 10
            )
        case .notificationPeek:
            return (
                spacing: 2,
                edgeInsets: NSEdgeInsets(top: 5, left: 8, bottom: 5, right: 8),
                cornerRadius: 7
            )
        case .onboardingGlow, .questionAction:
            return (
                spacing: 3,
                edgeInsets: NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10),
                cornerRadius: 10
            )
        case .expandedPanel, .sessionCard, .switcher, .usageInfo:
            return (
                spacing: 2,
                edgeInsets: NSEdgeInsets(top: 6, left: 8, bottom: 6, right: 8),
                cornerRadius: 8
            )
        }
    }

    private func sectionShadowMetrics(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> (opacity: Float, radius: CGFloat, offset: CGSize, color: CGColor?) {
        switch style {
        case .notificationPeek:
            return (
                opacity: 0.12,
                radius: 4,
                offset: CGSize(width: 0, height: -1),
                color: NSColor.shadowColor.cgColor
            )
        case .updatePill:
            return (
                opacity: 0.16,
                radius: 5,
                offset: CGSize(width: 0, height: -1),
                color: NSColor.shadowColor.cgColor
            )
        case .onboardingGlow, .questionAction:
            return (
                opacity: 0.18,
                radius: 6,
                offset: CGSize(width: 0, height: -2),
                color: NSColor.shadowColor.cgColor
            )
        case .compactPill, .expandedPanel, .sessionCard, .switcher, .usageInfo:
            return (opacity: 0, radius: 0, offset: .zero, color: nil)
        }
    }

    fileprivate static func identifierToken(for value: String) -> String {
        let lowercased = value.lowercased()
        let scalars = lowercased.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }

        return String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }

    private func pinIntrinsicSizePriorities(for view: NSView) {
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func sectionBackgroundColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .switcher:
            return .controlBackgroundColor
        case .notificationPeek:
            return .unemphasizedSelectedContentBackgroundColor
        case .usageInfo:
            return .underPageBackgroundColor
        case .updatePill:
            return .findHighlightColor
        case .onboardingGlow:
            return .keyboardFocusIndicatorColor
        case .questionAction:
            return .selectedControlColor
        }
    }

    private func sectionBorderColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .switcher:
            return .separatorColor
        case .notificationPeek:
            return .selectedContentBackgroundColor
        case .usageInfo:
            return .gridColor
        case .updatePill:
            return .systemYellow
        case .onboardingGlow:
            return .keyboardFocusIndicatorColor
        case .questionAction:
            return .controlAccentColor
        }
    }

    private func badgeBackgroundColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .switcher:
            return .windowBackgroundColor
        case .notificationPeek:
            return .unemphasizedSelectedContentBackgroundColor
        case .usageInfo:
            return .underPageBackgroundColor
        case .updatePill:
            return .findHighlightColor
        case .onboardingGlow:
            return .keyboardFocusIndicatorColor
        case .questionAction:
            return .selectedControlColor
        }
    }

    private func badgeBorderColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .switcher:
            return .separatorColor
        case .notificationPeek:
            return .selectedContentBackgroundColor
        case .usageInfo:
            return .gridColor
        case .updatePill:
            return .systemYellow
        case .onboardingGlow:
            return .keyboardFocusIndicatorColor
        case .questionAction:
            return .controlAccentColor
        }
    }

    private func titleTextColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .notificationPeek, .usageInfo, .switcher:
            return .labelColor
        case .updatePill:
            return .controlTextColor
        case .onboardingGlow, .questionAction:
            return .alternateSelectedControlTextColor
        }
    }

    private func supplementaryTextColor(
        for style: MyVibeIslandAppKitIslandSurfaceItemStyle
    ) -> NSColor {
        switch style {
        case .compactPill, .expandedPanel, .sessionCard, .notificationPeek, .usageInfo, .switcher:
            return .secondaryLabelColor
        case .updatePill:
            return .controlTextColor
        case .onboardingGlow, .questionAction:
            return .alternateSelectedControlTextColor
        }
    }

    private func accessibilityValue(
        for item: MyVibeIslandAppKitIslandSurfaceItemDescriptor
    ) -> String? {
        var parts = [String]()

        if let secondaryLabel = item.secondaryLabel {
            parts.append(secondaryLabel)
        }

        if let detailLabel = item.detailLabel {
            parts.append(detailLabel)
        }

        if !item.sessionBadges.isEmpty {
            parts.append("Sessions: \(item.sessionBadges.joined(separator: ", "))")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private func surfaceAccessibilityValue(
        for descriptor: MyVibeIslandAppKitIslandSurfaceDescriptor
    ) -> String {
        descriptor.items.count == 1
            ? "1 section"
            : "\(descriptor.items.count) sections"
    }

    private func toolTip(for hint: IslandSurfaceInteractionHint) -> String? {
        switch hint {
        case .none:
            return nil
        case .toggleExpandedPanel:
            return "Toggle expanded panel"
        case .openFocusedSession:
            return "Open focused session"
        case .openNotificationSession:
            return "Open notification session"
        case .openUpdateWindow:
            return "Open update window"
        case .switchFocusedSession:
            return "Switch focused session"
        case .answerQuestion:
            return "Answer question"
        }
    }
}

@MainActor
private final class MyVibeIslandAppKitActionButton: NSButton {
    private let handler: @MainActor () -> Void

    init(
        title: String,
        identifier: String,
        buttonType: NSButton.ButtonType = .momentaryPushIn,
        handler: @escaping @MainActor () -> Void
    ) {
        self.handler = handler
        super.init(frame: .zero)
        self.title = title
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setButtonType(buttonType)
        bezelStyle = .rounded
        target = self
        action = #selector(performAction)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func performAction() {
        handler()
    }
}

@MainActor
private final class MyVibeIslandAppKitQuestionWizardView: NSStackView {
    private let request: ActionRequestPreview
    private let requestToken: String
    private let performAction: @MainActor (ActionResolution) -> Void
    private var currentQuestionIndex = 0
    private var selections: [String: [String]] = [:]

    init(
        request: ActionRequestPreview,
        requestToken: String,
        performAction: @escaping @MainActor (ActionResolution) -> Void
    ) {
        self.request = request
        self.requestToken = requestToken
        self.performAction = performAction
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        orientation = .vertical
        alignment = .leading
        spacing = 4
        identifier = NSUserInterfaceItemIdentifier("my-vibe-island.action.\(requestToken).wizard")
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func render() {
        for view in arrangedSubviews {
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let question = request.questions[currentQuestionIndex]
        let header = NSTextField(labelWithString: question.header)
        header.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        addArrangedSubview(header)

        let prompt = NSTextField(labelWithString: question.prompt)
        prompt.identifier = NSUserInterfaceItemIdentifier(
            "my-vibe-island.action.\(requestToken).wizard.question"
        )
        addArrangedSubview(prompt)

        for option in question.options {
            let optionToken = MyVibeIslandAppKitIslandSurfaceViewFactory.identifierToken(for: option.id)
            let button = MyVibeIslandAppKitActionButton(
                title: option.label,
                identifier: "my-vibe-island.action.\(requestToken).wizard.option.\(optionToken)",
                buttonType: question.allowsMultipleSelection ? .switch : .radio
            ) { [weak self] in
                self?.select(option.label, for: question)
            }
            button.state = selections[question.header, default: []].contains(option.label)
                ? NSControl.StateValue.on
                : NSControl.StateValue.off
            button.toolTip = option.detail ?? option.label
            addArrangedSubview(button)
        }

        let navigation = NSStackView()
        navigation.orientation = .horizontal
        navigation.alignment = .centerY
        navigation.spacing = 6
        if currentQuestionIndex > 0 {
            navigation.addArrangedSubview(MyVibeIslandAppKitActionButton(
                title: "Previous",
                identifier: "my-vibe-island.action.\(requestToken).wizard.previous"
            ) { [weak self] in
                guard let self else { return }
                currentQuestionIndex -= 1
                render()
            })
        }
        if currentQuestionIndex < request.questions.count - 1 {
            navigation.addArrangedSubview(MyVibeIslandAppKitActionButton(
                title: "Next",
                identifier: "my-vibe-island.action.\(requestToken).wizard.next"
            ) { [weak self] in
                guard let self,
                      !selections[question.header, default: []].isEmpty else { return }
                currentQuestionIndex += 1
                render()
            })
        } else {
            let submit = MyVibeIslandAppKitActionButton(
                title: "Submit",
                identifier: "my-vibe-island.action.\(requestToken).wizard.submit"
            ) { [weak self] in
                self?.submit()
            }
            submit.isEnabled = request.questions.allSatisfy {
                !selections[$0.header, default: []].isEmpty
            }
            navigation.addArrangedSubview(submit)
        }
        addArrangedSubview(navigation)
    }

    private func select(_ label: String, for question: ActionRequestQuestion) {
        if question.allowsMultipleSelection {
            var selected = selections[question.header, default: []]
            if let index = selected.firstIndex(of: label) {
                selected.remove(at: index)
            } else {
                selected.append(label)
            }
            selections[question.header] = selected
        } else {
            selections[question.header] = [label]
        }
        render()
    }

    private func submit() {
        guard request.questions.allSatisfy({
            !selections[$0.header, default: []].isEmpty
        }) else { return }
        performAction(ActionResolution(
            requestId: request.requestId,
            sessionId: request.sessionId,
            kind: .answer,
            answers: Dictionary(uniqueKeysWithValues: request.questions.map {
                ($0.header, selections[$0.header, default: []].joined(separator: ", "))
            })
        ))
    }
}
