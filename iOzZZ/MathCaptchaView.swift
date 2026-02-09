import SwiftUI

struct MathCaptchaView: View {
    let difficulty: MathDifficulty
    let onSolved: () -> Void

    @State private var problem = CaptchaService.generateProblem(difficulty: .easy)
    @State private var userAnswer = ""
    @State private var isWrong = false
    @State private var attempts = 0

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)

                Text("Solve to Dismiss")
                    .font(.title2.bold())

                Text("Difficulty: \(difficulty.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Math problem
            Text(problem.question)
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .monospacedDigit()
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

            // Answer input
            VStack(spacing: 12) {
                TextField("Your answer", text: $userAnswer)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isWrong ? .red : .clear, lineWidth: 2)
                            .padding(.horizontal, 24)
                    )

                if isWrong {
                    Text("Wrong answer! Try again.")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }

                if attempts > 0 {
                    Text("Attempts: \(attempts)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Submit button
            Button {
                checkAnswer()
            } label: {
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 24)
            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .onAppear {
            problem = CaptchaService.generateProblem(difficulty: difficulty)
        }
        .animation(.easeInOut(duration: 0.3), value: isWrong)
    }

    private func checkAnswer() {
        if CaptchaService.validate(userAnswer: userAnswer, correctAnswer: problem.answer) {
            onSolved()
        } else {
            attempts += 1
            isWrong = true
            userAnswer = ""
            // Generate a new problem after wrong answer
            problem = CaptchaService.generateProblem(difficulty: difficulty)

            // Reset the error indicator after a delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                isWrong = false
            }
        }
    }
}

#Preview {
    MathCaptchaView(difficulty: .medium, onSolved: {})
}
