import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - AccountView
struct AccountView: View {
    @Environment(\.dismiss) var dismiss
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var showPhoneSheet = false

    var body: some View {
        VStack(spacing: 2) {

            // HEADER
            ZStack {
                Color.formBackground.ignoresSafeArea(edges: .top)
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").foregroundColor(Color.darkText)
                    }
                    Spacer()
                    Text("จัดการบัญชี").font(.headline).foregroundColor(Color.darkText)
                    Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 50)

            Divider()

            // CONTENT CARD
            VStack(spacing: 0) {

                // Email
                HStack {
                    Text("Email").foregroundColor(.loginTitle)
                    Spacer()
                    Text(email.isEmpty ? "-" : email)
                        .foregroundColor(.loginTitle)
                        .lineLimit(1)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 24)

                // Change Password
                NavigationLink { ChangePasswordView() } label: {
                    HStack {
                        Text("เปลี่ยนรหัสผ่าน").foregroundColor(.loginTitle)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.loginTitle)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                }

                Divider().padding(.horizontal, 24)

                // Phone
                Button { showPhoneSheet = true } label: {
                    HStack {
                        Text("เบอร์โทรศัพท์").foregroundColor(.loginTitle)
                        Spacer()
                        Text(phone.isEmpty ? "ยังไม่ได้เพิ่ม" : phone)
                            .foregroundColor(phone.isEmpty ? Color(.systemGray3) : .loginTitle)
                            .font(.system(size: 14))
                        Image(systemName: "chevron.right").foregroundColor(.loginTitle)
                    }
                    .padding(.vertical, 20)
                    .padding(.horizontal, 24)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
            .padding(.horizontal, 16)
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.formBackground)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { loadUserData() }
        .sheet(isPresented: $showPhoneSheet, onDismiss: { loadUserData() }) {
            PhoneEditSheet(currentPhone: phone)
                .presentationDetents([.fraction(0.5)])  // ← ครึ่งจอ แทน default ที่เล็กไป
                .presentationDragIndicator(.hidden)
        }
    }

    private func loadUserData() {
        guard let user = Auth.auth().currentUser else { return }
        email = user.email ?? ""
        Firestore.firestore().collection("users").document(user.uid).getDocument { snap, _ in
            guard let data = snap?.data() else { return }
            DispatchQueue.main.async {
                self.phone = data["phone"] as? String ?? ""
            }
        }
    }
}

// MARK: - PhoneEditSheet
struct PhoneEditSheet: View {
    let currentPhone: String
    @Environment(\.dismiss) var dismiss

    @State private var phoneInput: String = ""
    @State private var isSaving = false
    @State private var errorMsg: String = ""

    var isValid: Bool {
        let digits = phoneInput.filter { $0.isNumber }
        return digits.count == 10 && phoneInput.hasPrefix("0")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(currentPhone.isEmpty ? "เพิ่มเบอร์โทรศัพท์" : "แก้ไขเบอร์โทรศัพท์")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#2d1b10"))
                .padding(.horizontal, 24)

            Text("เบอร์โทรจะถูกใช้เพื่อการติดต่อเมื่อมารับของ")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#a0856a"))
                .padding(.horizontal, 24)
                .padding(.top, 4)

            // Input
            HStack(spacing: 10) {
                Image(systemName: "phone")
                    .foregroundColor(Color(hex: "#F97316"))
                    .font(.system(size: 16))
                TextField("0812345678", text: $phoneInput)
                    .keyboardType(.phonePad)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#2d1b10"))
                if !phoneInput.isEmpty {
                    Button { phoneInput = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#e5d3bd"), lineWidth: 1.5)
            )
            .cornerRadius(14)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            if !errorMsg.isEmpty {
                Text(errorMsg)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .padding(.horizontal, 28)
                    .padding(.top, 6)
            }

            // Buttons
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("ยกเลิก")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#a0856a"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#e5d3bd"), lineWidth: 1)
                        )
                }

                Button { savePhone() } label: {
                    Text(isSaving ? "กำลังบันทึก..." : "บันทึก")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(isValid ? Color(hex: "#F97316") : Color(.systemGray4))
                        .cornerRadius(14)
                }
                .disabled(!isValid || isSaving)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
        .background(Color.white)
        .onAppear { phoneInput = currentPhone }
    }

    private func savePhone() {
        guard isValid, let uid = Auth.auth().currentUser?.uid else { return }
        isSaving = true
        errorMsg = ""
        Firestore.firestore().collection("users").document(uid)
            .updateData(["phone": phoneInput]) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMsg = "บันทึกไม่สำเร็จ: \(error.localizedDescription)"
                    } else {
                        dismiss()
                    }
                }
            }
    }
}
