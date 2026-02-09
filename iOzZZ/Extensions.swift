import Foundation

extension Date {
    /// Creates a Date from hour and minute components for today.
    /// If the time has already passed today, returns tomorrow's date.
    static func next(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let date = calendar.date(from: components) else { return now }

        if date <= now {
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return date
    }
}

extension Int {
    /// Weekday name from Calendar weekday value (1=Sun..7=Sat)
    var weekdaySymbol: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard self >= 1, self <= 7 else { return "" }
        return symbols[self - 1]
    }
}
