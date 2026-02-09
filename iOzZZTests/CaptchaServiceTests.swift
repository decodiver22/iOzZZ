import Testing
@testable import iOzZZ

struct CaptchaServiceTests {

    // MARK: - Easy Difficulty

    @Test func easyProblemGeneratesValidQuestion() {
        let problem = CaptchaService.generateProblem(difficulty: .easy)
        #expect(!problem.question.isEmpty)
        #expect(problem.question.contains("+") || problem.question.contains("-"))
    }

    @Test func easyProblemHasReasonableAnswer() {
        for _ in 0..<100 {
            let problem = CaptchaService.generateProblem(difficulty: .easy)
            // Addition: max 99+99=198, Subtraction: min 0
            #expect(problem.answer >= 0)
            #expect(problem.answer <= 198)
        }
    }

    // MARK: - Medium Difficulty

    @Test func mediumProblemUsesMultiplication() {
        let problem = CaptchaService.generateProblem(difficulty: .medium)
        #expect(problem.question.contains("×"))
    }

    @Test func mediumProblemHasReasonableAnswer() {
        for _ in 0..<100 {
            let problem = CaptchaService.generateProblem(difficulty: .medium)
            // min: 6*6=36, max: 15*15=225
            #expect(problem.answer >= 36)
            #expect(problem.answer <= 225)
        }
    }

    // MARK: - Hard Difficulty

    @Test func hardProblemIsMultiStep() {
        let problem = CaptchaService.generateProblem(difficulty: .hard)
        #expect(problem.question.contains("×"))
        #expect(problem.question.contains("+") || problem.question.contains("-"))
    }

    @Test func hardProblemHasReasonableAnswer() {
        for _ in 0..<100 {
            let problem = CaptchaService.generateProblem(difficulty: .hard)
            // min: 6*6-50=-14, max: 15*15+50=275
            #expect(problem.answer >= -14)
            #expect(problem.answer <= 275)
        }
    }

    // MARK: - Validation

    @Test func correctAnswerValidates() {
        #expect(CaptchaService.validate(userAnswer: "42", correctAnswer: 42))
    }

    @Test func wrongAnswerFailsValidation() {
        #expect(!CaptchaService.validate(userAnswer: "41", correctAnswer: 42))
    }

    @Test func whitespaceIsTrimmed() {
        #expect(CaptchaService.validate(userAnswer: "  42  ", correctAnswer: 42))
        #expect(CaptchaService.validate(userAnswer: "\n42\n", correctAnswer: 42))
    }

    @Test func nonNumericInputFailsValidation() {
        #expect(!CaptchaService.validate(userAnswer: "abc", correctAnswer: 42))
        #expect(!CaptchaService.validate(userAnswer: "4.2", correctAnswer: 42))
    }

    @Test func emptyInputFailsValidation() {
        #expect(!CaptchaService.validate(userAnswer: "", correctAnswer: 42))
        #expect(!CaptchaService.validate(userAnswer: "   ", correctAnswer: 42))
    }

    @Test func negativeAnswerValidates() {
        #expect(CaptchaService.validate(userAnswer: "-5", correctAnswer: -5))
    }
}
