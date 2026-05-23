import SwiftUI
struct SocialButton: View {
    var image: String? = nil
    var systemImage: String? = nil
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 50, height: 50)
                .shadow(color: .black.opacity(0.1), radius: 5)
            
            if let image = image {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            }
            
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
        }
    }
}
