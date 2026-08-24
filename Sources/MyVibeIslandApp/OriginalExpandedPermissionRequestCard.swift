import MyVibeIslandCore
import SwiftUI

/// Reconstructed from the live original Codex approval hierarchy. The action
/// surface is selected by live bridge ownership, not by persisted metadata.
struct OriginalExpandedPermissionRequestCard: View {
    let request: ActionRequestPreview
    let onJumpToTerminal: () -> Void
    let onApprovalHoverChange: (Bool) -> Void
    let onSubmit: (ActionResolution) -> Bool

    init(
        request: ActionRequestPreview,
        onJumpToTerminal: @escaping () -> Void,
        onSubmit: @escaping (ActionResolution) -> Bool,
        onApprovalHoverChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.request = request
        self.onJumpToTerminal = onJumpToTerminal
        self.onSubmit = onSubmit
        self.onApprovalHoverChange = onApprovalHoverChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange.opacity(0.95))
                        .font(.system(size: 10, weight: .semibold))
                    if !request.canResolveLocally {
                        Text("允许")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.orange.opacity(0.95))
                    }
                    Text(request.toolName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.orange.opacity(0.95))
                    if request.canResolveLocally {
                        Spacer(minLength: 0)
                        Button(action: onJumpToTerminal) {
                            HStack(spacing: 4) {
                                Text("在终端中审批")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.62))
                        }
                        .buttonStyle(.plain)
                        .help("在终端中审批")
                    }
                }

                OriginalApprovalCommandSurface(command: command, reason: reason)
            }

            if request.canResolveLocally {
                OriginalLocalApprovalActionRow(
                    request: request,
                    onSubmit: onSubmit,
                    onApprovalHoverChange: onApprovalHoverChange
                )
            } else {
                OriginalJumpToTerminalPill(
                    toolName: request.toolName,
                    command: command,
                    action: onJumpToTerminal
                )
            }
        }
        .padding(.top, 2)
    }

    private var command: String {
        request.command ?? request.prompt ?? request.toolName
    }

    private var reason: String {
        request.reason ?? "请求需要在终端中确认"
    }
}

/// Two full-width controls from the live original Codex permission card.
struct OriginalLocalApprovalActionRow: View {
    let request: ActionRequestPreview
    let onApprovalHoverChange: (Bool) -> Void
    let onSubmit: (ActionResolution) -> Bool

    init(
        request: ActionRequestPreview,
        onSubmit: @escaping (ActionResolution) -> Bool,
        onApprovalHoverChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.request = request
        self.onSubmit = onSubmit
        self.onApprovalHoverChange = onApprovalHoverChange
    }

    var body: some View {
        HStack(spacing: 6) {
            actionButton("拒绝", kind: .deny, foreground: Color.white.opacity(0.88), background: Color.white.opacity(0.14))
            actionButton("允许一次", kind: .approve, foreground: Color.black.opacity(0.86), background: Color.white.opacity(0.92))
        }
        .frame(height: 26)
    }

    private func actionButton(
        _ title: String,
        kind: ActionResolutionKind,
        foreground: Color,
        background: Color
    ) -> some View {
        Button {
            _ = onSubmit(ActionResolution(
                requestId: request.requestId,
                sessionId: request.sessionId,
                kind: kind
            ))
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover(perform: onApprovalHoverChange)
    }
}
