import SwiftUI
import FirebaseAuth
import FirebaseFirestore
struct RegisterView: View {
    
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    var body: some View {
        
        ZStack {
          
            LinearGradient(
                colors: [Color(hex: "#FFFAF5"), Color(hex: "#ffe6d0")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                
                // Logo
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 80)
                    .padding(.top, 80)
                
                Spacer().frame(height: 20)
                
                // Card (เหมือน Login)
                VStack(spacing: 30) {
                    
                    Text("Sign up")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(hex: "#5A4633"))
                    
                    // Username
                    InputField(title: "Username", text: $username)
                        .textContentType(.username)
                    
                    // Email
                    InputField(title: "Email", text: $email)
                        .textContentType(.emailAddress)
                    // Password
                    InputField(title: "Password", text: $password, isSecure: true)
                        .textContentType(.newPassword)
                    // Confirm Password
                    InputField(title: "Confirm Password", text: $confirmPassword, isSecure: true)
                        .textContentType(.newPassword)
                    // Register Button
                    Button(action: { handleRegister()
                    }) {
                        Text("Create Account")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#FBAA58"))
                            .cornerRadius(25)
                    }
                    .padding(.top, 10)
                    
                                   
                    
                    // Login link
                    HStack(spacing: 0) {
                        Text("Already have an account? ")
                        Text("Login")
                            .underline()
                            .foregroundColor(Color(hex: "#FBAA58"))
                    }
                    .font(.system(size: 13))
                    .onTapGesture {
                        dismiss()
                    }
                    
                }
                .padding(30)
                .background(  Color.white.opacity(0.25)
                    .blur(radius: 10))
                .cornerRadius(40)
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Error", isPresented: $showAlert) {
               Button("OK", role: .cancel) {}
           } message: {
               Text(alertMessage)
           }
    }
    func handleRegister() {
        
        // เช็ค password
        if password != confirmPassword {
            alertMessage = "Password ไม่ตรงกัน"
            showAlert = true
            return
        }
        
        let auth = Auth.auth()
        let db = Firestore.firestore()
        
        auth.createUser(withEmail: email, password: password) { result, error in
            
            if let error = error as NSError? {
                
                switch error.code {
                    
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    alertMessage = "อีเมลนี้ถูกใช้งานแล้ว"
                    
                case AuthErrorCode.invalidEmail.rawValue:
                    alertMessage = "รูปแบบอีเมลไม่ถูกต้อง"
                    
                case AuthErrorCode.weakPassword.rawValue:
                    alertMessage = "รหัสผ่านต้องมีอย่างน้อย 6 ตัว"
                    
                default:
                    alertMessage = error.localizedDescription
                }
                
                showAlert = true
                return
            }
            
            guard let user = result?.user else { return }
            
            // save ลง Firestore
            db.collection("users").document(user.uid).setData([
                "username": username,
                "email": email,
                "photoURL": "",
                "createdAt": Timestamp(),
            ]) { err in
                
                if let err = err {
                    print("Firestore error:", err.localizedDescription)
                } else {
                    print("สมัครสำเร็จ")
                    self.isLogin = true
                 
                }
            }
        }
    }
}

#Preview {
    RegisterView(isLogin: .constant(false))
}

#Preview {
    LoginView(isLogin: .constant(false))
}
