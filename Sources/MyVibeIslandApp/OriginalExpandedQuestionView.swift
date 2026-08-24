import MyVibeIslandCore
import SwiftUI

struct OriginalExpandedQuestionView: View {
    let question: ActionRequestQuestion
    let selectedAnswers: [String]
    let questionIndex: Int
    let questionCount: Int
    let canInteract: Bool
    let onSelect: (String) -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(question.header).font(.system(size: 10, weight: .semibold))
            Text(question.prompt).font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.72)).lineLimit(2)
            HStack(spacing: 6) {
                ForEach(question.options, id: \.id) { option in
                    Button(option.label) { onSelect(option.id) }
                        .buttonStyle(.plain)
                        .disabled(!canInteract)
                        .opacity(selectedAnswers.contains(option.id) ? 1 : 0.72)
                }
                Spacer(minLength: 0)
                if questionIndex > 0 {
                    Button { onPrevious() } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain)
                        .disabled(!canInteract)
                }
                Button(questionCount == 1 || questionIndex + 1 == questionCount ? "Done" : "Next") { onNext() }
                    .buttonStyle(.plain)
                    .disabled(!canInteract || selectedAnswers.isEmpty)
            }
        }
    }
}
