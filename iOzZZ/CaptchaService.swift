import Foundation

struct MathProblem {
    let question: String
    let answer: Int
}

struct CaptchaService {

    // MARK: - Generate

    static func generateProblem(difficulty: MathDifficulty) -> MathProblem {
        switch difficulty {
        case .easy:
            return generateEasy()
        case .medium:
            return generateMedium()
        case .hard:
            return generateHard()
        }
    }

    // MARK: - Validate

    static func validate(userAnswer: String, correctAnswer: Int) -> Bool {
        let trimmed = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed) else { return false }
        return parsed == correctAnswer
    }

    // MARK: - Difficulty Levels

    /// Easy: addition or subtraction of 2-digit numbers
    private static func generateEasy() -> MathProblem {
        let a = Int.random(in: 10...99)
        let b = Int.random(in: 10...99)
        let useAddition = Bool.random()

        if useAddition {
            return MathProblem(question: "\(a) + \(b)", answer: a + b)
        } else {
            // Ensure non-negative result
            let (big, small) = a >= b ? (a, b) : (b, a)
            return MathProblem(question: "\(big) - \(small)", answer: big - small)
        }
    }

    /// Medium: multiplication of numbers 6-15
    private static func generateMedium() -> MathProblem {
        let a = Int.random(in: 6...15)
        let b = Int.random(in: 6...15)
        return MathProblem(question: "\(a) × \(b)", answer: a * b)
    }

    /// Hard: multi-step (a × b + c) or (a × b - c)
    private static func generateHard() -> MathProblem {
        let a = Int.random(in: 6...15)
        let b = Int.random(in: 6...15)
        let c = Int.random(in: 10...50)
        let useAddition = Bool.random()

        if useAddition {
            return MathProblem(question: "\(a) × \(b) + \(c)", answer: a * b + c)
        } else {
            return MathProblem(question: "\(a) × \(b) - \(c)", answer: a * b - c)
        }
    }
}
