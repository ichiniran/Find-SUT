import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isNotificationOn = true
    
    var body: some View {
        
        VStack(spacing: 2) {
            
            // HEADER
            ZStack {
                Color.formBackground
                    .ignoresSafeArea(edges: .top)
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.darkText)
                    }
                    
                    Spacer()
                    
                    Text("การตั้งค่า")
                        .font(.headline)
                        .foregroundColor(.darkText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 80)
            
            
            // CONTENT
            VStack(spacing: 0) {
                
                HStack {
                    Text("การแจ้งเตือน")
                        .foregroundColor(.loginTitle)
                    
                    Spacer()
                    
                    Toggle("", isOn: $isNotificationOn)
                        .labelsHidden()
                        .tint(Color.green)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 40)
                .background(Color.white)
            }
            
            Spacer()
        }
        .background(Color.formBackground)
        //LinearGradient.appGradient
           // .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}
#Preview {
    SettingsView()
}
