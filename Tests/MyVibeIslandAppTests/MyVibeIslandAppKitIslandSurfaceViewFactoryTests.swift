import AppKit
import MyVibeIslandCore
import XCTest
@testable import MyVibeIslandApp

final class MyVibeIslandAppKitIslandSurfaceViewFactoryTests: XCTestCase {
    @MainActor
    func testIslandSurfaceViewFactoryMatrixMatchesFixtureSnapshot() throws {
        let expected = try JSONDecoder().decode(
            IslandSurfaceViewFactoryMatrixFixture.self,
            from: try AppFixtureLoader.data("app/island-surface-view-factory-matrix")
        )
        let visible = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 640, height: 420),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .toggleExpandedPanel,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .switcher,
                    accessibilityLabel: "Session switcher",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .switchFocusedSession,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    accessibilityLabel: "Usage information",
                    detailLabel: "Quota resets tomorrow"
                )
            ]
        )
        let hidden = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: false,
            contentSize: DisplaySize(width: 320, height: 180),
            items: []
        )
        let factory = MyVibeIslandAppKitIslandSurfaceViewFactory()
        let actual = IslandSurfaceViewFactoryMatrixFixture(rows: [
            viewSummary(id: "visible-surface", view: factory.makeView(from: visible)),
            viewSummary(id: "hidden-surface", view: factory.makeView(from: hidden))
        ])

        XCTAssertEqual(actual, expected)
    }

    @MainActor
    func testFactoryUsesHorizontalPresentationForPillSections() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 420, height: 160),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sectionStacks = try stack.arrangedSubviews.map { view in
            try XCTUnwrap(view as? NSStackView)
        }
        let sectionOrientations = sectionStacks.map(Self.orientationName)

        XCTAssertEqual(sectionOrientations, ["horizontal", "horizontal", "vertical"])
    }

    @MainActor
    func testFactoryBuildsIslandSurfaceStackWithoutShowingAWindow() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 640, height: 420),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .toggleExpandedPanel,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .switcher,
                    accessibilityLabel: "Session switcher",
                    secondaryLabel: "1 session",
                    sessionBadges: ["active"],
                    sessionIds: ["active"],
                    interactionHint: .switchFocusedSession,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    accessibilityLabel: "Usage information",
                    detailLabel: "Quota resets tomorrow",
                    interactionHint: .none,
                    isInteractive: false
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sectionStacks = try stack.arrangedSubviews.map { view in
            try XCTUnwrap(view as? NSStackView)
        }
        let accessibilityRoles = sectionStacks.map { $0.accessibilityRole() }
        let accessibilityElements = sectionStacks.map { $0.isAccessibilityElement() }
        let sectionOrientations = sectionStacks.map(Self.orientationName)
        let labels = sectionStacks.compactMap { ($0.arrangedSubviews.first as? NSTextField)?.stringValue }
        let identifiers = sectionStacks.compactMap(\.identifier?.rawValue)
        let accessibilityLabels = sectionStacks.map { $0.accessibilityLabel() }
        let accessibilityValues = sectionStacks.map { $0.accessibilityValue() as? String }
        let sectionEdgeInsets = sectionStacks.map { insets in
            [
                insets.edgeInsets.top,
                insets.edgeInsets.left,
                insets.edgeInsets.bottom,
                insets.edgeInsets.right
            ]
        }
        let sectionCornerRadii = sectionStacks.map { $0.layer?.cornerRadius }
        let sectionBorderWidths = sectionStacks.map { $0.layer?.borderWidth }
        let sectionBackgroundColors = sectionStacks.map { $0.layer?.backgroundColor }
        let titleFields = sectionStacks.compactMap { $0.arrangedSubviews.first as? NSTextField }
        let titleIdentifiers = titleFields.compactMap(\.identifier?.rawValue)
        let titleFontTraits = titleFields.compactMap { field in
            field.font.map { NSFontManager.shared.traits(of: $0) }
        }
        let subtitles = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> String? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".sessions") == true else {
                    return nil
                }

                return textField.stringValue
            }.first
        }
        let subtitleFontSizes = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> CGFloat? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".sessions") == true else {
                    return nil
                }

                return textField.font?.pointSize
            }.first ?? nil
        }
        let subtitleTextColors = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> NSColor? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".sessions") == true else {
                    return nil
                }

                return textField.textColor
            }.first ?? nil
        }
        let subtitleIdentifiers = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> String? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".sessions") == true else {
                    return nil
                }

                return textField.identifier?.rawValue
            }.first
        }
        let detailLabels = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> NSTextField? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".detail") == true else {
                    return nil
                }

                return textField
            }.first?.stringValue
        }
        let detailFontSizes = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> CGFloat? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".detail") == true else {
                    return nil
                }

                return textField.font?.pointSize
            }.first ?? nil
        }
        let detailTextColors = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> NSColor? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".detail") == true else {
                    return nil
                }

                return textField.textColor
            }.first ?? nil
        }
        let detailIdentifiers = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { view -> String? in
                guard let textField = view as? NSTextField,
                      textField.identifier?.rawValue.hasSuffix(".detail") == true else {
                    return nil
                }

                return textField.identifier?.rawValue
            }.first
        }
        let badgeStacks = sectionStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { $0 as? NSStackView }.first
        }
        let badgeLabels = badgeStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }.first
        }
        let badgeViews = badgeStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { $0 as? NSTextField }.first
        }
        let badgeFontSizes = badgeViews.compactMap { $0.font?.pointSize }
        let badgeTextColors = badgeViews.map(\.textColor)
        let badgeIdentifiers = badgeStacks.compactMap { stack in
            stack.arrangedSubviews.compactMap { ($0 as? NSTextField)?.identifier?.rawValue }.first
        }
        let badgeBackgroundColors = badgeViews.map { $0.layer?.backgroundColor }
        let badgeStackAccessibilityLabels = badgeStacks.map { $0.accessibilityLabel() }
        let badgeStackAccessibilityValues = badgeStacks.map { $0.accessibilityValue() as? String }
        let toolTips = sectionStacks.compactMap(\.toolTip)

        XCTAssertEqual(view.frame.size.width, 640)
        XCTAssertEqual(view.frame.size.height, 420)
        XCTAssertEqual(view.identifier?.rawValue, "my-vibe-island.surface")
        XCTAssertEqual(view.accessibilityLabel(), "My Vibe Island surface")
        XCTAssertEqual(view.accessibilityValue() as? String, "3 sections")
        XCTAssertEqual(view.accessibilityRole(), .group)
        XCTAssertTrue(view.isAccessibilityElement())
        XCTAssertEqual(view.contentHuggingPriority(for: .horizontal), .required)
        XCTAssertEqual(view.contentHuggingPriority(for: .vertical), .required)
        XCTAssertEqual(view.contentCompressionResistancePriority(for: .horizontal), .required)
        XCTAssertEqual(view.contentCompressionResistancePriority(for: .vertical), .required)
        XCTAssertEqual(stack.orientation, .vertical)
        XCTAssertEqual(labels, ["Compact island", "Session switcher", "Usage information"])
        XCTAssertEqual(identifiers, [
            "my-vibe-island.surface.section.compact-pill",
            "my-vibe-island.surface.section.switcher",
            "my-vibe-island.surface.section.usage-info"
        ])
        XCTAssertEqual(accessibilityRoles, [.group, .group, .group])
        XCTAssertEqual(accessibilityElements, [true, true, true])
        XCTAssertEqual(sectionOrientations, ["horizontal", "vertical", "vertical"])
        XCTAssertEqual(accessibilityLabels, ["Compact island", "Session switcher", "Usage information"])
        XCTAssertEqual(accessibilityValues, [
            "1 session - Sessions: active",
            "1 session - Sessions: active",
            "Quota resets tomorrow"
        ])
        XCTAssertEqual(sectionEdgeInsets, [
            [4, 10, 4, 10],
            [6, 8, 6, 8],
            [6, 8, 6, 8]
        ])
        XCTAssertEqual(sectionStacks.map(\.wantsLayer), [true, true, true])
        XCTAssertEqual(
            sectionStacks.map { $0.contentHuggingPriority(for: .horizontal) },
            Array(repeating: .required, count: 3)
        )
        XCTAssertEqual(
            sectionStacks.map { $0.contentHuggingPriority(for: .vertical) },
            Array(repeating: .required, count: 3)
        )
        XCTAssertEqual(
            sectionStacks.map { $0.contentCompressionResistancePriority(for: .horizontal) },
            Array(repeating: .required, count: 3)
        )
        XCTAssertEqual(
            sectionStacks.map { $0.contentCompressionResistancePriority(for: .vertical) },
            Array(repeating: .required, count: 3)
        )
        XCTAssertEqual(sectionCornerRadii, [10, 8, 8])
        XCTAssertEqual(sectionBorderWidths, [1, 1, 1])
        XCTAssertEqual(sectionBackgroundColors, [
            NSColor.controlBackgroundColor.cgColor,
            NSColor.controlBackgroundColor.cgColor,
            NSColor.underPageBackgroundColor.cgColor
        ])
        XCTAssertEqual(titleIdentifiers, [
            "my-vibe-island.surface.section.compact-pill.title",
            "my-vibe-island.surface.section.switcher.title",
            "my-vibe-island.surface.section.usage-info.title"
        ])
        XCTAssertEqual(titleFontTraits, Array(repeating: .boldFontMask, count: 3))
        XCTAssertEqual(subtitles, ["1 session", "1 session"])
        XCTAssertEqual(subtitleFontSizes, Array(repeating: NSFont.smallSystemFontSize, count: 2))
        XCTAssertEqual(subtitleTextColors, Array(repeating: NSColor.secondaryLabelColor, count: 2))
        XCTAssertEqual(subtitleIdentifiers, [
            "my-vibe-island.surface.section.compact-pill.sessions",
            "my-vibe-island.surface.section.switcher.sessions"
        ])
        XCTAssertEqual(detailLabels, ["Quota resets tomorrow"])
        XCTAssertEqual(detailFontSizes, [NSFont.smallSystemFontSize])
        XCTAssertEqual(detailTextColors, [NSColor.secondaryLabelColor])
        XCTAssertEqual(detailIdentifiers, [
            "my-vibe-island.surface.section.usage-info.detail"
        ])
        XCTAssertEqual(badgeLabels, ["active", "active"])
        XCTAssertEqual(badgeIdentifiers, [
            "my-vibe-island.surface.section.compact-pill.badge.active",
            "my-vibe-island.surface.section.switcher.badge.active"
        ])
        XCTAssertEqual(badgeStackAccessibilityLabels, [
            "Compact island session badges",
            "Session switcher session badges"
        ])
        XCTAssertEqual(badgeStackAccessibilityValues, [
            "active",
            "active"
        ])
        XCTAssertEqual(badgeStacks.map { $0.accessibilityRole() }, [.group, .group])
        XCTAssertEqual(badgeStacks.map { $0.isAccessibilityElement() }, [true, true])
        XCTAssertEqual(
            badgeStacks.map { $0.contentHuggingPriority(for: .horizontal) },
            Array(repeating: .required, count: 2)
        )
        XCTAssertEqual(
            badgeStacks.map { $0.contentHuggingPriority(for: .vertical) },
            Array(repeating: .required, count: 2)
        )
        XCTAssertEqual(
            badgeStacks.map { $0.contentCompressionResistancePriority(for: .horizontal) },
            Array(repeating: .required, count: 2)
        )
        XCTAssertEqual(
            badgeStacks.map { $0.contentCompressionResistancePriority(for: .vertical) },
            Array(repeating: .required, count: 2)
        )
        XCTAssertEqual(badgeFontSizes, Array(repeating: NSFont.smallSystemFontSize, count: 2))
        XCTAssertEqual(badgeTextColors, Array(repeating: NSColor.secondaryLabelColor, count: 2))
        XCTAssertEqual(badgeViews.map(\.wantsLayer), [true, true])
        XCTAssertEqual(badgeViews.map { $0.layer?.cornerRadius }, [6, 6])
        XCTAssertEqual(badgeViews.map { $0.layer?.borderWidth }, [1, 1])
        XCTAssertTrue(badgeBackgroundColors.allSatisfy { color in
            guard let color else {
                return false
            }

            return CFEqual(color, NSColor.windowBackgroundColor.cgColor)
        })
        XCTAssertEqual(toolTips, ["Toggle expanded panel", "Switch focused session"])
    }

    @MainActor
    func testFactoryUsesTailTruncationForSurfaceTextFields() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    detailLabel: "A long detail label that should truncate at the tail",
                    secondaryLabel: "2 sessions",
                    sessionBadges: [
                        "session-with-a-long-identifier",
                        "review-with-a-long-identifier"
                    ],
                    sessionIds: ["session-with-a-long-identifier", "review-with-a-long-identifier"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let directTextFields = section.arrangedSubviews.compactMap { $0 as? NSTextField }
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let badgeTextFields = badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }
        let textFields = directTextFields + badgeTextFields

        XCTAssertEqual(textFields.map(\.lineBreakMode), Array(repeating: .byTruncatingTail, count: 5))
        XCTAssertEqual(textFields.map(\.maximumNumberOfLines), Array(repeating: 1, count: 5))
    }

    @MainActor
    func testFactoryAddsTooltipsToSurfaceTextFields() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    detailLabel: "A long detail label that should remain inspectable",
                    secondaryLabel: "2 sessions",
                    sessionBadges: [
                        "session-with-a-long-identifier",
                        "review-with-a-long-identifier"
                    ],
                    sessionIds: ["session-with-a-long-identifier", "review-with-a-long-identifier"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let directTextFields = section.arrangedSubviews.compactMap { $0 as? NSTextField }
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let badgeTextFields = badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }
        let textFields = directTextFields + badgeTextFields

        XCTAssertEqual(textFields.map(\.toolTip), [
            "Session cards",
            "2 sessions",
            "A long detail label that should remain inspectable",
            "session-with-a-long-identifier",
            "review-with-a-long-identifier"
        ])
    }

    @MainActor
    func testFactoryExposesSectionInteractivityToAccessibility() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island",
                    interactionHint: .toggleExpandedPanel,
                    isInteractive: true
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    accessibilityLabel: "Usage information",
                    interactionHint: .none,
                    isInteractive: false
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    accessibilityLabel: "Question actions",
                    interactionHint: .answerQuestion,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sections = try stack.arrangedSubviews.map { view in
            try XCTUnwrap(view as? NSStackView)
        }

        XCTAssertEqual(sections.map { $0.accessibilityHelp() }, [
            "Toggle expanded panel",
            nil,
            "Answer question"
        ])
        XCTAssertEqual(sections.map { $0.isAccessibilityEnabled() }, [
            true,
            false,
            true
        ])
    }

    @MainActor
    func testFactoryAddsTooltipsAndAccessibilityHelpToBadgeGroups() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    sessionBadges: [
                        "session-with-a-long-identifier",
                        "review-with-a-long-identifier"
                    ],
                    sessionIds: ["session-with-a-long-identifier", "review-with-a-long-identifier"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)

        XCTAssertEqual(
            badgeStack.toolTip,
            "session-with-a-long-identifier, review-with-a-long-identifier"
        )
        XCTAssertEqual(
            badgeStack.accessibilityHelp(),
            "Session cards session badges: session-with-a-long-identifier, review-with-a-long-identifier"
        )
    }

    @MainActor
    func testFactorySanitizesBadgeIdentifiersWithoutChangingBadgeText() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    sessionBadges: [
                        "Session/With Space",
                        "review:blocked#1"
                    ],
                    sessionIds: ["Session/With Space", "review:blocked#1"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let badgeFields = badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }

        XCTAssertEqual(badgeFields.map(\.stringValue), [
            "Session/With Space",
            "review:blocked#1"
        ])
        XCTAssertEqual(badgeFields.compactMap(\.identifier?.rawValue), [
            "my-vibe-island.surface.section.session-card.badge.session-with-space",
            "my-vibe-island.surface.section.session-card.badge.review-blocked-1"
        ])
    }

    @MainActor
    func testFactoryAppliesStyleSpecificSectionBackgrounds() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    style: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    style: .usageInfo,
                    accessibilityLabel: "Usage information"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .onboardingGlow,
                    style: .onboardingGlow,
                    accessibilityLabel: "Onboarding highlight"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sectionBackgrounds = try stack.arrangedSubviews.map { view in
            try XCTUnwrap((view as? NSStackView)?.layer?.backgroundColor)
        }

        XCTAssertEqual(sectionBackgrounds, [
            NSColor.controlBackgroundColor.cgColor,
            NSColor.unemphasizedSelectedContentBackgroundColor.cgColor,
            NSColor.underPageBackgroundColor.cgColor,
            NSColor.findHighlightColor.cgColor,
            NSColor.keyboardFocusIndicatorColor.cgColor,
            NSColor.selectedControlColor.cgColor
        ])
    }

    @MainActor
    func testFactoryAppliesStyleSpecificSectionBorderColors() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    style: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    style: .usageInfo,
                    accessibilityLabel: "Usage information"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .onboardingGlow,
                    style: .onboardingGlow,
                    accessibilityLabel: "Onboarding highlight"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sectionBorders = try stack.arrangedSubviews.map { view in
            try XCTUnwrap((view as? NSStackView)?.layer?.borderColor)
        }

        XCTAssertEqual(sectionBorders, [
            NSColor.separatorColor.cgColor,
            NSColor.selectedContentBackgroundColor.cgColor,
            NSColor.gridColor.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.keyboardFocusIndicatorColor.cgColor,
            NSColor.controlAccentColor.cgColor
        ])
    }

    @MainActor
    func testFactoryAppliesStyleSpecificSectionLayoutMetrics() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    style: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    style: .usageInfo,
                    accessibilityLabel: "Usage information"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .onboardingGlow,
                    style: .onboardingGlow,
                    accessibilityLabel: "Onboarding highlight"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sections = try stack.arrangedSubviews.map { view in
            try XCTUnwrap(view as? NSStackView)
        }

        XCTAssertEqual(sections.map(\.spacing), [4, 2, 2, 4, 3, 3])
        XCTAssertEqual(
            sections.map { [$0.edgeInsets.top, $0.edgeInsets.left, $0.edgeInsets.bottom, $0.edgeInsets.right] },
            [
                [4, 10, 4, 10],
                [5, 8, 5, 8],
                [6, 8, 6, 8],
                [4, 10, 4, 10],
                [8, 10, 8, 10],
                [8, 10, 8, 10]
            ]
        )
        XCTAssertEqual(sections.map { $0.layer?.cornerRadius }, [10, 7, 8, 10, 10, 10])
    }

    @MainActor
    func testFactoryUsesContinuousCornerCurvesForRoundedSurfaceLayers() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    sessionBadges: ["active", "review"],
                    sessionIds: ["active", "review"]
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let badgeFields = badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }

        XCTAssertEqual(section.layer?.cornerCurve, .continuous)
        XCTAssertEqual(
            badgeFields.map { $0.layer?.cornerCurve },
            Array(repeating: .continuous, count: 2)
        )
    }

    @MainActor
    func testFactoryBacksRootSurfaceWithTransparentLayer() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    sessionBadges: ["active", "review"],
                    sessionIds: ["active", "review"]
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)

        XCTAssertTrue(view.wantsLayer)
        XCTAssertEqual(view.layer?.backgroundColor, NSColor.clear.cgColor)
    }

    @MainActor
    func testFactoryAppliesStyleSpecificSectionShadows() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    style: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    style: .usageInfo,
                    accessibilityLabel: "Usage information"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .onboardingGlow,
                    style: .onboardingGlow,
                    accessibilityLabel: "Onboarding highlight"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let layers = try stack.arrangedSubviews.map { view in
            try XCTUnwrap((view as? NSStackView)?.layer)
        }

        XCTAssertEqual(layers.map(\.shadowOpacity), [0, 0.12, 0, 0.16, 0.18, 0.18])
        XCTAssertEqual(layers.map(\.shadowRadius), [0, 4, 0, 5, 6, 6])
        XCTAssertEqual(layers.map(\.shadowOffset), [
            .zero,
            CGSize(width: 0, height: -1),
            .zero,
            CGSize(width: 0, height: -1),
            CGSize(width: 0, height: -2),
            CGSize(width: 0, height: -2)
        ])
        XCTAssertEqual(layers.map { Self.isShadowColor($0.shadowColor) }, [
            false,
            true,
            false,
            true,
            true,
            true
        ])
    }

    @MainActor
    func testFactoryAppliesStyleSpecificTitleColors() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    style: .compactPill,
                    accessibilityLabel: "Compact island"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .usageInfo,
                    style: .usageInfo,
                    accessibilityLabel: "Usage information"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .onboardingGlow,
                    style: .onboardingGlow,
                    accessibilityLabel: "Onboarding highlight"
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let titleColors = try stack.arrangedSubviews.map { view in
            let section = try XCTUnwrap(view as? NSStackView)
            let title = try XCTUnwrap(section.arrangedSubviews.first as? NSTextField)
            return title.textColor
        }

        XCTAssertEqual(titleColors, [
            .labelColor,
            .labelColor,
            .labelColor,
            .controlTextColor,
            .alternateSelectedControlTextColor,
            .alternateSelectedControlTextColor
        ])
    }

    @MainActor
    func testFactoryAppliesStyleSpecificSupplementaryTextColors() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    style: .sessionCard,
                    accessibilityLabel: "Session cards",
                    detailLabel: "Default detail",
                    secondaryLabel: "Default secondary",
                    sessionBadges: ["default"],
                    sessionIds: ["default"]
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available",
                    detailLabel: "Update detail",
                    secondaryLabel: "Update secondary",
                    sessionBadges: ["update"],
                    sessionIds: ["update"]
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions",
                    detailLabel: "Question detail",
                    secondaryLabel: "Question secondary",
                    sessionBadges: ["question"],
                    sessionIds: ["question"]
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let sections = try stack.arrangedSubviews.map { view in
            try XCTUnwrap(view as? NSStackView)
        }
        let secondaryColors = try sections.map { section in
            try XCTUnwrap(section.arrangedSubviews.compactMap { view -> NSColor? in
                guard let field = view as? NSTextField,
                      field.identifier?.rawValue.hasSuffix(".sessions") == true else {
                    return nil
                }

                return field.textColor
            }.first)
        }
        let detailColors = try sections.map { section in
            try XCTUnwrap(section.arrangedSubviews.compactMap { view -> NSColor? in
                guard let field = view as? NSTextField,
                      field.identifier?.rawValue.hasSuffix(".detail") == true else {
                    return nil
                }

                return field.textColor
            }.first)
        }
        let badgeColors = try sections.map { section in
            let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
            let badge = try XCTUnwrap(badgeStack.arrangedSubviews.first as? NSTextField)
            return badge.textColor
        }

        let expected: [NSColor] = [
            .secondaryLabelColor,
            .controlTextColor,
            .alternateSelectedControlTextColor
        ]
        XCTAssertEqual(secondaryColors, expected)
        XCTAssertEqual(detailColors, expected)
        XCTAssertEqual(badgeColors, expected)
    }

    @MainActor
    func testFactoryAppliesStyleSpecificBadgeColors() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .notificationPeek,
                    style: .notificationPeek,
                    accessibilityLabel: "Notification peek",
                    sessionBadges: ["notify"],
                    sessionIds: ["notify"]
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .updatePill,
                    style: .updatePill,
                    accessibilityLabel: "Update available",
                    sessionBadges: ["update"],
                    sessionIds: ["update"]
                ),
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .questionActions,
                    style: .questionAction,
                    accessibilityLabel: "Question actions",
                    sessionBadges: ["question"],
                    sessionIds: ["question"]
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let badgeFields = try stack.arrangedSubviews.map { view in
            let section = try XCTUnwrap(view as? NSStackView)
            let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
            return try XCTUnwrap(badgeStack.arrangedSubviews.first as? NSTextField)
        }

        XCTAssertEqual(badgeFields.map { $0.layer?.backgroundColor }, [
            NSColor.unemphasizedSelectedContentBackgroundColor.cgColor,
            NSColor.findHighlightColor.cgColor,
            NSColor.selectedControlColor.cgColor
        ])
        XCTAssertEqual(badgeFields.map { $0.layer?.borderColor }, [
            NSColor.selectedContentBackgroundColor.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.controlAccentColor.cgColor
        ])
    }

    @MainActor
    func testFactoryPinsSurfaceTextFieldsToIntrinsicSize() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    detailLabel: "Focused worktree",
                    secondaryLabel: "2 sessions",
                    sessionBadges: ["active", "review"],
                    sessionIds: ["active", "review"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let directTextFields = section.arrangedSubviews.compactMap { $0 as? NSTextField }
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let badgeTextFields = badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }
        let textFields = directTextFields + badgeTextFields

        XCTAssertEqual(
            textFields.map { $0.contentHuggingPriority(for: .horizontal) },
            Array(repeating: .required, count: 5)
        )
        XCTAssertEqual(
            textFields.map { $0.contentHuggingPriority(for: .vertical) },
            Array(repeating: .required, count: 5)
        )
        XCTAssertEqual(
            textFields.map { $0.contentCompressionResistancePriority(for: .horizontal) },
            Array(repeating: .required, count: 5)
        )
        XCTAssertEqual(
            textFields.map { $0.contentCompressionResistancePriority(for: .vertical) },
            Array(repeating: .required, count: 5)
        )
    }

    @MainActor
    func testFactoryBuildsAutoLayoutReadySurfaceHierarchy() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .sessionCards,
                    accessibilityLabel: "Session cards",
                    detailLabel: "Focused worktree",
                    secondaryLabel: "2 sessions",
                    sessionBadges: ["active", "review"],
                    sessionIds: ["active", "review"],
                    interactionHint: .openFocusedSession,
                    isInteractive: true
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let stack = try XCTUnwrap(view as? NSStackView)
        let section = try XCTUnwrap(stack.arrangedSubviews.first as? NSStackView)
        let badgeStack = try XCTUnwrap(section.arrangedSubviews.compactMap { $0 as? NSStackView }.first)
        let textFields = section.arrangedSubviews.compactMap { $0 as? NSTextField }
            + badgeStack.arrangedSubviews.compactMap { $0 as? NSTextField }

        XCTAssertFalse(stack.translatesAutoresizingMaskIntoConstraints)
        XCTAssertFalse(section.translatesAutoresizingMaskIntoConstraints)
        XCTAssertFalse(badgeStack.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(
            textFields.map(\.translatesAutoresizingMaskIntoConstraints),
            Array(repeating: false, count: 5)
        )
    }

    @MainActor
    func testFactoryConstrainsRootSurfaceToDescriptorContentSize() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 320, height: 180),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .compactPill,
                    accessibilityLabel: "Compact island"
                )
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let widthConstraint = view.constraints.first {
            $0.firstItem === view && $0.firstAttribute == .width && $0.relation == .equal
        }
        let heightConstraint = view.constraints.first {
            $0.firstItem === view && $0.firstAttribute == .height && $0.relation == .equal
        }

        XCTAssertEqual(widthConstraint?.constant, 320)
        XCTAssertEqual(heightConstraint?.constant, 180)
        XCTAssertTrue(widthConstraint?.isActive == true)
        XCTAssertTrue(heightConstraint?.isActive == true)
    }

    @MainActor
    func testFactoryKeepsHiddenSurfaceOutOfAccessibilityTraversal() throws {
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: false,
            contentSize: DisplaySize(width: 320, height: 180),
            items: []
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)

        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
        XCTAssertEqual(view.accessibilityValue() as? String, "0 sections")
    }

    @MainActor
    func testFactoryPermissionControlsEmitTypedAllowAndDenyResolutions() throws {
        var resolutions: [ActionResolution] = []
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "permission-1",
            sessionId: "session-1",
            source: "codex",
            kind: .permission,
            toolName: "Shell",
            details: ActionRequestDetails(prompt: "Allow shell command?")
        ))
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .actionRequests,
                    accessibilityLabel: "Pending action requests",
                    actionRequestPreviews: [request]
                ),
            ]
        )
        let view = MyVibeIslandAppKitIslandSurfaceViewFactory(
            performAction: { resolutions.append($0) }
        ).makeView(from: descriptor)
        let buttons = descendants(of: view).compactMap { $0 as? NSButton }
        let allow = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action.permission-1.allow-once"
        })
        let deny = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action.permission-1.deny"
        })

        allow.performClick(nil)
        deny.performClick(nil)

        XCTAssertEqual(resolutions, [
            ActionResolution(requestId: "permission-1", sessionId: "session-1", kind: .approve),
            ActionResolution(requestId: "permission-1", sessionId: "session-1", kind: .deny),
        ])
    }

    @MainActor
    func testFactoryQuestionOptionAndSubmitEmitTypedAnswerResolution() throws {
        var resolutions: [ActionResolution] = []
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "question-1",
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "Question",
            details: ActionRequestDetails(
                prompt: "Choose a path",
                options: [
                    ActionRequestOption(id: "structured", label: "Structured"),
                    ActionRequestOption(id: "minimal", label: "Minimal"),
                ]
            )
        ))
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .actionRequests,
                    accessibilityLabel: "Pending action requests",
                    actionRequestPreviews: [request]
                ),
            ]
        )
        let view = MyVibeIslandAppKitIslandSurfaceViewFactory(
            performAction: { resolutions.append($0) }
        ).makeView(from: descriptor)
        let buttons = descendants(of: view).compactMap { $0 as? NSButton }
        let option = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action.question-1.option.minimal"
        })
        let submit = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action.question-1.submit"
        })

        option.performClick(nil)
        submit.performClick(nil)

        XCTAssertEqual(resolutions, [
            ActionResolution(
                requestId: "question-1",
                sessionId: "session-1",
                kind: .answer,
                selection: "Minimal"
            ),
        ])
    }

    @MainActor
    func testFactoryOpenCodeMultiQuestionWizardRetainsSelectionsAndEmitsAnswerMap() throws {
        var resolutions: [ActionResolution] = []
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "question-1",
            sessionId: "session-1",
            source: "opencode",
            kind: .question,
            toolName: "AskUserQuestion",
            details: ActionRequestDetails(questions: [
                ActionRequestQuestion(
                    id: "target",
                    header: "Target",
                    prompt: "Where should this run?",
                    options: [
                        ActionRequestOption(id: "local", label: "Local"),
                        ActionRequestOption(id: "remote", label: "Remote"),
                    ]
                ),
                ActionRequestQuestion(
                    id: "checks",
                    header: "Checks",
                    prompt: "Which checks should run?",
                    options: [
                        ActionRequestOption(id: "tests", label: "Tests"),
                        ActionRequestOption(id: "lint", label: "Lint"),
                    ],
                    allowsMultipleSelection: true
                ),
            ])
        ))
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 320),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .actionRequests,
                    accessibilityLabel: "Pending action requests",
                    actionRequestPreviews: [request]
                ),
            ]
        )
        let view = MyVibeIslandAppKitIslandSurfaceViewFactory(
            performAction: { resolutions.append($0) }
        ).makeView(from: descriptor)

        func button(_ suffix: String) throws -> NSButton {
            try XCTUnwrap(descendants(of: view).compactMap { $0 as? NSButton }.first {
                $0.identifier?.rawValue == "my-vibe-island.action.question-1.wizard.\(suffix)"
            })
        }
        func questionLabel() throws -> NSTextField {
            try XCTUnwrap(descendants(of: view).compactMap { $0 as? NSTextField }.first {
                $0.identifier?.rawValue == "my-vibe-island.action.question-1.wizard.question"
            })
        }

        XCTAssertEqual(try questionLabel().stringValue, "Where should this run?")
        try button("option.local").performClick(nil)
        try button("next").performClick(nil)

        XCTAssertEqual(try questionLabel().stringValue, "Which checks should run?")
        try button("option.tests").performClick(nil)
        try button("option.lint").performClick(nil)
        try button("previous").performClick(nil)

        XCTAssertEqual(try questionLabel().stringValue, "Where should this run?")
        XCTAssertEqual(try button("option.local").state, .on)
        try button("next").performClick(nil)
        XCTAssertEqual(try button("option.tests").state, .on)
        XCTAssertEqual(try button("option.lint").state, .on)
        try button("submit").performClick(nil)

        XCTAssertEqual(resolutions, [
            ActionResolution(
                requestId: "question-1",
                sessionId: "session-1",
                kind: .answer,
                answers: [
                    "Target": "Local",
                    "Checks": "Tests, Lint",
                ]
            ),
        ])
    }

    @MainActor
    func testFactoryQuestionWithoutOptionsShowsTerminalAnswerFallback() throws {
        let request = ActionRequestPreview(request: ActionableRequest(
            requestId: "question-terminal",
            sessionId: "session-1",
            source: "codex",
            kind: .question,
            toolName: "Question",
            details: ActionRequestDetails(prompt: "Confirm in the terminal")
        ))
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 260),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .actionRequests,
                    accessibilityLabel: "Pending action requests",
                    actionRequestPreviews: [request]
                ),
            ]
        )

        let view = MyVibeIslandAppKitIslandSurfaceViewFactory().makeView(from: descriptor)
        let descendants = descendants(of: view)
        let fallback = try XCTUnwrap(descendants.compactMap { $0 as? NSTextField }.first {
            $0.identifier?.rawValue == "my-vibe-island.action.question-terminal.answer-in-terminal"
        })

        XCTAssertEqual(fallback.stringValue, "Please answer in the terminal")
        XCTAssertFalse(descendants.compactMap { $0 as? NSButton }.contains {
            $0.identifier?.rawValue == "my-vibe-island.action.question-terminal.submit"
        })
    }

    @MainActor
    func testFactoryOpenCodePermissionQueueEmitsAlwaysAllowAndBulkResolutions() throws {
        var resolutions: [ActionResolution] = []
        let requests = ["permission-1", "permission-2"].map { requestId in
            ActionRequestPreview(request: ActionableRequest(
                requestId: requestId,
                sessionId: "session-1",
                source: "opencode",
                kind: .permission,
                toolName: "Bash"
            ))
        }
        let descriptor = MyVibeIslandAppKitIslandSurfaceDescriptor(
            isVisible: true,
            contentSize: DisplaySize(width: 520, height: 320),
            items: [
                MyVibeIslandAppKitIslandSurfaceItemDescriptor(
                    section: .actionRequests,
                    accessibilityLabel: "Pending action requests",
                    actionRequestPreviews: requests
                ),
            ]
        )
        let view = MyVibeIslandAppKitIslandSurfaceViewFactory(
            performAction: { resolutions.append($0) }
        ).makeView(from: descriptor)
        let buttons = descendants(of: view).compactMap { $0 as? NSButton }
        let always = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action.permission-1.always-allow"
        })
        let allowAll = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action-requests.allow-all"
        })
        let denyAll = try XCTUnwrap(buttons.first {
            $0.identifier?.rawValue == "my-vibe-island.action-requests.deny-all"
        })

        always.performClick(nil)
        allowAll.performClick(nil)
        denyAll.performClick(nil)

        XCTAssertEqual(resolutions, [
            ActionResolution(requestId: "permission-1", sessionId: "session-1", kind: .approveAlways),
            ActionResolution(requestId: "permission-1", sessionId: "session-1", kind: .approve),
            ActionResolution(requestId: "permission-2", sessionId: "session-1", kind: .approve),
            ActionResolution(requestId: "permission-1", sessionId: "session-1", kind: .deny),
            ActionResolution(requestId: "permission-2", sessionId: "session-1", kind: .deny),
        ])
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(descendants(of:))
    }

    @MainActor
    private func viewSummary(id: String, view: NSView) -> IslandSurfaceViewFactoryMatrixRow {
        let stack = view as? NSStackView
        let sections = stack?.arrangedSubviews.compactMap { $0 as? NSStackView } ?? []
        return IslandSurfaceViewFactoryMatrixRow(
            id: id,
            width: view.frame.width,
            height: view.frame.height,
            isHidden: view.isHidden,
            identifier: view.identifier?.rawValue,
            accessibilityLabel: view.accessibilityLabel(),
            accessibilityValue: view.accessibilityValue() as? String,
            isAccessibilityElement: view.isAccessibilityElement(),
            orientation: stack.map(Self.orientationName),
            sections: sections.map { section in
                IslandSurfaceSectionViewSummary(
                    identifier: section.identifier?.rawValue,
                    orientation: Self.orientationName(for: section),
                    accessibilityLabel: section.accessibilityLabel(),
                    accessibilityValue: section.accessibilityValue() as? String,
                    toolTip: section.toolTip,
                    directTextValues: section.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue },
                    badgeValues: section.arrangedSubviews.compactMap { $0 as? NSStackView }.flatMap { badges in
                        badges.arrangedSubviews.compactMap { ($0 as? NSTextField)?.stringValue }
                    }
                )
            }
        )
    }

    @MainActor
    private static func orientationName(for stack: NSStackView) -> String {
        stack.orientation == .horizontal ? "horizontal" : "vertical"
    }

    private static func isShadowColor(_ color: CGColor?) -> Bool {
        guard let color else {
            return false
        }

        return CFEqual(color, NSColor.shadowColor.cgColor)
    }
}

private struct IslandSurfaceViewFactoryMatrixFixture: Codable, Equatable {
    let rows: [IslandSurfaceViewFactoryMatrixRow]
}

private struct IslandSurfaceViewFactoryMatrixRow: Codable, Equatable {
    let id: String
    let width: Double
    let height: Double
    let isHidden: Bool
    let identifier: String?
    let accessibilityLabel: String?
    let accessibilityValue: String?
    let isAccessibilityElement: Bool
    let orientation: String?
    let sections: [IslandSurfaceSectionViewSummary]
}

private struct IslandSurfaceSectionViewSummary: Codable, Equatable {
    let identifier: String?
    let orientation: String
    let accessibilityLabel: String?
    let accessibilityValue: String?
    let toolTip: String?
    let directTextValues: [String]
    let badgeValues: [String]
}
