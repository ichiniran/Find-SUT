import SwiftUI
struct InputField: View {
    var title: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        
        if isSecure {
            SecureField(title, text: $text)
                .padding()
                .background(Color.white)
                .cornerRadius(25)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.oneTimeCode)
        } else {
            TextField(title, text: $text)
                .padding()
                .background(Color.white)
                .cornerRadius(25)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
        }
    }
}
