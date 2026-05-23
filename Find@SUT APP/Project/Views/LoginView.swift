import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @Binding var isLogin: Bool
    @State private var emailOrUsername: String = ""
    @State private var password: String = ""
     
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack (){
                
                // Background Gradient
                LinearGradient(
                    colors: [Color(hex: "#FFFAF5"), Color(hex: "#ffe6d0")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack {

                    Spacer()

                    // Logo
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 80)

                    Spacer().frame(height: 25)

                    // Card
                    VStack(spacing: 35) {

                        Text("Login")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(hex: "#5A4633"))

                        TextField("Email or Username", text: $emailOrUsername)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(25)
                            .autocorrectionDisabled(true)          //  ปิดแก้คำอัตโนมัติ
                            .textInputAutocapitalization(.never)   // ไม่พิมพ์ใหญ่ตัวแรก

                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(25)

                        HStack {
                            Spacer()
                            Button(action: {
                                handleResetPassword()
                            }) {
                                Text("forgot Password?")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#5A4633"))
                            }
                        }

                        Button(action: {
                            handleLogin()
                        }) {
                            Text("Login")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#FBAA58"))
                                .cornerRadius(25)
                        }

                        HStack(spacing: 0) {
                            Text("Don't have an account? ")
                                .foregroundColor(Color.black)
                            NavigationLink(destination: RegisterView(isLogin: $isLogin)) {
                                Text("Create New Account")
                                    .foregroundColor(Color(hex: "#FBAA58"))
                                    .underline()
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.system(size: 13))

                    }
                    .padding(30)
                    .background(Color.white.opacity(0.25))
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
        }
        .preferredColorScheme(.light)

        .alert("แจ้งเตือน", isPresented: $showAlert) {
            Button("ตกลง", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Login Functions
    func handleLogin() {
        let db = Firestore.firestore()
        
        if !emailOrUsername.contains("@") {
            // กรณีกรอก Username
            db.collection("users")
                .whereField("username", isEqualTo: emailOrUsername)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error:", error.localizedDescription)
                        return
                    }
                    
                    guard let doc = snapshot?.documents.first else {
                        DispatchQueue.main.async {
                            self.alertMessage = "ไม่พบ Username นี้ในระบบ"
                            self.showAlert = true
                        }
                        return
                    }
                    
                    let data = doc.data()
                    
                    // เช็ค banned ก่อน
                    if let banned = data["banned"] as? Bool, banned == true {
                        DispatchQueue.main.async {
                            self.alertMessage = "บัญชีผู้ใช้ถูกแบน ไม่สามารถเข้าสู่ระบบได้"
                            self.showAlert = true
                        }
                        return
                    }
                    
                    let email = data["email"] as? String ?? ""
                    self.loginWithEmail(email: email)
                }
        } else {
            // กรณีกรอก Email - เช็ค banned ก่อนเหมือนกัน
            db.collection("users")
                .whereField("email", isEqualTo: emailOrUsername)
                .getDocuments { snapshot, error in
                    if let doc = snapshot?.documents.first {
                        let data = doc.data()
                        
                        // เช็ค banned ก่อน
                        if let banned = data["banned"] as? Bool, banned == true {
                            DispatchQueue.main.async {
                                self.alertMessage = "บัญชีผู้ใช้ถูกแบน ไม่สามารถเข้าสู่ระบบได้"
                                self.showAlert = true
                            }
                            return
                        }
                    }
                    
                    // ถ้าไม่ถูกแบน หรือไม่เจอใน Firestore ให้ login ปกติ
                    self.loginWithEmail(email: self.emailOrUsername)
                }
        }
    }

    func loginWithEmail(email: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "อีเมลหรือรหัสผ่านไม่ถูกต้อง"
                    self.showAlert = true
                }
                return
            }
            
            print("Login สำเร็จ")
            DispatchQueue.main.async {
                self.isLogin = true
            }
        }
    }
    
    // MARK: - Reset Password Functions
    func handleResetPassword() {
        // 1. ตรวจสอบว่าผู้ใช้กรอกช่อง Email/Username แล้วหรือยัง
        guard !emailOrUsername.isEmpty else {
            alertMessage = "กรุณากรอก Email หรือ Username เพื่อทำการรีเซ็ตรหัสผ่าน"
            showAlert = true
            return
        }
        
        let db = Firestore.firestore()
        
        // 2. ถ้ากรอกเป็น Username (ไม่มี @) ให้ไปหา Email ในระบบก่อน
        if !emailOrUsername.contains("@") {
            db.collection("users")
                .whereField("username", isEqualTo: emailOrUsername)
                .getDocuments { snapshot, error in
                    if let error = error {
                        self.alertMessage = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
                        self.showAlert = true
                        return
                    }
                    
                    guard let doc = snapshot?.documents.first,
                          let email = doc.data()["email"] as? String else {
                        self.alertMessage = "ไม่พบ Username นี้ในระบบ"
                        self.showAlert = true
                        return
                    }
                    
                    // เจอ Email แล้ว ส่งลิงก์เลย
                    self.sendResetEmail(to: email)
                }
        } else {
            // 3. ถ้ากรอกเป็น Email อยู่แล้ว ให้ส่งลิงก์เลย
            sendResetEmail(to: emailOrUsername)
        }
    }
    
    func sendResetEmail(to email: String) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.alertMessage = "ไม่สามารถส่งอีเมลได้: \(error.localizedDescription)"
            } else {
                self.alertMessage = "ระบบได้ส่งลิงก์สำหรับเปลี่ยนรหัสผ่านไปยัง \(email) แล้ว กรุณาตรวจสอบกล่องจดหมายของคุณ"
            }
            self.showAlert = true
        }
    }
}

#Preview {
    LoginView(isLogin: .constant(false))
}
