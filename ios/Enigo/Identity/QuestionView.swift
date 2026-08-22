import SwiftUI

struct QuestionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var scheme
    let index: Int

    var body: some View {
        let question = ContentData.questions[index]
        EnigoScreen {
            HStack {
                Text("\(index + 1) of \(ContentData.questions.count)")
                    .font(EnigoFont.meta)
                    .foregroundStyle(EnigoColor.fgAlpha(scheme, 0.5))
                Spacer()
            }

            HStack(spacing: 4) {
                ForEach(0..<ContentData.questions.count, id: \.self) { i in
                    Capsule()
                        .fill(i <= index ? EnigoColor.accent(scheme) : EnigoColor.fgAlpha(scheme, 0.16))
                        .frame(height: 3)
                }
            }

            Eyebrow(text: question.category)
            Text(question.text)
                .font(EnigoFont.questionText)
                .foregroundStyle(EnigoColor.dominant(scheme))

            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { optionIndex, option in
                    SelectableRow(text: option, selected: false) {
                        appState.submitAnswer(optionIndex)
                    }
                }
            }
        }
    }
}
