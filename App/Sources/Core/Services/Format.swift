import Foundation

/// Formatting helpers shared by the printed receipt, the live tracking screen
/// and the share preview, so the same number is never rendered two ways.
public enum Format {
    /// `07′03″` — minutes and seconds per kilometre.
    public static func pace(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm, secondsPerKm.isFinite, secondsPerKm > 0 else { return "—" }
        let total = Int(secondsPerKm.rounded())
        return String(format: "%02d′%02d″", total / 60, total % 60)
    }

    /// A difference in pace, written the way a runner would say it.
    ///
    /// A few seconds is said as seconds, not as `00′11″`.
    public static func paceDifference(_ seconds: Double) -> String {
        let total = Int(abs(seconds).rounded())
        if total < 60 {
            return "\(total) s"
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// `03:24:25` or `34:17`.
    ///
    /// Hours are zero-padded so the receipt reads as a fixed monospaced
    /// duration rather than a shifting column.
    public static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// `29.00`
    public static func kilometres(_ metres: Double) -> String {
        String(format: "%.2f", metres / 1000)
    }

    /// `Oct 17, 2026`
    public static func receiptDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    /// `SAT–OCT 07:08`
    public static func receiptStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE–MMM HH:mm"
        return formatter.string(from: date)
    }

    /// `SAT 17 OCT`
    public static func archiveDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }
}
