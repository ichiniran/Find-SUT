import SwiftUI

struct OpenApp: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFFAF5"), Color(hex: "#ffe6d0")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Image("openlogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
        }
    }
}

#Preview {
    OpenApp()
}
