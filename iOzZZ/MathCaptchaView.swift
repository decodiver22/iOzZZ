//
//  MathCaptchaView.swift
//  iOzZZ
//
//  Math problem captcha UI with immersive full-screen design.
//  Generates new problem on wrong answer, tracks attempts, shows validation feedback.
//

import SwiftUI

struct MathCaptchaView: View {
    let difficulty: MathDifficulty
    let onSolved: () -> Void

    @State private var problem = CaptchaService.generateProblem(difficulty: .easy)
    @State private var userAnswer = ""
    @State private var isWrong = false
    @State private var attempts = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.05, blue: 0.2), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Header - more compact
                VStack(spacing: 10) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .red.opacity(0.5), radius: 15)

                    Text("Solve to Continue")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Difficulty: \(difficulty.rawValue)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .opacity(0.5)
                        )
                }

                // Math problem - more compact
                VStack {
                    Text(problem.question)
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)

                        RoundedRectangle(cornerRadius: 24)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                )
                .shadow(color: .black.opacity(0.3), radius: 15, y: 8)
                .shadow(color: .blue.opacity(0.2), radius: 20)
                .padding(.horizontal, 20)

                // Answer input - more compact
                VStack(spacing: 12) {
                    TextField("Your answer", text: $userAnswer)
                        .keyboardType(.numberPad)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 24)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.6)

                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        isWrong ?
                                            LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing) :
                                            LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        lineWidth: isWrong ? 3 : 1.5
                                    )
                            }
                        )
                        .padding(.horizontal, 20)

                    if isWrong {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("Wrong answer!")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.red)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    if attempts > 0 {
                        Text("Attempts: \(attempts)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.ultraThinMaterial).opacity(0.4))
                    }
                }

                // Submit button - more compact
                Button {
                    checkAnswer()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                        Text("Submit")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .background(
                    LinearGradient(
                        colors: userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                            [.gray, .gray.opacity(0.8)] :
                            [.green, .green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .green.opacity(0.3), radius: 12, y: 6)
                .padding(.horizontal, 20)
                .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer(minLength: 20)
            }
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
