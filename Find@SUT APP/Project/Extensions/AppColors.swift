import SwiftUI

extension Color {
    
    static let appBackground = Color(hex: "#FBAA58")
    static let formBackground = Color(hex: "#FFFAF5")
    static let textFieldBackground = Color(hex: "#FFFFFF")
    static let darkText = Color(hex: "#5A4633")
    static let loginTitle = Color(hex: "#6E4D31")
    static let normalText = Color(hex: "#000000")
}

extension LinearGradient {
    
    static let appGradient = LinearGradient(
        colors: [Color(hex: "#FFFAF5"), Color(hex: "#FFE6D0")],
        startPoint: .top,
        endPoint: .bottom
    )
}
