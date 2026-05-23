import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        
        VStack(spacing: 2) {
            
            // ── HEADER ──
            ZStack {
                Color.formBackground
                    .ignoresSafeArea()
                
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.loginTitle)
                    }
                    
                    Spacer()
                    
                    Text("เปลี่ยนรหัสผ่าน")
                        .font(.headline)
                        .foregroundColor(.darkText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .opacity(0)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 50)
            Divider()
            
            // ── FORM ──
            VStack(spacing: 0) {
                formRow(title: "รหัสผ่านเดิม", text: $oldPassword, placeholder: "ระบุรหัสผ่านเดิม")
                Divider().padding(.horizontal, 24)
                formRow(title: "รหัสผ่านใหม่", text: $newPassword, placeholder: "ระบุรหัสผ่านใหม่ (6 ตัวขึ้นไป)")
                Divider().padding(.horizontal, 24)
                formRow(title: "ยืนยันรหัสใหม่", text: $confirmPassword, placeholder: "ระบุรหัสผ่านใหม่อีกครั้ง")
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            // ── BUTTON ──
            Button {
                handleChangePassword()
            } label: {
                Text(isLoading ? "กำลังบันทึก..." : "บันทึก")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#F97316"))
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
            }
            .disabled(isLoading) // ป้องกันการกดซ้ำตอนกำลังโหลด
            
            Spacer()
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        // แจ้งเตือนผลลัพธ์
        .alert("แจ้งเตือน", isPresented: $showAlert) {
            Button("ตกลง", role: .cancel) {
                // ถ้าเปลี่ยนสำเร็จ พอกดตกลงปุ๊บให้ปิดหน้านี้ทิ้งเลย
                if isSuccess { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Functions
    func handleChangePassword() {
        // 1. ดักจับ Error เบื้องต้น
        guard !oldPassword.isEmpty, !newPassword.isEmpty, !confirmPassword.isEmpty else {
            alertMessage = "กรุณากรอกข้อมูลให้ครบทุกช่อง"
            showAlert = true
            return
        }
        
        guard newPassword == confirmPassword else {
            alertMessage = "รหัสผ่านใหม่ทั้ง 2 ช่องไม่ตรงกัน"
            showAlert = true
            return
        }
        
        guard newPassword.count >= 6 else {
            alertMessage = "รหัสผ่านใหม่ต้องมีความยาวอย่างน้อย 6 ตัวอักษร"
            showAlert = true
            return
        }
        
        // 2. เริ่มทำงาน
        isLoading = true
        
        // ดึงข้อมูลผู้ใช้ปัจจุบัน
        guard let user = Auth.auth().currentUser, let email = user.email else {
            alertMessage = "ไม่พบข้อมูลผู้ใช้งานในระบบ"
            showAlert = true
            isLoading = false
            return
        }
        
        // 3. ยืนยันตัวตนด้วยรหัสเดิม (Re-authenticate)
        let credential = EmailAuthProvider.credential(withEmail: email, password: oldPassword)
        
        user.reauthenticate(with: credential) { authResult, error in
            if let error = error {
                self.isLoading = false
                self.alertMessage = "รหัสผ่านเดิมไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง"
                self.showAlert = true
                print("Re-auth error: \(error.localizedDescription)")
                return
            }
            
            // 4. ถ้ายืนยันตัวตนผ่าน ให้สั่งเปลี่ยนเป็นรหัสใหม่ทันที
            user.updatePassword(to: newPassword) { error in
                self.isLoading = false
                if let error = error {
                    self.alertMessage = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
                    self.showAlert = true
                } else {
                    self.isSuccess = true
                    self.alertMessage = "เปลี่ยนรหัสผ่านสำเร็จแล้ว!"
                    self.showAlert = true
                }
            }
        }
    }
}

// MARK: - Form Row
extension ChangePasswordView {
    func formRow(title: String,
                 text: Binding<String>,
                 placeholder: String) -> some View {
        
        HStack {
            Text(title)
                .foregroundColor(.loginTitle)
            Spacer()
            SecureField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        /*.background(Color.white)
        .overlay(
                   Rectangle()
                       .fill(Color(hex: "#5A4633"))
                       .frame(height: 0.5),
                   alignment: .bottom
               )*/
    }
}

#Preview {
    ChangePasswordView()
}
