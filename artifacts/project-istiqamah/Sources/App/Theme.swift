import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.035, green: 0.039, blue: 0.035)
    static let card = Color(red: 0.075, green: 0.082, blue: 0.075)
    static let raised = Color(red: 0.11, green: 0.12, blue: 0.11)
    static let primary = Color(red: 0.56, green: 0.66, blue: 1.0)
    static let muted = Color(red: 0.62, green: 0.64, blue: 0.62)
    static let border = Color.white.opacity(0.09)
    static let flame = Color(red: 1.0, green: 0.45, blue: 0.16)
}

extension View {
    func istiqamahCard() -> some View {
        self
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.border)
            }
    }
}
